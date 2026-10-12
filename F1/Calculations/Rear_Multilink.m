function base_program_rear_multi
% =========================================================================
% HÁTSÓ multilink (5 link, bal + jobb) + Heave + Roll (nincs kormányzás)
% Link 5 = toe link: a váz felőli vége fix (rack_range = 0), csak a heave/roll mozgatja.
% Kinematika: base_program_front_left_multi 1:1 (LSQNONLIN, IC/RC, KPI/Caster/Scrub/Trail)
%   – KPI/Caster/Scrub/Trail itt a virtuális kormánytengelyből (a Link 5 menti
%     differenciális elmozdulásból), ugyanazzal a képlettel, mint az első tengelyen.
% + Pushrod / Rocker / Damper (Excelből, mint a DAA_Rear-ben)
% + Stabilizátor: U-bar vagy Z-bar (Excelből)
% =========================================================================
    % clc;
    % clear all;
    % close all;

    %% 0. BEMENETI FÁJLOK / BEÁLLÍTÁSOK
    input_excel_file  = 'Multi_Points_Rear.xlsx';         % Link 1..5 Chassis/Upright + Wheel Center (Link 5 = toe link)
    input_sheet       = '';                               % '' = első munkalap   (template: 'Multi_Points')
    rocker_excel_file = 'Optim_Rocker_Multi_Rear.xlsx';   % '' = ugyanaz a fájl, mint input_excel_file
    rocker_sheet      = '';                               % (template: 'Rocker')
    pushrod_mount     = 'upright';                        % 'upright' vagy 'link1' ... 'link5'
    arb_type          = 'U';                              % 'none' | 'U' | 'Z'
    arb_excel_file    = '';                               % '' = ugyanaz a fájl, mint a rocker fájl
    arb_sheet         = '';                               % (template: 'ARB_U' vagy 'ARB_Z')
    tire_width        = 200;                              % csak rajzhoz / tengelyhatárhoz

    %% 1. BEKÖTÉSI PONTOK – Excelből olvasás
    T_in = read_pts_table(input_excel_file, input_sheet);

    C_L = zeros(5,3);
    K_L = zeros(5,3);

    for i = 1:5
        % Link X Chassis
        idx_c = find(strcmpi(T_in.Name, sprintf('Link %d Chassis', i)) | ...
            strcmpi(T_in.Name, sprintf('Link%d Chassis', i)), 1);

        % Link X Upright
        idx_k = find(strcmpi(T_in.Name, sprintf('Link %d Upright', i)) | ...
            strcmpi(T_in.Name, sprintf('Link%d Upright', i)), 1);

        if isempty(idx_c) || isempty(idx_k)
            error('Hiányzó pont az Excelben: Link %d Chassis vagy Upright!', i);
        end

        C_L(i,:) = [T_in.X(idx_c), T_in.Y(idx_c), T_in.Z(idx_c)];
        K_L(i,:) = [T_in.X(idx_k), T_in.Y(idx_k), T_in.Z(idx_k)];
    end

    % Wheel Center
    idx_wc = find(strcmpi(T_in.Name, 'Wheel Center') | strcmpi(T_in.Name, 'WheelCenter'), 1);
    if ~isempty(idx_wc)
        WC_init_L = [T_in.X(idx_wc), T_in.Y(idx_wc), T_in.Z(idx_wc)];
    else
        warning('Wheel Center nem található az Excelben, alapértelmezett érték használata.');
        WC_init_L = [0, 600, 193];
    end

    TireRadius = WC_init_L(3);   % vagy írd be fixen: TireRadius = 193;

    % --- Jobb oldal (Tükrözés az Y tengelyre: Y = -Y) ---
    C_R = C_L; C_R(:,2) = -C_L(:,2);
    K_R = K_L; K_R(:,2) = -K_L(:,2);
    WC_init_R = WC_init_L; WC_init_R(2) = -WC_init_L(2);

    %% 1/b. ROCKER + ARB – Excelből olvasás
    [rocker_excel_file, rocker_sheet] = resolve_src(rocker_excel_file, rocker_sheet, input_excel_file, input_sheet);
    T_rock = read_pts_table(rocker_excel_file, rocker_sheet);
    rk_L = load_rocker(T_rock);
    rk_R = mirror_rocker(rk_L);

    [arb_excel_file, arb_sheet] = resolve_src(arb_excel_file, arb_sheet, rocker_excel_file, rocker_sheet);
    arb = load_arb(arb_type, arb_excel_file, arb_sheet);

    push_link = parse_pushrod_mount(pushrod_mount);

    L_push_L = norm(rk_L.push_rocker - rk_L.push_upright);
    L_push_R = norm(rk_R.push_rocker - rk_R.push_upright);
    RK_static_L = [rk_L.axis; rk_L.center; rk_L.push_rocker; rk_L.damper_rocker; rk_L.damper_chassis; rk_L.push_upright];
    RK_static_R = [rk_R.axis; rk_R.center; rk_R.push_rocker; rk_R.damper_rocker; rk_R.damper_chassis; rk_R.push_upright];

    %% 2. SZIMULÁCIÓS TARTOMÁNY ÉS MÁTRIXOK INICIALIZÁLÁSA
    travel_range = -30:5:30;    % +- 30 mm wheel travel (Heave)
    rack_range   = 0;          % hátsó tengely: nincs kormányzás (toe link fix a vázon)
    roll_range   = -2:0.5:2;      % +- 3 fok chassis roll (Dőlés)
    
    num_z = length(travel_range);
    num_r = length(rack_range);
    num_roll = length(roll_range);
    
    pivot_history = zeros(num_z, 1); % Eltároljuk a tisztán Heave Z pivotokat a vizualizációhoz
    
    % --- 3D Pontokat tároló mátrixok (Z, R, Roll, [X, Y, Z]) ---
    CP_mat_L       = zeros(num_z, num_r, num_roll, 3);
    CP_mat_R       = zeros(num_z, num_r, num_roll, 3);
    FrontIC_mat_L  = zeros(num_z, num_r, num_roll, 3);
    FrontIC_mat_R  = zeros(num_z, num_r, num_roll, 3);
    RC_mat         = zeros(num_z, num_r, num_roll, 3); 
    
    % --- Paraméterek Mátrixai ---
    KPI_L = zeros(num_z, num_r, num_roll); Caster_L = zeros(num_z, num_r, num_roll);
    Scrub_L = zeros(num_z, num_r, num_roll); Trail_L = zeros(num_z, num_r, num_roll);
    Camber_L = zeros(num_z, num_r, num_roll); Toe_L = zeros(num_z, num_r, num_roll);
    
    KPI_R = zeros(num_z, num_r, num_roll); Caster_R = zeros(num_z, num_r, num_roll);
    Scrub_R = zeros(num_z, num_r, num_roll); Trail_R = zeros(num_z, num_r, num_roll);
    Camber_R = zeros(num_z, num_r, num_roll); Toe_R = zeros(num_z, num_r, num_roll);
    
    % Állapotok mentéséhez
    K_history_L = zeros(num_z, num_r, num_roll, 5, 3); K_history_R = zeros(num_z, num_r, num_roll, 5, 3);
    WC_history_L = zeros(num_z, num_r, num_roll, 3); WC_history_R = zeros(num_z, num_r, num_roll, 3);
    R_history_L = zeros(num_z, num_r, num_roll, 3, 3); R_history_R = zeros(num_z, num_r, num_roll, 3, 3);
    m_rc_L_mat = zeros(num_z, num_r, num_roll); m_rc_R_mat = zeros(num_z, num_r, num_roll);

    % Rocker / damper / ARB
    rock_hist_L  = zeros(num_z, num_r, num_roll, 6, 3); rock_hist_R  = zeros(num_z, num_r, num_roll, 6, 3);
    rocker_ang_L = zeros(num_z, num_r, num_roll);       rocker_ang_R = zeros(num_z, num_r, num_roll);
    damper_len_L = zeros(num_z, num_r, num_roll);       damper_len_R = zeros(num_z, num_r, num_roll);
    arb_hist  = nan(num_z, num_r, num_roll, 6, 3);
    arb_phi_L = nan(num_z, num_r, num_roll); arb_phi_R = nan(num_z, num_r, num_roll);
    arb_twist = nan(num_z, num_r, num_roll);
    
    %% 3. MULTILINK KINEMATIKAI SZOLVER MIND KÉT OLDALRA
    options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 10000, 'FunctionTolerance', 1e-200);
    
    L0_L = zeros(5,1); L0_R = zeros(5,1);
    for i = 1:5
        L0_L(i) = norm(K_L(i,:) - C_L(i,:));
        L0_R(i) = norm(K_R(i,:) - C_R(i,:));
    end
    K_loc_L = K_L - WC_init_L;
    K_loc_R = K_R - WC_init_R;
    
    fprintf('Kezdeti szimulációs inicializáció folyamatban...\n');
    q0_straight_L = [WC_init_L(1), WC_init_L(2), 0, 0, 0];
    q0_straight_R = [WC_init_R(1), WC_init_R(2), 0, 0, 0];
    
    % Kiszámoljuk a statikus 0-állapot roll centerének Z koordinátáját
    [~, ~, current_RC_z, ~, ~, ~, ~, q0_straight_L, q0_straight_R] = ...
        get_local_RC_and_ICs(C_L, C_R, 0, 0, 0, 0, q0_straight_L, q0_straight_R, K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options, K_L, K_R);
        
    fprintf('Fő szimuláció indítása (Heave & Roll Sweep, hátsó tengely)...\n');
    
    for iz = 1:num_z
        dz = travel_range(iz);
        
        % TISZTÁN HEAVE alapú RC keresés (dy_rack = 0, roll = 0). 
        % Ezt az értéket MENTJÜK EL a következő iterációk forgáspontjának (csak a Z koordinátát).
        [~, ~, pure_rc_z, ~, ~, ~, ~, q0_straight_L, q0_straight_R] = ...
            get_local_RC_and_ICs(C_L, C_R, dz, 0, 0, current_RC_z, q0_straight_L, q0_straight_R, ...
                                 K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options, K_L, K_R);
        
        pivot_history(iz) = pure_rc_z;
        
        for ir = 1:num_r
            dy_rack = rack_range(ir);
            
            for iroll = 1:num_roll
                roll_angle_deg = roll_range(iroll);
                
                % 1. Adott állapot megoldása LSQNONLIN-el (Heave + Steer + Roll a pure_rc_z körül)
                [K_new_L, K_new_R, WC_new_L, WC_new_R, cp_L, cp_R, q_opt_L, q_opt_R, R_mat_L, R_mat_R, C_curr_L, C_curr_R] = ...
                    solve_state(C_L, C_R, dz, dy_rack, roll_angle_deg, pure_rc_z, q0_straight_L, q0_straight_R, ...
                                K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options);
                                
                % 2. Lokális pillanatnyi IC-k és RC számítása az adott állapotban
                [rc_x, rc_y, rc_z, ic_L, ic_R, m_L, m_R] = ...
                    get_local_RC_and_ICs(C_L, C_R, dz, dy_rack, roll_angle_deg, pure_rc_z, q_opt_L, q_opt_R, ...
                                         K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options, K_L, K_R);
                
                CP_mat_L(iz, ir, iroll, :) = cp_L;
                CP_mat_R(iz, ir, iroll, :) = cp_R;
                FrontIC_mat_L(iz, ir, iroll, :) = ic_L;
                FrontIC_mat_R(iz, ir, iroll, :) = ic_R;
                RC_mat(iz, ir, iroll, :) = [rc_x, rc_y, rc_z];
                m_rc_L_mat(iz, ir, iroll) = m_L;
                m_rc_R_mat(iz, ir, iroll) = m_R;
                
                %% --- DIFFERENCIÁL KINEMATIKA ÉS JELLEMZŐK ---
                % (BAL OLDAL)
                wheel_normal_L = R_mat_L * [0; 1; 0];
                Camber_L(iz, ir, iroll) = -atand(wheel_normal_L(3) / wheel_normal_L(2));
                Toe_L(iz, ir, iroll)    = -atand(wheel_normal_L(1) / wheel_normal_L(2));
                
                J_L = zeros(6,6);
                for i = 1:5
                    vec_link_L = K_new_L(i,:) - C_curr_L(i,:);
                    vec_r_L    = K_new_L(i,:) - WC_new_L;
                    J_L(i,1:3) = vec_link_L; J_L(i,4:6) = cross(vec_r_L, vec_link_L);
                end
                J_L(6,:) = [0 0 1 0 0 0];
                
                V_input_L = zeros(6,1); V_input_L(5) = (K_new_L(5,2) - C_curr_L(5,2)) * 10;
                twist_vector_L = J_L \ V_input_L;
                v_WC_L  = twist_vector_L(1:3); omega_L = twist_vector_L(4:6);
                omega_norm_L = norm(omega_L); U_vec_L = omega_L / omega_norm_L;
                if U_vec_L(3) < 0, U_vec_L = -U_vec_L; omega_L = -omega_L; v_WC_L = -v_WC_L; end
                
                KPI_L(iz, ir, iroll)    = atand(-U_vec_L(2) / U_vec_L(3));
                Caster_L(iz, ir, iroll) = atand(-U_vec_L(1) / U_vec_L(3));
                P_isa_L = WC_new_L' + cross(omega_L, v_WC_L) / (omega_norm_L^2);
                v_CP_pure_L = cross(omega_L, cp_L' - P_isa_L);
                delta_L = deg2rad(Toe_L(iz, ir, iroll)); omega_delta_L = omega_L(3);
                if abs(omega_delta_L) > 1e-8
                    Scrub_L(iz, ir, iroll) = -(v_CP_pure_L(1) * cos(delta_L) + v_CP_pure_L(2) * sin(delta_L)) / omega_delta_L;
                    Trail_L(iz, ir, iroll) = (v_CP_pure_L(1) * sin(delta_L) - v_CP_pure_L(2) * cos(delta_L)) / omega_delta_L;
                else
                    Scrub_L(iz, ir, iroll) = NaN; Trail_L(iz, ir, iroll) = NaN;
                end
                
                % (JOBB OLDAL)
                wheel_normal_R = R_mat_R * [0; -1; 0];
                Camber_R(iz, ir, iroll) = atand(wheel_normal_R(3) / wheel_normal_R(2));
                Toe_R(iz, ir, iroll)    = atand(wheel_normal_R(1) / wheel_normal_R(2));
                
                J_R = zeros(6,6);
                for i = 1:5
                    vec_link_R = K_new_R(i,:) - C_curr_R(i,:);
                    vec_r_R    = K_new_R(i,:) - WC_new_R;
                    J_R(i,1:3) = vec_link_R; J_R(i,4:6) = cross(vec_r_R, vec_link_R);
                end
                J_R(6,:) = [0 0 1 0 0 0];
                
                V_input_R = zeros(6,1); V_input_R(5) = (K_new_R(5,2) - C_curr_R(5,2)) * 10;
                twist_vector_R = J_R \ V_input_R;
                v_WC_R  = twist_vector_R(1:3); omega_R = twist_vector_R(4:6);
                omega_norm_R = norm(omega_R); U_vec_R = omega_R / omega_norm_R;
                if U_vec_R(3) < 0, U_vec_R = -U_vec_R; omega_R = -omega_R; v_WC_R = -v_WC_R; end
                
                KPI_R(iz, ir, iroll)    = -atand(-U_vec_R(2) / U_vec_R(3));
                Caster_R(iz, ir, iroll) = atand(-U_vec_R(1) / U_vec_R(3));
                P_isa_R = WC_new_R' + cross(omega_R, v_WC_R) / (omega_norm_R^2);
                v_CP_pure_R = cross(omega_R, cp_R' - P_isa_R);
                delta_R = deg2rad(Toe_R(iz, ir, iroll)); omega_delta_R = omega_R(3);
                if abs(omega_delta_R) > 1e-8
                    Scrub_R(iz, ir, iroll) = (v_CP_pure_R(1) * cos(delta_R) + v_CP_pure_R(2) * sin(delta_R)) / omega_delta_R;
                    Trail_R(iz, ir, iroll) = (v_CP_pure_R(1) * sin(delta_R) - v_CP_pure_R(2) * cos(delta_R)) / omega_delta_R;
                else
                    Scrub_R(iz, ir, iroll) = NaN; Trail_R(iz, ir, iroll) = NaN;
                end
                
                % Állapotok mentése
                K_history_L(iz, ir, iroll, :, :) = K_new_L; WC_history_L(iz, ir, iroll, :) = WC_new_L; R_history_L(iz, ir, iroll, :, :) = R_mat_L;
                K_history_R(iz, ir, iroll, :, :) = K_new_R; WC_history_R(iz, ir, iroll, :) = WC_new_R; R_history_R(iz, ir, iroll, :, :) = R_mat_R;

                %% --- PUSHROD / ROCKER / DAMPER / ARB (utófeldolgozás) ---
                Rroll_s = roll_matrix(roll_angle_deg);
                P10_L = pushrod_point(push_link, rk_L.push_upright, WC_init_L, WC_new_L, R_mat_L, C_L, K_L, C_curr_L, K_new_L);
                P10_R = pushrod_point(push_link, rk_R.push_upright, WC_init_R, WC_new_R, R_mat_R, C_R, K_R, C_curr_R, K_new_R);
                [RK_L, rang_L] = solve_rocker_state(rk_L, L_push_L, P10_L, dz, Rroll_s, pure_rc_z);
                [RK_R, rang_R] = solve_rocker_state(rk_R, L_push_R, P10_R, dz, Rroll_s, pure_rc_z);
                rock_hist_L(iz, ir, iroll, :, :) = RK_L;  rock_hist_R(iz, ir, iroll, :, :) = RK_R;
                rocker_ang_L(iz, ir, iroll) = rang_L;     rocker_ang_R(iz, ir, iroll) = -rang_R;   % jobb: tükrözött előjel
                damper_len_L(iz, ir, iroll) = norm(RK_L(4,:) - RK_L(5,:));
                damper_len_R(iz, ir, iroll) = norm(RK_R(4,:) - RK_R(5,:));

                if arb.has
                    D_arb_L = rocker_carry(RK_static_L, RK_L, arb.D_L);
                    D_arb_R = rocker_carry(RK_static_R, RK_R, arb.D_R);
                    [Parb, phL, phR, tw] = solve_arb_state(arb, D_arb_L, D_arb_R, dz, Rroll_s, pure_rc_z);
                    arb_hist(iz, ir, iroll, :, :) = Parb;
                    arb_phi_L(iz, ir, iroll) = phL; arb_phi_R(iz, ir, iroll) = phR;
                    arb_twist(iz, ir, iroll) = tw;
                end
            end
        end
        
        % Továbbvisszük a tisztán heave alapú z pivotot a következő rugóút lépésre
        current_RC_z = pure_rc_z;
    end
    
    fprintf('Szimuláció kész! Interaktív nézet megnyitása...\n');

    iz_zero = find(travel_range == 0, 1);
    ir_zero = find(rack_range == 0, 1);
    iroll_zero = find(roll_range == 0, 1);

    fprintf('Static damper L/R = %.2f / %.2f mm | static rocker szög L/R = %.3f / %.3f°\n', ...
        damper_len_L(iz_zero, ir_zero, iroll_zero), damper_len_R(iz_zero, ir_zero, iroll_zero), ...
        rocker_ang_L(iz_zero, ir_zero, iroll_zero), rocker_ang_R(iz_zero, ir_zero, iroll_zero));
    arb_report(arb, arb_twist(:, ir_zero, iroll_zero), arb_twist(iz_zero, ir_zero, :), roll_range);

    %% 4. TENGELYHATÁROK – a felfüggesztés összes állapotából
    P_chassis = [];
    for iz = [1, num_z]
        for iroll = [1, num_roll]
            Rr = roll_matrix(roll_range(iroll));
            for i = 1:5
                P_chassis = [P_chassis; chassis_tf(C_L(i,:), travel_range(iz), Rr, pivot_history(iz)); ...
                                        chassis_tf(C_R(i,:), travel_range(iz), Rr, pivot_history(iz))]; %#ok<AGROW>
            end
        end
    end
    P_all = [P_chassis; reshape(K_history_L, [], 3); reshape(K_history_R, [], 3); ...
             reshape(rock_hist_L, [], 3); reshape(rock_hist_R, [], 3); reshape(arb_hist, [], 3)];
    WC_all = [reshape(WC_history_L, [], 3); reshape(WC_history_R, [], 3)];
    [xl, yl, zl] = auto_axis_limits(P_all, WC_all, TireRadius, tire_width);
    
    %% 5. VIZUALIZÁCIÓ
    fig = figure('Name', 'Interactive REAR Multilink + Rocker + ARB (Heave/Roll Sweep)', 'NumberTitle', 'off', 'WindowState', 'maximized');
    ax = axes('Parent', fig, 'Position', [0.05 0.3 0.9 0.65]);
    hold(ax, 'on'); grid(ax, 'on'); axis(ax, 'equal');
    xlabel(ax, 'X [mm]'); ylabel(ax, 'Y [mm]'); zlabel(ax, 'Z [mm]');
    xlim(ax, xl); ylim(ax, yl); zlim(ax, zl);
    view(ax, -35, 20);
    light('Parent', ax, 'Position', [1 1 1], 'Style', 'infinite');
    lighting(ax, 'gouraud'); material(ax, 'dull');
    
    % Padló (a tengelyhatárokhoz igazítva)
    [Xf, Yf] = meshgrid(linspace(xl(1), xl(2), 10), linspace(yl(1), yl(2), 10));
    Zf = zeros(size(Xf));
    
    % Sliderek és UI felület (2 slider – nincs kormányzás)
    slider_z = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.2 0.14 0.6 0.03], 'Min', 1, 'Max', num_z, 'Value', iz_zero, ...
        'SliderStep', [1/(num_z-1) 5/(num_z-1)], 'Callback', @update_ui);
        
    slider_roll = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.2 0.06 0.6 0.03], 'Min', 1, 'Max', num_roll, 'Value', iroll_zero, ...
        'SliderStep', [1/(num_roll-1) 1/(num_roll-1)], 'Callback', @update_ui);
        
    txt_z = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.82 0.13 0.15 0.04], 'String', '', 'FontSize', 12, 'HorizontalAlignment', 'left');
        
    txt_roll = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.82 0.05 0.15 0.04], 'String', '', 'FontSize', 12, 'HorizontalAlignment', 'left');
        
    txt_rc = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.05 0.08 0.12 0.08], 'String', '', 'FontSize', 12, 'FontWeight', 'bold');

    txt_arb = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.40 0.15 0.15], 'String', '', 'FontSize', 10, 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
        
    txt_params_L = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.60 0.15 0.32], 'String', '', 'FontSize', 10, 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
        
    txt_params_R = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.83 0.60 0.15 0.32], 'String', '', 'FontSize', 10, 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    
    update_ui(0,0);
    
    %% Nested Functions for Visualization
    function update_ui(~, ~)
        w_idx = round(get(slider_z, 'Value'));
        s_idx = 1;   % nincs kormányzás
        r_idx = round(get(slider_roll, 'Value'));
        
        set(txt_z, 'String', sprintf('Wheel Travel: %.1f mm', travel_range(w_idx)));
        set(txt_roll, 'String', sprintf('Chassis Roll: %.1f °', roll_range(r_idx)));
        
        rc = squeeze(RC_mat(w_idx, s_idx, r_idx, :));
        set(txt_rc, 'String', sprintf('Roll Center Height:\n%.1f mm', rc(3)));
        
        param_str_L = sprintf('LEFT WHEEL:\n\nCamber: %.2f °\nToe: %.2f °\nKPI: %.2f °\nCaster: %.2f °\nScrub: %.1f mm\nMech. Trail: %.1f mm\nDamper: %.1f mm\nRocker: %.2f °', ...
            Camber_L(w_idx, s_idx, r_idx), Toe_L(w_idx, s_idx, r_idx), KPI_L(w_idx, s_idx, r_idx), Caster_L(w_idx, s_idx, r_idx), Scrub_L(w_idx, s_idx, r_idx), Trail_L(w_idx, s_idx, r_idx), ...
            damper_len_L(w_idx, s_idx, r_idx), rocker_ang_L(w_idx, s_idx, r_idx));
        set(txt_params_L, 'String', param_str_L);
        
        param_str_R = sprintf('RIGHT WHEEL:\n\nCamber: %.2f °\nToe: %.2f °\nKPI: %.2f °\nCaster: %.2f °\nScrub: %.1f mm\nMech. Trail: %.1f mm\nDamper: %.1f mm\nRocker: %.2f °', ...
            Camber_R(w_idx, s_idx, r_idx), Toe_R(w_idx, s_idx, r_idx), KPI_R(w_idx, s_idx, r_idx), Caster_R(w_idx, s_idx, r_idx), Scrub_R(w_idx, s_idx, r_idx), Trail_R(w_idx, s_idx, r_idx), ...
            damper_len_R(w_idx, s_idx, r_idx), rocker_ang_R(w_idx, s_idx, r_idx));
        set(txt_params_R, 'String', param_str_R);

        if arb.has
            set(txt_arb, 'String', sprintf('ARB (%s-bar):\nBlade L: %.2f °\nBlade R: %.2f °\nTwist: %.2f °', arb.type, ...
                arb_phi_L(w_idx, s_idx, r_idx), arb_phi_R(w_idx, s_idx, r_idx), arb_twist(w_idx, s_idx, r_idx)));
        else
            set(txt_arb, 'String', 'ARB: nincs');
        end
        
        cla(ax);
        surf(ax, Xf, Yf, Zf, 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        
        dz_val = travel_range(w_idx);
        dy_val = rack_range(s_idx);
        roll_val = roll_range(r_idx);
        
        % Visszaállítjuk pontosan ugyanazt a vázállapotot a rajzoláshoz
        pivot_z = pivot_history(w_idx);
        C_bL = C_L; C_bL(:,3) = C_bL(:,3) - dz_val; C_bL(5,2) = C_bL(5,2) + dy_val;
        C_bR = C_R; C_bR(:,3) = C_bR(:,3) - dz_val; C_bR(5,2) = C_bR(5,2) + dy_val;
        r_rad = deg2rad(roll_val);
        R_mat = [1 0 0; 0 cos(r_rad) -sin(r_rad); 0 sin(r_rad) cos(r_rad)];
        
        C_curr_L = zeros(5,3); C_curr_R = zeros(5,3);
        for idx_c = 1:5
            C_curr_L(idx_c,:) = (R_mat * (C_bL(idx_c,:)' - [0;0;pivot_z]) + [0;0;pivot_z])';
            C_curr_R(idx_c,:) = (R_mat * (C_bR(idx_c,:)' - [0;0;pivot_z]) + [0;0;pivot_z])';
        end
        
        K_curr_L = squeeze(K_history_L(w_idx, s_idx, r_idx, :, :));
        K_curr_R = squeeze(K_history_R(w_idx, s_idx, r_idx, :, :));
        WC_L = squeeze(WC_history_L(w_idx, s_idx, r_idx, :));
        WC_R = squeeze(WC_history_R(w_idx, s_idx, r_idx, :));
        R_mat_L_local = squeeze(R_history_L(w_idx, s_idx, r_idx, :, :));
        R_mat_R_local = squeeze(R_history_R(w_idx, s_idx, r_idx, :, :));
        
        draw_suspension(ax, C_curr_L, K_curr_L, 'k', 'b');
        draw_suspension(ax, C_curr_R, K_curr_R, 'k', 'b');
        
        draw_tire(ax, WC_L, R_mat_L_local * [0; 1; 0], TireRadius);
        draw_tire(ax, WC_R, R_mat_R_local * [0; -1; 0], TireRadius);

        % Rocker + pushrod + damper (+ ARB)
        RK_Lv = squeeze(rock_hist_L(w_idx, s_idx, r_idx, :, :));
        RK_Rv = squeeze(rock_hist_R(w_idx, s_idx, r_idx, :, :));
        if arb.has
            Parb_v = squeeze(arb_hist(w_idx, s_idx, r_idx, :, :));
            draw_rocker(ax, RK_Lv, Parb_v(1,:));
            draw_rocker(ax, RK_Rv, Parb_v(4,:));
            draw_arb(ax, Parb_v);
        else
            draw_rocker(ax, RK_Lv, []);
            draw_rocker(ax, RK_Rv, []);
        end
        
        cp_L = squeeze(CP_mat_L(w_idx, s_idx, r_idx, :));
        cp_R = squeeze(CP_mat_R(w_idx, s_idx, r_idx, :));
        ic_L = squeeze(FrontIC_mat_L(w_idx, s_idx, r_idx, :));
        ic_R = squeeze(FrontIC_mat_R(w_idx, s_idx, r_idx, :));
        
        plot3(ax, cp_L(1), cp_L(2), cp_L(3), 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'y', 'MarkerSize', 10);
        plot3(ax, cp_R(1), cp_R(2), cp_R(3), 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'y', 'MarkerSize', 10);
        
        draw_ic_line(ax, cp_L, ic_L, 'r');
        draw_ic_line(ax, cp_R, ic_R, 'r');
        
        plot3(ax, rc(1), rc(2), rc(3), 'pentagram', 'MarkerFaceColor', 'm', 'MarkerEdgeColor', 'k', 'MarkerSize', 15);
        plot3(ax, [rc(1), rc(1)], [rc(2), rc(2)], [0, rc(3)], 'm--', 'LineWidth', 1.5);
    end

end

%% HELPER FUNKCIÓK (SZOLVEREK ÉS KINEMATIKA)

function [K_L, K_R, WC_L, WC_R, CP_L, CP_R, qL, qR, R_L, R_R, C_curr_L, C_curr_R] = solve_state(C_L_base, C_R_base, dz, dy, roll_deg, pivot_z, q0_L, q0_R, K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options)
    % Alkalmazza a heave és steer elmozdulást a bázispontokra
    C_bL = C_L_base; C_bL(:,3) = C_bL(:,3) - dz; C_bL(5,2) = C_bL(5,2) + dy;
    C_bR = C_R_base; C_bR(:,3) = C_bR(:,3) - dz; C_bR(5,2) = C_bR(5,2) + dy;
    
    % Alkalmazza a roll elmozdulást a pillanatnyi pivot magasság körül
    r_rad = deg2rad(roll_deg);
    R_mat = [1 0 0; 0 cos(r_rad) -sin(r_rad); 0 sin(r_rad) cos(r_rad)];
    C_curr_L = zeros(5,3); C_curr_R = zeros(5,3);
    for idx=1:5
        C_curr_L(idx,:) = (R_mat * (C_bL(idx,:)' - [0;0;pivot_z]) + [0;0;pivot_z])';
        C_curr_R(idx,:) = (R_mat * (C_bR(idx,:)' - [0;0;pivot_z]) + [0;0;pivot_z])';
    end
    
    % Kinematika LSQNONLIN megoldás - Bal
    obj_L = @(q) calc_link_errors(q, C_curr_L, K_loc_L, WC_init_L, L0_L);
    qL = lsqnonlin(obj_L, q0_L, [], [], options);
    WC_L = [qL(1), qL(2), WC_init_L(3)];
    R_L = euler_to_rot(qL(3), qL(4), qL(5));
    K_L = zeros(5,3); for idx=1:5, K_L(idx,:) = (WC_L' + R_L * K_loc_L(idx,:)')'; end
    CP_L = (WC_L' + (-WC_L(3)/(-1)) * [0;0;-1])'; 
    
    % Kinematika LSQNONLIN megoldás - Jobb
    obj_R = @(q) calc_link_errors(q, C_curr_R, K_loc_R, WC_init_R, L0_R);
    qR = lsqnonlin(obj_R, q0_R, [], [], options);
    WC_R = [qR(1), qR(2), WC_init_R(3)];
    R_R = euler_to_rot(qR(3), qR(4), qR(5));
    K_R = zeros(5,3); for idx=1:5, K_R(idx,:) = (WC_R' + R_R * K_loc_R(idx,:)')'; end
    CP_R = (WC_R' + (-WC_R(3)/(-1)) * [0;0;-1])';
end

function [rc_x, rc_y, rc_z, ic_L, ic_R, m_L, m_R, q0_L_out, q0_R_out] = get_local_RC_and_ICs(C_L_base, C_R_base, dz, dy, roll_deg, pivot_z, q0_L, q0_R, K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options, K_init_L, K_init_R)
    % Kis perturbáció a lokális deriváláshoz (+1 és -1 mm heave Z irányban)
    [K_0_L, K_0_R, WC_0_L, WC_0_R, CP_0_L, CP_0_R, q0_L_out, q0_R_out] = solve_state(C_L_base, C_R_base, dz, dy, roll_deg, pivot_z, q0_L, q0_R, K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options);
    [K_m_L, K_m_R, WC_m_L, WC_m_R] = solve_state(C_L_base, C_R_base, dz-1, dy, roll_deg, pivot_z, q0_L, q0_R, K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options);
    [K_p_L, K_p_R, WC_p_L, WC_p_R] = solve_state(C_L_base, C_R_base, dz+1, dy, roll_deg, pivot_z, q0_L, q0_R, K_loc_L, K_loc_R, WC_init_L, WC_init_R, L0_L, L0_R, options);
    
    [ic_L, m_L] = get_side_IC_local(K_0_L, K_m_L, K_p_L, WC_0_L, WC_m_L, WC_p_L, CP_0_L, K_init_L, dz);
    [ic_R, m_R] = get_side_IC_local(K_0_R, K_m_R, K_p_R, WC_0_R, WC_m_R, WC_p_R, CP_0_R, K_init_R, dz);
    
    % Roll center a két virtuális lengőkar meredekség metszéspontjából
    A = [m_L, -1; m_R, -1];
    B = [m_L * CP_0_L(2) - CP_0_L(3); m_R * CP_0_R(2) - CP_0_R(3)];
    if abs(det(A)) > 1e-6
        RC_yz = A \ B; rc_y = RC_yz(1); rc_z = RC_yz(2);
    else
        rc_y = 0; rc_z = CP_0_L(3);
    end
    rc_x = (CP_0_L(1) + CP_0_R(1)) / 2;
end

function [ic, m] = get_side_IC_local(K_0, K_m, K_p, WC_0, WC_m, WC_p, CP, K_init, dz_c)
    A0 = K_init - mean(K_init, 1);
    
    B0_m = K_m - mean(K_m, 1);
    [U_m, ~, V_m] = svd(A0' * B0_m); R_m = V_m * U_m'; if det(R_m)<0, V_m(:,3)=-V_m(:,3); R_m = V_m * U_m'; end
    
    B0_p = K_p - mean(K_p, 1);
    [U_p, ~, V_p] = svd(A0' * B0_p); R_p = V_p * U_p'; if det(R_p)<0, V_p(:,3)=-V_p(:,3); R_p = V_p * U_p'; end
    
    R_delta = R_p * R_m';
    w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
    w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
    w_z = (R_delta(2,1) - R_delta(1,2)) / 2;
    
    p11_m = WC_m' + [0; 0; dz_c - 1];
    p11_p = WC_p' + [0; 0; dz_c + 1];
    p11_c = WC_0' + [0; 0; dz_c];
    
    v_11 = p11_p - p11_m;
    cp_x = CP(1); cp_y = CP(2); cp_z = CP(3);
    
    if abs(w_x) > 1e-10
        y_ic = p11_c(2) + (-v_11(3) + w_y*(cp_x - p11_c(1))) / w_x;
        z_ic = p11_c(3) + ( v_11(2) + w_z*(cp_x - p11_c(1))) / w_x;
        ic = [cp_x, y_ic, z_ic] - [0, 0, dz_c];
        m = (ic(3) - cp_z) / (ic(2) - cp_y);
    else
        ic = [cp_x, cp_y + sign(v_11(2))*1e6, cp_z + 1e6];
        if abs(v_11(3)) > 1e-10
            m = -v_11(2) / v_11(3);
        else
            m = 0;
        end
    end
end

function F = calc_link_errors(q, C_curr, K_loc, WC_init, L0)
    WC = [q(1), q(2), WC_init(3)];
    R = euler_to_rot(q(3), q(4), q(5));
    F = zeros(5,1);
    for i = 1:5
        K_global = WC' + R * K_loc(i,:)';
        F(i) = norm(K_global' - C_curr(i,:)) - L0(i);
    end
end

function R = euler_to_rot(rx, ry, rz)
    Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
    Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
    Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
    R = Rz * Ry * Rx;
end

function draw_suspension(ax, C, K, link_col, upr_col)
    for i = 1:5
        if i == 5, col = 'r'; else, col = link_col; end 
        plot3(ax, [C(i,1), K(i,1)], [C(i,2), K(i,2)], [C(i,3), K(i,3)], '-', 'Color', col, 'LineWidth', 3);
    end
    plot3(ax, [K(1,1), K(2,1), K(3,1), K(4,1), K(5,1), K(1,1)], ...
              [K(1,2), K(2,2), K(3,2), K(4,2), K(5,2), K(1,2)], ...
              [K(1,3), K(2,3), K(3,3), K(4,3), K(5,3), K(1,3)], '-', 'Color', upr_col, 'LineWidth', 2);
    scatter3(ax, C(:,1), C(:,2), C(:,3), 40, 'k', 'filled');
    scatter3(ax, K(:,1), K(:,2), K(:,3), 40, 'b', 'filled');
end

function draw_tire(ax, center, normal, radius)
    width = 200;
    normal = normal / norm(normal);
    theta = linspace(0, 2*pi, 30);
    v = null(normal(:)');
    circle_pts = radius * (v(:,1)*cos(theta) + v(:,2)*sin(theta));
    pts1 = center(:) + normal(:)*(width/2) + circle_pts;
    pts2 = center(:) - normal(:)*(width/2) + circle_pts;
    fill3(ax, pts1(1,:), pts1(2,:), pts1(3,:), [0.2 0.2 0.2], 'FaceAlpha', 0.08);
    fill3(ax, pts2(1,:), pts2(2,:), pts2(3,:), [0.2 0.2 0.2], 'FaceAlpha', 0.08);
    surf(ax, [pts1(1,:); pts2(1,:)], [pts1(2,:); pts2(2,:)], [pts1(3,:); pts2(3,:)], 'FaceColor', [0.1 0.1 0.1], 'EdgeColor', 'none', 'FaceAlpha',0.08);
end

function draw_ic_line(ax, cp, ic, color)
    if norm(ic - cp) > 1e4
        dir = (ic - cp) / norm(ic - cp);
        end_pt = cp + dir * 2000;
        plot3(ax, [cp(1), end_pt(1)], [cp(2), end_pt(2)], [cp(3), end_pt(3)], [color '--'], 'LineWidth', 1.5);
    else
        plot3(ax, [cp(1), ic(1)], [cp(2), ic(2)], [cp(3), ic(3)], [color '--'], 'LineWidth', 1.5);
        plot3(ax, ic(1), ic(2), ic(3), 'o', 'MarkerFaceColor', color, 'MarkerEdgeColor', 'k', 'MarkerSize', 6);
    end
end

%% ------------------- MULTILINK PUSHROD BEKÖTÉS -------------------

function push_link = parse_pushrod_mount(pushrod_mount)
% 'upright' -> 0 (a pushrod a csonkállványon), 'linkN' -> N (a pushrod az N. linken)
    pm = lower(strrep(strtrim(char(pushrod_mount)), ' ', ''));
    if strcmp(pm, 'upright')
        push_link = 0;
    else
        push_link = sscanf(pm, 'link%d');
        if isempty(push_link) || push_link < 1 || push_link > 5
            error('pushrod_mount csak ''upright'' vagy ''link1''...''link5'' lehet (most: %s)!', pushrod_mount);
        end
    end
    if push_link == 0
        disp('Pushrod bekötés: csonkállvány (upright).');
    else
        fprintf('Pushrod bekötés: Link %d.\n', push_link);
    end
end

function P10 = pushrod_point(push_link, P10_s, WC_init, WC_cur, R_cur, C_s, K_s, C_cur, K_cur)
% A pushrod alsó pontjának aktuális helye.
%  upright: mereven együtt mozog a csonkállvánnyal (ugyanaz a transzformáció, mint a K pontoké)
%  linkN  : a link irányváltozásának minimális forgatásával viszi (a link saját tengely körüli
%           elfordulása határozatlan; a link tengelyén fekvő pontra pontos)
    if push_link == 0
        P10 = WC_cur(:)' + (R_cur * (P10_s(:) - WC_init(:)))';
    else
        k  = push_link;
        Rl = rot_between(K_s(k,:) - C_s(k,:), K_cur(k,:) - C_cur(k,:));
        P10 = C_cur(k,:) + (Rl * (P10_s(:) - C_s(k,:)'))';
    end
end

%% =====================================================================
%% KÖZÖS SEGÉDFÜGGVÉNYEK: EXCEL / ROCKER / ARB (U-bar, Z-bar) / TENGELYHATÁR
%% (mind a 4 kódban azonos blokk – a kinematikai szolvert nem befolyásolják,
%%  a megoldott állapotokból utólag számolnak)
%% =====================================================================

function [f_out, s_out] = resolve_src(f_in, s_in, f_parent, s_parent)
% Üres fájlnév ('') -> a "szülő" fájl; ha a lap is üres, a szülő lapja.
    f_out = f_in; s_out = s_in;
    if isempty(f_out)
        f_out = f_parent;
        if isempty(s_out), s_out = s_parent; end
    end
end

function T = read_pts_table(file, sheet)
% Name | X | Y | Z tábla beolvasása (sheet = '' -> első munkalap).
    if exist(file, 'file') ~= 2
        error('A fájl nem található: %s\nKérlek tedd a munkakönyvtárba az Excel-t a template formátumában!', file);
    end
    if isempty(sheet)
        T = readtable(file);
        disp(['Pontok betöltése: ', file]);
    else
        T = readtable(file, 'Sheet', sheet);
        disp(['Pontok betöltése: ', file, ' [', sheet, ']']);
    end
    if ~all(ismember({'Name', 'X', 'Y', 'Z'}, T.Properties.VariableNames))
        error('A(z) %s táblában Name | X | Y | Z oszlopok kellenek!', file);
    end
    T.Name = strtrim(string(T.Name));
end

function pos = get_pt(T, names)
% Pont beolvasása név alapján (kis/nagybetű és szélső szóközök nem számítanak).
% names: egy név (char), vagy alternatív nevek cellája ({'A','B'}).
    if ischar(names) || isstring(names), names = cellstr(names); end
    tn  = strtrim(string(T.Name));
    idx = [];
    for q = 1:numel(names)
        idx = find(strcmpi(tn, strtrim(names{q})), 1);
        if ~isempty(idx), break; end
    end
    if isempty(idx)
        error('Hiányzó pont az Excelben: %s', strjoin(names, ' / '));
    end
    pos = [T.X(idx), T.Y(idx), T.Z(idx)];
end

function tf = has_pt(T, names)
    if ischar(names) || isstring(names), names = cellstr(names); end
    tn = strtrim(string(T.Name));
    tf = false;
    for q = 1:numel(names)
        if any(strcmpi(tn, strtrim(names{q}))), tf = true; return; end
    end
end

function pos = opt_pt(T, names, default_pos)
    if has_pt(T, names), pos = get_pt(T, names); else, pos = default_pos; end
end

function p = mirror_y(p)
    p(2) = -p(2);
end

%% ----------------------------- ROCKER ---------------------------------

function rk = load_rocker(T)
% Rocker / pushrod / damper pontok (bal oldal) – nevek mint a DAA_Rear-ben.
    rk.push_rocker    = get_pt(T, 'Pushrod Rocker');
    rk.push_upright   = get_pt(T, 'Pushrod Upright');
    rk.axis           = get_pt(T, {'Rocker Axis', 'Rocker Pivot Lower'});
    rk.center         = get_pt(T, {'Rocker Center', 'Rocker Pivot Center'});
    rk.damper_rocker  = get_pt(T, 'Damper Rocker');
    rk.damper_chassis = get_pt(T, 'Damper Chassis');
end

function rkR = mirror_rocker(rk)
    rkR = rk;
    f = fieldnames(rk);
    for i = 1:numel(f), rkR.(f{i}) = mirror_y(rk.(f{i})); end
end

function R = roll_matrix(roll_deg)
% Ugyanaz a roll mátrix, mint a szolverekben (X tengely körül).
    r = deg2rad(roll_deg);
    R = [1 0 0; 0 cos(r) -sin(r); 0 sin(r) cos(r)];
end

function p = chassis_tf(p0, dz, Rroll, pivot_z)
% Vázhoz rögzített pont aktuális helye: heave (Z - dz), majd roll a pivot körül
% – pontosan úgy, ahogy a szolverek a váz pontjait mozgatják.
    p = p0(:); p(3) = p(3) - dz;
    p = (Rroll * (p - [0; 0; pivot_z]) + [0; 0; pivot_z])';
end

function w = rodrigues(v, a, t)
% v vektor elforgatása az (origón átmenő) a tengely körül t [rad] szöggel.
    v = v(:); a = a(:) / norm(a);
    w = (v * cos(t) + cross(a, v) * sin(t) + a * (a' * v) * (1 - cos(t)))';
end

function ang = signed_angle_deg(v0, v1, a)
% v0 -> v1 előjeles szöge az a tengely körül (jobbkéz-szabály) [fok].
    a  = a(:) / norm(a);
    v0 = v0(:) - a * (a' * v0(:));
    v1 = v1(:) - a * (a' * v1(:));
    ang = rad2deg(atan2(a' * cross(v0, v1), v0' * v1));
end

function t = solve_circle_angle(P0, c, a, target, L, t_guess)
% P(t) = c + Rot(a,t)*(P0 - c) pont olyan t szöge, amelynél |P(t) - target| = L.
% Több gyök esetén a t_guess-hez legközelebbit adja (folytonos ág).
    a = a(:)' / norm(a);
    v = P0(:)' - c(:)';
    f = @(tt) norm(c(:)' + rodrigues(v, a, tt) - target(:)') - L;
    grid = t_guess + deg2rad(-90:2:90);
    fv = arrayfun(f, grid);
    t = NaN;
    for i = 1:numel(grid) - 1
        if fv(i) == 0
            r = grid(i);
        elseif sign(fv(i)) ~= sign(fv(i+1))
            r = fzero(f, [grid(i) grid(i+1)]);
        else
            continue;
        end
        if isnan(t) || abs(r - t_guess) < abs(t - t_guess), t = r; end
    end
    if isnan(t)
        [fmin, k] = min(abs(fv)); t = grid(k);
        warning('Rocker/ARB lánc nem zárható (maradék %.3g mm) – ellenőrizd a pontokat!', fmin);
    end
end

function [RK, rock_ang] = solve_rocker_state(rk, L_push, P10_cur, dz, Rroll, pivot_z)
% Multilinkhez: a rocker 1 DOF forgása a (Rocker Axis -> Rocker Center) tengely körül,
% úgy, hogy a pushrod hossza állandó maradjon.
% RK sorai: 1 axis, 2 center, 3 pushrod-rocker, 4 damper-rocker, 5 damper-chassis, 6 pushrod-upright
    A     = chassis_tf(rk.axis,          dz, Rroll, pivot_z);
    C     = chassis_tf(rk.center,        dz, Rroll, pivot_z);
    a     = C - A;
    P9_0  = chassis_tf(rk.push_rocker,   dz, Rroll, pivot_z);
    P13_0 = chassis_tf(rk.damper_rocker, dz, Rroll, pivot_z);
    th    = solve_circle_angle(P9_0, C, a, P10_cur, L_push, 0);
    P9    = C + rodrigues(P9_0  - C, a, th);
    P13   = C + rodrigues(P13_0 - C, a, th);
    P14   = chassis_tf(rk.damper_chassis, dz, Rroll, pivot_z);
    RK = [A; C; P9; P13; P14; P10_cur(:)'];
    rock_ang = rad2deg(th);
end

function ang = rocker_angle_deg(RK, P9_static, dz, Rroll, pivot_z)
% Rocker elfordulása a vázhoz képest (DAA: a szolver által adott pontokból).
    C  = RK(2,:);
    a  = RK(2,:) - RK(1,:);
    v0 = chassis_tf(P9_static, dz, Rroll, pivot_z) - C;
    v1 = RK(3,:) - C;
    ang = signed_angle_deg(v0, v1, a);
end

function D = rocker_carry(RK_static, RK_cur, D_static)
% Rockerhez mereven kötött pont (pl. ARB droplink-rocker) aktuális helye:
% Kabsch illesztés a rocker 4 pontjára (axis, center, pushrod-rocker, damper-rocker).
    A = RK_static(1:4,:); B = RK_cur(1:4,:);
    muA = mean(A, 1); muB = mean(B, 1);
    H = (A - muA)' * (B - muB);
    [U, ~, V] = svd(H); R = V * U';
    if det(R) < 0, V(:,3) = -V(:,3); R = V * U'; end
    D = (R * (D_static(:) - muA(:)))' + muB;
end

function R = rot_between(u, v)
% Minimális forgatás u iránytól v irányig (Rodrigues).
    u = u(:) / norm(u); v = v(:) / norm(v);
    w = cross(u, v); s = norm(w); c = u' * v;
    if s < 1e-12, R = eye(3); return; end
    W = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
    R = eye(3) + W + W * W * ((1 - c) / s^2);
end

%% ------------------------------- ARB ----------------------------------
% Pontok (Name oszlop):
%   ARB Droplink Rocker        – droplink vége a rockeren (bal)        [régi név: ARB Rocker]
%   ARB Droplink Blade         – droplink vége a blade-en (bal)        [régi név: ARB Blade]
%   ARB Blade Torsion Bar      – blade bekötése a torziós rúdba (bal)
%   ARB Droplink Rocker Right  – opcionális (alap: bal tükrözése, mert a rocker tükrözött)
%   ARB Droplink Blade Right   – U: opcionális (alap: tükrözés) | Z: KÖTELEZŐ
%   ARB Blade Torsion Bar Right– U: opcionális (alap: tükrözés) | Z: KÖTELEZŐ
%   ARB Torsion Axis           – opcionális 2. pont a torziós tengelyen (csak ha a két
%                                blade-bekötés egybeesik, pl. egy középső csapágyas Z-bar)
% Torziós tengely: (ARB Blade Torsion Bar) -> (ARB Blade Torsion Bar Right) egyenes.
% Mindkét blade a közös tengely körül fordul, a droplink hossza állandó;
% csavarodás: twist = phi_bal - phi_jobb (ugyanarra a tengelyirányra mérve).
%   U-bar: keresztirányú rúd, a blade-ek azonos irányba néznek -> heave-ben phiL = phiR (twist ~0),
%          roll-ban ellentétesek -> csavarodik.
%   Z-bar: a rúd (jellemzően hosszirányú) két végén a blade-ek ellentétes irányba állnak
%          (pl. egyik fel, másik le), a droplinkek ~keresztirányúak -> szintén csak akkor
%          csavarodik, ha a két kerék ellentétesen mozog.

function arb = load_arb(arb_type, file, sheet)
    arb = struct('has', false, 'type', upper(strtrim(char(arb_type))));
    if isempty(arb.type) || strcmp(arb.type, 'NONE')
        disp('ARB kikapcsolva (arb_type = ''none'').');
        return;
    end
    if ~any(strcmp(arb.type, {'U', 'Z'}))
        error('arb_type csak ''none'', ''U'' vagy ''Z'' lehet (most: %s)!', arb_type);
    end
    if exist(file, 'file') ~= 2
        warning('ARB fájl nem található (%s) – ARB nélkül számol.', file);
        return;
    end
    T = read_pts_table(file, sheet);

    nmD = {'ARB Droplink Rocker', 'ARB Rocker'};
    nmB = {'ARB Droplink Blade', 'ARB Blade'};
    nmT = {'ARB Blade Torsion Bar', 'ARB Torsion Bar'};
    if ~(has_pt(T, nmD) && has_pt(T, nmB) && has_pt(T, nmT))
        warning('ARB pontok hiányoznak (%s) – ARB nélkül számol.', file);
        return;
    end
    arb.D_L = get_pt(T, nmD);
    arb.B_L = get_pt(T, nmB);
    arb.T_L = get_pt(T, nmT);

    nmBR = {'ARB Droplink Blade Right'};
    nmTR = {'ARB Blade Torsion Bar Right', 'ARB Torsion Bar Right'};
    if strcmp(arb.type, 'Z') && ~(has_pt(T, nmBR) && has_pt(T, nmTR))
        error(['Z-bar esetén meg kell adni a jobb oldali pontokat is: ' ...
               '''ARB Droplink Blade Right'' és ''ARB Blade Torsion Bar Right''!']);
    end
    arb.D_R = opt_pt(T, {'ARB Droplink Rocker Right', 'ARB Rocker Right'}, mirror_y(arb.D_L));
    arb.B_R = opt_pt(T, nmBR, mirror_y(arb.B_L));
    arb.T_R = opt_pt(T, nmTR, mirror_y(arb.T_L));

    if has_pt(T, 'ARB Torsion Axis')
        ax = get_pt(T, 'ARB Torsion Axis') - arb.T_L;
    else
        ax = arb.T_R - arb.T_L;
    end
    if norm(ax) < 1e-6
        error('A torziós tengely nem definiált: a két blade-bekötés egybeesik – add meg az ''ARB Torsion Axis'' pontot!');
    end
    arb.axis_dir = ax / norm(ax);

    off = norm(cross(arb.T_R - arb.T_L, arb.axis_dir));
    if off > 0.5
        warning('Az ''ARB Blade Torsion Bar Right'' pont %.2f mm-re van a torziós tengelytől!', off);
    end
    arb.L_drop_L = norm(arb.D_L - arb.B_L);
    arb.L_drop_R = norm(arb.D_R - arb.B_R);
    arb.has = true;
    fprintf('ARB betöltve: %s-bar | torziós tengely = [%.3f %.3f %.3f] | droplink L/R = %.1f / %.1f mm\n', ...
        arb.type, arb.axis_dir, arb.L_drop_L, arb.L_drop_R);
end

function [Parb, phiL, phiR, twist] = solve_arb_state(arb, D_L, D_R, dz, Rroll, pivot_z)
% Parb sorai: 1 D_L, 2 B_L, 3 T_L, 4 D_R, 5 B_R, 6 T_R
    a   = (Rroll * arb.axis_dir(:))';
    TL  = chassis_tf(arb.T_L, dz, Rroll, pivot_z);
    TR  = chassis_tf(arb.T_R, dz, Rroll, pivot_z);
    BL0 = chassis_tf(arb.B_L, dz, Rroll, pivot_z);
    BR0 = chassis_tf(arb.B_R, dz, Rroll, pivot_z);
    pL  = solve_circle_angle(BL0, TL, a, D_L, arb.L_drop_L, 0);
    pR  = solve_circle_angle(BR0, TR, a, D_R, arb.L_drop_R, 0);
    BL  = TL + rodrigues(BL0 - TL, a, pL);
    BR  = TR + rodrigues(BR0 - TR, a, pR);
    Parb  = [D_L(:)'; BL; TL; D_R(:)'; BR; TR];
    phiL  = rad2deg(pL);
    phiR  = rad2deg(pR);
    twist = phiL - phiR;
end

function arb_report(arb, tw_heave, tw_roll, roll_range)
% Ellenőrzés: egy anti-roll bar heave-ben (közel) ne csavarodjon, roll-ban igen.
    if ~arb.has, return; end
    mh = max(abs(tw_heave(:)));
    mr = max(abs(tw_roll(:)));
    if numel(roll_range) > 1
        pf = polyfit(roll_range(:), tw_roll(:), 1); k = pf(1);
    else
        k = NaN;
    end
    fprintf('ARB (%s-bar): max |twist| tiszta heave-ben = %.3f°, tiszta roll-ban = %.3f° (%.3f °twist / °roll)\n', ...
        arb.type, mh, mr, k);
    if mr > 1e-6 && mh > 0.25 * mr
        warning(['A stabilizátor heave-ben is jelentősen csavarodik (%.2f° vs %.2f° roll-ban) – ' ...
                 'ellenőrizd a blade-ek irányát / a torziós rúd helyzetét (U vs Z)!'], mh, mr);
    end
end

%% --------------------------- RAJZ / TENGELY ----------------------------

function [xl, yl, zl] = auto_axis_limits(P, WC, wheel_r, wheel_w)
% Tengelyhatárok a felfüggesztés összes állapotának pontjaiból + kerekek + padló (Z=0).
    P  = P(all(isfinite(P), 2), :);
    WC = WC(all(isfinite(WC), 2), :);
    ext = [WC + [wheel_r 0 0]; WC - [wheel_r 0 0]; WC + [0 0 wheel_r]; ...
           WC + [0 wheel_w/2 0]; WC - [0 wheel_w/2 0]];
    P  = [P; ext];
    mn = min(P, [], 1); mx = max(P, [], 1);
    mn(3) = min(mn(3), 0);          % a padló mindig látszódjon
    m = 0.08 * max(mx - mn) + 20;   % margó
    xl = [mn(1) - m, mx(1) + m];
    yl = [mn(2) - m, mx(2) + m];
    zl = [mn(3) - m, mx(3) + m];
end

function draw_rocker(ax, RK, D)
% RK: [axis; center; pushrod-rocker; damper-rocker; damper-chassis; pushrod-upright]
    plot3(ax, RK([1 2],1), RK([1 2],2), RK([1 2],3), 'k:', 'LineWidth', 1.5);
    plot3(ax, RK([2 3 4 2],1), RK([2 3 4 2],2), RK([2 3 4 2],3), '-', 'Color', [1 0.5 0], 'LineWidth', 2.5);
    if nargin > 2 && ~isempty(D)
        plot3(ax, [RK(2,1) D(1)], [RK(2,2) D(2)], [RK(2,3) D(3)], '-', 'Color', [1 0.5 0], 'LineWidth', 2.5);
    end
    plot3(ax, RK([3 6],1), RK([3 6],2), RK([3 6],3), 'g-', 'LineWidth', 2);   % pushrod
    plot3(ax, RK([4 5],1), RK([4 5],2), RK([4 5],3), 'm-', 'LineWidth', 2);   % damper
    scatter3(ax, RK(:,1), RK(:,2), RK(:,3), 20, [1 0.5 0], 'filled');
end

function draw_arb(ax, Parb)
% Parb: [D_L; B_L; T_L; D_R; B_R; T_R]
    plot3(ax, Parb([1 2],1), Parb([1 2],2), Parb([1 2],3), 'c-', 'LineWidth', 2);           % droplink L
    plot3(ax, Parb([4 5],1), Parb([4 5],2), Parb([4 5],3), 'c-', 'LineWidth', 2);           % droplink R
    plot3(ax, Parb([2 3],1), Parb([2 3],2), Parb([2 3],3), 'b-', 'LineWidth', 3);           % blade L
    plot3(ax, Parb([5 6],1), Parb([5 6],2), Parb([5 6],3), 'b-', 'LineWidth', 3);           % blade R
    plot3(ax, Parb([3 6],1), Parb([3 6],2), Parb([3 6],3), '-', 'Color', [0.3 0.3 0.3], 'LineWidth', 4); % torziós rúd
    scatter3(ax, Parb(:,1), Parb(:,2), Parb(:,3), 20, 'c', 'filled');
end
