@ -1,1245 +0,0 @@
% =========================================================================
% Formula Student - Kanyarodási Kasztnidőlés, Merevség- és Átterhelődés Modell
% (GUI / Excel Grafikus Megadással mind a 4 Motion Ratio Görbére)
% =========================================================================
clear; clc; close all;
 
disp('========================================================');
disp(' KANYARODÁSI KASZTNIDŐLÉS ÉS ÁTTERHELŐDÉS MODELL');
disp(' - 4 db Motion Ratio görbe megadása GUI / Excel alapján:');
disp('   1. Első Főrugó MR(x)');
disp('   2. Hátsó Főrugó MR(x)');
disp('   3. Első ARB MR(x)');
disp('   4. Hátsó ARB MR(x)');
disp(' - Csillapítás (damper click, MR, A_RMS optimum) a dőlésszög és a kerékút mentén');
disp('========================================================');
 
%% 1. JÁRMŰ, GEOMETRIAI ÉS ROLL CENTER PARAMÉTEREK
valtoszam  = 175.128;      % [N/m / lbs/in] Átváltószám
g          = 9.81;         % [m/s^2] Gravitációs gyorsulás
m_total    = 254.0;        % [kg] Teljes tömeg (autó + pilóta)
distrF     = 0.50;         % [-] Első tengelyre eső tömegarány (50%)
m_SM       = 212.67;       % [kg] Rugózott tömeg
m_NSM_F    = 41.8 / 4;     % [kg] Első sarki rugózatlan tömeg
m_NSM_R    = 41.8 / 4;     % [kg] Hátsó sarki rugózatlan tömeg

L          = 1.54;         % [m] Tengelytáv
a          = L * (1 - distrF); % [m] CoG távolsága az első tengelytől
b          = L * distrF;   % [m] CoG távolsága a hátsó tengelytől
T_F        = 1.22;         % [m] Első nyomtáv
T_R        = 1.20;         % [m] Hátsó nyomtáv

h_CG_SM    = 0.290;        % [m] Rugózott tömeg CoG magassága
h_CG_total = 0.273;        % [m] Teljes autó CoG magassága
h_CG_NSM   = 0.044;        % [m] Rugózatlan tömeg CoG magassága

% Roll Center Magasságok (RC_calc.m és Diplomaterv alapján)
h_RC_F     = 0.123;       % [m] Első RC magasság (61.8 mm)
h_RC_R     = 0.127;       % [m] Hátsó RC magasság (118.2 mm)

% Roll Axis geometriai számítások
theta_RA_rad = atan((h_RC_F - h_RC_R) / L);
theta_RA_deg = rad2deg(theta_RA_rad);
h_RA_at_CG   = h_RC_R + (h_RC_F - h_RC_R) * (b / L);
dz           = h_CG_SM - h_RA_at_CG;                  % [m] Statikus rugózott tömeg erőkaria
d_perp       = (h_CG_total - h_RA_at_CG) * cos(theta_RA_rad); % [m] Statikus teljes autó erőkarja
 
%% 2. RUGÓK ÉS STABILIZÁTOROK (ARB) ALAPADATOK
K_spring_F  = 225;          % [lbs/in] Első főrugó
K_spring_R  = 225;          % [lbs/in] Hátsó főrugó

K_ARB_F = 0;                % [N/m] Első ARB össz, droplinkre vett merevsége
K_ARB_R = 0;                % [N/m] Hátsó ARB össz, droplinkre vett merevsége
 
% Stabilizátor setup: 'első-hátsó' sorrendben, mindkét tengelyen 'roll' vagy 'heave' típus
STAB_SETUP = 'roll-roll';   % 'roll-roll' | 'roll-heave' | 'heave-roll' | 'heave-heave'
 
K_HEAVE_F = 0;              % [N/m] Első heave stab. össz, droplinkre vett merevsége
K_HEAVE_R = 0;              % [N/m] Hátsó heave stab. össz, droplinkre vett merevsége
 
valid_setups = {'roll-roll', 'roll-heave', 'heave-roll', 'heave-heave'};
if ~any(strcmp(STAB_SETUP, valid_setups))
    error('Ismeretlen STAB_SETUP: %s (lehetőségek: %s)', STAB_SETUP, strjoin(valid_setups, ', '));
end
stab_types  = strsplit(STAB_SETUP, '-');
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
 
% Roll Inercia (kezdeti/statikus)
theta_x_CG   = 2.55;       % [kg*m^2]
theta_x_RC   = theta_x_CG + m_SM * (dz)^2;
 
% Váz torziós merevség
K_chassis_deg = 3500;                    % [Nm/deg] Váz torziós merevség (merev vázhoz írj Inf-et)
K_chassis     = K_chassis_deg * 180/pi;  % [Nm/rad]
 
% Aerodinamika
rho_air      = 1.2;      % [kg/m^3] Levegő sűrűsége
CLA          = 5.0;      % [m^2]    Leszorítóerő-tényező (C_L * A)
aero_distr_F = 0.50;     % [-]      Aero eloszlás: az első tengelyre eső arány
v_aero_kmh   = 0:1:120;  % [km/h]   Vizsgált sebességtartomány a hasmagasság-változáshoz
 
% Statikus hasmagasság
h_static_F_mm = 34;      % [mm] Első statikus hasmagasság
h_static_R_mm = 34;      % [mm] Hátsó statikus hasmagasság
 
%% 3. MOTION RATIO GÖRBÉK MEGADÁSA (GUI + EXCEL BETÖLTÉS / MENTÉS)
USE_GUI_FOR_CURVES = true;
eval_pts_mm = -30:1:30; % [mm] Kerékút értékelési tartomány
num_eval = length(eval_pts_mm);
 
target_excel = 'Célgörbe_MotionRatios.xlsx';   % CSAK BETÖLTÉSRE használt alapfájl
save_dir     = 'MR_Mentesek';                  % ide kerülnek az új, időbélyeges mentések
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
        -30, 30, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_1, y_init_1, eval_pts_mm);
        
    [MR_R_func, eval_y_2] = defineTargetCurveGUI('2. Hátsó Főrugó Motion Ratio (MR_R)', ...
        -30, 30, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_2, y_init_2, eval_pts_mm);
        
    [MR_ARB_F_func, eval_y_3] = defineTargetCurveGUI('3. Első stabilizátor Motion Ratio (MR_ARB_F, roll/heave)', ...
        -30, 30, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_3, y_init_3, eval_pts_mm);
        
    [MR_ARB_R_func, eval_y_4] = defineTargetCurveGUI('4. Hátsó stabilizátor Motion Ratio (MR_ARB_R, roll/heave)', ...
        -30, 30, 'Kerékút (Z) [mm]', 'Motion Ratio [-]', x_init_4, y_init_4, eval_pts_mm);
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
 
% Kerékmerevség függvények K_wheel(x) [N/m]
K_wheel_F_func = @(x) (K_spring_F * valtoszam) ./ (MR_F_func(x).^2);
K_wheel_R_func = @(x) (K_spring_R * valtoszam) ./ (MR_R_func(x).^2);
 
% Heave (együttes berugózás) merevség TENGELYENKÉNT [N/m]
K_heave_F_func = @(x) 2 * K_wheel_F_func(x) + K_HEAVE_F_act ./ (MR_ARB_F_func(x).^2);
K_heave_R_func = @(x) 2 * K_wheel_R_func(x) + K_HEAVE_R_act ./ (MR_ARB_R_func(x).^2);
K_heave_F_stat = K_heave_F_func(0);   % [N/m] statikus heave merevség, első tengely
K_heave_R_stat = K_heave_R_func(0);   % [N/m] statikus heave merevség, hátsó tengely
 
%% 4. CÉL OLDALGYORSULÁS ÉS DŐLÉSSZÖG CIKLUS (LÉPÉSKÖZ: FÉL TIZED FOK = 0.05°)
a_lat_g = 2;             % [G] Cél oldalgyorsulás
a_lat   = a_lat_g * g;   % [m/s^2]

% --- JACKING HATÁS SZÁMÍTÁSA AZ ADOTT a_lat CÉLÉRTÉKNÉL ---
K_Tire = 588 * valtoszam; % ~103,000 N/m Gumiabroncs függőleges merevség
K_wheel_F_stat = K_wheel_F_func(0);
K_wheel_R_stat = K_wheel_R_func(0);

K_ride_F_stat = (K_wheel_F_stat * K_Tire) / (K_wheel_F_stat + K_Tire);
K_ride_R_stat = (K_wheel_R_stat * K_Tire) / (K_wheel_R_stat + K_Tire);
K_ride_total_stat = 2 * K_ride_F_stat + 2 * K_ride_R_stat;

% Tengelyenkénti oldalerők és jacking erők
Fy_F_stat = (m_total * a_lat) * (1 - distrF);
Fy_R_stat = (m_total * a_lat) * distrF;

F_jack_F = Fy_F_stat * (h_RC_F / (T_F / 2));
F_jack_R = Fy_R_stat * (h_RC_R / (T_R / 2));

delta_h_jack = (F_jack_F + F_jack_R) / K_ride_total_stat; % [m] COG emelkedés

% Módosított (dinamikus) súlypontmagasságok és erőkarok a jacking miatt
h_CG_SM_dyn    = h_CG_SM + delta_h_jack;
h_CG_total_dyn = h_CG_total + delta_h_jack;

dz_dyn     = h_CG_SM_dyn - h_RA_at_CG;                           % [m] Rugózott tömeg erőkaria jackinggel
d_perp_dyn = (h_CG_total_dyn - h_RA_at_CG) * cos(theta_RA_rad); % [m] Teljes autó erőkarja jackinggel

% Frissített dőlési inercia a jackinggel megemelt súlypontra
theta_x_RC = theta_x_CG + m_SM * (dz_dyn)^2;

% Dőlőnyomaték a rugózott tömegen a megemelt súlyponttal (Jacking hatás)
M_roll  = m_SM * a_lat * dz_dyn; % [Nm]
 
% Ugyanez tengelyenként (mindkét tengely a saját RC-je körül)
M_roll_F_in = m_SM * distrF       * a_lat * (h_CG_SM_dyn - h_RC_F); % [Nm] első tengelyre jutó
M_roll_R_in = m_SM * (1 - distrF) * a_lat * (h_CG_SM_dyn - h_RC_R); % [Nm] hátsó tengelyre jutó
 
% Dőlésszög lépésköz: fél tized fok = 0.05 deg
deg_step = 0.001;           % [deg]
rad_step = deg2rad(deg_step);
 
% Statikus dőlésszög kezdeti becslés (a jackinggel növelt nyomatékkal)
K_wheel_ARB_F = K_ARB_F_act / (MR_ARB_F_func(0)^2);
K_wheel_ARB_R = K_ARB_R_act / (MR_ARB_R_func(0)^2);
K_roll_ARB_F  = K_wheel_ARB_F * T_F^2 / 4; % [Nm/rad]
K_roll_ARB_R  = K_wheel_ARB_R * T_R^2 / 4; % [Nm/rad]
 
K_roll_F_stat  = K_wheel_F_stat * (T_F^2 / 2) + K_roll_ARB_F;
K_roll_R_stat  = K_wheel_R_stat * (T_R^2 / 2) + K_roll_ARB_R;
phi_eq_stat    = M_roll / (K_roll_F_stat + K_roll_R_stat); % rad
 
% Dőlésszög vektor
phi_vec_deg = 0 : deg_step : (rad2deg(phi_eq_stat) * 1.5);
phi_vec_rad = deg2rad(phi_vec_deg);
N_steps     = length(phi_vec_rad);
 
% Tömbök az eredményeknek
K_wheel_F_vec = zeros(1, N_steps);
K_wheel_R_vec = zeros(1, N_steps);
K_roll_F_vec  = zeros(1, N_steps);
K_roll_R_vec  = zeros(1, N_steps);
K_roll_tot_vec= zeros(1, N_steps);
MN_vec        = zeros(1, N_steps);
TLTD_vec      = zeros(1, N_steps);
f_roll_vec    = zeros(1, N_steps);
f_ride_F_vec  = zeros(1, N_steps);
f_ride_R_vec  = zeros(1, N_steps);
M_res_vec     = zeros(1, N_steps);
phi_R_vec     = zeros(1, N_steps);   % hátsó tengely dőlésszöge
MD_vec        = zeros(1, N_steps);   % tényleges első nyomatékarány
M_F_res_vec   = zeros(1, N_steps);   % első tengely által felvett nyomaték
M_R_res_vec   = zeros(1, N_steps);   % hátsó tengely által felvett nyomaték
 
% Sarki rugózott tömegek a sajátfrekvencia visszaszámításához
m1_F = (m_SM * distrF) / 2;
m1_R = (m_SM * (1 - distrF)) / 2;
 
% Geometriai és NSM átterhelődések
delta_Fz_geom_F = (m_SM * a_lat * distrF * h_RC_F) / T_F;
delta_Fz_geom_R = (m_SM * a_lat * (1 - distrF) * h_RC_R) / T_R;
delta_Fz_NSM_F  = (2 * m_NSM_F * a_lat * h_CG_NSM) / T_F;
delta_Fz_NSM_R  = (2 * m_NSM_R * a_lat * h_CG_NSM) / T_R;
 
for i = 1:N_steps
    phi_F = phi_vec_rad(i);   % [rad] Az ELSŐ tengely dőlésszöge
 
    % ---------------- ELSŐ TENGELY ----------------
    x_F_outer = (T_F / 2) * sin(phi_F);   % Kerék elmozdulás [m]
 
    % Kerékmerevségek főrugókból
    K_wh_F_out = K_wheel_F_func(x_F_outer);
    K_wh_F_in  = K_wheel_F_func(-x_F_outer);
    K_wh_F_avg = (K_wh_F_out + K_wh_F_in) / 2;
    K_wheel_F_vec(i) = K_wh_F_avg;
 
    MR_ARB_F_curr     = MR_ARB_F_func(x_F_outer);
 
    K_wh_F_heave    = K_wh_F_avg + K_HEAVE_F_act / (2 * MR_ARB_F_curr^2);
    f_ride_F_vec(i) = (1 / (2 * pi)) * sqrt(K_wh_F_heave / m1_F);
 
    K_roll_ARB_F_curr = K_ARB_F_act / (MR_ARB_F_curr^2);
    K_roll_F_vec(i)   = K_wh_F_avg * (T_F^2 / 2) + K_roll_ARB_F_curr;
 
    % ---------------- VÁZ TORZIÓJA ----------------
    M_F_res_vec(i) = K_roll_F_vec(i) * phi_F;        % [Nm] első tengely által felvett nyomaték
    T_ch           = M_roll_F_in - M_F_res_vec(i);   % [Nm] vázon át a hátsó tengelyre jutó nyomaték
    phi_R          = phi_F - T_ch / K_chassis;       % [rad] hátsó tengely dőlése
    phi_R_vec(i)   = phi_R;
 
    % ---------------- HÁTSÓ TENGELY ----------------
    x_R_outer = (T_R / 2) * sin(phi_R);
 
    K_wh_R_out = K_wheel_R_func(x_R_outer);
    K_wh_R_in  = K_wheel_R_func(-x_R_outer);
    K_wh_R_avg = (K_wh_R_out + K_wh_R_in) / 2;
    K_wheel_R_vec(i) = K_wh_R_avg;
 
    MR_ARB_R_curr     = MR_ARB_R_func(x_R_outer);
 
    K_wh_R_heave    = K_wh_R_avg + K_HEAVE_R_act / (2 * MR_ARB_R_curr^2);
    f_ride_R_vec(i) = (1 / (2 * pi)) * sqrt(K_wh_R_heave / m1_R);
 
    K_roll_ARB_R_curr = K_ARB_R_act / (MR_ARB_R_curr^2);
    K_roll_R_vec(i)   = K_wh_R_avg * (T_R^2 / 2) + K_roll_ARB_R_curr;
    M_R_res_vec(i)    = K_roll_R_vec(i) * phi_R;     % [Nm] hátsó tengely által felvett nyomaték
 
    % ---------------- EREDŐ MENNYISÉGEK ----------------
    K_roll_tot_vec(i) = K_roll_F_vec(i) + K_roll_R_vec(i);
 
    % Magic Number [%]
    MN_vec(i) = (K_roll_F_vec(i) / K_roll_tot_vec(i)) * 100;
 
    % Tényleges első nyomatékarány [%]
    T_ch_lin  = (M_roll_F_in / K_roll_F_vec(i) - M_roll_R_in / K_roll_R_vec(i)) / ...
                (1 / K_chassis + 1 / K_roll_F_vec(i) + 1 / K_roll_R_vec(i));
    MD_vec(i) = (M_roll_F_in - T_ch_lin) / M_roll * 100;
 
    % Elasztikus átterhelődés a DINAMIKUS MERŐLEGES ERŐKARRAL (d_perp_dyn)
    delta_Fz_elast_F = (m_SM * a_lat * d_perp_dyn / T_F) * (MD_vec(i) / 100);
    delta_Fz_elast_R = (m_SM * a_lat * d_perp_dyn / T_R) * ((100 - MD_vec(i)) / 100);
 
    % Teljes átterhelődés tengelyenként
    delta_Fz_tot_F = delta_Fz_geom_F + delta_Fz_elast_F + delta_Fz_NSM_F;
    delta_Fz_tot_R = delta_Fz_geom_R + delta_Fz_elast_R + delta_Fz_NSM_R;
 
    % Total Load Transfer Distribution [%]
    TLTD_vec(i) = (delta_Fz_tot_F / (delta_Fz_tot_F + delta_Fz_tot_R)) * 100;
 
    % Roll Frekvencia [Hz] (a frissített theta_x_RC-vel)
    f_roll_vec(i) = (1 / (2 * pi)) * sqrt(K_roll_tot_vec(i) / theta_x_RC);
 
    % Ellenálló dőlőnyomaték
    M_res_vec(i) = M_F_res_vec(i) + M_R_res_vec(i);
end
 
% Egyensúlyi dőlésszög megkeresése (ahol M_res == M_roll)
[~, eq_idx] = min(abs(M_res_vec - M_roll));
if eq_idx == N_steps
    warning('Az egyensúlyi dőlésszög a vizsgált tartomány szélére esik - növeld a phi_vec_deg felső határát.');
end
phi_eq_deg   = phi_vec_deg(eq_idx);                 % első tengely [deg]
phi_eq_R_deg = rad2deg(phi_R_vec(eq_idx));          % hátsó tengely [deg]
T_ch_eq      = M_roll_F_in - M_F_res_vec(eq_idx);   % [Nm] váz torziós nyomaték
 
%% 5. EREDMÉNYEK KIÍRÁSA
fprintf('=========================================================================\n');
fprintf('  KANYARODÁSI KASZTNIDŐLÉS ÉS ÁTTERHELŐDÉS LEFOLYÁS (a_lat = %.2f G)\n', a_lat_g);
fprintf('=========================================================================\n');
fprintf('Jacking hatás: COG emelkedés = %.2f mm | Dinamikus CoG (rugózott) = %.1f mm\n', delta_h_jack*1000, h_CG_SM_dyn*1000);
fprintf('Első RC: %5.1f mm | Hátsó RC: %5.1f mm | Roll Axis dőlés: %.2f deg\n', h_RC_F*1000, h_RC_R*1000, theta_RA_deg);
fprintf('Kiszámított egyensúlyi dőlésszög (Steady-State Roll Angle): első = %.3f deg | hátsó = %.3f deg\n', phi_eq_deg, phi_eq_R_deg);
fprintf('Váz torziós merevség: %.0f Nm/deg | váz elcsavarodás: %.4f deg | váz torziós nyomaték (első->hátsó): %.1f Nm\n', ...
    K_chassis_deg, phi_eq_deg - phi_eq_R_deg, T_ch_eq);
fprintf('Dőlőnyomaték tengelyenként (váz nélkül): első = %.1f Nm | hátsó = %.1f Nm\n', M_roll_F_in, M_roll_R_in);
fprintf('Dőlőnyomaték tengelyenként (váz torzióval): első = %.1f Nm | hátsó = %.1f Nm\n', M_F_res_vec(eq_idx), M_R_res_vec(eq_idx));
fprintf('Stabilizátor setup: %s (első: %s | hátsó: %s)\n', STAB_SETUP, stab_type_F, stab_type_R);
fprintf('Statikus heave merevség (tengely): Első = %.1f N/mm | Hátsó = %.1f N/mm\n', K_heave_F_stat / 1000, K_heave_R_stat / 1000);
fprintf('Kiszámított statikus Ride Frekvenciák: Első = %.2f Hz | Hátsó = %.2f Hz\n', ...
    (1 / (2 * pi)) * sqrt(K_heave_F_stat / (2 * m1_F)), (1 / (2 * pi)) * sqrt(K_heave_R_stat / (2 * m1_R)));
fprintf('Magic Number az egyensúlyi pontban: %.2f %% | tényleges nyomatékmegoszlás (váz torzióval): %.2f %%\n', MN_vec(eq_idx), MD_vec(eq_idx));
fprintf('Total Load Transfer Distribution (TLTD) az egyensúlyi pontban: %.2f %%\n', TLTD_vec(eq_idx));
fprintf('Roll Frekvencia az egyensúlyi pontban: %.2f Hz\n', f_roll_vec(eq_idx));
fprintf('=========================================================================\n\n');
 
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

%% 5C. JACKING HATÁS PARAMÉTERES LEFOLYÁSA
ay_vec = linspace(0, 2 * g, 100);
h_CG_dyn_vec = zeros(size(ay_vec));

for i = 1:length(ay_vec)
    ay_curr = ay_vec(i);
    Fy_F_c = (m_total * ay_curr) * (1 - distrF);
    Fy_R_c = (m_total * ay_curr) * distrF;

    F_jack_F_c = Fy_F_c * (h_RC_F / (T_F / 2));
    F_jack_R_c = Fy_R_c * (h_RC_R / (T_R / 2));

    dh_j_c = (F_jack_F_c + F_jack_R_c) / K_ride_total_stat;
    h_CG_dyn_vec(i) = h_CG_total + dh_j_c;
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
%  7. CSILLAPÍTÁS - ADATOK ÉS BEÁLLÍTÁSOK (DamperSetups_Calc5 kiterjesztése)
%  ========================================================================
f_vec  = linspace(0, 50, 500);       % [Hz]  A_RMS frekvenciatartománya
 
C_damper_matrix = [
    51081.6, 9940.1, 3916, 1962.9, 1129.1, 601.9;    % Low Speed Rebound (LSR)
    61889.8, 11165.6, 5319.1, 2375.7, 960.1, 944.1;  % Low Speed Compression (LSC)
    2040.3, 1402.4, 1457.8, 1212.2, 569.6, 386.4;    % High Speed Rebound (HSR)
    2253.6, 1929.4, 1659.3, 1029.9, 621.4, 445.1     % High Speed Compression (HSC)
];
regime_names = {'Low Speed Rebound (LSR)', 'Low Speed Compression (LSC)', ...
                'High Speed Rebound (HSR)', 'High Speed Compression (HSC)'};
regime_short = {'LSR', 'LSC', 'HSR', 'HSC'};
 
xi_target = [0.70; 0.70; 0.45; 0.45];
 
CLICK_F = [4 4 4 4];      % Első damper
CLICK_R = [4 4 4 4];      % Hátsó damper
 
MR_D_F_func = MR_F_func;
MR_D_R_func = MR_R_func;
 
CONSOLE_POS_MM = [-20 -10 0 10 20];   % [mm]
TABLE_POS_MM   = -30:5:30;            % [mm]
PEN_CAP        = 50;                  % [%]
 
if any(CLICK_F < 1 | CLICK_F > 6 | CLICK_F ~= round(CLICK_F)) || ...
   any(CLICK_R < 1 | CLICK_R > 6 | CLICK_R ~= round(CLICK_R))
    error('A CLICK_F / CLICK_R értékei egész számok lehetnek 1 és 6 között.');
end
 
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
    fprintf('%-6s |  %5.2f (%.2f)  |  %5.2f (%.2f)\n', regime_short{r}, xi_F_vec(r, eq_idx), xi_target(r), xi_R_vec(r, eq_idx), xi_target(r));
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
        yline(xi_target(r), ':', 'Color', col_reg(r, :), 'LineWidth', 1, 'HandleVisibility', 'off');
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
RF = analyze_axle_travel(m1_F, m2_F, MR_D_F_func, Kwh_F_eff, C_damper_matrix, xi_target, K_Tire, f_vec, x_d_m);
RR = analyze_axle_travel(m1_R, m2_R, MR_D_R_func, Kwh_R_eff, C_damper_matrix, xi_target, K_Tire, f_vec, x_d_m);
fprintf('Kész (%.1f s).\n\n', toc);
 
fprintf('=========================================================================\n');
fprintf('  DAMPER SETUP A KERÉKÚTON - jelmagyarázat\n');
fprintf('  ^ = a cél xi-hez legközelebbi click | * = minimális A_RMS click | # = mindkettő\n');
fprintf('  dA_RMS = az A_RMS többlete az adott pozícióhoz tartozó, elméletileg optimális xi-hez képest\n');
fprintf('=========================================================================\n');
print_travel_table('ELSŐ TENGELY',  RF, x_d_mm, xi_target, regime_short, CLICK_F, CONSOLE_POS_MM);
print_travel_table('HÁTSÓ TENGELY', RR, x_d_mm, xi_target, regime_short, CLICK_R, CONSOLE_POS_MM);
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
tau_steer = 0.1;                % [s] Oldalgyorsulás felépülési időállandója (kormányzás gyorsasága)
a_lat_t = a_lat * (1 - exp(-t/tau_steer)); % Időben felépülő oldalgyorsulás [m/s^2]

zeta_roll = 0.7;
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
    dFz_geom_F_t(k) = (m_SM * a_lat_t(k) * distrF * h_RC_F) / T_F;
    dFz_geom_R_t(k) = (m_SM * a_lat_t(k) * (1 - distrF) * h_RC_R) / T_R;

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
plot_travel_xi('ELSŐ TENGELY',  RF, x_d_mm, xi_target, regime_names, CLICK_F, tab_group);
plot_travel_xi('HÁTSÓ TENGELY', RR, x_d_mm, xi_target, regime_names, CLICK_R, tab_group);
plot_travel_arms('ELSŐ TENGELY',  RF, x_d_mm, regime_names, CLICK_F, tab_group);
plot_travel_arms('HÁTSÓ TENGELY', RR, x_d_mm, regime_names, CLICK_R, tab_group);
plot_travel_penalty('ELSŐ TENGELY',  RF, x_d_mm, regime_names, CLICK_F, PEN_CAP, tab_group);
plot_travel_penalty('HÁTSÓ TENGELY', RR, x_d_mm, regime_names, CLICK_R, PEN_CAP, tab_group);
plot_travel_best_click(RF, RR, x_d_mm, regime_short, CLICK_F, CLICK_R, tab_group);
show_click_tables(RF, RR, x_d_mm, TABLE_POS_MM, tab_group);

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
        'Ride frekvencia f_{ride}(x) [Hz]',               RF.f_ride,    RR.f_ride;
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
    title('Ride Frekvencia a Kerékúton', 'FontWeight', 'bold');
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