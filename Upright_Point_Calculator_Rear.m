clc
clear all

% --- 1. BEMENETI ADATOK (Módosítsd a saját értékeidre!) ---
Track_Width = 1550; % Teljes nyomtáv (mm)
SR = 7;           % Scrub Radius (mm)
MT = 47;           % Mechanical Trail (mm)
caster_deg = 8.0;  % Caster szög (fok)
KPI_deg = 14.0;    % Kingpin Inclination szög (fok)

pushrod_rocker_point = [-10.690, 150.881, 560.784]; % Vázoldali pushrod pont
pushrod_dist = 40;                  % Távolság az upright bekötéstől (mm)
pushrod_at_upper = false;             % true = UBJ, false = LBJ

tierod_chassis_point = [170.140, 130.958, 540.912]; % Vázoldali tierod pont
target_tierod_dist = 80;           % Merőleges távolság a kormányzási tengelytől
tierod_length = 636;

% Lengőkarok síkjai: A*x + B*y + C*z + D = 0 formátumban

P1 = [142.910, 130.958, 518.738]; % Kasztni bekötés elöl
P2 = [-423.620, 168.674, 400.738]; % Kasztni bekötés hátul
P3 = [-17, 700.155, 458.458]; % Egy tippelt külső pont

V1 = P2 - P1;
V2 = P3 - P1;

N = cross(V1, V2);

D = -dot(N, P1);

Plane_U = [N(1), N(2), N(3), D];
% Plane_U = [0.1, -0.05, 1, -450]; 

% Példa egy sík generálására 3 pontból
P4 = [205.471, 126.962, 324.866];
P5 = [-407.280, 161.941, 274.481];
P6 = [21.475, 725.943, 239.577]; 

% Két vektor a síkon
V3 = P5 - P4;
V4 = P6 - P4;

% Normálvektor (A, B, C)
N2 = cross(V3, V4);

% D kiszámítása: N dot P1 + D = 0 -> D = -dot(N, P1)
D2 = -dot(N2, P4);

% A sík vektora a fenti kódhoz:
Plane_L = [N2(1), N2(2), N2(3), D2];
% Plane_L = [-0.05, 0.02, 1, -150];

% --- 2. KORMÁNYZÁSI TENGELY (STEERING AXIS) DEFINIÁLÁSA ---
Half_Track = Track_Width/2;
CP = [0, Half_Track, 0];
P0_x = MT; 
P0_y = Half_Track-SR;
P0_z = 0;
P0 = [P0_x, P0_y, P0_z];

% A tengely irányvektora
dir_x = -tand(caster_deg);
dir_y = -tand(KPI_deg);
dir_z = 1;
V_dir = [dir_x, dir_y, dir_z];

% --- 3. METSZÉSPONTOK SZÁMÍTÁSA ---
% Itt hívjuk meg a lenti segédfüggvényeket
UBJ = intersect_line_plane(P0, V_dir, Plane_U);
LBJ = intersect_line_plane(P0, V_dir, Plane_L);

% --- 4. EREDMÉNYEK KIÍRÁSA A PARANCSSORBA ---
fprintf('--- Felfüggesztés bekötési pontok ---\n');
fprintf('Felső bekötés (UBJ): X = %.2f, Y = %.2f, Z = %.2f mm\n', UBJ(1), UBJ(2), UBJ(3));
fprintf('Alsó bekötés  (LBJ): X = %.2f, Y = %.2f, Z = %.2f mm\n', LBJ(1), LBJ(2), LBJ(3));

% --- 2. PUSHROD SZÁMÍTÁS ---
if pushrod_at_upper
    pivot = UBJ;
else
    pivot = LBJ;
end
vec_p = pushrod_rocker_point - pivot;
vec_p = vec_p / norm(vec_p);
Pushrod_Upright_Point = pivot + vec_p * pushrod_dist;

% --- 3. TIEROD SZÁMÍTÁS (Optimalizálás) ---
% Vázoldali lengőkar vektorok
v_arm_U = UBJ - P1; v_arm_L = LBJ - P4; 
dir_U = v_arm_U / norm(v_arm_U); dir_L = v_arm_L / norm(v_arm_L);

% % Optimalizáló függvény: a tierod és a lengőkarok irányvektora közötti szögeltérés minimalizálása
% % A pontot a kormányzási tengelytől vett távolságra kényszerítjük (cylinder constraint)
% fun = @(p) abs(dot((p - tierod_chassis_point)/norm(p - tierod_chassis_point), dir_U)) + ...
%     abs(dot((p - tierod_chassis_point)/norm(p - tierod_chassis_point), dir_L));
% 
% % Kezdőérték: a tengelytől 'tierod_dist_from_axis' távolságra egy pont
% x0 = P0 + 500*V_dir + [0, tierod_dist_from_axis, 0]; 
% 
% % Kényszer: a pont a tengelytől pontosan 'dist' távolságra legyen
% % Mivel fminsearch nincs megkötéssel, büntetőfüggvényt alkalmazunk:
% penalty = @(p) fun(p) + 1000 * abs(norm(cross(p - P0, V_dir/norm(V_dir))) - tierod_dist_from_axis);
% Tierod_Upright_Point = fminsearch(penalty, x0);

z_min = min(UBJ(3), LBJ(3)); 
z_max = max(UBJ(3), LBJ(3));

% Optimalizáló függvény: 
% 1. Párhuzamossági hiba (minimizálandó)
% 2. Kényszerek (büntetőfüggvényként, ha nem teljesülnek)
fun_tierod = @(p) ...
    10.0 * (abs(dot((p - tierod_chassis_point)/norm(p - tierod_chassis_point), v_arm_U)) + ...
    abs(dot((p - tierod_chassis_point)/norm(p - tierod_chassis_point), v_arm_L))) + ...
    1000 * (norm(cross(p - P0, V_dir/norm(V_dir))) - target_tierod_dist)^2 + ...
    1000 * (norm(p - tierod_chassis_point) - tierod_length)^2 + ...
    500 * (max(0, z_min - p(3)) + max(0, p(3) - z_max)); % Z-korlát: lengőkarok között

% Kezdőérték
x0 = (UBJ + LBJ) / 2 + [0, target_tierod_dist, 0];
Tierod_Upright_Point = fminsearch(fun_tierod, x0);

% --- Hibaellenőrzés ---
dist_axis = norm(cross(Tierod_Upright_Point - P0, V_dir/norm(V_dir)));
dist_chassis = norm(Tierod_Upright_Point - tierod_chassis_point);

if abs(dist_axis - target_tierod_dist) > 0.1 || abs(dist_chassis - tierod_length) > 0.1
    error('GEOMETRIAI HIBA: A Tierod hossz és a kormánytengely távolság nem metszik egymást!');
else
    fprintf('Tierod pozíció: [%.2f, %.2f, %.2f]\n', Tierod_Upright_Point(1), Tierod_Upright_Point(2), Tierod_Upright_Point(3));
end

% 3D vizualizáció
plot_suspension(CP, P0, V_dir, UBJ, LBJ, Pushrod_Upright_Point, Tierod_Upright_Point, pushrod_rocker_point, tierod_chassis_point);

% =========================================================================
% --- SEGÉDFÜGGVÉNYEK (Ezeknek kötelezően a fájl legvégén kell lenniük) ---
% =========================================================================

function P_int = intersect_line_plane(P0, V_dir, Plane)
% Kiszámítja egy 3D egyenes és egy sík metszéspontját.
N = Plane(1:3); % Sík normálvektora [A, B, C]
D = Plane(4);   % D konstans

numerator = - (dot(N, P0) + D);
denominator = dot(N, V_dir);

if abs(denominator) < 1e-6
    error('A kormányzási tengely párhuzamos a lengőkar síkjával! Nincs metszéspont.');
end

t = numerator / denominator;
P_int = P0 + t * V_dir;
end

function plot_suspension(CP, P0, V_dir, UBJ, LBJ, Pushrod_Upright_Point, Tierod_Upright_Point, pushrod_rocker_point, tierod_chassis_point)
    figure('Name', 'Global Kingpin Axis Geometry');
    hold on; grid on; axis equal;
    
    % Autó középvonala (Centerline Y=0)
    plot3([-200, 200], [0, 0], [0, 0], 'g-.', 'LineWidth', 2);
    text(0, 0, 0, ' Centerline (Y=0)', 'Color', 'g', 'FontWeight', 'bold');
    
    % Contact Patch (CP)
    plot3(CP(1), CP(2), CP(3), 'ks', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
    text(CP(1), CP(2)+20, CP(3), ' Contact Patch');
    
    % Talaj döféspont
    plot3(P0(1), P0(2), P0(3), 'mx', 'MarkerSize', 8, 'LineWidth', 2);
    text(P0(1), P0(2)-40, P0(3), ' Döféspont (P0)', 'Color', 'm');
    
    % Kormányzási tengely vonala
    t_max = UBJ(3) + 100;
    SA_line = [P0; P0 + t_max * V_dir];
    plot3(SA_line(:,1), SA_line(:,2), SA_line(:,3), 'k--', 'LineWidth', 1.5);
    
    % Bekötési pontok
    plot3(UBJ(1), UBJ(2), UBJ(3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    plot3(LBJ(1), LBJ(2), LBJ(3), 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
    
    text(UBJ(1)+20, UBJ(2), UBJ(3), ' UBJ (Felső)');
    text(LBJ(1)+20, LBJ(2), LBJ(3), ' LBJ (Alsó)');

    plot3([tierod_chassis_point(1), Tierod_Upright_Point(1)], ...
        [tierod_chassis_point(2), Tierod_Upright_Point(2)], ...
        [tierod_chassis_point(3), Tierod_Upright_Point(3)], 'g-o', 'LineWidth', 2);
    plot3([pushrod_rocker_point(1), Pushrod_Upright_Point(1)], ...
        [pushrod_rocker_point(2), Pushrod_Upright_Point(2)], ...
        [pushrod_rocker_point(3), Pushrod_Upright_Point(3)], 'm-o', 'LineWidth', 2);
    
    % Tengelyek
    xlabel('X - Előrefelé (mm)');
    ylabel('Y - Kifelé (mm)');
    zlabel('Z - Magasság (mm)');
    
    view(135, 25);
end