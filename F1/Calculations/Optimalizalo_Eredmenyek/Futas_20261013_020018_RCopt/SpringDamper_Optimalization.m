% =========================================================================
%  BASZOGEP OPTIMALIZÁLÓ (fmincon)
%  A baszogep.m kasztnidőlés / átterhelődés / ride / damper modelljére épül.
%
%  Folytonos változók (fmincon):  4 db MR polinom (1. vagy 2. fokú, x [mm]),
%                                 ARB / heave stabilizátor merevség (ha kell)
%  Diszkrét változók (felsorolás): főrugó (első, hátsó) a listából,
%                                 stabilizátor típus tengelyenként (nincs/roll/heave),
%                                 MR polinom foka (1 / 2),
%                                 damper click mind a 4 rezsimre, mindkét tengelyen
%  Kimenet: Excel az optimális beállításokkal + MR képletek (és MR-fájlok,
%           amiket a baszogep.m közvetlenül be tud tölteni).
%
%  ÚJ (v2):
%   - minden futtatás saját almappát kap: OUT_DIR/Futas_<időbélyeg>_<RC mód>/ ; ebben az Excel,
%     az MR-fájlok, a strukturális átadási adatlapok, az RC-összefoglaló, a konzol-napló és a
%     használt beállítások (beallitasok.mat + a script másolata)
%   - a roll center (RC) magasságok optimalizálása választható (O.OPT_RC), a jacking minimalizálásával;
%     a jacking-ben a heave (Z-bar) stabilizátor merevítése is számít, a reaktivitás megtartása mellett
%   - reaktivitás-mutatók: dőlésgradiens, geometriai (azonnali) terhelésátadás, roll csillapítás,
%     a terhelésátadás fáziskésése szlalom-frekvencián
%   - strukturális átadási adatlap: ARB / Z-bar motion ratio + a droplinken mérhető célmerevség
%
%  Szükséges: Optimization Toolbox (fmincon). Parallel Computing Toolbox opcionális.
%
%  FIGYELEM: a "!!! ÁLLÍTSD BE" jelölésű értékek helyőrzők - írd át őket.
% =========================================================================
clear; clc; close all;
t_all = tic;

%% 1. JÁRMŰ- ÉS MODELLADATOK (változatlanul a baszogep.m-ből)
P = struct();
P.valtoszam  = 175.128;     % [N/m / lbs/in]
P.g          = 9.81;
P.m_total    = 725.82;
P.distrF     = 0.45;
P.m_SM       = 628.82;
P.m_NSM_F    = 94.9 / 4;
P.m_NSM_R    = 94.9 / 4;
P.L          = 3.00;
P.T_F        = 1.60;
P.T_R        = 1.60;
P.h_CG_SM    = 0.320;
P.h_CG_total = 0.3;
P.h_CG_NSM   = 0.360;
P.h_RC_F     = 0.123;   % [m] ALAP RC magasság (O.OPT_RC = true esetén az optimalizáló felülírja; az önellenőrzés ezzel számol)
P.h_RC_R     = 0.127;   % [m] ALAP RC magasság (hátsó)
P.theta_x_CG = 7.65;
P.K_chassis  = 3500 * 180/pi;        % [Nm/rad]  (merev vázhoz: Inf)
P.rho_air    = 1.2;
P.CLA        = 6.4;
P.aero_distr_F = 0.45;
P.v_max_kmh  = 360;                  % [km/h] a hasmagasság-vizsgálat felső sebessége
P.h_static_F_mm = 35;
P.h_static_R_mm = 60;
% --- 0.4b DINAMIKUS MAGASSÁGOK: A ROLL CENTER A CoG-GAL EGYÜTT MOZOG ---------------
% A kasztni függőleges elmozdulása (jacking felfelé, aero lesüllyedés lefelé) a CoG-t ÉS a roll centert is viszi.
P.DYN_HEIGHT = true;     % true: dinamikus CoG + RC (aero lesüllyedés + jacking); false: a korábbi modell (RC fix, a CoG csak jackinggel emelkedik)
P.k_RC_F     = 1.05;      % [-] az első RC a kasztni függőleges mozgásának hányadát követi (1 = 1:1, 0 = fix RC)  !!! ÁLLÍTSD BE a kinematikából (dRC/dheave)
P.k_RC_R     = 1.05;      % [-] ugyanez hátul                                                                      !!! ÁLLÍTSD BE
P.v_corner_kmh = 120;     % [km/h] kanyarsebesség: ezen a sebességen számolt aero lesüllyedés kerül a dinamikus CoG-ba / RC-be  !!! ÁLLÍTSD BE
P.a_lat_g    = 5;
P.K_Tire     = 1700 * P.valtoszam;    % [N/m]

% Az ARB roll-merevségének átszámítása.
% true : K_ARB/MR^2 * T^2/4  (baszogep.m 226-229. sor, statikus becslés)
% false: K_ARB/MR^2          (baszogep.m 284. és 306. sor, a ciklusban - T^2/4 nélkül)
P.ARB_ROLL_T2_4 = true;

% Damper mátrix [N s/m] (damper oldalon): sorok LSR, LSC, HSR, HSC; oszlopok click 1..6
% P.C = [
%     80000, 74500, 69000, 63500, 58000, 52500, 47000, 41500, 36000, 30500, 25000, 20000;
%     60000, 55800, 51600, 47400, 43200, 39000, 34800, 30600, 26400, 22200, 18000, 14000;
%     8000, 7420, 6840, 6260, 5680, 5100, 4520, 3940, 3360, 2780, 2200, 1600;
%     6000, 5590, 5180, 4770, 4360, 3950, 3540, 3130, 2720, 2310, 1900, 1500
% ];
P.C = [
    51081.6, 9940.1, 3916, 1962.9, 1129.1, 601.9;    % Low Speed Rebound (LSR)
    61889.8, 11165.6, 5319.1, 2375.7, 960.1, 944.1;  % Low Speed Compression (LSC)
    2040.3, 1402.4, 1457.8, 1212.2, 569.6, 386.4;    % High Speed Rebound (HSR)
    2253.6, 1929.4, 1659.3, 1029.9, 621.4, 445.1     % High Speed Compression (HSC)
    ];

P.regime_short = {'LSR', 'LSC', 'HSR', 'HSC'};

% származtatott mennyiségek
P.a_lat        = P.a_lat_g * P.g;
P.b            = P.L * P.distrF;
% (a roll tengely geometriája, a geometriai terhelésátadás és a jacking az RC magasságoktól függ,
%  ezért kiértékelésenként számoljuk: rc_geometry() és model_mech())
P.m1_F = P.m_SM * P.distrF / 2;              % sarki rugózott tömeg
P.m1_R = P.m_SM * (1 - P.distrF) / 2;
P.m2_F = P.m_NSM_F;
P.m2_R = P.m_NSM_R;
P.dFz_NSM_F  = (2 * P.m_NSM_F * P.a_lat * P.h_CG_NSM) / P.T_F;
P.dFz_NSM_R  = (2 * P.m_NSM_R * P.a_lat * P.h_CG_NSM) / P.T_R;
P.F_down_ax_F = 0.5 * P.rho_air * P.CLA * (P.v_max_kmh / 3.6)^2 * P.aero_distr_F;   % [N] első tengely
P.F_down_ax_R = 0.5 * P.rho_air * P.CLA * (P.v_max_kmh / 3.6)^2 * (1 - P.aero_distr_F);
P.F_down_cor_F = 0.5 * P.rho_air * P.CLA * (P.v_corner_kmh / 3.6)^2 * P.aero_distr_F;   % [N] első tengely kanyarsebességen
P.F_down_cor_R = 0.5 * P.rho_air * P.CLA * (P.v_corner_kmh / 3.6)^2 * (1 - P.aero_distr_F);
P.fzopt = optimset('Display', 'off', 'TolX', 1e-12);

%% 2. OPTIMALIZÁLÁSI BEÁLLÍTÁSOK
O = struct();

% --- Elfogadott tartományok az egyensúlyi (a_lat = 2 G) állapotban -------
O.PHI_RANGE_DEG = [0.50 1.0];   % [deg]  !!! ÁLLÍTSD BE - egyensúlyi dőlésszög (első tengely, mint baszogep phi_eq_deg)
O.TLTD_RANGE    = [30 40];       % [%]    !!! ÁLLÍTSD BE - TLTD (első arány)
O.MN_RANGE      = [45 55];       % [%]    !!! ÁLLÍTSD BE - Magic Number (K_roll_F / K_roll_tot)

% --- Statikus ride frekvencia cél -----------------------------------------
O.F_RIDE_RANGE_F = [5.8 6.1];    % [Hz] első ride frekvencia megengedett tartománya (kemény korlát)  !!! ÁLLÍTSD BE
O.F_RIDE_RANGE_R = [6.2 6.7];    % [Hz] hátsó ride frekvencia megengedett tartománya (kemény korlát)  !!! ÁLLÍTSD BE
% Lágy húzás a tartományon BELÜL: a tartomány közepe felé (W_F = 0 -> a tartományon belül a frekvencia szabad,
% a többi tag dönt: jacking, damper, aero; nagy W_F -> a tartomány közepére szorítja). A lágy cél a W_F sor alatt (O.F_RIDE_TARGET) kézzel is felülírható.

% --- Cél damping ratio statikusan (x = 0) ---------------------------------
% sorok: LSR LSC HSR HSC | oszlopok: első, hátsó      !!! ÁLLÍTSD BE (most a baszogep.m értékei)
O.XI_TARGET = [0.70 0.70;
               0.70 0.70;
               0.40 0.40;
               0.40 0.40];

% --- Hasmagasság -----------------------------------------------------------
O.H_MIN_MM = 5;                % [mm] minimális hasmagasság a teljes sebességtartományban (0 helyett kis tartalék)
O.AERO_WITHIN_TRAVEL = true;     % true: az aero berugózás se haladja meg a berugózási tartományt (MR polinom érvényessége)

% --- Kerékút és damper -----------------------------------------------------
O.TRAVEL_TOTAL_MM  = 30;         % [mm] kerék összmozgás 50 mm a szabály
O.TRAVEL_BUMP_MM   = 15;         % [mm] berugózás (a maradék = kirugózás) 25 mm a szabály
O.TRAVEL_REB_MM    = O.TRAVEL_TOTAL_MM - O.TRAVEL_BUMP_MM;
O.DAMPER_STROKE_MM = 40;         % [mm] damper löket, 57 mm csak átverjük
O.DAMPER_LMAX_MM   = 400;        % [mm] damper hossza teljesen kihúzva

% --- Rugólista és diszkrét opciók -----------------------------------------
O.SPRING_LIST_F = [500 600 700 800 900 1000 1100 1200];   % [lbs/in] !!! ÁLLÍTSD BE a ténylegesen rendelkezésre álló rugókra
O.SPRING_LIST_R = O.SPRING_LIST_F;
O.STAB_MODES_F  = [0];       % 0 = nincs, 1 = roll (ARB), 2 = heave stabilizátor
O.STAB_MODES_R  = [0];       % (egy tengelyen vagy roll vagy heave, a kettő együtt nem szerepel)
% O.MR_ORDER_LIST = [1 2];         % motion ratio polinom foka
O.MR_ORDER_LIST = [1];

% --- Változók határai --------------------------------------------------------
% MR(x) = m0 + m1*x + m2*x^2,  x [mm] (+ = berugózás)
O.MR_M0_SPRING = [0.30 1.50];
O.MR_M0_ARB    = [1.00 3.0];
O.MR_M1_RANGE  = [-0.6112 0.6112];      % [1/mm]
O.MR_M2_RANGE  = [-4e-2  4e-2];       % [1/mm^2]
O.MR_MIN = 0.30;                      % MR a teljes kerékúton ebben a sávban maradjon
O.MR_MAX = 3.60;
O.K_ARB_MAX   = 200000;                % [N/m] droplinkre vett ARB merevség felső határa
O.K_HEAVE_MAX = 200000;                % [N/m] droplinkre vett heave stab. merevség felső határa
O.K_MIN_FRAC  = 0.005;                % ennél kisebb stabilizátor merevség = "nincs stabilizátor"

% --- Célfüggvény súlyok ------------------------------------------------------
% J = W_F*(ride freq relatív hiba^2) + Σ_tengely átlag_rezsim[ W_XI*(xi relatív hiba)^2 + W_ARMS*(A_RMS többlet) ]
O.W_F    = 1;                  % v4: 200 -> 20, hogy a ride tartomány valóban szabadságot adjon (200 = gyakorlatilag a tartomány közepére szorít)
O.F_RIDE_TARGET = [mean(O.F_RIDE_RANGE_F) mean(O.F_RIDE_RANGE_R)];   % [Hz] [első hátsó] lágy cél, alapból a tartományok közepe
O.W_XI   = 10;
O.W_ARMS = 2;
% --- ROLL FREKVENCIA (v7): minél magasabb legyen ---------------------------------------------------------------------
% J_froll = W_FROLL * (max(0, F_ROLL_REF - f_roll) / F_ROLL_REF)^2   (W_FROLL = 0 -> kikapcsolva)
% Monoton húzás felfelé: a F_ROLL_REF egy MAGAS plafon, amit a solver nem feltétlenül ér el. Mivel f_roll ~ 1/sqrt(phi),
% a gyakorlati felső határt a PHI_RANGE_DEG alsó értéke adja: f_roll,max ~ 10.5 Hz * sqrt(0.88 / phi_min)  (phi_min = 0.5 -> ~14 Hz).
O.W_FROLL     = 10;
O.F_ROLL_REF  = 16;             % [Hz]  !!! ÁLLÍTSD BE - ennél kisebb roll frekvencia büntetett; ha a phi alsó határát lejjebb viszed, ezt is emeld
% O.ARMS_POS_MM = [-20 -10 0 10 20];    % [mm] kerékút-pozíciók, ahol az A_RMS többletet értékeljük
O.ARMS_POS_MM = [-15 0 15];

% --- ROLL CENTER (RC) OPTIMALIZÁLÁS, JACKING ÉS REAKTIVITÁS ---------------------
O.OPT_RC     = true;             % true: h_RC_F és h_RC_R is optimalizálási változó; false: P.h_RC_F / P.h_RC_R fix
O.RC_RANGE_F = [0.1 0.110];    % [m]  !!! ÁLLÍTSD BE - a kinematikával ténylegesen megvalósítható első RC magasság
O.RC_RANGE_R = [0.120 0.130];    % [m]  !!! ÁLLÍTSD BE - hátsó RC magasság

% Jacking: a_lat mellett a kasztni emelkedése dh_jack = (F_jack_F + F_jack_R) / K_ride_össz.
% A K_ride_össz-ben a heave stabilizátor (Z-bar) is benne van, ezért a heave merevítés csökkenti a jacking-et
% (a ride frekvencia cél és a hasmagasság-korlát viszont fékezi a túlzott merevítést).
% J_jack = W_JACK * (dh_jack[mm] / JACK_REF_MM)^2        (W_JACK = 0 -> a jacking nincs a célfüggvényben)
% HANGOLÁS (v3): a jacking ~ (h_RC_F + h_RC_R) / K_ride, a geometriai átadás is ~ (h_RC_F + h_RC_R),
% ezért a két tag egymás ellen húz: a W_JACK / W_GEO arány dönti el, hol lesz az RC összeg.
% Egyensúlyi RC-összeg (becslés, 4,2 Hz ride): s ≈ 0.1313*W_GEO / (7.26e-4*W_JACK + 5.96e-4*W_GEO) [mm]
% (JACK_REF = 2 mm, GEO_REF = 10 %, GEO_TARGET = 40 % mellett). W_JACK=0.5, W_GEO=1 -> s ≈ 137 mm.
O.W_JACK      = 5;
O.JACK_REF_MM = 10;               % [mm]  ennyi jacking mellett J_jack = W_JACK
O.JACK_MAX_MM = 10;             % [mm]  kemény felső korlát a jacking-re (Inf = nincs)

% Reaktivitás = a kormányzás és a terhelésátadás közti fáziskésés (phase lag) szlalom frekvencián.
% A keresztirányú terhelésátadás átviteli függvénye:
%     H(f) = g + (1 - g) / (1 - r^2 + 2j*zeta*r)
%   g    = geometriai (azonnali) hányad: RC-n átadódó + nem rugózott tömeg része az összes terhelésátadásból
%   r    = f_szlalom / f_roll,   zeta = a roll-mód csillapítási tényezője (a kis sebességű, LS csillapításból)
% fáziskésés = -arg(H).   J_react = W_REACT * (késés[deg] / LAG_REF_DEG)^2   (W_REACT = 0 -> nincs a célfüggvényben)
% A célfüggvényben / korlátban a zeta a CÉL-xi (O.XI_TARGET LSR,LSC átlaga) alapján számolódik, hogy a
% célfüggvény sima maradjon; az Excelben a ténylegesen kiválasztott click-ekkel számolt érték is szerepel.
% FIGYELEM (v3): a fáziskésés szinte NEM függ az RC-től (a roll mód ~11 Hz, a szlalom ~0,8 Hz, a késést
% a csillapítás adja; az RC teljes tartományán csak ~1° a változás), ezért a W_REACT*(lag/ref)^2 tag
% gyakorlatilag nem hat az RC-re. A reaktivitás RC-függő része a geometriai (azonnali) átadási hányad,
% ezért az RC-t ez a lágy tag húzza felfelé (a W_JACK ellenében):
%     J_geo = W_GEO * (max(0, GEO_TARGET - GEO_SHARE) / GEO_REF)^2
O.W_REACT          = 0.2;
O.LAG_REF_DEG      = 30;          % [deg] ennyi késés mellett J_react = W_REACT
O.W_GEO            = 1;         % a geometriai átadás hiányának súlya (0 = nincs)
O.GEO_TARGET       = 40;          % [%]   lágy cél: efölött nincs büntetés
O.GEO_REF          = 10;          % [%]   ennyi hiány mellett J_geo = W_GEO
% v4: a célfüggvény az RC-nek csak az ÖSSZEGÉT (hF+hR) látta (jacking, geo%, dz), a megosztását (hF vs hR) nem -> lapos irány,
% az sqp a tartomány szélére sodorta az egyiket (30/66,5 és 66,5/30 gyakorlatilag azonos J-vel). A megosztást a TLTD dönti el:
%     J_tltd = W_TLTD * ((TLTD - TLTD_TARGET) / TLTD_REF)^2     (W_TLTD = 0 -> kikapcsolva)
O.W_TLTD          = 0.5;
O.TLTD_TARGET     = 31;          % [%]   !!! ÁLLÍTSD BE - kívánt TLTD (első arány); a tartományon (O.TLTD_RANGE) belül marad
O.TLTD_REF        = 2;           % [%]   ennyi eltérésnél J_tltd = W_TLTD
O.SLALOM_V_KMH     = 100;         % [km/h] !!! ÁLLÍTSD BE - szlalom sebesség
O.SLALOM_SPACING_M = 8;          % [m]    !!! ÁLLÍTSD BE - bóják távolsága
O.F_SLALOM_HZ      = (O.SLALOM_V_KMH / 3.6) / (2 * O.SLALOM_SPACING_M);   % [Hz] irányváltási frekvencia
O.LAG_MAX_DEG      = 20;        % [deg] kemény felső korlát a fáziskésésre (Inf = nincs)
% v3: a régi 40 % kemény minimum (ELŐZŐ ÉRTÉK) csak hF+hR >= ~215 mm mellett teljesül, de a megengedett
% RC-tartomány maximuma 90+120 = 210 mm -> a korlát sosem teljesülhetett, az sqp mindig a plafonra tolta az RC-t.
% Most csak biztonsági háló (a lágy cél a GEO_TARGET / W_GEO); ~20 % <-> hF+hR >= ~105 mm.
O.GEO_SHARE_MIN    = 20;         % [%]   a geometriai (azonnali) terhelésátadás kemény minimuma (az alapeset kb. 46 %)
O.ROLL_GRAD_MAX_DEG_G = 0.7;     % [deg/g] max. dőlésgradiens (első tengely; Inf = nincs)
O.RUN_TAG = '';                  % opcionális szöveg a futás-mappa nevének végére

% --- Numerika ----------------------------------------------------------------
O.F_VEC   = linspace(0, 50, 120);     % [Hz] A_RMS frekvenciarács az optimalizálás alatt (gyors)
O.XI_GRID = linspace(0.1, 1.5, 40);   % xi-rács az A_RMS optimumhoz
O.N_STARTS = 2;                       % kezdőpontok száma esetenként
O.FEAS_TOL = 1e-3;                    % megengedett (skálázott) korlátsértés
O.N_KEEP   = 30;                      % ennyi megoldás kerül az Excelbe
O.N_MR_FILES = 3;                     % ennyi legjobb megoldáshoz készül baszogep-kompatibilis MR-fájl
O.PARFOR_WORKERS = 64;                % 0 = soros futás; >0 = párhuzamos (ha van Parallel Computing Toolbox)
O.OUT_DIR = 'Optimalizalo_Eredmenyek';

%% 2B. FUTÁS-MAPPA (minden futtatás saját mappát kap)
stamp = datestr(now, 'yyyymmdd_HHMMSS');
if O.OPT_RC
    rcTag = 'RCopt';
else
    rcTag = sprintf('RCfix_F%03.0f_R%03.0f', 1000 * P.h_RC_F, 1000 * P.h_RC_R);
end
runName = sprintf('Futas_%s_%s', stamp, rcTag);
if ~isempty(O.RUN_TAG), runName = [runName '_' O.RUN_TAG]; end
runDir = fullfile(O.OUT_DIR, runName);
if ~exist(runDir, 'dir'), mkdir(runDir); end
diary(fullfile(runDir, 'konzol_log.txt'));
try
    save(fullfile(runDir, 'beallitasok.mat'), 'P', 'O');
    copyfile([mfilename('fullpath') '.m'], runDir);      % a futtatott script másolata (reprodukálhatóság)
catch
    warning('A beállítások / a script másolatának mentése a futás-mappába nem sikerült.');
end
fprintf('Futás-mappa: %s\n', runDir);
if O.OPT_RC
    fprintf('RC mód: optimalizált (első %.0f...%.0f mm, hátsó %.0f...%.0f mm)\n', 1000 * O.RC_RANGE_F, 1000 * O.RC_RANGE_R);
else
    fprintf('RC mód: fix (első %.1f mm, hátsó %.1f mm)\n', 1000 * P.h_RC_F, 1000 * P.h_RC_R);
end

%% 3. ÖNELLENŐRZÉS: a baszogep.m alapeset (175/175 lbs/in, konstans MR, ARB nélkül)
p_base = [0.82 0 0,  0.85 0 0,  0.85 0 0,  0.80 0 0,  0 0 0 0,  P.h_RC_F P.h_RC_R];
M0 = model_mech(p_base, 175, 175, P);
fprintf('Önellenőrzés (baszogep.m alapeset): phi_F = %.3f deg | phi_R = %.3f deg | MN = %.2f %% | TLTD = %.2f %% | f_ride = %.2f / %.2f Hz\n', ...
    M0.phiF_deg, M0.phiR_deg, M0.MN, M0.TLTD, M0.fF, M0.fR);
fprintf('                                    RC = %.1f / %.1f mm | jacking = %.2f mm (F_jack %.0f / %.0f N) | geometriai átadás = %.1f %% | dőlésgradiens = %.3f deg/g | f_roll = %.2f Hz\n\n', ...
    1000 * M0.hRC_F, 1000 * M0.hRC_R, 1000 * M0.dh_jack, M0.F_jack_F, M0.F_jack_R, M0.GEO_SHARE, M0.roll_grad, M0.f_roll);

%% 4. ESETEK FELSOROLÁSA ÉS OPTIMALIZÁLÁS
cases = struct('kF', {}, 'kR', {}, 'modeF', {}, 'modeR', {}, 'order', {});
for ord_ = O.MR_ORDER_LIST
    for mF = O.STAB_MODES_F
        for mR = O.STAB_MODES_R
            for kF = O.SPRING_LIST_F
                for kR = O.SPRING_LIST_R
                    cases(end+1) = struct('kF', kF, 'kR', kR, 'modeF', mF, 'modeR', mR, 'order', ord_); %#ok<SAGROW>
                end
            end
        end
    end
end
nC = numel(cases);
fprintf('Optimalizálandó esetek száma: %d (x %d kezdőpont)\n', nC, O.N_STARTS);

results = cell(nC, 1);
nW = O.PARFOR_WORKERS;
parfor (ic = 1:nC, nW)
    results{ic} = run_case(cases(ic), P, O, ic);
end
R = [results{:}];
if isempty(R)
    error('Egyetlen esetre sem sikerült optimalizálni - ellenőrizd az Optimization Toolbox meglétét és a beállításokat.');
end
fprintf('Optimalizálás kész (%.1f s).\n', toc(t_all));

%% 5. VÁLOGATÁS, DEDUPLIKÁLÁS, PONTOS (finom rácsú) ÚJRAÉRTÉKELÉS
% "nincs stabilizátor"-ra átcímkézés, ha a merevség gyakorlatilag nulla
for k = 1:numel(R)
    p = R(k).p; cs = R(k).cs;
    if cs.modeF == 1 && p(13) < O.K_MIN_FRAC * O.K_ARB_MAX,   p(13) = 0; cs.modeF = 0; end
    if cs.modeF == 2 && p(15) < O.K_MIN_FRAC * O.K_HEAVE_MAX, p(15) = 0; cs.modeF = 0; end
    if cs.modeR == 1 && p(14) < O.K_MIN_FRAC * O.K_ARB_MAX,   p(14) = 0; cs.modeR = 0; end
    if cs.modeR == 2 && p(16) < O.K_MIN_FRAC * O.K_HEAVE_MAX, p(16) = 0; cs.modeR = 0; end
    R(k).p = p; R(k).cs = cs;
end

feas = [R.maxviol] <= O.FEAS_TOL;
key  = [R.J] + 1e3 * max(0, [R.maxviol]);
[~, ix] = sortrows([double(~feas(:)), key(:)]);
R = R(ix);
if ~any(feas)
    warning('Egyetlen megoldás sem teljesíti az összes korlátot - a legkevésbé sértő megoldások kerülnek kiírásra (Megfelel = NEM). Lazítsd a tartományokat / bővítsd a rugólistát.');
end

keys = cell(numel(R), 1);
for k = 1:numel(R)
    keys{k} = sprintf('%d|%d|%d|%g|%g', R(k).cs.order, R(k).cs.modeF, R(k).cs.modeR, R(k).cs.kF, R(k).cs.kR);
end
[~, ia] = unique(keys, 'stable');
R = R(ia);
R = R(1:min(O.N_KEEP, numel(R)));

Of = O;                                   % finomabb rács a végső értékeléshez
Of.F_VEC   = linspace(0, 50, 500);
Of.XI_GRID = linspace(0.1, 1.5, 80);

sol = struct('p', {}, 'cs', {}, 'E', {}, 'feas', {}, 'key', {});
for k = 1:numel(R)
    E = evaluate(R(k).p, R(k).cs, P, Of);
    sol(k).p = R(k).p; sol(k).cs = R(k).cs; sol(k).E = E;
    sol(k).feas = E.maxviol <= O.FEAS_TOL;
    sol(k).key = E.J + 1e3 * max(0, E.maxviol) + 1e6 * ~sol(k).feas;
end
[~, ix] = sort([sol.key]);
sol = sol(ix);

%% 6. KIÍRÁS A KONZOLRA
modeName = {'nincs', 'roll', 'heave'};
fprintf('\n=========================================================================\n');
fprintf('  LEGJOBB MEGOLDÁSOK (J = célfüggvény, kisebb a jobb)\n');
fprintf('=========================================================================\n');
fprintf('%-3s %-7s %-4s %-5s %-5s %-12s | %-6s %-6s %-6s | %-9s | %-11s | %-6s %-5s %-5s | %-8s | %s\n', ...
    '#', 'J', 'fok', 'rugF', 'rugR', 'stab (F-R)', 'phi[°]', 'TLTD', 'MN', 'f_ride F/R', 'RC F/R [mm]', 'jack', 'geo%', 'lag°', 'Megfelel', 'click F | click R');
for k = 1:min(10, numel(sol))
    s = sol(k); E = s.E;
    fprintf('%-3d %-7.4f %-4d %-5g %-5g %-12s | %-6.3f %-6.1f %-6.1f | %4.2f/%4.2f | %5.1f/%5.1f | %-6.2f %-5.1f %-5.1f | %-8s | [%s] | [%s]\n', ...
        k, E.J, s.cs.order, s.cs.kF, s.cs.kR, [modeName{s.cs.modeF+1} '-' modeName{s.cs.modeR+1}], ...
        E.M.phiF_deg, E.M.TLTD, E.M.MN, E.M.fF, E.M.fR, ...
        1000 * s.p(17), 1000 * s.p(18), 1000 * E.M.dh_jack, E.M.GEO_SHARE, E.Rd.lag_deg, ...
        ternary(s.feas, 'igen', 'NEM'), num2str(E.DF.click), num2str(E.DR.click));
end
fprintf('\nJ felbontás (melyik tag viszi a célfüggvényt):\n');
fprintf('%-3s %-8s | %-8s %-8s %-8s %-8s %-8s %-8s %-8s | %-8s\n', '#', 'J', 'ride', 'damper', 'jacking', 'geo', 'react', 'TLTD', 'froll', 'f_roll[Hz]');
for k = 1:min(5, numel(sol))
    E = sol(k).E;
    fprintf('%-3d %-8.3f | %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f %-8.3f | %-8.2f\n', k, E.J, E.J_ride, E.J_dmp, E.J_jack, E.J_geo, E.J_react, E.J_tltd, E.J_froll, E.M.f_roll);
end
s = sol(1);
fprintf('\nA legjobb megoldás roll center magasságai (%s): első = %.1f mm, hátsó = %.1f mm  (alap: %.1f / %.1f mm)\n', ...
    ternary(O.OPT_RC, 'optimalizált', 'fix'), 1000 * s.p(17), 1000 * s.p(18), 1000 * P.h_RC_F, 1000 * P.h_RC_R);
fprintf('Dinamikus RC (%.0f km/h, DYN_HEIGHT = %s): első = %.1f mm, hátsó = %.1f mm | CoG elmozdulás = %+.1f mm (aero berugózás: %.1f / %.1f mm)\n', ...
    P.v_corner_kmh, mat2str(logical(P.DYN_HEIGHT)), 1000 * s.E.M.hRC_F_dyn, 1000 * s.E.M.hRC_R_dyn, 1000 * s.E.M.dz_CG, 1000 * s.E.M.xaero_cor_F, 1000 * s.E.M.xaero_cor_R);
if O.OPT_RC
    % diagnosztika (v3): hány a top-10 megoldásból fut az RC-tartomány szélére (<= 2 % a határtól)?
    nTop = min(10, numel(sol)); nUp = 0; nLo = 0;
    for k = 1:nTop
        zF = (sol(k).p(17) - O.RC_RANGE_F(1)) / diff(O.RC_RANGE_F);
        zR = (sol(k).p(18) - O.RC_RANGE_R(1)) / diff(O.RC_RANGE_R);
        nUp = nUp + (zF > 0.98) + (zR > 0.98);
        nLo = nLo + (zF < 0.02) + (zR < 0.02);
    end
    if nUp + nLo > 0
        warning(['A top-%d megoldás RC-értékeiből %d a felső, %d az alsó határra fut. ' ...
            'Ellenőrizd a GEO_SHARE_MIN / JACK_MAX korlátokat és a W_JACK : W_GEO arányt, vagy tágítsd az RC tartományt.'], nTop, nUp, nLo);
    end
end
% aktív korlátok a legjobb megoldásnál (v4): melyik korlát tartja a megoldást a határon?
cNames = {'phi_min','phi_max','TLTD_min','TLTD_max','MN_min','MN_max','aero_F','aero_R', ...
    'MRmin_F','MRmin_R','MRmin_ARB_F','MRmin_ARB_R','MRmax_F','MRmax_R','MRmax_ARB_F','MRmax_ARB_R', ...
    'loket_F','loket_R','dolesgradiens_max','geo_min','jacking_max','lag_max', ...
    'fride_F_min','fride_F_max','fride_R_min','fride_R_max'};
cb = sol(1).E.c(:);
if numel(cb) == numel(cNames)
    actIdx = find(cb > -0.01);
    if isempty(actIdx)
        fprintf('Aktív korlát a legjobb megoldásnál: nincs (az optimum belső pont).\n');
    else
        fprintf('Aktív korlátok a legjobb megoldásnál: %s\n', strjoin(cNames(actIdx), ', '));
    end
end
fprintf('A legjobb megoldás motion ratio függvényei (x = kerékút [mm], + = berugózás):\n');
fprintf('  %s\n', mr_text(s.p(1:3),   'MR_F',     true));
fprintf('  %s\n', mr_text(s.p(4:6),   'MR_R',     true));
fprintf('  %s\n', mr_text(s.p(7:9),   'MR_ARB_F', s.cs.modeF > 0));
fprintf('  %s\n', mr_text(s.p(10:12), 'MR_ARB_R', s.cs.modeR > 0));

%% 7. KIMENETEK (minden a futás-mappába: runDir)
Xs = cell(numel(sol), 1);                 % kiegészítő mennyiségek megoldásonként
for k = 1:numel(sol)
    Xs{k} = solution_extras(sol(k).p, sol(k).cs, P, O);
end
xlsx_file = fullfile(runDir, sprintf('Optimalis_beallitasok_%s.xlsx', stamp));

hdr = {'Rang', 'J', 'Megfelel', 'MR fok', 'Első rugó [lbs/in]', 'Hátsó rugó [lbs/in]', 'Első stab.', 'Hátsó stab.', ...
    'RC első [mm]', 'RC hátsó [mm]', ...
    'K_ARB első [N/m]', 'K_ARB hátsó [N/m]', 'K_HEAVE első [N/m]', 'K_HEAVE hátsó [N/m]', ...
    'Első LSR click', 'Első LSC click', 'Első HSR click', 'Első HSC click', ...
    'Hátsó LSR click', 'Hátsó LSC click', 'Hátsó HSR click', 'Hátsó HSC click', ...
    'Egyensúlyi dőlés első [deg]', 'Egyensúlyi dőlés hátsó [deg]', 'TLTD [%]', 'MN [%]', 'MD (váz torzióval) [%]', ...
    'Ride freq első [Hz]', 'Ride freq hátsó [Hz]', 'Roll freq [Hz]', ...
    'xi első LSR', 'xi első LSC', 'xi első HSR', 'xi első HSC', 'xi hátsó LSR', 'xi hátsó LSC', 'xi hátsó HSR', 'xi hátsó HSC', ...
    'A_RMS hiba első [%]', 'A_RMS hiba hátsó [%]', ...
    'Min. hasmagasság első [mm]', 'Min. hasmagasság hátsó [mm]', 'Aero berugózás első [mm]', 'Aero berugózás hátsó [mm]', ...
    'Damper út első [mm]', 'Damper út hátsó [mm]', 'Löket tartalék első [mm]', 'Löket tartalék hátsó [mm]', ...
    'Stat. damperhossz első [mm]*', 'Stat. damperhossz hátsó [mm]*', ...
    'MR_F(x) [x: mm]', 'MR_R(x) [x: mm]', 'MR_ARB_F(x) [x: mm]', 'MR_ARB_R(x) [x: mm]', ...
    'MR_F m0', 'MR_F m1', 'MR_F m2', 'MR_R m0', 'MR_R m1', 'MR_R m2', ...
    'MR_ARB_F m0', 'MR_ARB_F m1', 'MR_ARB_F m2', 'MR_ARB_R m0', 'MR_ARB_R m1', 'MR_ARB_R m2', ...
    'Jacking [mm]', 'Jacking az alap-RC-vel [mm]', 'F_jack első [N]', 'F_jack hátsó [N]', ...
    'Dőlésgradiens [deg/g]', 'Geometriai ter.átadás [%]', 'Roll zeta (cél-xi)', 'Roll zeta (tényleges click)', ...
    'Fáziskésés szlalom f-en, cél-xi [deg]', 'Fáziskésés szlalom f-en, tényleges click [deg]', ...
    'Terhelésátadás amplitúdó szlalom f-en [-]', 'Roll tengely dőlése [deg]', ...
    'J ride', 'J damper', 'J jacking', 'J geo', 'J react', 'J TLTD', 'J froll'};
out = cell(numel(sol) + 1, numel(hdr));
out(1, :) = hdr;
for k = 1:numel(sol)
    s = sol(k); E = s.E; p = s.p; cs = s.cs; X = Xs{k};
    out(k+1, :) = [{k, E.J, ternary(s.feas, 'igen', 'NEM'), cs.order, cs.kF, cs.kR, modeName{cs.modeF+1}, modeName{cs.modeR+1}, ...
        1000 * p(17), 1000 * p(18), p(13), p(14), p(15), p(16)}, num2cell(E.DF.click), num2cell(E.DR.click), ...
        {E.M.phiF_deg, E.M.phiR_deg, E.M.TLTD, E.M.MN, E.M.MD, E.M.fF, E.M.fR, E.M.f_roll}, ...
        num2cell(E.DF.xi), num2cell(E.DR.xi), ...
        {E.DF.arms_pen_mean, E.DR.arms_pen_mean, X.h_min_F, X.h_min_R, X.xaero_F, X.xaero_R, ...
         X.S_F, X.S_R, O.DAMPER_STROKE_MM - X.S_F, O.DAMPER_STROKE_MM - X.S_R, X.L_stat_F, X.L_stat_R, ...
         mr_text(p(1:3), 'MR_F', true), mr_text(p(4:6), 'MR_R', true), ...
         mr_text(p(7:9), 'MR_ARB_F', cs.modeF > 0), mr_text(p(10:12), 'MR_ARB_R', cs.modeR > 0)}, ...
        num2cell(p(1:12)), ...
        {1000 * E.M.dh_jack, X.dh_jack_base_mm, E.M.F_jack_F, E.M.F_jack_R, ...
         E.M.roll_grad, E.M.GEO_SHARE, E.Rdt.zeta, E.Rd.zeta, E.Rdt.lag_deg, E.Rd.lag_deg, E.Rdt.amp, X.RA_incl_deg, ...
         E.J_ride, E.J_dmp, E.J_jack, E.J_geo, E.J_react, E.J_tltd, E.J_froll}];
end
writecell(out, xlsx_file, 'Sheet', 'Optimalis_beallitasok');

% --- Roll center lap: a futás RC-i megoldásonként ---
rcHdr = {'Rang', 'RC mód', 'RC első [mm]', 'RC hátsó [mm]', 'Alap RC első [mm]', 'Alap RC hátsó [mm]', 'Roll tengely dőlése [deg]', ...
    'Jacking [mm]', 'Jacking az alap-RC-vel [mm]', 'Geometriai ter.átadás [%]', 'Fáziskésés szlalom f-en [deg]', ...
    'Dinamikus RC első [mm]', 'Dinamikus RC hátsó [mm]', 'CoG elmozdulás (jacking-aero) [mm]'};
rcOut = cell(numel(sol) + 1, numel(rcHdr));
rcOut(1, :) = rcHdr;
for k = 1:numel(sol)
    s = sol(k); E = s.E; X = Xs{k};
    rcOut(k+1, :) = {k, ternary(O.OPT_RC, 'optimalizált', 'fix'), 1000 * s.p(17), 1000 * s.p(18), ...
        1000 * P.h_RC_F, 1000 * P.h_RC_R, X.RA_incl_deg, 1000 * E.M.dh_jack, X.dh_jack_base_mm, E.M.GEO_SHARE, E.Rd.lag_deg, ...
        1000 * E.M.hRC_F_dyn, 1000 * E.M.hRC_R_dyn, 1000 * E.M.dz_CG};
end
writecell(rcOut, xlsx_file, 'Sheet', 'Roll_center');

% --- Strukturális átadási lap: ARB / Z-bar motion ratio + droplinken mérhető célmerevség ---
stOut = [];
for k = 1:numel(sol)
    [st_hdr, st_rows] = handover_table(k, sol(k).p, sol(k).cs, P, O);
    if isempty(stOut), stOut = st_hdr; end
    stOut = [stOut; st_rows]; %#ok<AGROW>
end
writecell(stOut, xlsx_file, 'Sheet', 'Strukturalis_atadas');

% --- Bemenetek lap ---
inp = {
    'Egyensúlyi dőlésszög tartomány [deg]', sprintf('%.3f ... %.3f', O.PHI_RANGE_DEG);
    'TLTD tartomány [%]',                   sprintf('%.2f ... %.2f', O.TLTD_RANGE);
    'MN tartomány [%]',                     sprintf('%.2f ... %.2f', O.MN_RANGE);
    'Ride freq tartomány első [Hz]',        sprintf('%.2f ... %.2f', O.F_RIDE_RANGE_F);
    'Ride freq tartomány hátsó [Hz]',       sprintf('%.2f ... %.2f', O.F_RIDE_RANGE_R);
    'Ride freq lágy cél első / hátsó [Hz]', sprintf('%.2f / %.2f (W_F = %g)', O.F_RIDE_TARGET, O.W_F);
    'Cél xi első [LSR LSC HSR HSC]',        sprintf('%.2f ', O.XI_TARGET(:, 1));
    'Cél xi hátsó [LSR LSC HSR HSC]',       sprintf('%.2f ', O.XI_TARGET(:, 2));
    'Min. hasmagasság [mm]',                O.H_MIN_MM;
    'Kerékút összesen / berugózás [mm]',    sprintf('%g / %g', O.TRAVEL_TOTAL_MM, O.TRAVEL_BUMP_MM);
    'Damper löket / max hossz [mm]',        sprintf('%g / %g', O.DAMPER_STROKE_MM, O.DAMPER_LMAX_MM);
    'Rugólista első [lbs/in]',              sprintf('%g ', O.SPRING_LIST_F);
    'Rugólista hátsó [lbs/in]',             sprintf('%g ', O.SPRING_LIST_R);
    'Súlyok W_F / W_XI / W_ARMS',           sprintf('%g / %g / %g', O.W_F, O.W_XI, O.W_ARMS);
    'A_RMS értékelési pozíciók [mm]',       sprintf('%g ', O.ARMS_POS_MM);
    'ARB roll-merevség T^2/4 szorzóval',    ternary(P.ARB_ROLL_T2_4, 'igen', 'nem');
    'RC optimalizálás',                     ternary(O.OPT_RC, 'igen', 'nem (fix RC)');
    'RC tartomány első / hátsó [mm]',       sprintf('%.0f ... %.0f / %.0f ... %.0f', 1000 * O.RC_RANGE_F, 1000 * O.RC_RANGE_R);
    'Alap RC első / hátsó [mm]',            sprintf('%.1f / %.1f', 1000 * P.h_RC_F, 1000 * P.h_RC_R);
    'Dinamikus CoG/RC: be / k_RC F-R / v_kanyar [km/h]', sprintf('%s / %.2f - %.2f / %g', mat2str(logical(P.DYN_HEIGHT)), P.k_RC_F, P.k_RC_R, P.v_corner_kmh);
    'Jacking: súly / ref [mm] / max [mm]',  sprintf('%g / %g / %g', O.W_JACK, O.JACK_REF_MM, O.JACK_MAX_MM);
    'Reaktivitás: súly / ref [deg] / max késés [deg]', sprintf('%g / %g / %g', O.W_REACT, O.LAG_REF_DEG, O.LAG_MAX_DEG);
    'Geometriai átadás lágy tag: súly / cél [%] / ref [%]', sprintf('%g / %g / %g', O.W_GEO, O.GEO_TARGET, O.GEO_REF);
    'Roll frekvencia lágy tag: súly / ref [Hz]', sprintf('%g / %g', O.W_FROLL, O.F_ROLL_REF);
    'TLTD lágy tag: súly / cél [%] / ref [%]', sprintf('%g / %g / %g', O.W_TLTD, O.TLTD_TARGET, O.TLTD_REF);
    'Szlalom frekvencia [Hz]',              sprintf('%.3f (%.0f km/h, %.1f m bójatáv)', O.F_SLALOM_HZ, O.SLALOM_V_KMH, O.SLALOM_SPACING_M);
    'Geometriai ter.átadás minimum [%]',    O.GEO_SHARE_MIN;
    'Max. dőlésgradiens [deg/g]',           O.ROLL_GRAD_MAX_DEG_G;
    '* Stat. damperhossz',                  'ha a damper teljes kirugózásnál éppen teljesen kihúzott (L_max); megengedett tartomány: L_max - löket + S_bump ... L_max - S_reb'};
writecell([{'Paraméter', 'Érték'}; inp], xlsx_file, 'Sheet', 'Bemenetek');
fprintf('\nEredmények (Excel): %s\n', xlsx_file);

% --- RC összefoglaló szövegfájl ---
fid = fopen(fullfile(runDir, 'RC_osszefoglalo.txt'), 'w', 'n', 'UTF-8');
if fid > 0
    fprintf(fid, 'ROLL CENTER ÖSSZEFOGLALÓ - futás: %s\n', stamp);
    fprintf(fid, 'RC mód: %s\n', ternary(O.OPT_RC, 'optimalizált', 'fix'));
    fprintf(fid, 'Alap RC (P.h_RC_F / P.h_RC_R): első %.1f mm, hátsó %.1f mm\n', 1000 * P.h_RC_F, 1000 * P.h_RC_R);
    if O.OPT_RC
        fprintf(fid, 'RC tartomány: első %.0f...%.0f mm, hátsó %.0f...%.0f mm\n', 1000 * O.RC_RANGE_F, 1000 * O.RC_RANGE_R);
    end
    fprintf(fid, '\n%-5s %-10s %-10s %-13s %-15s %-13s %-10s\n', 'Rang', 'RC_F [mm]', 'RC_R [mm]', 'Jacking [mm]', 'Jack alap-RC', 'Geo átadás %', 'Késés [°]');
    for k = 1:numel(sol)
        fprintf(fid, '%-5d %-10.1f %-10.1f %-13.2f %-15.2f %-13.1f %-10.2f\n', k, 1000 * sol(k).p(17), 1000 * sol(k).p(18), ...
            1000 * sol(k).E.M.dh_jack, Xs{k}.dh_jack_base_mm, sol(k).E.M.GEO_SHARE, sol(k).E.Rd.lag_deg);
    end
    fclose(fid);
end

% --- baszogep.m-be közvetlenül betölthető MR-fájlok + strukturális adatlapok a legjobb megoldásokra ---
for k = 1:min(O.N_MR_FILES, numel(sol))
    export_mr_excel(sol(k).p, fullfile(runDir, sprintf('MR_rang%d.xlsx', k)));
    write_handover_txt(fullfile(runDir, sprintf('Strukturalis_atadas_rang%d.txt', k)), k, sol(k), P, O, stamp);
end
fprintf('MR-fájlok (baszogep.m formátum, nevezd át Célgörbe_MotionRatios.xlsx-re) és strukturális adatlapok: %s\n', runDir);
fprintf('Összes futásidő: %.1f s\n', toc(t_all));
diary off;

%% ========================================================================
%  SEGÉDFÜGGVÉNYEK
%  ========================================================================

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function v = mrv(c, x_m)
    % motion ratio [-], x_m: kerékút [m]; a polinom x-e mm; alsó korlát a nullával osztás ellen
    v = max(c(1) + c(2) * (1000 * x_m) + c(3) * (1000 * x_m).^2, 0.05);
end

function v = polyv(c, x_mm)
    v = c(1) + c(2) * x_mm + c(3) * x_mm.^2;
end

function s = mr_text(c, name, active)
    if ~active
        s = '- (nincs stabilizátor ezen a tengelyen)';
    elseif abs(c(3)) < 1e-12
        s = sprintf('%s(x) = %.4f %+.5f*x', name, c(1), c(2));
    else
        s = sprintf('%s(x) = %.4f %+.5f*x %+.3e*x^2', name, c(1), c(2), c(3));
    end
end

function pn = nominal_p(cs, O, P)
    pn = [0.82 0 0,  0.85 0 0,  0.85 0 0,  0.80 0 0,  0 0 0 0,  P.h_RC_F P.h_RC_R];
    % v3: az alap RC (123/127 mm) a megengedett tartomány FÖLÖTT van -> a kezdőpont a plafonra volt vágva.
    % Optimalizált RC-nél a tartomány közepéről indulunk.
    if O.OPT_RC, pn(17) = mean(O.RC_RANGE_F); pn(18) = mean(O.RC_RANGE_R); end
    if cs.modeF == 1, pn(13) = 0.25 * O.K_ARB_MAX;   end
    if cs.modeR == 1, pn(14) = 0.25 * O.K_ARB_MAX;   end
    if cs.modeF == 2, pn(15) = 0.25 * O.K_HEAVE_MAX; end
    if cs.modeR == 2, pn(16) = 0.25 * O.K_HEAVE_MAX; end
end

function [lb, ub, free, pfix] = build_bounds(cs, O, P)
    % p = [mF(3) mR(3) aF(3) aR(3) K_ARB_F K_ARB_R K_HEAVE_F K_HEAVE_R h_RC_F h_RC_R]
    lb = zeros(1, 18); ub = zeros(1, 18);
    lb([1 4]) = O.MR_M0_SPRING(1);  ub([1 4]) = O.MR_M0_SPRING(2);
    lb([7 10]) = O.MR_M0_ARB(1);    ub([7 10]) = O.MR_M0_ARB(2);
    lb([2 5 8 11]) = O.MR_M1_RANGE(1); ub([2 5 8 11]) = O.MR_M1_RANGE(2);
    lb([3 6 9 12]) = O.MR_M2_RANGE(1); ub([3 6 9 12]) = O.MR_M2_RANGE(2);
    lb(13:16) = 0;
    ub([13 14]) = O.K_ARB_MAX;  ub([15 16]) = O.K_HEAVE_MAX;
    lb(17) = O.RC_RANGE_F(1);  ub(17) = O.RC_RANGE_F(2);     % roll center magasságok [m]
    lb(18) = O.RC_RANGE_R(1);  ub(18) = O.RC_RANGE_R(2);

    free = false(1, 18);
    free([1 2 4 5]) = true;
    if cs.order == 2, free([3 6]) = true; end
    if cs.modeF > 0, free([7 8])   = true; if cs.order == 2, free(9)  = true; end, end
    if cs.modeR > 0, free([10 11]) = true; if cs.order == 2, free(12) = true; end, end
    if cs.modeF == 1, free(13) = true; elseif cs.modeF == 2, free(15) = true; end
    if cs.modeR == 1, free(14) = true; elseif cs.modeR == 2, free(16) = true; end
    if O.OPT_RC, free([17 18]) = true; end                   % RC optimalizálás választható
    pfix = nominal_p(cs, O, P);
end

function out = run_case(cs, P, O, seed)
    [lb, ub, free, pfix] = build_bounds(cs, O, P);
    lbf = lb(free); ubf = ub(free);
    nf = nnz(free);
    z_nom = (pfix(free) - lbf) ./ (ubf - lbf);
    z_nom = min(max(z_nom, 0), 1);
    rs = RandStream('twister', 'Seed', seed);

    opts = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'iter-detailed', ...
        'MaxIterations', 150, 'MaxFunctionEvaluations', 4000, ...
        'StepTolerance', 1e-9, 'ConstraintTolerance', 1e-6, 'OptimalityTolerance', 1e-6, ...
        'FiniteDifferenceStepSize', 1e-5);

    zc = []; Ec = [];                       % egyszerű gyorsítótár: célfv. és korlátok közös kiértékelése
    best = [];
    for s = 1:O.N_STARTS
        z0 = z_nom(:);
        if s > 1, z0 = min(max(z0 + 0.2 * randn(rs, nf, 1), 0), 1); end
        try
            zopt = fmincon(@(z) obj(z), z0, [], [], [], [], zeros(nf, 1), ones(nf, 1), @(z) nonl(z), opts);
            E = get_E(zopt);
            sc = E.J + 1e3 * max(0, E.maxviol);
            if isempty(best) || sc < best.sc
                best.sc = sc; best.p = pfix; best.p(free) = lbf + zopt(:).' .* (ubf - lbf);
                best.J = E.J; best.maxviol = E.maxviol;
            end
        catch
            % egy kezdőpont hibája nem állítja meg a futást
        end
    end
    if isempty(best)
        out = [];
    else
        out = struct('p', best.p, 'cs', cs, 'J', best.J, 'maxviol', best.maxviol);
    end

    function f = obj(z)
        f = get_E(z).J;
    end
    function [c, ceq] = nonl(z)
        c = get_E(z).c; ceq = [];
    end
    function E = get_E(z)
        zr = z(:).';
        if isempty(zc) || any(zr ~= zc)
            p = pfix; p(free) = lbf + zr .* (ubf - lbf);
            Ec = evaluate(p, cs, P, O); zc = zr;
        end
        E = Ec;
    end
end

function [r, S] = roll_state(phF, S0)
    % Az első tengely dőlésszögéhez tartozó nyomaték-maradék (baszogep.m ciklusa, váz torzióval)
    xF  = (S0.T_F / 2) * sin(phF);
    KwF = 0.5 * S0.kF * (1 / mrv(S0.cF, xF)^2 + 1 / mrv(S0.cF, -xF)^2);
    KrF = KwF * (S0.T_F^2 / 2) + S0.KarbF * S0.arbF / mrv(S0.aF, xF)^2;
    MFr = KrF * phF;
    Tch = S0.M_roll_F_in - MFr;
    phR = phF - Tch / S0.Kch;
    xR  = (S0.T_R / 2) * sin(phR);
    KwR = 0.5 * S0.kR * (1 / mrv(S0.cR, xR)^2 + 1 / mrv(S0.cR, -xR)^2);
    KrR = KwR * (S0.T_R^2 / 2) + S0.KarbR * S0.arbR / mrv(S0.aR, xR)^2;
    MRr = KrR * phR;
    r = MFr + MRr - S0.M_roll;
    if nargout > 1
        S.KrF = KrF; S.KrR = KrR; S.phR = phR; S.KwF = KwF; S.KwR = KwR;
    end
end

function G = rc_geometry(hF, hR, P)
    % Roll tengely geometria és geometriai (azonnali) terhelésátadás az RC magasságokból [m]
    G.h_RA_at_CG   = hR + (hF - hR) * (P.b / P.L);
    G.theta_RA_rad = atan((hF - hR) / P.L);
    G.dFz_geom_F   = (P.m_SM * P.a_lat * P.distrF * hF) / P.T_F;
    G.dFz_geom_R   = (P.m_SM * P.a_lat * (1 - P.distrF) * hR) / P.T_R;
end

function c = upper_c(v, vmax)
    % felső korlát skálázott alakja (c <= 0 a megfelelő); vmax = Inf / [] -> kikapcsolva (mindig teljesül)
    if ~isempty(vmax) && isfinite(vmax) && vmax > 0, c = (v - vmax) / vmax; else, c = -1; end
end

function c = lower_c(v, vmin)
    % alsó korlát skálázott alakja (c <= 0 a megfelelő); vmin = Inf / [] / 0 -> kikapcsolva
    if ~isempty(vmin) && isfinite(vmin) && vmin > 0, c = (vmin - v) / vmin; else, c = -1; end
end

function M = model_mech(p, kF, kR, P)
    % Egyensúlyi dőlés, MN, TLTD, ride frekvenciák, jacking - a baszogep.m 3-5. fejezetének zárt alakja
    % p = [mF(3) mR(3) aF(3) aR(3) K_ARB_F K_ARB_R K_HEAVE_F K_HEAVE_R h_RC_F h_RC_R]
    vt = P.valtoszam;
    cF = p(1:3); cR = p(4:6); aF = p(7:9); aR = p(10:12);
    KarbF = p(13); KarbR = p(14); KhvF = p(15); KhvR = p(16);
    hRC_F = p(17); hRC_R = p(18);                    % statikus (tervezési) RC magasságok; a dinamikusak lent: hRCd_F / hRCd_R

    KwF0 = kF * vt / mrv(cF, 0)^2;
    KwR0 = kR * vt / mrv(cR, 0)^2;
    KhF0 = 2 * KwF0 + KhvF / mrv(aF, 0)^2;         % statikus heave merevség tengelyenként (rugók + heave stabilizátor)
    KhR0 = 2 * KwR0 + KhvR / mrv(aR, 0)^2;
    KrideF_ax = KhF0 * (2 * P.K_Tire) / (KhF0 + 2 * P.K_Tire);   % tengely heave merevsége a gumikkal sorosan
    KrideR_ax = KhR0 * (2 * P.K_Tire) / (KhR0 + 2 * P.K_Tire);   % (heave stab. nélkül = a korábbi 2*Kride_kerék)
    Kride_tot = KrideF_ax + KrideR_ax;

    Fy = P.m_total * P.a_lat;
    % Aero lesüllyedés kanyarsebességen (a tengely heave merevségéből, statikus helyzetből) [m]; DYN_HEIGHT = false -> 0
    if P.DYN_HEIGHT
        xaF = aero_defl(kF, cF, aF, KhvF, P.F_down_cor_F, vt);
        xaR = aero_defl(kR, cR, aR, KhvR, P.F_down_cor_R, vt);
    else
        xaF = 0; xaR = 0;
    end
    % Jacking + dinamikus RC fixpont-iteráció: a jacking az RC magasságától függ, az RC pedig a kasztni elmozdulásától
    % függ (jacking felfelé, aero lesüllyedés lefelé; k_RC = a kasztni mozgásának RC-t követő hányada)
    dh_jack = 0;
    for it = 1:6
        hRCd_F = hRC_F + P.k_RC_F * P.DYN_HEIGHT * (dh_jack - xaF);
        hRCd_R = hRC_R + P.k_RC_R * P.DYN_HEIGHT * (dh_jack - xaR);
        dh_jack = (Fy * P.distrF * (hRCd_F / (P.T_F / 2)) + Fy * (1 - P.distrF) * (hRCd_R / (P.T_R / 2))) / Kride_tot;
    end
    hRCd_F = hRC_F + P.k_RC_F * P.DYN_HEIGHT * (dh_jack - xaF);
    hRCd_R = hRC_R + P.k_RC_R * P.DYN_HEIGHT * (dh_jack - xaR);
    F_jack_F = Fy * P.distrF       * (hRCd_F / (P.T_F / 2));   % a tengely oldalerő-hányada az elsőn: distrF
    F_jack_R = Fy * (1 - P.distrF) * (hRCd_R / (P.T_R / 2));
    dh_jack  = (F_jack_F + F_jack_R) / Kride_tot;
    % A CoG a kasztnival együtt mozog: jacking felfelé, aero lesüllyedés lefelé (a CoG-nál interpolálva)
    dz_CG = dh_jack - (P.distrF * xaF + (1 - P.distrF) * xaR);

    hSM  = P.h_CG_SM + dz_CG;
    htot = P.h_CG_total + dz_CG;
    G = rc_geometry(hRCd_F, hRCd_R, P);                    % roll tengely a DINAMIKUS RC magasságokból
    dz_dyn     = hSM - G.h_RA_at_CG;
    d_perp_dyn = (htot - G.h_RA_at_CG) * cos(G.theta_RA_rad);
    theta_x_RC = P.theta_x_CG + P.m_SM * dz_dyn^2;

    S0.M_roll      = P.m_SM * P.a_lat * dz_dyn;
    S0.M_roll_F_in = P.m_SM * P.distrF * P.a_lat * (hSM - hRCd_F);
    S0.M_roll_R_in = P.m_SM * (1 - P.distrF) * P.a_lat * (hSM - hRCd_R);
    S0.kF = kF * vt; S0.kR = kR * vt;
    S0.cF = cF; S0.cR = cR; S0.aF = aF; S0.aR = aR;
    S0.KarbF = KarbF; S0.KarbR = KarbR;
    S0.T_F = P.T_F; S0.T_R = P.T_R; S0.Kch = P.K_chassis;
    if P.ARB_ROLL_T2_4, S0.arbF = P.T_F^2 / 4; S0.arbR = P.T_R^2 / 4; else, S0.arbF = 1; S0.arbR = 1; end

    phHi = 0.10;                                   % [rad] keresési tartomány felső határa
    r0 = roll_state(0, S0);
    [r1, Sh] = roll_state(phHi, S0);
    if r0 >= 0
        phF = 0;
    elseif r1 <= 0
        phF = phHi + (-r1) / (Sh.KrF + Sh.KrR);    % túl puha: linearizált kiterjesztés (a korlát úgyis sérül)
    else
        phF = fzero(@(ph) roll_state(ph, S0), [0 phHi], P.fzopt);
    end
    [~, Sq] = roll_state(phF, S0);

    KrF = Sq.KrF; KrR = Sq.KrR;
    M.phiF_deg = rad2deg(phF);
    M.phiR_deg = rad2deg(Sq.phR);
    M.MN = 100 * KrF / (KrF + KrR);
    Tch_lin = (S0.M_roll_F_in / KrF - S0.M_roll_R_in / KrR) / (1 / P.K_chassis + 1 / KrF + 1 / KrR);
    M.MD = (S0.M_roll_F_in - Tch_lin) / S0.M_roll * 100;
    dFz_el_F = (P.m_SM * P.a_lat * d_perp_dyn / P.T_F) * (M.MD / 100);
    dFz_el_R = (P.m_SM * P.a_lat * d_perp_dyn / P.T_R) * ((100 - M.MD) / 100);
    tF = G.dFz_geom_F + dFz_el_F + P.dFz_NSM_F;
    tR = G.dFz_geom_R + dFz_el_R + P.dFz_NSM_R;
    M.TLTD   = 100 * tF / (tF + tR);
    % geometriai (azonnali) hányad: RC-n átadódó + nem rugózott tömeg része az összes terhelésátadásból
    M.GEO_SHARE = 100 * (G.dFz_geom_F + G.dFz_geom_R + P.dFz_NSM_F + P.dFz_NSM_R) / (tF + tR);
    M.f_roll = sqrt((KrF + KrR) / theta_x_RC) / (2 * pi);
    M.K_roll = KrF + KrR;                          % [Nm/rad]
    M.theta_x_RC = theta_x_RC;                     % [kg m^2]
    M.roll_grad = M.phiF_deg / P.a_lat_g;          % [deg/g] (első tengely, mint a phi_eq_deg)

    M.fF = sqrt(KhF0 / (2 * P.m1_F)) / (2 * pi);
    M.fR = sqrt(KhR0 / (2 * P.m1_R)) / (2 * pi);
    M.KwF0 = KwF0; M.KwR0 = KwR0;
    M.dh_jack = dh_jack;                           % [m]
    M.F_jack_F = F_jack_F; M.F_jack_R = F_jack_R;  % [N]
    M.hRC_F = hRC_F; M.hRC_R = hRC_R;              % [m] statikus (tervezési) RC
    M.hRC_F_dyn = hRCd_F; M.hRC_R_dyn = hRCd_R;    % [m] dinamikus RC (aero lesüllyedés + jacking után)
    M.dz_CG = dz_CG;                               % [m] CoG függőleges elmozdulása (jacking - aero lesüllyedés)
    M.xaero_cor_F = xaF; M.xaero_cor_R = xaR;      % [m] aero berugózás kanyarsebességen
end

function xa = aero_defl(kk, cW, cA, Khv, F, vt)
    % Tengelyenkénti aero-leszorítóerőhöz (F [N]) tartozó berugózás [m]: a heave merevség integráljának inverze
    if F <= 0, xa = 0; return; end
    x  = linspace(0, 0.060, 121);
    Kh = 2 * (kk * vt) ./ mrv(cW, x).^2 + Khv ./ mrv(cA, x).^2;
    xa = interp1(cumtrapz(x, Kh), x, F, 'pchip', 'extrap');
end

function Rd = roll_dynamics(M, cwF, cwR, P, O)
    % A roll-mód csillapítási tényezője és a keresztirányú terhelésátadás fáziskésése a szlalom frekvencián.
    % cwF, cwR: kerékszintű kis sebességű csillapítás [N s/m] tengelyenként (LSR és LSC átlaga:
    % tiszta rollnál az egyik kerék összenyomódik, a másik kinyúlik).
    C_roll = cwF * P.T_F^2 / 2 + cwR * P.T_R^2 / 2;          % [Nm s/rad]
    Rd.zeta = C_roll / (2 * sqrt(M.K_roll * M.theta_x_RC));
    r  = O.F_SLALOM_HZ / M.f_roll;
    Hroll = 1 / (1 - r^2 + 2i * Rd.zeta * r);                % rugózott tömeg roll-válasza (nyomaték -> dőlés jellegű)
    gs = M.GEO_SHARE / 100;
    H  = gs + (1 - gs) * Hroll;                              % azonnali (geometriai) + késleltetett (rugalmas) rész
    Rd.lag_deg = -angle(H) * 180 / pi;
    Rd.amp = abs(H);
end

function Fax = axle_force(kk, cW, cA, Khv, xlim_m, vt)
    % tengelyenkénti aero-erő, amit a heave merevség xlim_m berugózásig felvesz [N]
    x  = linspace(0, xlim_m, 41);
    Kh = 2 * (kk * vt) ./ mrv(cW, x).^2 + Khv ./ mrv(cA, x).^2;
    Fax = trapz(x, Kh);
end

function v = arms_vec(xi, K, m1, m2, Kt, f)
    % A_RMS több xi-re egyszerre (baszogep.m get_ARMS_for_xi vektorizált változata)
    w  = 2 * pi * f(:).';
    c  = xi(:) * 2 * sqrt(K * m1);
    cw = 1i * (c * w);
    A11 = K - m1 * w.^2 + cw;
    A22 = K + Kt - m2 * w.^2 + cw;
    A12 = -(K + cw);
    Z2  = A11 * Kt ./ (A11 .* A22 - A12.^2);
    A_f = abs(Kt * (Z2 - 1));
    v = sqrt(trapz(f(:).', A_f.^2, 2) / (f(end) - f(1)));
end

function D = damper_select(cW, cA, kk, Khv, m1, m2, xiT, P, O)
    % Click-választás rezsimenként: statikus xi hiba + A_RMS többlet súlyozott minimuma
    vt = P.valtoszam;
    nClk = size(P.C, 2);                               % <-- ÚJ: click-ek száma (12)
    MR0 = mrv(cW, 0);
    K0  = kk * vt / MR0^2 + Khv / (2 * mrv(cA, 0)^2);
    xi0 = P.C ./ (MR0^2 * 2 * sqrt(K0 * m1));          % 4 x nClk

    pos = O.ARMS_POS_MM(:).' / 1000;
    pen = zeros(4, nClk, numel(pos));                  % <-- 6 helyett nClk
    for ip = 1:numel(pos)
        x   = pos(ip);
        MRx = mrv(cW, x);
        Kx  = kk * vt / MRx^2 + Khv / (2 * mrv(cA, x)^2);
        xi_mat = P.C ./ (MRx^2 * 2 * sqrt(Kx * m1));
        vals = arms_vec([xi_mat(:); O.XI_GRID(:)], Kx, m1, m2, P.K_Tire, O.F_VEC);
        A_cl = reshape(vals(1:4*nClk), 4, nClk);       % <-- 24 és 6 helyett
        pen(:, :, ip) = A_cl ./ min(vals) - 1;
    end
    armsFrac = mean(pen, 3);
    Jc = O.W_XI * (xi0 ./ xiT(:) - 1).^2 + O.W_ARMS * armsFrac;
    [Jmin, click] = min(Jc, [], 2);
    idx = sub2ind([4 nClk], (1:4).', click);           % <-- [4 6] helyett

    D.J = mean(Jmin);
    D.click = click(:).';
    D.xi = xi0(idx).';
    D.arms_pen = 100 * armsFrac(idx).';
    D.arms_pen_mean = mean(D.arms_pen);
end

function E = evaluate(p, cs, P, O)
    vt = P.valtoszam;
    cF = p(1:3); cR = p(4:6); aF = p(7:9); aR = p(10:12);
    actF = cs.modeF > 0; actR = cs.modeR > 0;
    M = model_mech(p, cs.kF, cs.kR, P);

    % --- 1) tartomány-korlátok (skálázva a tartomány szélességével) ---
    c_phi  = range_c(M.phiF_deg, O.PHI_RANGE_DEG);
    c_tltd = range_c(M.TLTD,     O.TLTD_RANGE);
    c_mn   = range_c(M.MN,       O.MN_RANGE);

    % --- 2) hasmagasság > H_MIN a teljes sebességtartományban (aero) ---
    xlF = P.h_static_F_mm - O.H_MIN_MM;
    xlR = P.h_static_R_mm - O.H_MIN_MM;
    if O.AERO_WITHIN_TRAVEL
        xlF = min(xlF, O.TRAVEL_BUMP_MM); xlR = min(xlR, O.TRAVEL_BUMP_MM);
    end
    FaxF = axle_force(cs.kF, cF, aF, p(15), xlF / 1000, vt);
    FaxR = axle_force(cs.kR, cR, aR, p(16), xlR / 1000, vt);
    c_aero = [(P.F_down_ax_F - FaxF) / P.F_down_ax_F; (P.F_down_ax_R - FaxR) / P.F_down_ax_R];

    % --- 3) MR a megengedett sávban + damper löket a teljes kerékúton ---
    xg = linspace(-O.TRAVEL_REB_MM, O.TRAVEL_BUMP_MM, 51);
    mFg = polyv(cF, xg); mRg = polyv(cR, xg); aFg = polyv(aF, xg); aRg = polyv(aR, xg);
    act = [true; true; actF; actR];
    c_mrmin = (O.MR_MIN - [min(mFg); min(mRg); min(aFg); min(aRg)]) / O.MR_MIN;
    c_mrmax = ([max(mFg); max(mRg); max(aFg); max(aRg)] - O.MR_MAX) / O.MR_MAX;
    c_mrmin(~act) = -1; c_mrmax(~act) = -1;
    S_F = trapz(xg, mFg); S_R = trapz(xg, mRg);          % damper elmozdulás a teljes kerékúton [mm]
    c_str = [(S_F - O.DAMPER_STROKE_MM) / O.DAMPER_STROKE_MM; (S_R - O.DAMPER_STROKE_MM) / O.DAMPER_STROKE_MM];

    % --- 4) célfüggvény: ride freq + damper + jacking + reaktivitás ---
    fT = O.F_RIDE_TARGET;
    J_ride = O.W_F * (((M.fF - fT(1)) / fT(1))^2 + ((M.fR - fT(2)) / fT(2))^2);
    DF = damper_select(cF, aF, cs.kF, p(15), P.m1_F, P.m2_F, O.XI_TARGET(:, 1), P, O);
    DR = damper_select(cR, aR, cs.kR, p(16), P.m1_R, P.m2_R, O.XI_TARGET(:, 2), P, O);

    % roll csillapítás és fáziskésés: (t) cél-xi alapján (sima, ezt használja az optimalizáló),
    %                                 (a) a ténylegesen kiválasztott click-ekkel (csak kiírásra)
    MR0F = mrv(cF, 0); MR0R = mrv(cR, 0);
    K0F = cs.kF * vt / MR0F^2 + p(15) / (2 * mrv(aF, 0)^2);
    K0R = cs.kR * vt / MR0R^2 + p(16) / (2 * mrv(aR, 0)^2);
    cwF_t = mean(O.XI_TARGET(1:2, 1)) * 2 * sqrt(K0F * P.m1_F);
    cwR_t = mean(O.XI_TARGET(1:2, 2)) * 2 * sqrt(K0R * P.m1_R);
    cwF_a = (P.C(1, DF.click(1)) + P.C(2, DF.click(2))) / 2 / MR0F^2;
    cwR_a = (P.C(1, DR.click(1)) + P.C(2, DR.click(2))) / 2 / MR0R^2;
    Rdt = roll_dynamics(M, cwF_t, cwR_t, P, O);
    Rda = roll_dynamics(M, cwF_a, cwR_a, P, O);

    J_jack  = O.W_JACK  * (1000 * M.dh_jack / O.JACK_REF_MM)^2;
    J_react = O.W_REACT * (Rdt.lag_deg / O.LAG_REF_DEG)^2;
    J_geo   = O.W_GEO   * (max(0, O.GEO_TARGET - M.GEO_SHARE) / O.GEO_REF)^2;   % RC-függő reaktivitás-tag
    J_tltd  = O.W_TLTD  * ((M.TLTD - O.TLTD_TARGET) / O.TLTD_REF)^2;           % RC-megosztást eldöntő lágy tag
    J_froll = O.W_FROLL * (max(0, O.F_ROLL_REF - M.f_roll) / O.F_ROLL_REF)^2;       % minél magasabb roll frekvencia
    J = J_ride + DF.J + DR.J + J_jack + J_react + J_geo + J_tltd + J_froll;

    % --- 5) reaktivitás / jacking korlátok (Inf = kikapcsolva) ---
    c_rg   = upper_c(M.roll_grad,        O.ROLL_GRAD_MAX_DEG_G);
    c_geo  = lower_c(M.GEO_SHARE,        O.GEO_SHARE_MIN);
    c_jack = upper_c(1000 * M.dh_jack,   O.JACK_MAX_MM);
    c_lag  = upper_c(Rdt.lag_deg,        O.LAG_MAX_DEG);

    c_fF   = range_c(M.fF, O.F_RIDE_RANGE_F);                % [alsó; felső] első ride frekvencia
    c_fR   = range_c(M.fR, O.F_RIDE_RANGE_R);                % [alsó; felső] hátsó ride frekvencia
    c = [c_phi; c_tltd; c_mn; c_aero; c_mrmin; c_mrmax; c_str; c_rg; c_geo; c_jack; c_lag; c_fF; c_fR];

    if ~isfinite(J) || any(~isfinite(c))
        J = 1e3; c = 1e3 * ones(numel(c), 1);
    end
    E.J = J; E.c = c; E.maxviol = max(c);
    E.M = M; E.DF = DF; E.DR = DR; E.S_F = S_F; E.S_R = S_R;
    E.Rd = Rda; E.Rdt = Rdt; E.J_jack = J_jack; E.J_react = J_react; E.J_geo = J_geo; E.J_tltd = J_tltd; E.J_ride = J_ride; E.J_dmp = DF.J + DR.J; E.J_froll = J_froll;
end

function c = range_c(v, rg)
    w = max(rg(2) - rg(1), 1e-3);
    c = [(rg(1) - v) / w; (v - rg(2)) / w];
end

function X = solution_extras(p, cs, P, O)
    % Hasmagasság a teljes sebességtartományban (baszogep.m 5B.), damper út és statikus hossz
    vt = P.valtoszam;
    cF = p(1:3); cR = p(4:6); aF = p(7:9); aR = p(10:12);
    xgrid = linspace(0, 0.060, 601);
    KhF = 2 * (cs.kF * vt) ./ mrv(cF, xgrid).^2 + p(15) ./ mrv(aF, xgrid).^2;
    KhR = 2 * (cs.kR * vt) ./ mrv(cR, xgrid).^2 + p(16) ./ mrv(aR, xgrid).^2;
    xaF = interp1(cumtrapz(xgrid, KhF), xgrid, P.F_down_ax_F, 'pchip', 'extrap');
    xaR = interp1(cumtrapz(xgrid, KhR), xgrid, P.F_down_ax_R, 'pchip', 'extrap');
    X.xaero_F = 1000 * xaF; X.xaero_R = 1000 * xaR;
    X.h_min_F = P.h_static_F_mm - X.xaero_F;
    X.h_min_R = P.h_static_R_mm - X.xaero_R;

    xn = linspace(-O.TRAVEL_REB_MM, 0, 26); xp = linspace(0, O.TRAVEL_BUMP_MM, 26);
    SrebF = trapz(xn, polyv(cF, xn)); SbumpF = trapz(xp, polyv(cF, xp));
    SrebR = trapz(xn, polyv(cR, xn)); SbumpR = trapz(xp, polyv(cR, xp));
    X.S_F = SrebF + SbumpF; X.S_R = SrebR + SbumpR;
    X.L_stat_F = O.DAMPER_LMAX_MM - SrebF;      % ha teljes kirugózásnál a damper éppen L_max hosszú
    X.L_stat_R = O.DAMPER_LMAX_MM - SrebR;

    % jacking az alap RC magasságokkal (összehasonlításhoz) és a roll tengely dőlése
    pb = p; pb(17) = P.h_RC_F; pb(18) = P.h_RC_R;
    Mb = model_mech(pb, cs.kF, cs.kR, P);
    X.dh_jack_base_mm = 1000 * Mb.dh_jack;
    X.RA_incl_deg = rad2deg(atan((p(17) - p(18)) / P.L));
end

function export_mr_excel(p, file)
    % baszogep.m formátum: 1. sor = kerékút [mm], 2-5. sor = MR_Spring_Front/Rear, MR_ARB_Front/Rear
    xm = -30:1:30;
    out = cell(5, numel(xm) + 1);
    out{1, 1} = 'Kerékút_Z_mm';
    out(1, 2:end) = num2cell(xm);
    names = {'MR_Spring_Front', 'MR_Spring_Rear', 'MR_ARB_Front', 'MR_ARB_Rear'};
    cc = {p(1:3), p(4:6), p(7:9), p(10:12)};
    for k = 1:4
        out{k + 1, 1} = names{k};
        out(k + 1, 2:end) = num2cell(polyv(cc{k}, xm));
    end
    writecell(out, file);
end

function [hdr, rows] = handover_table(k, p, cs, P, O)
    % Strukturális átadási adatok tengelyenként (első, hátsó): stabilizátor motion ratio + droplinken mérhető célmerevség
    vt = P.valtoszam;
    hdr = {'Rang', 'Tengely', 'Stabilizátor típus', ...
        'MR_stab(x) [kerékút / droplink-út; x: kerékút mm]', 'MR_stab statikus (x=0)', 'MR_stab min (teljes kerékút)', 'MR_stab max (teljes kerékút)', ...
        'CÉL K_droplink (modell-definíció) [N/mm]', 'Droplinkenkénti ekvivalens merevség [N/mm]', 'Egy droplinken mérve, a másik vég rögzítve [N/mm]', ...
        'Stab. hozzájárulása a tengely roll-merevségéhez (x=0) [Nm/deg]', 'Rugók roll-merevsége a tengelyen (x=0) [Nm/deg]', 'Tengely össz. roll-merevség (x=0) [Nm/deg]', ...
        'Stab. heave-merevsége a kerekeknél (x=0) [N/mm]', 'Rugók heave-merevsége a kerekeknél (x=0) [N/mm]', ...
        'Megjegyzés (mérési konvenció, a modell képletéből levezetve)'};
    typ = {'nincs', 'roll (ARB)', 'heave (Z-bar)'};
    rows = cell(2, numel(hdr));
    xg = linspace(-O.TRAVEL_REB_MM, O.TRAVEL_BUMP_MM, 51);
    for ax = 1:2
        if ax == 1
            name = 'Első';  mode = cs.modeF; cw = p(1:3); ca = p(7:9);  Karb = p(13); Khv = p(15); kk = cs.kF; T = P.T_F;
        else
            name = 'Hátsó'; mode = cs.modeR; cw = p(4:6); ca = p(10:12); Karb = p(14); Khv = p(16); kk = cs.kR; T = P.T_R;
        end
        MR0 = mrv(cw, 0);
        Kw0 = kk * vt / MR0^2;                         % rugó kerékszintű merevsége [N/m]
        Kspring_roll = Kw0 * T^2 / 2;                  % rugók roll-merevsége a tengelyen [Nm/rad]
        if P.ARB_ROLL_T2_4, arbT = T^2 / 4; else, arbT = 1; end

        mrTxt = '-'; mr0 = '-'; mrmin = '-'; mrmax = '-';
        Kdl = '-'; Kper = '-'; Kone = '-';
        rollStab = 0; heaveStab = 0;
        note = 'nincs stabilizátor ezen a tengelyen';
        if mode > 0
            MRa0 = mrv(ca, 0);
            mA = polyv(ca, xg);
            mrTxt = mr_text(ca, 'MR_stab', true);
            mr0 = MRa0; mrmin = min(mA); mrmax = max(mA);
            if mode == 1
                K = Karb;
                rollStab = K * arbT / MRa0^2;          % [Nm/rad]
                Kdl = K / 1000;
                if P.ARB_ROLL_T2_4
                    Kper = K / 2 / 1000; Kone = K / 4 / 1000;
                    note = ['A modell: K_roll_ARB = K/MR^2 * T^2/4. K a két droplink ekvivalens merevségének összege; ' ...
                            'roll (ellentétes) mozgásnál droplinkenként K/2; ideális torziós rúd + merev karok esetén egy droplinken ' ...
                            'mérve, a másik véget rögzítve K/4. MR = kerékút / droplink-út. Ellenőrzés: a roll-merevség [Nm/deg] konvenciófüggetlen.'];
                else
                    Kper = 'n/a'; Kone = 'n/a';
                    note = ['ARB_ROLL_T2_4 = false: a modellben K_roll_ARB = K/MR^2 (K itt roll-merevség jellegű), ' ...
                            'a droplink-átszámítás nem egyértelmű - egyeztess a K_ARB definíciójáról. A roll-merevség [Nm/deg] konvenciófüggetlen.'];
                end
            else
                K = Khv;
                heaveStab = K / MRa0^2;                % [N/m] a kerekeknél, tengelyszinten
                Kdl = K / 1000; Kper = K / 2 / 1000; Kone = 'n/a';
                note = ['A modell: a tengely heave merevsége a kerekeknél = K/MR^2; K a két droplink együttes merevsége ' ...
                        '(azonos irányú mozgásnál), droplinkenként K/2. MR = kerékút / droplink-út. Ellenőrzés: a heave-merevség [N/mm] konvenciófüggetlen.'];
            end
        end
        rollTot = Kspring_roll + rollStab;
        rows(ax, :) = {k, name, typ{mode + 1}, mrTxt, mr0, mrmin, mrmax, Kdl, Kper, Kone, ...
            rollStab * pi / 180, Kspring_roll * pi / 180, rollTot * pi / 180, heaveStab / 1000, 2 * Kw0 / 1000, note};
    end
end

function write_handover_txt(file, k, s, P, O, stamp)
    % Olvasható strukturális átadási adatlap egy megoldásra (szöveges fájl)
    [hdr, rows] = handover_table(k, s.p, s.cs, P, O);
    fid = fopen(file, 'w', 'n', 'UTF-8');
    if fid < 0
        warning('Nem sikerült megnyitni: %s', file); return;
    end
    fprintf(fid, 'STRUKTURÁLIS ÁTADÁSI ADATLAP - %d. rang (futás: %s)\n', k, stamp);
    fprintf(fid, '%s\n', repmat('=', 1, 72));
    fprintf(fid, 'Roll center (statikus): első = %.1f mm, hátsó = %.1f mm  [%s]\n', 1000 * s.p(17), 1000 * s.p(18), ternary(O.OPT_RC, 'optimalizált', 'fix'));
    fprintf(fid, 'Főrugók: első %g lbs/in, hátsó %g lbs/in\n', s.cs.kF, s.cs.kR);
    fprintf(fid, 'Dőlésgradiens: %.3f deg/g | jacking: %.2f mm | geometriai terhelésátadás: %.1f %%\n\n', ...
        s.E.M.roll_grad, 1000 * s.E.M.dh_jack, s.E.M.GEO_SHARE);
    for ax = 1:size(rows, 1)
        fprintf(fid, '--- %s tengely ---\n', rows{ax, 2});
        for c = 3:numel(hdr)
            v = rows{ax, c};
            if ischar(v)
                fprintf(fid, '  %s: %s\n', hdr{c}, v);
            else
                fprintf(fid, '  %s: %.4g\n', hdr{c}, v);
            end
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end

