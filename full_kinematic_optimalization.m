% =========================================================================
% FELFÜGGESZTÉS OPTIMALIZÁLÓ SCRIPT VÁZLAT
% =========================================================================
clear; clc; close all;

%% 1. INICIALIZÁLÁS (Initial Guess)
% A 8 pont (3-3 lengőkar, 2 kormányösszekötő) x, y, z koordinátái.
% Összesen 24 változó
% Sorrend: [x1,y1,z1, x2,y2,z2, ... x8,y8,z8]

flca_fore = [160.000 ; 226.000; 156.000];
flca_aft = [-122.598; 226.000; 186.806];
flca_upright = [0.000; 586.760; 105.000];
fuca_fore = [148.070; 224.000; 360.000];
fuca_aft = [-151.596; 224.000; 325.000];
fuca_upright = [-15.000; 555.000; 275.000];
tierod_rack = [65.000; 244.000; 164.000];
tierod_upright = [76.000; 564.000; 150.000];

x0 = [flca_fore', flca_aft', flca_upright', fuca_fore', fuca_aft', fuca_upright', tierod_rack', tierod_upright'];

%% 2. KORLÁTOK (Bounds) BEÁLLÍTÁSA
% Megadjuk, hogy az egyes pontok mettől meddig mozoghatnak a térben (mm-ben).
% Ezzel akadályozzuk meg, hogy a gömbfejek a vázon belülre kerüljenek.
d_flca_fore      = [20, 20, 20];   % +-20 mm minden irányba
d_flca_aft       = [20, 20, 20];
d_flca_upright   = [10,  5, 15];   % Az upright pontok szigorúbbak (pl. Y-ban csak 5 mm-t mozoghat kifelé/befelé)
d_fuca_fore      = [20, 20, 20];
d_fuca_aft       = [20, 20, 20];
d_fuca_upright   = [10,  5, 15];
d_tierod_rack    = [15, 15,  0];   % A kormánymű magassága (Z) FIX (0 mm mozgás)!
d_tierod_upright = [15, 10, 15];

% Összefűzzük a deltákat is egyetlen 1x24-es sorvektorrá
dx = [d_flca_fore, d_flca_aft, d_flca_upright, d_fuca_fore, d_fuca_aft, d_fuca_upright, d_tierod_rack, d_tierod_upright];

% Az lb és ub kiszámítása az x0-hoz képest:
lb = x0 - dx;
ub = x0 + dx;

%% 3. FMINCON BEÁLLÍTÁSOK
% Az SQP (Sequential Quadratic Programming) algoritmus általában jól
% teljesít nemlineáris mechanikai feladatoknál.
options = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'iter-detailed', 'MaxFunctionEvaluations', 5000, 'StepTolerance', 1e-6);

%% 4. OPTIMALIZÁLÁS FUTTATÁSA
disp('Optimalizálás indítása...');
% [x_opt, fval, exitflag, output] = fmincon(@suspension_objective, x0, [], [], [], [], lb, ub, @suspension_constraints, options);
cost = suspension_objective(x0);

disp('Optimalizálás befejeződött!');
% disp(['Végső célfüggvény érték (hiba): ', num2str(fval)]);

% =========================================================================
% FÜGGVÉNYEK: CÉLFÜGGVÉNY ÉS KINEMATIKA
% =========================================================================

function cost = suspension_objective(x)
    % Cél értékek (Amit el akarunk érni az fmincon-nal)
    target_RC_height = 50; 
    target_Camber = -1.5; 
    
    cost = 0; % Kezdeti hiba
    
    % Rugóút beállítása
    wheel_travel_range = 29:-1:-33; 
    N = length(wheel_travel_range);
    
    % Autó alapadatai (A base_program_front_left alapján)
    Wheelbase = 1540;  % mm
    Trackwidth = 1220; % mm
    wheel_radius = 193; % mm (10 colos kerék esetén kb. ennyi a sugár)
    
    % Eredmények tárolására szolgáló tömbök inicializálása
    Caster = zeros(N, 1); KPI = zeros(N, 1); Camber = zeros(N, 1);
    Toe = zeros(N, 1); Scrub = zeros(N, 1); Trail = zeros(N, 1);
    FVIC_Y = zeros(N, 1); FVIC_Z = zeros(N, 1);
    SVIC_X = zeros(N, 1); SVIC_Z = zeros(N, 1);
    Ackermann = zeros(N, 1); RC_height = zeros(N, 1);
    
    % Előző lépés pontjai a sebességvektoros IC számoláshoz
    pt_UCA_prev = []; pt_LCA_prev = [];

    % Inicializálás a Results struct-ba
    Results.Caster = zeros(N, 1);
    Results.KPI = zeros(N, 1);
    Results.Camber = zeros(N, 1);
    Results.Toe = zeros(N, 1);
    Results.Scrub = zeros(N, 1);
    Results.Trail = zeros(N, 1);
    Results.FVIC_Y = zeros(N, 1);
    Results.FVIC_Z = zeros(N, 1);
    Results.SVIC_X = zeros(N, 1);
    Results.SVIC_Z = zeros(N, 1);
    Results.Ackermann = zeros(N, 1);
    Results.RC_height = zeros(N, 1);
    
    % Végigmegyünk az összes rugóúton (indexelve)
    for i = 1:N
        wt = wheel_travel_range(i);
        
        % 1. KINEMATIKAI SZIMULÁCIÓ MEGHÍVÁSA
        % Lekérdezzük a 3D-s pontokat és a forgásmátrixot az aktuális rugóútnál
        [pt_UCA, pt_LCA, pt_TR, pt_WC, R_upright] = solve_geometry_for_step(x, wt);
        
        % =========================================================================
        % 2. PARAMÉTEREK SZÁMÍTÁSA AZ AKTUÁLIS LÉPÉSBEN (i. index)
        % (Ide került be a te kódod, minimális finomítással)
        % =========================================================================
        
        % --- 1. KORMÁNYZÁSI TENGELY (Kingpin Axis) ---
        v_SA = pt_UCA - pt_LCA; 
        u_SA = v_SA / norm(v_SA); 

        % --- 2. CASTER ÉS KPI ---
        Caster(i) = atand(v_SA(1) / v_SA(3)); 
        KPI(i)    = atand(v_SA(2) / v_SA(3)); 

        % --- 3. CAMBER ÉS TOE ---
        spindle_vec = R_upright * [0; 1; 0]; 
        Camber(i) = asind(spindle_vec(3)); 
        Toe(i)    = atand(spindle_vec(1) / spindle_vec(2));

        % --- 4. SCRUB RADIUS ÉS MECHANICAL TRAIL ---
        Z_ground = pt_WC(3) - wheel_radius; 
        t_ground = (Z_ground - pt_UCA(3)) / u_SA(3);
        P_intersect = pt_UCA + t_ground * u_SA; 
        Contact_Patch = [pt_WC(1), pt_WC(2), Z_ground]; 

        Trail(i) = P_intersect(1) - Contact_Patch(1); 
        Scrub(i) = P_intersect(2) - Contact_Patch(2); 

        % --- 5. ACKERMANN PERCENTAGE ---
        t_TR = (pt_TR(3) - pt_LCA(3)) / u_SA(3);
        P_SA_TR = pt_LCA + t_TR * u_SA; 
        arm_vec = pt_TR - P_SA_TR; 

        X_SA = P_SA_TR(1); Y_SA = P_SA_TR(2);
        % Osztás nullával védelem
        if abs(arm_vec(2)) > 1e-6
            X_int = X_SA + Y_SA * (arm_vec(1) / arm_vec(2)); 
            Ackermann(i) = (Wheelbase / abs(X_int - pt_WC(1))) * 100;
        else
            Ackermann(i) = NaN;
        end

        % --- 6. INSTANT CENTERS ---
        if i > 1
            v_UCA = pt_UCA - pt_UCA_prev;
            v_LCA = pt_LCA - pt_LCA_prev;
            
            % FVIC
            A_yz = pt_UCA(2:3); B_yz = pt_LCA(2:3);
            dirA_yz = [-v_UCA(3), v_UCA(2)]'; 
            dirB_yz = [-v_LCA(3), v_LCA(2)]'; 
            
            M_yz = [dirA_yz(1), -dirB_yz(1); dirA_yz(2), -dirB_yz(2)];
            rhs_yz = B_yz' - A_yz';
            
            if abs(det(M_yz)) > 1e-6 
                t_yz = M_yz \ rhs_yz;
                FVIC = A_yz' + t_yz(1) * dirA_yz;
                FVIC_Y(i) = FVIC(1); FVIC_Z(i) = FVIC(2);
            else
                FVIC_Y(i) = NaN; FVIC_Z(i) = NaN; 
            end
            
            % SVIC
            A_xz = [pt_UCA(1), pt_UCA(3)]; B_xz = [pt_LCA(1), pt_LCA(3)];
            dirA_xz = [-v_UCA(3), v_UCA(1)]';
            dirB_xz = [-v_LCA(3), v_LCA(1)]';
            
            M_xz = [dirA_xz(1), -dirB_xz(1); dirA_xz(2), -dirB_xz(2)];
            rhs_xz = B_xz' - A_xz';
            
            if abs(det(M_xz)) > 1e-6
                t_xz = M_xz \ rhs_xz;
                SVIC = A_xz' + t_xz(1) * dirA_xz;
                SVIC_X(i) = SVIC(1); SVIC_Z(i) = SVIC(2);
            else
                SVIC_X(i) = NaN; SVIC_Z(i) = NaN;
            end
            
            % --- ROLL CENTER MAGASSÁG SZÁMÍTÁSA ---
            % Ha van FVIC, kiszámoljuk, hol döfi át az Y=0 (kocsi közepe) síkot a Contact Patch-FVIC egyenes
            if ~isnan(FVIC_Y(i))
                m_rc = (FVIC_Z(i) - Z_ground) / (FVIC_Y(i) - pt_WC(2));
                RC_height(i) = Z_ground - m_rc * pt_WC(2);
            else
                RC_height(i) = NaN;
            end
        else
            FVIC_Y(i) = NaN; FVIC_Z(i) = NaN;
            SVIC_X(i) = NaN; SVIC_Z(i) = NaN;
            RC_height(i) = NaN;
        end

        pt_UCA_prev = pt_UCA;
        pt_LCA_prev = pt_LCA;

        % AZ EREDMÉNYEK MENTÉSE A STRUKTÚRÁBA
        Results.Caster(i) = Caster(i);
        Results.KPI(i) = KPI(i);
        Results.Camber(i) = Camber(i);
        Results.Toe(i) = Toe(i);
        Results.Scrub(i) = Scrub(i);
        Results.Trail(i) = Trail(i);
        Results.FVIC_Y(i) = FVIC_Y(i);
        Results.FVIC_Z(i) = FVIC_Z(i);
        Results.SVIC_X(i) = SVIC_X(i);
        Results.SVIC_Z(i) = SVIC_Z(i);
        Results.Ackermann(i) = Ackermann(i);
        Results.RC_height(i) = RC_height(i);
        
        % =========================================================================
        % 3. CÉLFÜGGVÉNY (HIBA) ÖSSZEGZÉSE (Amit minimalizálni akarunk)
        % =========================================================================
        if i > 1 && ~isnan(RC_height(i))
            error_RC = (target_RC_height - RC_height(i))^2;
            error_Camber = (target_Camber - Camber(i))^2;
            
            % A hiba hozzáadása az összköltséghez
            cost = cost + (1.0 * error_RC) + (10.0 * error_Camber);
        end
    end

    % Globális láthatóság biztosítása (ha optimalizálás közben is látni akarod)
    assignin('base', 'Results', Results); 
    assignin('base', 'wheel_travel_range', wheel_travel_range);
end

% =========================================================================
% KINEMATIKAI MEGOLDÓ (A "NEM DUMMY" RÉSZ)
% =========================================================================

function [pt_UCA, pt_LCA, pt_TR, pt_WC, R_upright] = solve_geometry_for_step(x, wt)

    x_guess = [x(7:9); x(16:18); x(22:24)]; 
    
    options = optimoptions('fsolve', 'Display', 'off', 'Algorithm', 'trust-region-dogleg');
    
    % Most már 7 kényszert oldunk meg 9 változóra? 
    % Nem, 9 ismeretlenünk van (3 pont x 3 koord), de a rendszerünk már eléggé kötött.
    [x_new, ~] = fsolve(@(xg) compute_residuals(xg, x, wt), x_guess, options);
    
    pt_LCA = x_new(1:3); 
    pt_UCA = x_new(4:6); 
    pt_TR  = x_new(7:9);
    pt_WC  = [0; 610; 193 + wt];
    
    % % Forgásmátrix: egyszerűsített orientáció az upright pontokból
    % v_axis = pt_UCA - pt_LCA; u_axis = v_axis/norm(v_axis);
    % R_upright = [u_axis, cross([0;0;1], u_axis), cross(u_axis, [0;1;0])]; 
    % R_upright felépítése (Gram-Schmidt-like módszer)
    z_axis = (pt_UCA - pt_LCA) / norm(pt_UCA - pt_LCA); % Ez a Kingpin tengely
    y_axis = [0; 1; 0]; % Eredeti keréktengely irány
    x_axis = cross(y_axis, z_axis); x_axis = x_axis / norm(x_axis);
    y_axis = cross(z_axis, x_axis); % Újra ortogonalizálva

    x_axis = x_axis(:); 
    y_axis = y_axis(:); 
    z_axis = z_axis(:);

    R_upright = [x_axis, y_axis, z_axis];
end

% =========================================================================
% FÜGGVÉNYEK: KÉNYSZEREK
% =========================================================================

function [c, ceq] = suspension_constraints(x)
% Nemlineáris kényszerek (Itt tiltjuk meg a fizikai képtelenségeket)

c = [];   % Egyenlőtlenségi kényszerek (pl. távolság > 0). c <= 0 formában!
ceq = []; % Egyenlőségi kényszerek

% Példa kényszer: A felső lengőkar váz felőli két pontja (x1,y1,z1 és x4,y4,z4)
% közötti távolság (alap/bázis) legalább 150 mm kell legyen.
% Mivel c <= 0 formát vár az fmincon, ezért: 150 - tavolsag <= 0

end

% =========================================================================
% KÉNYSZEREGYENLETEK (Residuals)
% =========================================================================
function res = compute_residuals(xg, x, wt)
    % xg: a mozgó pontok [LCA_u; UCA_u; TR_u]
    % x: a fix vázpontok [LCA_f, LCA_a, LCA_u, UCA_f, UCA_a, UCA_u, TR_rack, TR_upright]
    
    % Kerékközép mozgása
    pt_WC = [0; 610; 193 + wt]; 
    
    % Eredeti távolságok (kezdeti x0-ból számolva)
    d_WC_LCA = norm([0; 610; 193] - x(7:9));
    d_WC_UCA = norm([0; 610; 193] - x(16:18));
    d_TR = norm(x(22:24) - x(19:21)); % Tie-rod hossza: (TR_upright - TR_rack)
    
    res = [
        % Lengőkarok vázhoz viszonyított hossza (merev rudak)
        norm(xg(1:3) - x(1:3))^2 - norm(x(7:9) - x(1:3))^2;   
        norm(xg(1:3) - x(4:6))^2 - norm(x(7:9) - x(4:6))^2;   
        norm(xg(4:6) - x(10:12))^2 - norm(x(16:18) - x(10:12))^2; 
        norm(xg(4:6) - x(13:15))^2 - norm(x(16:18) - x(13:15))^2; 
        
        % Upright és kerékközép kapcsolata
        norm(xg(1:3) - pt_WC)^2 - d_WC_LCA^2; 
        norm(xg(4:6) - pt_WC)^2 - d_WC_UCA^2;
        
        % TIE-ROD KÉNYSZER:
        % A mozgó TR_upright pont (xg(7:9)) és a fix TR_rack pont (x(19:21)) távolsága
        norm(xg(7:9) - x(19:21))^2 - d_TR^2;
    ];
end

% =========================================================================
% EREDMÉNYEK PLOTTOLÁSA ÉS GEOMETRIA RAJZOLÁS
% =========================================================================
function plot_suspension_results(x, wheel_travel_range, Results)
figure('Name', 'Kinematikai Elemzés', 'WindowState', 'maximized');

% 1. Plotok
subplot(2,3,1); plot(wheel_travel_range, Results.Camber); title('Camber'); grid on;
subplot(2,3,2); plot(wheel_travel_range, Results.Toe); title('Toe'); grid on;
subplot(2,3,3); plot(wheel_travel_range, Results.RC_height); title('Roll Center Z'); grid on;
subplot(2,3,4); plot(wheel_travel_range, Results.Caster); title('Caster'); grid on;
subplot(2,3,5); plot(wheel_travel_range, Results.KPI); title('KPI'); grid on;

% --- 2. 3D Felfüggesztés Rajzolása ---
figure('Name', 'Felfüggesztés Geometria');
[pt_UCA, pt_LCA, pt_TR, pt_WC, ~] = solve_geometry_for_step(x, 0);

% A vázpontok kinyerése az 'x' vektorból (3x4-es mátrixot csinálunk)
% A vázpontok sorrendje: [x(1:3), x(4:6), x(10:12), x(13:15)]
% (A 19:21-es rack pontot is hozzáadhatjuk a vázhoz)
chassis_pts = [x(1:3), x(4:6), x(10:12), x(13:15), x(19:21)];

% Ellenőrzés: 
% A plot3(X, Y, Z) elvárja, hogy X, Y és Z külön sorvektorok legyenek.
% Mivel a chassis_pts 3xN méretű, a megfelelő hivatkozás:
plot3(chassis_pts(1,:), chassis_pts(2,:), chassis_pts(3,:), 'ko', 'MarkerFaceColor', 'k', 'LineWidth', 2); 
hold on;

% Lengőkarok rajzolása (vázpontokhoz kötjük az upright pontokat)
% LCA: x(1:3) -> pt_LCA
plot3([x(1), pt_LCA(1)], [x(2), pt_LCA(2)], [x(3), pt_LCA(3)], 'b-o', 'LineWidth', 1.5);
% UCA: x(10:12) -> pt_UCA
plot3([x(10), pt_UCA(1)], [x(11), pt_UCA(2)], [x(12), pt_UCA(3)], 'r-o', 'LineWidth', 1.5);

grid on; axis equal; view(3);
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Felfüggesztés Geometria (0 mm rugóút)');
end

plot_suspension_results(x0, wheel_travel_range, Results);