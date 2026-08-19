% =========================================================================
% FORMULA STUDENT - 3D SPATIAL KINEMATICS & PRELOAD SOLVER
% Cél: 3D CAD koordináták alapján a pontos hasmagasság, gátló elmozdulás,
%      valós non-lineáris Motion Ratio és előfeszítés számítása.
% =========================================================================

clear; clc;

% --- 1. JÁRMŰ ÉS RUGÓ ADATOK ---
m_corner_sprung = 43.79;    % Rugózott saroksúly [kg]
k_s = 30.647;               % Rugómerevség [N/mm]
L_spring_free = 120;        % Terheletlen rugóhossz [mm]
g = 9.81;

% --- 2. 3D HARDPOINT KOORDINÁTÁK CAD-BŐL [X, Y, Z] (mm) ---
% (A koordinátákat a design/tervezési hasmagasságban add meg!)

% Alsó lengőkar vázfelőli forgáspontjai (ez határozza meg a forgástengelyt)
H1 = [160.000 226.000 156.000];     % Első szilent/gömbfej
H2 = [-122.598 226.000 186.806];     % Hátsó szilent/gömbfej

% Pushrod alsó bekötése (az alsó lengőkaron vagy a csonkállványon)
A_0 = [-20.475 482.786 310.000];    

% Himba (Bellcrank) forgástengelye a vázon (Pivot) és a forgástengely iránya
B_pivot = [-86.840 169.822 563.784];        % Himba forgástengelyének közepe (1. pont) [X, Y, Z]
B_axis_point_2 = [-84.470 155.712 545.260]; % A tengely egy másik tetszőleges pontja (2. pont) [X, Y, Z]

% Himba bekötési pontjai (Design állapotban)
P_pr_0 = [-48.025 153.151 582.198];  % Ide csatlakozik a Pushrod a himbán
P_dmp_0 = [-78.900 110.016 611.104]; % Ide csatlakozik a Gátló a himbán

% Gátló vázfelőli fix bekötési pontja
C_dmp = [-253.279 82.017 610.122];   

% --- CÉL HASMAGASSÁG VÁLTOZÁS ---
wheel_travel_target = -4;  % pl. 10 mm ültetés a keréknél (negatív érték)

% --- 3. DINAMIKUS PARAMÉTEREK ---
track = 1220; % mm
roll_angle = 1; % deg
min_rebound = track/2*sind(roll_angle);

% =========================================================================
% TÉRBELI KINEMATIKAI SZÁMÍTÁSOK (3D VEKTORALGEBRA)
% =========================================================================

% Unit vektorok és fix hosszak számítása
u_wb = (H2 - H1) / norm(H2 - H1); % Lengőkar forgástengely egységvektora
% A himba forgástengelyének egységvektora a két megadott pontból:
u_bc = (B_axis_point_2 - B_pivot) / norm(B_axis_point_2 - B_pivot); 
L_pr = norm(P_pr_0 - A_0);        % Pushrod fix hossza

% 1. LÉPÉS: Lengőkar elforgatása a kerék kívánt mozgásához
% Megkeressük azt a dőlésszöget (phi), ahol az A pont Z koordinátája pontosan a kívánt mértékben változik.
target_z = A_0(3) + wheel_travel_target;
opt_phi = @(phi) rodrigues_rot(A_0, H1, u_wb, phi)*[0;0;1] - target_z;
phi_sol = fzero(opt_phi, 0);

% Az A pont új 3D pozíciója
A_curr = rodrigues_rot(A_0, H1, u_wb, phi_sol);

% 2. LÉPÉS: Himba elfordulásának számítása (theta)
% Megkeressük azt a theta szöget, ahol a himbán lévő pushrod-bekötés távolsága 
% az új A_curr ponttól pontosan megegyezik a pushrod fix hosszával (L_pr).
opt_theta = @(theta) norm(rodrigues_rot(P_pr_0, B_pivot, u_bc, theta) - A_curr) - L_pr;
theta_sol = fzero(opt_theta, 0);

% Himba új 3D pozíciói
P_pr_curr = rodrigues_rot(P_pr_0, B_pivot, u_bc, theta_sol);
P_dmp_curr = rodrigues_rot(P_dmp_0, B_pivot, u_bc, theta_sol);

% 3. LÉPÉS: Új gátló hossz és elmozdulás számítása
L_dmp_design = norm(P_dmp_0 - C_dmp);
L_dmp_curr = norm(P_dmp_curr - C_dmp);
damper_travel = L_dmp_design - L_dmp_curr;

% Valós, 3D pillanatnyi Motion Ratio (MR) ezen a ponton
MR_3D =  abs(wheel_travel_target) / damper_travel;

% --- ERŐ ÉS ELŐFESZÍTÉS SZÁMÍTÁS ---
F_wheel = m_corner_sprung * g;
F_spring = F_wheel * MR_3D; % Rugóra ható erő a 3D-s áttételen keresztül
x_static_comp = F_spring / k_s; % Statikus összenyomódás a súly alatt [mm]

% Feltételezve, hogy szeretnénk 15 mm droop-ot hagyni a gátlónál:
droop_shock_target = min_rebound / MR_3D; 
preload_needed = x_static_comp - droop_shock_target;
L_spring_installed = L_spring_free - preload_needed;

% --- EREDMÉNYEK KIÍRATÁSA ---
clc;
fprintf('=== 3D TÉRBELI KINEMATIKAI FUTÓMŰ MEGOLDÓ ===\n\n');
fprintf('Kerék függőleges elmozdulása:  %+.2f mm\n', wheel_travel_target);
fprintf('Pushrod alsó bekötés új 3D helye:   [%.1f, %.1f, %.1f] mm\n', A_curr);
fprintf('Himba-gátló bekötés új 3D helye:    [%.1f, %.1f, %.1f] mm\n', P_dmp_curr);
fprintf('---------------------------------------------------------\n');
fprintf('Gátló elmozdulása a térben (Damper Travel):  %.2f mm\n', damper_travel);
fprintf('Valós, lokális 3D Motion Ratio (Damper/Wheel): %.4f\n', MR_3D);
fprintf('Rendszer statikus ereje a rugónál:             %.1f N\n', F_spring);
fprintf('---------------------------------------------------------\n');
fprintf('>> AJÁNLOTT ELŐFESZÍTÉS (15 mm gátló-droophoz): %.1f mm\n', preload_needed);
fprintf('>> ELŐÍRT BESZERELT RUGÓHOSSZ (felemelt vázon):  %.1f mm\n', L_spring_installed);
fprintf('=========================================================\n');

% --- SEGÉDFÜGGVÉNY: Rodrigues-féle 3D rotációs formula ---
function P_rot = rodrigues_rot(P, O, u, theta)
    % P: forgatni kívánt pont koordinátája
    % O: egy pont a forgástengelyen (pl. Pivot)
    % u: a forgástengely irányú egységvektor
    % theta: forgatási szög radiánban
    v = P - O;
    v_rot = v * cos(theta) + cross(u, v) * sin(theta) + u * dot(u, v) * (1 - cos(theta));
    P_rot = O + v_rot;
end