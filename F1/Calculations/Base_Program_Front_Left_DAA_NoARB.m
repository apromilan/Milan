function base_program_front_left()

    % clc
    clear all
    % close all

    % Azért vannak elnevezve a fejezetek a kódban, mert így könnyebb rá hivatkozni akár egymásnak akár az AI-nak those who know

    % ======================================
    % 1. Pontok definiálása (struct tömb) 
    % ======================================

    % %% 1. Pontok definiálása – Excelből olvasás (Felfüggesztés + Rocker pontok)

    input_excel_file = 'DAA_Points_Front.xlsx';         % Felfüggesztési pontok Excelje
    rocker_excel_file = 'Optim_Rocker_DAA_Front.xlsx';  % Rocker pontok Excelje

    if exist(input_excel_file, 'file') ~= 2
        error('A fájl nem található: %s\nKérlek tedd a munkakönyvtárba az Excel-t!', input_excel_file);
    end
    if exist(rocker_excel_file, 'file') ~= 2
        error('A fájl nem található: %s\nKérlek tedd a munkakönyvtárba az Excel-t!', rocker_excel_file);
    end

    disp(['Pontok betöltése az Excel fájlokból: ', input_excel_file, ' és ', rocker_excel_file]);
    T_in = readtable(input_excel_file);
    T_rocker = readtable(rocker_excel_file);

    % Segédfüggvény a név alapú kereséshez
    function pos = get_pt(T, name)
        idx = find(strcmpi(T.Name, name), 1);
        if isempty(idx)
            error('Hiányzó pont az Excelben: %s', name);
        end
        pos = [T.X(idx), T.Y(idx), T.Z(idx)];
    end

    % === Excelből beolvasott felfüggesztési pontok ===
    upper_fore_chassis   = get_pt(T_in, 'Upper Fore Chassis');
    upper_aft_chassis    = get_pt(T_in, 'Upper Aft Chassis');
    lower_fore_chassis   = get_pt(T_in, 'Lower Fore Chassis');
    lower_aft_chassis    = get_pt(T_in, 'Lower Aft Chassis');
    tie_rod_rack         = get_pt(T_in, 'Tie Rod Rack');
    upper_upright        = get_pt(T_in, 'Upper Upright');
    lower_upright        = get_pt(T_in, 'Lower Upright');
    tie_rod_upright      = get_pt(T_in, 'Tie Rod Upright');
    wheel_center         = get_pt(T_in, 'Wheel Center');

    % === Excelből beolvasott rocker pontok (Optim_Rocker_DAA.xlsx) ===
    % Csak a kért 6 pontot húzzuk be!
    pushrod_upright      = get_pt(T_rocker, 'Pushrod Upright');
    pushrod_rocker       = get_pt(T_rocker, 'Pushrod Rocker');
    rocker_center        = get_pt(T_rocker, 'Rocker Center');
    rocker_axis          = get_pt(T_rocker, 'Rocker Axis');
    damper_rocker        = get_pt(T_rocker, 'Damper Rocker');
    damper_chassis       = get_pt(T_rocker, 'Damper Chassis');


    % === Struct tömb feltöltése ===
    points = struct('name', {}, 'pos', {}, 'fixed', {});

    % 1-8. pontok (Lengőkarok és kormányösszekötő)
    points(1).name = 'Front left upper arm fore';       points(1).pos = upper_fore_chassis;   points(1).fixed = true;
    points(2).name = 'Front left upper arm aft';        points(2).pos = upper_aft_chassis;    points(2).fixed = true;
    points(3).name = 'Front left upper arm upright';    points(3).pos = upper_upright;        points(3).fixed = false;
    points(4).name = 'Front left lower arm fore';       points(4).pos = lower_fore_chassis;   points(4).fixed = true;
    points(5).name = 'Front left lower arm aft';        points(5).pos = lower_aft_chassis;    points(5).fixed = true;
    points(6).name = 'Front left lower arm upright';    points(6).pos = lower_upright;        points(6).fixed = false;
    points(7).name = 'Front left tie rod rack';         points(7).pos = tie_rod_rack;         points(7).fixed = false;
    points(8).name = 'Front left tie rod upright';      points(8).pos = tie_rod_upright;      points(8).fixed = false;

    % 9 – Pushrod rocker oldala (Excelből)
    points(9).name  = 'Front left pushrod rocker';
    points(9).pos   = pushrod_rocker;
    points(9).fixed = false;

    % 10 – Pushrod csonkállvány oldala (Excelből)
    points(10).name = 'Front left pushrod upright';
    points(10).pos  = pushrod_upright;
    points(10).fixed = false;

    % 11 – Rocker tengely vázoldali pontja / axis (Excelből)
    points(11).name  = 'Front left rocker axis';
    points(11).pos   = rocker_axis;
    points(11).fixed = true;

    % 12 – Rocker tengely center (Excelből)
    points(12).name  = 'Front left rocker center';
    points(12).pos   = rocker_center;
    points(12).fixed = true;

    % 13 – Damper rocker oldala (Excelből)
    points(13).name = 'Front left damper rocker';
    points(13).pos  = damper_rocker;
    points(13).fixed = false;

    % 14 – Damper váz oldal (Excelből)
    points(14).name = 'Front left damper chassis';
    points(14).pos  = damper_chassis;
    points(14).fixed = true;

    % 15 – Kerék középpont (Felfüggesztés Excelből)
    points(15).name  = 'Front left wheel center';
    points(15).pos   = wheel_center;
    points(15).fixed = false;

    % % ARB pontok kikommentelve (16, 17, 18)
    % points(16).name = 'Front left ARB rocker'; ...
    % points(17).name = 'Front left ARB blade'; ...
    % points(18).name = 'Front left blade torsion bar'; ...

    %% 1a. F1 2026 SZABÁLYZAT (Section C10) – ugyanazok a beállítások, mint az optimalizálóban
    F1 = f1_rules_2026('front');       % 'front' | 'rear'  (ez az első DAA)
    F1.RefPlaneZ       = 45;           % [mm] az F1 Z=0 referenciasík magassága a talaj felett (Legality Setup)
    F1.Rim.InnerRadius = 215;          % [mm] a felni belső (hordó) sugara – CAD / RV-F-RIM-MIN
    F1.SteerCheckRack  = 30;           % [mm] C10.3.6c kormányzási tartomány (±rack)
    F1.MaxRackTravel   = Inf;          % [mm] ha véges: a +23°/-21° lockhoz szükséges rack-út korlátja
    F1.TyreWidth       = 280;          % [mm] 2026 első gumi szélessége – CSAK a rajzhoz

    % --- ÜTKÖZÉS ÉS VIZUALIZÁCIÓ PARAMÉTEREI (= optimalizáló) ---
    Collision.rod_diameter = [20, 20, 20, 20, 12, 16]; % UCA fore, UCA aft, LCA fore, LCA aft, Tie rod, Pushrod
    Collision.rod_names    = {'UCA fore', 'UCA aft', 'LCA fore', 'LCA aft', 'Tie rod', 'Pushrod'};
    Collision.skip_pairs   = [1 2; 3 4];               % A-kar szárai: szándékosan közös gömbcsukló
    Collision.rod_diameter_upper = Collision.rod_diameter(1);   
    Collision.rod_diameter_lower = Collision.rod_diameter(3);
    Collision.rod_diameter_tie   = Collision.rod_diameter(5);
    Collision.min_clearance = 5;                        % [mm]

    Collision.motor_radius = 48;             % A henger sugara
    Collision.motor_length = 160.2;          % A henger teljes hossza
    Collision.motor_y_offset = -63.4;        % Eltolás a kerékközépponttól a tengely mentén

    % Felni paraméterei (FS)
    Collision.rim_inner_radius = 119;
    Collision.rim_outer_radius = 124.5;
    Collision.rim_width        = 195;
    Collision.rim_y_offset     = 0;

    % --- F1 2026: felni a C10.7.2 szerint ---
    if F1.Enable
        Collision.use_motor        = false;
        Collision.rim_inner_radius = F1.Rim.InnerRadius;
        Collision.rim_outer_radius = F1.Rim.OuterRadius;    
        Collision.rim_width        = F1.Rim.Width;          
        Collision.rim_y_offset     = F1.Rim.CenterOffset;
        Collision.wheel_axis0      = f1_wheel_axes(F1);     
    else
        Collision.use_motor   = true;
        Collision.wheel_axis0 = [0; 1; 0];
    end

    % Gumi / felni rajz méretei
    if F1.Enable
        Tyre.R_outer  = F1.TyreRadius;       
        Tyre.R_rim    = F1.Rim.BeadRadius;   
        Tyre.width    = F1.TyreWidth;
        Tyre.rim_half = F1.Rim.Width / 2;
    else
        Tyre.R_outer  = 386 / 2;
        Tyre.R_rim    = 254 / 2;
        Tyre.width    = 191;
        Tyre.rim_half = 0.7 * 254 / 2;
    end

    % --- F1 2026 megfelelőség a beolvasott Excel geometrián ---
    f1_check_wheel_static(wheel_center, F1, F1.Axle);      
    f1_check_outboard_point(points(10).pos, wheel_center, F1, 'Pushrod upright', F1.PushrodOnMember);
    fprintf(['[Méretek] Felni: perem Ø%.1f, ülék Ø%.1f, belső r = %.1f, szélesség %.1f mm | ' ...
             'Gumi: Ø%.1f x %.1f mm | WC Y = %.1f mm (nyomtáv ~ %.1f mm)\n'], ...
        2*Collision.rim_outer_radius, 2*Tyre.R_rim, Collision.rim_inner_radius, Collision.rim_width, ...
        2*Tyre.R_outer, Tyre.width, wheel_center(2), 2*abs(wheel_center(2)));
    C_f1  = [upper_fore_chassis; upper_aft_chassis; lower_fore_chassis; lower_aft_chassis; tie_rod_rack];
    Kb_f1 = [upper_upright; lower_upright; tie_rod_upright];
    [~, ~, f1_names, f1_vals] = f1_nonlcon_DAA([C_f1(:); Kb_f1(:)], wheel_center, F1, Collision);
    f1_report(f1_names, f1_vals, ['Excel geometria (', input_excel_file, ')']);

    % Távolságok
    dist_1_3 = norm(points(1).pos - points(3).pos);
    dist_2_3 = norm(points(2).pos - points(3).pos);
    dist_4_6 = norm(points(4).pos - points(6).pos);
    dist_5_6 = norm(points(5).pos - points(6).pos);
    dist_3_6 = norm(points(3).pos - points(6).pos);
    dist_8_6 = norm(points(8).pos - points(6).pos);
    dist_8_3 = norm(points(8).pos - points(3).pos);
    dist_7_8 = norm(points(7).pos - points(8).pos);
    dist_9_10 = norm(points(9).pos - points(10).pos);
    % dist_3_10 = norm(points(3).pos - points(10).pos);
    % dist_1_10 = norm(points(1).pos - points(10).pos);
    % dist_2_10 = norm(points(2).pos - points(10).pos);
    dist_3_10 = norm(points(6).pos - points(10).pos);
    dist_1_10 = norm(points(4).pos - points(10).pos);
    dist_2_10 = norm(points(5).pos - points(10).pos);
    dist_9_11 = norm(points(9).pos - points(11).pos);
    dist_9_12 = norm(points(9).pos - points(12).pos);
    dist_3_15 = norm(points(3).pos - points(15).pos);
    dist_6_15 = norm(points(6).pos - points(15).pos);
    dist_8_15 = norm(points(8).pos - points(15).pos);
    dist_9_13 = norm(points(9).pos - points(13).pos);
    dist_11_13 = norm(points(11).pos - points(13).pos);
    dist_12_13 = norm(points(12).pos - points(13).pos);

    if F1.Enable
        wheel_radius = F1.TyreRadius;    
    else
        wheel_radius = 193;              
    end
    
    % Rúd alak kirajzolása
    function h = draw_rod(ax, p1, p2, radius, color, alpha)
        direction = p2 - p1;
        len = norm(direction);
        if len < 1e-6
            h = [];
            return;
        end
        u = direction / len;
        if abs(u(3)) < 0.999
            v = cross([0 0 1], u);
        else
            v = cross([1 0 0], u);
        end
        v = v / norm(v);
        w = cross(u, v);
        [xc, yc, zc] = cylinder(radius * [1 1], 24);
        zc = zc * len;
        X = p1(1) + xc.*v(1) + yc.*w(1) + zc.*u(1);
        Y = p1(2) + xc.*v(2) + yc.*w(2) + zc.*u(2);
        Z = p1(3) + xc.*v(3) + yc.*w(3) + zc.*u(3);
        h = surf(ax, X, Y, Z, 'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', alpha, 'FaceLighting', 'gouraud');
    end

    function h = draw_tire(ax, pos_center, unit_normal, ~, ~)
        R_outer = Tyre.R_outer;     
        R_rim = Tyre.R_rim;           
        tire_width_mm = Tyre.width;         
        sidewall_thickness = (R_outer - R_rim);  
        section_radius = sidewall_thickness * 0.8;   
        n_theta = 120;   
        n_phi = 40;    
        [theta, phi] = meshgrid(linspace(0, 2*pi, n_theta), linspace(-pi/2, pi/2, n_phi));
        r_profile = R_outer - section_radius * (1 - cos(phi));  
        X = r_profile .* cos(theta);
        Y = r_profile .* sin(theta);
        Z = (tire_width_mm / 2) * sin(phi);   
        rim_height = Tyre.rim_half;  
        z_rim = linspace(-rim_height, rim_height, 10);
        [theta_rim, z_rim] = meshgrid(linspace(0, 2*pi, 80), z_rim);
        X_rim = R_rim * cos(theta_rim);
        Y_rim = R_rim * sin(theta_rim);
        Z_rim = z_rim;   

        from = [0; 0; 1];
        to = unit_normal(:) / norm(unit_normal);
        if norm(to - from) < 1e-6
            R_align = eye(3);  
        else
            v = cross(from, to);
            s = norm(v);
            c = dot(from, to);
            if s < 1e-8
                R_align = (c > 0) * eye(3) + (c <= 0) * (-eye(3));
            else
                vx = [0 -v(3) v(2); v(3) 0 -v(1); -v(2) v(1) 0];
                R_align = eye(3) + vx + (vx * vx) * (1 - c) / s^2;
            end
        end

        pts_tyre = [X(:)'; Y(:)'; Z(:)'];
        pts_tyre_rot = R_align * pts_tyre;
        X_t_rot = reshape(pts_tyre_rot(1,:), size(X)) + pos_center(1);
        Y_t_rot = reshape(pts_tyre_rot(2,:), size(Y)) + pos_center(2);
        Z_t_rot = reshape(pts_tyre_rot(3,:), size(Z)) + pos_center(3);
    
        pts_rim = [X_rim(:)'; Y_rim(:)'; Z_rim(:)'];
        pts_rim_rot = R_align * pts_rim;
        X_r_rot = reshape(pts_rim_rot(1,:), size(X_rim)) + pos_center(1);
        Y_r_rot = reshape(pts_rim_rot(2,:), size(Y_rim)) + pos_center(2);
        Z_r_rot = reshape(pts_rim_rot(3,:), size(Z_rim)) + pos_center(3);
    
        hold(ax, 'on');
        surf(ax, X_t_rot, Y_t_rot, Z_t_rot, 'FaceColor', [0.28 0.28 0.30], 'EdgeColor', 'none', 'FaceAlpha', 0.098, 'FaceLighting', 'gouraud', 'SpecularStrength', 0.25, 'AmbientStrength', 0.7);
        surf(ax, X_r_rot, Y_r_rot, Z_r_rot, 'FaceColor', [0.65 0.68 0.72], 'EdgeColor', 'none', 'FaceAlpha', 0.01, 'FaceLighting', 'phong', 'SpecularStrength', 0.6);
        hold(ax, 'off');
        h = gco;
    end

    % ========================
    % 2. Kényszerek definiálása
    % ========================

    constraints = {};   
    
    function constraints = add_distance(constraints, pts_array, i, j, length_mm)
        new_constraint = @(all_points) norm(all_points(j).pos - all_points(i).pos) - length_mm; 
        constraints{end+1} = new_constraint;
    end
    
    constraints = add_distance(constraints, points, 1, 3, dist_1_3);   
    constraints = add_distance(constraints, points, 2, 3, dist_2_3);   
    constraints = add_distance(constraints, points, 4, 6, dist_4_6);   
    constraints = add_distance(constraints, points, 5, 6, dist_5_6);   
    constraints = add_distance(constraints, points, 3, 6, dist_3_6);   
    constraints = add_distance(constraints, points, 8, 6, dist_8_6);   
    constraints = add_distance(constraints, points, 8, 3, dist_8_3);   
    constraints = add_distance(constraints, points, 7, 8, dist_7_8);   
    constraints = add_distance(constraints, points, 9, 10, dist_9_10);   
    % constraints = add_distance(constraints, points, 3, 10, dist_3_10);   
    % constraints = add_distance(constraints, points, 1, 10, dist_1_10);   
    % constraints = add_distance(constraints, points, 2, 10, dist_2_10); 
    constraints = add_distance(constraints, points, 6, 10, dist_3_10);   
    constraints = add_distance(constraints, points, 4, 10, dist_1_10);   
    constraints = add_distance(constraints, points, 5, 10, dist_2_10); 
    constraints = add_distance(constraints, points, 9, 11, dist_9_11);    
    constraints = add_distance(constraints, points, 9, 12, dist_9_12);   
    constraints = add_distance(constraints, points, 3, 15, dist_3_15);    
    constraints = add_distance(constraints, points, 6, 15, dist_6_15);    
    constraints = add_distance(constraints, points, 8, 15, dist_8_15);    
    constraints = add_distance(constraints, points, 9, 13, dist_9_13);
    constraints = add_distance(constraints, points, 11, 13, dist_11_13);
    constraints = add_distance(constraints, points, 12, 13, dist_12_13);
    % ARB kényszerek kikommentelve (16, 17, 18)

    % ===========================================================================================================
    % 3. Residual függvény
    % ===========================================================================================================

    function residuals = compute_all_residuals(x_free, points_base, constraints, free_indices)
        points = points_base;
        k = 1;
        for idx = free_indices
            points(idx).pos = x_free(k : k+2);   
            k = k + 3;
        end

        residuals = zeros(length(constraints), 1);
        for c = 1 : length(constraints)
            residuals(c) = constraints{c}(points); 
        end
    end

    % === 4. Szabad változók összegyűjtése ===
    free_indices = find(~[points.fixed]);  
    initial_x7 = points(7).pos(1);
    x_initial = [];
    for i = free_indices
        x_initial = [x_initial, points(i).pos];   
    end
    
    % === 5. Megoldás futtatása ===
    options = optimoptions('lsqnonlin', 'Display', 'iter-detailed', 'MaxIterations', 5000, 'StepTolerance', 1e-20, 'FunctionTolerance', 1e-20);

    [x_solution, res_norm, residual_vector, exitflag] = lsqnonlin(@(x) compute_all_residuals(x, points, constraints, free_indices), x_initial, [], [], options); 

    % === 6. Eredmény visszaírása és kiírása ===
    k = 1;
    for i = free_indices
        points(i).pos = x_solution(k : k+2);
        k = k + 3;
    end

    disp('=================== EREDMÉNY ===================');
    disp('Residual norma (minél kisebb, annál jobb):');
    disp(res_norm);

    if res_norm > 1e-6
        disp('Figyelem: nem tökéletes az illeszkedés – rossz kezdeti értékek?');
    end

    %% Mozgós modell
    
    wheel_travel_range = -15 : 5 : 15; 
    steering_range = -30 : 30 : 30; 
    num_wheel_steps = length(wheel_travel_range);
    num_steer_steps = length(steering_range);
    positions_history = zeros(length(points), 3, num_wheel_steps, num_steer_steps);

    original_points = points;

    upright_indices = [3,6,8,10];
    upright_static_pos = zeros(3, length(upright_indices));
    for ii = 1:length(upright_indices)
        upright_static_pos(:,ii) = original_points(upright_indices(ii)).pos';
    end

    initial_normal = [0, 1, 0]';  

    fixed_indices = find([points.fixed]);
    chassis_fixed = setdiff(fixed_indices, 16);  

    for wheel_step = 1:num_wheel_steps
        for steer_step = 1:num_steer_steps
            for i = fixed_indices
                positions_history(i, :, wheel_step, steer_step) = points(i).pos; 
            end
        end
    end

    quick_options = optimoptions('fsolve', 'Display', 'off', 'MaxIterations', 5000, 'StepTolerance', 1e-20, 'FunctionTolerance', 1e-20, 'Algorithm', 'levenberg-marquardt');

     function residuals = compute_residuals_with_z_and_y(x_free, points_base, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7)
        points = points_base;  
        
        k = 1;
        for idx = free_indices
            points(idx).pos = x_free(k : k+2);
            k = k + 3;
        end
        
        residuals = zeros(length(constraints), 1);
        for c = 1 : length(constraints)
            residuals(c) = constraints{c}(points);
        end
        
        residuals(end+1) = points(7).pos(1) - initial_x7;
        residuals(end+1) = points(7).pos(3) - target_z7;
        residuals(end+1) = points(15).pos(3) - target_z15; 
        residuals(end+1) = points(7).pos(2) - target_y7;
    end

    zero_wheel_step = find(wheel_travel_range == 0, 1);
    zero_steer_step = find(steering_range == 0, 1);
    positions_history(3, :, zero_wheel_step, zero_steer_step) = points(3).pos;
    positions_history(6, :, zero_wheel_step, zero_steer_step) = points(6).pos;
    positions_history(7, :, zero_wheel_step, zero_steer_step) = points(7).pos;
    positions_history(8, :, zero_wheel_step, zero_steer_step) = points(8).pos;
    positions_history(9, :, zero_wheel_step, zero_steer_step) = points(9).pos;
    positions_history(10, :, zero_wheel_step, zero_steer_step) = points(10).pos;
    positions_history(13, :, zero_wheel_step, zero_steer_step) = points(13).pos;
    positions_history(15, :, zero_wheel_step, zero_steer_step) = points(15).pos;
    % ARB pontok (16, 17, 18) history mentése kikommentelve
    static_z15 = points(15).pos(3);
    static_y7 = points(7).pos(2);
    static_z7 = points(7).pos(3); 

    % Negatív irány (rebound)
    current_pos3 = points(3).pos;
    current_pos6 = points(6).pos;
    current_pos7 = points(7).pos;
    current_pos8 = points(8).pos;
    current_pos9 = points(9).pos;
    current_pos10 = points(10).pos;
    current_pos13 = points(13).pos;
    current_pos15 = points(15).pos;
    current_dz = 0;
    for wheel_step = zero_wheel_step - 1 : -1 : 1
        dz = wheel_travel_range(wheel_step); 
        delta_dz = dz - current_dz;
        points_base = original_points;
        for i = chassis_fixed
            points_base(i).pos(3) = points_base(i).pos(3) - dz;  
        end
        x_free_initial = [current_pos3 + [0 0 delta_dz], current_pos6 + [0 0 delta_dz], current_pos7 + [0 0 delta_dz], current_pos8 + [0 0 delta_dz], current_pos9 + [0 0 delta_dz], current_pos10 + [0 0 delta_dz], current_pos13 + [0 0 delta_dz], current_pos15 + [0 0 delta_dz]];
        x_free_initial = x_free_initial(:)';
        target_z15 = static_z15;  
        target_y7 = static_y7;
        target_z7 = static_z7 - dz;  
        x_solution_step = fsolve(@(x) compute_residuals_with_z_and_y(x, points_base, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7), x_free_initial, quick_options);
        current_pos3 = x_solution_step(1:3);
        current_pos6 = x_solution_step(4:6);
        current_pos7 = x_solution_step(7:9);
        current_pos8 = x_solution_step(10:12);
        current_pos9 = x_solution_step(13:15);
        current_pos10 = x_solution_step(16:18);
        current_pos13 = x_solution_step(19:21);
        current_pos15 = x_solution_step(22:24);
        positions_history(3, :, wheel_step, zero_steer_step) = current_pos3;
        positions_history(6, :, wheel_step, zero_steer_step) = current_pos6;
        positions_history(7, :, wheel_step, zero_steer_step) = current_pos7;
        positions_history(8, :, wheel_step, zero_steer_step) = current_pos8;
        positions_history(9, :, wheel_step, zero_steer_step) = current_pos9;
        positions_history(10, :, wheel_step, zero_steer_step) = current_pos10;
        positions_history(13, :, wheel_step, zero_steer_step) = current_pos13;
        positions_history(15, :, wheel_step, zero_steer_step) = current_pos15;

        for i = chassis_fixed
            positions_history(i, :, wheel_step, zero_steer_step) = points_base(i).pos;
        end
        current_dz = dz;
    end

    % Pozitív irány (bound)
    current_pos3 = points(3).pos;
    current_pos6 = points(6).pos;
    current_pos7 = points(7).pos;
    current_pos8 = points(8).pos;
    current_pos9 = points(9).pos;
    current_pos10 = points(10).pos;
    current_pos13 = points(13).pos;
    current_pos15 = points(15).pos;
    current_dz = 0;
    for wheel_step = zero_wheel_step + 1 : 1 : num_wheel_steps
        dz = wheel_travel_range(wheel_step);
        delta_dz = dz - current_dz;
        points_base = original_points;
        for i = chassis_fixed
            points_base(i).pos(3) = points_base(i).pos(3) - dz;
        end
        x_free_initial = [current_pos3 + [0 0 delta_dz], current_pos6 + [0 0 delta_dz], current_pos7 + [0 0 delta_dz], current_pos8 + [0 0 delta_dz], current_pos9 + [0 0 delta_dz], current_pos10 + [0 0 delta_dz], current_pos13 + [0 0 delta_dz], current_pos15 + [0 0 delta_dz]];
        x_free_initial = x_free_initial(:)';
        target_z15 = static_z15;  
        target_y7 = static_y7;
        target_z7 = static_z7 - dz;
        x_solution_step = fsolve(@(x) compute_residuals_with_z_and_y(x, points_base, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7), x_free_initial, quick_options);
        current_pos3 = x_solution_step(1:3);
        current_pos6 = x_solution_step(4:6);
        current_pos7 = x_solution_step(7:9);
        current_pos8 = x_solution_step(10:12);
        current_pos9 = x_solution_step(13:15);
        current_pos10 = x_solution_step(16:18);
        current_pos13 = x_solution_step(19:21);
        current_pos15 = x_solution_step(22:24);
        positions_history(3, :, wheel_step, zero_steer_step) = current_pos3;
        positions_history(6, :, wheel_step, zero_steer_step) = current_pos6;
        positions_history(7, :, wheel_step, zero_steer_step) = current_pos7;
        positions_history(8, :, wheel_step, zero_steer_step) = current_pos8;
        positions_history(9, :, wheel_step, zero_steer_step) = current_pos9;
        positions_history(10, :, wheel_step, zero_steer_step) = current_pos10;
        positions_history(13, :, wheel_step, zero_steer_step) = current_pos13;
        positions_history(15, :, wheel_step, zero_steer_step) = current_pos15;

        for i = chassis_fixed
            positions_history(i, :, wheel_step, zero_steer_step) = points_base(i).pos;
        end
        current_dz = dz;
    end

    for wheel_step = 1:num_wheel_steps
        % Negative steering
        current_pos3 = squeeze(positions_history(3, :, wheel_step, zero_steer_step));
        current_pos6 = squeeze(positions_history(6, :, wheel_step, zero_steer_step));
        current_pos7 = squeeze(positions_history(7, :, wheel_step, zero_steer_step));
        current_pos8 = squeeze(positions_history(8, :, wheel_step, zero_steer_step));
        current_pos9 = squeeze(positions_history(9, :, wheel_step, zero_steer_step));
        current_pos10 = squeeze(positions_history(10, :, wheel_step, zero_steer_step));
        current_pos13 = squeeze(positions_history(13, :, wheel_step, zero_steer_step));
        current_pos15 = squeeze(positions_history(15, :, wheel_step, zero_steer_step));
        current_dy = 0;
        for steer_step = zero_steer_step - 1 : -1 : 1
            dy = steering_range(steer_step);
            delta_dy = dy - current_dy;
            points_base = original_points;
            dz = wheel_travel_range(wheel_step);
            for i = chassis_fixed
                points_base(i).pos(3) = points_base(i).pos(3) - dz;
            end
            x_free_initial = [current_pos3 + [0 delta_dy 0], current_pos6 + [0 delta_dy 0], current_pos7 + [0 delta_dy 0], current_pos8 + [0 delta_dy 0], current_pos9 + [0 delta_dy 0], current_pos10 + [0 delta_dy 0], current_pos13 + [0 delta_dy 0], current_pos15 + [0 delta_dy 0]];
            x_free_initial = x_free_initial(:)';
            target_z15 = static_z15; 
            target_y7 = static_y7 + dy;
            target_z7 = static_z7 - dz;
            x_solution_step = fsolve(@(x) compute_residuals_with_z_and_y(x, points_base, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7), x_free_initial, quick_options);
            current_pos3 = x_solution_step(1:3);
            current_pos6 = x_solution_step(4:6);
            current_pos7 = x_solution_step(7:9);
            current_pos8 = x_solution_step(10:12);
            current_pos9 = x_solution_step(13:15);
            current_pos10 = x_solution_step(16:18);
            current_pos13 = x_solution_step(19:21);
            current_pos15 = x_solution_step(22:24);
            positions_history(3, :, wheel_step, steer_step) = current_pos3;
            positions_history(6, :, wheel_step, steer_step) = current_pos6;
            positions_history(7, :, wheel_step, steer_step) = current_pos7;
            positions_history(8, :, wheel_step, steer_step) = current_pos8;
            positions_history(9, :, wheel_step, steer_step) = current_pos9;
            positions_history(10, :, wheel_step, steer_step) = current_pos10;
            positions_history(13, :, wheel_step, steer_step) = current_pos13;
            positions_history(15, :, wheel_step, steer_step) = current_pos15;

            for i = chassis_fixed
                positions_history(i, :, wheel_step, steer_step) = points_base(i).pos;
            end
            current_dy = dy;
        end

        % Positive steering
        current_pos3 = squeeze(positions_history(3, :, wheel_step, zero_steer_step));
        current_pos6 = squeeze(positions_history(6, :, wheel_step, zero_steer_step));
        current_pos7 = squeeze(positions_history(7, :, wheel_step, zero_steer_step));
        current_pos8 = squeeze(positions_history(8, :, wheel_step, zero_steer_step));
        current_pos9 = squeeze(positions_history(9, :, wheel_step, zero_steer_step));
        current_pos10 = squeeze(positions_history(10, :, wheel_step, zero_steer_step));
        current_pos13 = squeeze(positions_history(13, :, wheel_step, zero_steer_step));
        current_pos15 = squeeze(positions_history(15, :, wheel_step, zero_steer_step));
        current_dy = 0;
        for steer_step = zero_steer_step + 1 : 1 : num_steer_steps
            dy = steering_range(steer_step);
            delta_dy = dy - current_dy;
            points_base = original_points;
            dz = wheel_travel_range(wheel_step);
            for i = chassis_fixed
                points_base(i).pos(3) = points_base(i).pos(3) - dz;
            end
            x_free_initial = [current_pos3 + [0 delta_dy 0], current_pos6 + [0 delta_dy 0], current_pos7 + [0 delta_dy 0], current_pos8 + [0 delta_dy 0], current_pos9 + [0 delta_dy 0], current_pos10 + [0 delta_dy 0], current_pos13 + [0 delta_dy 0], current_pos15 + [0 delta_dy 0]];
            x_free_initial = x_free_initial(:)';
            target_z15 = static_z15; 
            target_y7 = static_y7 + dy;
            target_z7 = static_z7 - dz;
            x_solution_step = fsolve(@(x) compute_residuals_with_z_and_y(x, points_base, constraints, free_indices, target_z15, target_y7, initial_x7, target_z7), x_free_initial, quick_options);
            current_pos3 = x_solution_step(1:3);
            current_pos6 = x_solution_step(4:6);
            current_pos7 = x_solution_step(7:9);
            current_pos8 = x_solution_step(10:12);
            current_pos9 = x_solution_step(13:15);
            current_pos10 = x_solution_step(16:18);
            current_pos13 = x_solution_step(19:21);
            current_pos15 = x_solution_step(22:24);
            positions_history(3, :, wheel_step, steer_step) = current_pos3;
            positions_history(6, :, wheel_step, steer_step) = current_pos6;
            positions_history(7, :, wheel_step, steer_step) = current_pos7;
            positions_history(8, :, wheel_step, steer_step) = current_pos8;
            positions_history(9, :, wheel_step, steer_step) = current_pos9;
            positions_history(10, :, wheel_step, steer_step) = current_pos10;
            positions_history(13, :, wheel_step, steer_step) = current_pos13;
            positions_history(15, :, wheel_step, steer_step) = current_pos15;

            for i = chassis_fixed
                positions_history(i, :, wheel_step, steer_step) = points_base(i).pos;
            end
            current_dy = dy;
        end
    end

    % ===============================
    % 2. Paraméter számítások és tárolások
    % ===============================

    top_history = zeros(num_wheel_steps, num_steer_steps, 3);
    bottom_history = zeros(num_wheel_steps, num_steer_steps, 3);
    front_history = zeros(num_wheel_steps, num_steer_steps, 3);
    rear_history = zeros(num_wheel_steps, num_steer_steps, 3);
    camber_history = zeros(num_wheel_steps, num_steer_steps, 3);
    toe_history = zeros(num_wheel_steps, num_steer_steps);
    mechanical_trail_history = zeros(num_wheel_steps, num_steer_steps);
    scrub_radius_history = zeros(num_wheel_steps, num_steer_steps);
    caster_history = zeros(num_wheel_steps, num_steer_steps);
    kpi_history = zeros(num_wheel_steps, num_steer_steps);
    contact_patch_x_history = zeros(num_wheel_steps, num_steer_steps);
    contact_patch_y_history = zeros(num_wheel_steps, num_steer_steps);
    contact_patch_z_history = zeros(num_wheel_steps, num_steer_steps);
    front_ic_history = zeros(num_wheel_steps, num_steer_steps, 3);  
    side_ic_history = zeros(num_wheel_steps, num_steer_steps, 3);   
    instant_axis_dir_history = zeros(num_wheel_steps, num_steer_steps, 3);  
    instant_axis_point_history = zeros(num_wheel_steps, num_steer_steps, 3);  
    front_vsa_history = zeros(num_wheel_steps, num_steer_steps);
    side_vsa_history = zeros(num_wheel_steps, num_steer_steps);
    damper_length_history = zeros(num_wheel_steps, num_steer_steps);
    damper_MR_history = zeros(num_wheel_steps, num_steer_steps);
    % arb_angle_history és arb_MR_history kikommentelve
    half_track_history = zeros(num_wheel_steps, num_steer_steps);
    ride_height_history = zeros(num_wheel_steps, num_steer_steps);
    R_history = zeros(num_wheel_steps, num_steer_steps, 3, 3);
    roll_center_history = zeros(num_wheel_steps, num_steer_steps);
    roll_center_history = zeros(num_wheel_steps, num_steer_steps, 3);

    anti_dive_history   = zeros(num_wheel_steps, num_steer_steps);  
    phi_F_history       = zeros(num_wheel_steps, num_steer_steps);  

    W_wheelbase_mm          = 3000;   
    front_brake_percent     = 54;     
    h_CG_SM_static_mm       = 320;    

    A = [squeeze(positions_history(6,:,zero_wheel_step, zero_steer_step)); 
         squeeze(positions_history(3,:,zero_wheel_step, zero_steer_step)); 
         squeeze(positions_history(8,:,zero_wheel_step, zero_steer_step))];    
    muA = mean(A);

    initial_normal = [0, 1, 0]';  
    pos_center_s = squeeze(positions_history(15,:,zero_wheel_step, zero_steer_step));
    pos_top_s = pos_center_s + [0 0 wheel_radius];
    pos_bottom_s = pos_center_s + [0 0 -wheel_radius];
    pos_front_s = pos_center_s + [wheel_radius 0 0];
    pos_rear_s = pos_center_s + [-wheel_radius 0 0];
    
    for wheel_step = 1:num_wheel_steps
        for steer_step = 1:num_steer_steps

            pos_lower = squeeze(positions_history(6, :, wheel_step, steer_step));
            pos_upper = squeeze(positions_history(3, :, wheel_step, steer_step));
            pos_center = squeeze(positions_history(15, :, wheel_step, steer_step));
    
            B = [squeeze(positions_history(6,:,wheel_step,steer_step)); 
                 squeeze(positions_history(3,:,wheel_step,steer_step)); 
                 squeeze(positions_history(8,:,wheel_step,steer_step)) ];
            muB = mean(B);
        
            A0 = A - muA;
            B0 = B - muB;
            H = A0' * B0;
            [U, S, V] = svd(H);
            R = V * U';
            if det(R) < 0
                V(:,3) = -V(:,3);
                R = V * U';
            end

            R_history(wheel_step, steer_step, :, :) = R;

            pos_top_c = (R * (pos_top_s' - muA'))' + muB;
            pos_bottom_c = (R * (pos_bottom_s' - muA'))' + muB;
            pos_front_c = (R * (pos_front_s' - muA'))' + muB;
            pos_rear_c = (R * (pos_rear_s' - muA'))' + muB;
    
            top_history(wheel_step, steer_step, :) = pos_top_c;
            bottom_history(wheel_step, steer_step, :) = pos_bottom_c;
            front_history(wheel_step, steer_step, :) = pos_front_c;
            rear_history(wheel_step, steer_step, :) = pos_rear_c;
    
            horiz_vec = pos_front_c - pos_rear_c;
            horiz_vec(3) = 0;  
            if norm(horiz_vec) < 1e-6
                warning('Hibás heading [%d,%d]: pontok túl közel', wheel_step, steer_step);
                heading_unit = [1, 0, 0];  
            else
                heading_unit = horiz_vec / norm(horiz_vec);
            end
            
            transverse_unit = [-heading_unit(2), heading_unit(1), 0];  
            vert_vec = pos_top_c - pos_bottom_c;
            tilt_lateral = dot(vert_vec, transverse_unit);
            tilt_vertical = dot(vert_vec, [0, 0, 1]);
            camber_rad = atan2(tilt_lateral, tilt_vertical);
            camber_history(wheel_step, steer_step) = -rad2deg(camber_rad); 
     
            current_normal = R * initial_normal;
            unit_normal = current_normal / norm(current_normal);

            if abs(unit_normal(2)) > 1e-6
                toe_history(wheel_step, steer_step) = -rad2deg(atan(unit_normal(1) / unit_normal(2)));
            else
                toe_history(wheel_step, steer_step) = 90 * sign(unit_normal(1));  
            end

            gravity_dir = [0; 0; -1]; 
            proj_grav = gravity_dir - dot(gravity_dir, unit_normal) * unit_normal;
            if norm(proj_grav) > 1e-6
                down_dir = proj_grav / norm(proj_grav);
            else
                down_dir = [0; 0; -1];  
            end
            t_gnd = (0 - pos_center(3)) / down_dir(3);  
            cp = pos_center' + t_gnd * down_dir;

            contact_patch = cp;  
            cp_x = cp(1);
            cp_y = cp(2);
            cp_z = cp(3);
    
            contact_patch_x_history(wheel_step, steer_step) = cp_x;
            contact_patch_y_history(wheel_step, steer_step) = cp_y;
            contact_patch_z_history(wheel_step, steer_step) = cp_z;

            kingpin_vec = pos_upper - pos_lower;
            kingpin_vec = kingpin_vec / norm(kingpin_vec);
    
            if abs(kingpin_vec(3)) > 1e-8
                t_ground = -pos_upper(3) / kingpin_vec(3);
                kingpin_ground = pos_upper + t_ground * kingpin_vec;
                kg_x = kingpin_ground(1);
                kg_y = kingpin_ground(2);
            else
                kg_x = pos_center(1);
                kg_y = pos_center(2);
            end

            kpi_projection = [kingpin_vec(2); kingpin_vec(3)];
            kpi_projection = kpi_projection / norm(kpi_projection);
            kpi_history(wheel_step, steer_step) = -rad2deg(atan2(kpi_projection(1), abs(kpi_projection(2))));
    
            scrub_radius_history(wheel_step, steer_step) = cp_y - kg_y;
            mechanical_trail_history(wheel_step, steer_step) = kg_x - cp_x;   

            caster_projection = [kingpin_vec(1); kingpin_vec(3)];
            caster_projection = caster_projection / norm(caster_projection);
            caster_history(wheel_step, steer_step) = -rad2deg(atan2(caster_projection(1), caster_projection(2)));

            if num_wheel_steps > 1
                if wheel_step == 1
                    step_m = 1;
                    step_p = 2;
                elseif wheel_step == num_wheel_steps
                    step_m = num_wheel_steps - 1;
                    step_p = num_wheel_steps;
                else
                    step_m = wheel_step - 1;
                    step_p = wheel_step + 1;
                end

                dz_m = wheel_travel_range(step_m);
                dz_p = wheel_travel_range(step_p);
                dz_c = wheel_travel_range(wheel_step);

                B_m = [reshape(positions_history(6,:,step_m,steer_step), 1, 3);
                       reshape(positions_history(3,:,step_m,steer_step), 1, 3);
                       reshape(positions_history(8,:,step_m,steer_step), 1, 3)];
                muB_m = mean(B_m);
                B0_m = B_m - muB_m;
                H_m = A0' * B0_m;
                [U_m, ~, V_m] = svd(H_m);
                R_m = V_m * U_m';
                if det(R_m) < 0, V_m(:,3) = -V_m(:,3); R_m = V_m * U_m'; end

                B_p = [reshape(positions_history(6,:,step_p,steer_step), 1, 3);
                       reshape(positions_history(3,:,step_p,steer_step), 1, 3);
                       reshape(positions_history(8,:,step_p,steer_step), 1, 3)];
                muB_p = mean(B_p);
                B0_p = B_p - muB_p;
                H_p = A0' * B0_p;
                [U_p, ~, V_p] = svd(H_p);
                R_p = V_p * U_p';
                if det(R_p) < 0, V_p(:,3) = -V_p(:,3); R_p = V_p * U_p'; end

                R_delta = R_p * R_m';

                w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
                w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
                w_z = (R_delta(2,1) - R_delta(1,2)) / 2;

                p15_m = reshape(positions_history(15, :, step_m, steer_step), 1, 3) + [0, 0, dz_m];
                p15_p = reshape(positions_history(15, :, step_p, steer_step), 1, 3) + [0, 0, dz_p];
                p15_c = reshape(positions_history(15, :, wheel_step, steer_step), 1, 3) + [0, 0, dz_c];

                v_15 = p15_p - p15_m;

                if abs(w_x) > 1e-10
                    y_ic = p15_c(2) + (-v_15(3) + w_y * (cp_x - p15_c(1))) / w_x;
                    z_ic = p15_c(3) + ( v_15(2) + w_z * (cp_x - p15_c(1))) / w_x;
                    front_ic_chassis = [cp_x, y_ic, z_ic];
                else
                    front_ic_chassis = [cp_x, cp_y + sign(v_15(2))*1e6, cp_z + 1e6];
                end

                if abs(w_y) > 1e-10
                    x_ic = p15_c(1) + ( v_15(3) + w_x * (cp_y - p15_c(2))) / w_y;
                    z_ic = p15_c(3) + (-v_15(1) + w_z * (cp_y - p15_c(2))) / w_y;
                    side_ic_chassis = [x_ic, cp_y, z_ic];
                else
                    side_ic_chassis = [cp_x + sign(v_15(1))*1e6, cp_y, cp_z + 1e6];
                end

                front_ic = front_ic_chassis - [0, 0, dz_c];
                side_ic  = side_ic_chassis  - [0, 0, dz_c];

                ia_dir = [w_x, w_y, w_z];
                if norm(ia_dir) > 1e-10
                    ia_dir = ia_dir / norm(ia_dir);
                end
                ia_point = front_ic; 
            else
                front_ic = [cp_x, 1e6, 1e6];
                side_ic  = [1e6, cp_y, 1e6];
                ia_dir   = [0, 0, 0];
                ia_point = front_ic;
            end

            front_ic_history(wheel_step, steer_step, :) = front_ic;
            side_ic_history(wheel_step, steer_step, :) = side_ic;
            instant_axis_dir_history(wheel_step, steer_step, :) = ia_dir;
            instant_axis_point_history(wheel_step, steer_step, :) = ia_point;

            front_vsa_history(wheel_step, steer_step) = hypot(front_ic(2) - cp_y, front_ic(3) - cp_z);
            side_vsa_history(wheel_step, steer_step) = hypot(side_ic(1) - cp_x, side_ic(3) - cp_z);

            dx_side = side_ic(1) - cp_x;          
            dz_side = side_ic(3) - cp_z;          

            if abs(dx_side) > 1.0 && norm(side_ic) < 1e5
                tan_Phi_F = dz_side / (-dx_side);   
                Phi_F_deg = rad2deg(atan(tan_Phi_F));
            else
                tan_Phi_F = 0;
                Phi_F_deg = 0;
            end
            phi_F_history(wheel_step, steer_step) = Phi_F_deg;

            heave_mm = wheel_travel_range(wheel_step);
            h_CG_SM_current = h_CG_SM_static_mm - heave_mm;   

            if h_CG_SM_current > 1.0
                anti_dive_pct = (W_wheelbase_mm * tan_Phi_F * (front_brake_percent/100) / h_CG_SM_current) * 100;
            else
                anti_dive_pct = 0;
            end
            anti_dive_history(wheel_step, steer_step) = anti_dive_pct;

            if norm(ia_dir) > 1e-10
                CP_L = [cp_x, cp_y, cp_z];
                IA_pt_L = ia_point; 
                IA_dir_L = ia_dir;
            
                CP_R = [cp_x, -cp_y, cp_z];
                IA_pt_R = [ia_point(1), -ia_point(2), ia_point(3)];
                IA_dir_R = [ia_dir(1), -ia_dir(2), ia_dir(3)];
            
                vec_L = IA_pt_L - CP_L;
                N_L = cross(IA_dir_L, vec_L);
                if norm(N_L) > 1e-10
                    N_L = N_L / norm(N_L);
                end
            
                vec_R = IA_pt_R - CP_R;
                N_R = cross(IA_dir_R, vec_R);
                if norm(N_R) > 1e-10
                    N_R = N_R / norm(N_R);
                end
            
                d = cross(N_L, N_R);
                if norm(d) > 1e-10
                    d = d / norm(d);
                else
                    d = [1, 0, 0]; 
                end
            
                A_planes = [N_L; N_R];
                b_planes = [dot(N_L, CP_L); dot(N_R, CP_R)];
                P0 = (pinv(A_planes) * b_planes)'; 
            
                x_RC = (CP_L(1) + CP_R(1)) / 2;
            
                if abs(d(1)) > 1e-10
                    t_RC = (x_RC - P0(1)) / d(1);
                else
                    t_RC = 0; 
                end
            
                RC = P0 + t_RC * d;
            else
                RC = [cp_x, 0, cp_z];
                N_L = [0, 0, 0]; N_R = [0, 0, 0]; d = [0, 0, 0]; P0 = [0, 0, 0]; x_RC = cp_x;
            end
            
            roll_center_history(wheel_step, steer_step, :) = RC;

            pos13 = squeeze(positions_history(13, :, wheel_step, steer_step));
            pos14 = squeeze(positions_history(14, :, wheel_step, steer_step));
            damper_length = norm(pos13 - pos14);
            damper_length_history(wheel_step, steer_step) = damper_length;

            % % ARB szög számítás kikommentelve (17, 18)

            half_track_history(wheel_step, steer_step) = cp_y;

            if F1.Enable
                static_ride_height = F1.RefPlaneZ;   
            else
                static_ride_height = 34;             
            end
            ride_height_history(wheel_step, steer_step) = static_ride_height - wheel_travel_range(wheel_step);

        end
    end

    % Damper Motion Ratio számítás (ARB MR kikommentelve)
    for wheel_step = 2:num_wheel_steps-1
        for steer_step = 1:num_steer_steps
                damper_MR_history(1, steer_step) = (wheel_travel_range(2) - wheel_travel_range(1)) / (damper_length_history(2, steer_step) - damper_length_history(1, steer_step));
                damper_MR_history(wheel_step, steer_step) = (wheel_travel_range(wheel_step + 1) - wheel_travel_range(wheel_step - 1)) / (damper_length_history(wheel_step + 1, steer_step) - damper_length_history(wheel_step - 1, steer_step));
                damper_MR_history(end, steer_step) = (wheel_travel_range(end) - wheel_travel_range(end - 1)) / (damper_length_history(end, steer_step) - damper_length_history(end - 1, steer_step));
        end
    end

    damper_MR_history = damper_MR_history * -1;

    save('front_left_ic_history.mat', 'front_ic_history')
    save('contact_patch_left_x_history.mat', 'contact_patch_x_history')
    save('contact_patch_left_y_history.mat', 'contact_patch_y_history')
    save('contact_patch_left_z_history.mat', 'contact_patch_z_history')
    save('front_left_instant_axis_dir_history.mat', 'instant_axis_dir_history');
    save('front_left_instant_axis_point_history.mat', 'instant_axis_point_history');

    % Ütközés-vizsgálat
    collision_map = false(num_wheel_steps, num_steer_steps);
    collision_txt = cell(num_wheel_steps, num_steer_steps);
    for steer_step = 1:num_steer_steps
        for wheel_step = 1:num_wheel_steps
            [hit_s, rs_s] = pose_collision(wheel_step, steer_step);
            collision_map(wheel_step, steer_step) = any(hit_s);
            collision_txt{wheel_step, steer_step} = col_pose_string(hit_s, rs_s, Collision);
        end
    end
    fprintf('\n===== ÜTKÖZÉS-VIZSGÁLAT a teljes sweepen (%d póz, min. clearance %.1f mm) =====\n', ...
        numel(collision_map), Collision.min_clearance);
    if ~any(collision_map(:))
        disp('  Nincs ütközés egyik pózban sem.');
    else
        [iz_c, ir_c] = find(collision_map);
        for k_c = 1:min(numel(iz_c), 30)
            fprintf('  Z = %6.1f mm, rack = %6.1f mm : %s\n', wheel_travel_range(iz_c(k_c)), steering_range(ir_c(k_c)), ...
                collision_txt{iz_c(k_c), ir_c(k_c)});
        end
        if numel(iz_c) > 30, fprintf('  ... további %d ütköző póz\n', numel(iz_c) - 30); end
    end

    [~, f1_failed]       = f1_rules_status(f1_names, f1_vals);
    [~, f1_wheel_failed] = f1_static_wheel_status(wheel_center, F1);
    f1_failed = [f1_failed, f1_wheel_failed];
    if ~f1_outboard_ok(points(10).pos, wheel_center, F1, F1.PushrodOnMember)
        f1_failed{end+1} = 'C10.3.4 (pushrod upright)';
    end
    n_col = nnz(collision_map);
    n_tot = numel(collision_map);
    track_mm = 2 * abs(half_track_history(zero_wheel_step, zero_steer_step));
    if F1.Enable
        n0_s = f1_wheel_axes(F1);
        O_s  = f1_wcs_origin(wheel_center, n0_s, F1);
        dim_str = sprintf(['Felni: perem Ø%.0f, belső r %.0f, szél. %.1f mm | Gumi: Ø%.0f x %.0f mm | ' ...
            'Nyomtáv: %.0f mm (WCS |Y| = %.1f, max %g; Z_F1 = %.1f, %g..%g)'], ...
            2*F1.Rim.OuterRadius, F1.Rim.InnerRadius, F1.Rim.Width, 2*F1.TyreRadius, F1.TyreWidth, ...
            track_mm, abs(O_s(2)), F1.WCS_Ymax, O_s(3) - F1.RefPlaneZ, F1.WCS_Zrange(1), F1.WCS_Zrange(2));
    else
        dim_str = sprintf('FS mód | Felni: r %.0f..%.0f, szél. %.0f mm | Nyomtáv: %.0f mm', ...
            Collision.rim_inner_radius, Collision.rim_outer_radius, Collision.rim_width, track_mm);
    end
    if isempty(f1_failed) && n_col == 0
        if F1.Enable
            f1_str = sprintf('F1 2026 C10: SZABÁLYOS  |  teljes sweep: nincs ütközés (0/%d póz)', n_tot);
        else
            f1_str = sprintf('F1 ellenőrzés KI  |  teljes sweep: nincs ütközés (0/%d póz)', n_tot);
        end
        f1_bg = [0.6 0.9 0.6];
    else
        f1_parts = {};
        if ~isempty(f1_failed), f1_parts{end+1} = ['F1 SÉRÜL: ', strjoin(unique(f1_failed, 'stable'), ', ')]; end
        if n_col > 0, f1_parts{end+1} = sprintf('ÜTKÖZÉS %d/%d pózban', n_col, n_tot); end
        f1_str = strjoin(f1_parts, '  |  ');
        f1_bg = [1 0.55 0.55];
    end
    fprintf('\n>>> %s\n>>> %s\n\n', f1_str, dim_str);

    vis_lims = calc_vis_limits(positions_history, wheel_center, Tyre.R_outer);


    % =========================================================================
    % 3. Interaktív figure + slider
    % =========================================================================

    % ARB vonalak eltávolítva a line_pairs listából
    line_pairs = {[1, 3], [0.8 0.8 0.8], 3; [2, 3], [0.8 0.8 0.8], 3; [4, 6],  [0.8 0.8 0.8], 3; [5, 6], [0.8 0.8 0.8], 3; [3, 6], [0.8 0.8 0.8], 1.5; [3, 8], [0.8 0.8 0.8], 1.5; [6, 8], [0.8 0.8 0.8], 1.5; [7, 8], [0.8 0.8 0.8], 3; [9, 10], [0.8 0.8 0.8], 3; [11, 12], [0.8 0.8 0.8], 2.5; [13, 14], [0.8 0.8 0.8], 2; [12, 13], [0.8 0.8 0.8], 2; [12, 9], [0.8 0.8 0.8], 2};

    fig = figure('Name', 'Suspension visualization', 'NumberTitle', 'off', 'Position', [100 80 1920 1020], 'WindowState','maximized');   
    
    ax1 = axes('Parent', fig, 'Position', [0.005 0.55 0.45 0.4]);   
    hold(ax1, 'on'); grid(ax1, 'on'); axis(ax1, 'equal');
    xlim(ax1, vis_lims(1,:)); ylim(ax1, vis_lims(2,:)); zlim(ax1, vis_lims(3,:));
    xlabel(ax1, 'X [mm]'); ylabel(ax1, 'Y [mm]'); zlabel(ax1, 'Z [mm]');
    view(ax1, 135, 10); box(ax1, 'on'); title(ax1, '3D view');

    ax2 = axes('Parent', fig, 'Position', [0.505 0.55 0.45 0.4]);
    hold(ax2, 'on'); grid(ax2, 'on'); axis(ax2, 'equal');
    xlim(ax2, vis_lims(1,:)); ylim(ax2, vis_lims(2,:)); zlim(ax2, vis_lims(3,:));
    xlabel(ax2, 'X [mm]'); ylabel(ax2, 'Y [mm]'); zlabel(ax2, 'Z [mm]');
    view(ax2, 0, 90); box(ax2, 'on'); title(ax2, 'Top view');

    ax3 = axes('Parent', fig, 'Position', [0.005 0.05 0.45 0.4]);
    hold(ax3, 'on'); grid(ax3, 'on'); axis(ax3, 'equal');
    xlim(ax3, vis_lims(1,:)); ylim(ax3, vis_lims(2,:)); zlim(ax3, vis_lims(3,:));
    xlabel(ax3, 'X [mm]'); ylabel(ax3, 'Y [mm]'); zlabel(ax3, 'Z [mm]');
    view(ax3, 180, 0); box(ax3, 'on'); title(ax3, 'Side view');

    ax4 = axes('Parent', fig, 'Position', [0.505 0.05 0.45 0.4]);
    hold(ax4, 'on'); grid(ax4, 'on'); axis(ax4, 'equal');
    xlim(ax4, vis_lims(1,:)); ylim(ax4, vis_lims(2,:)); zlim(ax4, vis_lims(3,:));
    xlabel(ax4, 'X [mm]'); ylabel(ax4, 'Y [mm]'); zlabel(ax4, 'Z [mm]');
    view(ax4, 90, 0); box(ax4, 'on'); title(ax4, 'Front view');

    light('Parent', ax1, 'Position', [1 1 1], 'Style', 'infinite');
    light('Parent', ax1, 'Position', [-1 -1 1], 'Style', 'infinite');
    lighting(ax1, 'gouraud'); material(ax1, 'dull');

    [X, Y] = meshgrid(linspace(vis_lims(1,1), vis_lims(1,2), 40), linspace(vis_lims(2,1), vis_lims(2,2), 40));
    Z = -0 * ones(size(X));
    h_floor1 = surf(ax1, X, Y, Z, 'FaceColor', [0.92 0.94 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.45, 'FaceLighting', 'gouraud');
    set(h_floor1, 'HandleVisibility', 'off'); uistack(h_floor1, 'bottom');
    h_floor2 = surf(ax2, X, Y, Z, 'FaceColor', [0.92 0.94 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.45, 'FaceLighting', 'gouraud');
    set(h_floor2, 'HandleVisibility', 'off'); uistack(h_floor2, 'bottom');
    h_floor3 = surf(ax3, X, Y, Z, 'FaceColor', [0.92 0.94 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.45, 'FaceLighting', 'gouraud');
    set(h_floor3, 'HandleVisibility', 'off'); uistack(h_floor3, 'bottom');
    h_floor4 = surf(ax4, X, Y, Z, 'FaceColor', [0.92 0.94 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.45, 'FaceLighting', 'gouraud');
    set(h_floor4, 'HandleVisibility', 'off'); uistack(h_floor4, 'bottom');

    h_status_pose = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.005 0.962 0.49 0.036], 'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'String', '');
    h_status_f1 = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.505 0.962 0.49 0.036], 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'String', sprintf('%s\n%s', f1_str, dim_str), 'BackgroundColor', f1_bg);
    h_status_pose2 = gobjects(1);   

    h_points1 = gobjects(length(points), 1); h_texts1 = gobjects(length(points), 1); h_lines1 = gobjects(size(line_pairs,1), 1);
    h_points2 = gobjects(length(points), 1); h_texts2 = gobjects(length(points), 1); h_lines2 = gobjects(size(line_pairs,1), 1);
    h_points3 = gobjects(length(points), 1); h_texts3 = gobjects(length(points), 1); h_lines3 = gobjects(size(line_pairs,1), 1);
    h_points4 = gobjects(length(points), 1); h_texts4 = gobjects(length(points), 1); h_lines4 = gobjects(size(line_pairs,1), 1);
    
    initial_wheel_step = find(wheel_travel_range >= 0, 1, 'first');  
    initial_steer_step = find(steering_range >= 0, 1, 'first');
    update_plot(initial_wheel_step, initial_steer_step);
    
    fig2 = figure('Name','Toe, Camber, Contact Patch, VSA','NumberTitle','off', 'Position',[200 150 1400 780], 'WindowState','maximized');  

    ax_toe = subplot(2,2,1, 'Position', [0.05 0.55 0.3 0.4]);
    hold(ax_toe,'on'); grid on; box on;
    title(ax_toe,'Toe angle  (piros x = ütköző póz)');
    xlabel(ax_toe,'Wheel travel [mm]'); ylabel(ax_toe,'Toe angle [°]'); set(ax_toe,'FontSize',11);
    
    ax_camber = subplot(2,2,2, 'Position', [0.67 0.55 0.3 0.4]);
    hold(ax_camber,'on'); grid on; box on;
    title(ax_camber,'Camber angle');
    xlabel(ax_camber,'Wheel travel [mm]'); ylabel(ax_camber,'Camber angle [°]'); set(ax_camber,'FontSize',11);

    ax_contact_patch = subplot(2,2,3, 'Position', [0.05  0.07  0.3  0.4]);
    hold(ax_contact_patch,'on'); grid on; box on;
    title(ax_contact_patch,'Contact patch coordinates');
    xlabel(ax_contact_patch,'Wheel travel [mm]'); ylabel(ax_contact_patch,'Contact patch displacement [mm]'); set(ax_contact_patch,'FontSize',11);

    ax_vsa = subplot(2,2,4, 'Position', [0.67  0.07  0.3  0.4]);
    hold(ax_vsa,'on'); grid on; box on;
    title(ax_vsa,'Virtual swing arm length');
    xlabel(ax_vsa,'Wheel travel [mm]'); ylabel(ax_vsa,'Virtual swing arm length [mm]'); set(ax_vsa,'FontSize',11);

    h_toe_curve = plot(ax_toe, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_toe_collision = plot(ax_toe, NaN, NaN, 'rx', 'MarkerSize', 12, 'LineWidth', 2, 'HandleVisibility', 'off');
    h_camber_curve = plot(ax_camber, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_contact_patch_x_curve = plot(ax_contact_patch, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_contact_patch_y_curve = plot(ax_contact_patch, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_contact_patch_z_curve = plot(ax_contact_patch, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_front_vsa_curve = plot(ax_vsa, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_vsa_curve = plot(ax_vsa, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
   
    h_point_toe = plot(ax_toe, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_camber = plot(ax_camber, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_contact_patch_x = plot(ax_contact_patch, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_contact_patch_y = plot(ax_contact_patch, 0, 0, 'bo','MarkerFaceColor','b','MarkerSize',10);
    h_point_contact_patch_z = plot(ax_contact_patch, 0, 0, 'go','MarkerFaceColor','g','MarkerSize',10);
    h_point_front_vsa = plot(ax_vsa, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_side_vsa = plot(ax_vsa, 0, 0, 'ro','MarkerFaceColor','g','MarkerSize',10);

    wheel_slider2 = uicontrol('Parent',fig2, 'Style','slider', 'Units','normalized', 'Position',[0.44 0.05 0.02 0.85], 'Value',initial_wheel_step, 'Min',1, 'Max',num_wheel_steps, 'SliderStep',[1/(num_wheel_steps-1) 10/(num_wheel_steps-1)], 'Callback',@wheel_slider2_callback);
    steer_slider2 = uicontrol('Parent',fig2, 'Style','slider', 'Units','normalized', 'Position',[0.54 0.05 0.02 0.85], 'Value',initial_steer_step, 'Min',1, 'Max',num_steer_steps, 'SliderStep',[1/(num_steer_steps-1) 10/(num_steer_steps-1)], 'Callback',@steer_slider2_callback);

    travel_text2 = uicontrol('Parent',fig2, 'Style','text','Units','normalized', 'Position',[0.41 0.9 0.08 0.05], 'String',sprintf('Wheel Travel:\n%6.1f mm',wheel_travel_range(initial_wheel_step)), 'FontSize',12, 'FontWeight','bold','HorizontalAlignment','center');
    steer_text2 = uicontrol('Parent',fig2, 'Style','text','Units','normalized', 'Position',[0.50 0.9 0.10 0.05], 'String',sprintf('Rack Displacement:\n%6.1f mm', steering_range(initial_steer_step)), 'FontSize',12, 'FontWeight','bold','HorizontalAlignment','center');
    h_status_pose2 = uicontrol('Parent',fig2, 'Style','text','Units','normalized', 'Position',[0.36 0.955 0.28 0.04], 'String','', 'FontSize',9, 'FontWeight','bold','HorizontalAlignment','center');
    update_status(initial_wheel_step, initial_steer_step, false);

    fig3 = figure('Name', 'Mechanical Trail, Caster, Scrub & KPI', 'NumberTitle', 'off', 'Position', [300 100 1600 900], 'WindowState', 'maximized');

    ax_trail = subplot(2,2,1); hold on; grid on; box on; title(ax_trail, 'Mechanical Trail'); xlabel(ax_trail, 'Wheel travel [mm]'); ylabel(ax_trail, 'Mechanical Trail [mm]');
    ax_caster = subplot(2,2,2); hold on; grid on; box on; title(ax_caster, 'Caster Angle'); xlabel(ax_caster, 'Wheel travel [mm]'); ylabel(ax_caster, 'Caster Angle [°]');
    ax_scrub = subplot(2,2,3); hold on; grid on; box on; title(ax_scrub, 'Scrub Radius'); xlabel(ax_scrub, 'Wheel travel [mm]'); ylabel(ax_scrub, 'Scrub Radius [mm]');
    ax_kpi = subplot(2,2,4); hold on; grid on; box on; title(ax_kpi, 'Kingpin Inclination Angle'); xlabel(ax_kpi, 'Wheel travel [mm]'); ylabel(ax_kpi, 'Kingpin Inclination Angle [°]');
    
    h_trail_curve = plot(ax_trail, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_caster_curve = plot(ax_caster, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_scrub_curve = plot(ax_scrub, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_kpi_curve = plot(ax_kpi, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    
    h_point_trail = plot(ax_trail, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_caster = plot(ax_caster, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_scrub = plot(ax_scrub, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_kpi = plot(ax_kpi, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);

   % Fig4 – ARB grafikonok helyett csak Damper Length és Damper MR maradt
   fig4 = figure('Name', 'Damper Length & Damper MR', 'NumberTitle', 'off', 'Position', [300 100 1600 900], 'WindowState', 'maximized');

    ax_damper_length = subplot(1,2,1); hold on; grid on; box on;
    title(ax_damper_length, 'Damper Length'); xlabel(ax_damper_length, 'Wheel travel [mm]'); ylabel(ax_damper_length, 'Damper Length [mm]');
    
    ax_damper_MR = subplot(1,2,2); hold on; grid on; box on;
    title(ax_damper_MR, 'Damper Motion Ratio'); xlabel(ax_damper_MR, 'Wheel travel [mm]'); ylabel(ax_damper_MR, 'Damper Motion Ratio [-]');
    
    h_damper_length_curve = plot(ax_damper_length, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_damper_MR_curve = plot(ax_damper_MR, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    
    h_point_damper_length = plot(ax_damper_length, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_damper_MR = plot(ax_damper_MR, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);

    fig5 = figure('Name','Front IC, Side IC, Half Track, Ride Height','NumberTitle','off', 'Position',[200 150 1400 780], 'WindowState','maximized');  

    ax_front_IC = subplot(2,2,1); hold(ax_front_IC,'on'); grid on; box on; title(ax_front_IC,'Front IC coordinates'); xlabel(ax_front_IC,'Wheel travel [mm]'); ylabel(ax_front_IC,'Front IC coordinates [mm]'); set(ax_front_IC,'FontSize',11);
    ax_side_IC = subplot(2,2,2); hold(ax_side_IC,'on'); grid on; box on; title(ax_side_IC,'Side IC coordinates'); xlabel(ax_side_IC,'Wheel travel [mm]'); ylabel(ax_side_IC,'Side IC coordinates [mm]'); set(ax_side_IC,'FontSize',11);
    ax_half_track = subplot(2,2,3); hold(ax_half_track,'on'); grid on; box on; title(ax_half_track,'Half Track'); xlabel(ax_half_track,'Wheel travel [mm]'); ylabel(ax_half_track,'Half Track [mm]'); set(ax_half_track,'FontSize',11);
    ax_ride_height = subplot(2,2,4); hold(ax_ride_height,'on'); grid on; box on; title(ax_ride_height,'Ride Height'); xlabel(ax_ride_height,'Wheel travel [mm]'); ylabel(ax_ride_height,'Ride Height [mm]'); set(ax_ride_height,'FontSize',11);

    h_front_IC_x_curve = plot(ax_front_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_front_IC_y_curve = plot(ax_front_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_front_IC_z_curve = plot(ax_front_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_IC_x_curve = plot(ax_side_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_IC_y_curve = plot(ax_side_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_IC_z_curve = plot(ax_side_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_half_track_curve = plot(ax_half_track, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_ride_height_curve = plot(ax_ride_height, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
   
    h_point_front_IC_x = plot(ax_front_IC, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_front_IC_y = plot(ax_front_IC, 0, 0, 'bo','MarkerFaceColor','b','MarkerSize',10);
    h_point_front_IC_z = plot(ax_front_IC, 0, 0, 'go','MarkerFaceColor','g','MarkerSize',10);
    h_point_side_IC_x = plot(ax_side_IC, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_side_IC_y = plot(ax_side_IC, 0, 0, 'bo','MarkerFaceColor','b','MarkerSize',10);
    h_point_side_IC_z = plot(ax_side_IC, 0, 0, 'go','MarkerFaceColor','g','MarkerSize',10);           
    h_point_half_track = plot(ax_half_track, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_ride_height = plot(ax_ride_height, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);

    fig6 = figure('Name','Anti-Dive & Side-View Swing Arm Angle (Phi_F)','NumberTitle','off', ...
                  'Position',[250 120 1200 600], 'WindowState','maximized');

    ax_anti_dive = subplot(1,2,1);
    hold(ax_anti_dive,'on'); grid on; box on;
    title(ax_anti_dive, sprintf('Anti-Dive (W=%.0f mm, %%Fbrake=%.0f, h_{CG,SM,stat}=%.0f mm)', ...
          W_wheelbase_mm, front_brake_percent, h_CG_SM_static_mm));
    xlabel(ax_anti_dive, 'Wheel travel [mm]'); ylabel(ax_anti_dive, 'Anti-Dive [%]'); set(ax_anti_dive,'FontSize',11);

    ax_phi_F = subplot(1,2,2);
    hold(ax_phi_F,'on'); grid on; box on;
    title(ax_phi_F, 'Side-view swing-arm angle \Phi_F (CP \rightarrow Side IC)');
    xlabel(ax_phi_F, 'Wheel travel [mm]'); ylabel(ax_phi_F, '\Phi_F [°]'); set(ax_phi_F,'FontSize',11);

    h_anti_dive_curve = plot(ax_anti_dive, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.2 0.4 0.8], 'LineWidth',2, 'HandleVisibility','off');
    h_phi_F_curve     = plot(ax_phi_F,     wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.8 0.3 0.1], 'LineWidth',2, 'HandleVisibility','off');
    h_point_anti_dive = plot(ax_anti_dive, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_phi_F     = plot(ax_phi_F,     0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);

    update_diagram(initial_wheel_step, initial_steer_step)

    %% Callback és frissítő függvények

        function wheel_slider_callback(src, ~)
            wheel_step = round(get(src, 'Value'));
            set(src, 'Value', wheel_step);
            steer_step = round(get(steer_slider, 'Value'));
            update_plot(wheel_step, steer_step);
            set(travel_text, 'String', sprintf('Wheel travel: %6.1f mm', wheel_travel_range(wheel_step)));
        end

        function steer_slider_callback(src, ~)
            steer_step = round(get(src, 'Value'));
            set(src, 'Value', steer_step);
            wheel_step = round(get(wheel_slider, 'Value'));
            update_plot(wheel_step, steer_step);
            set(steer_text, 'String', sprintf('Rack displacement: %6.1f mm', steering_range(steer_step)));
        end
    
        function update_plot(wheel_step, steer_step)
            update_axes(ax1, h_points1, h_texts1, h_lines1, wheel_step, steer_step, [30 30 30], Collision);
            update_axes(ax2, h_points2, h_texts2, h_lines2, wheel_step, steer_step, [30 30 0], Collision); 
            update_axes(ax3, h_points3, h_texts3, h_lines3, wheel_step, steer_step, [30 0 30], Collision);
            update_axes(ax4, h_points4, h_texts4, h_lines4, wheel_step, steer_step, [0 30 30], Collision);
            update_status(wheel_step, steer_step, true);

            space = '    ';
            fprintf('Wheel Travel                           : %.1f mm\n', wheel_travel_range(wheel_step));
            fprintf('Rack Displacement                 : %.1f mm\n', steering_range(steer_step));
            for i = 1:length(points)
                pos = squeeze(positions_history(i, :, wheel_step, steer_step));
                fprintf('%-32s%s : [%.3f, %.3f, %.3f]\n', points(i).name, space, pos(1), pos(2), pos(3));
            end
            pos_center = squeeze(positions_history(15, :, wheel_step, steer_step));
            pos_upper = pos_center + [0, 0, wheel_radius];
            pos_lower = pos_center + [0, 0, -wheel_radius];
            pos_left = pos_center + [-wheel_radius, 0, 0];
            pos_right = pos_center + [wheel_radius, 0, 0];
            camber_rel = camber_history(wheel_step, steer_step) - camber_history(zero_wheel_step, zero_steer_step);
            toe_rel    = toe_history(wheel_step, steer_step)    - toe_history(zero_wheel_step, zero_steer_step);
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel upper', pos_upper(1), pos_upper(2), pos_upper(3));
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel lower', pos_lower(1), pos_lower(2), pos_lower(3));
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel left', pos_left(1), pos_left(2), pos_left(3));
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel right', pos_right(1), pos_right(2), pos_right(3)); 
            fprintf('Camber angle                         : %.4f °\n', -camber_rel);
            fprintf('Toe angle                                : %.4f °\n', toe_rel);
            trail_rel  = mechanical_trail_history(wheel_step, steer_step) - mechanical_trail_history(zero_wheel_step, zero_steer_step);
            caster_rel = caster_history(wheel_step, steer_step) - caster_history(zero_wheel_step, zero_steer_step);
            scrub_rel  = scrub_radius_history(wheel_step, steer_step) - scrub_radius_history(zero_wheel_step, zero_steer_step);
            kpi_rel    = kpi_history(wheel_step, steer_step) - kpi_history(zero_wheel_step, zero_steer_step);
            
            fprintf('Mechanical trail change              : %.4f mm\n', trail_rel);
            fprintf('Caster angle change                  : %.4f °\n', caster_rel);
            fprintf('Scrub radius change                  : %.4f mm\n', scrub_rel);
            fprintf('KPI change                           : %.4f °\n', kpi_rel);
            fprintf('------------------------------------\n');
        end

        function [hit, reasons, dd, C_pts, K_pts, WC_pos, unit_normal] = pose_collision(wheel_step, steer_step)
            pp = positions_history(:, :, wheel_step, steer_step);
            C_pts  = pp([1 2 4 5 7 9], :);      
            K_pts  = pp([3 3 6 6 8 10], :);     
            WC_pos = pp(15, :);
            Rw = squeeze(R_history(wheel_step, steer_step, :, :));
            unit_normal = Rw * Collision.wheel_axis0(:);
            unit_normal = unit_normal / norm(unit_normal);
            [hit, reasons, dd] = col_check_pose(C_pts, K_pts, WC_pos, unit_normal, Collision);
        end

        function update_status(wheel_step, steer_step, verbose)
            [hit, reasons, dd] = pose_collision(wheel_step, steer_step);
            rod_nm = col_rod_names(Collision, numel(hit));
            if verbose
                for ii_s = 1:numel(hit)
                    if hit(ii_s), mark_str = '  <-- PIROS'; else, mark_str = ''; end
                    fprintf('%-18s szabad távolság: rúd %7.1f | motor %7.1f | felni %7.1f mm (min. %.1f)%s\n', ...
                        rod_nm{ii_s}, dd.rod(ii_s), dd.motor(ii_s), dd.rim(ii_s), Collision.min_clearance, mark_str);
                end
            end
            if any(hit)
                st = sprintf('ÜTKÖZÉS (Z = %.1f mm, rack = %.1f mm): %s', wheel_travel_range(wheel_step), ...
                    steering_range(steer_step), col_pose_string(hit, reasons, Collision));
                bg = [1 0.55 0.55];
                if verbose, fprintf('  → PIROS: %s\n', col_pose_string(hit, reasons, Collision)); end
            else
                st = sprintf('Nincs ütközés (Z = %.1f mm, rack = %.1f mm) – minden rúd kék', ...
                    wheel_travel_range(wheel_step), steering_range(steer_step));
                bg = [0.6 0.9 0.6];
            end
            set(h_status_pose, 'String', st, 'BackgroundColor', bg);
            if isgraphics(h_status_pose2), set(h_status_pose2, 'String', st, 'BackgroundColor', bg); end
        end

        function update_axes(ax, h_points, h_texts, h_lines, wheel_step, steer_step, label_offset, Collision)
            cla(ax);
            hold(ax, 'on');

            [X, Y] = meshgrid(linspace(vis_lims(1,1), vis_lims(1,2), 40), linspace(vis_lims(2,1), vis_lims(2,2), 40));
            Z = -0 * ones(size(X));
            h_floor = surf(ax, X, Y, Z, 'FaceColor', [0.92 0.94 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.45, 'FaceLighting', 'gouraud');
            set(h_floor, 'HandleVisibility', 'off');
            uistack(h_floor, 'bottom');    

            light('Parent', ax, 'Position', [1 1 1], 'Style', 'infinite');
            light('Parent', ax, 'Position', [-1 -1 1], 'Style', 'infinite');

            p = zeros(length(points), 3);
            for i = 1:length(points)
                pos = squeeze(positions_history(i, :, wheel_step, steer_step));
                p(i, :) = pos; 
                
                if ishandle(h_points(i))
                    set(h_points(i), 'XData', pos(1), 'YData', pos(2), 'ZData', pos(3));
                else
                    h_points(i) = plot3(ax, pos(1), pos(2), pos(3), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
                end
            end

            [hit, ~, ~, C_pts, K_pts, WC_pos, unit_normal] = pose_collision(wheel_step, steer_step);
            un_row = unit_normal(:)';

            if Collision.use_motor
                motor_c = WC_pos + Collision.motor_y_offset * un_row;
                draw_cylinder_custom(ax, motor_c, un_row, Collision.motor_radius, Collision.motor_length, [0.4 0.4 0.4], 0.6);
            end
            rim_center = WC_pos + Collision.rim_y_offset * un_row;
            draw_cylinder_custom(ax, rim_center, un_row, Collision.rim_inner_radius, Collision.rim_width, [0.7 0.7 0.7], 0.4);

            radii = Collision.rod_diameter(:)' / 2;   
            for i = 1:size(C_pts, 1)
                if hit(i)
                    rod_color = [1 0 0];
                else
                    rod_color = [0.2 0.6 1.0];
                end
                draw_rod(ax, C_pts(i,:), K_pts(i,:), radii(i), rod_color, 1.0);
            end

            main_pairs = [1 3; 2 3; 4 6; 5 6; 7 8; 9 10];  
            for p_idx = 1:size(line_pairs,1)
                idx1 = line_pairs{p_idx,1}(1);
                idx2 = line_pairs{p_idx,1}(2);

                is_main = false;
                for m = 1:size(main_pairs,1)
                    if (idx1 == main_pairs(m,1) && idx2 == main_pairs(m,2)) || ...
                       (idx1 == main_pairs(m,2) && idx2 == main_pairs(m,1))
                        is_main = true;
                        break;
                    end
                end

                if ~is_main
                    pos1 = p(idx1, :);
                    pos2 = p(idx2, :);
                    col  = line_pairs{p_idx,2};
                    rad  = line_pairs{p_idx,3} / 2;   
                    if rad < 1.5
                        rad = 4;  
                    end
                    draw_rod(ax, pos1, pos2, rad, col, 0.95);
                end
            end

            draw_tire(ax, WC_pos, unit_normal, [], []);
        end
    
        function wheel_slider2_callback(src, ~)
            wheel_step = round(get(src, 'Value'));
            set(src, 'Value', wheel_step);
            steer_step = round(get(steer_slider2, 'Value'));
            update_diagram(wheel_step, steer_step);
            update_plot(wheel_step, steer_step);    
            set(travel_text2,'String',sprintf('Wheel travel:\n%6.1f mm',wheel_travel_range(wheel_step)));
        end

        function steer_slider2_callback(src, ~)
            steer_step = round(get(src, 'Value'));
            set(src, 'Value', steer_step);
            wheel_step = round(get(wheel_slider2, 'Value'));
            update_diagram(wheel_step, steer_step);
            update_plot(wheel_step, steer_step);    
            set(steer_text2,'String',sprintf('Rack displacement:\n%6.1f mm',steering_range(steer_step)));
        end

        function update_diagram(wheel_step, steer_step)

            wt = wheel_travel_range(wheel_step);
    
            % Fig2
            toe_rel = toe_history(:, steer_step) - toe_history(zero_wheel_step, zero_steer_step);
            camber_rel = -1 * (camber_history(:, steer_step) - camber_history(zero_wheel_step, zero_steer_step));
            contact_patch_x_rel = contact_patch_x_history(:, steer_step) - contact_patch_x_history(zero_wheel_step, zero_steer_step);
            contact_patch_y_rel = contact_patch_y_history(:, steer_step) - contact_patch_y_history(zero_wheel_step, zero_steer_step);
            contact_patch_z_rel = contact_patch_z_history(:, steer_step) - contact_patch_z_history(zero_wheel_step, zero_steer_step);
            front_vsa_abs = front_vsa_history(:, steer_step);
            side_vsa_abs = side_vsa_history(:, steer_step);

            toe_current = toe_rel(wheel_step);
            camber_current = camber_rel(wheel_step);
            contact_patch_x_current = contact_patch_x_history(wheel_step, steer_step);
            contact_patch_y_current = contact_patch_y_history(wheel_step, steer_step);
            contact_patch_z_current = contact_patch_z_history(wheel_step, steer_step);
            front_vsa_current = front_vsa_abs(wheel_step);
            side_vsa_current = side_vsa_abs(wheel_step);

            set(h_toe_curve,   'YData', toe_rel);
            col_idx = collision_map(:, steer_step);
            set(h_toe_collision, 'XData', wheel_travel_range(col_idx), 'YData', toe_rel(col_idx));
            set(h_camber_curve, 'YData', camber_rel);
            set(h_contact_patch_x_curve, 'YData', contact_patch_x_rel);
            set(h_contact_patch_y_curve, 'YData', contact_patch_y_rel);
            set(h_contact_patch_z_curve, 'YData', contact_patch_z_rel);
            set(h_front_vsa_curve, 'YData', front_vsa_abs);
            set(h_side_vsa_curve, 'YData', side_vsa_abs);
            
            set(h_point_toe,   'XData', wt, 'YData', toe_rel(wheel_step));
            set(h_point_camber, 'XData', wt, 'YData', camber_rel(wheel_step));
            set(h_point_contact_patch_x, 'XData', wt, 'YData', contact_patch_x_rel(wheel_step));
            set(h_point_contact_patch_y, 'XData', wt, 'YData', contact_patch_y_rel(wheel_step));
            set(h_point_contact_patch_z, 'XData', wt, 'YData', contact_patch_z_rel(wheel_step));
            set(h_point_front_vsa, 'XData', wt, 'YData', front_vsa_abs(wheel_step));
            set(h_point_side_vsa, 'XData', wt, 'YData', side_vsa_abs(wheel_step));

            legend(ax_toe, sprintf('Toe = %.3f°', toe_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_camber, sprintf('Camber = %.3f°', camber_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_contact_patch, sprintf('X  = %.3f mm', contact_patch_x_current), sprintf('Y  = %.3f mm', contact_patch_y_current), sprintf('Z  = %.3f mm', contact_patch_z_current), 'Location','best', 'FontSize', 12, 'Box','on');
            legend(ax_vsa, sprintf('Front VSA = %.3f mm', front_vsa_current), sprintf('Side VSA  = %.3f mm', side_vsa_current), 'Location','best', 'FontSize',12, 'Box','on');
            
            ylim(ax_toe, [min(toe_rel)-1 max(toe_rel)+1]);
            ylim(ax_camber, [min(camber_rel)-1 max(camber_rel)+1]);
            ylim(ax_contact_patch, [min(contact_patch_y_rel)-1 max(contact_patch_y_rel)+1]);

            % Fig3
            trail_abs = mechanical_trail_history(:, steer_step);
            caster_abs = caster_history(:, steer_step);
            scrub_abs = scrub_radius_history(:, steer_step);
            kpi_abs = kpi_history(:, steer_step);

            trail_current = trail_abs(wheel_step);
            caster_current = caster_abs(wheel_step);
            scrub_current = scrub_abs(wheel_step);
            kpi_current = kpi_abs(wheel_step);

            set(h_trail_curve, 'YData', trail_abs);
            set(h_caster_curve, 'YData', caster_abs);
            set(h_scrub_curve, 'YData', scrub_abs);
            set(h_kpi_curve, 'YData', kpi_abs);

            set(h_point_trail, 'XData', wt, 'YData', trail_abs(wheel_step));
            set(h_point_caster, 'XData', wt, 'YData', caster_abs(wheel_step));
            set(h_point_scrub, 'XData', wt, 'YData', scrub_abs(wheel_step));
            set(h_point_kpi, 'XData', wt, 'YData', kpi_abs(wheel_step));

            legend(ax_trail, sprintf('Mechanical Trail = %.3f mm', trail_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_caster, sprintf('Caster Angle = %.3f°', caster_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_scrub, sprintf('Scrub Radius = %.3f mm', scrub_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_kpi, sprintf('KPI = %.3f°', kpi_current), 'Location','best', 'FontSize', 12, 'Box','on');

            ylim(ax_trail,  [min(trail_abs)-5  max(trail_abs)+5]);
            ylim(ax_caster, [min(caster_abs)-1 max(caster_abs)+1]);
            ylim(ax_scrub,  [min(scrub_abs)-5  max(scrub_abs)+5]);
            ylim(ax_kpi, [min(kpi_abs)-1 max(kpi_abs)+1]);

            % Fig4 (Damper Length & Damper MR - ARB részek eltávolítva)
            damper_length_abs = damper_length_history(:, steer_step);
            damper_MR_abs = damper_MR_history(:, steer_step);

            damper_length_current = damper_length_abs(wheel_step);
            damper_MR_current = damper_MR_abs(wheel_step);

            set(h_damper_length_curve, 'YData', damper_length_abs);
            set(h_damper_MR_curve, 'YData', damper_MR_abs);

            set(h_point_damper_length,  'XData', wt, 'YData', damper_length_abs(wheel_step));
            set(h_point_damper_MR, 'XData', wt, 'YData', damper_MR_abs(wheel_step));

            legend(ax_damper_length, sprintf('Damper Length = %.3f mm', damper_length_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_damper_MR, sprintf('Damper MR = %.3f -', damper_MR_current), 'Location','best', 'FontSize',12, 'Box','on');

            ylim(ax_damper_length, [min(damper_length_abs)-5  max(damper_length_abs)+5]);
            ylim(ax_damper_MR, [min(damper_MR_abs)-1 max(damper_MR_abs)+1]);

            % Fig5
            front_IC_x_rel = front_ic_history(:, steer_step, 1) - front_ic_history(zero_wheel_step, zero_steer_step, 1);
            front_IC_y_rel = front_ic_history(:, steer_step, 2) - front_ic_history(zero_wheel_step, zero_steer_step, 2);
            front_IC_z_rel = front_ic_history(:, steer_step, 3) - front_ic_history(zero_wheel_step, zero_steer_step, 3);
            side_IC_x_rel = side_ic_history(:, steer_step, 1) - side_ic_history(zero_wheel_step, zero_steer_step, 1);
            side_IC_y_rel = side_ic_history(:, steer_step, 2) - side_ic_history(zero_wheel_step, zero_steer_step, 2);
            side_IC_z_rel = side_ic_history(:, steer_step, 3) - side_ic_history(zero_wheel_step, zero_steer_step, 3);
            half_track_abs = half_track_history(:, steer_step);
            ride_height_abs = ride_height_history(:, steer_step);

            front_IC_x_current = front_ic_history(wheel_step, steer_step, 1);
            front_IC_y_current = front_ic_history(wheel_step, steer_step, 2);
            front_IC_z_current = front_ic_history(wheel_step, steer_step, 3);
            side_IC_x_current = side_ic_history(wheel_step, steer_step, 1);
            side_IC_y_current = side_ic_history(wheel_step, steer_step, 2);
            side_IC_z_current = side_ic_history(wheel_step, steer_step, 3);
            half_track_current = half_track_abs(wheel_step);
            ride_height_current = ride_height_abs(wheel_step);

            set(h_front_IC_x_curve, 'YData', front_IC_x_rel);
            set(h_front_IC_y_curve, 'YData', front_IC_y_rel);
            set(h_front_IC_z_curve, 'YData', front_IC_z_rel);
            set(h_side_IC_x_curve, 'YData', side_IC_x_rel);
            set(h_side_IC_y_curve, 'YData', side_IC_y_rel);
            set(h_side_IC_z_curve, 'YData', side_IC_z_rel);
            set(h_half_track_curve, 'YData', half_track_abs);
            set(h_ride_height_curve, 'YData', ride_height_abs);
            
            set(h_point_front_IC_x, 'XData', wt, 'YData', front_IC_x_rel(wheel_step));
            set(h_point_front_IC_y, 'XData', wt, 'YData', front_IC_y_rel(wheel_step));
            set(h_point_front_IC_z, 'XData', wt, 'YData', front_IC_z_rel(wheel_step));
            set(h_point_side_IC_x, 'XData', wt, 'YData', side_IC_x_rel(wheel_step));
            set(h_point_side_IC_y, 'XData', wt, 'YData', side_IC_y_rel(wheel_step));
            set(h_point_side_IC_z, 'XData', wt, 'YData', side_IC_z_rel(wheel_step));           
            set(h_point_half_track, 'XData', wt, 'YData', half_track_abs(wheel_step));
            set(h_point_ride_height, 'XData', wt, 'YData', ride_height_abs(wheel_step));

            legend(ax_front_IC, sprintf('X  = %.3f mm', front_IC_x_current), sprintf('Y  = %.3f mm', front_IC_y_current), sprintf('Z  = %.3f mm', front_IC_z_current), 'Location','best', 'FontSize', 12, 'Box','on');
            legend(ax_side_IC, sprintf('X  = %.3f mm', side_IC_x_current), sprintf('Y  = %.3f mm', side_IC_y_current), sprintf('Z  = %.3f mm', side_IC_z_current), 'Location','best', 'FontSize', 12, 'Box','on');
            legend(ax_half_track, sprintf('Half Track = %.3f mm', half_track_current), 'Location','best', 'FontSize', 12, 'Box','on');
            legend(ax_ride_height, sprintf('Ride Height = %.3f mm', ride_height_current), 'Location','best', 'FontSize',12, 'Box','on');
            
            ylim(ax_front_IC, [min(front_IC_y_rel)-1 max(front_IC_y_rel)+1]);
            ylim(ax_side_IC, [min(side_IC_z_rel)-1 max(side_IC_z_rel)+1]);
            ylim(ax_half_track, [min(half_track_abs)-1 max(half_track_abs)+1]);
            ylim(ax_ride_height, [min(ride_height_abs)-1 max(ride_height_abs)+1]);

            % Fig6 – Anti-dive & Phi_F
            anti_dive_abs = anti_dive_history(:, steer_step);
            phi_F_abs     = phi_F_history(:, steer_step);
            anti_dive_current = anti_dive_abs(wheel_step);
            phi_F_current     = phi_F_abs(wheel_step);

            set(h_anti_dive_curve, 'YData', anti_dive_abs);
            set(h_phi_F_curve,     'YData', phi_F_abs);
            set(h_point_anti_dive, 'XData', wt, 'YData', anti_dive_current);
            set(h_point_phi_F,     'XData', wt, 'YData', phi_F_current);

            legend(ax_anti_dive, sprintf('Anti-Dive = %.2f %%', anti_dive_current), ...
                   'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_phi_F, sprintf('\\Phi_F = %.3f °', phi_F_current), ...
                   'Location','best', 'FontSize',12, 'Box','on');

            ylim(ax_anti_dive, [min(anti_dive_abs)-5, max(anti_dive_abs)+5]);
            ylim(ax_phi_F,     [min(phi_F_abs)-2,     max(phi_F_abs)+2]);

            drawnow;
        end

    function h = draw_cylinder_custom(ax, center, axis_vec, radius, length, color, alpha)
        u = axis_vec / norm(axis_vec);
        if abs(u(3)) < 0.999
            v = cross([0 0 1], u);
        else
            v = cross([1 0 0], u);
        end
        v = v / norm(v);
        w = cross(u, v);

        [xc, yc, zc] = cylinder(radius * [1 1], 24);
        zc = (zc - 0.5) * length; 

        X = center(1) + xc.*v(1) + yc.*w(1) + zc.*u(1);
        Y = center(2) + xc.*v(2) + yc.*w(2) + zc.*u(2);
        Z = center(3) + xc.*v(3) + yc.*w(3) + zc.*u(3);

        h = surf(ax, X, Y, Z, 'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', alpha, 'FaceLighting', 'gouraud');
    end

    %% 3x3 EREDMÉNY MÁTRIX EXPORTÁLÁSA EXCELBE
    xl_file       = 'Front_Left_DAA_3x3.xlsx';
    xl_zero_w     = zero_wheel_step;
    xl_zero_s     = zero_steer_step;
    xl_steer_idx  = [1, zero_steer_step, num_steer_steps];    
    xl_travel_idx = [num_wheel_steps, zero_wheel_step, 1];    
    xl_steer_lbl  = {'right steer', 'static', 'left steer'};
    xl_col_lbl    = {'compression', 'static', 'rebound'};
    xl_par_lbl    = {'toe', 'camber', 'kpi', 'caster', 'kpi trail', 'caster trail'};
    xl_par_unit   = {'°', '°', '°', '°', ' mm', ' mm'};
    xl_par_data   = {toe_history - toe_history(xl_zero_w, xl_zero_s), ...
                     -(camber_history(:,:,1) - camber_history(xl_zero_w, xl_zero_s)), ...
                     kpi_history, caster_history, scrub_radius_history, mechanical_trail_history};

    xl_out = cell(21, 12);
    for xl_k = 1:3
        xl_out{1, 2 + xl_k} = xl_col_lbl{xl_k};    
        xl_out{1, 9 + xl_k} = xl_col_lbl{xl_k};    
    end
    for xl_b = 1:3
        xl_r0 = 2 + (xl_b - 1) * 7;                
        xl_out{xl_r0, 1} = xl_steer_lbl{xl_b};
        xl_out{xl_r0, 8} = xl_steer_lbl{xl_b};
        for xl_p = 1:6
            xl_row = xl_r0 + xl_p - 1;
            xl_out{xl_row, 2} = xl_par_lbl{xl_p};
            xl_out{xl_row, 9} = xl_par_lbl{xl_p};
            for xl_c = 1:3
                xl_val = xl_par_data{xl_p}(xl_travel_idx(xl_c), xl_steer_idx(xl_b));
                xl_val = round(xl_val * 1000) / 1000;
                if xl_val == 0
                    xl_out{xl_row, 2 + xl_c} = ['0', xl_par_unit{xl_p}];
                else
                    xl_out{xl_row, 2 + xl_c} = sprintf('%.3f%s', xl_val, xl_par_unit{xl_p});
                end
            end
        end
    end

    try
        writecell(xl_out, xl_file, 'Sheet', 'Munka1', 'Range', 'A1');
        disp(['3x3 eredmény mátrix exportálva: ', xl_file]);
    catch xl_err
        warning('Az Excel export nem sikerült: %s', xl_err.message);
    end

end 

%% =====================================================================
%% LOKÁLIS SEGÉDFÜGGVÉNYEK – VIZUALIZÁCIÓ
%% =====================================================================

function L = calc_vis_limits(positions_history, WC, R_tyre)
    P = reshape(permute(positions_history, [2 1 3 4]), 3, [])';
    P = P(all(isfinite(P), 2) & any(P ~= 0, 2), :);
    WC = WC(:)';
    lo = min([P; WC - R_tyre - 60], [], 1);
    hi = max([P; WC + R_tyre + 60], [], 1);
    lo(3) = min(lo(3), -50);
    L = [lo(:), hi(:)];
end

%% =====================================================================
%% ÜTKÖZÉS-ELLENŐRZÉS
%% =====================================================================

function [hit, reasons, dd] = col_check_pose(C_pts, K_pts, WC, unit_normal, Col)
    n = size(C_pts, 1);
    radii = Col.rod_diameter(:) / 2;
    if numel(radii) < n, radii = [radii; repmat(radii(end), n - numel(radii), 1)]; end
    gap = Col.min_clearance;
    names = col_rod_names(Col, n);
    hit = false(n, 1);
    reasons = cell(n, 1);
    for i = 1:n, reasons{i} = {}; end
    dd.rod = inf(n, 1); dd.motor = inf(n, 1); dd.rim = inf(n, 1);
    ax_n = unit_normal(:) / (norm(unit_normal) + 1e-15);

    for i = 1:n
        for j = i+1:n
            if col_is_skipped(i, j, Col), continue; end
            if col_share_end(C_pts(i,:), K_pts(i,:), C_pts(j,:), K_pts(j,:)), continue; end
            d = col_seg_seg(C_pts(i,:), K_pts(i,:), C_pts(j,:), K_pts(j,:)) - radii(i) - radii(j);
            dd.rod(i) = min(dd.rod(i), d);
            dd.rod(j) = min(dd.rod(j), d);
            if d < gap
                hit(i) = true; hit(j) = true;
                reasons{i}{end+1} = sprintf('%s (%.1f mm)', names{j}, d);
                reasons{j}{end+1} = sprintf('%s (%.1f mm)', names{i}, d);
            end
        end
    end

    if ~isfield(Col, 'use_motor') || Col.use_motor
        mc = WC(:) + Col.motor_y_offset * ax_n;
        for i = 1:n
            d = col_seg_cyl(C_pts(i,:), K_pts(i,:), mc, ax_n, Col.motor_radius, Col.motor_length) - radii(i);
            dd.motor(i) = d;
            if d < gap
                hit(i) = true;
                reasons{i}{end+1} = sprintf('Motor (%.1f mm)', d);
            end
        end
    end

    rc = WC(:) + Col.rim_y_offset * ax_n;
    for i = 1:n
        d = f1_seg_rim_dist(C_pts(i,:), K_pts(i,:), rc, ax_n, Col.rim_inner_radius, ...
            Col.rim_outer_radius, Col.rim_width / 2) - radii(i);
        dd.rim(i) = d;
        if d < gap
            hit(i) = true;
            reasons{i}{end+1} = sprintf('Felni (%.1f mm)', d);
        end
    end
end

function names = col_rod_names(Col, n)
    if isfield(Col, 'rod_names') && numel(Col.rod_names) >= n
        names = Col.rod_names(1:n);
    else
        names = arrayfun(@(k) sprintf('Rúd %d', k), 1:n, 'UniformOutput', false);
    end
end

function tf = col_is_skipped(i, j, Col)
    tf = false;
    if ~isfield(Col, 'skip_pairs') || isempty(Col.skip_pairs), return; end
    sp = Col.skip_pairs;
    tf = any((sp(:,1) == i & sp(:,2) == j) | (sp(:,1) == j & sp(:,2) == i));
end

function tf = col_share_end(Ci, Ki, Cj, Kj)
    tf = (norm(Ci - Cj) < 1e-6) || (norm(Ki - Kj) < 1e-6) || (norm(Ci - Kj) < 1e-6) || (norm(Ki - Cj) < 1e-6);
end

function s = col_pose_string(hit, reasons, Col)
    names = col_rod_names(Col, numel(hit));
    parts = {};
    for i = find(hit(:))'
        parts{end+1} = sprintf('%s: %s', names{i}, strjoin(reasons{i}, ', ')); 
    end
    s = strjoin(parts, ' | ');
end

function d = col_seg_seg(p1, q1, p2, q2)
    p1 = p1(:); q1 = q1(:); p2 = p2(:); q2 = q2(:);
    u = q1 - p1; v = q2 - p2; w0 = p1 - p2;
    a = dot(u,u); b = dot(u,v); c = dot(v,v);
    d_ = dot(u,w0); e = dot(v,w0);
    D = a*c - b*b;
    if D < 1e-12
        sc = 0; tc = 0; if c > 1e-12, tc = e/c; end
    else
        sc = (b*e - c*d_) / D; tc = (a*e - b*d_) / D;
    end
    sc = min(1, max(0, sc)); tc = min(1, max(0, tc));
    d = norm(w0 + sc*u - tc*v);
end

function d = col_seg_cyl(p0, p1, c_center, c_axis, radius, height)
    p0 = p0(:); p1 = p1(:); c_center = c_center(:); c_axis = c_axis(:) / (norm(c_axis) + 1e-15);
    d = inf; half_h = height / 2;
    for k = 0:60
        p = p0 + (k/60) * (p1 - p0); w = p - c_center;
        axial = dot(w, c_axis); radial = norm(w - axial * c_axis);
        a = radial - radius; b = abs(axial) - half_h;
        d = min(d, norm([max(a, 0), max(b, 0)]) + min(max(a, b), 0));
    end
end

%% =====================================================================
%% F1 2026 – ÖSSZESÍTŐ SEGÉDFÜGGVÉNYEK
%% =====================================================================

function [ok, failed] = f1_rules_status(names, vals)
    ok = true; failed = {};
    for i = 1:numel(names)
        v = vals{i};
        if ~isempty(v) && max(v) > 1e-3
            ok = false;
            failed{end+1} = strtok(names{i}); 
        end
    end
end

function [ok, failed] = f1_static_wheel_status(WC, F1)
    ok = true; failed = {};
    if ~F1.Enable, return; end
    n0  = f1_wheel_axes(F1);
    O   = f1_wcs_origin(WC, n0, F1);
    zF1 = O(3) - F1.RefPlaneZ;
    if abs(O(2)) > F1.WCS_Ymax + 1e-6, ok = false; failed{end+1} = 'C10.10.1 (nyomtáv)'; end
    if zF1 < F1.WCS_Zrange(1) || zF1 > F1.WCS_Zrange(2), ok = false; failed{end+1} = 'C10.1c (WCS Z)'; end
end

function ok = f1_outboard_ok(P, WC, F1, on_member)
    ok = true;
    if ~F1.Enable, return; end
    [n0, zw0] = f1_wheel_axes(F1);
    [yw, zw, r] = f1_wcs_coords(P(:)', WC, n0, zw0, F1);
    if on_member
        ok = yw <= F1.PushrodExcYWmax;
    else
        ok = (yw <= F1.OutboardYWmax) && (zw >= F1.OutboardZWmin);
        if F1.Drum.Enable
            ok = ok && r <= F1.Drum.Radius && yw >= F1.Drum.YW(1) && yw <= F1.Drum.YW(2);
        end
    end
end

function err = f1_link_errors(q, C_curr, K_loc, WC_init, dz, L0)
    WC_current = [q(1), q(2), WC_init(3) + dz];
    R = f1_euler_rot(q(3), q(4), q(5));
    err = zeros(size(K_loc, 1), 1);
    for i = 1:size(K_loc, 1)
        K_current = WC_current' + R * K_loc(i,:)';
        err(i) = norm(K_current' - C_curr(i,:)) - L0(i);
    end
end

function R = f1_euler_rot(rx, ry, rz)
    Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
    Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
    Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
    R = Rz * Ry * Rx;
end

%% =====================================================================
%% F1 2026 SZABÁLYZAT (Section C10)
%% =====================================================================

function F1 = f1_rules_2026(axle)
    axle = lower(strtrim(axle));
    F1.Enable  = true;
    F1.Axle    = axle;
    F1.IsFront = strcmp(axle, 'front');

    if F1.IsFront
        % F1.LegalCamber    = -3;  
        F1.LegalCamber    = 0; 
        F1.WCS_Zrange     = [290 320];    
        F1.WCS_Ymax       = 603;          
        F1.OutboardZWmin  = -100;         
        F1.TyreRadius     = 705/2;        
        F1.Rim.MountWidth = 315;          
        F1.Rim.Width      = 334;          
        F1.RefPlaneZ      = 45;           
    else
        % F1.LegalCamber    = -1;
        F1.LegalCamber    = 0;
        F1.WCS_Zrange     = [225 285];
        F1.WCS_Ymax       = 525;
        F1.OutboardZWmin  = -40;
        F1.TyreRadius     = 710/2;        
        F1.Rim.MountWidth = 401.3;
        F1.Rim.Width      = 420.3;
        F1.RefPlaneZ      = 95;           
    end
    F1.Rim.InboardLip   = 10.5;           
    F1.Rim.OutboardLip  = 8.5;            
    F1.WC_YW            = -(F1.Rim.InboardLip + F1.Rim.MountWidth/2);  
    F1.Rim.OuterRadius  = 496/2;          
    F1.Rim.BeadRadius   = 462.5/2;        
    F1.Rim.MinThickness = 2.5;            
    F1.Rim.InnerRadius  = 215;            
    F1.Rim.CenterOffset = F1.Rim.Width/2 + F1.WC_YW;   

    F1.OutboardYWmax = 0;                 
    F1.Drum.Enable = false;               
    F1.Drum.Radius = NaN;                 
    F1.Drum.YW     = [NaN NaN];           

    F1.ZWgradMax         = 1;             
    F1.ZWgradWindow      = 10;            
    F1.IncidenceHeaveMax = 5;             
    F1.IncidenceSteerMax = 1;             
    F1.CheckDz    = -30:5:30;             
    F1.NoMountBox = [];                   

    F1.PairMinDX      = 300;              
    F1.PairMinZ       = 250;              
    F1.JackAngle      = 12;               
    F1.JackMax        = 2;                
    F1.LockToeIn      = 23;               
    F1.LockToeOut     = 21;               
    F1.MaxRackTravel  = Inf;              
    F1.SteerCheckRack = 30;               

    F1.PushrodOnMember       = true;     
    F1.PushrodExcYWmax       = 50;        
    F1.PushrodExcLineDist    = 25;        
    F1.CheckPushrodIncidence = true;      
end

function [n0, zw0] = f1_wheel_axes(F1)
    phi = -deg2rad(F1.LegalCamber);
    n0  = [0;  cos(phi); sin(phi)];
    zw0 = [0; -sin(phi); cos(phi)];
end

function O = f1_wcs_origin(WC, n, F1)
    O = WC(:) + F1.WC_YW * n(:);
end

function [yw, zw, r] = f1_wcs_coords(P, WC, n, zw_ax, F1)
    O  = f1_wcs_origin(WC, n, F1)';
    D  = P - O;
    yw = -D * n(:);
    zw =  D * zw_ax(:);
    r  = sqrt(max(sum(D.^2, 2) - yw.^2, 0));
end

function f1_check_wheel_static(WC, F1, label)
    if ~F1.Enable, return; end
    n0  = f1_wheel_axes(F1);
    O   = f1_wcs_origin(WC, n0, F1);
    zF1 = O(3) - F1.RefPlaneZ;
    fprintf('[F1 %s] WCS origó: |Y| = %.1f mm (max %g) | Z_F1 = %.1f mm (%g..%g) | WC Z = %.1f mm (gumi sugár %.1f)\n', ...
        label, abs(O(2)), F1.WCS_Ymax, zF1, F1.WCS_Zrange(1), F1.WCS_Zrange(2), WC(3), F1.TyreRadius);
    if abs(O(2)) > F1.WCS_Ymax + 1e-6
        warning('F1 C10.10.1: a WCS origó |Y| = %.1f > %g mm!', abs(O(2)), F1.WCS_Ymax);
    end
    if zF1 < F1.WCS_Zrange(1) || zF1 > F1.WCS_Zrange(2)
        warning('F1 C10.1c: a WCS origó Z_F1 = %.1f mm, kívül esik a %g..%g tartományon!', ...
            zF1, F1.WCS_Zrange(1), F1.WCS_Zrange(2));
    end
end

function f1_check_outboard_point(P, WC, F1, label, on_member)
    if ~F1.Enable, return; end
    [n0, zw0] = f1_wheel_axes(F1);
    [yw, zw, r] = f1_wcs_coords(P(:)', WC, n0, zw0, F1);
    if on_member
        fprintf('[F1] %s: YW = %.1f mm (C10.3.4d: <= %g)\n', label, yw, F1.PushrodExcYWmax);
        if yw > F1.PushrodExcYWmax
            warning('F1 C10.3.4d: %s túl beljebb van!', label);
        end
    else
        fprintf('[F1] %s: YW = %.1f mm (<= %g), ZW = %.1f mm (>= %g), r = %.1f mm\n', ...
            label, yw, F1.OutboardYWmax, zw, F1.OutboardZWmin, r);
        if yw > F1.OutboardYWmax, warning('F1 C10.3.4a: %s YW = %.1f > %g mm!', label, yw, F1.OutboardYWmax); end
        if zw < F1.OutboardZWmin, warning('F1 C10.3.4b: %s ZW = %.1f < %g mm!', label, zw, F1.OutboardZWmin); end
    end
end

function R = f1_axis_rot(a, t)
    a = a(:) / norm(a);
    W = [0 -a(3) a(2); a(3) 0 -a(1); -a(2) a(1) 0];
    R = eye(3) + sin(t) * W + (1 - cos(t)) * (W * W);
end

function R = f1_rot_between(u, v)
    u = u(:) / norm(u); v = v(:) / norm(v);
    w = cross(u, v); s = norm(w); c = u' * v;
    if s < 1e-12, R = eye(3); return; end
    W = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
    R = eye(3) + W + W * W * ((1 - c) / s^2);
end

function t = f1_signed_angle(v0, v1, a)
    a  = a(:) / norm(a);
    v0 = v0(:) - a * (a' * v0(:));
    v1 = v1(:) - a * (a' * v1(:));
    t  = atan2(a' * cross(v0, v1), v0' * v1);
end

function m0 = f1_major_axis0(L)
    m0 = cross(L(:), [0; 0; 1]);
    if norm(m0) < 1e-9, m0 = [1; 0; 0]; end
    m0 = m0 / norm(m0);
end

function a = f1_incidence(m)
    a = asind(max(-1, min(1, m(3) / norm(m))));
end

function d = f1_seg_rim_dist(p0, p1, center, axis, r_in, r_out, half_w)
    p0 = p0(:); p1 = p1(:); center = center(:); axis = axis(:) / norm(axis);
    d = inf;
    for k = 0:60
        pt = p0 + (k/60) * (p1 - p0); w = pt - center;
        ax = axis' * w; rad = norm(w - ax * axis);
        a = max(r_in - rad, rad - r_out); b = abs(ax) - half_w;
        d = min(d, norm([max(a, 0), max(b, 0)]) + min(max(a, b), 0));
    end
end

function s = f1_box_sdf(P, box)
    q = max(box(:,1)' - P(:)', P(:)' - box(:,2)');
    s = norm(max(q, 0)) + min(max(q), 0);
end

function [names, vals] = f1_add(names, vals, name, v)
    names{end+1} = name; vals{end+1} = v(:);
end

function f1_report(names, vals, label)
    fprintf('\n===== F1 2026 C10 megfelelőség: %s =====\n', label);
    if isempty(names), disp('  (F1 ellenőrzés kikapcsolva)'); return; end
    for i = 1:numel(names)
        v = vals{i};
        if isempty(v), continue; end
        mx = max(v);
        if mx <= 1e-3, st = 'OK'; else, st = '*** SÉRÜL ***'; end
        fprintf('  %-66s max(c) = %9.3f   %s\n', names{i}, mx, st);
    end
end

%% ---------------- F1 KINEMATIKAI KÉNYSZEREK ----------------

function [Q, ok, Cp] = f1_pose_sweep(C, K_loc, WC_init, L0, vals, mode, steer_idx)
    opt = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-10, ...
        'StepTolerance', 1e-12, 'MaxIterations', 200);
    n = numel(vals); Q = nan(n, 5); ok = false(n, 1); Cp = cell(n, 1);
    q_def = [WC_init(1), WC_init(2), 0, 0, 0];
    [~, i0] = min(abs(vals));
    order = [i0:n, i0-1:-1:1];
    q_prev = q_def; q_at0 = q_def;
    for k = order
        if k == i0 - 1, q_prev = q_at0; end
        Ck = C;
        if strcmp(mode, 'dz')
            Ck(:,3) = C(:,3) - vals(k);
        else
            Ck(steer_idx,2) = C(steer_idx,2) + vals(k);
        end
        obj = @(q) f1_link_errors(q, Ck, K_loc, WC_init, 0, L0);
        [q, resn, ~, ef] = lsqnonlin(obj, q_prev, [], [], opt);
        good = (ef > 0) && (resn < 1e-6);
        if ~good
            [q, resn, ~, ef] = lsqnonlin(obj, q_def, [], [], opt);
            good = (ef > 0) && (resn < 1e-6);
        end
        if good
            Q(k,:) = q; ok(k) = true; Cp{k} = Ck; q_prev = q;
            if k == i0, q_at0 = q; end
        end
    end
end

function Kk = f1_pose_points(q, K_loc, WC_init)
    R   = f1_euler_rot(q(3), q(4), q(5));
    WCk = [q(1), q(2), WC_init(3)];
    Kk  = (WCk(:) + R * K_loc')';
end

function inc = f1_member_incidences(C0, K0, C, K, hinge)
    n = size(C0, 1); inc = zeros(n, 1);
    for i = 1:n
        L0 = K0(i,:) - C0(i,:);
        m0 = f1_major_axis0(L0);
        if hinge(i,1) > 0
            a0 = C0(hinge(i,2),:) - C0(hinge(i,1),:);
            a1 = C(hinge(i,2),:)  - C(hinge(i,1),:);
            Rh = f1_rot_between(a0, a1);                  
            v0 = Rh * (K0(i,:) - C0(hinge(i,1),:))';
            v1 = (K(i,:) - C(hinge(i,1),:))';
            m  = f1_axis_rot(a1, f1_signed_angle(v0, v1, a1)) * (Rh * m0);
        else
            m  = f1_rot_between(L0, K(i,:) - C(i,:)) * m0;
        end
        inc(i) = f1_incidence(m) - f1_incidence(m0);
    end
end

function [names, vals] = f1_static_cons(C, Kout, WC, F1, pairs, names, vals)
    [n0, zw0] = f1_wheel_axes(F1);
    [yw, zw, r] = f1_wcs_coords(Kout, WC, n0, zw0, F1);
    [names, vals] = f1_add(names, vals, 'C10.3.4a outboard pontok YW <= 0 [mm]', yw - F1.OutboardYWmax);
    [names, vals] = f1_add(names, vals, sprintf('C10.3.4b outboard pontok ZW >= %g [mm]', F1.OutboardZWmin), ...
        F1.OutboardZWmin - zw);
    if F1.Drum.Enable
        [names, vals] = f1_add(names, vals, 'C10.3.4c outboard pontok a Drumon belül [mm]', ...
            [r - F1.Drum.Radius; F1.Drum.YW(1) - yw; yw - F1.Drum.YW(2)]);
    else
        [names, vals] = f1_add(names, vals, 'C10.3.4c Drum (KIKAPCSOLVA)', -ones(3*numel(yw), 1));
    end
    if F1.IsFront && ~isempty(pairs)
        dx = abs(C(pairs(:,1),1) - C(pairs(:,2),1));
        [names, vals] = f1_add(names, vals, sprintf('C10.3.5 párok vázpontjainak X-távolsága >= %g [mm]', F1.PairMinDX), ...
            F1.PairMinDX - dx);
        idx = unique(pairs(:));
        [names, vals] = f1_add(names, vals, sprintf('C10.3.5 pár-vázpontok Z_F1 >= %g [mm]', F1.PairMinZ), ...
            (F1.PairMinZ + F1.RefPlaneZ) - C(idx,3));
    end
    if ~isempty(F1.NoMountBox)
        s = zeros(size(C,1), 1);
        for i = 1:size(C,1), s(i) = f1_box_sdf(C(i,:), F1.NoMountBox); end
        [names, vals] = f1_add(names, vals, 'C10.3.10 vázpontok a PU-dobozon kívül [mm]', -s);
    end
end

function [names, vals] = f1_heave_cons(C, Km, WC_init, F1, hinge, names, vals)
    nM = size(Km, 1);
    L0 = sqrt(sum((Km - C).^2, 2));
    K_loc = Km - WC_init;
    dzs = F1.CheckDz(:)'; np = numel(dzs);
    [Q, ok, Cp] = f1_pose_sweep(C, K_loc, WC_init, L0, dzs, 'dz', 0);
    [~, zw0] = f1_wheel_axes(F1);
    th  = nan(1, np);
    inc = (10 + F1.IncidenceHeaveMax) * ones(nM, np);   
    for k = 1:np
        if ~ok(k), continue; end
        R  = f1_euler_rot(Q(k,3), Q(k,4), Q(k,5));
        zw = R * zw0; th(k) = atan2d(zw(1), zw(3));
        Kk = f1_pose_points(Q(k,:), K_loc, WC_init);
        inc(:,k) = f1_member_incidences(C, Km, Cp{k}, Kk, hinge);
    end
    g = zeros(0, 1);
    for i = 1:np
        for j = i+1:np
            if abs((dzs(j) - dzs(i)) - F1.ZWgradWindow) < 1e-9
                if isnan(th(i)) || isnan(th(j))
                    g(end+1, 1) = 10; 
                else
                    g(end+1, 1) = abs(th(j) - th(i)) - F1.ZWgradMax; 
                end
            end
        end
    end
    [names, vals] = f1_add(names, vals, sprintf('C10.3.1 ZW oldalnézeti szögváltozás <= %g° / %g mm [deg]', ...
        F1.ZWgradMax, F1.ZWgradWindow), g);
    [names, vals] = f1_add(names, vals, sprintf('C10.3.6c tag-főtengely dőlésváltozás rugóúton <= %g° [deg]', ...
        F1.IncidenceHeaveMax), abs(inc(:)) - F1.IncidenceHeaveMax);
end

function [names, vals] = f1_steer_cons(C, Km, WC_init, F1, hinge, steer_idx, names, vals)
    nM = size(Km, 1);
    L0 = sqrt(sum((Km - C).^2, 2));
    K_loc = Km - WC_init;
    dys = linspace(-F1.SteerCheckRack, F1.SteerCheckRack, 7);
    [Q, ok, Cp] = f1_pose_sweep(C, K_loc, WC_init, L0, dys, 'dy', steer_idx);
    inc = (10 + F1.IncidenceSteerMax) * ones(nM, numel(dys));
    for k = 1:numel(dys)
        if ~ok(k), continue; end
        Kk = f1_pose_points(Q(k,:), K_loc, WC_init);
        inc(:,k) = f1_member_incidences(C, Km, Cp{k}, Kk, hinge);
    end
    [names, vals] = f1_add(names, vals, sprintf('C10.3.6c tag-főtengely dőlésváltozás kormányzáson <= %g° [deg]', ...
        F1.IncidenceSteerMax), abs(inc(:)) - F1.IncidenceSteerMax);
end

function [names, vals] = f1_kingpin_cons(C, Kb, WC, F1, radii, gap, Col, names, vals)
    n0 = f1_wheel_axes(F1);
    P  = Kb(2,:)'; a = Kb(1,:)' - P; a = a / norm(a);
    al = deg2rad(-70:0.25:70); N = numel(al);
    delta = zeros(1, N); dzc = zeros(1, N);
    for k = 1:N
        Rk = f1_axis_rot(a, al(k));
        nk = Rk * n0;  delta(k) = asind(nk(1));            
        wk = P + Rk * (WC(:) - P); dzc(k) = wk(3) - WC(3);
    end

    if max(delta) >= F1.JackAngle && min(delta) <= -F1.JackAngle
        cj = max(abs(dzc(abs(delta) <= F1.JackAngle))) - F1.JackMax;
    else
        cj = 10;
    end
    [names, vals] = f1_add(names, vals, sprintf('C10.2.6b kerékközép Z-változás ±%g° kerékszögön <= %g mm [mm]', ...
        F1.JackAngle, F1.JackMax), cj);

    [names, vals] = f1_add(names, vals, sprintf('C10.3.7 elérhető toe-in >= %g° és toe-out >= %g° [deg]', ...
        F1.LockToeIn, F1.LockToeOut), [F1.LockToeIn - max(delta); F1.LockToeOut + min(delta)]);

    [ds, is] = sort(delta); [ds, iu] = unique(ds); als = al(is(iu));
    targets = [F1.LockToeIn, -F1.LockToeOut];
    Km  = [Kb(1,:); Kb(1,:); Kb(2,:); Kb(2,:)];
    L5  = norm(Kb(3,:) - C(5,:));
    c_rim = zeros(10, 1); c_rack = zeros(2, 1);
    for t = 1:2
        tg  = max(ds(1), min(ds(end), targets(t)));
        Rk  = f1_axis_rot(a, interp1(ds, als, tg));
        nk  = Rk * n0; wk = P + Rk * (WC(:) - P);
        rc  = wk + Col.rim_y_offset * nk;
        for i = 1:4
            dd = f1_seg_rim_dist(C(i,:), Km(i,:), rc, nk, Col.rim_inner_radius, Col.rim_outer_radius, Col.rim_width/2);
            c_rim((t-1)*5 + i) = radii(i) + gap - dd;
        end
        tr = (P + Rk * (Kb(3,:)' - P))';
        dxx = tr(1) - C(5,1); dzz = tr(3) - C(5,3); disc = L5^2 - dxx^2 - dzz^2;
        if disc >= 0
            yc = tr(2) + [-1, 1] * sqrt(disc);
            [~, j] = min(abs(yc - C(5,2)));
            rk = [C(5,1), yc(j), C(5,3)];
            dd = f1_seg_rim_dist(rk, tr, rc, nk, Col.rim_inner_radius, Col.rim_outer_radius, Col.rim_width/2);
            c_rim((t-1)*5 + 5) = radii(5) + gap - dd;
            travel = abs(yc(j) - C(5,2));
        else
            c_rim((t-1)*5 + 5) = -1;     
            travel = Inf;
        end
        if isfinite(F1.MaxRackTravel)
            c_rack(t) = min(travel - F1.MaxRackTravel, 100);
        else
            c_rack(t) = -1;
        end
    end
    [names, vals] = f1_add(names, vals, 'C10.3.7 felni–tag szabadmagasság a lock pózokban [mm]', c_rim);
    [names, vals] = f1_add(names, vals, 'C10.3.7 lockhoz szükséges rack-út <= F1.MaxRackTravel [mm]', c_rack);
end

function [c, ceq, names, vals] = f1_nonlcon_DAA(x, WC_init, F1, Collision)
    ceq = []; names = {}; vals = {};
    if ~F1.Enable, c = zeros(0, 1); return; end
    C  = reshape(x(1:15), [5,3]);
    Kb = reshape(x(16:24), [3,3]);
    Km = [Kb(1,:); Kb(1,:); Kb(2,:); Kb(2,:); Kb(3,:)];   
    hinge = [1 2; 1 2; 3 4; 3 4; 0 0];                     
    radii = [Collision.rod_diameter_upper; Collision.rod_diameter_upper; ...
             Collision.rod_diameter_lower; Collision.rod_diameter_lower; Collision.rod_diameter_tie] / 2;

    [names, vals] = f1_static_cons(C, Kb, WC_init, F1, [1 2; 3 4], names, vals);
    [names, vals] = f1_heave_cons(C, Km, WC_init, F1, hinge, names, vals);
    if F1.IsFront
        [names, vals] = f1_steer_cons(C, Km, WC_init, F1, hinge, 5, names, vals);
        [names, vals] = f1_kingpin_cons(C, Kb, WC_init, F1, radii, Collision.min_clearance, Collision, names, vals);
    end
    c = vertcat(vals{:});
end