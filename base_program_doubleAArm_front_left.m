function base_program_doubleAArm_front_left()
    clc; clear; close all;

    % =========================================================================
    % 1. PONTOK DEFINIÁLÁSA (Az eredeti base_program_front_left.m indexelése)
    % =========================================================================
    wheel_radius = 360; % Első kerék sugár (mm)
    
    points = struct('name', {}, 'pos', {}, 'fixed', {});

    % Fix vázoldali pontok (Chassis)
    points(1).name  = 'Front left upper arm fore';    points(1).pos = [142.910, 130.958, 588.738];  points(1).fixed = true;
    points(2).name  = 'Front left upper arm aft';     points(2).pos = [-423.620, 168.674, 470.738];  points(2).fixed = true;
    
    % Mozgó csonkállvány oldali pontok (Upright) - Felső Gömbfej
    points(3).name  = 'Front left upper arm upright'; points(3).pos = [-51.340, 691.900, 521.820];  points(3).fixed = false;
    
    % Fix vázoldali pontok (Chassis)
    points(4).name  = 'Front left lower arm fore';    points(4).pos = [205.470, 126.962, 394.866];  points(4).fixed = true;
    points(5).name  = 'Front left lower arm aft';     points(5).pos = [-407.280, 161.941, 344.481];  points(5).fixed = true;
    
    % Mozgó csonkállvány oldali pontok (Upright) - Alsó Gömbfej
    points(6).name  = 'Front left lower arm upright'; points(6).pos = [-20.720, 746.210, 303.980];  points(6).fixed = false;
    
    % Kormányösszekötő pontok (Tie rod)
    points(7).name  = 'Front left tie rod chassis';   points(7).pos = [170.140, 130.958, 540.912];  points(7).fixed = true;
    points(8).name  = 'Front left tie rod upright';   points(8).pos = [25.017, 696.430, 481.810];  points(8).fixed = false;
    
    % Kerékközép (Wheel Center)
    points(9).name  = 'Front left wheel center';      points(9).pos = [0.000,    1660/2, 360.000];  points(9).fixed = false;

    points_orig = points;
    free_indices = [3, 6, 8, 9]; % Csak a csonkállvány és a kerékközép pontjai mozognak
    Z_ground_static = points_orig(9).pos(3) - wheel_radius; % Statikus talajmagasság

    % =========================================================================
    % 2. KÉNYSZEREK DEFINIÁLÁSA (Távolságtartások)
    % =========================================================================
    constraints = {};
    
    % Lengőkarok fizikai hossza (Chassis -> Upright)
    constraints{end+1} = @(p) norm(p(3).pos - p(1).pos) - norm(points_orig(3).pos - points_orig(1).pos); % Felső első szár
    constraints{end+1} = @(p) norm(p(3).pos - p(2).pos) - norm(points_orig(3).pos - points_orig(2).pos); % Felső hátsó szár
    constraints{end+1} = @(p) norm(p(6).pos - p(4).pos) - norm(points_orig(6).pos - points_orig(4).pos); % Alsó első szár
    constraints{end+1} = @(p) norm(p(6).pos - p(5).pos) - norm(points_orig(6).pos - points_orig(5).pos); % Alsó hátsó szár
    constraints{end+1} = @(p) norm(p(8).pos - p(7).pos) - norm(points_orig(8).pos - points_orig(7).pos); % Kormányösszekötő

    % Csonkállvány merev test belső kényszerei (3, 6, 8, 9 pontok egymáshoz képest fix távolságúak)
    upright_pts = [3, 6, 8, 9];
    pairs = nchoosek(upright_pts, 2);
    for k = 1:size(pairs, 1)
        idx1 = pairs(k,1); idx2 = pairs(k,2);
        constraints{end+1} = @(p) norm(p(idx2).pos - p(idx1).pos) - norm(points_orig(idx2).pos - points_orig(idx1).pos);
    end

    % =========================================================================
    % 3. ANIMÁCIÓS ÉS DIAGRAM ABLAKOK ELŐKÉSZÍTÉSE
    % =========================================================================
    % FIGURE 1: 3D Geometriai vizualizáció és animáció
    fig3d = figure('Name', 'Double Wishbone - 3D Futómű Animáció', 'WindowState', 'maximized');
    ax3d = axes('Parent', fig3d); hold(ax3d, 'on'); grid(ax3d, 'on'); view(ax3d, 3); axis(ax3d, 'equal');
    xlabel(ax3d, 'X (Hosszirány) [mm]'); ylabel(ax3d, 'Y (Keresztirány) [mm]'); zlabel(ax3d, 'Z (Magasság) [mm]');
    title(ax3d, 'Első bal oldali kettős keresztlengőkaros futómű mozgása');

    % Fix vázpontok kirajzolása
    chassis_idx = [1, 2, 4, 5, 7];
    for cp = chassis_idx
        plot3(ax3d, points_orig(cp).pos(1), points_orig(cp).pos(2), points_orig(cp).pos(3), 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
    end

    % Animációs grafikus handle-ök inicializálása
    h_upper   = plot3(ax3d, [0 0 0 0], [0 0 0 0], [0 0 0 0], 'b-', 'LineWidth', 2.5);
    h_lower   = plot3(ax3d, [0 0 0 0], [0 0 0 0], [0 0 0 0], 'r-', 'LineWidth', 2.5);
    h_tierod  = plot3(ax3d, [0 0], [0 0], [0 0], 'm-', 'LineWidth', 2);
    h_upright = plot3(ax3d, [0 0 0 0 0], [0 0 0 0 0], [0 0 0 0 0], 'k-', 'LineWidth', 3);
    h_kp_line = plot3(ax3d, [0 0], [0 0], [0 0], 'c--', 'LineWidth', 1.5);
    h_wheel   = plot3(ax3d, zeros(1,21), zeros(1,21), zeros(1,21), 'g-', 'LineWidth', 3);

    % =========================================================================
    % 4. SZIMULÁCIÓS CIKLUS (Wheel Travel Sweep)
    % =========================================================================
    wheel_travel_range = -30 : 2 : 30;
    num_steps = length(wheel_travel_range);

    Results.Camber    = zeros(num_steps, 1);
    Results.Toe       = zeros(num_steps, 1);
    Results.RC_Z      = zeros(num_steps, 1);
    Results.HalfTrack = zeros(num_steps, 1);
    Results.Caster    = zeros(num_steps, 1);
    Results.KPI       = zeros(num_steps, 1);
    Results.Scrub     = zeros(num_steps, 1);
    Results.Trail     = zeros(num_steps, 1);

    computed_positions = cell(num_steps, 1);
    zero_step = find(wheel_travel_range == 0, 1);
    options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 1000, 'FunctionTolerance', 1e-12);

    % Kezdő tipp feltöltése (szabad koordináták)
    current_x = [];
    for i = free_indices
        current_x = [current_x, points(i).pos];
    end

    % Jounce (Berugózás felfelé)
    for step = zero_step : num_steps
        target_z = points_orig(9).pos(3) + wheel_travel_range(step);
        [current_x, ~] = lsqnonlin(@(x) compute_residuals(x, points_orig, constraints, free_indices, target_z), current_x, [], [], options);
        pts_step = points_orig; idx = 1;
        for i = free_indices
            pts_step(i).pos = current_x(idx:idx+2); idx = idx + 3;
        end
        computed_positions{step} = pts_step;
    end

    % Visszaállás statikusba a Rebound-hoz
    current_x = [];
    for i = free_indices
        current_x = [current_x, points_orig(i).pos];
    end

    % Rebound (Kirugózás lefelé)
    for step = zero_step-1 : -1 : 1
        target_z = points_orig(9).pos(3) + wheel_travel_range(step);
        [current_x, ~] = lsqnonlin(@(x) compute_residuals(x, points_orig, constraints, free_indices, target_z), current_x, [], [], options);
        pts_step = points_orig; idx = 1;
        for i = free_indices
            pts_step(i).pos = current_x(idx:idx+2); idx = idx + 3;
        end
        computed_positions{step} = pts_step;
    end

    % =========================================================================
    % 5. FUTÓMŰ PARAMÉTEREK KISZÁMÍTÁSA ÉS ANIMÁLÁSA
    % =========================================================================
    A_static = zeros(3, 4);
    for ii = 1:4
        A_static(:, ii) = points_orig(upright_pts(ii)).pos';
    end
    muA = mean(A_static, 2);
    initial_normal = [0; 1; 0]; % Statikus bal oldali keréknormális

    for step = 1:num_steps
        pts_curr = computed_positions{step};
        WC = pts_curr(9).pos';
        
        % A) Camber és Toe számítás SVD orientáció-követéssel
        B_curr = zeros(3, 4);
        for ii = 1:4
            B_curr(:, ii) = pts_curr(upright_pts(ii)).pos';
        end
        muB = mean(B_curr, 2);
        H = (A_static - muA) * (B_curr - muB)';
        [U, ~, V] = svd(H);
        R = V * U';
        if det(R) < 0, R = V * diag([1, 1, -1]) * U'; end
        unit_normal = R * initial_normal;
        
        Results.Camber(step) = -rad2deg(atan2(unit_normal(3), unit_normal(2)));
        Results.Toe(step)    = -rad2deg(atan2(unit_normal(1), unit_normal(2)));
        Results.HalfTrack(step) = WC(2) - points_orig(9).pos(2);
        
        % B) IGAZI KORMÁNYTENGELY (Kingpin geometriai számítás a 3 és 6 pontokból)
        u_kp = (pts_curr(3).pos - pts_curr(6).pos)'; % Alsó gömbfejtől a felsőig mutató vektor
        u_kp = u_kp / norm(u_kp);
        if u_kp(3) < 0, u_kp = -u_kp; end % Mindig felfelé mutasson
        
        Results.Caster(step) = rad2deg(atan2(-u_kp(1), u_kp(3)));
        Results.KPI(step)    = rad2deg(atan2(-u_kp(2), u_kp(3)));
        
        % Kormánytengely döféspontja a talajon (Z = Z_ground_static)
        t_ground = (Z_ground_static - pts_curr(6).pos(3)) / u_kp(3);
        P_ground = pts_curr(6).pos' + t_ground * u_kp;
        
        Results.Scrub(step) = WC(2) - P_ground(2);
        Results.Trail(step) = P_ground(1) - WC(1);
        
        % C) ROLL CENTER SZÁMÍTÁS (Tiszta 2D elölnézeti vetítéssel a kettős keresztlengőkarhoz)
        % Felső lengőkar pillanatnyi elölnézeti forgáspontja (Chassis hinge 1-2)
        v_u = pts_curr(2).pos - pts_curr(1).pos;
        t_u = dot(pts_curr(3).pos - pts_curr(1).pos, v_u) / dot(v_u, v_u);
        Pivot_u = pts_curr(1).pos + t_u * v_u;
        
        % Alsó lengőkar pillanatnyi elölnézeti forgáspontja (Chassis hinge 4-5)
        v_l = pts_curr(5).pos - pts_curr(4).pos;
        t_l = dot(pts_curr(6).pos - pts_curr(4).pos, v_l) / dot(v_l, v_l);
        Pivot_l = pts_curr(4).pos + t_l * v_l;
        
        % Vetületek Y-Z síkon
        Pu1 = Pivot_u(2:3); Pu2 = pts_curr(3).pos(2:3);
        Pl1 = Pivot_l(2:3); Pl2 = pts_curr(6).pos(2:3);
        
        mu_slope = (Pu2(2) - Pu1(2)) / (Pu2(1) - Pu1(1));
        ml_slope = (Pl2(2) - Pl1(2)) / (Pl2(1) - Pl1(1));
        
        % Instant Center (IC) koordinátái
        Y_ic = (Pl1(2) - Pu1(2) + mu_slope*Pu1(1) - ml_slope*Pl1(1)) / (mu_slope - ml_slope);
        Z_ic = Pu1(2) + mu_slope * (Y_ic - Pu1(1));
        
        % Roll Center magasság (gumi talajpont és IC egyenesének metszete az autó szimmetriatengelyével Y=0)
        m_rc = (Z_ic - Z_ground_static) / (Y_ic - WC(2));
        Results.RC_Z(step) = Z_ground_static - m_rc * WC(2);

        % D) ANIMÁCIÓ FRISSÍTÉSE (Élő kirajzolás)
        set(h_upper, 'XData', [pts_curr(1).pos(1), pts_curr(3).pos(1), pts_curr(2).pos(1)], ...
                     'YData', [pts_curr(1).pos(2), pts_curr(3).pos(2), pts_curr(2).pos(2)], ...
                     'ZData', [pts_curr(1).pos(3), pts_curr(3).pos(3), pts_curr(2).pos(3)]);
                 
        set(h_lower, 'XData', [pts_curr(4).pos(1), pts_curr(6).pos(1), pts_curr(5).pos(1)], ...
                     'YData', [pts_curr(4).pos(2), pts_curr(6).pos(2), pts_curr(5).pos(2)], ...
                     'ZData', [pts_curr(4).pos(3), pts_curr(6).pos(3), pts_curr(5).pos(3)]);
                 
        set(h_tierod, 'XData', [pts_curr(7).pos(1), pts_curr(8).pos(1)], ...
                      'YData', [pts_curr(7).pos(2), pts_curr(8).pos(2)], ...
                      'ZData', [pts_curr(7).pos(3), pts_curr(8).pos(3)]);
                  
        set(h_upright, 'XData', [pts_curr(3).pos(1), pts_curr(6).pos(1), pts_curr(8).pos(1), pts_curr(9).pos(1), pts_curr(3).pos(1)], ...
                       'YData', [pts_curr(3).pos(2), pts_curr(6).pos(2), pts_curr(8).pos(2), pts_curr(9).pos(2), pts_curr(3).pos(2)], ...
                       'ZData', [pts_curr(3).pos(3), pts_curr(6).pos(3), pts_curr(8).pos(3), pts_curr(9).pos(3), pts_curr(3).pos(3)]);
                   
        set(h_kp_line, 'XData', [pts_curr(3).pos(1), P_ground(1)], ...
                       'YData', [pts_curr(3).pos(2), P_ground(2)], ...
                       'ZData', [pts_curr(3).pos(3), P_ground(3)]);
                   
        % Kerék körív kirajzolása
        ang = linspace(0, 2*pi, 21);
        wheel_circ = zeros(3, 21);
        for a = 1:21
            wheel_circ(:, a) = WC + R * [cos(ang(a))*wheel_radius; 0; sin(ang(a))*wheel_radius];
        end
        set(h_wheel, 'XData', wheel_circ(1,:), 'YData', wheel_circ(2,:), 'ZData', wheel_circ(3,:));
        
        drawnow; pause(0.01);
    end

    % =========================================================================
    % 6. DIAGRAMOK PLOTOLÁSA (Maximalizált ablakméretekkel)
    % =========================================================================
    % --- FIGURE 2: Alap Kinematika ---
    figure('Name', 'Double Wishbone - Alap Kinematika', 'WindowState', 'maximized');
    
    subplot(2,2,1); plot(wheel_travel_range, Results.Camber, 'b', 'LineWidth', 2); grid on; 
    title('Camber Angle'); xlabel('Wheel Travel (mm)'); ylabel('Camber (deg)');
    
    subplot(2,2,2); plot(wheel_travel_range, Results.Toe, 'r', 'LineWidth', 2); grid on; 
    title('Toe Angle'); xlabel('Wheel Travel (mm)'); ylabel('Toe (deg)');
    
    subplot(2,2,3); plot(wheel_travel_range, Results.RC_Z, 'k', 'LineWidth', 2); grid on; 
    title('Kinematic Roll Center Z'); xlabel('Wheel Travel (mm)'); ylabel('Height (mm)');
    
    subplot(2,2,4); plot(wheel_travel_range, Results.HalfTrack, 'm', 'LineWidth', 2); grid on; 
    title('Half-Track Change'); xlabel('Wheel Travel (mm)'); ylabel('\Delta Y (mm)');
    
    % --- FIGURE 3: Kormányzási Geometria ---
    figure('Name', 'Double Wishbone - Kormányzási Geometria', 'WindowState', 'maximized');
    
    subplot(2,2,1); plot(wheel_travel_range, Results.Caster, 'g', 'LineWidth', 2); grid on; 
    title('Physical Caster Angle'); xlabel('Wheel Travel (mm)'); ylabel('Caster (deg)');
    
    subplot(2,2,2); plot(wheel_travel_range, Results.KPI, 'c', 'LineWidth', 2); grid on; 
    title('Physical KPI'); xlabel('Wheel Travel (mm)'); ylabel('KPI (deg)');
    
    subplot(2,2,3); plot(wheel_travel_range, Results.Scrub, 'b', 'LineWidth', 2); grid on; 
    title('Scrub Radius'); xlabel('Wheel Travel (mm)'); ylabel('Scrub (mm)');
    
    subplot(2,2,4); plot(wheel_travel_range, Results.Trail, 'r', 'LineWidth', 2); grid on; 
    title('Mechanical Trail'); xlabel('Wheel Travel (mm)'); ylabel('Trail (mm)');
end

% =========================================================================
% SEGÉDFÜGGVÉNY: Kényszeregyenletek hibafüggvénye (Residuals)
% =========================================================================
function residuals = compute_residuals(x_free, points_base, constraints, free_indices, target_z9)
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
    
    % Kerékközép (9-es pont) Z magasságának kényszerítése az aktuális rugóútra
    residuals(end) = pts(9).pos(3) - target_z9;
end