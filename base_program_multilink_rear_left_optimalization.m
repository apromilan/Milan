function base_program_multilink_rear_left_optimalization()
    clc; clear; close all;

    % =========================================================================
    % 1. KÍVÁNT KINEMATIKAI CÉLPARAMÉTEREK
    % =========================================================================
    target.Caster = 12.0;  % Kívánt Caster szög (fok)
    target.KPI    = 14.0; % Kívánt KPI szög (fok)
    target.Scrub  = 7;    % Kívánt Scrub radius (mm)
    target.Trail  = 47;   % Kívánt Mechanical Trail (mm)
    target.RC_Z   = 100.0; % ÚJ: Kívánt Roll Center magasság a talajtól (mm)

    Wheelbase = 3000; % Tengelytáv (mm)
    CG_height = 300;  % Súlypont magasság (mm)
    Brake_perc = 0.64; % Fékerő arány hátul
    Drive_perc = 1; % Hajtásarány hátul
    
    % --- Geometriai alapértékek és Kerékközép ---
    wheel_radius = 360;
    WC_pos = [-3000.000, 775.000, 360.000]; % Kerékközép statikus helyzete
    Z_ground_static = WC_pos(3) - wheel_radius;

    % =========================================================================
    % 2. FELNI ÉS CSOMAGOLÁSI (PACKAGING) KÉNYSZEREK DEFINIÁLÁSA
    % =========================================================================
    rim_inner_radius = 231; % Felni belső szabad sugara (mm) X-Z síkban
    rim_inner_Y_plane = WC_pos(2) - 0; 

    % =========================================================================
    % 3. FIX VÁZPONTOK ÉS KEZDETI UPRIGHT BECSLÉS
    % =========================================================================
    points = struct('name', {}, 'pos', {}, 'fixed', {});

    % Váz oldali (Chassis) fix pontok
    points(1).name  = 'Upper Front Chassis';    points(1).pos = [-2610.180, 149.557, 471.424];  points(1).fixed = true;
    points(2).name  = 'Upper Rear Chassis';     points(2).pos = [-3021.190,  79.993, 502.424];  points(2).fixed = true;
    points(3).name  = 'Lower Front Chassis';    points(3).pos = [-2606.680, 153.689, 371.311];  points(3).fixed = true;
    points(4).name  = 'Lower Rear Chassis';     points(4).pos = [-2987.790,  77.777, 372.804];  points(4).fixed = true;
    points(5).name  = 'Toe Link Chassis';       points(5).pos = [-2480.310, 133.848, 419.589];  points(5).fixed = true;

    % Kezdeti becslés az Upright pontokra
    upright_guess = [
        -2916.942, 734.117, 500.646; % Upper Front Upright
        -3030.467, 707.836, 498.340; % Upper Rear Upright
        -2967.954, 733.688, 357.922; % Lower Front Upright
        -3100.502, 733.665, 347.614; % Lower Rear Upright
        -2838.341, 687.484, 428.422  % Toe Link Upright
    ];
    x_initial = reshape(upright_guess', [], 1); % 15x1 vektor
    
    chassis_pts = reshape([points(1:5).pos], 3, 5)';

    % --- Felső és alsó határok (Y-sík betartása) ---
    lb = -inf(15, 1); 
    ub = inf(15, 1);  
    for i = 1:5
        ub((i-1)*3 + 2) = rim_inner_Y_plane; 
    end

    % =========================================================================
    % 4. OPTIMALIZÁLÓ FUTTATÁSA (VSA KINEMATIKA + PACKAGING)
    % =========================================================================
    fprintf('Célparaméterek optimalizálása folyamatban (VSA + Felni kényszerek)...\n');
    
    opt_options = optimoptions('lsqnonlin', 'Display', 'iter', ...
                               'MaxFunctionEvaluations', 5000, ...
                               'FunctionTolerance', 1e-8);
    
    x_optimized = lsqnonlin(@(x) vsa_objective_function(x, chassis_pts, WC_pos, ...
                  Z_ground_static, target, x_initial, rim_inner_radius), ...
                  x_initial, lb, ub, opt_options);

    % Optimalizált pontok visszamásolása a struktúrába
    opt_upright = reshape(x_optimized, 3, 5)';

    points(6).name  = 'Upper Front Upright';    points(6).pos = opt_upright(1, :); points(6).fixed = false;
    points(7).name  = 'Upper Rear Upright';     points(7).pos = opt_upright(2, :); points(7).fixed = false;
    points(8).name  = 'Lower Front Upright';    points(8).pos = opt_upright(3, :); points(8).fixed = false;
    points(9).name  = 'Lower Rear Upright';     points(9).pos = opt_upright(4, :); points(9).fixed = false;
    points(10).name = 'Toe Link Upright';       points(10).pos = opt_upright(5, :); points(10).fixed = false;
    points(11).name = 'Wheel Center';           points(11).pos = WC_pos;            points(11).fixed = false;

    fprintf('\n--- Optimalizált Upright Pontok ---\n');
    for i = 6:10
        fprintf('%s: [%.3f, %.3f, %.3f]\n', points(i).name, points(i).pos(1), points(i).pos(2), points(i).pos(3));
    end

    % ========================
    % 5. Kényszerek definiálása (Távolságok) - OPTIMALIZÁLT PONTOK ALAPJÁN
    % ========================
    constraints = {};
    
    function constraints = add_distance(constraints, pts_array, i, j)
        len_mm = norm(pts_array(j).pos - pts_array(i).pos);
        new_constraint = @(all_points) norm(all_points(j).pos - all_points(i).pos) - len_mm;
        constraints{end+1} = new_constraint;
    end

    % A. Lengőkarok hossza
    for i = 1:5
        constraints = add_distance(constraints, points, i, i+5);
    end

    % B. Csonkállvány belső merevsége (15 belső távolság)
    upright_pts = 6:11;
    pairs = nchoosek(upright_pts, 2); 
    for k = 1:size(pairs, 1)
        constraints = add_distance(constraints, points, pairs(k,1), pairs(k,2));
    end

    free_indices = find(~[points.fixed]);
    x_initial = [];
    for i = free_indices
        x_initial = [x_initial, points(i).pos];
    end

    function residuals = compute_all_residuals(x_free, points_base, constraints, free_indices, target_z)
        pts = points_base;
        k = 1;
        for idx = free_indices
            pts(idx).pos = x_free(k : k+2);
            k = k + 3;
        end
        residuals = zeros(length(constraints) + 1, 1);
        for c = 1 : length(constraints)
            residuals(c) = constraints{c}(pts);
        end
        residuals(end) = pts(11).pos(3) - target_z; 
    end

    % === ELŐ-RELAXÁCIÓ ===
    options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 1000, 'FunctionTolerance', 1e-12);
    [x_relaxed, ~] = lsqnonlin(@(x) compute_all_residuals(x, points, constraints, free_indices, points(11).pos(3)), x_initial, [], [], options);
    
    k = 1;
    for i = free_indices
        points(i).pos = x_relaxed(k : k+2);
        k = k + 3;
    end
    original_points = points;

    % ========================================================================================================
    % 6. Szimulációs Ciklus (-30mm-től +30mm berugózásig)
    % ========================================================================================================
    wheel_travel_range = -30:1:30;
    N = length(wheel_travel_range);
    zero_step = find(wheel_travel_range == 0, 1);
    
    positions_history = zeros(length(points), 3, N);
    positions_history(:, :, zero_step) = reshape([points.pos], 3, [])';

    % Jounce (Felfelé)
    current_x = x_relaxed;
    for step = zero_step+1 : N
        dz = wheel_travel_range(step);
        target_z = original_points(11).pos(3) + dz;
        guess_x = current_x;
        guess_x(3:3:end) = guess_x(3:3:end) + (dz - wheel_travel_range(step-1)); 
        [current_x, ~] = lsqnonlin(@(x) compute_all_residuals(x, original_points, constraints, free_indices, target_z), guess_x, [], [], options);
        idx = 1;
        for i = free_indices
            positions_history(i, :, step) = current_x(idx:idx+2);
            idx = idx + 3;
        end
        positions_history(1:5, :, step) = positions_history(1:5, :, zero_step);
    end

    % Rebound (Lefelé)
    current_x = x_relaxed;
    for step = zero_step-1 : -1 : 1
        dz = wheel_travel_range(step);
        target_z = original_points(11).pos(3) + dz;
        guess_x = current_x;
        guess_x(3:3:end) = guess_x(3:3:end) + (dz - wheel_travel_range(step+1)); 
        [current_x, ~] = lsqnonlin(@(x) compute_all_residuals(x, original_points, constraints, free_indices, target_z), guess_x, [], [], options);
        idx = 1;
        for i = free_indices
            positions_history(i, :, step) = current_x(idx:idx+2);
            idx = idx + 3;
        end
        positions_history(1:5, :, step) = positions_history(1:5, :, zero_step);
    end

    % ======================================
    % 7. OptimumKinematics Metrikák Számítása
    % ======================================
    Results = struct('Camber', zeros(N,1), 'Toe', zeros(N,1), 'RC_Z', zeros(N,1), ...
                     'Caster', zeros(N,1), 'KPI', zeros(N,1), 'Scrub', zeros(N,1), 'Trail', zeros(N,1), 'HalfTrack', zeros(N,1), 'AntiSquat', zeros(N,1));

    A_static = [squeeze(positions_history(6,:,zero_step)); squeeze(positions_history(8,:,zero_step)); squeeze(positions_history(10,:,zero_step))];
    muA = mean(A_static);
    initial_normal = [0; 1; 0]; 
    last_w_steer = [0; 0; 1];
    
    VSA_static_point = [0,0,0];
    VSA_static_dir = [0,0,0];

    for step = 1:N
        B_curr = [squeeze(positions_history(6,:,step)); squeeze(positions_history(8,:,step)); squeeze(positions_history(10,:,step))];
        muB = mean(B_curr);
        H = (A_static - muA)' * (B_curr - muB);
        [U, ~, V] = svd(H);
        R = V * U';
        if det(R) < 0
            R = V * diag([1, 1, -1]) * U';
        end
        unit_normal = R * initial_normal;
        
        Results.Camber(step) = -rad2deg(atan2(unit_normal(3), unit_normal(2)));
        Results.Toe(step)    = -rad2deg(atan2(unit_normal(1), unit_normal(2)));
        
        WC_curr = squeeze(positions_history(11,:,step));
        Results.HalfTrack(step) = WC_curr(2) - original_points(11).pos(2);

        J = zeros(5, 6);
        for i = 1:5
            B_pt = squeeze(positions_history(i+5,:,step));
            A_pt = squeeze(positions_history(i,:,step));
            n_vec = (B_pt - A_pt); n_vec = n_vec / norm(n_vec);
            r_vec = B_pt - WC_curr; 
            J(i, 1:3) = n_vec;
            J(i, 4:6) = cross(r_vec, n_vec);
        end

        [~, ~, V_t] = svd(J);
        twist_t = V_t(:, end); 
        v_travel = twist_t(1:3); w_travel = twist_t(4:6);
        
        if abs(w_travel(1)) > 1e-6
            Y_ic = WC_curr(2) - (v_travel(3) / w_travel(1));
            Z_ic = WC_curr(3) + (v_travel(2) / w_travel(1));
            Results.RC_Z(step) = Z_ground_static - WC_curr(2) * ((Z_ic - Z_ground_static) / (Y_ic - WC_curr(2)));
        end

        if abs(w_travel(2)) > 1e-6
            % SVSA Instant Center X és Z koordinátái
            X_ic_side = WC_curr(1) + (v_travel(3) / w_travel(2));
            Z_ic_side = WC_curr(3) - (v_travel(1) / w_travel(2));

            % A kerék tapadási pontjától az IC-be mutató egyenes meredeksége (tangense)
            tan_svsa = (Z_ic_side - Z_ground_static) / (X_ic_side - WC_curr(1));

            % Százalékos Anti-Squat (CG és tengelytáv figyelembevételével)
            Results.AntiSquat(step) = tan_svsa * (Wheelbase / CG_height) * 100;
        else
            Results.AntiSquat(step) = 0;
        end

        J_steer = J(1:4, :); 
        J_steer(5, :) = [0, 0, 1, 0, 0, 0]; 
        [~, ~, V_s] = svd(J_steer);
        twist_s = V_s(:, end);
        v_steer = twist_s(1:3); w_steer = twist_s(4:6);

        if dot(w_steer, last_w_steer) < 0
            w_steer = -w_steer; v_steer = -v_steer;
        end
        last_w_steer = w_steer;

        if norm(w_steer) > 1e-5
            w_dir = w_steer / norm(w_steer);
            Results.Caster(step) = rad2deg(atan2(-w_dir(1), w_dir(3)));
            Results.KPI(step)    = rad2deg(atan2(-w_dir(2), w_dir(3)));  % Bal oldalra: befelé dőlés
            
            r_kp = cross(w_steer, v_steer) / (norm(w_steer)^2) + WC_curr';
            t_g = (Z_ground_static - r_kp(3)) / w_dir(3);
            P_ground = r_kp + t_g * w_dir;
            
            Results.Scrub(step) = WC_curr(2) - P_ground(2);
            Results.Trail(step) = P_ground(1) - WC_curr(1);
            
            if step == zero_step
                VSA_static_point = r_kp';
                VSA_static_dir = w_dir';
            end
        end
    end

    % =================================
    % 8. 3D Vizualizáció (Statikus állapot)
    % =================================
    fig_viz = figure('Name', 'Multilink Felfüggesztés 3D Nézet', 'Position', [100, 100, 900, 700], 'WindowState','maximized');
    hold on; grid on; axis equal; view(135, 20);
    xlabel('X [mm] (Előre)'); ylabel('Y [mm] (Jobbra)'); zlabel('Z [mm] (Felfelé)');
    title('Multilink Geometria és Virtuális Kormánytengely (VSA)');

    [Xg, Yg] = meshgrid(linspace(-3500, -2000, 2), linspace(0, 1000, 2));
    Zg = Z_ground_static * ones(size(Xg));
    surf(Xg, Yg, Zg, 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

    for i = 1:5
        pA = squeeze(positions_history(i, :, zero_step));
        pB = squeeze(positions_history(i+5, :, zero_step));
        plot3(pA(1), pA(2), pA(3), 'ks', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
        plot3(pB(1), pB(2), pB(3), 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        plot3([pA(1), pB(1)], [pA(2), pB(2)], [pA(3), pB(3)], 'k-', 'LineWidth', 2);
    end

    WC_stat = squeeze(positions_history(11, :, zero_step));
    plot3(WC_stat(1), WC_stat(2), WC_stat(3), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    for i = 6:10
        pB = squeeze(positions_history(i, :, zero_step));
        plot3([WC_stat(1), pB(1)], [WC_stat(2), pB(2)], [WC_stat(3), pB(3)], 'Color', [0.5 0.5 0.5], 'LineWidth', 3);
    end

    t_top = 200 / VSA_static_dir(3);
    t_bot = (Z_ground_static - VSA_static_point(3)) / VSA_static_dir(3);
    VSA_top = VSA_static_point + t_top * VSA_static_dir;
    VSA_bot = VSA_static_point + t_bot * VSA_static_dir;
    
    plot3([VSA_top(1), VSA_bot(1)], [VSA_top(2), VSA_bot(2)], [VSA_top(3), VSA_bot(3)], '--m', 'LineWidth', 3);
    
    CP = [WC_stat(1), WC_stat(2), Z_ground_static];
    plot3(CP(1), CP(2), CP(3), 'b*', 'MarkerSize', 10);
    plot3(VSA_bot(1), VSA_bot(2), VSA_bot(3), 'm*', 'MarkerSize', 10);
    plot3([CP(1), VSA_bot(1)], [CP(2), VSA_bot(2)], [Z_ground_static, Z_ground_static], 'c-', 'LineWidth', 3);

    legend('Talaj', 'Vázpontok', 'Upright Pontok', 'Lengőkarok', 'Kerékközép', 'Csonkállvány test', 'Virtuális Kormánytengely (VSA)', 'Contact Patch', 'VSA Döféspont', 'Scrub/Trail Eltérés');

    % =================================
    % 9. Eredmények Plotolása
    % =================================
    fig_kin = figure('Name', 'Multilink - Alap Kinematika', 'Position', [150, 150, 1000, 800], 'WindowState','maximized');

    subplot(2,3,1); plot(wheel_travel_range, Results.Camber, 'b', 'LineWidth', 2); grid on; title('Camber Angle'); xlabel('Travel (mm)'); ylabel('Camber (deg)');
    subplot(2,3,2); plot(wheel_travel_range, Results.Toe, 'r', 'LineWidth', 2); grid on; title('Toe Angle'); xlabel('Travel (mm)'); ylabel('Toe (deg)');
    subplot(2,3,3); plot(wheel_travel_range, Results.RC_Z, 'k', 'LineWidth', 2); grid on; title('Roll Center Z'); xlabel('Travel (mm)'); ylabel('Height (mm)');
    subplot(2,3,4); plot(wheel_travel_range, Results.HalfTrack, 'm', 'LineWidth', 2); grid on; title('Half-Track Change'); xlabel('Travel (mm)'); ylabel('\Delta Y (mm)');
    subplot(2,3,5); plot(wheel_travel_range, Results.AntiSquat*Drive_perc, 'Color', [0.85 0.32 0.09], 'LineWidth', 2); grid on; title('Anti-Squat (%)'); xlabel('Travel (mm)'); ylabel('Anti-Squat (%)');
    
    fig_steer = figure('Name', 'Multilink - Kormányzási Geometria', 'Position', [200, 200, 1000, 800], 'WindowState','maximized');
    subplot(2,2,1); plot(wheel_travel_range, Results.Caster, 'g', 'LineWidth', 2); grid on; title('Virtual Caster Angle'); xlabel('Wheel Travel (mm)'); ylabel('Caster (deg)');
    subplot(2,2,2); plot(wheel_travel_range, Results.KPI, 'c', 'LineWidth', 2); grid on; title('Virtual KPI'); xlabel('Wheel Travel (mm)'); ylabel('KPI (deg)');
    subplot(2,2,3); plot(wheel_travel_range, Results.Scrub, 'LineWidth', 2); grid on; title('Scrub Radius'); xlabel('Wheel Travel (mm)'); ylabel('Scrub (mm)');
    subplot(2,2,4); plot(wheel_travel_range, Results.Trail, 'Color', [0.8 0.4 0], 'LineWidth', 2); grid on; title('Mechanical Trail'); xlabel('Wheel Travel (mm)'); ylabel('Trail (mm)');
    
    disp('Kész! A 3D vizualizáció és a grafikonok legenerálva.');
end

% =========================================================================
% SEGÉDFÜGGVÉNY: VSA és Felni Csomagolás Célfüggvény
% =========================================================================
function residuals = vsa_objective_function(x_upright, chassis_pts, WC, Z_ground, targets, x_initial, rim_radius)
    J = zeros(5, 6);
    WC_col = WC'; 
    err_packaging = zeros(5, 1);
    W_pack = 50.0;

    for i = 1:5
        idx = (i-1)*3 + 1;
        p_U = x_upright(idx : idx+2); 
        p_C = chassis_pts(i, :)'; 

        r_dist = sqrt((p_U(1) - WC(1))^2 + (p_U(3) - WC(3))^2);
        if r_dist > rim_radius
            err_packaging(i) = (r_dist - rim_radius) * W_pack;
        end

        n_vec = (p_U - p_C); 
        n_vec = n_vec / norm(n_vec);
        r_vec = p_U - WC_col; 

        J(i, 1:3) = n_vec';
        J(i, 4:6) = cross(r_vec, n_vec)';
    end

    [~, ~, V_t] = svd(J);
    twist_t = V_t(:, end); 
    v_travel = twist_t(1:3); w_travel = twist_t(4:6);

    if abs(w_travel(1)) > 1e-6
        Y_ic = WC_col(2) - (v_travel(3) / w_travel(1));
        Z_ic = WC_col(3) + (v_travel(2) / w_travel(1));
        calc_RC_Z = Z_ground - WC_col(2) * ((Z_ic - Z_ground) / (Y_ic - WC_col(2)));

        % Toe Link vonalának és az IC irányának szögeltérése (Y-Z síkban)
        C5 = chassis_pts(5, :)';    % Toe Link Chassis
        U5 = x_upright(13:15);      % Toe Link Upright

        v_tie = [C5(2) - U5(2); C5(3) - U5(3)];
        v_tie = v_tie / (norm(v_tie) + 1e-6); % Normalizálás

        v_ic = [Y_ic - U5(2); Z_ic - U5(3)];
        v_ic = v_ic / (norm(v_ic) + 1e-6);    % Normalizálás

        % A két 2D vektor keresztszorzata (sin(theta)). Ha a Tie Rod az IC-be mutat, ez 0.
        calc_Tierod_Align = abs(v_tie(1)*v_ic(2) - v_tie(2)*v_ic(1)); 
    else
        calc_RC_Z = 0;
        calc_Tierod_Align = 1.0; % Maximális büntetés, ha nincs normális IC
    end

    J_steer = J(1:4, :); 
    J_steer(5, :) = [0, 0, 1, 0, 0, 0]; 
    [~, ~, V_s] = svd(J_steer);
    twist_s = V_s(:, end);
    v_steer = twist_s(1:3); 
    w_steer = twist_s(4:6);

    if w_steer(3) < 0
        w_steer = -w_steer; 
        v_steer = -v_steer;
    end

    if norm(w_steer) > 1e-5
        w_dir = w_steer / norm(w_steer);
        calc_Caster = rad2deg(atan2(-w_dir(1), w_dir(3)));
        calc_KPI    = rad2deg(atan2(-w_dir(2), w_dir(3)));   % Bal oldal - befelé dőlés
        
        r_kp = cross(w_steer, v_steer) / (norm(w_steer)^2) + WC_col;
        t_g = (Z_ground - r_kp(3)) / w_dir(3);
        P_ground = r_kp + t_g * w_dir;

        calc_Scrub = WC(2) - P_ground(2);
        calc_Trail = P_ground(1) - WC(1);
    else
        calc_Caster = 0; calc_KPI = 0; calc_Scrub = 0; calc_Trail = 0;
    end

    W_ang  = 30.0; 
    W_dist = 60.0;  
    W_tie  = 60.0;
    err_caster = (calc_Caster - targets.Caster) * W_ang;
    err_kpi    = (calc_KPI - targets.KPI) * W_ang;
    err_scrub  = (calc_Scrub - targets.Scrub) * W_dist;
    err_trail  = (calc_Trail - targets.Trail) * W_dist;
    err_rc     = (calc_RC_Z - targets.RC_Z) * W_dist;
    err_tierod = calc_Tierod_Align * W_tie;         

    W_reg =10; 
    err_reg = (x_upright - x_initial) * W_reg;

    residuals = [err_caster; err_kpi; err_scrub; err_trail; err_rc; err_tierod; err_reg; err_packaging];
end