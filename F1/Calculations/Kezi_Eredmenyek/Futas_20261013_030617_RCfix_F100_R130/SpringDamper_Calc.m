% =========================================================================
% Formula Student - Kanyarodási Kasztnidőlés, Merevség- és Átterhelődés Modell
% KÉZI (iterálható) VÁLTOZAT
%
%  Ez a fájl a baszogep_optimalizalo_2.m minden számítását és Excel / fájl-kimenetét
%  tartalmazza, de OPTIMALIZÁLÁS nélkül: a beállításokat (főrugók, stabilizátorok, roll center,
%  damper click-ek, motion ratio görbék) te adod meg kézzel, a program pedig EGYETLEN megoldásra
%  ugyanazt számolja ki és ugyanúgy ír ki mindent, mint az optimalizáló a legjobb megoldásokra.
%
%  A paramétereket, amiket állíthatsz, a "0. PARAMÉTEREK" fejezet (a fájl eleje) gyűjti össze.
%  A motion ratio (MR) görbék betöltése változatlan: Excelből (Célgörbe_MotionRatios.xlsx) / GUI-val.
%
%  Számítás (az optimalizálóval azonos függvények): egyensúlyi dőlés, MN, MD, TLTD, ride / roll
%  frekvencia, jacking (heave stabilizátorral és gumi-sorosítással), geometriai terhelésátadás,
%  dőlésgradiens, roll csillapítás + fáziskésés szlalom frekvencián, hasmagasság az aero miatt,
%  damper löket / statikus hossz, click-ek xi és A_RMS értékelése, korlát-ellenőrzés, célfüggvény (J),
%  strukturális átadási adatlap (ARB / Z-bar MR + droplink célmerevség), RC összefoglaló.
%
%  Kimenet: Kezi_Eredmenyek/Futas_<időbélyeg>_<RC mód>/ mappa (Excel, MR-fájl, adatlap, napló, beállítások).
%  A "!!! ÁLLÍTSD BE" jelölésű értékek az optimalizálóból átvett célok / határok (csak kiértékelésre).
% =========================================================================
clear; clc; close all;
t_all = tic;

disp('========================================================');
disp(' KANYARODÁSI KASZTNIDŐLÉS ÉS ÁTTERHELŐDÉS MODELL (KÉZI)');
disp(' - 4 db Motion Ratio görbe megadása GUI / Excel alapján:');
disp('   1. Első Főrugó MR(x)');
disp('   2. Hátsó Főrugó MR(x)');
disp('   3. Első ARB MR(x)');
disp('   4. Hátsó ARB MR(x)');
disp(' - Az optimalizáló összes számítása + Excel kimenet egy kézi beállításra');
disp('========================================================');

%% =========================================================================
%  0. PARAMÉTEREK - MINDEN, AMIT KÉZZEL ÁLLÍTHATSZ, ITT VAN
%  =========================================================================

% ---- 0.1 KÉZZEL ITERÁLT BEÁLLÍTÁS -----------------------------------------
K_spring_F  = 600;          % [lbs/in] Első főrugó
K_spring_R  = 700;          % [lbs/in] Hátsó főrugó

% Stabilizátor setup: 'első-hátsó' sorrendben, tengelyenként 'none' | 'roll' | 'heave'
% (pl. 'roll-roll', 'roll-heave', 'heave-roll', 'heave-heave', 'none-roll', 'none-none')
STAB_SETUP  = 'none-none';

% K_ARB_F     = 68615.71205;            % [N/m] Első ARB össz, droplinkre vett merevsége (roll típusnál használt)
% K_ARB_R     = 84522.71887;            % [N/m] Hátsó ARB össz, droplinkre vett merevsége
% K_ARB_F     = 80783.37609;            % [N/m] Első ARB össz, droplinkre vett merevsége (roll típusnál használt)
% K_ARB_R     = 107497.929;            % [N/m] Hátsó ARB össz, droplinkre vett merevsége
K_ARB_F     = 0;            % [N/m] Első ARB össz, droplinkre vett merevsége (roll típusnál használt)
K_ARB_R     = 0;            % [N/m] Hátsó ARB össz, droplinkre vett merevsége
K_HEAVE_F   = 0;            % [N/m] Első heave stab. össz, droplinkre vett merevsége (heave típusnál használt)
K_HEAVE_R   = 0;            % [N/m] Hátsó heave stab. össz, droplinkre vett merevsége

h_RC_F      = 0.100;        % [m] Első RC magasság (statikus)
h_RC_R      = 0.130;        % [m] Hátsó RC magasság (statikus)

CLICK_F     = [3 4 1 1];    % Első damper click [LSR LSC HSR HSC], egész szám 1..6
CLICK_R     = [3 3 1 1];    % Hátsó damper click [LSR LSC HSR HSC]

% ---- 0.2 MOTION RATIO GÖRBÉK (Excel / GUI) - változatlan működés ---------
USE_GUI_FOR_CURVES = true;                      % true: GUI szerkesztő mind a 4 görbére (Excel az alap); false: csak az Excel
eval_pts_mm  = -15:1:15;                        % [mm] Kerékút értékelési tartomány
% target_excel = 'Célgörbe_MotionRatios.xlsx';    % CSAK BETÖLTÉSRE használt alapfájl
% target_excel = 'Célgörbe_MotionRatios_girbegurba.xlsx';    % CSAK BETÖLTÉSRE használt alapfájl
target_excel = 'Célgörbe_MotionRatios.xlsx';    % CSAK BETÖLTÉSRE használt alapfájl
save_dir     = 'MR_Mentesek';                   % ide kerülnek az új, időbélyeges mentések (módosított görbék)

% ---- 0.3 JÁRMŰ, GEOMETRIA, TÖMEGEK ----------------------------------------
valtoszam  = 175.128;      % [N/m / lbs/in] Átváltószám
g          = 9.81;         % [m/s^2] Gravitációs gyorsulás
m_total    = 725.82;        % [kg] Teljes tömeg (autó + pilóta)
distrF     = 0.45;         % [-] Első tengelyre eső tömegarány
m_SM       = 628.82;       % [kg] Rugózott tömeg
m_NSM_F    = 94.9 / 4;     % [kg] Első sarki rugózatlan tömeg
m_NSM_R    = 94.9 / 4;     % [kg] Hátsó sarki rugózatlan tömeg

L          = 3;         % [m] Tengelytáv
T_F        = 1.6;         % [m] Első nyomtáv   (az optimalizálóban: 1.20)
T_R        = 1.6;         % [m] Hátsó nyomtáv

h_CG_SM    = 0.32;        % [m] Rugózott tömeg CoG magassága
h_CG_total = 0.3;        % [m] Teljes autó CoG magassága
h_CG_NSM   = 0.36;        % [m] Rugózatlan tömeg CoG magassága

theta_x_CG    = 7.65;      % [kg*m^2] Roll inercia a CoG körül
K_chassis_deg = 3500;      % [Nm/deg] Váz torziós merevség (merev vázhoz írj Inf-et)
K_Tire        = 1700 * valtoszam;   % [N/m] Gumiabroncs függőleges merevség (~103,000 N/m)
a_lat_g       = 5;         % [G] Cél oldalgyorsulás

% Az ARB roll-merevségének átszámítása:
% true : K_ARB/MR^2 * T^2/4 (mint az optimalizálóban és eddig ebben a fájlban)
% false: K_ARB/MR^2         (T^2/4 nélkül)
ARB_ROLL_T2_4 = true;

% ---- 0.4 AERODINAMIKA ÉS HASMAGASSÁG --------------------------------------
rho_air      = 1.2;      % [kg/m^3] Levegő sűrűsége
CLA          = 6.4;      % [m^2]    Leszorítóerő-tényező (C_L * A)   (az optimalizálóban: 5.5)
aero_distr_F = 0.45;     % [-]      Aero eloszlás: az első tengelyre eső arány
v_aero_kmh   = 0:1:360;  % [km/h]   Vizsgált sebességtartomány (a végpontja a hasmagasság-vizsgálat felső sebessége)
h_static_F_mm = 35;      % [mm] Első statikus hasmagasság
h_static_R_mm = 35;      % [mm] Hátsó statikus hasmagasság

% ---- 0.4b DINAMIKUS MAGASSÁGOK: A ROLL CENTER A CoG-GAL EGYÜTT MOZOG ---------------
% A kasztni függőleges elmozdulása (jacking felfelé, aero lesüllyedés lefelé) a CoG-t ÉS a roll centert is viszi.
DYN_HEIGHT   = true;     % true: dinamikus CoG + RC (aero lesüllyedés + jacking); false: a korábbi modell (RC fix, a CoG csak jackinggel emelkedik)
k_RC_F       = 1.05;      % [-] az első RC a kasztni függőleges mozgásának hányadát követi (1 = 1:1, 0 = fix RC)  !!! ÁLLÍTSD BE a kinematikából (dRC/dheave)
k_RC_R       = 1.05;      % [-] ugyanez hátul                                                                      !!! ÁLLÍTSD BE
v_corner_kmh = 160;       % [km/h] kanyarsebesség: ezen a sebességen számolt aero lesüllyedés kerül a dinamikus CoG-ba / RC-be  !!! ÁLLÍTSD BE

% ---- 0.5 DAMPER ADATOK ------------------------------------------------------
% Damper mátrix [N s/m] (damper oldalon): sorok LSR, LSC, HSR, HSC; oszlopok click 1..6
C_damper_matrix = [
    51081.6, 9940.1, 3916, 1962.9, 1129.1, 601.9;    % Low Speed Rebound (LSR)
    61889.8, 11165.6, 5319.1, 2375.7, 960.1, 944.1;  % Low Speed Compression (LSC)
    2040.3, 1402.4, 1457.8, 1212.2, 569.6, 586.4;    % High Speed Rebound (HSR)
    2253.6, 1929.4, 1659.3, 1029.9, 621.4, 645.1     % High Speed Compression (HSC)
];

% ---- 0.6 CÉLOK ÉS HATÁROK (a "Megfelel" ellenőrzéshez és a J célfüggvényhez; az optimalizálóból átvéve) ----
O = struct();
O.PHI_RANGE_DEG = [0.50 1];    % [deg]  !!! ÁLLÍTSD BE - egyensúlyi dőlésszög (első tengely)
O.TLTD_RANGE    = [35 40];       % [%]    !!! ÁLLÍTSD BE - TLTD (első arány)
O.MN_RANGE      = [45 55];       % [%]    !!! ÁLLÍTSD BE - Magic Number (K_roll_F / K_roll_tot)
O.F_RIDE_TARGET = [6.17 6.55];     % [Hz] [első hátsó] statikus ride frekvencia cél  !!! ÁLLÍTSD BE

% Cél damping ratio statikusan (x = 0); sorok: LSR LSC HSR HSC | oszlopok: első, hátsó  !!! ÁLLÍTSD BE
% (az optimalizálóban: 0.75 0.75 0.40 0.40 mindkét tengelyen)
O.XI_TARGET = [0.70 0.70;
               0.70 0.70;
               0.45 0.45;
               0.45 0.45];

O.H_MIN_MM = 5;                  % [mm] minimális hasmagasság a teljes sebességtartományban
O.AERO_WITHIN_TRAVEL = true;     % true: az aero berugózás se haladja meg a berugózási tartományt

O.TRAVEL_TOTAL_MM  = 30;         % [mm] kerék összmozgás
O.TRAVEL_BUMP_MM   = 15;         % [mm] berugózás (a maradék = kirugózás)
O.DAMPER_STROKE_MM = 40;         % [mm] damper löket
O.DAMPER_LMAX_MM   = 400;        % [mm] damper hossza teljesen kihúzva

O.MR_MIN = 0.70;                 % MR a teljes kerékúton ebben a sávban maradjon
O.MR_MAX = 1.60;

% Célfüggvény súlyok: J = W_F*(ride freq relatív hiba^2) + Σ_tengely[ W_XI*(xi relatív hiba)^2 + W_ARMS*(A_RMS többlet) ] + jacking + reaktivitás
O.W_F    = 200;
O.W_XI   = 10;
O.W_ARMS = 1;
O.ARMS_POS_MM = [-15 0 15];      % [mm] kerékút-pozíciók, ahol az A_RMS többletet értékeljük

% Jacking és reaktivitás
O.W_JACK      = 0.5;
O.JACK_REF_MM = 2;               % [mm]  !!! ÁLLÍTSD BE - ennyi jacking mellett J_jack = W_JACK
O.JACK_MAX_MM = 8;               % [mm]  kemény felső korlát a jacking-re (Inf = nincs)
O.W_REACT          = 0.1;
O.LAG_REF_DEG      = 8;          % [deg] !!! ÁLLÍTSD BE - ennyi késés mellett J_react = W_REACT
O.SLALOM_V_KMH     = 45;         % [km/h] !!! ÁLLÍTSD BE - szlalom sebesség
O.SLALOM_SPACING_M = 8;          % [m]    !!! ÁLLÍTSD BE - bóják távolsága
O.LAG_MAX_DEG      = 20;         % [deg] kemény felső korlát a fáziskésésre (Inf = nincs)
O.GEO_SHARE_MIN    = 40;         % [%]   a geometriai (azonnali) terhelésátadás minimuma !!! ÁLLÍTSD BE
O.ROLL_GRAD_MAX_DEG_G = 0.5;     % [deg/g] max. dőlésgradiens (első tengely; Inf = nincs)

O.FEAS_TOL = 1e-3;               % megengedett (skálázott) korlátsértés a "Megfelel" ellenőrzésnél

% ---- 0.7 KIMENET ------------------------------------------------------------
O.OUT_DIR = 'Kezi_Eredmenyek';   % a futás-mappák szülőmappája (az optimalizálóé: Optimalizalo_Eredmenyek)
O.RUN_TAG = '';                  % opcionális szöveg a futás-mappa nevének végére

% ---- 0.8 MEGJELENÍTÉS, TRANZIENS ---------------------------------------------
deg_step       = 0.001;               % [deg] dőlésszög lépésköz az ábrákhoz
CONSOLE_POS_MM = [-20 -10 0 10 20];   % [mm] a konzolra kiírt kerékút-pozíciók (damper tábla)
TABLE_POS_MM   = -30:5:30;            % [mm] a "Javasolt Beállítások" fül pozíciói
PEN_CAP        = 50;                  % [%]  a hőtérkép színskálájának felső határa
TAU_STEER      = 0.1;                 % [s]  tranziens: oldalgyorsulás felépülési időállandója
ZETA_ROLL_TRANSIENT = 0.7;            % [-]  tranziens: a roll csillapítási tényező, amivel a tranziens fut

%% =========================================================================
%  0B. SZÁRMAZTATOTT MENNYISÉGEK ÉS ELLENŐRZÉSEK
%  =========================================================================
a            = L * (1 - distrF);                  % [m] CoG távolsága az első tengelytől
b            = L * distrF;                        % [m] CoG távolsága a hátsó tengelytől
a_lat        = a_lat_g * g;                       % [m/s^2]
K_chassis    = K_chassis_deg * 180/pi;            % [Nm/rad]
theta_RA_deg = rad2deg(atan((h_RC_F - h_RC_R) / L));

valid_types = {'none', 'roll', 'heave'};
stab_types  = strsplit(STAB_SETUP, '-');
if numel(stab_types) ~= 2 || ~all(ismember(stab_types, valid_types))
    error('Ismeretlen STAB_SETUP: %s (tengelyenként: %s; formátum: első-hátsó, pl. roll-heave)', STAB_SETUP, strjoin(valid_types, ' | '));
end
stab_type_F = stab_types{1};
stab_type_R = stab_types{2};

% Ténylegesen aktív merevségek (a nem kiválasztott típus 0)
K_ARB_F_act   = strcmp(stab_type_F, 'roll')  * K_ARB_F;
K_ARB_R_act   = strcmp(stab_type_R, 'roll')  * K_ARB_R;
K_HEAVE_F_act = strcmp(stab_type_F, 'heave') * K_HEAVE_F;
K_HEAVE_R_act = strcmp(stab_type_R, 'heave') * K_HEAVE_R;

if (strcmp(stab_type_F, 'heave') && K_HEAVE_F == 0) || (strcmp(stab_type_R, 'heave') && K_HEAVE_R == 0)
    warning('Heave stabilizátor van kiválasztva, de a K_HEAVE értéke 0 - add meg a merevséget.');
end

% Stabilizátor mód tengelyenként (0 = nincs, 1 = roll, 2 = heave; 0 merevségű stabilizátor = nincs)
modeF = find(strcmp(stab_type_F, valid_types)) - 1;
modeR = find(strcmp(stab_type_R, valid_types)) - 1;
if modeF == 1 && K_ARB_F_act   <= 0, modeF = 0; end
if modeF == 2 && K_HEAVE_F_act <= 0, modeF = 0; end
if modeR == 1 && K_ARB_R_act   <= 0, modeR = 0; end
if modeR == 2 && K_HEAVE_R_act <= 0, modeR = 0; end

if any(CLICK_F < 1 | CLICK_F > 6 | CLICK_F ~= round(CLICK_F)) || ...
   any(CLICK_R < 1 | CLICK_R > 6 | CLICK_R ~= round(CLICK_R))
    error('A CLICK_F / CLICK_R értékei egész számok lehetnek 1 és 6 között.');
end

regime_names = {'Low Speed Rebound (LSR)', 'Low Speed Compression (LSC)', ...
                'High Speed Rebound (HSR)', 'High Speed Compression (HSC)'};
regime_short = {'LSR', 'LSC', 'HSR', 'HSC'};

% A modell (optimalizáló-kompatibilis) paraméter-struktúrái
P = struct();
P.valtoszam  = valtoszam;
P.g          = g;
P.m_total    = m_total;
P.distrF     = distrF;
P.m_SM       = m_SM;
P.m_NSM_F    = m_NSM_F;
P.m_NSM_R    = m_NSM_R;
P.L          = L;
P.T_F        = T_F;
P.T_R        = T_R;
P.h_CG_SM    = h_CG_SM;
P.h_CG_total = h_CG_total;
P.h_CG_NSM   = h_CG_NSM;
P.h_RC_F     = h_RC_F;
P.h_RC_R     = h_RC_R;
P.theta_x_CG = theta_x_CG;
P.K_chassis  = K_chassis;
P.rho_air    = rho_air;
P.CLA        = CLA;
P.aero_distr_F = aero_distr_F;
P.v_max_kmh  = v_aero_kmh(end);
P.h_static_F_mm = h_static_F_mm;
P.h_static_R_mm = h_static_R_mm;
P.DYN_HEIGHT = DYN_HEIGHT;
P.k_RC_F     = k_RC_F;
P.k_RC_R     = k_RC_R;
P.v_corner_kmh = v_corner_kmh;
P.a_lat_g    = a_lat_g;
P.K_Tire     = K_Tire;
P.ARB_ROLL_T2_4 = ARB_ROLL_T2_4;
P.C          = C_damper_matrix;
P.regime_short = regime_short;
P.a_lat      = a_lat;
P.b          = b;
P.m1_F = m_SM * distrF / 2;                 % sarki rugózott tömeg
P.m1_R = m_SM * (1 - distrF) / 2;
P.m2_F = m_NSM_F;
P.m2_R = m_NSM_R;
P.dFz_NSM_F  = (2 * m_NSM_F * a_lat * h_CG_NSM) / T_F;
P.dFz_NSM_R  = (2 * m_NSM_R * a_lat * h_CG_NSM) / T_R;
P.F_down_ax_F = 0.5 * rho_air * CLA * (P.v_max_kmh / 3.6)^2 * aero_distr_F;         % [N] első tengely
P.F_down_ax_R = 0.5 * rho_air * CLA * (P.v_max_kmh / 3.6)^2 * (1 - aero_distr_F);
P.F_down_cor_F = 0.5 * rho_air * CLA * (v_corner_kmh / 3.6)^2 * aero_distr_F;         % [N] első tengely kanyarsebességen
P.F_down_cor_R = 0.5 * rho_air * CLA * (v_corner_kmh / 3.6)^2 * (1 - aero_distr_F);
P.fzopt = optimset('Display', 'off', 'TolX', 1e-12);

O.TRAVEL_REB_MM = O.TRAVEL_TOTAL_MM - O.TRAVEL_BUMP_MM;
O.F_SLALOM_HZ   = (O.SLALOM_V_KMH / 3.6) / (2 * O.SLALOM_SPACING_M);   % [Hz] irányváltási frekvencia
O.F_VEC   = linspace(0, 50, 500);       % [Hz] A_RMS frekvenciarács (az optimalizáló végső, finom rácsa)
O.XI_GRID = linspace(0.1, 1.5, 80);     % xi-rács az A_RMS optimumhoz

%% 3. MOTION RATIO GÖRBÉK MEGADÁSA (GUI + EXCEL BETÖLTÉS / MENTÉS)
num_eval = length(eval_pts_mm);
loaded_data = {};
if exist(target_excel, 'file') == 2
    disp(['Célgörbék betöltése Excelből: ', target_excel]);
    try
        loaded_data = readcell(target_excel);
    catch
        disp('Nem sikerült beolvasni az Excelt, alapértelmezett értékek használata.');
    end
end
 
% Initial / default értékek előkészítése
[x_init_1, y_init_1] = get_excel_pts(loaded_data, 2, eval_pts_mm, 0.82);
[x_init_2, y_init_2] = get_excel_pts(loaded_data, 3, eval_pts_mm, 0.85);
[x_init_3, y_init_3] = get_excel_pts(loaded_data, 4, eval_pts_mm, 0.85);
[x_init_4, y_init_4] = get_excel_pts(loaded_data, 5, eval_pts_mm, 0.80);
 
if USE_GUI_FOR_CURVES
    disp('Grafikus célgörbe szerkesztő indítása mind a 4 Motion Ratio-ra...');
    
    [MR_F_func, eval_y_1] = defineTargetCurveGUI('1. Első Főrugó Motion Ratio (MR_F)', ...
        -15, 15, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_1, y_init_1, eval_pts_mm);
        
    [MR_R_func, eval_y_2] = defineTargetCurveGUI('2. Hátsó Főrugó Motion Ratio (MR_R)', ...
        -15, 15, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_2, y_init_2, eval_pts_mm);
        
    [MR_ARB_F_func, eval_y_3] = defineTargetCurveGUI('3. Első stabilizátor Motion Ratio (MR_ARB_F, roll/heave)', ...
        -15, 15, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_3, y_init_3, eval_pts_mm);
        
    [MR_ARB_R_func, eval_y_4] = defineTargetCurveGUI('4. Hátsó stabilizátor Motion Ratio (MR_ARB_R, roll/heave)', ...
        -15, 15, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_4, y_init_4, eval_pts_mm);
else
    MR_F_func     = @(x) interp1(x_init_1, y_init_1, x*1000, 'pchip', 'extrap');
    MR_R_func     = @(x) interp1(x_init_2, y_init_2, x*1000, 'pchip', 'extrap');
    MR_ARB_F_func = @(x) interp1(x_init_3, y_init_3, x*1000, 'pchip', 'extrap');
    MR_ARB_R_func = @(x) interp1(x_init_4, y_init_4, x*1000, 'pchip', 'extrap');
    eval_y_1 = y_init_1; eval_y_2 = y_init_2; eval_y_3 = y_init_3; eval_y_4 = y_init_4;
end
 
% Excel mentés beállítása
out_cell = cell(5, num_eval + 1); out_cell(:) = {''};
out_cell{1, 1} = 'Kerékút_Z_mm';
out_cell(1, 2:num_eval+1) = num2cell(eval_pts_mm);
out_cell{2, 1} = 'MR_Spring_Front';
out_cell(2, 2:num_eval+1) = num2cell(eval_y_1);
out_cell{3, 1} = 'MR_Spring_Rear';
out_cell(3, 2:num_eval+1) = num2cell(eval_y_2);
out_cell{4, 1} = 'MR_ARB_Front';
out_cell(4, 2:num_eval+1) = num2cell(eval_y_3);
out_cell{5, 1} = 'MR_ARB_Rear';
out_cell(5, 2:num_eval+1) = num2cell(eval_y_4);
 
mr_changed = isempty(loaded_data) || ...
    any(abs(eval_y_1(:) - y_init_1(:)) > 1e-9) || any(abs(eval_y_2(:) - y_init_2(:)) > 1e-9) || ...
    any(abs(eval_y_3(:) - y_init_3(:)) > 1e-9) || any(abs(eval_y_4(:) - y_init_4(:)) > 1e-9);
 
if mr_changed
    try
        if ~exist(save_dir, 'dir'), mkdir(save_dir); end
        [~, base_name, ~] = fileparts(target_excel);
        save_excel = fullfile(save_dir, sprintf('%s_%s.xlsx', base_name, datestr(now, 'yyyymmdd_HHMMSS')));
        writecell(out_cell, save_excel);
        disp(['Módosított görbék elmentve új fájlba: ', save_excel]);
    catch
        disp('Nem sikerült elmenteni az új Excel fájlt.');
    end
else
    disp('A görbék nem változtak, nem készült új mentés.');
end

%% 2B. FUTÁS-MAPPA (minden futtatás saját mappát kap, mint az optimalizálónál)
stamp = datestr(now, 'yyyymmdd_HHMMSS');
rcTag = sprintf('RCfix_F%03.0f_R%03.0f', 1000 * h_RC_F, 1000 * h_RC_R);
runName = sprintf('Futas_%s_%s', stamp, rcTag);
if ~isempty(O.RUN_TAG), runName = [runName '_' O.RUN_TAG]; end
runDir = fullfile(O.OUT_DIR, runName);
if ~exist(runDir, 'dir'), mkdir(runDir); end
diary(fullfile(runDir, 'konzol_log.txt'));
Kezi = struct('K_spring_F', K_spring_F, 'K_spring_R', K_spring_R, 'STAB_SETUP', STAB_SETUP, ...
    'K_ARB_F', K_ARB_F, 'K_ARB_R', K_ARB_R, 'K_HEAVE_F', K_HEAVE_F, 'K_HEAVE_R', K_HEAVE_R, ...
    'h_RC_F', h_RC_F, 'h_RC_R', h_RC_R, 'CLICK_F', CLICK_F, 'CLICK_R', CLICK_R, ...
    'eval_pts_mm', eval_pts_mm, 'MR_Spring_Front', eval_y_1(:).', 'MR_Spring_Rear', eval_y_2(:).', ...
    'MR_ARB_Front', eval_y_3(:).', 'MR_ARB_Rear', eval_y_4(:).');
try
    save(fullfile(runDir, 'beallitasok.mat'), 'P', 'O', 'Kezi');
    copyfile([mfilename('fullpath') '.m'], runDir);      % a futtatott script másolata (reprodukálhatóság)
catch
    warning('A beállítások / a script másolatának mentése a futás-mappába nem sikerült.');
end
fprintf('Futás-mappa: %s\n', runDir);
fprintf('RC mód: fix (első %.1f mm, hátsó %.1f mm)\n', 1000 * h_RC_F, 1000 * h_RC_R);

% Kerékmerevség függvények K_wheel(x) [N/m]
K_wheel_F_func = @(x) (K_spring_F * valtoszam) ./ (MR_F_func(x).^2);
K_wheel_R_func = @(x) (K_spring_R * valtoszam) ./ (MR_R_func(x).^2);

% Heave (együttes berugózás) merevség TENGELYENKÉNT [N/m]
K_heave_F_func = @(x) 2 * K_wheel_F_func(x) + K_HEAVE_F_act ./ (MR_ARB_F_func(x).^2);
K_heave_R_func = @(x) 2 * K_wheel_R_func(x) + K_HEAVE_R_act ./ (MR_ARB_R_func(x).^2);
K_heave_F_stat = K_heave_F_func(0);   % [N/m] statikus heave merevség, első tengely
K_heave_R_stat = K_heave_R_func(0);   % [N/m] statikus heave merevség, hátsó tengely

%% 4. MODELL KIÉRTÉKELÉSE (az optimalizáló model_mech / evaluate függvényeivel - ugyanaz a számítás)
% S = a kézi beállítás (az optimalizáló "p" vektorának és "cs" struktúrájának megfelelője;
%     a motion ratio-k itt az Excelből / GUI-ból jövő görbék, függvénykezelőként)
S = struct();
S.kF = K_spring_F;      S.kR = K_spring_R;
S.modeF = modeF;        S.modeR = modeR;
S.KarbF = K_ARB_F_act;  S.KarbR = K_ARB_R_act;
S.KhvF = K_HEAVE_F_act; S.KhvR = K_HEAVE_R_act;
S.hRC_F = h_RC_F;       S.hRC_R = h_RC_R;
S.fSpF = MR_F_func;     S.fSpR = MR_R_func;
S.fAbF = MR_ARB_F_func; S.fAbR = MR_ARB_R_func;
S.clickF = CLICK_F;     S.clickR = CLICK_R;

E = evaluate(S, P, O);          % egyensúly, MN, TLTD, ride, jacking, damper, reaktivitás, korlátok, J
M = E.M;
X = solution_extras(S, P, O);   % hasmagasság (aero), damper út / statikus hossz, roll tengely dőlése
feas = E.maxviol <= O.FEAS_TOL;

% Az ábrák és a későbbi fejezetek által használt mennyiségek a modellből
delta_h_jack   = M.dh_jack;                 % [m] COG emelkedés
h_CG_SM_dyn    = M.hSM;                     % [m] dinamikus CoG (rugózott)
dz_dyn         = M.dz_dyn;                  % [m] rugózott tömeg erőkaria jackinggel
theta_x_RC     = M.theta_x_RC;              % [kg m^2] dőlési inercia a jackinggel megemelt súlyponttal
m1_F = P.m1_F;  m1_R = P.m1_R;
S0 = M.S0;                                  % a dőlésszög-ciklus közös adatai
M_roll_F_in = S0.M_roll_F_in;               % [Nm] első tengelyre jutó dőlőnyomaték
M_roll_R_in = S0.M_roll_R_in;               % [Nm] hátsó tengelyre jutó dőlőnyomaték

%% 4B. DŐLÉSSZÖG-LEFOLYÁS AZ ÁBRÁKHOZ (lépésköz: deg_step; ugyanaz a modell, mint az egyensúlyi pont)
phi_eq_deg_exact = M.phiF_deg;
phi_vec_deg = 0 : deg_step : max(1.5 * phi_eq_deg_exact, 0.5);
phi_vec_rad = deg2rad(phi_vec_deg);
N_steps     = length(phi_vec_rad);

K_wheel_F_vec = zeros(1, N_steps);   K_wheel_R_vec = zeros(1, N_steps);
K_roll_F_vec  = zeros(1, N_steps);   K_roll_R_vec  = zeros(1, N_steps);
K_roll_tot_vec= zeros(1, N_steps);   MN_vec        = zeros(1, N_steps);
TLTD_vec      = zeros(1, N_steps);   f_roll_vec    = zeros(1, N_steps);
f_ride_F_vec  = zeros(1, N_steps);   f_ride_R_vec  = zeros(1, N_steps);
M_res_vec     = zeros(1, N_steps);   phi_R_vec     = zeros(1, N_steps);   % hátsó tengely dőlésszöge
MD_vec        = zeros(1, N_steps);   % tényleges első nyomatékarány
M_F_res_vec   = zeros(1, N_steps);   % első tengely által felvett nyomaték
M_R_res_vec   = zeros(1, N_steps);   % hátsó tengely által felvett nyomaték

for i = 1:N_steps
    phi_F = phi_vec_rad(i);                          % [rad] az ELSŐ tengely dőlésszöge
    [~, Q] = roll_state(phi_F, S0);                  % váz torzióval: első + hátsó tengely
    phi_R  = Q.phR;
    x_F_outer = (T_F / 2) * sin(phi_F);
    x_R_outer = (T_R / 2) * sin(phi_R);

    K_wheel_F_vec(i) = Q.KwF;    K_wheel_R_vec(i) = Q.KwR;
    K_roll_F_vec(i)  = Q.KrF;    K_roll_R_vec(i)  = Q.KrR;
    phi_R_vec(i)     = phi_R;

    f_ride_F_vec(i) = sqrt((Q.KwF + S.KhvF / (2 * mrv(S.fAbF, x_F_outer)^2)) / m1_F) / (2 * pi);
    f_ride_R_vec(i) = sqrt((Q.KwR + S.KhvR / (2 * mrv(S.fAbR, x_R_outer)^2)) / m1_R) / (2 * pi);

    M_F_res_vec(i) = Q.KrF * phi_F;                  % [Nm]
    M_R_res_vec(i) = Q.KrR * phi_R;                  % [Nm]
    M_res_vec(i)   = M_F_res_vec(i) + M_R_res_vec(i);
    K_roll_tot_vec(i) = Q.KrF + Q.KrR;
    MN_vec(i) = 100 * Q.KrF / K_roll_tot_vec(i);

    T_ch_lin  = (S0.M_roll_F_in / Q.KrF - S0.M_roll_R_in / Q.KrR) / (1 / P.K_chassis + 1 / Q.KrF + 1 / Q.KrR);
    MD_vec(i) = (S0.M_roll_F_in - T_ch_lin) / S0.M_roll * 100;

    dFz_el_F = (P.m_SM * a_lat * M.d_perp_dyn / T_F) * (MD_vec(i) / 100);
    dFz_el_R = (P.m_SM * a_lat * M.d_perp_dyn / T_R) * ((100 - MD_vec(i)) / 100);
    tF = M.G.dFz_geom_F + dFz_el_F + P.dFz_NSM_F;
    tR = M.G.dFz_geom_R + dFz_el_R + P.dFz_NSM_R;
    TLTD_vec(i) = 100 * tF / (tF + tR);

    f_roll_vec(i) = sqrt(K_roll_tot_vec(i) / theta_x_RC) / (2 * pi);
end

[~, eq_idx] = min(abs(phi_vec_rad - M.phi_eq_rad));
phi_eq_deg   = phi_vec_deg(eq_idx);                 % első tengely [deg] (rácspont, az ábrák függőleges vonalához)
phi_eq_R_deg = rad2deg(phi_R_vec(eq_idx));          % hátsó tengely [deg]
T_ch_eq      = M_roll_F_in - M_F_res_vec(eq_idx);   % [Nm] váz torziós nyomaték

%% 5. EREDMÉNYEK KIÍRÁSA
modeName = {'nincs', 'roll', 'heave'};
fprintf('=========================================================================\n');
fprintf('  KANYARODÁSI KASZTNIDŐLÉS ÉS ÁTTERHELŐDÉS LEFOLYÁS (a_lat = %.2f G)\n', a_lat_g);
fprintf('=========================================================================\n');
fprintf('Beállítás: főrugó első = %g | hátsó = %g lbs/in | stabilizátor: %s (első: %s | hátsó: %s)\n', ...
    K_spring_F, K_spring_R, STAB_SETUP, modeName{modeF + 1}, modeName{modeR + 1});
fprintf('Stabilizátor merevségek: K_ARB első/hátsó = %.0f / %.0f N/m | K_HEAVE első/hátsó = %.0f / %.0f N/m\n', ...
    K_ARB_F_act, K_ARB_R_act, K_HEAVE_F_act, K_HEAVE_R_act);
fprintf('Jacking hatás: COG emelkedés = %.2f mm | Dinamikus CoG (rugózott) = %.1f mm | F_jack első/hátsó = %.0f / %.0f N\n', ...
    1000 * M.dh_jack, 1000 * h_CG_SM_dyn, M.F_jack_F, M.F_jack_R);
fprintf('Első RC: %5.1f mm | Hátsó RC: %5.1f mm | Roll Axis dőlés: %.2f deg\n', h_RC_F * 1000, h_RC_R * 1000, theta_RA_deg);
fprintf('Dinamikus RC (%.0f km/h, %.1fg, DYN_HEIGHT = %s): első = %.1f mm | hátsó = %.1f mm | CoG elmozdulás = %+.1f mm (aero berugózás: %.1f / %.1f mm)\n', ...
    P.v_corner_kmh, P.a_lat_g, mat2str(logical(P.DYN_HEIGHT)), 1000 * M.hRC_F_dyn, 1000 * M.hRC_R_dyn, 1000 * M.dz_CG, 1000 * M.xaero_cor_F, 1000 * M.xaero_cor_R);
fprintf('Kiszámított egyensúlyi dőlésszög (Steady-State Roll Angle): első = %.3f deg | hátsó = %.3f deg | dőlésgradiens = %.3f deg/g\n', ...
    M.phiF_deg, M.phiR_deg, M.roll_grad);
fprintf('Váz torziós merevség: %.0f Nm/deg | váz elcsavarodás: %.4f deg | váz torziós nyomaték (első->hátsó): %.1f Nm\n', ...
    K_chassis_deg, phi_eq_deg - phi_eq_R_deg, T_ch_eq);
fprintf('Dőlőnyomaték tengelyenként (váz nélkül): első = %.1f Nm | hátsó = %.1f Nm\n', M_roll_F_in, M_roll_R_in);
fprintf('Dőlőnyomaték tengelyenként (váz torzióval): első = %.1f Nm | hátsó = %.1f Nm\n', M_F_res_vec(eq_idx), M_R_res_vec(eq_idx));
fprintf('Statikus heave merevség (tengely): Első = %.1f N/mm | Hátsó = %.1f N/mm\n', K_heave_F_stat / 1000, K_heave_R_stat / 1000);
fprintf('Kiszámított statikus Rugózási Frekvenciák: Első = %.2f Hz | Hátsó = %.2f Hz\n', M.fF, M.fR);
fprintf('Magic Number az egyensúlyi pontban: %.2f %% | tényleges nyomatékmegoszlás (váz torzióval): %.2f %%\n', M.MN, M.MD);
fprintf('Total Load Transfer Distribution (TLTD) az egyensúlyi pontban: %.2f %% | geometriai (azonnali) átadás: %.1f %%\n', M.TLTD, M.GEO_SHARE);
fprintf('Roll Frekvencia az egyensúlyi pontban: %.2f Hz\n', M.f_roll);
fprintf('Ellenőrzés (ábra-rács vs. zárt alak): egyensúlyi dőlés %.4f vs. %.4f deg | MN %.2f vs. %.2f %%\n', ...
    phi_eq_deg, M.phiF_deg, MN_vec(eq_idx), M.MN);
fprintf('=========================================================================\n\n');

fprintf('=========================================================================\n');
fprintf('  ROLL DINAMIKA, REAKTIVITÁS (szlalom: %.0f km/h, %.1f m bójatáv -> %.3f Hz)\n', O.SLALOM_V_KMH, O.SLALOM_SPACING_M, O.F_SLALOM_HZ);
fprintf('=========================================================================\n');
fprintf('Roll zeta: cél-xi alapján %.3f | a beállított click-ekkel %.3f\n', E.Rdt.zeta, E.Rd.zeta);
fprintf('Fáziskésés szlalom frekvencián: cél-xi alapján %.2f deg | a beállított click-ekkel %.2f deg (amplitúdó: %.3f)\n', ...
    E.Rdt.lag_deg, E.Rd.lag_deg, E.Rdt.amp);
fprintf('Hasmagasság %.0f km/h-nál: első = %.1f mm | hátsó = %.1f mm (aero berugózás: %.1f / %.1f mm, min. megengedett: %.1f mm)\n', ...
    P.v_max_kmh, X.h_min_F, X.h_min_R, X.xaero_F, X.xaero_R, O.H_MIN_MM);
fprintf('Damper út a teljes kerékúton: első = %.1f mm | hátsó = %.1f mm (löket: %g mm) | statikus damperhossz*: %.1f / %.1f mm\n', ...
    X.S_F, X.S_R, O.DAMPER_STROKE_MM, X.L_stat_F, X.L_stat_R);
fprintf('Click-ek [LSR LSC HSR HSC]: első = [%s] | hátsó = [%s]\n', num2str(E.DF.click), num2str(E.DR.click));
fprintf('  xi első  = [%s] (cél [%s])\n', num2str(E.DF.xi, '%.2f '), num2str(O.XI_TARGET(:, 1).', '%.2f '));
fprintf('  xi hátsó = [%s] (cél [%s])\n', num2str(E.DR.xi, '%.2f '), num2str(O.XI_TARGET(:, 2).', '%.2f '));
fprintf('  A_RMS többlet az optimumhoz képest (átlag): első = %.1f %% | hátsó = %.1f %%\n', E.DF.arms_pen_mean, E.DR.arms_pen_mean);
fprintf('  Optimalizáló-logika szerint javasolt click: első = [%s] | hátsó = [%s]\n', num2str(E.DF.click_best), num2str(E.DR.click_best));
fprintf('MR függvények (2. fokú illesztés a megadott görbékre; x = kerékút [mm], + = berugózás):\n');
fprintf('  %s\n', mr_curve_text(S.fSpF, 'MR_F',     true, O));
fprintf('  %s\n', mr_curve_text(S.fSpR, 'MR_R',     true, O));
fprintf('  %s\n', mr_curve_text(S.fAbF, 'MR_ARB_F', S.modeF > 0, O));
fprintf('  %s\n', mr_curve_text(S.fAbR, 'MR_ARB_R', S.modeR > 0, O));
fprintf('=========================================================================\n');
fprintf('  KORLÁT-ELLENŐRZÉS (célfüggvény J = %.4f; kisebb a jobb)\n', E.J);
fprintf('=========================================================================\n');
for ic = 1:numel(E.c)
    if E.c(ic) > O.FEAS_TOL
        fprintf('  SÉRTI: %-26s (skálázott sértés: %.4f)\n', E.cnames{ic}, E.c(ic));
    end
end
fprintf('Megfelel (az összes korlát teljesül): %s  (legnagyobb skálázott sértés: %.4f)\n', ternary(feas, 'IGEN', 'NEM'), E.maxviol);
fprintf('=========================================================================\n\n');

%% 7. KIMENETEK (minden a futás-mappába: runDir; ugyanaz a formátum, mint az optimalizálónál)
xlsx_file = fullfile(runDir, sprintf('Optimalis_beallitasok_%s.xlsx', stamp));
[cFit_F, ~]  = curve_fit(S.fSpF, O);   [cFit_R, ~]  = curve_fit(S.fSpR, O);
[cFit_AF, ~] = curve_fit(S.fAbF, O);   [cFit_AR, ~] = curve_fit(S.fAbR, O);

hdr = {'Rang', 'J', 'Megfelel', 'MR megadás', 'Első rugó [lbs/in]', 'Hátsó rugó [lbs/in]', 'Első stab.', 'Hátsó stab.', ...
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
    'MR_F m0 (illesztett)', 'MR_F m1 (illesztett)', 'MR_F m2 (illesztett)', 'MR_R m0 (illesztett)', 'MR_R m1 (illesztett)', 'MR_R m2 (illesztett)', ...
    'MR_ARB_F m0 (illesztett)', 'MR_ARB_F m1 (illesztett)', 'MR_ARB_F m2 (illesztett)', 'MR_ARB_R m0 (illesztett)', 'MR_ARB_R m1 (illesztett)', 'MR_ARB_R m2 (illesztett)', ...
    'Jacking [mm]', 'Jacking az alap-RC-vel [mm]', 'F_jack első [N]', 'F_jack hátsó [N]', ...
    'Dőlésgradiens [deg/g]', 'Geometriai ter.átadás [%]', 'Roll zeta (cél-xi)', 'Roll zeta (tényleges click)', ...
    'Fáziskésés szlalom f-en, cél-xi [deg]', 'Fáziskésés szlalom f-en, tényleges click [deg]', ...
    'Terhelésátadás amplitúdó szlalom f-en [-]', 'Roll tengely dőlése [deg]', ...
    'Javasolt click első LSR', 'Javasolt click első LSC', 'Javasolt click első HSR', 'Javasolt click első HSC', ...
    'Javasolt click hátsó LSR', 'Javasolt click hátsó LSC', 'Javasolt click hátsó HSR', 'Javasolt click hátsó HSC', ...
    'J a javasolt click-ekkel'};
out = cell(2, numel(hdr));
out(1, :) = hdr;
out(2, :) = [{1, E.J, ternary(feas, 'igen', 'NEM'), 'görbe (Excel/GUI)', S.kF, S.kR, modeName{S.modeF + 1}, modeName{S.modeR + 1}, ...
    1000 * S.hRC_F, 1000 * S.hRC_R, S.KarbF, S.KarbR, S.KhvF, S.KhvR}, num2cell(E.DF.click), num2cell(E.DR.click), ...
    {M.phiF_deg, M.phiR_deg, M.TLTD, M.MN, M.MD, M.fF, M.fR, M.f_roll}, ...
    num2cell(E.DF.xi), num2cell(E.DR.xi), ...
    {E.DF.arms_pen_mean, E.DR.arms_pen_mean, X.h_min_F, X.h_min_R, X.xaero_F, X.xaero_R, ...
     X.S_F, X.S_R, O.DAMPER_STROKE_MM - X.S_F, O.DAMPER_STROKE_MM - X.S_R, X.L_stat_F, X.L_stat_R, ...
     mr_curve_text(S.fSpF, 'MR_F', true, O), mr_curve_text(S.fSpR, 'MR_R', true, O), ...
     mr_curve_text(S.fAbF, 'MR_ARB_F', S.modeF > 0, O), mr_curve_text(S.fAbR, 'MR_ARB_R', S.modeR > 0, O)}, ...
    num2cell([cFit_F, cFit_R, cFit_AF, cFit_AR]), ...
    {1000 * M.dh_jack, X.dh_jack_base_mm, M.F_jack_F, M.F_jack_R, ...
     M.roll_grad, M.GEO_SHARE, E.Rdt.zeta, E.Rd.zeta, E.Rdt.lag_deg, E.Rd.lag_deg, E.Rdt.amp, X.RA_incl_deg}, ...
    num2cell(E.DF.click_best), num2cell(E.DR.click_best), {E.J_best_clicks}];
writecell(out, xlsx_file, 'Sheet', 'Optimalis_beallitasok');

% --- Roll center lap ---
rcHdr = {'Rang', 'RC mód', 'RC első [mm]', 'RC hátsó [mm]', 'Alap RC első [mm]', 'Alap RC hátsó [mm]', 'Roll tengely dőlése [deg]', ...
    'Jacking [mm]', 'Jacking az alap-RC-vel [mm]', 'Geometriai ter.átadás [%]', 'Fáziskésés szlalom f-en [deg]', ...
    'Dinamikus RC első [mm]', 'Dinamikus RC hátsó [mm]', 'CoG elmozdulás (jacking-aero) [mm]'};
rcOut = [rcHdr; {1, 'fix', 1000 * S.hRC_F, 1000 * S.hRC_R, 1000 * h_RC_F, 1000 * h_RC_R, X.RA_incl_deg, ...
    1000 * M.dh_jack, X.dh_jack_base_mm, M.GEO_SHARE, E.Rd.lag_deg, ...
    1000 * M.hRC_F_dyn, 1000 * M.hRC_R_dyn, 1000 * M.dz_CG}];
writecell(rcOut, xlsx_file, 'Sheet', 'Roll_center');

% --- Strukturális átadási lap: ARB / Z-bar motion ratio + droplinken mérhető célmerevség ---
[st_hdr, st_rows] = handover_table(1, S, P, O);
writecell([st_hdr; st_rows], xlsx_file, 'Sheet', 'Strukturalis_atadas');

% --- Bemenetek lap ---
inp = {
    'Kézi beállítás: főrugó első / hátsó [lbs/in]', sprintf('%g / %g', K_spring_F, K_spring_R);
    'Stabilizátor setup (első-hátsó)',      STAB_SETUP;
    'K_ARB első / hátsó [N/m]',             sprintf('%.0f / %.0f', K_ARB_F_act, K_ARB_R_act);
    'K_HEAVE első / hátsó [N/m]',           sprintf('%.0f / %.0f', K_HEAVE_F_act, K_HEAVE_R_act);
    'Click első [LSR LSC HSR HSC]',         sprintf('%d ', CLICK_F);
    'Click hátsó [LSR LSC HSR HSC]',        sprintf('%d ', CLICK_R);
    'MR görbék forrása',                    ternary(USE_GUI_FOR_CURVES, ['GUI (alap: ' target_excel ')'], target_excel);
    'Egyensúlyi dőlésszög tartomány [deg]', sprintf('%.3f ... %.3f', O.PHI_RANGE_DEG);
    'TLTD tartomány [%]',                   sprintf('%.2f ... %.2f', O.TLTD_RANGE);
    'MN tartomány [%]',                     sprintf('%.2f ... %.2f', O.MN_RANGE);
    'Cél ride freq első / hátsó [Hz]',      sprintf('%.2f / %.2f', O.F_RIDE_TARGET);
    'Cél xi első [LSR LSC HSR HSC]',        sprintf('%.2f ', O.XI_TARGET(:, 1));
    'Cél xi hátsó [LSR LSC HSR HSC]',       sprintf('%.2f ', O.XI_TARGET(:, 2));
    'Min. hasmagasság [mm]',                O.H_MIN_MM;
    'Kerékút összesen / berugózás [mm]',    sprintf('%g / %g', O.TRAVEL_TOTAL_MM, O.TRAVEL_BUMP_MM);
    'Damper löket / max hossz [mm]',        sprintf('%g / %g', O.DAMPER_STROKE_MM, O.DAMPER_LMAX_MM);
    'Súlyok W_F / W_XI / W_ARMS',           sprintf('%g / %g / %g', O.W_F, O.W_XI, O.W_ARMS);
    'A_RMS értékelési pozíciók [mm]',       sprintf('%g ', O.ARMS_POS_MM);
    'ARB roll-merevség T^2/4 szorzóval',    ternary(P.ARB_ROLL_T2_4, 'igen', 'nem');
    'RC optimalizálás',                     'nem (fix RC, kézi)';
    'Alap RC első / hátsó [mm]',            sprintf('%.1f / %.1f', 1000 * P.h_RC_F, 1000 * P.h_RC_R);
    'Dinamikus CoG/RC: be / k_RC F-R / v_kanyar [km/h]', sprintf('%s / %.2f - %.2f / %g', mat2str(logical(P.DYN_HEIGHT)), P.k_RC_F, P.k_RC_R, P.v_corner_kmh);
    'Jacking: súly / ref [mm] / max [mm]',  sprintf('%g / %g / %g', O.W_JACK, O.JACK_REF_MM, O.JACK_MAX_MM);
    'Reaktivitás: súly / ref [deg] / max késés [deg]', sprintf('%g / %g / %g', O.W_REACT, O.LAG_REF_DEG, O.LAG_MAX_DEG);
    'Szlalom frekvencia [Hz]',              sprintf('%.3f (%.0f km/h, %.1f m bójatáv)', O.F_SLALOM_HZ, O.SLALOM_V_KMH, O.SLALOM_SPACING_M);
    'Geometriai ter.átadás minimum [%]',    O.GEO_SHARE_MIN;
    'Max. dőlésgradiens [deg/g]',           O.ROLL_GRAD_MAX_DEG_G;
    'Nyomtáv első / hátsó [m]',             sprintf('%.3f / %.3f', T_F, T_R);
    'CLA [m^2] / aero első arány',          sprintf('%.2f / %.2f', CLA, aero_distr_F);
    '* Stat. damperhossz',                  'ha a damper teljes kirugózásnál éppen teljesen kihúzott (L_max); megengedett tartomány: L_max - löket + S_bump ... L_max - S_reb'};
writecell([{'Paraméter', 'Érték'}; inp], xlsx_file, 'Sheet', 'Bemenetek');
fprintf('Eredmények (Excel): %s\n', xlsx_file);

% --- RC összefoglaló szövegfájl ---
fid = fopen(fullfile(runDir, 'RC_osszefoglalo.txt'), 'w', 'n', 'UTF-8');
if fid > 0
    fprintf(fid, 'ROLL CENTER ÖSSZEFOGLALÓ - futás: %s\n', stamp);
    fprintf(fid, 'RC mód: fix (kézi)\n');
    fprintf(fid, 'RC (h_RC_F / h_RC_R): első %.1f mm, hátsó %.1f mm\n', 1000 * h_RC_F, 1000 * h_RC_R);
    fprintf(fid, '\n%-5s %-10s %-10s %-13s %-15s %-13s %-10s\n', 'Rang', 'RC_F [mm]', 'RC_R [mm]', 'Jacking [mm]', 'Jack alap-RC', 'Geo átadás %', 'Késés [°]');
    fprintf(fid, '%-5d %-10.1f %-10.1f %-13.2f %-15.2f %-13.1f %-10.2f\n', 1, 1000 * S.hRC_F, 1000 * S.hRC_R, ...
        1000 * M.dh_jack, X.dh_jack_base_mm, M.GEO_SHARE, E.Rd.lag_deg);
    fclose(fid);
end

% --- baszogep-formátumú MR-fájl (a használt görbék) + strukturális adatlap ---
mr_out = cell(5, num_eval + 1);
mr_out{1, 1} = 'Kerékút_Z_mm';
mr_out(1, 2:num_eval+1) = num2cell(eval_pts_mm);
mr_names = {'MR_Spring_Front', 'MR_Spring_Rear', 'MR_ARB_Front', 'MR_ARB_Rear'};
mr_vals  = {eval_y_1, eval_y_2, eval_y_3, eval_y_4};
for k = 1:4
    mr_out{k + 1, 1} = mr_names{k};
    mr_out(k + 1, 2:num_eval+1) = num2cell(reshape(mr_vals{k}, 1, []));
end
writecell(mr_out, fullfile(runDir, 'MR_rang1.xlsx'));
write_handover_txt(fullfile(runDir, 'Strukturalis_atadas_rang1.txt'), 1, S, E, X, P, O, stamp);
fprintf('MR-fájl (baszogep formátum, nevezd át Célgörbe_MotionRatios.xlsx-re) és strukturális adatlap: %s\n\n', runDir);
%% 5B. AERODINAMIKA - HASMAGASSÁG-VÁLTOZÁS A SEBESSÉG FÜGGVÉNYÉBEN
F_down_tot = 0.5 * rho_air * CLA * (v_aero_kmh / 3.6).^2;   % [N]
F_down_F   = F_down_tot * aero_distr_F;                     % [N]
F_down_R   = F_down_tot * (1 - aero_distr_F);               % [N]
 
x_grid   = linspace(0, 0.060, 601);                         % [m]
F_ax_F   = cumtrapz(x_grid, K_heave_F_func(x_grid));        % [N]
F_ax_R   = cumtrapz(x_grid, K_heave_R_func(x_grid));        % [N]
x_aero_F = interp1(F_ax_F, x_grid, F_down_F, 'pchip', 'extrap');
x_aero_R = interp1(F_ax_R, x_grid, F_down_R, 'pchip', 'extrap');
 
dh_F_mm  = -1000 * x_aero_F;                                % [mm]
dh_R_mm  = -1000 * x_aero_R;                                % [mm]
h_F_mm   = h_static_F_mm + dh_F_mm;                         % [mm]
h_R_mm   = h_static_R_mm + dh_R_mm;                         % [mm]
 
K_heave_F_v = K_heave_F_func(x_aero_F);                     % [N/m]
K_heave_R_v = K_heave_R_func(x_aero_R);
 
if max(abs([dh_F_mm dh_R_mm])) > max(eval_pts_mm)
    warning('A hasmagasság-változás meghaladja a Motion Ratio görbe tartományát (%d mm), a görbe extrapolálva van.', max(eval_pts_mm));
end
if any(h_F_mm <= 0) || any(h_R_mm <= 0)
    warning('A hasmagasság eléri a talajt (<= 0 mm) a vizsgált sebességtartományban.');
end
 
fprintf('AERO (CLA = %.2f m^2, első arány = %.0f %%): %.0f km/h-nál leszorítóerő = %.0f N\n', ...
    CLA, aero_distr_F * 100, v_aero_kmh(end), F_down_tot(end));
fprintf('Hasmagasság: statikus első = %.1f mm | hátsó = %.1f mm  ->  %.0f km/h-nál első = %.1f mm (%.1f) | hátsó = %.1f mm (%.1f)\n', ...
    h_static_F_mm, h_static_R_mm, v_aero_kmh(end), h_F_mm(end), dh_F_mm(end), h_R_mm(end), dh_R_mm(end));

%% 5C. JACKING HATÁS PARAMÉTERES LEFOLYÁSA (az optimalizáló jacking modelljével: heave stab. + gumi-sorosítás)
ay_vec = linspace(0, a_lat, 100);
h_CG_dyn_vec = zeros(size(ay_vec));

for i = 1:length(ay_vec)
    Fy_c = P.m_total * ay_vec(i);
    dh_c = 0;                                          % jacking fixpont-iteráció a dinamikus RC-vel
    for it = 1:6
        hF_c = h_RC_F + P.k_RC_F * P.DYN_HEIGHT * (dh_c - M.xaero_cor_F);
        hR_c = h_RC_R + P.k_RC_R * P.DYN_HEIGHT * (dh_c - M.xaero_cor_R);
        dh_c = (Fy_c * distrF * (hF_c / (T_F / 2)) + Fy_c * (1 - distrF) * (hR_c / (T_R / 2))) / M.Kride_tot;
    end
    h_CG_dyn_vec(i) = h_CG_total + dh_c;               % csak a jacking emelkedése (az aero lesüllyedés nélkül)
end

%% ========================================================================
%  6. EGYSÉGES TELJES KÉPERNYŐS FIGURÁK ÉS LAPOK (UITABGROUP) LÉTREHOZÁSA
%  ========================================================================
main_fig = figure('Name', 'Formula Student Roll & Damping Analízis', ...
    'NumberTitle', 'off', 'WindowState', 'maximized');
tab_group = uitabgroup(main_fig);

% --- TAB 1: Jacking Hatás ---
tab_jack = uitab(tab_group, 'Title', 'Jacking Hatás');
ax_jack  = axes('Parent', tab_jack);
plot(ax_jack, ay_vec / g, h_CG_dyn_vec * 1000, 'LineWidth', 1.5);
xlabel(ax_jack, 'Oldalgyorsulás [G]');
ylabel(ax_jack, 'Dinamikus Súlypontmagasság h_{CG} [mm]');
title(ax_jack, 'Jacking Hatás miatti Súlypontemelkedés az Oldalgyorsulás Függvényében');
grid(ax_jack, 'on');

% --- TAB 2: Kanyarodási Kasztnidőlés Analízis ---
tab_roll = uitab(tab_group, 'Title', 'Kasztnidőlés Analízis');

subplot(2, 2, 1, 'Parent', tab_roll);
plot(phi_vec_deg, K_wheel_F_vec / 1000, 'b-', 'LineWidth', 2, 'DisplayName', 'Első Kerékmerevség (K_{wheel,F})');
hold on; grid on;
plot(phi_vec_deg, K_wheel_R_vec / 1000, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó Kerékmerevség (K_{wheel,R})');
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'DisplayName', sprintf('Egyensúlyi Dőlés = %.2f°', phi_eq_deg));
xlabel('Első tengely dőlésszöge \phi_F [fok] (fél tized fokos lépésekben)', 'FontWeight', 'bold');
ylabel('Kerékmerevség K_{wheel} [kN/m]', 'FontWeight', 'bold');
title('Kerékmerevségek Változása a Dőlésszög Függvényében', 'FontWeight', 'bold');
legend('Location', 'best');

subplot(2, 2, 2, 'Parent', tab_roll);
plot(phi_vec_deg, MN_vec, 'm-', 'LineWidth', 2, 'DisplayName', 'Magic Number (MN)');
hold on; grid on;
plot(phi_vec_deg, MD_vec, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Tényleges nyomatékmegoszlás (váz torzióval)');
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'DisplayName', sprintf('Egyensúlyi Dőlés = %.2f°', phi_eq_deg));
yline(MN_vec(eq_idx), 'm:', 'LineWidth', 1.2, 'DisplayName', sprintf('Egyensúlyi MN = %.2f%%', MN_vec(eq_idx)));
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('Magic Number MN [%]', 'FontWeight', 'bold');
title('Dőlési Merevségeloszlás (Magic Number) Lefolyása', 'FontWeight', 'bold');
legend('Location', 'best');

subplot(2, 2, 3, 'Parent', tab_roll);
plot(phi_vec_deg, TLTD_vec, 'g-', 'LineWidth', 2, 'DisplayName', 'TLTD (Első tengely arány)');
hold on; grid on;
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'DisplayName', sprintf('Egyensúlyi Dőlés = %.2f°', phi_eq_deg));
yline(TLTD_vec(eq_idx), 'g:', 'LineWidth', 1.2, 'DisplayName', sprintf('Egyensúlyi TLTD = %.2f%%', TLTD_vec(eq_idx)));
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('TLTD [%]', 'FontWeight', 'bold');
title('Teljes Átterhelődés-eloszlás (TLTD) Lefolyása', 'FontWeight', 'bold');
legend('Location', 'best');

subplot(2, 2, 4, 'Parent', tab_roll);
plot(phi_vec_deg, f_roll_vec, 'c-', 'LineWidth', 2, 'DisplayName', 'Roll Frekvencia (f_{roll})');
hold on; grid on;
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'DisplayName', sprintf('Egyensúlyi Dőlés = %.2f°', phi_eq_deg));
yline(f_roll_vec(eq_idx), 'c:', 'LineWidth', 1.2, 'DisplayName', sprintf('Egyensúlyi f_{roll} = %.2f Hz', f_roll_vec(eq_idx)));
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('Sajátfrekvencia f_{roll} [Hz]', 'FontWeight', 'bold');
title('Dőlési Sajátfrekvencia Változása', 'FontWeight', 'bold');
legend('Location', 'best');

sgtitle(tab_roll, sprintf('Kanyar Modell Analízis (a_{lat} = %.2f G, GUI-val megadott MR Görbékkel)', a_lat_g), 'FontWeight', 'bold', 'FontSize', 12);

% --- TAB 3: Aerodinamika ---
tab_aero = uitab(tab_group, 'Title', 'Aerodinamika');

subplot(2, 2, 1, 'Parent', tab_aero);
plot(v_aero_kmh, h_F_mm, 'b-',  'LineWidth', 2, 'DisplayName', 'Első hasmagasság');
hold on; grid on;
plot(v_aero_kmh, h_R_mm, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó hasmagasság');
yline(0, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Talaj');
xlabel('Sebesség v [km/h]', 'FontWeight', 'bold');
ylabel('Hasmagasság [mm]', 'FontWeight', 'bold');
title(sprintf('Hasmagasság (statikus: első %.0f mm, hátsó %.0f mm)', h_static_F_mm, h_static_R_mm), 'FontWeight', 'bold');
legend('Location', 'best');

subplot(2, 2, 2, 'Parent', tab_aero);
plot(v_aero_kmh, dh_F_mm, 'b-',  'LineWidth', 2, 'DisplayName', 'Első');
hold on; grid on;
plot(v_aero_kmh, dh_R_mm, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó');
xlabel('Sebesség v [km/h]', 'FontWeight', 'bold');
ylabel('Hasmagasság-változás [mm] (negatív = lejjebb ül)', 'FontWeight', 'bold');
title('Hasmagasság-változás a Sebesség Függvényében', 'FontWeight', 'bold');
legend('Location', 'best');

subplot(2, 2, 3, 'Parent', tab_aero);
plot(v_aero_kmh, F_down_tot, 'k-',  'LineWidth', 2, 'DisplayName', 'Összes');
hold on; grid on;
plot(v_aero_kmh, F_down_F, 'b-',  'LineWidth', 1.5, 'DisplayName', 'Első tengely');
plot(v_aero_kmh, F_down_R, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Hátsó tengely');
xlabel('Sebesség v [km/h]', 'FontWeight', 'bold');
ylabel('Leszorítóerő [N]', 'FontWeight', 'bold');
title(sprintf('Leszorítóerő (CLA = %.2f m^2, első arány = %.0f%%)', CLA, aero_distr_F * 100), 'FontWeight', 'bold');
legend('Location', 'best');

subplot(2, 2, 4, 'Parent', tab_aero);
plot(v_aero_kmh, K_heave_F_v / 1000, 'b-',  'LineWidth', 2, 'DisplayName', 'Első tengely');
hold on; grid on;
plot(v_aero_kmh, K_heave_R_v / 1000, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó tengely');
xlabel('Sebesség v [km/h]', 'FontWeight', 'bold');
ylabel('Heave merevség [N/mm]', 'FontWeight', 'bold');
title(sprintf('Heave Merevség a Munkapontban (setup: %s)', STAB_SETUP), 'FontWeight', 'bold');
legend('Location', 'best');

%% ========================================================================
%  7. CSILLAPÍTÁS - SEGÉDADATOK (a beállítások a fájl elején, a 0. fejezetben)
%  ========================================================================
f_vec = O.F_VEC;                     % [Hz]  A_RMS frekvenciatartománya

MR_D_F_func = MR_F_func;
MR_D_R_func = MR_R_func;

m2_F = m_NSM_F;   % [kg]
m2_R = m_NSM_R;   % [kg]

c_sel_F = zeros(1, 4); c_sel_R = zeros(1, 4);
for r = 1:4
    c_sel_F(r) = C_damper_matrix(r, CLICK_F(r));
    c_sel_R(r) = C_damper_matrix(r, CLICK_R(r));
end

%% ========================================================================
%  7A. CSILLAPÍTÁS A DŐLÉSSZÖG FÜGGVÉNYÉBEN
%  ========================================================================
x_F_vec = reshape((T_F / 2) * sin(phi_vec_rad), 1, []);
x_R_vec = reshape((T_R / 2) * sin(phi_R_vec),   1, []);
 
inv_MR2_F = (reshape(1 ./ MR_D_F_func( x_F_vec).^2, 1, []) + reshape(1 ./ MR_D_F_func(-x_F_vec).^2, 1, [])) / 2;
inv_MR2_R = (reshape(1 ./ MR_D_R_func( x_R_vec).^2, 1, []) + reshape(1 ./ MR_D_R_func(-x_R_vec).^2, 1, [])) / 2;
 
c_wh_F = c_sel_F(:) * inv_MR2_F;
c_wh_R = c_sel_R(:) * inv_MR2_R;
 
xi_F_vec = c_wh_F ./ (4 * pi * m1_F * f_ride_F_vec);
xi_R_vec = c_wh_R ./ (4 * pi * m1_R * f_ride_R_vec);
 
c_wh_LS_F = (c_wh_F(1, :) + c_wh_F(2, :)) / 2;   c_wh_HS_F = (c_wh_F(3, :) + c_wh_F(4, :)) / 2;
c_wh_LS_R = (c_wh_R(1, :) + c_wh_R(2, :)) / 2;   c_wh_HS_R = (c_wh_R(3, :) + c_wh_R(4, :)) / 2;
 
C_heave_LS_F = 2 * c_wh_LS_F;   C_heave_HS_F = 2 * c_wh_HS_F;
C_heave_LS_R = 2 * c_wh_LS_R;   C_heave_HS_R = 2 * c_wh_HS_R;
 
C_roll_LS_F = c_wh_LS_F * T_F^2 / 2;   C_roll_HS_F = c_wh_HS_F * T_F^2 / 2;
C_roll_LS_R = c_wh_LS_R * T_R^2 / 2;   C_roll_HS_R = c_wh_HS_R * T_R^2 / 2;
C_roll_LS_tot = C_roll_LS_F + C_roll_LS_R;
C_roll_HS_tot = C_roll_HS_F + C_roll_HS_R;
 
zeta_roll_LS = C_roll_LS_tot ./ (2 * sqrt(K_roll_tot_vec * theta_x_RC));
zeta_roll_HS = C_roll_HS_tot ./ (2 * sqrt(K_roll_tot_vec * theta_x_RC));
 
fprintf('=========================================================================\n');
fprintf('  CSILLAPÍTÁS AZ EGYENSÚLYI DŐLÉSNÉL (phi_F = %.3f deg)\n', phi_eq_deg);
fprintf('=========================================================================\n');
fprintf('Beállított clickek [LSR LSC HSR HSC]: Első = [%s] | Hátsó = [%s]\n', num2str(CLICK_F), num2str(CLICK_R));
fprintf('Ride frekvencia: Első = %.2f Hz | Hátsó = %.2f Hz | Roll frekvencia = %.2f Hz\n', ...
    f_ride_F_vec(eq_idx), f_ride_R_vec(eq_idx), f_roll_vec(eq_idx));
fprintf('%-6s | xi Első (cél) | xi Hátsó (cél)\n', 'Rezsim');
for r = 1:4
    fprintf('%-6s |  %5.2f (%.2f)  |  %5.2f (%.2f)\n', regime_short{r}, xi_F_vec(r, eq_idx), O.XI_TARGET(r, 1), xi_R_vec(r, eq_idx), O.XI_TARGET(r, 2));
end
fprintf('Heave csillapítás LS: Első = %.0f | Hátsó = %.0f N*s/m   ||   HS: Első = %.0f | Hátsó = %.0f N*s/m\n', ...
    C_heave_LS_F(eq_idx), C_heave_LS_R(eq_idx), C_heave_HS_F(eq_idx), C_heave_HS_R(eq_idx));
fprintf('Roll csillapítás LS: össz = %.0f Nm*s/rad (zeta = %.3f)   ||   HS: össz = %.0f Nm*s/rad (zeta = %.3f)\n', ...
    C_roll_LS_tot(eq_idx), zeta_roll_LS(eq_idx), C_roll_HS_tot(eq_idx), zeta_roll_HS(eq_idx));
fprintf('=========================================================================\n\n');
 
col_reg = [0 0.45 0.74; 0.85 0.33 0.10; 0 0.45 0.74; 0.85 0.33 0.10];
ls_reg  = {'-', '-', '--', '--'};

% --- TAB 4: Csillapítás a dőlésszög függvényében ---
tab_damp_roll = uitab(tab_group, 'Title', 'Csillapítás Dőlésnél');

subplot(2, 3, 1, 'Parent', tab_damp_roll);
plot(phi_vec_deg, f_ride_F_vec, 'b-',  'LineWidth', 2, 'DisplayName', 'Első f_{ride}'); hold on; grid on;
plot(phi_vec_deg, f_ride_R_vec, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó f_{ride}');
plot(phi_vec_deg, f_roll_vec,   'c-',  'LineWidth', 2, 'DisplayName', 'f_{roll}');
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('Frekvencia [Hz]', 'FontWeight', 'bold');
title('Ride és Roll Sajátfrekvencia', 'FontWeight', 'bold');
legend('Location', 'best');
 
for ax_i = 1:2
    subplot(2, 3, 1 + ax_i, 'Parent', tab_damp_roll); hold on; grid on;
    if ax_i == 1, xi_plot = xi_F_vec; ax_name = 'Első tengely'; else, xi_plot = xi_R_vec; ax_name = 'Hátsó tengely'; end
    for r = 1:4
        plot(phi_vec_deg, xi_plot(r, :), ls_reg{r}, 'Color', col_reg(r, :), 'LineWidth', 2, 'DisplayName', regime_short{r});
        yline(O.XI_TARGET(r, ax_i), ':', 'Color', col_reg(r, :), 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
    ylabel('Relatív csillapítás \xi [-]', 'FontWeight', 'bold');
    title(sprintf('Heave Damping Ratio - %s (pontozott: cél)', ax_name), 'FontWeight', 'bold');
    legend('Location', 'best');
end
 
subplot(2, 3, 4, 'Parent', tab_damp_roll);
plot(phi_vec_deg, C_heave_LS_F, 'b-',  'LineWidth', 2, 'DisplayName', 'Első LS'); hold on; grid on;
plot(phi_vec_deg, C_heave_HS_F, 'b--', 'LineWidth', 2, 'DisplayName', 'Első HS');
plot(phi_vec_deg, C_heave_LS_R, 'r-',  'LineWidth', 2, 'DisplayName', 'Hátsó LS');
plot(phi_vec_deg, C_heave_HS_R, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó HS');
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('Heave csillapítás [N s/m]', 'FontWeight', 'bold');
title('Heave Damping (tengelyenként, 2 kerék)', 'FontWeight', 'bold');
legend('Location', 'best');
 
subplot(2, 3, 5, 'Parent', tab_damp_roll);
plot(phi_vec_deg, C_roll_LS_F,   'b-',  'LineWidth', 1.8, 'DisplayName', 'Első LS'); hold on; grid on;
plot(phi_vec_deg, C_roll_HS_F,   'b--', 'LineWidth', 1.8, 'DisplayName', 'Első HS');
plot(phi_vec_deg, C_roll_LS_R,   'r-',  'LineWidth', 1.8, 'DisplayName', 'Hátsó LS');
plot(phi_vec_deg, C_roll_HS_R,   'r--', 'LineWidth', 1.8, 'DisplayName', 'Hátsó HS');
plot(phi_vec_deg, C_roll_LS_tot, 'k-',  'LineWidth', 2.5, 'DisplayName', 'Össz LS');
plot(phi_vec_deg, C_roll_HS_tot, 'k--', 'LineWidth', 2.5, 'DisplayName', 'Össz HS');
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('Roll csillapítás [Nm s/rad]', 'FontWeight', 'bold');
title('Roll Damping', 'FontWeight', 'bold');
legend('Location', 'best', 'NumColumns', 2);
 
subplot(2, 3, 6, 'Parent', tab_damp_roll);
plot(phi_vec_deg, zeta_roll_LS, 'm-',  'LineWidth', 2, 'DisplayName', 'Low speed'); hold on; grid on;
plot(phi_vec_deg, zeta_roll_HS, 'm--', 'LineWidth', 2, 'DisplayName', 'High speed');
xline(phi_eq_deg, 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xlabel('Első tengely dőlésszöge \phi_F [fok]', 'FontWeight', 'bold');
ylabel('Roll relatív csillapítás \zeta_{roll} [-]', 'FontWeight', 'bold');
title('Roll Damping Ratio', 'FontWeight', 'bold');
legend('Location', 'best');
 
sgtitle(tab_damp_roll, sprintf('Csillapítások a Dőlés Függvényében (Első click [%s], Hátsó click [%s])', num2str(CLICK_F), num2str(CLICK_R)), ...
    'FontWeight', 'bold', 'FontSize', 12);
 
%% ========================================================================
%  7B. DAMPER SETUP ANALÍZIS A TELJES KERÉKÚTON
%  ========================================================================
x_d_mm = eval_pts_mm(:).';     % [mm]
x_d_m  = x_d_mm / 1000;        % [m]
 
Kwh_F_eff = @(x) K_wheel_F_func(x) + K_HEAVE_F_act ./ (2 * MR_ARB_F_func(x).^2);
Kwh_R_eff = @(x) K_wheel_R_func(x) + K_HEAVE_R_act ./ (2 * MR_ARB_R_func(x).^2);
 
disp('Damper analízis a teljes kerékúton (A_RMS minden kerékút-pozícióra, click-re és rezsimre)...');
tic;
RF = analyze_axle_travel(m1_F, m2_F, MR_D_F_func, Kwh_F_eff, C_damper_matrix, O.XI_TARGET(:, 1), K_Tire, f_vec, x_d_m);
RR = analyze_axle_travel(m1_R, m2_R, MR_D_R_func, Kwh_R_eff, C_damper_matrix, O.XI_TARGET(:, 2), K_Tire, f_vec, x_d_m);
fprintf('Kész (%.1f s).\n\n', toc);
 
fprintf('=========================================================================\n');
fprintf('  DAMPER SETUP A KERÉKÚTON - jelmagyarázat\n');
fprintf('  ^ = a cél xi-hez legközelebbi click | * = minimális A_RMS click | # = mindkettő\n');
fprintf('  dA_RMS = az A_RMS többlete az adott pozícióhoz tartozó, elméletileg optimális xi-hez képest\n');
fprintf('=========================================================================\n');
print_travel_table('ELSŐ TENGELY',  RF, x_d_mm, O.XI_TARGET(:, 1), regime_short, CLICK_F, CONSOLE_POS_MM);
print_travel_table('HÁTSÓ TENGELY', RR, x_d_mm, O.XI_TARGET(:, 2), regime_short, CLICK_R, CONSOLE_POS_MM);
fprintf('\n');

%% --- CSILLAPÍTÁS PONTOS SZÁMÍTÁSA A BEÁLLÍTOTT DAMPER PARAMÉTEREKBŐL ---
c_damper_F = (c_sel_F(1) + c_sel_F(2)) / 2; % [Ns/m] Első damper (LSR+LSC átlag)
c_damper_R = (c_sel_R(1) + c_sel_R(2)) / 2; % [Ns/m] Hátsó damper (LSR+LSC átlag)

MR_F0 = MR_F_func(0);
MR_R0 = MR_R_func(0);

c_wheel_F = c_damper_F / (MR_F0)^2;
c_wheel_R = c_damper_R / (MR_R0)^2;

c_roll = 0.5 * c_wheel_F * (T_F)^2 + 0.5 * c_wheel_R * (T_R)^2;

K_roll_eq  = K_roll_tot_vec(eq_idx);          
I_xx_RC    = theta_x_RC;                      
c_roll_crit = 2 * sqrt(K_roll_eq * I_xx_RC);
zeta_roll   = c_roll / c_roll_crit;

fprintf('Roll csillapítás a beállított damper clickekből: c_roll = %.1f Nms/rad | zeta_roll = %.3f\n', c_roll, zeta_roll);

%% --- TRANZIENS (IDŐBELI) ÁTTERHELŐDÉS MODELL ---
t = 0:0.01:1.0;                 % [s] Szimulációs idő
tau_steer = TAU_STEER;          % [s] Oldalgyorsulás felépülési időállandója (a fájl elején állítható)
a_lat_t = a_lat * (1 - exp(-t/tau_steer)); % Időben felépülő oldalgyorsulás [m/s^2]

zeta_roll = ZETA_ROLL_TRANSIENT;   % a tranzienshez használt roll csillapítási tényező (a fájl elején állítható)
C_roll = 2 * zeta_roll * sqrt(K_roll_eq * theta_x_RC);

phi_t     = zeros(size(t));
phi_dot_t = zeros(size(t));
for k = 1:(length(t)-1)
    dt = t(k+1) - t(k);
    M_roll_t = m_SM * a_lat_t(k) * dz_dyn; 

    phi_ddot = (M_roll_t - C_roll * phi_dot_t(k) - K_roll_eq * phi_t(k)) / I_xx_RC;

    phi_dot_t(k+1) = phi_dot_t(k) + phi_ddot * dt;
    phi_t(k+1)     = phi_t(k) + phi_dot_t(k+1) * dt;
end

dFz_geom_F_t  = zeros(size(t));
dFz_geom_R_t  = zeros(size(t));
dFz_elast_F_t = zeros(size(t));
dFz_elast_R_t = zeros(size(t));
TLTD_t        = zeros(size(t));
MN_t          = zeros(size(t));

phi_eq_rad = deg2rad(phi_eq_deg); 

for k = 1:length(t)
    dFz_geom_F_t(k) = (m_SM * a_lat_t(k) * distrF * M.hRC_F_dyn) / T_F;
    dFz_geom_R_t(k) = (m_SM * a_lat_t(k) * (1 - distrF) * M.hRC_R_dyn) / T_R;

    dFz_NSM_F_curr  = (2 * m_NSM_F * a_lat_t(k) * h_CG_NSM) / T_F;
    dFz_NSM_R_curr  = (2 * m_NSM_R * a_lat_t(k) * h_CG_NSM) / T_R;

    dFz_elast_F_t(k) = (M_F_res_vec(eq_idx) * (phi_t(k) / phi_eq_rad)) / T_F;
    dFz_elast_R_t(k) = (M_R_res_vec(eq_idx) * (phi_t(k) / phi_eq_rad)) / T_R;

    dFz_tot_F_curr = dFz_geom_F_t(k) + dFz_elast_F_t(k) + dFz_NSM_F_curr;
    dFz_tot_R_curr = dFz_geom_R_t(k) + dFz_elast_R_t(k) + dFz_NSM_R_curr;

    if (dFz_tot_F_curr + dFz_tot_R_curr) > 0.1
        TLTD_t(k) = (dFz_tot_F_curr / (dFz_tot_F_curr + dFz_tot_R_curr)) * 100;
    else
        TLTD_t(k) = TLTD_vec(1); 
    end

    dM_elast_F = dFz_elast_F_t(k) * T_F;
    dM_elast_R = dFz_elast_R_t(k) * T_R;
    if (dM_elast_F + dM_elast_R) > 0.1
        MN_t(k) = (dM_elast_F / (dM_elast_F + dM_elast_R)) * 100;
    else
        MN_t(k) = MD_vec(eq_idx); 
    end
end

% --- TAB 5: Tranziens Átterhelődés ---
tab_trans = uitab(tab_group, 'Title', 'Tranziens Átterhelődés');

subplot(1, 2, 1, 'Parent', tab_trans);
plot(t, a_lat_t / g, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Oldalgyorsulás [G]');
hold on; grid on;
plot(t, dFz_geom_F_t, 'b-',  'LineWidth', 2, 'DisplayName', 'Első Geometriai \DeltaF_z');
plot(t, dFz_geom_R_t, 'b--', 'LineWidth', 1.8, 'DisplayName', 'Hátsó Geometriai \DeltaF_z');
plot(t, dFz_elast_F_t, 'r-',  'LineWidth', 2, 'DisplayName', 'Első Elasztikus \DeltaF_z');
plot(t, dFz_elast_R_t, 'r--', 'LineWidth', 1.8, 'DisplayName', 'Hátsó Elasztikus \DeltaF_z');
xlabel('Idő t [s]', 'FontWeight', 'bold');
ylabel('Átterhelődés [N] / Gyorsulás [G]', 'FontWeight', 'bold');
title(sprintf('Geometriai vs. Elasztikus Átterhelődések (\\zeta_{roll} = %.3f)', zeta_roll), 'FontWeight', 'bold');
legend('Location', 'best');

subplot(1, 2, 2, 'Parent', tab_trans);
plot(t, TLTD_t, 'g-', 'LineWidth', 2, 'DisplayName', 'TLTD(t) [%]');
hold on; grid on;
plot(t, MN_t, 'm-.', 'LineWidth', 2, 'DisplayName', 'Magic Number / Elasztikus Megoszlás MN(t) [%]');

yline(TLTD_vec(eq_idx), 'g:', 'LineWidth', 1.5, 'DisplayName', sprintf('Steady-State TLTD (%.1f%%)', TLTD_vec(eq_idx)));
yline(MD_vec(eq_idx),   'm:', 'LineWidth', 1.5, 'DisplayName', sprintf('Steady-State MN (%.1f%%)', MD_vec(eq_idx)));

xlabel('Idő t [s]', 'FontWeight', 'bold');
ylabel('Arány [%]', 'FontWeight', 'bold');
title(sprintf('Dinamikus TLTD és Magic Number Lefolyása (\\zeta_{roll} = %.3f)', zeta_roll), 'FontWeight', 'bold');
legend('Location', 'best');

% --- FÜGGVÉNY-ALAPÚ ÁBRÁK KIRAJZOLÁSA ÚJ FÜLEKRE ---
plot_travel_basics(RF, RR, x_d_mm, tab_group);
plot_travel_heave(RF, RR, x_d_mm, c_sel_F, c_sel_R, m1_F, m1_R, regime_short, CLICK_F, CLICK_R, tab_group);
plot_travel_xi('ELSŐ TENGELY',  RF, x_d_mm, O.XI_TARGET(:, 1), regime_names, CLICK_F, tab_group);
plot_travel_xi('HÁTSÓ TENGELY', RR, x_d_mm, O.XI_TARGET(:, 2), regime_names, CLICK_R, tab_group);
plot_travel_arms('ELSŐ TENGELY',  RF, x_d_mm, regime_names, CLICK_F, tab_group);
plot_travel_arms('HÁTSÓ TENGELY', RR, x_d_mm, regime_names, CLICK_R, tab_group);
plot_travel_penalty('ELSŐ TENGELY',  RF, x_d_mm, regime_names, CLICK_F, PEN_CAP, tab_group);
plot_travel_penalty('HÁTSÓ TENGELY', RR, x_d_mm, regime_names, CLICK_R, PEN_CAP, tab_group);
plot_travel_best_click(RF, RR, x_d_mm, regime_short, CLICK_F, CLICK_R, tab_group);
show_click_tables(RF, RR, x_d_mm, TABLE_POS_MM, tab_group);

fprintf('Összes futásidő: %.1f s\n', toc(t_all));
diary off;

%% ========================================================================
%  SEGÉDFÜGGVÉNYEK
%  ========================================================================

function [x_out, y_out] = get_excel_pts(loaded_data, row_idx, eval_pts, default_val)
    x_out = eval_pts(:);
    y_out = default_val * ones(length(eval_pts), 1);
    if ~isempty(loaded_data) && size(loaded_data, 1) >= row_idx
        for i = 1:length(eval_pts)
            if size(loaded_data, 2) >= i+1
                val = loaded_data{row_idx, i+1};
                if isnumeric(val) && ~isnan(val)
                    y_out(i) = val;
                end
            end
        end
    end
end
 
function [curve_func, eval_y] = defineTargetCurveGUI(name, x_min, x_max, x_label, y_label, init_x, init_y, eval_pts_mm)
    if nargin >= 7 && ~isempty(init_x)
        x_pts = init_x(:);
        y_pts = init_y(:);
    else
        x_pts = [x_min; 0; x_max];
        y_pts = [0.8; 0.8; 0.8];
    end
 
    fig = figure('Name', ['Görbe Szerkesztő: ', name], ...
        'NumberTitle', 'off', 'Position', [200 150 1000 600], ...
        'MenuBar', 'none', 'ToolBar', 'figure', 'DockControls', 'off');
 
    ax = axes('Parent', fig, 'Position', [0.08 0.12 0.58 0.8]);
    grid(ax, 'on'); hold(ax, 'on');
    xlabel(ax, x_label); ylabel(ax, y_label);
 
    y_min_val = min(y_pts) - 0.2; y_max_val = max(y_pts) + 0.2;
    if y_min_val == y_max_val, y_min_val = y_min_val - 0.5; y_max_val = y_max_val + 0.5; end
    xlim(ax, [x_min, x_max]); ylim(ax, [y_min_val, y_max_val]);
 
    pnl = uipanel('Parent', fig, 'Title', 'Vezérlők & Pontok', 'Position', [0.69 0.05 0.29 0.9]);
 
    uicontrol(pnl, 'Style', 'text', 'String', 'Pontok listája (X [mm], Y [-]):', ...
        'Position', [10 490 200 20], 'HorizontalAlignment', 'left');
    lst_points = uicontrol(pnl, 'Style', 'listbox', 'Position', [10 340 250 150]);
 
    uicontrol(pnl, 'Style', 'text', 'String', 'X:', 'Position', [10 305 20 20]);
    txt_x = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [30 305 55 22]);
    uicontrol(pnl, 'Style', 'text', 'String', 'Y:', 'Position', [90 305 20 20]);
    txt_y = uicontrol(pnl, 'Style', 'edit', 'String', '0.8', 'Position', [110 305 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Hozzáad', ...
        'Position', [170 305 90 22], 'Callback', @add_point_manual);
 
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Kijelölt Pont Törlése', ...
        'Position', [10 270 250 28], 'Callback', @delete_selected_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Utolsó Visszavonása (Undo)', ...
        'Position', [10 235 250 28], 'Callback', @undo_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Minden Pont Törlése', ...
        'Position', [10 200 250 28], 'Callback', @clear_points);
 
    uicontrol(pnl, 'Style', 'text', 'String', 'Y min / Y max skála:', ...
        'Position', [10 160 120 20], 'HorizontalAlignment', 'left');
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_min_val), 'Position', [10 135 55 22]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_max_val), 'Position', [70 135 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Skála Beállítása', ...
        'Position', [135 135 125 22], 'Callback', @update_axes_limits);
 
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Megtart / Ugrás (Skip)', ...
        'Position', [10 80 250 35], 'BackgroundColor', [0.85 0.9 0.85], 'Callback', @skip_callback);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Mentés és Folytatás', ...
        'Position', [10 30 250 40], 'BackgroundColor', [0.2 0.7 0.2], ...
        'ForegroundColor', [1 1 1], 'FontWeight', 'bold', 'Callback', @save_callback);
 
    set(fig, 'WindowButtonDownFcn', @click_on_axes);
    update_plot_and_list();
    uiwait(fig);
 
    if isempty(x_pts)
        x_sorted = [x_min; x_max]; y_sorted = [0.8; 0.8];
    else
        [x_sorted, s_idx] = sort(x_pts); y_sorted = y_pts(s_idx);
        [x_sorted, u_idx] = unique(x_sorted); y_sorted = y_sorted(u_idx);
    end
    if length(x_sorted) < 2
        x_sorted = [x_min; x_max]; y_sorted = [0.8; 0.8];
    end
 
    eval_y = interp1(x_sorted, y_sorted, eval_pts_mm(:), 'pchip', 'extrap');
    curve_func = @(x_m) interp1(x_sorted, y_sorted, x_m * 1000, 'pchip', 'extrap');
 
    if ishandle(fig), close(fig); end
 
    function click_on_axes(~, ~)
        cp = get(ax, 'CurrentPoint'); cx = cp(1,1); cy = cp(1,2);
        xl = xlim(ax); yl = ylim(ax);
        if cx >= xl(1) && cx <= xl(2) && cy >= yl(1) && cy <= yl(2)
            x_pts(end+1, 1) = cx; y_pts(end+1, 1) = cy;
            update_plot_and_list();
        end
    end
    function add_point_manual(~, ~)
        nx = str2double(get(txt_x, 'String')); ny = str2double(get(txt_y, 'String'));
        if ~isnan(nx) && ~isnan(ny)
            x_pts(end+1, 1) = nx; y_pts(end+1, 1) = ny;
            update_plot_and_list();
        end
    end
    function delete_selected_point(~, ~)
        if isempty(x_pts), return; end
        idx = get(lst_points, 'Value');
        if isempty(idx) || idx < 1 || idx > length(x_pts), return; end
        x_pts(idx) = []; y_pts(idx) = [];
        update_plot_and_list();
    end
    function undo_point(~, ~)
        if ~isempty(x_pts)
            x_pts(end) = []; y_pts(end) = [];
            update_plot_and_list();
        end
    end
    function clear_points(~, ~)
        x_pts = []; y_pts = [];
        update_plot_and_list();
    end
    function update_axes_limits(~, ~)
        ymin_n = str2double(get(txt_ymin, 'String'));
        ymax_n = str2double(get(txt_ymax, 'String'));
        if ~isnan(ymin_n) && ~isnan(ymax_n) && ymax_n > ymin_n
            ylim(ax, [ymin_n, ymax_n]);
        end
    end
    function skip_callback(~, ~), uiresume(fig); end
    function save_callback(~, ~), uiresume(fig); end
 
    function update_plot_and_list()
        cla(ax); grid(ax, 'on'); hold(ax, 'on');
        if length(x_pts) >= 2
            [xs, s_idx] = sort(x_pts); ys = y_pts(s_idx);
            [xs, u_idx] = unique(xs); ys = ys(u_idx);
            z_fit = linspace(x_min, x_max, 100);
            y_fit = interp1(xs, ys, z_fit, 'pchip', 'extrap');
            plot(ax, z_fit, y_fit, 'b-', 'LineWidth', 2);
        end
        if ~isempty(x_pts)
            plot(ax, x_pts, y_pts, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        end
        str_list = cell(length(x_pts), 1);
        for i = 1:length(x_pts)
            str_list{i} = sprintf('%d:  X = %.2f mm,  Y = %.3f', i, x_pts(i), y_pts(i));
        end
        set(lst_points, 'String', str_list);
        if ~isempty(str_list)
            set(lst_points, 'Value', min(get(lst_points, 'Value'), length(str_list)));
            if get(lst_points, 'Value') < 1
                set(lst_points, 'Value', length(str_list));
            end
        end
    end
end

function R = analyze_axle_travel(m1, m2, MR_D_func, Kwh_func, C_mat, xi_target, K_Tire, f_vec, x_m)
    nx = numel(x_m);
    R.MR     = reshape(MR_D_func(x_m), 1, []);
    R.K_wh   = reshape(Kwh_func(x_m),  1, []);
    R.f_ride = sqrt(R.K_wh / m1) / (2 * pi);
    R.xi       = zeros(4, 6, nx);
    R.ARMS     = zeros(4, 6, nx);
    R.xi_opt   = zeros(1, nx);
    R.ARMS_opt = zeros(1, nx);
    R.best_t   = zeros(4, nx);
    R.best_a   = zeros(4, nx);
 
    for ix = 1:nx
        K      = R.K_wh(ix);
        c_crit = 2 * sqrt(K * m1);
        xi_mat = C_mat ./ (R.MR(ix)^2 * c_crit);
        R.xi(:, :, ix) = xi_mat;
 
        for row = 1:4
            for col = 1:6
                R.ARMS(row, col, ix) = get_ARMS_for_xi(xi_mat(row, col), K, m1, m2, K_Tire, f_vec);
            end
        end
 
        xo = calculate_ARMS_optimum(K, m1, m2, K_Tire, f_vec);
        R.xi_opt(ix)   = xo;
        R.ARMS_opt(ix) = min(get_ARMS_for_xi(xo, K, m1, m2, K_Tire, f_vec), min(min(R.ARMS(:, :, ix))));
 
        for row = 1:4
            [~, R.best_t(row, ix)] = min(abs(xi_mat(row, :) - xi_target(row)));
            [~, R.best_a(row, ix)] = min(R.ARMS(row, :, ix));
        end
    end
 
    R.pen   = (R.ARMS ./ reshape(R.ARMS_opt, 1, 1, []) - 1) * 100;
    R.c_opt = R.xi_opt .* 2 .* sqrt(R.K_wh * m1) .* R.MR.^2;
end
 
function print_travel_table(axle_name, R, x_mm, xi_target, regime_short, click_sel, pos_mm)
    for p = pos_mm(:).'
        [~, ix] = min(abs(x_mm - p));
        fprintf('\n-------------------------------------------------------------------------------------------\n');
        fprintf(' %s | x = %+.0f mm | MR = %.3f | K_wheel = %.1f N/mm | f_ride = %.2f Hz | xi_opt = %.2f\n', ...
            axle_name, x_mm(ix), R.MR(ix), R.K_wh(ix) / 1000, R.f_ride(ix), R.xi_opt(ix));
        fprintf('-------------------------------------------------------------------------------------------\n');
        fprintf(' %-4s %6s | %-42s | %-4s %-5s | %s\n', 'Rez.', 'xi_cél', 'xi a click-eken (1..6)', 'cél', 'A_RMS', 'Beállított: click -> xi | dA_RMS');
        for r = 1:4
            fprintf(' %-4s %6.2f | ', regime_short{r}, xi_target(r));
            for c = 1:6
                m = ' ';
                isT = (c == R.best_t(r, ix));
                isA = (c == R.best_a(r, ix));
                if isT && isA, m = '#'; elseif isT, m = '^'; elseif isA, m = '*'; end
                fprintf('%6.2f%c', R.xi(r, c, ix), m);
            end
            fprintf(' | %-4d %-5d | %d -> xi %.2f | %+.1f %%\n', R.best_t(r, ix), R.best_a(r, ix), ...
                click_sel(r), R.xi(r, click_sel(r), ix), R.pen(r, click_sel(r), ix));
        end
        fprintf(' dA_RMS [%%] a click-eken:\n');
        for r = 1:4
            fprintf(' %-4s        | ', regime_short{r});
            fprintf('%7.1f', squeeze(R.pen(r, :, ix)));
            fprintf('\n');
        end
    end
end
 
function plot_travel_basics(RF, RR, x_mm, tab_group)
    tab = uitab(tab_group, 'Title', 'Kerékút Alapok');
    items = {
        'Motion Ratio MR(x) [-]',                         RF.MR,        RR.MR;
        'Kerékmerevség K_{wheel}(x) [N/mm]',              RF.K_wh/1000, RR.K_wh/1000;
        'Rugózási frekvencia f_{ride}(x) [Hz]',               RF.f_ride,    RR.f_ride;
        'Optimális \xi_{opt}(x) (min. A_{RMS}) [-]',      RF.xi_opt,    RR.xi_opt;
        'Minimális A_{RMS}(x) [N]',                       RF.ARMS_opt,  RR.ARMS_opt;
        'Optimális damper-oldali c_{opt}(x) [N s/m]',     RF.c_opt,     RR.c_opt
    };
    for k = 1:size(items, 1)
        subplot(2, 3, k, 'Parent', tab);
        plot(x_mm, items{k, 2}, 'b-',  'LineWidth', 2, 'DisplayName', 'Első'); hold on; grid on;
        plot(x_mm, items{k, 3}, 'r--', 'LineWidth', 2, 'DisplayName', 'Hátsó');
        xline(0, 'k:', 'HandleVisibility', 'off');
        xlabel('Kerékút x [mm] (+ = berugózás)', 'FontWeight', 'bold');
        title(items{k, 1}, 'FontWeight', 'bold');
        legend('Location', 'best');
    end
    sgtitle(tab, 'Kerékút-függő Alapmennyiségek a Motion Ratio Görbékből', 'FontWeight', 'bold', 'FontSize', 12);
end
 
function plot_travel_heave(RF, RR, x_mm, c_sel_F, c_sel_R, m1_F, m1_R, regime_short, click_F, click_R, tab_group)
    tab = uitab(tab_group, 'Title', 'Ride & Heave (Kerékút)');
 
    subplot(2, 2, 1, 'Parent', tab);
    plot(x_mm, RF.f_ride, 'b-',  'LineWidth', 2.2, 'DisplayName', 'Első f_{ride}'); hold on; grid on;
    plot(x_mm, RR.f_ride, 'r--', 'LineWidth', 2.2, 'DisplayName', 'Hátsó f_{ride}');
    xline(0, 'k:', 'HandleVisibility', 'off');
    xlabel('Kerékút x [mm] (+ = berugózás)', 'FontWeight', 'bold');
    ylabel('Ride frekvencia f_{ride} [Hz]', 'FontWeight', 'bold');
    title('Rugózási Frekvencia a Kerékúton', 'FontWeight', 'bold');
    legend('Location', 'best');
 
    subplot(2, 2, 2, 'Parent', tab);
    plot(x_mm, RR.f_ride ./ RF.f_ride, 'k-', 'LineWidth', 2.2); hold on; grid on;
    yline(1.0, 'b:', 'LineWidth', 1.2); yline(1.2, 'r:', 'LineWidth', 1.2);
    xline(0, 'k:', 'HandleVisibility', 'off');
    xlabel('Kerékút x [mm] (+ = berugózás)', 'FontWeight', 'bold');
    ylabel('f_{ride,R} / f_{ride,F} [-]', 'FontWeight', 'bold');
    title('Flat-Ride Arány (hátsó / első; 1.0 - 1.2 a tipikus cél)', 'FontWeight', 'bold');
 
    Rs = {RF, RR}; c_sels = {c_sel_F, c_sel_R}; m1s = {m1_F, m1_R};
    names = {'Első tengely', 'Hátsó tengely'}; clicks = {click_F, click_R};
    col_reg = [0 0.45 0.74; 0.85 0.33 0.10; 0 0.45 0.74; 0.85 0.33 0.10];
    ls_reg  = {'-', '-', '--', '--'};
    for ax_i = 1:2
        R = Rs{ax_i};
        subplot(2, 2, 2 + ax_i, 'Parent', tab); hold on; grid on;
        for r = 1:4
            C_heave = 2 * c_sels{ax_i}(r) ./ R.MR.^2;
            plot(x_mm, C_heave, ls_reg{r}, 'Color', col_reg(r, :), 'LineWidth', 2.2, ...
                'DisplayName', sprintf('%s (click %d)', regime_short{r}, clicks{ax_i}(r)));
        end
        C_heave_opt = 2 * R.xi_opt .* 2 .* sqrt(R.K_wh * m1s{ax_i});
        plot(x_mm, C_heave_opt, 'k-.', 'LineWidth', 2, 'DisplayName', 'Optimum (\xi_{opt}, min. A_{RMS})');
        xline(0, 'k:', 'HandleVisibility', 'off');
        xlabel('Kerékút x [mm] (+ = berugózás)', 'FontWeight', 'bold');
        ylabel('Heave csillapítás [N s/m]', 'FontWeight', 'bold');
        title(['Heave Damping a Kerékúton - ', names{ax_i}], 'FontWeight', 'bold');
        legend('Location', 'best', 'FontSize', 8);
    end
    sgtitle(tab, 'Ride Frekvencia és Heave Damping a Kerékúton', 'FontWeight', 'bold', 'FontSize', 12);
end

function plot_travel_xi(axle_name, R, x_mm, xi_target, regime_names, click_sel, tab_group)
    tab_title = sprintf('Relatív Csill. (%s)', strrep(axle_name, ' TENGELY', ''));
    tab = uitab(tab_group, 'Title', tab_title);
    for r = 1:4
        subplot(2, 2, r, 'Parent', tab); hold on; grid on;
        for c = 1:6
            lw = 1.0; clr = [0.6 0.6 0.6];
            if c == click_sel(r), lw = 2.5; clr = [0 0.45 0.74]; end
            plot(x_mm, squeeze(R.xi(r, c, :)), 'LineWidth', lw, 'Color', clr, 'DisplayName', sprintf('Click %d', c));
        end
        plot(x_mm, R.xi_opt, 'k--', 'LineWidth', 1.8, 'DisplayName', '\xi_{opt}');
        yline(xi_target(r), 'r:', 'LineWidth', 1.5, 'DisplayName', 'Cél \xi');
        xline(0, 'k:', 'HandleVisibility', 'off');
        xlabel('Kerékút x [mm]', 'FontWeight', 'bold');
        ylabel('Relatív csillapítás \xi [-]', 'FontWeight', 'bold');
        title(sprintf('%s (Beállítva: Click %d)', regime_names{r}, click_sel(r)), 'FontWeight', 'bold');
        legend('Location', 'best');
    end
    sgtitle(tab, ['Relatív Csillapítás (\xi) a Kerékúton - ', axle_name], 'FontWeight', 'bold', 'FontSize', 12);
end

function plot_travel_arms(axle_name, R, x_mm, regime_names, click_sel, tab_group)
    tab_title = sprintf('A_RMS (%s)', strrep(axle_name, ' TENGELY', ''));
    tab = uitab(tab_group, 'Title', tab_title);
    for r = 1:4
        subplot(2, 2, r, 'Parent', tab); hold on; grid on;
        for c = 1:6
            lw = 1.0; clr = [0.6 0.6 0.6];
            if c == click_sel(r), lw = 2.5; clr = [0.85 0.33 0.10]; end
            plot(x_mm, squeeze(R.ARMS(r, c, :)), 'LineWidth', lw, 'Color', clr, 'DisplayName', sprintf('Click %d', c));
        end
        plot(x_mm, R.ARMS_opt, 'k--', 'LineWidth', 1.8, 'DisplayName', 'Min. A_{RMS}');
        xline(0, 'k:', 'HandleVisibility', 'off');
        xlabel('Kerékút x [mm]', 'FontWeight', 'bold');
        ylabel('A_{RMS} [N]', 'FontWeight', 'bold');
        title(sprintf('%s (Beállítva: Click %d)', regime_names{r}, click_sel(r)), 'FontWeight', 'bold');
        legend('Location', 'best');
    end
    sgtitle(tab, ['Dinamikus Kerékterhelés Fluctuáció (A_{RMS}) - ', axle_name], 'FontWeight', 'bold', 'FontSize', 12);
end

function plot_travel_penalty(axle_name, R, x_mm, regime_names, click_sel, pen_cap, tab_group)
    tab_title = sprintf('Hőtérkép (%s)', strrep(axle_name, ' TENGELY', ''));
    tab = uitab(tab_group, 'Title', tab_title);
    for r = 1:4
        subplot(2, 2, r, 'Parent', tab); hold on;
        imagesc(x_mm, 1:6, squeeze(R.pen(r, :, :)));
        set(gca, 'YDir', 'normal'); colormap(gca, parula); caxis([0 pen_cap]);
        cb = colorbar; cb.Label.String = 'A_{RMS} többlet az optimumhoz képest [%]';
        p1 = plot(x_mm, R.best_a(r, :), 'w.', 'MarkerSize', 12);
        p2 = plot(x_mm, R.best_t(r, :), 'ro', 'MarkerSize', 5, 'LineWidth', 1);
        p3 = yline(click_sel(r), 'm--', 'LineWidth', 2);
        xlim([min(x_mm) max(x_mm)]); ylim([0.5 6.5]); yticks(1:6);
        xlabel('Kerékút x [mm] (+ = berugózás)', 'FontWeight', 'bold');
        ylabel('Damper click', 'FontWeight', 'bold');
        title(regime_names{r}, 'FontWeight', 'bold');
        if r == 1
            legend([p1 p2 p3], {'A_{RMS} szerinti legjobb', 'Cél \xi szerinti legjobb', 'Beállított click'}, ...
                'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 7);
        end
    end
    sgtitle(tab, sprintf('%s: Melyik click mennyire optimális a kerékúton? (kék = optimum, sárga >= %d%% többlet)', axle_name, pen_cap), ...
        'FontWeight', 'bold', 'FontSize', 12);
end

function plot_travel_best_click(RF, RR, x_mm, regime_short, click_F, click_R, tab_group)
    tab = uitab(tab_group, 'Title', 'Optimális Clickek');
    Rs = {RF, RR}; names = {'Első', 'Hátsó'}; clicks = {click_F, click_R};
    for ax_i = 1:2
        R = Rs{ax_i};
        for r = 1:4
            subplot(2, 4, (ax_i - 1) * 4 + r, 'Parent', tab); hold on; grid on;
            stairs(x_mm, R.best_a(r, :), 'b-',  'LineWidth', 2.2, 'DisplayName', 'A_{RMS} szerint');
            stairs(x_mm, R.best_t(r, :), 'r--', 'LineWidth', 2.2, 'DisplayName', 'Cél \xi szerint');
            yline(clicks{ax_i}(r), 'm:', 'LineWidth', 2, 'DisplayName', 'Beállított');
            ylim([0.5 6.5]); yticks(1:6);
            xlabel('Kerékút x [mm]', 'FontWeight', 'bold');
            ylabel('Click', 'FontWeight', 'bold');
            title(sprintf('%s - %s', names{ax_i}, regime_short{r}), 'FontWeight', 'bold');
            if ax_i == 1 && r == 1, legend('Location', 'best', 'FontSize', 7); end
        end
    end
    sgtitle(tab, 'Optimális Damper Click a Kerékúton (rezsimenként)', 'FontWeight', 'bold', 'FontSize', 12);
end

function show_click_tables(RF, RR, x_mm, tbl_pos_mm, tab_group)
    tab = uitab(tab_group, 'Title', 'Javasolt Beállítások');
    cn = {'x [mm]', 'MR', 'f_ride [Hz]', 'xi_opt', 'LSR cél', 'LSR A_RMS', 'LSC cél', 'LSC A_RMS', ...
        'HSR cél', 'HSR A_RMS', 'HSC cél', 'HSC A_RMS'};
    Rs = {RF, RR}; names = {'ELSŐ TENGELY - javasolt click (cél xi szerint / A_RMS minimum szerint)', ...
        'HÁTSÓ TENGELY - javasolt click (cél xi szerint / A_RMS minimum szerint)'};
    idx = zeros(1, numel(tbl_pos_mm));
    for k = 1:numel(tbl_pos_mm)
        [~, idx(k)] = min(abs(x_mm - tbl_pos_mm(k)));
    end
    for ax_i = 1:2
        R = Rs{ax_i};
        data = [x_mm(idx).', round(R.MR(idx).', 3), round(R.f_ride(idx).', 2), round(R.xi_opt(idx).', 2)];
        for r = 1:4
            data = [data, R.best_t(r, idx).', R.best_a(r, idx).']; %#ok<AGROW>
        end
        y0 = 0.53 - (ax_i - 1) * 0.50;
        uicontrol(tab, 'Style', 'text', 'String', names{ax_i}, 'Units', 'normalized', ...
            'Position', [0.02, y0 + 0.41, 0.96, 0.035], 'FontWeight', 'bold', 'FontSize', 11, ...
            'HorizontalAlignment', 'left');
        uitable(tab, 'Data', data, 'ColumnName', cn, 'Units', 'normalized', ...
            'Position', [0.02, y0, 0.96, 0.40], 'FontSize', 10, ...
            'ColumnWidth', {60, 60, 80, 60, 75, 85, 75, 85, 75, 85, 75, 85});
    end
end

function xi_at_min = calculate_ARMS_optimum(K_wheel_s, m1, m2, K_Tire, f)
xi_grid = linspace(0.1, 1.5, 80);
A_RMS_vec = zeros(size(xi_grid));
for i = 1:length(xi_grid)
    A_RMS_vec(i) = get_ARMS_for_xi(xi_grid(i), K_wheel_s, m1, m2, K_Tire, f);
end
    
    [~, min_idx] = min(A_RMS_vec);
    if min_idx > 1 && min_idx < length(xi_grid)
        xi_sub = xi_grid(min_idx-1 : min_idx+1);
        y_sub  = A_RMS_vec(min_idx-1 : min_idx+1);
        p = polyfit(xi_sub, y_sub, 2);
        if p(1) > 0
            xi_at_min = -p(2) / (2 * p(1));
        else
            xi_at_min = xi_grid(min_idx);
        end
    else
        xi_at_min = xi_grid(min_idx);
    end
end

function Arms = get_ARMS_for_xi(xi, K_wheel_s, m1, m2, K_Tire, f)
w  = 2 * pi * f(:).';
c  = xi * 2 * sqrt(K_wheel_s * m1);
A11 = K_wheel_s - m1 * w.^2 + 1i * w * c;
A22 = K_wheel_s + K_Tire - m2 * w.^2 + 1i * w * c;
A12 = -(K_wheel_s + 1i * w * c);
Z2  = A11 * K_Tire ./ (A11 .* A22 - A12.^2);
A_f = abs(K_Tire * (Z2 - 1));
fr  = f(:).';
Arms = sqrt(trapz(fr, A_f.^2) / (fr(end) - fr(1)));
end

%% ========================================================================
%  AZ OPTIMALIZÁLÓBÓL ÁTVETT MODELL- ÉS KIMENETI FÜGGVÉNYEK
%  (a motion ratio-k itt a görbékből jövő függvénykezelők, nem polinomok)
%  ========================================================================

function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end

function v = mrv(f, x_m)
    % motion ratio [-], x_m: kerékút [m]; alsó korlát a nullával osztás ellen
    v = max(f(x_m), 0.05);
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

function [c, errmax] = curve_fit(f, O)
    % 2. fokú polinom-illesztés a megadott MR görbére a kerékút-tartományon (x [mm]) - képlet-kiíráshoz
    x  = linspace(-O.TRAVEL_REB_MM, O.TRAVEL_BUMP_MM, 61);
    y  = f(x / 1000);
    co = polyfit(x(:), y(:), 2);
    c  = [co(3) co(2) co(1)];                      % [m0 m1 m2]
    errmax = max(abs(polyval(co, x(:)) - y(:)));
end

function s = mr_curve_text(f, name, active, O)
    if ~active
        s = '- (nincs stabilizátor ezen a tengelyen)';
        return;
    end
    [c, e] = curve_fit(f, O);
    s = [mr_text(c, name, true) sprintf('   [2. fokú illesztés a megadott görbére, max. eltérés %.4f]', e)];
end

function G = rc_geometry(hF, hR, P)
    % Roll tengely geometria és geometriai (azonnali) terhelésátadás az RC magasságokból [m]
    G.h_RA_at_CG   = hR + (hF - hR) * (P.b / P.L);
    G.theta_RA_rad = atan((hF - hR) / P.L);
    G.dFz_geom_F   = (P.m_SM * P.a_lat * P.distrF * hF) / P.T_F;
    G.dFz_geom_R   = (P.m_SM * P.a_lat * (1 - P.distrF) * hR) / P.T_R;
end

function c = range_c(v, rg)
    w = max(rg(2) - rg(1), 1e-3);
    c = [(rg(1) - v) / w; (v - rg(2)) / w];
end

function c = upper_c(v, vmax)
    % felső korlát skálázott alakja (c <= 0 a megfelelő); vmax = Inf / [] -> kikapcsolva (mindig teljesül)
    if ~isempty(vmax) && isfinite(vmax) && vmax > 0, c = (v - vmax) / vmax; else, c = -1; end
end

function c = lower_c(v, vmin)
    % alsó korlát skálázott alakja (c <= 0 a megfelelő); vmin = Inf / [] / 0 -> kikapcsolva
    if ~isempty(vmin) && isfinite(vmin) && vmin > 0, c = (vmin - v) / vmin; else, c = -1; end
end

function [r, Q] = roll_state(phF, S0)
    % Az első tengely dőlésszögéhez tartozó nyomaték-maradék (váz torzióval)
    xF  = (S0.T_F / 2) * sin(phF);
    KwF = 0.5 * S0.kF * (1 / mrv(S0.fSpF, xF)^2 + 1 / mrv(S0.fSpF, -xF)^2);
    KrF = KwF * (S0.T_F^2 / 2) + S0.KarbF * S0.arbF / mrv(S0.fAbF, xF)^2;
    MFr = KrF * phF;
    Tch = S0.M_roll_F_in - MFr;
    phR = phF - Tch / S0.Kch;
    xR  = (S0.T_R / 2) * sin(phR);
    KwR = 0.5 * S0.kR * (1 / mrv(S0.fSpR, xR)^2 + 1 / mrv(S0.fSpR, -xR)^2);
    KrR = KwR * (S0.T_R^2 / 2) + S0.KarbR * S0.arbR / mrv(S0.fAbR, xR)^2;
    MRr = KrR * phR;
    r = MFr + MRr - S0.M_roll;
    if nargout > 1
        Q.KrF = KrF; Q.KrR = KrR; Q.phR = phR; Q.KwF = KwF; Q.KwR = KwR;
    end
end

function M = model_mech(S, P)
    % Egyensúlyi dőlés, MN, TLTD, ride frekvenciák, jacking
    vt = P.valtoszam;
    hRC_F = S.hRC_F; hRC_R = S.hRC_R;                % statikus (tervezési) RC magasságok; a dinamikusak lent: hRCd_F / hRCd_R

    KwF0 = S.kF * vt / mrv(S.fSpF, 0)^2;
    KwR0 = S.kR * vt / mrv(S.fSpR, 0)^2;
    KhF0 = 2 * KwF0 + S.KhvF / mrv(S.fAbF, 0)^2;   % statikus heave merevség tengelyenként (rugók + heave stabilizátor)
    KhR0 = 2 * KwR0 + S.KhvR / mrv(S.fAbR, 0)^2;
    KrideF_ax = KhF0 * (2 * P.K_Tire) / (KhF0 + 2 * P.K_Tire);   % tengely heave merevsége a gumikkal sorosan
    KrideR_ax = KhR0 * (2 * P.K_Tire) / (KhR0 + 2 * P.K_Tire);
    Kride_tot = KrideF_ax + KrideR_ax;

    Fy = P.m_total * P.a_lat;
    % Aero lesüllyedés kanyarsebességen (a tengely heave merevségéből, statikus helyzetből) [m]; DYN_HEIGHT = false -> 0
    if P.DYN_HEIGHT
        xaF = aero_defl(S.kF, S.fSpF, S.fAbF, S.KhvF, P.F_down_cor_F, vt);
        xaR = aero_defl(S.kR, S.fSpR, S.fAbR, S.KhvR, P.F_down_cor_R, vt);
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
    S0.kF = S.kF * vt; S0.kR = S.kR * vt;
    S0.fSpF = S.fSpF; S0.fSpR = S.fSpR; S0.fAbF = S.fAbF; S0.fAbR = S.fAbR;
    S0.KarbF = S.KarbF; S0.KarbR = S.KarbR;
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
    M.phi_eq_rad = phF;
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
    M.roll_grad = M.phiF_deg / P.a_lat_g;          % [deg/g] (első tengely)

    M.fF = sqrt(KhF0 / (2 * P.m1_F)) / (2 * pi);
    M.fR = sqrt(KhR0 / (2 * P.m1_R)) / (2 * pi);
    M.KwF0 = KwF0; M.KwR0 = KwR0;
    M.dh_jack = dh_jack;                           % [m]
    M.F_jack_F = F_jack_F; M.F_jack_R = F_jack_R;  % [N]
    M.hRC_F = hRC_F; M.hRC_R = hRC_R;              % [m] statikus (tervezési) RC
    M.hRC_F_dyn = hRCd_F; M.hRC_R_dyn = hRCd_R;    % [m] dinamikus RC (aero lesüllyedés + jacking után)
    M.dz_CG = dz_CG;                               % [m] CoG függőleges elmozdulása (jacking - aero lesüllyedés)
    M.xaero_cor_F = xaF; M.xaero_cor_R = xaR;      % [m] aero berugózás kanyarsebességen
    % kiegészítők az ábrákhoz / ellenőrzéshez
    M.G = G; M.dz_dyn = dz_dyn; M.d_perp_dyn = d_perp_dyn; M.hSM = hSM;
    M.Kride_tot = Kride_tot; M.S0 = S0;
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
    % cwF, cwR: kerékszintű kis sebességű csillapítás [N s/m] tengelyenként (LSR és LSC átlaga)
    C_roll = cwF * P.T_F^2 / 2 + cwR * P.T_R^2 / 2;          % [Nm s/rad]
    Rd.zeta = C_roll / (2 * sqrt(M.K_roll * M.theta_x_RC));
    r  = O.F_SLALOM_HZ / M.f_roll;
    Hroll = 1 / (1 - r^2 + 2i * Rd.zeta * r);                % rugózott tömeg roll-válasza
    gs = M.GEO_SHARE / 100;
    H  = gs + (1 - gs) * Hroll;                              % azonnali (geometriai) + késleltetett (rugalmas) rész
    Rd.lag_deg = -angle(H) * 180 / pi;
    Rd.amp = abs(H);
end

function Fax = axle_force(kk, fW, fA, Khv, xlim_m, vt)
    % tengelyenkénti aero-erő, amit a heave merevség xlim_m berugózásig felvesz [N]
    x  = linspace(0, xlim_m, 41);
    Kh = 2 * (kk * vt) ./ mrv(fW, x).^2 + Khv ./ mrv(fA, x).^2;
    Fax = trapz(x, Kh);
end

function v = arms_vec(xi, K, m1, m2, Kt, f)
    % A_RMS több xi-re egyszerre (get_ARMS_for_xi vektorizált változata)
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

function D = damper_select(fW, fA, kk, Khv, m1, m2, xiT, P, O, click_in)
    % Click-értékelés rezsimenként: statikus xi hiba + A_RMS többlet súlyozott költsége.
    % click_in: a kézzel beállított click-ek [LSR LSC HSR HSC]; ezekkel számol (D.click, D.J),
    % D.click_best / D.J_best = az optimalizáló-logika szerinti legjobb click (összehasonlításhoz)
    vt = P.valtoszam;
    MR0 = mrv(fW, 0);
    K0  = kk * vt / MR0^2 + Khv / (2 * mrv(fA, 0)^2);
    xi0 = P.C ./ (MR0^2 * 2 * sqrt(K0 * m1));          % 4x6

    pos = O.ARMS_POS_MM(:).' / 1000;
    pen = zeros(4, 6, numel(pos));
    for ip = 1:numel(pos)
        x   = pos(ip);
        MRx = mrv(fW, x);
        Kx  = kk * vt / MRx^2 + Khv / (2 * mrv(fA, x)^2);
        xi_mat = P.C ./ (MRx^2 * 2 * sqrt(Kx * m1));
        vals = arms_vec([xi_mat(:); O.XI_GRID(:)], Kx, m1, m2, P.K_Tire, O.F_VEC);
        A_cl = reshape(vals(1:24), 4, 6);
        pen(:, :, ip) = A_cl ./ min(vals) - 1;
    end
    armsFrac = mean(pen, 3);
    Jc = O.W_XI * (xi0 ./ xiT(:) - 1).^2 + O.W_ARMS * armsFrac;
    [Jmin, click_best] = min(Jc, [], 2);
    if nargin < 10 || isempty(click_in)
        click = click_best;
    else
        click = click_in(:);
    end
    idx = sub2ind([4 6], (1:4).', click);

    D.J = mean(Jc(idx));
    D.click = click(:).';
    D.xi = xi0(idx).';
    D.arms_pen = 100 * armsFrac(idx).';
    D.arms_pen_mean = mean(D.arms_pen);
    D.click_best = click_best(:).';
    D.J_best = mean(Jmin);
end

function E = evaluate(S, P, O)
    vt = P.valtoszam;
    actF = S.modeF > 0; actR = S.modeR > 0;
    M = model_mech(S, P);

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
    FaxF = axle_force(S.kF, S.fSpF, S.fAbF, S.KhvF, xlF / 1000, vt);
    FaxR = axle_force(S.kR, S.fSpR, S.fAbR, S.KhvR, xlR / 1000, vt);
    c_aero = [(P.F_down_ax_F - FaxF) / P.F_down_ax_F; (P.F_down_ax_R - FaxR) / P.F_down_ax_R];

    % --- 3) MR a megengedett sávban + damper löket a teljes kerékúton ---
    xg = linspace(-O.TRAVEL_REB_MM, O.TRAVEL_BUMP_MM, 51);
    mFg = S.fSpF(xg / 1000); mRg = S.fSpR(xg / 1000); aFg = S.fAbF(xg / 1000); aRg = S.fAbR(xg / 1000);
    act = [true; true; actF; actR];
    c_mrmin = (O.MR_MIN - [min(mFg); min(mRg); min(aFg); min(aRg)]) / O.MR_MIN;
    c_mrmax = ([max(mFg); max(mRg); max(aFg); max(aRg)] - O.MR_MAX) / O.MR_MAX;
    c_mrmin(~act) = -1; c_mrmax(~act) = -1;
    S_F = trapz(xg, mFg); S_R = trapz(xg, mRg);          % damper elmozdulás a teljes kerékúton [mm]
    c_str = [(S_F - O.DAMPER_STROKE_MM) / O.DAMPER_STROKE_MM; (S_R - O.DAMPER_STROKE_MM) / O.DAMPER_STROKE_MM];

    % --- 4) célfüggvény: ride freq + damper + jacking + reaktivitás ---
    fT = O.F_RIDE_TARGET;
    J_ride = O.W_F * (((M.fF - fT(1)) / fT(1))^2 + ((M.fR - fT(2)) / fT(2))^2);
    DF = damper_select(S.fSpF, S.fAbF, S.kF, S.KhvF, P.m1_F, P.m2_F, O.XI_TARGET(:, 1), P, O, S.clickF);
    DR = damper_select(S.fSpR, S.fAbR, S.kR, S.KhvR, P.m1_R, P.m2_R, O.XI_TARGET(:, 2), P, O, S.clickR);

    % roll csillapítás és fáziskésés: (t) cél-xi alapján, (a) a ténylegesen beállított click-ekkel
    MR0F = mrv(S.fSpF, 0); MR0R = mrv(S.fSpR, 0);
    K0F = S.kF * vt / MR0F^2 + S.KhvF / (2 * mrv(S.fAbF, 0)^2);
    K0R = S.kR * vt / MR0R^2 + S.KhvR / (2 * mrv(S.fAbR, 0)^2);
    cwF_t = mean(O.XI_TARGET(1:2, 1)) * 2 * sqrt(K0F * P.m1_F);
    cwR_t = mean(O.XI_TARGET(1:2, 2)) * 2 * sqrt(K0R * P.m1_R);
    cwF_a = (P.C(1, DF.click(1)) + P.C(2, DF.click(2))) / 2 / MR0F^2;
    cwR_a = (P.C(1, DR.click(1)) + P.C(2, DR.click(2))) / 2 / MR0R^2;
    Rdt = roll_dynamics(M, cwF_t, cwR_t, P, O);
    Rda = roll_dynamics(M, cwF_a, cwR_a, P, O);

    J_jack  = O.W_JACK  * (1000 * M.dh_jack / O.JACK_REF_MM)^2;
    J_react = O.W_REACT * (Rdt.lag_deg / O.LAG_REF_DEG)^2;
    J = J_ride + DF.J + DR.J + J_jack + J_react;
    J_best_clicks = J_ride + DF.J_best + DR.J_best + J_jack + J_react;

    % --- 5) reaktivitás / jacking korlátok (Inf = kikapcsolva) ---
    c_rg   = upper_c(M.roll_grad,        O.ROLL_GRAD_MAX_DEG_G);
    c_geo  = lower_c(M.GEO_SHARE,        O.GEO_SHARE_MIN);
    c_jack = upper_c(1000 * M.dh_jack,   O.JACK_MAX_MM);
    c_lag  = upper_c(Rdt.lag_deg,        O.LAG_MAX_DEG);

    c = [c_phi; c_tltd; c_mn; c_aero; c_mrmin; c_mrmax; c_str; c_rg; c_geo; c_jack; c_lag];
    cnames = {'egyensúlyi dőlés < min', 'egyensúlyi dőlés > max', 'TLTD < min', 'TLTD > max', 'MN < min', 'MN > max', ...
        'aero hasmagasság (első)', 'aero hasmagasság (hátsó)', ...
        'MR < min (első rugó)', 'MR < min (hátsó rugó)', 'MR < min (első stab.)', 'MR < min (hátsó stab.)', ...
        'MR > max (első rugó)', 'MR > max (hátsó rugó)', 'MR > max (első stab.)', 'MR > max (hátsó stab.)', ...
        'damper löket (első)', 'damper löket (hátsó)', 'dőlésgradiens', 'geometriai átadás', 'jacking', 'fáziskésés'};

    if ~isfinite(J) || any(~isfinite(c))
        J = 1e3; c = 1e3 * ones(numel(c), 1);
    end
    E.J = J; E.c = c; E.cnames = cnames; E.maxviol = max(c);
    E.M = M; E.DF = DF; E.DR = DR; E.S_F = S_F; E.S_R = S_R;
    E.Rd = Rda; E.Rdt = Rdt; E.J_jack = J_jack; E.J_react = J_react;
    E.J_best_clicks = J_best_clicks;
end

function X = solution_extras(S, P, O)
    % Hasmagasság a teljes sebességtartományban, damper út és statikus hossz
    vt = P.valtoszam;
    xgrid = linspace(0, 0.060, 601);
    KhF = 2 * (S.kF * vt) ./ mrv(S.fSpF, xgrid).^2 + S.KhvF ./ mrv(S.fAbF, xgrid).^2;
    KhR = 2 * (S.kR * vt) ./ mrv(S.fSpR, xgrid).^2 + S.KhvR ./ mrv(S.fAbR, xgrid).^2;
    xaF = interp1(cumtrapz(xgrid, KhF), xgrid, P.F_down_ax_F, 'pchip', 'extrap');
    xaR = interp1(cumtrapz(xgrid, KhR), xgrid, P.F_down_ax_R, 'pchip', 'extrap');
    X.xaero_F = 1000 * xaF; X.xaero_R = 1000 * xaR;
    X.h_min_F = P.h_static_F_mm - X.xaero_F;
    X.h_min_R = P.h_static_R_mm - X.xaero_R;

    xn = linspace(-O.TRAVEL_REB_MM, 0, 26); xp = linspace(0, O.TRAVEL_BUMP_MM, 26);
    SrebF = trapz(xn, S.fSpF(xn / 1000)); SbumpF = trapz(xp, S.fSpF(xp / 1000));
    SrebR = trapz(xn, S.fSpR(xn / 1000)); SbumpR = trapz(xp, S.fSpR(xp / 1000));
    X.S_F = SrebF + SbumpF; X.S_R = SrebR + SbumpR;
    X.L_stat_F = O.DAMPER_LMAX_MM - SrebF;      % ha teljes kirugózásnál a damper éppen L_max hosszú
    X.L_stat_R = O.DAMPER_LMAX_MM - SrebR;

    % jacking az alap RC magasságokkal (összehasonlításhoz; kézi módban az RC fix, ezért megegyezik) és a roll tengely dőlése
    Sb = S; Sb.hRC_F = P.h_RC_F; Sb.hRC_R = P.h_RC_R;
    Mb = model_mech(Sb, P);
    X.dh_jack_base_mm = 1000 * Mb.dh_jack;
    X.RA_incl_deg = rad2deg(atan((S.hRC_F - S.hRC_R) / P.L));
end

function [hdr, rows] = handover_table(k, S, P, O)
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
            name = 'Első';  mode = S.modeF; fw = S.fSpF; fa = S.fAbF; Karb = S.KarbF; Khv = S.KhvF; kk = S.kF; T = P.T_F;
        else
            name = 'Hátsó'; mode = S.modeR; fw = S.fSpR; fa = S.fAbR; Karb = S.KarbR; Khv = S.KhvR; kk = S.kR; T = P.T_R;
        end
        MR0 = mrv(fw, 0);
        Kw0 = kk * vt / MR0^2;                         % rugó kerékszintű merevsége [N/m]
        Kspring_roll = Kw0 * T^2 / 2;                  % rugók roll-merevsége a tengelyen [Nm/rad]
        if P.ARB_ROLL_T2_4, arbT = T^2 / 4; else, arbT = 1; end

        mrTxt = '-'; mr0 = '-'; mrmin = '-'; mrmax = '-';
        Kdl = '-'; Kper = '-'; Kone = '-';
        rollStab = 0; heaveStab = 0;
        note = 'nincs stabilizátor ezen a tengelyen';
        if mode > 0
            MRa0 = mrv(fa, 0);
            mA = fa(xg / 1000);
            mrTxt = mr_curve_text(fa, 'MR_stab', true, O);
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

function write_handover_txt(file, k, S, E, X, P, O, stamp) %#ok<INUSL>
    % Olvasható strukturális átadási adatlap a megoldásra (szöveges fájl)
    [hdr, rows] = handover_table(k, S, P, O);
    fid = fopen(file, 'w', 'n', 'UTF-8');
    if fid < 0
        warning('Nem sikerült megnyitni: %s', file); return;
    end
    fprintf(fid, 'STRUKTURÁLIS ÁTADÁSI ADATLAP - %d. rang (futás: %s)\n', k, stamp);
    fprintf(fid, '%s\n', repmat('=', 1, 72));
    fprintf(fid, 'Roll center (statikus): első = %.1f mm, hátsó = %.1f mm  [fix]\n', 1000 * S.hRC_F, 1000 * S.hRC_R);
    fprintf(fid, 'Főrugók: első %g lbs/in, hátsó %g lbs/in\n', S.kF, S.kR);
    fprintf(fid, 'Dőlésgradiens: %.3f deg/g | jacking: %.2f mm | geometriai terhelésátadás: %.1f %%\n\n', ...
        E.M.roll_grad, 1000 * E.M.dh_jack, E.M.GEO_SHARE);
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
