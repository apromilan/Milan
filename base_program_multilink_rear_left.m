function base_program_multilink_rear_left()
    clc; clear; close all;

    % ======================================
    % 1. Pontok definiálása (struct tömb) 
    % ======================================
    points = struct('name', {}, 'pos', {}, 'fixed', {});

    % Váz oldali (Chassis) fix pontok
    points(1).name  = 'Upper Front Chassis';    points(1).pos = [-2610.180, 149.557, 471.424];  points(1).fixed = true;
    points(2).name  = 'Upper Rear Chassis';     points(2).pos = [-3021.190,  79.993, 502.424];  points(2).fixed = true;
    points(3).name  = 'Lower Front Chassis';    points(3).pos = [-2606.680, 153.689, 371.311];  points(3).fixed = true;
    points(4).name  = 'Lower Rear Chassis';     points(4).pos = [-2987.790,  77.777, 372.804];  points(4).fixed = true;
    points(5).name  = 'Toe Link Chassis';       points(5).pos = [-2480.310, 133.848, 419.589];  points(5).fixed = true;

    % Csonkállvány (Upright) mozgó pontjai (tervezési magasságban)
    points(6).name  = 'Upper Front Upright';    points(6).pos = [-2963.942, 704.412, 494.308];  points(6).fixed = false;
    points(7).name  = 'Upper Rear Upright';     points(7).pos = [-3046.858, 707.128, 505.611];  points(7).fixed = false;
    points(8).name  = 'Lower Front Upright';    points(8).pos = [-2968.608, 733.282, 358.001];  points(8).fixed = false;
    points(9).name  = 'Lower Rear Upright';     points(9).pos = [-3017.324, 737.420, 348.449];  points(9).fixed = false;
    points(10).name = 'Toe Link Upright';       points(10).pos = [-2898.351, 697.442, 430.244];  points(10).fixed = false;
    
    % Kerékközép
    points(11).name = 'Wheel Center';           points(11).pos = [-3000.000, 775.000, 360.000]; points(11).fixed = false;

    wheel_radius = 360;
    Z_ground_static = points(11).pos(3) - wheel_radius;

    % ========================
    % 2. Kényszerek definiálása (Távolságok)
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
    % 3. Szimulációs Ciklus (-30mm-től +30mm berugózásig)
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
    % 4. OptimumKinematics Metrikák Számítása
    % ======================================
    Results = struct('Camber', zeros(N,1), 'Toe', zeros(N,1), 'RC_Z', zeros(N,1), ...
                     'Caster', zeros(N,1), 'KPI', zeros(N,1), 'Scrub', zeros(N,1), 'Trail', zeros(N,1), 'HalfTrack', zeros(N,1));

    A_static = [squeeze(positions_history(6,:,zero_step)); squeeze(positions_history(8,:,zero_step)); squeeze(positions_history(10,:,zero_step))];
    muA = mean(A_static);
    initial_normal = [0; 1; 0]; 
    last_w_steer = [0; 0; 1];
    
    % VSA vonalhoz a 0 pozíció elmentése
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
            Results.KPI(step)    = rad2deg(atan2(abs(w_dir(2)), w_dir(3)));
            
            r_kp = cross(w_steer, v_steer) / (norm(w_steer)^2) + WC_curr';
            t_g = (Z_ground_static - r_kp(3)) / w_dir(3);
            P_ground = r_kp + t_g * w_dir;
            
            % Bal oldalra igazított kivonási sorrend (Hogy a Scrub ne legyen inverz)
            Results.Scrub(step) = WC_curr(2) - P_ground(2);
            Results.Trail(step) = P_ground(1) - WC_curr(1);
            
            % A statikus VSA vonal elmentése a rajzoláshoz
            if step == zero_step
                VSA_static_point = r_kp';
                VSA_static_dir = w_dir';
            end
        end
    end

    % =================================
    % 5. 3D Vizualizáció (Statikus állapot)
    % =================================
    fig_viz = figure('Name', 'Multilink Felfüggesztés 3D Nézet', 'Position', [100, 100, 900, 700]);
    hold on; grid on; axis equal; view(135, 20);
    xlabel('X [mm] (Előre)'); ylabel('Y [mm] (Jobbra)'); zlabel('Z [mm] (Felfelé)');
    title('Multilink Geometria és Virtuális Kormánytengely (VSA)');

    % Talajsík rajzolása
    [Xg, Yg] = meshgrid(linspace(-3500, -2000, 2), linspace(0, 1000, 2));
    Zg = Z_ground_static * ones(size(Xg));
    surf(Xg, Yg, Zg, 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

    % Vázpontok (fekete négyzetek) és Csonkállvány pontok (piros körök)
    for i = 1:5
        pA = squeeze(positions_history(i, :, zero_step));
        pB = squeeze(positions_history(i+5, :, zero_step));
        plot3(pA(1), pA(2), pA(3), 'ks', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
        plot3(pB(1), pB(2), pB(3), 'ro', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
        % Lengőkarok vonala
        plot3([pA(1), pB(1)], [pA(2), pB(2)], [pA(3), pB(3)], 'k-', 'LineWidth', 2);
    end

    % Csonkállvány testének "pókháló" vizualizációja (A kerékközépről kiindulva)
    WC_stat = squeeze(positions_history(11, :, zero_step));
    plot3(WC_stat(1), WC_stat(2), WC_stat(3), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    for i = 6:10
        pB = squeeze(positions_history(i, :, zero_step));
        plot3([WC_stat(1), pB(1)], [WC_stat(2), pB(2)], [WC_stat(3), pB(3)], 'Color', [0.5 0.5 0.5], 'LineWidth', 3);
    end

    % --- VIRTUAL STEERING AXIS (VSA) Vonal ---
    % Felfelé meghosszabbítjuk 200mm-t, lefelé pedig a talajig
    t_top = 200 / VSA_static_dir(3);
    t_bot = (Z_ground_static - VSA_static_point(3)) / VSA_static_dir(3);
    VSA_top = VSA_static_point + t_top * VSA_static_dir;
    VSA_bot = VSA_static_point + t_bot * VSA_static_dir;
    
    plot3([VSA_top(1), VSA_bot(1)], [VSA_top(2), VSA_bot(2)], [VSA_top(3), VSA_bot(3)], '--m', 'LineWidth', 3);
    
    % Contact Patch és döféspont (Scrub radius bemutatása a talajon)
    CP = [WC_stat(1), WC_stat(2), Z_ground_static];
    plot3(CP(1), CP(2), CP(3), 'b*', 'MarkerSize', 10); % Contact patch
    plot3(VSA_bot(1), VSA_bot(2), VSA_bot(3), 'm*', 'MarkerSize', 10); % Kingpin talajdöféspont
    plot3([CP(1), VSA_bot(1)], [CP(2), VSA_bot(2)], [Z_ground_static, Z_ground_static], 'c-', 'LineWidth', 3); % Scrub / Trail vektor
    
    %legend('Talaj', 'Vázpontok', 'Upright Pontok', 'Lengőkarok', 'Kerékközép', 'Csonkállvány test', 'Virtuális Kormánytengely (VSA)', 'Contact Patch', 'VSA Döféspont', 'Scrub/Trail Eltérés');

    % =================================
    % 6. Eredmények Plotolása (Két külön Figure)
    % =================================
    
    % --- FIGURE 2: Alap Kinematika ---
    fig_kin = figure('Name', 'Multilink - Alap Kinematika', 'Position', [150, 150, 1000, 800], 'WindowState','maximized');
    
    subplot(2,2,1); plot(wheel_travel_range, Results.Camber, 'b', 'LineWidth', 2); grid on; title('Kerékdőlési szög'); xlabel('Rugóút (mm)'); ylabel('Kerékdőlés (deg)');
    subplot(2,2,2); plot(wheel_travel_range, Results.Toe, 'r', 'LineWidth', 2); grid on; title('Kerékszög'); xlabel('Rugóút (mm)'); ylabel('Kerékszög (deg)');
    % subplot(2,2,3); plot(wheel_travel_range, Results.RC_Z, 'k', 'LineWidth', 2); grid on; title('Kinematic Roll Center Z'); xlabel('Rugóút (mm)'); ylabel('Height (mm)');
    % subplot(2,2,4); plot(wheel_travel_range, Results.HalfTrack, 'm', 'LineWidth', 2); grid on; title('Half-Track Change'); xlabel('Rugóút (mm)'); ylabel('\Delta Y (mm)');
    
    % --- FIGURE 3: Kormányzási Geometria ---
    fig_steer = figure('Name', 'Multilink - Kormányzási Geometria', 'Position', [200, 200, 1000, 800], 'WindowState','maximized');
    
    subplot(2,2,1); plot(wheel_travel_range, Results.Caster, 'g', 'LineWidth', 2); grid on; title('Virtuális Csaphátradőlés'); xlabel('Rugóút (mm)'); ylabel('Csaphátradőlés (deg)');
    subplot(2,2,2); plot(wheel_travel_range, Results.KPI, 'c', 'LineWidth', 2); grid on; title('Virtuális Csapterpesztés'); xlabel('Rugóút (mm)'); ylabel('Csapterpesztés (deg)');
    subplot(2,2,3); plot(wheel_travel_range, Results.Scrub, 'LineWidth', 2); grid on; title('Kormánylegördülési sugár'); xlabel('Rugóút (mm)'); ylabel('Kormánylegördülési sugár (mm)');
    subplot(2,2,4); plot(wheel_travel_range, Results.Trail, 'Color', [0.8 0.4 0], 'LineWidth', 2); grid on; title('Mechanikai Utánfutás'); xlabel('Rugóút (mm)'); ylabel('Mechanikai Utánfutás (mm)');
    
    disp('Kész! A 3D vizualizáció és a felbontott grafikonok legenerálva.');
end