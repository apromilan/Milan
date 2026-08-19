function full_kinematic_optimalization()
    clc; clear; close all;

    if exist('stop_opt.txt', 'file'), delete('stop_opt.txt'); 
    end

    % =========================================================================
    % 0. VEZÉRLŐ KAPCSOLÓ
    % true  = Futtatja az fmincon optimalizálót (eltarthat egy ideig)
    % false = Csak leteszteli a kiinduló (gyári) pontokat és kirajzolja a görbéket
    % =========================================================================
    OPTIMIZATION_ENABLED = true;

    %% 1. INICIALIZÁLÁS (Initial Guess) - A 24 optimalizálandó változó
    LCA_fore = [160.000, 226.000, 156.000];
    LCA_aft = [-122.598, 226.000, 186.806];
    LCA_upright = [0.000, 586.760, 105.000];
    UCA_fore = [148.070, 224.000, 360.000];
    UCA_aft = [-151.596, 224.000, 325.000];
    UCA_upright = [-15.000, 555.000, 275.000];
    TR_rack  = [65.000, 244.000, 164.000];
    TR_upright  = [76.000, 564.000, 150.000];
    x0 = [LCA_fore, LCA_aft, LCA_upright, UCA_fore, UCA_aft, UCA_upright, TR_rack, TR_upright];
    
    %% 2. KORLÁTOK (Aszimmetrikus Bounding Box)
    LCA_fore_box = [50, 10, 50]; 
    LCA_aft_box = [50, 10, 50];
    LCA_upright_box = [10, 10, 10]; 
    UCA_fore_box = [50, 10, 50]; 
    UCA_aft_box = [50, 10, 50];
    UCA_upright_box = [10, 10, 10]; 
    TR_rack_box  = [5, 30, 20];
    TR_upright_box  = [10, 10, 10];
    box_all = [LCA_fore_box, LCA_aft_box, LCA_upright_box, UCA_fore_box, UCA_aft_box, UCA_upright_box, TR_rack_box, TR_upright_box];
    
    lb = x0 - box_all;
    ub = x0 + box_all;    

    %% 3. BEÁLLÍTÁSOK (Söprési tartományok, célok és súlyok)
    Config = struct();
    Config.sweep_range_bump = -29:1:33;   % Berugózás
    Config.sweep_range_steer = -30:5:30;  % Kormányzás
    
    Config.Constraints.Max_WC_Y = 610; 
    Config.Constraints.Rim_Radius = 115; 
    Config.Constraints.Rod_Diameter = 20; 

    Config.Bump.Targets.Camber = [0.05, 0.0]; 
    Config.Bump.Targets.Toe    = [-0.00, 0.0]; 
    % Config.Bump.Targets.RollCenter   = [-1.00, 90.0];
    Config.Bump.Weights.Camber = 20;
    Config.Bump.Weights.Toe    = 10;
    Config.Bump.Weights.RollCenter   = 20;
    
    Config.Steer.Targets.Scrub = [0.1, 5.0]; 
    Config.Steer.Targets.MechTrail = [0.5, 10.0];
    Config.Steer.Weights.Scrub = 10;
    Config.Steer.Weights.MechTrail = 10;

    Config.Bump.Tolerances.Camber = 0.5;   
    Config.Bump.Tolerances.Toe    = 0.5;   
    Config.Bump.Tolerances.RollCenter   = 15.0;  
    Config.Steer.Tolerances.Scrub = 5.0;   
    Config.Steer.Tolerances.MechTrail = 5.0;   

    %% 4. VEZÉRLÉS LOGIKÁJA
    if OPTIMIZATION_ENABLED
        disp('========================================================================');
        disp('=== OPTIMALIZÁLÁS INDÍTÁSA (fmincon) ===');
        disp('Ha le akarod állítani úgy, hogy rajzoljon grafikonokat, hozz létre');
        disp('egy üres "stop_opt.txt" nevű fájlt abba a mappába, ahol a kódod van.');
        disp('========================================================================');
        
        % Beállítjuk az egyedi OutputFcn-t, ami figyeli a stop fájlt
        options = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'iter', 'MaxFunctionEvaluations', 1000, 'OutputFcn', @check_stop_signal);
        obj_fun = @(x) cost(x, Config);
        nonlcon_fun = @(x) kinematic_constraints(x, Config);
        try
            [x_opt, fval] = fmincon(obj_fun, x0, [], [], [], [], lb, ub, nonlcon_fun, options);
            disp(['Végső hiba (Cost): ', num2str(fval)]);
        catch ME % Matlab Exception
            if strcmp(ME.identifier, 'Optimization:UserStop')
                disp('Kézi megszakítás észlelve, az eddigi legjobb eredmények mentése és plotolása.');
                % Betöltjük az utolsó mentett legolcsóbb állapotot
                if exist('current_best_points.mat', 'file')
                    load('current_best_points.mat', 'points_best');
                    x_opt = points_best;
                else
                    x_opt = x0;
                end
            else
                rethrow(ME); % Ha valódi kódhiba történt, dobja ki
            end
        end
    else
        disp('========================================================================');
        disp('=== TESZT ÜZEMMÓD: Optimalizálás kikapcsolva ===');
        disp('Alapértelmezett pontok kinematikai vizsgálata.');
        disp('========================================================================');
        test_cost = cost(x0, Config);
        disp(['Kezdeti pontok hibája (Cost): ', num2str(test_cost)]);
        x_opt = x0;
    end
    
    %% 5. EREDMÉNYEK KIÉRTÉKELÉSE ÉS ÁBRÁZOLÁSA
    plot_results(x_opt, Config);

    if exist('stop_opt.txt', 'file'), delete('stop_opt.txt'); 
    end
    if exist('current_best_points.mat', 'file'), delete('current_best_points.mat'); 
    end
end

% =========================================================================
% OUTPUT FÜGGVÉNY A MANUÁLIS MEGSZAKÍTÁSHOZ
% =========================================================================
function stop = check_stop_signal(x, ~, state)
stop = false;

% Minden iterációban elmentjük az aktuális x-et, ha a felhasználó lelőné a programot
if strcmp(state, 'iter')
    points_best = x;
    save('current_best_points.mat', 'points_best');
end

% Ha létezik a fájl a mappában, leállítjuk az fmincon-t egy egyedi hibával, amit a try-catch elkap
if exist('stop_opt.txt', 'file')
    error('Optimization:UserStop', 'User requested stop via file.');
end
end

% =========================================================================
% KÖLTSÉGFÜGGVÉNY: A TELJES FSOLVE-OS KINEMATIKAI SZIMULÁCIÓT HÍVJA
% =========================================================================
function total_cost = cost(x, Config)
    total_cost = 0;
    
    % 1. Lefuttatjuk a kinematikát (Bump és Steer sweep) az aktuális x pontokra
    [result_bump, result_steer, valid] = simulate_kinematics(x, Config);
    
    if ~valid
        total_cost = 1e6; % BÜNTETÉS: Ha összecsuklik a futómű
        return;
    end
    
    % 2. Berugózás (Bump) kiértékelése
    for i = 1:length(Config.sweep_range_bump)
        wheel_travel = Config.sweep_range_bump(i);
        target_camber = polyval(Config.Bump.Targets.Camber, wheel_travel);
        target_toe = polyval(Config.Bump.Targets.Toe, wheel_travel);
        % target_roll_center  = polyval(Config.Bump.Targets.RollCenter, wheel_travel);
        
        cost_camber = Config.Bump.Weights.Camber * ((result_bump.Camber(i) - target_camber) / Config.Bump.Tolerances.Camber)^2;
        cost_toe = Config.Bump.Weights.Toe * ((result_bump.Toe(i) - target_toe) / Config.Bump.Tolerances.Toe)^2;
        % cost_roll_center = Config.Bump.Weights.RollCenter * ((result_bump.RollCenter(i) - target_roll_centr) / Config.Bump.Tolerances.RollCenter)^2;
        
        % total_cost = total_cost + cost_camber + cost_toe + cost_roll_center;
        total_cost = total_cost + cost_camber + cost_toe;
    end
    
    % 3. Kormányzás (Steer) kiértékelése
    for i = 1:length(Config.sweep_range_steer)
        rack_travel = Config.sweep_range_steer(i);
        target_scrub = polyval(Config.Steer.Targets.Scrub, rack_travel);
        target_mech_trail = polyval(Config.Steer.Targets.MechTrail, rack_travel);
        
        cost_scrub = Config.Steer.Weights.Scrub * ((result_steer.Scrub(i) - target_scrub) / Config.Steer.Tolerances.Scrub)^2;
        cost_mech_trail = Config.Steer.Weights.MechTrail * ((result_steer.MechTrail(i) - target_mech_trail) / Config.Steer.Tolerances.MechTrail)^2;
        
        total_cost = total_cost + cost_scrub + cost_mech_trail;
    end
end

% =========================================================================
% FŐ KINEMATIKAI MOTOR: A BASE PROGRAM PONTOS MÁSA (FSOLVE)
% =========================================================================
function [result_bump, result_steer, valid] = simulate_kinematics(x, Config)
    valid = true;
    result_bump = struct('Camber', [], 'Toe', [], 'RollCenter', []);
    result_steer = struct('Scrub', [], 'MechTrail', []);
    
    % 1. A teljes 18-pontos struktúra felépítése
    points = struct('name', {}, 'pos', {}, 'fixed', {});
    
    % Felső lengőkar
    points(1).name = 'UCA_fore'; points(1).pos = x(10:12); points(1).fixed = true;
    points(2).name = 'UCA_aft'; points(2).pos = x(13:15); points(2).fixed = true;
    points(3).name = 'UCA_upright'; points(3).pos = x(16:18); points(3).fixed = false;
    % Alsó lengőkar
    points(4).name = 'LCA_fore'; points(4).pos = x(1:3); points(4).fixed = true;
    points(5).name = 'LCA_aft'; points(5).pos = x(4:6); points(5).fixed = true;
    points(6).name = 'LCA_upright'; points(6).pos = x(7:9); points(6).fixed = false;
    % Kormány
    points(7).name = 'TR_rack';  points(7).pos = x(19:21); points(7).fixed = false;
    points(8).name = 'TR_upright'; points(8).pos = x(22:24); points(8).fixed = false;
    % Fixen hagyott mozgó belsőségek (Ezekre most nem optimalizálunk, de mozognak)
    points(9).name  = 'PR_rocker'; points(9).pos = [-48.025, 153.151, 582.198]; points(9).fixed = false;
    points(10).name = 'PR_upright'; points(10).pos = [-20.475, 482.786, 305]; points(10).fixed = false;
    points(11).name = 'Rocker_pivot'; points(11).pos = [-84.470, 155.712, 545.260]; points(11).fixed = true;
    points(12).name = 'Rocker_center'; points(12).pos = [-86.84, 169.822, 563.784]; points(12).fixed = true;
    points(13).name = 'Damper_rocker'; points(13).pos = [-78.900, 110.016, 611.104]; points(13).fixed = false;
    points(14).name = 'Damper_chass'; points(14).pos = [-253.279, 82.017, 610.122]; points(14).fixed = true;
    points(15).name = 'Wheel_center'; points(15).pos = [0, 610, 193]; points(15).fixed = false;
    points(16).name = 'ARB_rocker'; points(16).pos = [-69.613, 126.436, 599.785]; points(16).fixed = false;
    points(17).name = 'ARB_blade'; points(17).pos = [72.237, 126.440, 614.444]; points(17).fixed = false;
    points(18).name = 'ARB_torsionbar'; points(18).pos = [75.097, 126.436, 585.090]; points(18).fixed = true;

    % Szabad indexek
    free_indices = find(~[points.fixed]);
    chassis_fixed = setdiff(find([points.fixed]), 16); % 16 (ARB) nem kapja meg a dz eltolást
    
    % Távolság kényszerek generálása az AKTUÁLIS pontokból
    constraints = {};
    add_dist = @(c, i, j) [c, {@(p) norm(p(j).pos - p(i).pos) - norm(points(j).pos - points(i).pos)}];
    constraints = add_dist(constraints, 1, 3); 
    constraints = add_dist(constraints, 2, 3);
    constraints = add_dist(constraints, 4, 6); 
    constraints = add_dist(constraints, 5, 6);
    constraints = add_dist(constraints, 3, 6); 
    constraints = add_dist(constraints, 8, 6);
    constraints = add_dist(constraints, 8, 3); 
    constraints = add_dist(constraints, 7, 8);
    constraints = add_dist(constraints, 9, 10); 
    constraints = add_dist(constraints, 3, 10);
    constraints = add_dist(constraints, 1, 10); 
    constraints = add_dist(constraints, 2, 10);
    constraints = add_dist(constraints, 9, 11); 
    constraints = add_dist(constraints, 9, 12);
    constraints = add_dist(constraints, 3, 15); 
    constraints = add_dist(constraints, 6, 15);
    constraints = add_dist(constraints, 8, 15);
    constraints = add_dist(constraints, 9, 13);
    constraints = add_dist(constraints, 11, 13); 
    constraints = add_dist(constraints, 12, 13);
    constraints = add_dist(constraints, 16, 11); 
    constraints = add_dist(constraints, 16, 12);
    constraints = add_dist(constraints, 16, 17); 
    constraints = add_dist(constraints, 16, 9);
    constraints = add_dist(constraints, 17, 18);
    % Szög kényszer U bar miatt
    constraints{end+1} = @(all_points) dot(all_points(17).pos - all_points(18).pos, [0 1 0]);
    
    % Statikus alapváltozók elmentése
    static_z15 = points(15).pos(3);
    static_y7 = points(7).pos(2);
    static_z7 = points(7).pos(3);
    initial_x7 = points(7).pos(1);
    
    fsolve_opts = optimoptions('fsolve', 'Display', 'off', 'StepTolerance', 1e-8, 'FunctionTolerance', 1e-8);
    
    % Szabad változók kezdeti kinyerése
    x_free_base = [];
    for idx = free_indices, x_free_base = [x_free_base, points(idx).pos]; 
    end
    
    % Statikus referencia (Wheel rotationhez kell a base programból)
    A_stat = [points(6).pos; points(3).pos; points(8).pos];
    muA = mean(A_stat);

    % ==========================================================
    % 1. PURE BUMP SWEEP SZIMULÁCIÓJA
    % ==========================================================
    zero_idx_bump = find(Config.sweep_range_bump == 0, 1);
    bump_camber = zeros(length(Config.sweep_range_bump), 1);
    bump_toe = zeros(size(bump_camber));
    bump_roll_center = zeros(size(bump_camber));
    
    x_free_curr = x_free_base;
    
    % Felfelé (Bound)
    for i = zero_idx_bump : length(Config.sweep_range_bump)
        dz = Config.sweep_range_bump(i);
        [x_free_curr, B_curr, p_solved, ok] = run_step(dz, 0, x_free_curr, points, free_indices, chassis_fixed, constraints, static_z15, static_y7, initial_x7, static_z7, fsolve_opts);
        if ~ok, valid = false; 
            return; 
        end
        [camber, toe, roll_center, ~, ~] = math(p_solved, A_stat, muA, B_curr);
        bump_camber(i) = camber; 
        bump_toe(i) = toe; 
        bump_roll_center(i) = roll_center;
    end
    
    x_free_curr = x_free_base; % Vissza 0-ra
    % Lefelé (Rebound)
    for i = zero_idx_bump-1 : -1 : 1
        dz = Config.sweep_range_bump(i);
        [x_free_curr, B_curr, p_solved, ok] = run_step(dz, 0, x_free_curr, points, free_indices, chassis_fixed, constraints, static_z15, static_y7, initial_x7, static_z7, fsolve_opts);
        if ~ok, valid = false; 
            return; 
        end
        [camber, toe, roll_center, ~, ~] = math(p_solved, A_stat, muA, B_curr);
        bump_camber(i) = camber; 
        bump_toe(i) = toe; 
        bump_roll_center(i) = roll_center;
    end
    
    result_bump.Camber = bump_camber; 
    result_bump.Toe = bump_toe; 
    result_bump.RollCenter = bump_roll_center;
    
    % ==========================================================
    % 2. PURE STEER SWEEP SZIMULÁCIÓJA
    % ==========================================================
    zero_idx_steer = find(Config.sweep_range_steer == 0, 1);
    steer_scrub = zeros(length(Config.sweep_range_steer), 1);
    steer_mech_trail = zeros(size(steer_scrub));
    
    x_free_curr = x_free_base;
    
    % Jobbra
    for i = zero_idx_steer : length(Config.sweep_range_steer)
        dy = Config.sweep_range_steer(i);
        [x_free_curr, B_curr, p_solved, ok] = run_step(0, dy, x_free_curr, points, free_indices, chassis_fixed, constraints, static_z15, static_y7, initial_x7, static_z7, fsolve_opts);
        if ~ok, valid = false; 
            return; 
        end
        [~, ~, ~, scrub, mech_trail] = math(p_solved, A_stat, muA, B_curr);
        steer_scrub(i) = scrub; 
        steer_mech_trail(i) = mech_trail;
    end
    
    x_free_curr = x_free_base;
    % Balra
    for i = zero_idx_steer-1 : -1 : 1
        dy = Config.sweep_range_steer(i);
        [x_free_curr, B_curr, p_solved, ok] = run_step(0, dy, x_free_curr, points, free_indices, chassis_fixed, constraints, static_z15, static_y7, initial_x7, static_z7, fsolve_opts);
        if ~ok, valid = false; 
            return; 
        end
        [~, ~, ~, scrub, mech_trail] = math(p_solved, A_stat, muA, B_curr);
        steer_scrub(i) = scrub; 
        steer_mech_trail(i) = mech_trail;
    end
    
    result_steer.Scrub = steer_scrub; 
    result_steer.MechTrail = steer_mech_trail;
end

% SEGÉDFÜGGVÉNY AZ EGYETLEN LÉPÉS MEGOLDÁSÁHOZ (FSOLVE)
function [x_sol, B_curr, p_solved, ok] = run_step(dz, dy, x_guess, points_base, free_indices, chassis_fixed, constraints, static_z15, static_y7, initial_x7, static_z7, opts)
    p_temp = points_base;
    for i = chassis_fixed
        p_temp(i).pos(3) = p_temp(i).pos(3) - dz;
    end
    target_z15 = static_z15;
    target_y7  = static_y7 + dy;
    target_z7  = static_z7 - dz;
    [x_sol, ~, exitflag] = fsolve(@(x) compute_res(x, p_temp, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7), x_guess, opts);
    ok = (exitflag > 0);
    p_solved = p_temp;
    k = 1;
    for idx = free_indices
        p_solved(idx).pos = x_sol(k : k+2);
        k = k + 3;
    end
    B_curr = [p_solved(6).pos; p_solved(3).pos; p_solved(8).pos];
end

% AZ FSOLVE RESIDUAL FÜGGVÉNYE
function residuals = compute_res(x_free, p_base, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7)
    p = p_base;
    k = 1;
    for idx = free_indices
        p(idx).pos = x_free(k : k+2);
        k = k + 3;
    end
    residuals = zeros(length(constraints), 1);
    for c = 1:length(constraints)
        residuals(c) = constraints{c}(p);
    end
    residuals(end+1) = p(7).pos(1) - initial_x7;
    residuals(end+1) = p(7).pos(3) - target_z7;
    residuals(end+1) = p(15).pos(3) - target_z15;
    residuals(end+1) = p(7).pos(2) - target_y7;
end

% =========================================================================
% MATEMATIKA
% =========================================================================
function [camber, toe, roll_center, scrub, mech_trail] = math(p, A_stat, muA, B_curr)
    
    % SVD Forgatás
    muB = mean(B_curr);
    A0 = A_stat - muA;
    B0 = B_curr - muB;
    H = A0' * B0;
    [U, ~, V] = svd(H);
    R = V * U';
    if det(R) < 0
        V(:,3) = -V(:,3);
        R = V * U';
    end
    
    % --- Camber (Gumi proj. alapján) ---
    pos_center_s = [0, 610, 193]; % Statikus
    pos_top_s = pos_center_s + [0 0 193];
    pos_bottom_s = pos_center_s + [0 0 -193];
    pos_front_s = pos_center_s + [193 0 0];
    pos_rear_s = pos_center_s + [-193 0 0];
    
    pos_top_c = (R * (pos_top_s' - muA'))' + muB;
    pos_bottom_c = (R * (pos_bottom_s' - muA'))' + muB;
    pos_front_c = (R * (pos_front_s' - muA'))' + muB;
    pos_rear_c = (R * (pos_rear_s' - muA'))' + muB;
    
    horiz_vec = pos_front_c - pos_rear_c;
    horiz_vec(3) = 0;
    heading_unit = horiz_vec / norm(horiz_vec);
    transverse_unit = [-heading_unit(2), heading_unit(1), 0];
    vert_vec = pos_top_c - pos_bottom_c;
    
    tilt_lateral = dot(vert_vec, transverse_unit);
    tilt_vertical = dot(vert_vec, [0, 0, 1]);
    camber = rad2deg(atan2(tilt_lateral, tilt_vertical));
    
    % --- Toe ---
    current_normal = R * [0; 1; 0];
    unit_normal = current_normal / norm(current_normal);
    if abs(unit_normal(2)) > 1e-6
        toe = -rad2deg(atan(unit_normal(1) / unit_normal(2)));
    else
        toe = 90 * sign(unit_normal(1));
    end
    
    % --- Contact Patch ---
    gravity_dir = [0; 0; -1];
    proj_grav = gravity_dir - dot(gravity_dir, unit_normal) * unit_normal;
    if norm(proj_grav) > 1e-6
        down_dir = proj_grav / norm(proj_grav);
    else
        down_dir = [0; 0; -1];
    end
    t_gnd = (0 - p(15).pos(3)) / down_dir(3);
    cp = p(15).pos' + t_gnd * down_dir;
    cp_x = cp(1); cp_y = cp(2);
    
    % --- Kingpin ---
    kingpin_vec = p(3).pos - p(6).pos;
    kingpin_vec = kingpin_vec / norm(kingpin_vec);
    if abs(kingpin_vec(3)) > 1e-8
        t_ground = -p(3).pos(3) / kingpin_vec(3);
        kingpin_ground = p(3).pos + t_ground * kingpin_vec;
        kg_x = kingpin_ground(1); kg_y = kingpin_ground(2);
    else
        kg_x = p(15).pos(1); kg_y = p(15).pos(2);
    end
    
    scrub = cp_y - kg_y;
    mech_trail = kg_x - cp_x;
    
    % --- Front IC & Roll Center ---
    N_upper = cross(p(1).pos - p(3).pos, p(2).pos - p(3).pos); N_upper = N_upper / norm(N_upper);
    N_lower = cross(p(4).pos - p(6).pos, p(5).pos - p(6).pos); N_lower = N_lower / norm(N_lower);
    d_upper = dot(N_upper, p(3).pos);
    d_lower = dot(N_lower, p(6).pos);
    
    axis_dir = cross(N_upper, N_lower);
    if norm(axis_dir) > 1e-6
        axis_dir = axis_dir / norm(axis_dir);
        A_ = [N_upper; N_lower];
        b_ = [d_upper; d_lower];
        p_on_axis = pinv(A_) * b_;
        
        if abs(p_on_axis(1)) > 1e-8
            t_front  = (cp_x - p_on_axis(1)) / axis_dir(1);
            front_ic = p_on_axis + t_front * axis_dir';
            roll_center = front_ic(3);
        else
            roll_center = NaN;
        end
    else
        roll_center = NaN;
    end
end

% =========================================================================
% NEMLINEÁRIS KÉNYSZEREK (nonlcon) - Rúdütközések vizsgálata
% =========================================================================
function [c, ceq] = kinematic_constraints(x, Config)
    c = []; ceq = [];
    
    % Hogy ne hívjuk meg minden iterációnál az egész szimulációt, 
    % a kritikus kényszereket itt futtatjuk csak 3 állapotra: min, 0, max.
    
    wheel_states = [min(Config.sweep_range_bump), 0, max(Config.sweep_range_bump)];
    Config_nonlcon = Config; 
    Config_nonlcon.sweep_range_bump = wheel_states;
    Config_nonlcon.sweep_range_steer = [0]; % Steer alatt is kellene, mert a kombinált esetekben veszélyes általában
    
    [~, ~, valid] = simulate_kinematics(x, Config_nonlcon);
    
    if ~valid
        c = 999; % Ha elakad, keményen büntetjük
    end
end

% =========================================================================
% EREDMÉNYEK KIRAJZOLÁSA (Ahogy korábban is)
% =========================================================================
function plot_results(x_opt, Config)
    [result_bump, result_steer, valid] = simulate_kinematics(x_opt, Config);
    if ~valid
        disp('Hiba');
        return;
    end
    % Target generálás
    wheel_travel_data = Config.sweep_range_bump;
    bump_target = zeros(3, length(wheel_travel_data));
    for i=1:length(wheel_travel_data)
        bump_target(1,i) = polyval(Config.Bump.Targets.Camber, wheel_travel_data(i));
        bump_target(2,i) = polyval(Config.Bump.Targets.Toe, wheel_travel_data(i));
        % bump_target(3,i) = polyval(Config.Bump.Targets.RollCenter, wheel_travel_data(i));
    end
    rack_travel_data = Config.sweep_range_steer;
    steer_target = zeros(2, length(rack_travel_data));
    for i=1:length(rack_travel_data)
        steer_target(1,i) = polyval(Config.Steer.Targets.Scrub, rack_travel_data(i));
        steer_target(2,i) = polyval(Config.Steer.Targets.MechTrail, rack_travel_data(i));
    end
  
    figure('Name', 'Optimalizáció Eredménye: BUMP', 'WindowState', 'maximized');
    subplot(2, 2, 1);
    plot(wheel_travel_data, bump_target(1,:), 'r--', 'LineWidth', 2); 
    hold on; 
    grid on;
    plot(wheel_travel_data, result_bump.Camber, 'b-', 'LineWidth', 2);
    title('Camber Angle'); 
    legend('Target', 'Actual');
    
    subplot(2, 2, 2);
    plot(wheel_travel_data, bump_target(2,:), 'r--', 'LineWidth', 2); 
    hold on; 
    grid on;
    plot(wheel_travel_data, result_bump.Toe, 'b-', 'LineWidth', 2);
    title('Toe Angle'); 
    legend('Target', 'Actual');
    
    % subplot(2, 2, 3);
    % plot(wheel_travel_data, bump_target(3,:), 'r--', 'LineWidth', 2); 
    % hold on; 
    % grid on;
    % plot(wheel_travel_data, result_bump.RollCenter, 'b-', 'LineWidth', 2);
    % title('Roll Center Z'); 
    % legend('Target', 'Actual');
    
    figure('Name', 'Optimalizáció Eredménye: STEERING', 'WindowState', 'maximized');
    subplot(2, 1, 1);
    plot(rack_travel_data, steer_target(1,:), 'r--', 'LineWidth', 2); 
    hold on; 
    grid on;
    plot(rack_travel_data, result_steer.Scrub, 'b-', 'LineWidth', 2);
    title('Scrub Radius'); 
    legend('Target', 'Actual');
    
    subplot(2, 1, 2);
    plot(rack_travel_data, steer_target(2,:), 'r--', 'LineWidth', 2); 
    hold on; 
    grid on;
    plot(rack_travel_data, result_steer.MechTrail, 'b-', 'LineWidth', 2);
    title('Mechanical Trail'); 
    legend('Target', 'Actual');
end