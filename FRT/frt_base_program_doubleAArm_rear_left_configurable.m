
function base_program_doubleAArm_front_left_configurable_v3()
    clc; clear; close all;

    % =========================================================================
    % 0. SZIMULÁCIÓS MÓD KIVÁLASZTÁSA
    % =========================================================================
    % 'travel'   -> Rugóút sweep (-30mm-től +30mm-ig), kormányközép rögzítve
    % 'steering' -> Kormányzás sweep (fogasléc Y mozgás), kerékmagasság rögzítve
    % =========================================================================
    sim_mode = 'travel'; 

    % =========================================================================
    % 1. PONTOK DEFINIÁLÁSA (Eredeti koordináták)
    % =========================================================================
    wheel_radius = 193; % Első kerék sugár (mm)
    
    points = struct('name', {}, 'pos', {}, 'fixed', {});

    % Fix vázoldali pontok (Chassis)
    points(1).name  = 'Front left upper arm fore';    points(1).pos = [-1431.440, 217.517, 267.328];  points(1).fixed = true;
    points(2).name  = 'Front left upper arm aft';     points(2).pos = [-1608.900, 218.398, 295.532];  points(2).fixed = true;
    
    % Mozgó csonkállvány oldali pontok (Upright) - Felső Gömbfej
    points(3).name  = 'Front left upper arm upright'; points(3).pos = [-1537.000,505.000, 285.000];  points(3).fixed = false;
    
    % Fix vázoldali pontok (Chassis)
    points(4).name  = 'Front left lower arm fore';    points(4).pos = [-1304.330, 217.845, 179.279];  points(4).fixed = true;
    points(5).name  = 'Front left lower arm aft';     points(5).pos = [-1654.490, 217.202, 139.370];  points(5).fixed = true;
    
    % Mozgó csonkállvány oldali pontok (Upright) - Alsó Gömbfej
    points(6).name  = 'Front left lower arm upright'; points(6).pos = [-1545.000, 563.000, 105.000];  points(6).fixed = false;
    
    % Kormányösszekötő pontok (Tie rod)
    points(7).name  = 'Front left tie rod chassis';   points(7).pos = [-1448.000, 216.497, 219.682];  points(7).fixed = true;
    points(8).name  = 'Front left tie rod upright';   points(8).pos = [-1448.000, 575.000, 190.000];  points(8).fixed = false;
    
    % Kerékközép (Wheel Center)
    points(9).name  = 'Front left wheel center';      points(9).pos = [-1540.000, 1200/2, 193.000];  points(9).fixed = false;

    points_orig = points;
    free_indices = [3, 6, 8, 9]; % Szabadon mozgó pontok indexei
    Z_ground_static = points_orig(9).pos(3) - wheel_radius; 

    Wheelbase = 1540; % Tengelytáv (mm)
    CG_height = 272;  % Súlypont magasság (mm)
    Brake_perc_front = 0.36; % Első fékerő arány (pl. 64%)
    Drive_perc_front = 0.5;  % Első hajtásarány (0 ha RWD, 1 ha FWD, 0.5 ha AWD)

    % =========================================================================
    % 2. KÉNYSZEREK DEFINIÁLÁSA
    % =========================================================================
    constraints = {};
    
    % Lengőkarok fizikai hossza
    constraints{end+1} = @(p) norm(p(3).pos - p(1).pos) - norm(points_orig(3).pos - points_orig(1).pos); 
    constraints{end+1} = @(p) norm(p(3).pos - p(2).pos) - norm(points_orig(3).pos - points_orig(2).pos); 
    constraints{end+1} = @(p) norm(p(6).pos - p(4).pos) - norm(points_orig(6).pos - points_orig(4).pos); 
    constraints{end+1} = @(p) norm(p(5).pos - p(4).pos) * 0; 
    constraints{end+1} = @(p) norm(p(6).pos - p(5).pos) - norm(points_orig(6).pos - points_orig(5).pos); 
    constraints{end+1} = @(p) norm(p(8).pos - p(7).pos) - norm(points_orig(8).pos - points_orig(7).pos); 

    % Csonkállvány belső merev kényszerei
    upright_pts = [3, 6, 8, 9];
    pairs = nchoosek(upright_pts, 2);
    for k = 1:size(pairs, 1)
        idx1 = pairs(k,1); idx2 = pairs(k,2);
        constraints{end+1} = @(p) norm(p(idx2).pos - p(idx1).pos) - norm(points_orig(idx2).pos - points_orig(idx1).pos);
    end

    % =========================================================================
    % 3. ÜZEMMÓD SPECIFIKUS BEÁLLÍTÁSOK
    % =========================================================================
    if strcmp(sim_mode, 'travel')
        sweep_range = -30 : 2 : 30;
        xlbl =  'Wheel Travel [mm]';
        title_suffix = ' (Wheel Travel sweep)';
    elseif strcmp(sim_mode, 'steering')
        sweep_range = -25 : 1 : 25; 
        xlbl = 'Fogasléc elmozdulás [mm]';
        title_suffix = ' (Kormányzás sweep)';
    else
        error('Hibás sim_mode!');
    end
    
    num_steps = length(sweep_range);
    zero_step = find(sweep_range == 0, 1);

    % =========================================================================
    % 4. ANIMÁCIÓS ABLAK ELŐKÉSZÍTÉSE
    % =========================================================================
    fig3d = figure('Name', ['3D Animáció' title_suffix], 'WindowState', 'maximized');
    ax3d = axes('Parent', fig3d); hold(ax3d, 'on'); grid(ax3d, 'on'); view(ax3d, 3); axis(ax3d, 'equal');
    xlabel(ax3d, 'X (Hosszirány) [mm]'); ylabel(ax3d, 'Y (Keresztirány) [mm]'); zlabel(ax3d, 'Z (Magasság) [mm]');

    % Statikus vázpontok kirajzolása
    chassis_idx = [1, 2, 4, 5];
    for cp = chassis_idx
        plot3(ax3d, points_orig(cp).pos(1), points_orig(cp).pos(2), points_orig(cp).pos(3), 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 8);
    end

    h_upper   = plot3(ax3d, [0 0 0], [0 0 0], [0 0 0], 'b-', 'LineWidth', 2.5);
    h_lower   = plot3(ax3d, [0 0 0], [0 0 0], [0 0 0], 'r-', 'LineWidth', 2.5);
    h_tierod  = plot3(ax3d, [0 0], [0 0], [0 0], 'm-', 'LineWidth', 2);
    h_rack_pt = plot3(ax3d, 0, 0, 0, 'ms', 'MarkerFaceColor', 'm', 'MarkerSize', 7);
    h_upright = plot3(ax3d, zeros(1,5), zeros(1,5), zeros(1,5), 'k-', 'LineWidth', 3);
    h_kp_line = plot3(ax3d, [0 0], [0 0], [0 0], 'c--', 'LineWidth', 1.5);
    h_wheel   = plot3(ax3d, zeros(1,21), zeros(1,21), zeros(1,21), 'g-', 'LineWidth', 3);

    % =========================================================================
    % 5. MEGOLDÓ CIKLUSOK (LSQNONLIN)
    % =========================================================================
    Results.Camber       = zeros(num_steps, 1);
    Results.Toe          = zeros(num_steps, 1);
    Results.RC_Z         = zeros(num_steps, 1);
    Results.HalfTrack    = zeros(num_steps, 1);
    Results.Caster       = zeros(num_steps, 1);
    Results.KPI          = zeros(num_steps, 1);
    Results.Scrub        = zeros(num_steps, 1);
    Results.Trail        = zeros(num_steps, 1);
    Results.LeverArm     = zeros(num_steps, 1); 
    Results.LeverArmAngle= zeros(num_steps, 1); % ÚJ: Szögtároló vektor
    Results.AntiDive     = zeros(num_steps, 1);
    Results.AntiSquat     = zeros(num_steps, 1);

    computed_positions = cell(num_steps, 1);
    options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 1000, 'FunctionTolerance', 1e-12);

    current_x = [];
    for i = free_indices, current_x = [current_x, points_orig(i).pos]; end

    % Pozitív sweep
    for step = zero_step : num_steps
        pts_base = points_orig;
        if strcmp(sim_mode, 'travel')
            target_z = points_orig(9).pos(3) + sweep_range(step);
        else
            target_z = points_orig(9).pos(3); 
            pts_base(7).pos(2) = points_orig(7).pos(2) + sweep_range(step); 
        end
        [current_x, ~] = lsqnonlin(@(x) compute_residuals(x, pts_base, constraints, free_indices, target_z), current_x, [], [], options);
        pts_step = pts_base; idx = 1;
        for i = free_indices, pts_step(i).pos = current_x(idx:idx+2); idx = idx + 3; end
        computed_positions{step} = pts_step;
    end

    % Negatív sweep
    current_x = [];
    for i = free_indices, current_x = [current_x, points_orig(i).pos]; end
    for step = zero_step-1 : -1 : 1
        pts_base = points_orig;
        if strcmp(sim_mode, 'travel')
            target_z = points_orig(9).pos(3) + sweep_range(step);
        else
            target_z = points_orig(9).pos(3);
            pts_base(7).pos(2) = points_orig(7).pos(2) + sweep_range(step); 
        end
        [current_x, ~] = lsqnonlin(@(x) compute_residuals(x, pts_base, constraints, free_indices, target_z), current_x, [], [], options);
        pts_step = pts_base; idx = 1;
        for i = free_indices, pts_step(i).pos = current_x(idx:idx+2); idx = idx + 3; end
        computed_positions{step} = pts_step;
    end

    % =========================================================================
    % 6. POST-PROCESSING ÉS ÚJ SZÖGSZÁMÍTÁS
    % =========================================================================
    A_static = zeros(3, 4);
    for ii = 1:4, A_static(:, ii) = points_orig(upright_pts(ii)).pos'; end
    muA = mean(A_static, 2); initial_normal = [0; 1; 0]; 

    for step = 1:num_steps
        pts_curr = computed_positions{step};
        WC = pts_curr(9).pos';
        
        B_curr = zeros(3, 4);
        for ii = 1:4, B_curr(:, ii) = pts_curr(upright_pts(ii)).pos'; end
        muB = mean(B_curr, 2); H = (A_static - muA) * (B_curr - muB)';
        [U, ~, V] = svd(H); R = V * U';
        if det(R) < 0, R = V * diag([1, 1, -1]) * U'; end
        unit_normal = R * initial_normal;
        
        Results.Camber(step) = -rad2deg(atan2(unit_normal(3), unit_normal(2)));
        Results.Toe(step)    = -rad2deg(atan2(unit_normal(1), unit_normal(2)));
        Results.HalfTrack(step) = WC(2) - points_orig(9).pos(2);
        
        u_kp = (pts_curr(3).pos - pts_curr(6).pos)'; u_kp = u_kp / norm(u_kp);
        if u_kp(3) < 0, u_kp = -u_kp; end 
        Results.Caster(step) = rad2deg(atan2(-u_kp(1), u_kp(3)));
        Results.KPI(step)    = rad2deg(atan2(-u_kp(2), u_kp(3)));
        
        t_ground = (Z_ground_static - pts_curr(6).pos(3)) / u_kp(3);
        P_ground = pts_curr(6).pos' + t_ground * u_kp;
        Results.Scrub(step) = WC(2) - P_ground(2);
        Results.Trail(step) = P_ground(1) - WC(1);
        
        % -----------------------------------------------------------------
        %  ÚJ GEOMETRIAI SZÁMÍTÁSOK: LEVER ARM VEKTOR ÉS JÁRMŰ SÍKJA
        % -----------------------------------------------------------------
        A_kp = pts_curr(6).pos; % Alsó KPI gömbfej
        B_kp = pts_curr(3).pos; % Felső KPI gömbfej
        P_tr = pts_curr(8).pos; % Kormányösszekötő gömbfej a csonkállványon
        
        v_line = B_kp - A_kp;   % Kingpin egyenes irányvektora
        w_vec  = P_tr - A_kp;   % Vektor az alsó pontból a kormánykar végébe
        
        % Merőleges vetítéssel megkeressük a valódi 3D-s kormánykar vektort
        proj_vec = (dot(w_vec, v_line) / dot(v_line, v_line)) * v_line;
        lever_arm_vec = w_vec - proj_vec; 
        
        % 1. Fizikai hossz (norma)
        Results.LeverArm(step) = norm(lever_arm_vec);
        
        % 2. Bezárt szög a hosszanti síkkal (X-Z sík, aminek a normálisa az Y:[0,1,0])
        % Képlet: szög = asind( Vektor_Y / Vektor_Norma )
        Results.LeverArmAngle(step) = asind(lever_arm_vec(2) / norm(lever_arm_vec));
        % -----------------------------------------------------------------

        % Roll Center
        v_u = pts_curr(2).pos - pts_curr(1).pos; t_u = dot(pts_curr(3).pos - pts_curr(1).pos, v_u) / dot(v_u, v_u); Pivot_u = pts_curr(1).pos + t_u * v_u;
        v_l = pts_curr(5).pos - pts_curr(4).pos; t_l = dot(pts_curr(6).pos - pts_curr(4).pos, v_l) / dot(v_l, v_l); Pivot_l = pts_curr(4).pos + t_l * v_l;
        Pu1 = Pivot_u(2:3); Pu2 = pts_curr(3).pos(2:3); Pl1 = Pivot_l(2:3); Pl2 = pts_curr(6).pos(2:3);
        mu_slope = (Pu2(2) - Pu1(2)) / (Pu2(1) - Pu1(1)); ml_slope = (Pl2(2) - Pl1(2)) / (Pl2(1) - Pl1(1));
        Y_ic = (Pl1(2) - Pu1(2) + mu_slope*Pu1(1) - ml_slope*Pl1(1)) / (mu_slope - ml_slope);
        m_rc = (Pu1(2) + mu_slope * (Y_ic - Pu1(1)) - Z_ground_static) / (Y_ic - WC(2));
        Results.RC_Z(step) = Z_ground_static - m_rc * WC(2);

        % Anti dive, anti squat
        % A Double A-Arm 5 db virtuális rudas modellként írható fel:
        links_chassis = [1, 2, 4, 5, 7];
        links_upright = [3, 3, 6, 6, 8];

        J_kin = zeros(5, 6);
        for i_link = 1:5
            p_chas = pts_curr(links_chassis(i_link)).pos; % 1x3 vektor
            p_up   = pts_curr(links_upright(i_link)).pos; % 1x3 vektor

            n_vec = p_up - p_chas;
            n_vec = n_vec / norm(n_vec);
            r_vec = p_up - WC'; % WC oszlopvektor (3x1), így WC' (1x3) kell

            J_kin(i_link, 1:3) = n_vec;
            J_kin(i_link, 4:6) = cross(r_vec, n_vec);
        end

        [~, ~, V_t] = svd(J_kin);
        twist_t = V_t(:, end); 
        v_travel = twist_t(1:3); 
        w_travel = twist_t(4:6);

        if abs(w_travel(2)) > 1e-6
            % SVSA Instant Center X és Z koordinátái a hosszanti síkban
            X_ic_side = WC(1) + (v_travel(3) / w_travel(2));
            Z_ic_side = WC(3) - (v_travel(1) / w_travel(2));

            % A kerék tapadási pontjától az IC-be mutató egyenes meredeksége
            tan_svsa = (Z_ic_side - Z_ground_static) / (X_ic_side - WC(1));

            % Alap kinematikai bólintás/emelkedés mutató (még szorozni kell a terheléselosztással)
            Results.AntiDive(step) = tan_svsa * (Wheelbase / CG_height) * 100;
            Results.AntiSquat(step) = tan_svsa * (Wheelbase / CG_height) * 100;
        else
            Results.AntiDive(step) = 0;
            Results.AntiSquat(step) = 0;
        end

        % Animáció frissítése
        set(h_upper, 'XData', [pts_curr(1).pos(1), pts_curr(3).pos(1), pts_curr(2).pos(1)], 'YData', [pts_curr(1).pos(2), pts_curr(3).pos(2), pts_curr(2).pos(2)], 'ZData', [pts_curr(1).pos(3), pts_curr(3).pos(3), pts_curr(2).pos(3)]);
        set(h_lower, 'XData', [pts_curr(4).pos(1), pts_curr(6).pos(1), pts_curr(5).pos(1)], 'YData', [pts_curr(4).pos(2), pts_curr(6).pos(2), pts_curr(5).pos(2)], 'ZData', [pts_curr(4).pos(3), pts_curr(6).pos(3), pts_curr(5).pos(3)]);
        set(h_tierod, 'XData', [pts_curr(7).pos(1), pts_curr(8).pos(1)], 'YData', [pts_curr(7).pos(2), pts_curr(8).pos(2)], 'ZData', [pts_curr(7).pos(3), pts_curr(8).pos(3)]);
        set(h_rack_pt, 'XData', pts_curr(7).pos(1), 'YData', pts_curr(7).pos(2), 'ZData', pts_curr(7).pos(3));
        set(h_upright, 'XData', [pts_curr(3).pos(1), pts_curr(6).pos(1), pts_curr(8).pos(1), pts_curr(9).pos(1), pts_curr(3).pos(1)], 'YData', [pts_curr(3).pos(2), pts_curr(6).pos(2), pts_curr(8).pos(2), pts_curr(9).pos(2), pts_curr(3).pos(2)], 'ZData', [pts_curr(3).pos(3), pts_curr(6).pos(3), pts_curr(8).pos(3), pts_curr(9).pos(3), pts_curr(3).pos(3)]);
        set(h_kp_line, 'XData', [pts_curr(3).pos(1), P_ground(1)], 'YData', [pts_curr(3).pos(2), P_ground(2)], 'ZData', [pts_curr(3).pos(3), P_ground(3)]);
        ang = linspace(0, 2*pi, 21); wheel_circ = zeros(3, 21);
        for a = 1:21, wheel_circ(:, a) = WC + R * [cos(ang(a))*wheel_radius; 0; sin(ang(a))*wheel_radius]; end
        set(h_wheel, 'XData', wheel_circ(1,:), 'YData', wheel_circ(2,:), 'ZData', wheel_circ(3,:));
        drawnow; pause(0.002);
    end

    % =========================================================================
    % 7. DIAGRAMOK PLOTOLÁSA
    % =========================================================================
    figure('Name', ['Alap Kinematika' title_suffix], 'WindowState', 'maximized');
    subplot(2,3,1); plot(sweep_range, Results.Camber, 'b', 'LineWidth', 2); grid on; title('Kerékdőlés'); xlabel(xlbl); ylabel('Kerékdőlés (deg)');
    subplot(2,3,2); plot(sweep_range, Results.Toe, 'r', 'LineWidth', 2); grid on; title('Kerékszög'); xlabel(xlbl); ylabel('Kerékszög (deg)');
    subplot(2,3,3); plot(sweep_range, Results.RC_Z, 'k', 'LineWidth', 2); grid on; title('Kinematic Roll Center Z'); xlabel(xlbl); ylabel('Height (mm)');
    subplot(2,3,4); plot(sweep_range, Results.HalfTrack, 'm', 'LineWidth', 2); grid on; title('Fél-nyomtáv változás'); xlabel(xlbl); ylabel('\Delta Y (mm)');
    subplot(2,3,5); plot(sweep_range, Results.AntiDive * Brake_perc_front, 'Color', [0.85 0.32 0.09], 'LineWidth', 2); grid on; title('Anti-Dive (%)'); xlabel(xlbl); ylabel('Anti-Dive (%)');
    subplot(2,3,6); plot(sweep_range, Results.AntiSquat * Drive_perc_front, 'Color', [0.47 0.67 0.19], 'LineWidth', 2); grid on; title('Anti-Squat (%)'); xlabel(xlbl); ylabel('Anti-Squat (%)');    

    figure('Name', ['Kormány Geometria' title_suffix], 'WindowState', 'maximized');
    subplot(2,2,1); plot(sweep_range, Results.Caster, 'g', 'LineWidth', 2); grid on; title('Csaphátradőlés'); xlabel(xlbl); ylabel('Csaphátradőlés (deg)');
    subplot(2,2,2); plot(sweep_range, Results.KPI, 'c', 'LineWidth', 2); grid on; title('Csapterpesztés'); xlabel(xlbl); ylabel('Csapterpesztés (deg)');
    subplot(2,2,3); plot(sweep_range, Results.Scrub, 'b', 'LineWidth', 2); grid on; title('Kormánylegördülési sugár'); xlabel(xlbl); ylabel('Kormánylegördülési sugár (mm)');
    subplot(2,2,4); plot(sweep_range, Results.Trail, 'r', 'LineWidth', 2); grid on; title('Mechanikai Utánfutás'); xlabel(xlbl); ylabel('Mechanikai Utánfutás (mm)');

    % --- FIGURE 4: KORMÁNYKAR GEOMETRIAI ADATAI (OSZTOTT) ---
    figure('Name', ['Kormánykar Komplett Analízis' title_suffix], 'WindowState', 'maximized');
    
    % 4/1: Kar hossza
    subplot(1,2,1);
    plot(sweep_range, Results.LeverArm, 'b-', 'LineWidth', 2.5); grid on;
    title('Kormánykar térbeli fizikai hossza'); xlabel(xlbl); ylabel('Karhossz [mm]');
    mean_lever = mean(Results.LeverArm);
    if max(Results.LeverArm) - min(Results.LeverArm) < 1e-3
        ylim([mean_lever - 15, mean_lever + 15]);
    end
    text(mean(sweep_range), mean_lever + 4, sprintf('Statikus hossz: %.2f mm', mean_lever), 'FontWeight', 'bold', 'Color', 'b', 'HorizontalAlignment', 'center');

    % 4/2: Kar szöge a hosszanti síkkal
    subplot(1,2,2);
    plot(sweep_range, Results.LeverArmAngle, 'r-', 'LineWidth', 2.5); grid on;
    title('Kormánykar szöge a hosszanti (X-Z) felezősíkkal'); xlabel(xlbl); ylabel('Bezárt szög [fok]');
    mean_angle = mean(Results.LeverArmAngle);
    
    % Statikus szög kiírása
    text(mean(sweep_range), mean_angle + (max(Results.LeverArmAngle)-min(Results.LeverArmAngle)+1)*0.2, ...
         sprintf('Statikus szög: %.2f°', Results.LeverArmAngle(zero_step)), 'FontWeight', 'bold', 'Color', 'r', 'HorizontalAlignment', 'center');
end

function residuals = compute_residuals(x_free, points_base, constraints, free_indices, target_z9)
    pts = points_base; k = 1;
    for idx = free_indices, pts(idx).pos = x_free(k : k+2); k = k + 3; end
    residuals = zeros(length(constraints) + 1, 1);
    for c = 1 : length(constraints), residuals(c) = constraints{c}(pts); end
    residuals(end) = pts(9).pos(3) - target_z9;
end