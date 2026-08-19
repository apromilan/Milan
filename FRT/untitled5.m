% =========================================================================
% FORMULA STUDENT - PUSHROD & PRELOAD SETUP CALCULATOR
% Cél: Kiszámolja a fizikai pushrod hosszt és a szükséges rugóelőfeszítést
%      a kívánt hasmagasság és droop eléréséhez.
% =========================================================================

clear; clc;

% --- 1. JÁRMŰ ÉS RUGÓ ADATOK ---
m_corner_sprung = 43.79;    % Rugózott saroksúly [kg]
k_s = 175.12684*175;               % Rugómerevség [N/mm]
L_spring_free = 120;        % Terheletlen rugóhossz [mm]
g = 9.81;

% --- 2. 3D HARDPOINT KOORDINÁTÁK CAD-BŐL [X, Y, Z] (mm) ---
% (Ezek a fix tervezési pontok a vázon és a csonkállványon)
H1 = [160.000 226.000 156.000];     
H2 = [-122.598 226.000 186.806];     
A_0 = [-20.475 482.786 310.000];    

B_pivot = [-86.840 169.822 563.784];        
B_axis_point_2 = [-84.470 155.712 545.260]; 

P_pr_0 = [-48.025 153.151 582.198];  
P_dmp_0 = [-78.900 110.016 611.104]; 
C_dmp = [-253.279 82.017 610.122];   

% --- 3. CÉL BEÁLLÍTÁSOK (TARGETS) ---
wheel_travel_target = 4;  % A kívánt hasmagasság változás a CAD-hez képest [mm]

track = 1220;    % Nyomtáv [mm]
roll_angle = 0.5;  % Tervezett max kasztni dőlés [deg]
min_rebound = (track/2) * sind(roll_angle); % Szükséges kerék droop [mm]

% =========================================================================
% TÉRBELI KINEMATIKAI SZÁMÍTÁSOK (INVERZ MEGOLDÓ)
% =========================================================================

% Vektorok számítása
u_wb = (H2 - H1) / norm(H2 - H1); 
u_bc = (B_axis_point_2 - B_pivot) / norm(B_axis_point_2 - B_pivot); 

% 1. LÉPÉS: Hova kerül a kerék (alsó bekötés) a cél hasmagasságon?
target_z = A_0(3) + wheel_travel_target;
opt_phi = @(phi) rodrigues_rot(A_0, H1, u_wb, phi)*[0;0;1] - target_z;
phi_sol = fzero(opt_phi, 0);
A_curr = rodrigues_rot(A_0, H1, u_wb, phi_sol);

% 2. LÉPÉS: AZ IDEÁLIS PUSHROD HOSSZ KISZÁMÍTÁSA
% Ahhoz, hogy a himba a tervezett optimális szögben álljon statikusan, 
% a pushrodnak ezt a távolságot kell áthidalnia:
L_pr_ideal = norm(P_pr_0 - A_curr);

% 3. LÉPÉS: LOKÁLIS MOTION RATIO SZÁMÍTÁSA (Numerikus deriválással)
% Kimozdítjuk a kereket 1 mm-rel felfelé (bump), és megnézzük a gátló mozgását
wheel_bump = 1.0; 
target_z_bump = A_curr(3) + wheel_bump;
opt_phi_bump = @(phi) rodrigues_rot(A_curr, H1, u_wb, phi)*[0;0;1] - target_z_bump;
phi_bump_sol = fzero(opt_phi_bump, 0);
A_bump = rodrigues_rot(A_curr, H1, u_wb, phi_bump_sol);

% Himba új szöge az 1 mm-es kerékmozgás hatására (a beállított pushroddal)
opt_theta_bump = @(theta) norm(rodrigues_rot(P_pr_0, B_pivot, u_bc, theta) - A_bump) - L_pr_ideal;
theta_bump_sol = fzero(opt_theta_bump, 0);

P_dmp_bump = rodrigues_rot(P_dmp_0, B_pivot, u_bc, theta_bump_sol);
L_dmp_static = norm(P_dmp_0 - C_dmp); 
L_dmp_bump = norm(P_dmp_bump - C_dmp);
damper_travel_1mm = L_dmp_static - L_dmp_bump;

% MR_3D = wheel_bump / damper_travel_1mm;
MR_3D = 1.246;

% 4. LÉPÉS: ERŐ ÉS ELŐFESZÍTÉS SZÁMÍTÁS
F_wheel = m_corner_sprung * g;
F_spring = F_wheel * MR_3D; 
x_static_comp = F_spring / k_s; 

droop_shock_target = min_rebound / MR_3D; 
preload_needed = x_static_comp - droop_shock_target;
L_spring_installed = L_spring_free - preload_needed;

% --- EREDMÉNYEK KIÍRATÁSA ---
clc;
fprintf('=== FORMULA STUDENT SETUP CALCULATOR ===\n\n');
fprintf('Cél hasmagasság változás:      %+.2f mm\n', wheel_travel_target);
fprintf('Cél kerék-droop (dőlésből):    %.2f mm\n', min_rebound);
fprintf('Lokális 3D Motion Ratio:       %.4f\n', MR_3D);
fprintf('---------------------------------------------------------\n');
fprintf('>>> FIZIKAI BEÁLLÍTÁSI ÉRTÉKEK A GARÁZSBAN <<<\n\n');
fprintf('1. PUSHROD HOSSZ (szemközéptől szemközépig): %.1f mm\n', L_pr_ideal);
fprintf('2. RUGÓ ELŐFESZÍTÉS (Preload):               %.1f mm\n', preload_needed);
fprintf('   (Beszerelt rugóhossz felemelt autón:      %.1f mm)\n', L_spring_installed);
fprintf('=========================================================\n');

% --- SEGÉDFÜGGVÉNY: Rodrigues-féle 3D rotációs formula ---
function P_rot = rodrigues_rot(P, O, u, theta)
v = P - O;
v_rot = v * cos(theta) + cross(u, v) * sin(theta) + u * dot(u, v) * (1 - cos(theta));
P_rot = O + v_rot;
end