function base_program_rear_left_multi
    % clc
    % clear all
    % close all
    
    %% 1. BEKÖTÉSI PONTOK – Excelből olvasás
    input_excel_file = 'Multi_Points_Rear.xlsx';   % <-- ide írd a fájlnevedet

    if exist(input_excel_file, 'file') ~= 2
        error('A fájl nem található: %s\nKérlek tedd a munkakönyvtárba az Excel-t a fenti formátumban!', input_excel_file);
    end

    disp(['Pontok betöltése az Excelből: ', input_excel_file]);
    T_in = readtable(input_excel_file);

    C = zeros(5,3);
    K = zeros(5,3);

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

        C(i,:) = [T_in.X(idx_c), T_in.Y(idx_c), T_in.Z(idx_c)];
        K(i,:) = [T_in.X(idx_k), T_in.Y(idx_k), T_in.Z(idx_k)];
    end

    % Wheel Center
    idx_wc = find(strcmpi(T_in.Name, 'Wheel Center') | strcmpi(T_in.Name, 'WheelCenter'), 1);
    if ~isempty(idx_wc)
        WC_init = [T_in.X(idx_wc), T_in.Y(idx_wc), T_in.Z(idx_wc)];
    else
        warning('Wheel Center nem található az Excelben, alapértelmezett érték használata.');
        WC_init = [0, 600, 193];
    end

    %% 1a. F1 2026 SZABÁLYZAT (Section C10) – ugyanazok a beállítások, mint az optimalizálóban
    % Az alapértékek szabálypontonként a f1_rules_2026() függvényben vannak (a fájl végén).
    F1 = f1_rules_2026('rear');        % 'front' | 'rear'  (ez a hátsó multilink)
    F1.RefPlaneZ       = 95;           % [mm] az F1 Z=0 referenciasík magassága a talaj felett (Legality Setup)
    F1.Rim.InnerRadius = 215;          % [mm] a felni belső (hordó) sugara – CAD / RV-R-RIM-MIN
    F1.TyreWidth       = 375;          % [mm] 2026 hátsó gumi szélessége – CSAK a rajzhoz (ellenőrizd a Pirelli adatlapon)
    % F1.Drum.Enable = true; F1.Drum.Radius = ...; F1.Drum.YW = [..., ...];   % C10.3.4c / C3.14.2
    % F1.NoMountBox  = [xmin xmax; ymin ymax; zmin zmax];                    % C10.3.10: PU-ra nem köthet
    % F1.Enable = false;               % F1 kényszerek ki (eredeti FS működés)

    if F1.Enable
        TireRadius = F1.TyreRadius;    % Pirelli 2026 hátsó Ø710
    else
        TireRadius = WC_init(3);       % vagy írd be fixen: TireRadius = 193;
    end

    % === Rocker pontok Excelből (Optim_Rocker_Multi.xlsx) ===
    rocker_excel_file = 'Optim_Rocker_Multi_Rear.xlsx';
    if exist(rocker_excel_file, 'file') ~= 2
        error('A fájl nem található: %s\nKérlek tedd a munkakönyvtárba az Excel-t!', rocker_excel_file);
    end
    disp(['Rocker pontok betöltése: ', rocker_excel_file]);
    T_rocker = readtable(rocker_excel_file);

    function pos = get_pt(T, name)
        idx = find(strcmpi(T.Name, name), 1);
        if isempty(idx)
            error('Hiányzó pont az Excelben: %s', name);
        end
        pos = [T.X(idx), T.Y(idx), T.Z(idx)];
    end

    pushrod_upright = get_pt(T_rocker, 'Pushrod Upright');
    pushrod_rocker  = get_pt(T_rocker, 'Pushrod Rocker');
    rocker_center   = get_pt(T_rocker, 'Rocker Center');
    rocker_axis     = get_pt(T_rocker, 'Rocker Axis');
    damper_rocker   = get_pt(T_rocker, 'Damper Rocker');
    damper_chassis  = get_pt(T_rocker, 'Damper Chassis');
    
    % Struct tömb az ábrázoláshoz (base_program_front_left struktúra szerint)
    points = struct('name', {}, 'pos', {}, 'fixed', {});
    
    points(1).name  = 'Front Left Link 1 Chassis';
    points(1).pos   = C(1,:);
    points(1).fixed = true;
    
    points(2).name  = 'Front Left Link 1 Upright';
    points(2).pos   = K(1,:);
    points(2).fixed = false;
    
    points(3).name  = 'Front Left Link 2 Chassis';
    points(3).pos   = C(2,:);
    points(3).fixed = true;
    
    points(4).name  = 'Front Left Link 2 Upright';
    points(4).pos   = K(2,:);
    points(4).fixed = false;
    
    points(5).name  = 'Front Left Link 3 Chassis';
    points(5).pos   = C(3,:);
    points(5).fixed = true;
    
    points(6).name  = 'Front Left Link 3 Upright';
    points(6).pos   = K(3,:);
    points(6).fixed = false;
    
    points(7).name  = 'Front Left Link 4 Chassis';
    points(7).pos   = C(4,:);
    points(7).fixed = true;
    
    points(8).name  = 'Front Left Link 4 Upright';
    points(8).pos   = K(4,:);
    points(8).fixed = false;
    
    points(9).name  = 'Front Left Link 5 Chassis';
    points(9).pos   = C(5,:);
    points(9).fixed = false;
    
    points(10).name = 'Front Left Link 5 Upright';
    points(10).pos  = K(5,:);
    points(10).fixed = false;
    
    points(11).name = 'Front Left Wheel Center';
    points(11).pos  = WC_init;
    points(11).fixed = false;

    % Rocker / Pushrod / Damper pontok (Excelből)
    points(12).name = 'Front left pushrod rocker';
    points(12).pos  = pushrod_rocker;
    points(12).fixed = false;

    points(13).name = 'Front left pushrod upright';
    points(13).pos  = pushrod_upright;
    points(13).fixed = false;

    points(14).name = 'Front left rocker axis';
    points(14).pos  = rocker_axis;
    points(14).fixed = true;

    points(15).name = 'Front left rocker center';
    points(15).pos  = rocker_center;
    points(15).fixed = true;

    points(16).name = 'Front left damper rocker';
    points(16).pos  = damper_rocker;
    points(16).fixed = false;

    points(17).name = 'Front left damper chassis';
    points(17).pos  = damper_chassis;
    points(17).fixed = true;

    % Kezdeti pushrod hossz (kényszerhez)
    dist_pushrod = norm(pushrod_rocker - pushrod_upright);

    % --- ÜTKÖZÉS ÉS VIZUALIZÁCIÓ PARAMÉTEREI (= optimalizáló) ---
    Collision.rod_diameter = [20, 20, 20, 20, 12, 16]; % Link1..4, Tie rod, Pushrod
    Collision.rod_names    = {'Link 1', 'Link 2', 'Link 3', 'Link 4', 'Link 5 (tie rod)', 'Pushrod'};
    Collision.skip_pairs   = zeros(0, 2);               % multilink: nincs közös csuklópontú pár
    Collision.min_clearance = 5;                        % [mm] ugyanaz, mint az optimalizálóban

    % Motor (Henger, mm)
    % Collision.motor_center = [0, 546.6, 193]; % A henger középpontja
    % Collision.motor_radius = 48;            % A henger sugara (írd be a valós értéket)
    % Collision.motor_length = 160.2;          % A henger teljes hossza
    % Collision.motor_axis   = [0, 1, 0];     % A henger orientációja (pl. Y-tengely mentén fekszik)

    Collision.motor_radius = 48;             % A henger sugara
    Collision.motor_length = 160.2;          % A henger teljes hossza
    Collision.motor_y_offset = -63.4;        % Eltolás a kerékközépponttól a tengely mentén (546.6 - 610)

    % Felni paraméterei (FS)
    Collision.rim_inner_radius = 119;
    Collision.rim_outer_radius = 124.5;
    Collision.rim_width        = 195;
    Collision.rim_y_offset     = 0;

    % --- F1 2026: felni a C10.7.2 szerint, nincs agymotor (felülírja a fenti FS értékeket) ---
    if F1.Enable
        Collision.use_motor        = false;
        Collision.rim_inner_radius = F1.Rim.InnerRadius;
        Collision.rim_outer_radius = F1.Rim.OuterRadius;    % Ø496 perem
        Collision.rim_width        = F1.Rim.Width;          % 420.3 (hátsó)
        Collision.rim_y_offset     = F1.Rim.CenterOffset;
        Collision.wheel_axis0      = f1_wheel_axes(F1);     % Legality Setup camber (-1° hátul)
    else
        Collision.use_motor   = true;
        Collision.wheel_axis0 = [0; 1; 0];
    end
    Collision.steer_range = 0;               % hátsó tengely: az F1 kormányzási ellenőrzés kimarad

    % Gumi / felni rajz méretei
    if F1.Enable
        Tyre.R_outer  = F1.TyreRadius;       % Ø710
        Tyre.R_rim    = F1.Rim.BeadRadius;   % Ø462.5 (18")
        Tyre.width    = F1.TyreWidth;
        Tyre.rim_half = F1.Rim.Width / 2;
    else
        Tyre.R_outer  = TireRadius;
        Tyre.R_rim    = 254 / 2;
        Tyre.width    = 191;
        Tyre.rim_half = 0.7 * 254 / 2;
    end

    % --- F1 2026 megfelelőség a beolvasott (kézzel szerkesztett) Excel geometrián ---
    f1_check_wheel_static(WC_init, F1, F1.Axle);           % C10.1c, C10.10.1, gumiméret
    f1_check_outboard_point(pushrod_upright, WC_init, F1, 'Pushrod Upright', F1.PushrodOnMember);
    fprintf(['[Méretek] Felni: perem Ø%.1f, ülék Ø%.1f, belső r = %.1f, szélesség %.1f mm | ' ...
             'Gumi: Ø%.1f x %.1f mm | WC Y = %.1f mm (nyomtáv ~ %.1f mm)\n'], ...
        2*Collision.rim_outer_radius, 2*Tyre.R_rim, Collision.rim_inner_radius, Collision.rim_width, ...
        2*Tyre.R_outer, Tyre.width, WC_init(2), 2*abs(WC_init(2)));
    [~, ~, f1_names, f1_vals] = f1_nonlcon_ML([C(:); K(:)], WC_init, F1, Collision);
    f1_report(f1_names, f1_vals, ['Excel geometria (', input_excel_file, ')']);
    
    %% 2. SZIMULÁCIÓS TARTOMÁNY ÉS MÁTRIXOK INICIALIZÁLÁSA
    travel_range = -15:1:15;    % +- 30 mm wheel travel
    rack_range   = zeros(1, 3);      % +- 20 mm rack travel
    
    num_z = length(travel_range);
    num_r = length(rack_range);
    
    wheel_travel_range = travel_range;
    steering_range     = rack_range;
    
    num_wheel_steps = num_z;
    num_steer_steps = num_r;

    % ============================================================
    % USER INPUTS for anti-dive / anti-squat formula (= optimalizáló Vehicle értékei)
    % ============================================================
    W_wheelbase_mm          = 3000;   % <-- TENGELytáv [mm]  (optimalizáló: Vehicle.Wheelbase)
    front_brake_percent     = 64;     % <-- % front brake bias (0..100)
    rear_drive_percent      = 100;    % <-- % hajtás a hátsó tengelyen (RWD = 100) – anti-squat
    h_CG_SM_static_mm       = 320;    % <-- rugózott tömeg CG magassága statikus állapotban [mm] (optimalizáló: Vehicle.h_CG_SM)
    
    % --- Eredmény Mátrixok Inicializálása ---
    KPI_mat    = zeros(num_z, num_r);
    Caster_mat = zeros(num_z, num_r);
    Scrub_mat  = zeros(num_z, num_r);
    Trail_mat  = zeros(num_z, num_r);
    Camber_mat = zeros(num_z, num_r);
    Toe_mat    = zeros(num_z, num_r);
    AntiDive_mat = zeros(num_z, num_r); % Új mátrix: Anti-dive history
    PhiF_mat     = zeros(num_z, num_r); % Új mátrix: Phi_F angle history
    AntiSquat_mat = zeros(num_z, num_r); % Anti-squat history (optimalizáló képlete)
    PhiR_mat      = zeros(num_z, num_r); % Phi_R angle history
    
    % 3D Pontokat tároló mátrixok (Z, R, [X, Y, Z])
    CP_mat       = zeros(num_z, num_r, 3); % Contact Patch
    FrontIC_mat  = zeros(num_z, num_r, 3); % Front View Instant Center
    SideIC_mat   = zeros(num_z, num_r, 3); % Side View Instant Center
    RC_Z_mat     = zeros(num_z, num_r);    % Roll Center Z (magasság)
    FrontVSA_mat = zeros(num_z, num_r);    % Front Virtual Swing Arm
    SideVSA_mat  = zeros(num_z, num_r);    % Side Virtual Swing Arm
    
    % Állapotok mentéséhez
    K_history    = zeros(num_z, num_r, 5, 3);
    WC_history   = zeros(num_z, num_r, 3);
    R_history    = zeros(num_z, num_r, 3, 3);
    
    % Positions history a vizualizációhoz
    positions_history = zeros(length(points), 3, num_z, num_r);

    % Virtuális kormányzási tengely (a kormányzás pillanatnyi csavartengelye): pont + egységvektor
    SteerAxisP_mat = zeros(num_z, num_r, 3);
    SteerAxisU_mat = zeros(num_z, num_r, 3);
    
    %% 3. MULTILINK KINEMATIKAI SZOLVER (done_3.m számolása)
    options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 10000, 'FunctionTolerance', 1e-200);
    
    L0 = zeros(5,1);
    for i = 1:5
        L0(i) = norm(K(i,:) - C(i,:));
    end
    K_loc = K - WC_init;
    
    disp('Szimuláció indítása (Solver fut... Mátrixok feltöltése folyamatban)');
    
    q0_straight = [WC_init(1), WC_init(2), 0, 0, 0];
    
    for iz = 1:num_z
        dz = travel_range(iz);
    
        % ----- VÁZ ELTOLÁSA (a kerék Z-ben fix marad) -----
        C_moved = C;
        C_moved(:,3) = C(:,3) - dz;
    
        % 1. Egyenes kerék pozíció keresése az aktuális vázhelyzethez
        obj_fun_straight = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
        q0_straight = lsqnonlin(obj_fun_straight, q0_straight, [], [], options);
    
        for ir = 1:num_r
            dy_rack = rack_range(ir);
    
            % Rack elmozdulás a tie rod belső pontján
            C_current = C_moved;
            C_current(5,2) = C_moved(5,2) + dy_rack;
    
            % Szolver futtatása
            q0 = q0_straight;
            obj_fun = @(q) calc_link_errors(q, C_current, K_loc, WC_init, 0, L0);
            q_opt = lsqnonlin(obj_fun, q0, [], [], options);
    
            % Kerékközéppont és Orientáció
            WC_new = [q_opt(1), q_opt(2), WC_init(3)];
            R_mat  = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
    
            K_new = zeros(5,3);
            for i = 1:5
                K_new(i,:) = (WC_new' + R_mat * K_loc(i,:)')';
            end
    
            % ===== CAMBER ÉS TOE =====
            wheel_normal = R_mat * [0; 1; 0];
            Camber_mat(iz, ir) = atand(wheel_normal(3) / wheel_normal(2));
            Toe_mat(iz, ir)    = -atand(wheel_normal(1) / wheel_normal(2));
    
            % ===== DIFFERENCIÁLIS KINEMATIKA (Kormányzási Jacobian) =====
            J = zeros(6,6);
            for i = 1:5
                vec_link = K_new(i,:) - C_current(i,:);
                vec_r    = K_new(i,:) - WC_new;
                J(i,1:3) = vec_link;
                J(i,4:6) = cross(vec_r, vec_link);
            end
            J(6,:) = [0 0 1 0 0 0]; % WC Z sebesség = 0
    
            V_input = zeros(6,1);
            V_input(5) = (K_new(5,2) - C_current(5,2)) * 10; % Tesztsebesség a racken
    
            twist_vector = J \ V_input;
            v_WC  = twist_vector(1:3);
            omega = twist_vector(4:6);
    
            % Irány konzisztencia tartása
            omega_norm = norm(omega);
            U_vec = omega / omega_norm;
            if U_vec(3) < 0
                U_vec = -U_vec;
                omega = -omega;
                v_WC  = -v_WC;
            end
    
            % ===== KPI ÉS CASTER =====
            KPI_mat(iz, ir)    = atand(-U_vec(2) / U_vec(3));
            Caster_mat(iz, ir) = atand(-U_vec(1) / U_vec(3));
    
            % ===== CONTACT PATCH (CP) KISZÁMÍTÁSA =====
            unit_normal = wheel_normal / norm(wheel_normal);
            gravity_dir = [0; 0; -1];
            proj_grav   = gravity_dir - dot(gravity_dir, unit_normal) * unit_normal;
    
            if norm(proj_grav) > 1e-6
                down_dir = proj_grav / norm(proj_grav);
            else
                down_dir = [0; 0; -1];
            end
    
            t_gnd = (0 - WC_new(3)) / down_dir(3);
            cp    = WC_new' + t_gnd * down_dir; 
            CP_mat(iz, ir, :) = cp;
    
            % ===== SCRUB RADIUS ÉS MECH TRAIL =====
            P_isa = WC_new' + cross(omega, v_WC) / (omega_norm^2);
            SteerAxisP_mat(iz, ir, :) = P_isa;     % a tengely egy pontja [mm]
            SteerAxisU_mat(iz, ir, :) = U_vec;     % egységvektor (Z felé mutat)
            v_CP_pure = cross(omega, cp - P_isa);
            
            delta = deg2rad(Toe_mat(iz, ir));
            omega_delta = omega(3);
    
            if abs(omega_delta) > 1e-8
                Scrub_mat(iz, ir) = -(v_CP_pure(1) * cos(delta) + v_CP_pure(2) * sin(delta)) / omega_delta;
                Trail_mat(iz, ir) = (v_CP_pure(1) * sin(delta) - v_CP_pure(2) * cos(delta)) / omega_delta;
            else
                Scrub_mat(iz, ir) = NaN;
                Trail_mat(iz, ir) = NaN;
            end
    
            % ===== ÁLLAPOTOK MENTÉSE =====
            K_history(iz, ir, :, :) = K_new;
            WC_history(iz, ir, :)   = WC_new;
            R_history(iz, ir, :, :) = R_mat;
    
            % Positions history feltöltése (5 link + WC)
            positions_history(1, :, iz, ir)  = C_current(1,:);
            positions_history(2, :, iz, ir)  = K_new(1,:);
            positions_history(3, :, iz, ir)  = C_current(2,:);
            positions_history(4, :, iz, ir)  = K_new(2,:);
            positions_history(5, :, iz, ir)  = C_current(3,:);
            positions_history(6, :, iz, ir)  = K_new(3,:);
            positions_history(7, :, iz, ir)  = C_current(4,:);
            positions_history(8, :, iz, ir)  = K_new(4,:);
            positions_history(9, :, iz, ir)  = C_current(5,:);
            positions_history(10, :, iz, ir) = K_new(5,:);
            positions_history(11, :, iz, ir) = WC_new;

            % --- Rocker / Pushrod / Damper pontok (helyes 1-DOF rocker forgás) ---
            % Chassis-fix pontok: Z eltolás a vázzal
            axis_now   = [rocker_axis(1),   rocker_axis(2),   rocker_axis(3)   - dz];
            center_now = [rocker_center(1), rocker_center(2), rocker_center(3) - dz];
            damp_ch_now= [damper_chassis(1),damper_chassis(2),damper_chassis(3)- dz];
            positions_history(14, :, iz, ir) = axis_now;
            positions_history(15, :, iz, ir) = center_now;
            positions_history(17, :, iz, ir) = damp_ch_now;

            % Pushrod upright: rigid a WC/upright-hoz képest (R_mat * local)
            loc_pu = (pushrod_upright - WC_init)';
            pu_now = (WC_new' + R_mat * loc_pu)';
            positions_history(13, :, iz, ir) = pu_now;

            % Rocker tengely egységvektora
            axis_dir = center_now - axis_now;
            if norm(axis_dir) < 1e-9
                axis_u = [0; 0; 1];
            else
                axis_u = axis_dir(:) / norm(axis_dir);
            end

            % Statikus vektorok a rocker center-től
            v_pr0 = (pushrod_rocker - rocker_center)';  % 3x1
            v_dr0 = (damper_rocker  - rocker_center)';

            % Rodrigues forgatás az axis_u körül
            rot_about = @(v, u, th) v*cos(th) + cross(u,v)*sin(th) + u*dot(u,v)*(1-cos(th));

            % 1-DOF: theta, amivel |pushrod_rocker - pushrod_upright| = dist_pushrod
            rocker_res = @(th) norm(center_now' + rot_about(v_pr0, axis_u, th) - pu_now') - dist_pushrod;

            th0 = 0;
            try
                th_sol = fsolve(rocker_res, th0, optimoptions('fsolve','Display','off','FunctionTolerance',1e-12,'MaxIterations',200));
            catch
                th_sol = 0;
            end

            pr_now = (center_now' + rot_about(v_pr0, axis_u, th_sol))';
            dr_now = (center_now' + rot_about(v_dr0, axis_u, th_sol))';

            positions_history(12, :, iz, ir) = pr_now;   % pushrod rocker
            positions_history(16, :, iz, ir) = dr_now;   % damper rocker (ugyanaz a szög → rigid rocker)
        end
    end
    
    %% 4. INSTANT CENTER ÉS ROLL CENTER KISZÁMÍTÁSA (Kinematikai módszer - done_3.m)
    disp('Instant Center és Roll Center számítása (Kinematikai módszer)...');
    
    A_0 = K;
    muA_0 = mean(A_0, 1);
    A0 = A_0 - muA_0;
    
    instant_axis_dir_history   = zeros(num_z, num_r, 3);
    instant_axis_point_history = zeros(num_z, num_r, 3);
    
    for ir = 1:num_r
        for iz = 1:num_z
            cp = reshape(CP_mat(iz, ir, :), 1, 3);
            cp_x = cp(1); cp_y = cp(2); cp_z = cp(3);
            
            if num_z > 1
                if iz == 1
                    step_m = 1; step_p = 2;
                elseif iz == num_z
                    step_m = num_z - 1; step_p = num_z;
                else
                    step_m = iz - 1; step_p = iz + 1;
                end
                
                dz_m = travel_range(step_m);
                dz_p = travel_range(step_p);
                dz_c = travel_range(iz);
                
                B_m = squeeze(K_history(step_m, ir, :, :));
                muB_m = mean(B_m, 1);
                B0_m  = B_m - muB_m;
                H_m   = A0' * B0_m;
                [U_m, ~, V_m] = svd(H_m);
                R_m = V_m * U_m';
                if det(R_m) < 0, V_m(:,3) = -V_m(:,3); R_m = V_m * U_m'; end
                
                B_p = squeeze(K_history(step_p, ir, :, :));
                muB_p = mean(B_p, 1);
                B0_p  = B_p - muB_p;
                H_p   = A0' * B0_p;
                [U_p, ~, V_p] = svd(H_p);
                R_p = V_p * U_p';
                if det(R_p) < 0, V_p(:,3) = -V_p(:,3); R_p = V_p * U_p'; end
                
                R_delta = R_p * R_m';
                w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
                w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
                w_z = (R_delta(2,1) - R_delta(1,2)) / 2;
                
                p11_m = reshape(WC_history(step_m, ir, :), 1, 3) + [0, 0, dz_m];
                p11_p = reshape(WC_history(step_p, ir, :), 1, 3) + [0, 0, dz_p];
                p11_c = reshape(WC_history(iz, ir, :), 1, 3)     + [0, 0, dz_c];
                
                v_11 = p11_p - p11_m;
                
                if abs(w_x) > 1e-10
                    y_ic = p11_c(2) + (-v_11(3) + w_y * (cp_x - p11_c(1))) / w_x;
                    z_ic = p11_c(3) + ( v_11(2) + w_z * (cp_x - p11_c(1))) / w_x;
                    front_ic_chassis = [cp_x, y_ic, z_ic];
                else
                    front_ic_chassis = [cp_x, cp_y + sign(v_11(2))*1e6, cp_z + 1e6];
                end
                
                if abs(w_y) > 1e-10
                    x_ic = p11_c(1) + ( v_11(3) + w_x * (cp_y - p11_c(2))) / w_y;
                    z_ic = p11_c(3) + (-v_11(1) + w_z * (cp_y - p11_c(2))) / w_y;
                    side_ic_chassis = [x_ic, cp_y, z_ic];
                else
                    side_ic_chassis = [cp_x + sign(v_11(1))*1e6, cp_y, cp_z + 1e6];
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
                v_11     = [0, 0, 0];
                w_x      = 0;
                ia_dir   = [0, 0, 0];
                ia_point = front_ic;
            end
            
            FrontIC_mat(iz, ir, :) = front_ic;
            SideIC_mat(iz, ir, :)  = side_ic;
            FrontVSA_mat(iz, ir)   = hypot(front_ic(2) - cp_y, front_ic(3) - cp_z);
            SideVSA_mat(iz, ir)    = hypot(side_ic(1)  - cp_x, side_ic(3)  - cp_z);
            
            % ============================================================
            % Anti-dive (front, braking) 
            % ============================================================
            dx_side = side_ic(1) - cp_x;          % x_IC - x_CP  (tipikusan negatív)
            dz_side = side_ic(3) - cp_z;          % z_IC - z_CP  (tipikusan pozitív)

            if abs(dx_side) > 1.0 && norm(side_ic) < 1e5
                % Előjel-javított tan: pozitív, ha IC mögött + felett van
                tan_Phi_F = dz_side / (-dx_side);   % = dz / (cp_x - side_ic_x)
                Phi_F_deg = rad2deg(atan(tan_Phi_F));
            else
                tan_Phi_F = 0;
                Phi_F_deg = 0;
            end
            PhiF_mat(iz, ir) = Phi_F_deg;

            heave_mm = travel_range(iz);
            h_CG_SM_current = h_CG_SM_static_mm - heave_mm;   % vázzal süllyed

            if h_CG_SM_current > 1.0
                anti_dive_pct = (W_wheelbase_mm * tan_Phi_F * (front_brake_percent/100) / h_CG_SM_current) * 100;
            else
                anti_dive_pct = 0;
            end
            AntiDive_mat(iz, ir) = anti_dive_pct;

            % ============================================================
            % Anti-squat (rear, gyorsítás) – az optimalizáló calc_anti_squat képlete
            % tan(Phi_R) = (z_IC - z_CP) / (x_IC - x_CP)   (nincs előjelfordítás)
            % ============================================================
            if abs(dx_side) > 1.0 && norm(side_ic) < 1e5
                tan_Phi_R = dz_side / dx_side;
            else
                tan_Phi_R = 0;
            end
            PhiR_mat(iz, ir) = rad2deg(atan(tan_Phi_R));
            if h_CG_SM_current > 1.0
                AntiSquat_mat(iz, ir) = (W_wheelbase_mm * tan_Phi_R * (rear_drive_percent/100) / h_CG_SM_current) * 100;
            else
                AntiSquat_mat(iz, ir) = 0;
            end
            
            instant_axis_dir_history(iz, ir, :)   = ia_dir;
            instant_axis_point_history(iz, ir, :) = ia_point;
    
            if abs(w_x) > 1e-10
                m_rc = (front_ic(3) - cp_z) / (front_ic(2) - cp_y);
            else
                if abs(v_11(3)) > 1e-10
                    m_rc = -v_11(2) / v_11(3);
                else
                    m_rc = 0;
                end
            end
            
            RC_Z_mat(iz, ir) = cp_z - m_rc * cp_y;
        end
    end
    
    disp('Szimuláció kész! Az összes kért paraméter mátrixban tárolva a Workspace-ben.');
    fprintf('A tárolt mátrixok mérete: %d x %d (Wheel Travel x Rack Travel)\n', num_z, num_r);
    
    % Deformált struktúrák áthidalása base_program_front_left névváltozókkal
    camber_history           = Camber_mat;
    toe_history              = Toe_mat;
    kpi_history              = KPI_mat;
    caster_history           = Caster_mat;
    scrub_radius_history     = Scrub_mat;
    mechanical_trail_history = Trail_mat;
    contact_patch_x_history  = squeeze(CP_mat(:,:,1));
    contact_patch_y_history  = squeeze(CP_mat(:,:,2));
    contact_patch_z_history  = squeeze(CP_mat(:,:,3));
    front_ic_history         = FrontIC_mat;
    side_ic_history          = SideIC_mat;
    front_vsa_history        = FrontVSA_mat;
    side_vsa_history         = SideVSA_mat;
    roll_center_history      = RC_Z_mat;
    half_track_history       = contact_patch_y_history;
    if F1.Enable
        static_ride_height = F1.RefPlaneZ;   % F1: a Z=0 referenciasík magassága a talaj felett (Legality Setup)
    else
        static_ride_height = 34;             % FS
    end
    ride_height_history      = repmat(static_ride_height - travel_range', 1, num_r);
    anti_dive_history        = AntiDive_mat;
    phi_F_history            = PhiF_mat;
    anti_squat_history       = AntiSquat_mat;
    phi_R_history            = PhiR_mat;

    % --- Damper Length & Motion Ratio ---
    damper_length_history = zeros(num_z, num_r);
    damper_MR_history     = zeros(num_z, num_r);
    for ir = 1:num_r
        for iz = 1:num_z
            p_dr = squeeze(positions_history(16, :, iz, ir));  % damper rocker
            p_dc = squeeze(positions_history(17, :, iz, ir));  % damper chassis
            damper_length_history(iz, ir) = norm(p_dr - p_dc);
        end
        damper_MR_history(1, ir) = (travel_range(2) - travel_range(1)) / ...
            (damper_length_history(2, ir) - damper_length_history(1, ir) + 1e-15);
        for iz = 2:num_z-1
            damper_MR_history(iz, ir) = (travel_range(iz+1) - travel_range(iz-1)) / ...
                (damper_length_history(iz+1, ir) - damper_length_history(iz-1, ir) + 1e-15);
        end
        damper_MR_history(end, ir) = (travel_range(end) - travel_range(end-1)) / ...
            (damper_length_history(end, ir) - damper_length_history(end-1, ir) + 1e-15);
    end
    damper_MR_history = -damper_MR_history;  % dWheel/dDamper előjel (DAA-val megegyező)

    %% 4b. ÜTKÖZÉS-VIZSGÁLAT A TELJES SWEEPEN (rúd–rúd, rúd–felni, rúd–motor)
    collision_map = false(num_z, num_r);
    collision_txt = cell(num_z, num_r);
    for ir = 1:num_r
        for iz = 1:num_z
            [hit_s, rs_s] = pose_collision(iz, ir);
            collision_map(iz, ir) = any(hit_s);
            collision_txt{iz, ir} = col_pose_string(hit_s, rs_s, Collision);
        end
    end
    fprintf('\n===== ÜTKÖZÉS-VIZSGÁLAT a teljes sweepen (%d póz, min. clearance %.1f mm) =====\n', ...
        numel(collision_map), Collision.min_clearance);
    if ~any(collision_map(:))
        disp('  Nincs ütközés egyik pózban sem.');
    else
        [iz_c, ir_c] = find(collision_map);
        for k = 1:min(numel(iz_c), 30)
            fprintf('  Z = %6.1f mm, rack = %6.1f mm : %s\n', travel_range(iz_c(k)), rack_range(ir_c(k)), ...
                collision_txt{iz_c(k), ir_c(k)});
        end
        if numel(iz_c) > 30, fprintf('  ... további %d ütköző póz\n', numel(iz_c) - 30); end
    end
    
    %% 5. ÖSSZEFOGLALÓ TÁBLÁZATOK KIÍRÁSA (done_3.m)
    iz_rebound = 1;                        % Max kirugózás (-30 mm)
    iz_zero    = find(travel_range == 0, 1); % 0 rugózás
    iz_bump    = length(travel_range);        % Max berugózás (+30 mm)
    
    ir_min     = 1;                        % Minimum kormányszög (-20 mm rack)
    ir_zero    = find(rack_range == 0, 1);   % 0 kormányszög (0 mm rack)
    ir_max     = length(rack_range);          % Maximum kormányszög (+20 mm rack)

    % --- Virtuális kormányzási tengely – statikus helyzet 3D pontjai ---
    [sta_b0, sta_t0, sta_p0, sta_u0] = steer_axis_ends(iz_zero, ir_zero);
    sta_g0 = NaN(1,3); sta_w0 = NaN(1,3);
    if abs(sta_u0(3)) > 1e-6
        sta_g0 = sta_p0 + ((0 - sta_p0(3)) / sta_u0(3)) * sta_u0;              % metszés a talajjal (Z = 0)
        sta_w0 = sta_p0 + ((WC_init(3) - sta_p0(3)) / sta_u0(3)) * sta_u0;     % metszés a kerékközéppont magasságában
    end
    fprintf('\n===== VIRTUÁLIS KORMÁNYZÁSI TENGELY – statikus helyzet (Z = 0 mm, rack = 0 mm) =====\n');
    fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Tengely pontja (WC-hez legközelebbi)', sta_p0(1), sta_p0(2), sta_p0(3));
    fprintf('%-40s : [ %.5f, %.5f, %.5f ]\n', 'Irányvektor (egység)', sta_u0(1), sta_u0(2), sta_u0(3));
    fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Alsó pont (talaj, Z = 0)', sta_g0(1), sta_g0(2), sta_g0(3));
    fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Pont a kerékközéppont magasságában', sta_w0(1), sta_w0(2), sta_w0(3));
    fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Rajzolt tengely alsó vége', sta_b0(1), sta_b0(2), sta_b0(3));
    fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Rajzolt tengely felső vége', sta_t0(1), sta_t0(2), sta_t0(3));
    fprintf('%-40s : %.4f ° | Caster: %.4f °\n', 'KPI', KPI_mat(iz_zero, ir_zero), Caster_mat(iz_zero, ir_zero));
    fprintf('------------------------------------\n');
    
    matrices = {'KPI_mat', KPI_mat; ...
        'Caster_mat', Caster_mat; ...
        'Camber_mat', Camber_mat; ...
        'Toe_mat', Toe_mat; ...
        'Scrub_mat', Scrub_mat; ...
        'Trail_mat', Trail_mat; ...
        'AntiDive_mat', AntiDive_mat; ...
        'PhiF_mat', PhiF_mat; ...
        'AntiSquat_mat', AntiSquat_mat; ...
        'PhiR_mat', PhiR_mat};
    
    for k = 1:size(matrices, 1)
        name = matrices{k, 1};
        mat  = matrices{k, 2};
    
        fprintf('\n=========================================================\n');
        fprintf(' %s ÉRTÉKEK\n', name);
        fprintf('=========================================================\n');
        fprintf('              | Min Kormány |   0 Kormány  | Max Kormány |\n');
        fprintf('---------------------------------------------------------\n');
        fprintf('Max Berugózás | %11.4f | %12.4f | %11.4f |\n', ...
            mat(iz_bump, ir_min), mat(iz_bump, ir_zero), mat(iz_bump, ir_max));
        fprintf('0 Rugózás     | %11.4f | %12.4f | %11.4f |\n', ...
            mat(iz_zero, ir_min), mat(iz_zero, ir_zero), mat(iz_zero, ir_max));
        fprintf('Max Kirugózás | %11.4f | %12.4f | %11.4f |\n', ...
            mat(iz_rebound, ir_min), mat(iz_rebound, ir_zero), mat(iz_rebound, ir_max));
    end
    
    %% 3x3 EREDMÉNY MÁTRIX EXPORTÁLÁSA EXCELBE (Comparison.xlsx formátum)
    % Blokkok (sorok):  left steer / static (0 steer) / right steer
    % Oszlopok:         compression (max berugózás) / static (0 rugóút) / rebound (max kirugózás)
    % Soronként:        toe, camber, kpi, caster, kpi trail (= scrub radius), caster trail (= mechanical trail)
    % A toe és a camber a statikus helyzethez (0 rugóút, 0 kormány) viszonyított érték, ugyanúgy,
    % mint a diagramokon; a KPI, caster, scrub radius és mechanical trail abszolút érték.
    % Left steer = a legnagyobb negatív rack elmozdulás, right steer = a legnagyobb pozitív rack elmozdulás.
    % Ha nálad fordítva van, az xl_steer_idx első és harmadik elemét kell megcserélni.
    xl_file       = 'Rear_Left_Multi_3x3.xlsx';
    xl_zero_w     = iz_zero;
    xl_zero_s     = ir_zero;
    xl_steer_idx  = [ir_min, ir_zero, ir_max];    % left, 0, right
    xl_travel_idx = [iz_bump, iz_zero, iz_rebound];    % compression, static, rebound
    xl_steer_lbl  = {'left steer', 'static', 'right steer'};
    xl_col_lbl    = {'compression', 'static', 'rebound'};
    xl_par_lbl    = {'toe', 'camber', 'kpi', 'caster', 'kpi trail', 'caster trail'};
    xl_par_unit   = {'°', '°', '°', '°', ' mm', ' mm'};
    xl_par_data   = {toe_history - toe_history(xl_zero_w, xl_zero_s), ...
                     -(camber_history(:,:,1) - camber_history(xl_zero_w, xl_zero_s)), ...
                     kpi_history, caster_history, scrub_radius_history, mechanical_trail_history};

    % A munkalap felépítése a Comparison.xlsx szerint (A1:L21).
    % Bal tábla (A:E) = ennek a programnak az eredménye, jobb tábla (H:L) = üres, összehasonlításhoz.
    xl_out = cell(21, 12);
    for xl_k = 1:3
        xl_out{1, 2 + xl_k} = xl_col_lbl{xl_k};    % C1:E1
        xl_out{1, 9 + xl_k} = xl_col_lbl{xl_k};    % J1:L1
    end
    for xl_b = 1:3
        xl_r0 = 2 + (xl_b - 1) * 7;                % blokk első sora: 2, 9, 16
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
        warning('Az Excel export nem sikerült: %s (ha a fájl meg van nyitva Excelben, zárd be, és futtasd újra)', xl_err.message);
    end

    %% 5b. F1 + ÜTKÖZÉS ÖSSZESÍTŐ (a 3D ábra fejlécéhez és a konzolra)
    [f1_rules_ok, f1_failed] = f1_rules_status(f1_names, f1_vals); %#ok<ASGLU>
    [~, f1_wheel_failed]     = f1_static_wheel_status(WC_init, F1);
    f1_failed = [f1_failed, f1_wheel_failed];
    if ~f1_outboard_ok(pushrod_upright, WC_init, F1, F1.PushrodOnMember)
        f1_failed{end+1} = 'C10.3.4 (pushrod upright)';
    end
    n_col = nnz(collision_map);
    n_tot = numel(collision_map);
    track_mm = 2 * abs(half_track_history(iz_zero, ir_zero));
    if F1.Enable
        n0_s = f1_wheel_axes(F1);
        O_s  = f1_wcs_origin(WC_init, n0_s, F1);
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

    % Tengelyhatárok a teljes sweep + az F1 kerék alapján
    vis_lims = calc_vis_limits(positions_history, WC_init, Tyre.R_outer);

    %% 6. VIZUALIZÁCIÓ (base_program_front_left nézetek és diagramok)
    line_pairs = { ...
        [1, 2], [0.8 0.8 0.8], 3; ...
        [3, 4], [0.8 0.8 0.8], 3; ...
        [5, 6], [0.8 0.8 0.8], 3; ...
        [7, 8], [0.8 0.8 0.8], 3; ...
        [9, 10], [0.8 0.8 0.8], 3; ...
        [2, 4], [0.8 0.8 0.8], 1.5; ...
        [4, 6], [0.8 0.8 0.8], 1.5; ...
        [6, 8], [0.8 0.8 0.8], 1.5; ...
        [8, 10], [0.8 0.8 0.8], 1.5; ...
        [10, 2], [0.8 0.8 0.8], 1.5; ...
        [2, 11], [0.8 0.8 0.8], 1.5; ...
        [4, 11], [0.8 0.8 0.8], 1.5; ...
        [6, 11], [0.8 0.8 0.8], 1.5; ...
        [8, 11], [0.8 0.8 0.8], 1.5; ...
        [10, 11], [0.8 0.8 0.8], 1.5};
    
    fig = figure('Name', 'Suspension visualization (Multilink)', 'NumberTitle', 'off', 'Position', [100 80 1920 1020], 'WindowState','maximized');   
    
    ax1 = axes('Parent', fig, 'Position', [0.005 0.55 0.45 0.4]);   
    hold(ax1, 'on'); grid(ax1, 'on'); axis(ax1, 'equal');
    xlim(ax1, vis_lims(1,:)); ylim(ax1, vis_lims(2,:)); zlim(ax1, vis_lims(3,:));
    xlabel(ax1, 'X [mm]'); ylabel(ax1, 'Y [mm]'); zlabel(ax1, 'Z [mm]');
    view(ax1, 135, 10); box(ax1, 'on');
    light('Parent', ax1, 'Position', [1 1 1], 'Style', 'infinite');
    lighting(ax1, 'gouraud'); material(ax1, 'dull'); title(ax1, '3D view');
    
    ax2 = axes('Parent', fig, 'Position', [0.505 0.55 0.45 0.4]);
    hold(ax2, 'on'); grid(ax2, 'on'); axis(ax2, 'equal');
    xlim(ax2, vis_lims(1,:)); ylim(ax2, vis_lims(2,:)); zlim(ax2, vis_lims(3,:));
    xlabel(ax2, 'X [mm]'); ylabel(ax2, 'Y [mm]'); zlabel(ax2, 'Z [mm]');
    view(ax2, 0, 90); box(ax2, 'on');
    light('Parent', ax2, 'Position', [1 1 1], 'Style', 'infinite');
    lighting(ax2, 'gouraud'); material(ax2, 'dull'); title(ax2, 'Top view');
    
    ax3 = axes('Parent', fig, 'Position', [0.005 0.05 0.45 0.4]);
    hold(ax3, 'on'); grid(ax3, 'on'); axis(ax3, 'equal');
    xlim(ax3, vis_lims(1,:)); ylim(ax3, vis_lims(2,:)); zlim(ax3, vis_lims(3,:));
    xlabel(ax3, 'X [mm]'); ylabel(ax3, 'Y [mm]'); zlabel(ax3, 'Z [mm]');
    view(ax3, 180, 0); box(ax3, 'on');
    light('Parent', ax3, 'Position', [1 1 1], 'Style', 'infinite');
    lighting(ax3, 'gouraud'); material(ax3, 'dull'); title(ax3, 'Side view');
    
    ax4 = axes('Parent', fig, 'Position', [0.505 0.05 0.45 0.4]);
    hold(ax4, 'on'); grid(ax4, 'on'); axis(ax4, 'equal');
    xlim(ax4, vis_lims(1,:)); ylim(ax4, vis_lims(2,:)); zlim(ax4, vis_lims(3,:));
    xlabel(ax4, 'X [mm]'); ylabel(ax4, 'Y [mm]'); zlabel(ax4, 'Z [mm]');
    view(ax4, 90, 0); box(ax4, 'on');
    light('Parent', ax4, 'Position', [1 1 1], 'Style', 'infinite');
    lighting(ax4, 'gouraud'); material(ax4, 'dull'); title(ax4, 'Front view');

    % Állapotsávok: bal = aktuális póz ütközése, jobb = F1 szabályosság + méretek
    h_status_pose = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.005 0.962 0.49 0.036], 'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'String', '');
    h_status_f1 = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.505 0.962 0.49 0.036], 'FontSize', 9, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'String', sprintf('%s\n%s', f1_str, dim_str), 'BackgroundColor', f1_bg);
    h_status_pose2 = gobjects(1);   % a fig2-n lévő párja (később jön létre)
    
    h_points1 = gobjects(length(points), 1); h_texts1 = gobjects(length(points), 1); h_lines1 = gobjects(size(line_pairs,1), 1);
    h_points2 = gobjects(length(points), 1); h_texts2 = gobjects(length(points), 1); h_lines2 = gobjects(size(line_pairs,1), 1);
    h_points3 = gobjects(length(points), 1); h_texts3 = gobjects(length(points), 1); h_lines3 = gobjects(size(line_pairs,1), 1);
    h_points4 = gobjects(length(points), 1); h_texts4 = gobjects(length(points), 1); h_lines4 = gobjects(size(line_pairs,1), 1);
    
    initial_wheel_step = iz_zero;
    initial_steer_step = ir_zero;
    update_plot(initial_wheel_step, initial_steer_step);
    
    % FIG 2: Toe, Camber, Contact Patch, VSA
    fig2 = figure('Name','Toe, Camber, Contact Patch, VSA','NumberTitle','off', 'Position',[200 150 1400 780], 'WindowState','maximized');  
    
    ax_toe = subplot(2,2,1, 'Position', [0.05 0.55 0.3 0.4]);
    hold(ax_toe,'on'); grid on; box on; title(ax_toe,'Toe angle  (piros x = ütköző póz)');
    xlabel(ax_toe,'Wheel travel [mm]'); ylabel(ax_toe,'Toe angle [°]'); set(ax_toe,'FontSize',11);
    
    ax_camber = subplot(2,2,2, 'Position', [0.67 0.55 0.3 0.4]);
    hold(ax_camber,'on'); grid on; box on; title(ax_camber,'Camber angle');
    xlabel(ax_camber,'Wheel travel [mm]'); ylabel(ax_camber,'Camber angle [°]'); set(ax_camber,'FontSize',11);
    
    ax_contact_patch = subplot(2,2,3, 'Position', [0.05 0.07 0.3 0.4]);
    hold(ax_contact_patch,'on'); grid on; box on; title(ax_contact_patch,'Contact patch coordinates');
    xlabel(ax_contact_patch,'Wheel travel [mm]'); ylabel(ax_contact_patch,'Contact patch displacement [mm]'); set(ax_contact_patch,'FontSize',11);
    
    ax_vsa = subplot(2,2,4, 'Position', [0.67 0.07 0.3 0.4]);
    hold(ax_vsa,'on'); grid on; box on; title(ax_vsa,'Virtual swing arm length');
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
    steer_text2  = uicontrol('Parent',fig2, 'Style','text','Units','normalized', 'Position',[0.50 0.9 0.10 0.05], 'String',sprintf('Rack Displacement:\n%6.1f mm', steering_range(initial_steer_step)), 'FontSize',12, 'FontWeight','bold','HorizontalAlignment','center');
    h_status_pose2 = uicontrol('Parent',fig2, 'Style','text','Units','normalized', 'Position',[0.36 0.955 0.28 0.04], 'String','', 'FontSize',9, 'FontWeight','bold','HorizontalAlignment','center');
    update_status(initial_wheel_step, initial_steer_step, false);
    
    % FIG 3: Trail, Caster, Scrub, KPI
    fig3 = figure('Name', 'Mechanical Trail, Caster, Scrub & KPI', 'NumberTitle', 'off', 'Position', [300 100 1600 900], 'WindowState', 'maximized');
    
    ax_trail = subplot(2,2,1); hold on; grid on; box on; title(ax_trail, 'Mechanical Trail'); xlabel(ax_trail, 'Wheel travel [mm]'); ylabel(ax_trail, 'Mechanical Trail [mm]');
    ax_caster = subplot(2,2,2); hold on; grid on; box on; title(ax_caster, 'Caster Angle'); xlabel(ax_caster, 'Wheel travel [mm]'); ylabel(ax_caster, 'Caster Angle [°]');
    ax_scrub = subplot(2,2,3); hold on; grid on; box on; title(ax_scrub, 'Scrub Radius'); xlabel(ax_scrub, 'Wheel travel [mm]'); ylabel(ax_scrub, 'Scrub Radius [mm]');
    ax_kpi = subplot(2,2,4); hold on; grid on; box on; title(ax_kpi, 'Kingpin Inclination Angle'); xlabel(ax_kpi, 'Wheel travel [mm]'); ylabel(ax_kpi, 'Kingpin Inclination Angle [°]');
    
    h_trail_curve  = plot(ax_trail, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_caster_curve = plot(ax_caster, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_scrub_curve  = plot(ax_scrub, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_kpi_curve    = plot(ax_kpi, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    
    h_point_trail  = plot(ax_trail, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_caster = plot(ax_caster, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_scrub  = plot(ax_scrub, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_kpi    = plot(ax_kpi, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    
    % FIG 5: Front IC, Side IC, Half Track, Ride Height
    fig5 = figure('Name','Front IC, Side IC, Half Track, Ride Height','NumberTitle','off', 'Position',[200 150 1400 780], 'WindowState','maximized');  
    
    ax_front_IC = subplot(2,2,1); hold(ax_front_IC,'on'); grid on; box on; title(ax_front_IC,'Front IC coordinates'); xlabel(ax_front_IC,'Wheel travel [mm]'); ylabel(ax_front_IC,'Front IC coordinates [mm]'); set(ax_front_IC,'FontSize',11);
    ax_side_IC  = subplot(2,2,2); hold(ax_side_IC,'on'); grid on; box on; title(ax_side_IC,'Side IC coordinates'); xlabel(ax_side_IC,'Wheel travel [mm]'); ylabel(ax_side_IC,'Side IC coordinates [mm]'); set(ax_side_IC,'FontSize',11);
    ax_half_track = subplot(2,2,3); hold(ax_half_track,'on'); grid on; box on; title(ax_half_track,'Half Track'); xlabel(ax_half_track,'Wheel travel [mm]'); ylabel(ax_half_track,'Half Track [mm]'); set(ax_half_track,'FontSize',11);
    ax_ride_height = subplot(2,2,4); hold(ax_ride_height,'on'); grid on; box on; title(ax_ride_height,'Ride Height'); xlabel(ax_ride_height,'Wheel travel [mm]'); ylabel(ax_ride_height,'Ride Height [mm]'); set(ax_ride_height,'FontSize',11);
    
    h_front_IC_x_curve = plot(ax_front_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_front_IC_y_curve = plot(ax_front_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_front_IC_z_curve = plot(ax_front_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_IC_x_curve  = plot(ax_side_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_IC_y_curve  = plot(ax_side_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_side_IC_z_curve  = plot(ax_side_IC, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_half_track_curve = plot(ax_half_track, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    h_ride_height_curve = plot(ax_ride_height, wheel_travel_range, zeros(size(wheel_travel_range)), 'Color', [0.6 0.6 0.6], 'LineWidth', 2, 'HandleVisibility', 'off');
    
    h_point_front_IC_x = plot(ax_front_IC, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_front_IC_y = plot(ax_front_IC, 0, 0, 'bo','MarkerFaceColor','b','MarkerSize',10);
    h_point_front_IC_z = plot(ax_front_IC, 0, 0, 'go','MarkerFaceColor','g','MarkerSize',10);
    h_point_side_IC_x  = plot(ax_side_IC, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_side_IC_y  = plot(ax_side_IC, 0, 0, 'bo','MarkerFaceColor','b','MarkerSize',10);
    h_point_side_IC_z  = plot(ax_side_IC, 0, 0, 'go','MarkerFaceColor','g','MarkerSize',10);
    h_point_half_track = plot(ax_half_track, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_ride_height = plot(ax_ride_height, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    
    % ============================================================
    % Fig6 – Anti-dive, Phi_F és Anti-squat heave függvényében
    % ============================================================
    fig6 = figure('Name','Anti-Dive, Side-View Swing Arm Angle (Phi_F) & Anti-Squat','NumberTitle','off', ...
                  'Position',[250 120 1200 600], 'WindowState','maximized');

    ax_anti_dive = subplot(1,3,1);
    hold(ax_anti_dive,'on'); grid on; box on;
    title(ax_anti_dive, sprintf('Anti-Dive (W=%.0f mm, %%Fbrake=%.0f, h_{CG,SM,stat}=%.0f mm)', ...
          W_wheelbase_mm, front_brake_percent, h_CG_SM_static_mm));
    xlabel(ax_anti_dive, 'Wheel travel [mm]');
    ylabel(ax_anti_dive, 'Anti-Dive [%]');
    set(ax_anti_dive,'FontSize',11);

    ax_phi_F = subplot(1,3,2);
    hold(ax_phi_F,'on'); grid on; box on;
    title(ax_phi_F, 'Side-view swing-arm angle \Phi_F (CP \rightarrow Side IC)');
    xlabel(ax_phi_F, 'Wheel travel [mm]');
    ylabel(ax_phi_F, '\Phi_F [°]');
    set(ax_phi_F,'FontSize',11);

    ax_anti_squat = subplot(1,3,3);
    hold(ax_anti_squat,'on'); grid on; box on;
    title(ax_anti_squat, sprintf('Anti-Squat (W=%.0f mm, %%Drive_{rear}=%.0f, h_{CG,SM,stat}=%.0f mm)', ...
          W_wheelbase_mm, rear_drive_percent, h_CG_SM_static_mm));
    xlabel(ax_anti_squat, 'Wheel travel [mm]');
    ylabel(ax_anti_squat, 'Anti-Squat [%]');
    set(ax_anti_squat,'FontSize',11);

    h_anti_dive_curve = plot(ax_anti_dive, wheel_travel_range, zeros(size(wheel_travel_range)), ...
                             'Color',[0.2 0.4 0.8], 'LineWidth',2, 'HandleVisibility','off');
    h_phi_F_curve     = plot(ax_phi_F,     wheel_travel_range, zeros(size(wheel_travel_range)), ...
                             'Color',[0.8 0.3 0.1], 'LineWidth',2, 'HandleVisibility','off');
    h_anti_squat_curve = plot(ax_anti_squat, wheel_travel_range, zeros(size(wheel_travel_range)), ...
                             'Color',[0.2 0.6 0.3], 'LineWidth',2, 'HandleVisibility','off');
    h_point_anti_dive = plot(ax_anti_dive, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_phi_F     = plot(ax_phi_F,     0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_anti_squat = plot(ax_anti_squat, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);

    % ============================================================
    % Fig4 – Damper Length & Motion Ratio
    % ============================================================
    fig4 = figure('Name', 'Damper Length & Motion Ratio', 'NumberTitle', 'off', ...
                  'Position', [300 100 1200 600], 'WindowState', 'maximized');

    ax_damper_length = subplot(1,2,1);
    hold(ax_damper_length,'on'); grid on; box on;
    title(ax_damper_length, 'Damper Length');
    xlabel(ax_damper_length, 'Wheel travel [mm]');
    ylabel(ax_damper_length, 'Damper Length [mm]');
    set(ax_damper_length,'FontSize',11);

    ax_damper_MR = subplot(1,2,2);
    hold(ax_damper_MR,'on'); grid on; box on;
    title(ax_damper_MR, 'Damper Motion Ratio');
    xlabel(ax_damper_MR, 'Wheel travel [mm]');
    ylabel(ax_damper_MR, 'Damper Motion Ratio [-]');
    set(ax_damper_MR,'FontSize',11);

    h_damper_length_curve = plot(ax_damper_length, wheel_travel_range, zeros(size(wheel_travel_range)), ...
                                 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_damper_MR_curve     = plot(ax_damper_MR, wheel_travel_range, zeros(size(wheel_travel_range)), ...
                                 'Color',[0.6 0.6 0.6],'LineWidth',2, 'HandleVisibility','off');
    h_point_damper_length = plot(ax_damper_length, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);
    h_point_damper_MR     = plot(ax_damper_MR, 0, 0, 'ro','MarkerFaceColor','r','MarkerSize',10);

    update_diagram(initial_wheel_step, initial_steer_step);
    
    
    %% 7. NÉZET ÉS FRISSÍTŐ FÜGGVÉNYEK (Nested Functions)
        function update_plot(wheel_step, steer_step)
            update_axes(ax1, h_points1, h_texts1, h_lines1, wheel_step, steer_step, [30 30 30], Collision);
            update_axes(ax2, h_points2, h_texts2, h_lines2, wheel_step, steer_step, [30 30 0], Collision); 
            update_axes(ax3, h_points3, h_texts3, h_lines3, wheel_step, steer_step, [30 0 30], Collision);
            update_axes(ax4, h_points4, h_texts4, h_lines4, wheel_step, steer_step, [0 30 30], Collision);
            update_status(wheel_step, steer_step, true);
    
            space = '    ';
            fprintf('Wheel Travel                           : %.1f mm\n', wheel_travel_range(wheel_step));
            fprintf('Rack Displacement                      : %.1f mm\n', steering_range(steer_step));
            for i = 1:length(points)
                pos = squeeze(positions_history(i, :, wheel_step, steer_step));
                fprintf('%-32s%s : [%.3f, %.3f, %.3f]\n', points(i).name, space, pos(1), pos(2), pos(3));
            end
            pos_center = squeeze(positions_history(11, :, wheel_step, steer_step));
            pos_upper = pos_center + [0, 0, TireRadius];
            pos_lower = pos_center + [0, 0, -TireRadius];
            pos_left  = pos_center + [-TireRadius, 0, 0];
            pos_right = pos_center + [TireRadius, 0, 0];
            camber_rel = camber_history(wheel_step, steer_step) - camber_history(iz_zero, ir_zero);
            toe_rel    = toe_history(wheel_step, steer_step)    - toe_history(iz_zero, ir_zero);
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel upper', pos_upper(1), pos_upper(2), pos_upper(3));
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel lower', pos_lower(1), pos_lower(2), pos_lower(3));
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel left', pos_left(1), pos_left(2), pos_left(3));
            fprintf('%-40s : [ %.3f, %.3f, %.3f ]\n', 'Wheel right', pos_right(1), pos_right(2), pos_right(3)); 
            fprintf('Camber angle                         : %.4f °\n', -camber_rel);
            fprintf('Toe angle                                : %.4f °\n', toe_rel);
            trail_rel  = mechanical_trail_history(wheel_step, steer_step) - mechanical_trail_history(iz_zero, ir_zero);
            caster_rel = caster_history(wheel_step, steer_step) - caster_history(iz_zero, ir_zero);
            scrub_rel  = scrub_radius_history(wheel_step, steer_step) - scrub_radius_history(iz_zero, ir_zero);
            kpi_rel    = kpi_history(wheel_step, steer_step) - kpi_history(iz_zero, ir_zero);
            
            fprintf('Mechanical trail change              : %.4f mm\n', trail_rel);
            fprintf('Caster angle change                  : %.4f °\n', caster_rel);
            fprintf('Scrub radius change                  : %.4f mm\n', scrub_rel);
            fprintf('KPI change                           : %.4f °\n', kpi_rel);
            fprintf('------------------------------------\n');
        end

        % Ütközés-vizsgálat egy pózban (ugyanaz a logika, mint az optimalizáló nonlcon-jában)
        function [hit, reasons, dd, C_pts, K_pts, WC_pos, unit_normal] = pose_collision(wheel_step, steer_step)
            pp = positions_history(:, :, wheel_step, steer_step);
            C_pts  = pp([1 3 5 7 9 12], :);     % Link 1..5 váz + pushrod rocker
            K_pts  = pp([2 4 6 8 10 13], :);    % Link 1..5 upright + pushrod upright
            WC_pos = pp(11, :);
            Rw = squeeze(R_history(wheel_step, steer_step, :, :));
            unit_normal = Rw * Collision.wheel_axis0(:);
            unit_normal = unit_normal / norm(unit_normal);
            [hit, reasons, dd] = col_check_pose(C_pts, K_pts, WC_pos, unit_normal, Collision);
        end

        % Állapotsáv + konzol diagnosztika az aktuális pózra
        function update_status(wheel_step, steer_step, verbose)
            [hit, reasons, dd] = pose_collision(wheel_step, steer_step);
            rod_nm = col_rod_names(Collision, numel(hit));
            if verbose
                for ii = 1:numel(hit)
                    if hit(ii), mark_str = '  <-- PIROS'; else, mark_str = ''; end
                    fprintf('%-18s szabad távolság: rúd %7.1f | motor %7.1f | felni %7.1f mm (min. %.1f)%s\n', ...
                        rod_nm{ii}, dd.rod(ii), dd.motor(ii), dd.rim(ii), Collision.min_clearance, mark_str);
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

            toe_rel = toe_history(:, steer_step) - toe_history(iz_zero, ir_zero);
            camber_rel = -1 * (camber_history(:, steer_step) - camber_history(iz_zero, ir_zero));
            contact_patch_x_rel = contact_patch_x_history(:, steer_step) - contact_patch_x_history(iz_zero, ir_zero);
            contact_patch_y_rel = contact_patch_y_history(:, steer_step) - contact_patch_y_history(iz_zero, ir_zero);
            contact_patch_z_rel = contact_patch_z_history(:, steer_step) - contact_patch_z_history(iz_zero, ir_zero);
            front_vsa_abs = front_vsa_history(:, steer_step);
            side_vsa_abs  = side_vsa_history(:, steer_step);

            toe_current = toe_rel(wheel_step);
            camber_current = camber_rel(wheel_step);
            contact_patch_x_current = contact_patch_x_history(wheel_step, steer_step);
            contact_patch_y_current = contact_patch_y_history(wheel_step, steer_step);
            contact_patch_z_current = contact_patch_z_history(wheel_step, steer_step);
            front_vsa_current = front_vsa_abs(wheel_step);
            side_vsa_current  = side_vsa_abs(wheel_step);

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
            set(h_point_side_vsa,  'XData', wt, 'YData', side_vsa_abs(wheel_step));

            legend(ax_toe, sprintf('Toe = %.3f°', toe_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_camber, sprintf('Camber = %.3f°', camber_current), 'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_contact_patch, sprintf('X  = %.3f mm', contact_patch_x_current), sprintf('Y  = %.3f mm', contact_patch_y_current), sprintf('Z  = %.3f mm', contact_patch_z_current), 'Location','best', 'FontSize', 12, 'Box','on');
            legend(ax_vsa, sprintf('Front VSA = %.3f mm', front_vsa_current), sprintf('Side VSA  = %.3f mm', side_vsa_current), 'Location','best', 'FontSize',12, 'Box','on');

            ylim(ax_toe, [min(toe_rel)-1 max(toe_rel)+1]);
            ylim(ax_camber, [min(camber_rel)-1 max(camber_rel)+1]);
            ylim(ax_contact_patch, [min(contact_patch_y_rel)-1 max(contact_patch_y_rel)+1]);

            trail_abs  = mechanical_trail_history(:, steer_step);
            caster_abs = caster_history(:, steer_step);
            scrub_abs  = scrub_radius_history(:, steer_step);
            kpi_abs    = kpi_history(:, steer_step);

            trail_current  = trail_abs(wheel_step);
            caster_current = caster_abs(wheel_step);
            scrub_current  = scrub_abs(wheel_step);
            kpi_current    = kpi_abs(wheel_step);

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

            front_IC_x_rel = front_ic_history(:, steer_step, 1) - front_ic_history(iz_zero, ir_zero, 1);
            front_IC_y_rel = front_ic_history(:, steer_step, 2) - front_ic_history(iz_zero, ir_zero, 2);
            front_IC_z_rel = front_ic_history(:, steer_step, 3) - front_ic_history(iz_zero, ir_zero, 3);
            side_IC_x_rel  = side_ic_history(:, steer_step, 1) - side_ic_history(iz_zero, ir_zero, 1);
            side_IC_y_rel  = side_ic_history(:, steer_step, 2) - side_ic_history(iz_zero, ir_zero, 2);
            side_IC_z_rel  = side_ic_history(:, steer_step, 3) - side_ic_history(iz_zero, ir_zero, 3);
            half_track_abs = half_track_history(:, steer_step);
            ride_height_abs = ride_height_history(:, steer_step);

            front_IC_x_current = front_ic_history(wheel_step, steer_step, 1);
            front_IC_y_current = front_ic_history(wheel_step, steer_step, 2);
            front_IC_z_current = front_ic_history(wheel_step, steer_step, 3);
            side_IC_x_current  = side_ic_history(wheel_step, steer_step, 1);
            side_IC_y_current  = side_ic_history(wheel_step, steer_step, 2);
            side_IC_z_current  = side_ic_history(wheel_step, steer_step, 3);
            half_track_current  = half_track_abs(wheel_step);
            ride_height_current = ride_height_abs(wheel_step);

            set(h_front_IC_x_curve, 'YData', front_IC_x_rel);
            set(h_front_IC_y_curve, 'YData', front_IC_y_rel);
            set(h_front_IC_z_curve, 'YData', front_IC_z_rel);
            set(h_side_IC_x_curve,  'YData', side_IC_x_rel);
            set(h_side_IC_y_curve,  'YData', side_IC_y_rel);
            set(h_side_IC_z_curve,  'YData', side_IC_z_rel);
            set(h_half_track_curve, 'YData', half_track_abs);
            set(h_ride_height_curve, 'YData', ride_height_abs);

            set(h_point_front_IC_x, 'XData', wt, 'YData', front_IC_x_rel(wheel_step));
            set(h_point_front_IC_y, 'XData', wt, 'YData', front_IC_y_rel(wheel_step));
            set(h_point_front_IC_z, 'XData', wt, 'YData', front_IC_z_rel(wheel_step));
            set(h_point_side_IC_x,  'XData', wt, 'YData', side_IC_x_rel(wheel_step));
            set(h_point_side_IC_y,  'XData', wt, 'YData', side_IC_y_rel(wheel_step));
            set(h_point_side_IC_z,  'XData', wt, 'YData', side_IC_z_rel(wheel_step));           
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

            % Fig6 – Anti-squat
            anti_squat_abs     = anti_squat_history(:, steer_step);
            anti_squat_current = anti_squat_abs(wheel_step);
            set(h_anti_squat_curve, 'YData', anti_squat_abs);
            set(h_point_anti_squat, 'XData', wt, 'YData', anti_squat_current);
            legend(ax_anti_squat, sprintf('Anti-Squat = %.2f %%  (\\Phi_R = %.2f°)', anti_squat_current, ...
                   phi_R_history(wheel_step, steer_step)), 'Location','best', 'FontSize',12, 'Box','on');
            ylim(ax_anti_squat, [min(anti_squat_abs)-5, max(anti_squat_abs)+5]);

            % Fig4 – Damper Length & Motion Ratio
            damper_length_abs = damper_length_history(:, steer_step);
            damper_MR_abs     = damper_MR_history(:, steer_step);
            damper_length_current = damper_length_abs(wheel_step);
            damper_MR_current     = damper_MR_abs(wheel_step);

            set(h_damper_length_curve, 'YData', damper_length_abs);
            set(h_damper_MR_curve,     'YData', damper_MR_abs);
            set(h_point_damper_length, 'XData', wt, 'YData', damper_length_current);
            set(h_point_damper_MR,     'XData', wt, 'YData', damper_MR_current);

            legend(ax_damper_length, sprintf('Damper Length = %.3f mm', damper_length_current), ...
                   'Location','best', 'FontSize',12, 'Box','on');
            legend(ax_damper_MR, sprintf('Damper MR = %.3f -', damper_MR_current), ...
                   'Location','best', 'FontSize',12, 'Box','on');

            ylim(ax_damper_length, [min(damper_length_abs)-5, max(damper_length_abs)+5]);
            ylim(ax_damper_MR,     [min(damper_MR_abs)-0.2,  max(damper_MR_abs)+0.2]);

            drawnow;
        end
    
        function [sta_b, sta_t, sta_p, sta_u] = steer_axis_ends(w_i, s_i)
            % Virtuális kormányzási tengely: pont, irány és a rajzolt szakasz két vége
            % (alul a talaj Z = 0, felül a gumi tetejének magassága; majdnem vízszintes tengelynél ±400 mm)
            sta_p = squeeze(SteerAxisP_mat(w_i, s_i, :))';
            sta_u = squeeze(SteerAxisU_mat(w_i, s_i, :))';
            if abs(sta_u(3)) > 0.2
                sta_b = sta_p + ((0 - sta_p(3)) / sta_u(3)) * sta_u;
                sta_t = sta_p + ((WC_init(3) + Tyre.R_outer - sta_p(3)) / sta_u(3)) * sta_u;
            else
                sta_b = sta_p - 400 * sta_u;
                sta_t = sta_p + 400 * sta_u;
            end
        end

        function update_axes(ax, h_points, h_texts, h_lines, wheel_step, steer_step, label_offset, Collision)
            cla(ax);
            hold(ax, 'on');

            % Padló újra létrehozása (a kerék alatt, a teljes sweep méretéhez igazítva)
            [X, Y] = meshgrid(linspace(vis_lims(1,1), vis_lims(1,2), 40), linspace(vis_lims(2,1), vis_lims(2,2), 40));
            Z = zeros(size(X));
            h_floor = surf(ax, X, Y, Z, 'FaceColor', [0.92 0.94 0.98], 'EdgeColor', 'none', 'FaceAlpha', 0.45, 'FaceLighting', 'gouraud');
            set(h_floor, 'HandleVisibility', 'off');
            uistack(h_floor, 'bottom');    

            % Fények újra létrehozása
            light('Parent', ax, 'Position', [1 1 1], 'Style', 'infinite');
            light('Parent', ax, 'Position', [-1 -1 1], 'Style', 'infinite');

            % 1. Pontok előkészítése és kirajzolása
            p = zeros(length(points), 3);
            for i = 1:length(points)
                pos = squeeze(positions_history(i, :, wheel_step, steer_step));
                p(i, :) = pos; % Eltesszük későbbre a mátrixba is
                
                if ishandle(h_points(i))
                    set(h_points(i), 'XData', pos(1), 'YData', pos(2), 'ZData', pos(3));
                else
                    h_points(i) = plot3(ax, pos(1), pos(2), pos(3), 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
                end
            end

            % =========================================================================
            % 2. ÜTKÖZÉSVIZSGÁLAT ÉS TESTEK (Felni F1 C10.7.2 szerint; motor csak FS módban)
            %    Rúd: kék = szabad, PIROS = rúd–rúd / rúd–felni / rúd–motor ütközés
            % =========================================================================
            [hit, ~, ~, C_pts, K_pts, WC_pos, unit_normal] = pose_collision(wheel_step, steer_step);
            un_row = unit_normal(:)';

            if Collision.use_motor
                motor_c = WC_pos + Collision.motor_y_offset * un_row;
                draw_cylinder_custom(ax, motor_c, un_row, Collision.motor_radius, Collision.motor_length, [0.4 0.4 0.4], 0.6);
            end
            rim_center = WC_pos + Collision.rim_y_offset * un_row;
            draw_cylinder_custom(ax, rim_center, un_row, Collision.rim_inner_radius, Collision.rim_width, [0.7 0.7 0.7], 0.4);

            radii = Collision.rod_diameter(:)' / 2;   % biztosan 1×N sorvektor
            for i = 1:size(C_pts, 1)
                if hit(i)
                    rod_color = [1 0 0];
                else
                    rod_color = [0.2 0.6 1.0];
                end
                draw_rod(ax, C_pts(i,:), K_pts(i,:), radii(i), rod_color, 1.0);
            end

            % =========================================================================
            % 3. Rocker / Damper / többi segédrúd kirajzolása
            % =========================================================================
            % Rocker tengely (axis – center)
            draw_rod(ax, p(14,:), p(15,:), 3, [0.5 0.5 0.5], 0.9);
            % Damper (rocker – chassis)
            draw_rod(ax, p(16,:), p(17,:), 5, [0.3 0.7 0.3], 0.95);
            % Rocker – damper rocker kapcsolat (ha van)
            draw_rod(ax, p(12,:), p(16,:), 3, [0.6 0.6 0.2], 0.9);
            % Rocker center – pushrod rocker
            draw_rod(ax, p(15,:), p(12,:), 3, [0.6 0.4 0.2], 0.9);

            % =========================================================================
            % 4. Gumiabroncs kirajzolása (F1 méretek, legality camber)
            % =========================================================================
            draw_tire(ax, WC_pos, unit_normal, [], []);

            % Virtuális kormányzási tengely (szaggatott)
            [sta_b, sta_t] = steer_axis_ends(wheel_step, steer_step);
            hold(ax, 'on');                      % a draw_tire hold off-ra állít, enélkül a plot3 letörölné az ábrát
            if all(isfinite([sta_b sta_t]))
                plot3(ax, [sta_b(1) sta_t(1)], [sta_b(2) sta_t(2)], [sta_b(3) sta_t(3)], ...
                    '--', 'Color', [1 0.45 0], 'LineWidth', 2.2);
                plot3(ax, sta_b(1), sta_b(2), sta_b(3), 's', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [1 0.45 0], 'MarkerSize', 6);
            end

        end
    
    %% 8. SEGÉDFÜGGVÉNYEK
    function err = calc_link_errors(q, C_curr, K_loc, WC_init, dz, L0)
        WC_current = [q(1), q(2), WC_init(3) + dz];
        R = euler_to_rot(q(3), q(4), q(5));
        err = zeros(5,1);
        for i = 1:5
            K_current = WC_current' + R * K_loc(i,:)';
            L_current = norm(K_current' - C_curr(i,:));
            err(i) = L_current - L0(i);
        end
    end
    
    function R = euler_to_rot(rx, ry, rz)
        Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
        Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
        Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
        R = Rz * Ry * Rx;
    end
    
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
    
    function h = draw_tire(ax, pos_center, unit_normal, varargin)
        % Méretek a Tyre struktúrából (F1 2026: gumi Ø705/710, 18" felni, felniszélesség C10.7.2)
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
        % Félig átlátszó gumi, hogy a felnin belüli (piros) rudak is látszódjanak
        surf(ax, X_t_rot, Y_t_rot, Z_t_rot, 'FaceColor', [0.28 0.28 0.30], 'EdgeColor', 'none', 'FaceAlpha', 0.35, 'FaceLighting', 'gouraud', 'SpecularStrength', 0.25, 'AmbientStrength', 0.7);
        surf(ax, X_r_rot, Y_r_rot, Z_r_rot, 'FaceColor', [0.65 0.68 0.72], 'EdgeColor', 'none', 'FaceAlpha', 0.25, 'FaceLighting', 'phong', 'SpecularStrength', 0.6);
        hold(ax, 'off');
        h = gco;
    end

    % --- HENGER RAJZOLÓ (Motor és Felni vizualizáció) ---
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
    zc = (zc - 0.5) * length; % Középpontra igazítás

    X = center(1) + xc.*v(1) + yc.*w(1) + zc.*u(1);
    Y = center(2) + xc.*v(2) + yc.*w(2) + zc.*u(2);
    Z = center(3) + xc.*v(3) + yc.*w(3) + zc.*u(3);

    h = surf(ax, X, Y, Z, 'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', alpha, 'FaceLighting', 'gouraud');
    end

end

%% =====================================================================
%% LOKÁLIS SEGÉDFÜGGVÉNYEK – VIZUALIZÁCIÓ
%% =====================================================================

function L = calc_vis_limits(positions_history, WC, R_tyre)
% A 3D nézetek tengelyhatárai: a teljes sweep összes pontja + a kerék (F1 méretek).
    P = reshape(permute(positions_history, [2 1 3 4]), 3, [])';
    P = P(all(isfinite(P), 2) & any(P ~= 0, 2), :);
    WC = WC(:)';
    lo = min([P; WC - R_tyre - 60], [], 1);
    hi = max([P; WC + R_tyre + 60], [], 1);
    lo(3) = min(lo(3), -50);
    L = [lo(:), hi(:)];
end

%% =====================================================================
%% ÜTKÖZÉS-ELLENŐRZÉS (az optimalizálók get_collision_distances logikája)
%% =====================================================================

function [hit, reasons, dd] = col_check_pose(C_pts, K_pts, WC, unit_normal, Col)
% Egy póz ütközés-vizsgálata. hit(i) = true -> az i. rúd PIROS.
% dd.rod / dd.motor / dd.rim: az i. rúd legkisebb szabad (felület–felület) távolsága [mm];
% ütközés, ha ez kisebb, mint Col.min_clearance (= optimalizáló: need - d > 0).
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

    % 1) Rúd–rúd (A-kar párok és közös végpontú rudak kihagyva)
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

    % 2) Rúd–motor (csak FS módban; F1: nincs agymotor)
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

    % 3) Rúd–felni (gyűrű: r_inner..r_outer, ±szélesség/2, előjeles távolság)
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
% Rövid szöveg: melyik rúd mihez ér hozzá (üres, ha nincs ütközés).
    names = col_rod_names(Col, numel(hit));
    parts = {};
    for i = find(hit(:))'
        parts{end+1} = sprintf('%s: %s', names{i}, strjoin(reasons{i}, ', ')); %#ok<AGROW>
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
% Előjeles távolság szakasz és véges henger között (< 0: behatolás).
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
%% F1 2026 – ÖSSZESÍTŐ SEGÉDFÜGGVÉNYEK (csak a számoló programokban)
%% =====================================================================

function [ok, failed] = f1_rules_status(names, vals)
% A f1_report-tal azonos döntés (max(c) <= 1e-3 = OK), a sérülő szabálypontok kódjával.
    ok = true; failed = {};
    for i = 1:numel(names)
        v = vals{i};
        if ~isempty(v) && max(v) > 1e-3
            ok = false;
            failed{end+1} = strtok(names{i}); %#ok<AGROW>
        end
    end
end

function [ok, failed] = f1_static_wheel_status(WC, F1)
% C10.10.1 (nyomtáv / WCS |Y|) és C10.1c (WCS Z) – a f1_check_wheel_static döntése, szövegesen.
    ok = true; failed = {};
    if ~F1.Enable, return; end
    n0  = f1_wheel_axes(F1);
    O   = f1_wcs_origin(WC, n0, F1);
    zF1 = O(3) - F1.RefPlaneZ;
    if abs(O(2)) > F1.WCS_Ymax + 1e-6, ok = false; failed{end+1} = 'C10.10.1 (nyomtáv)'; end
    if zF1 < F1.WCS_Zrange(1) || zF1 > F1.WCS_Zrange(2), ok = false; failed{end+1} = 'C10.1c (WCS Z)'; end
end

function ok = f1_outboard_ok(P, WC, F1, on_member)
% A f1_check_outboard_point döntése logikai értékként.
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
% = az optimalizáló calc_link_errors-a (5 tag + merev upright, WC Z rögzített)
    WC_current = [q(1), q(2), WC_init(3) + dz];
    R = f1_euler_rot(q(3), q(4), q(5));
    err = zeros(size(K_loc, 1), 1);
    for i = 1:size(K_loc, 1)
        K_current = WC_current' + R * K_loc(i,:)';
        err(i) = norm(K_current' - C_curr(i,:)) - L0(i);
    end
end

function R = f1_euler_rot(rx, ry, rz)
% = az optimalizáló euler_to_rot-ja
    Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
    Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
    Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
    R = Rz * Ry * Rx;
end

%% =====================================================================
%% F1 2026 SZABÁLYZAT (Section C10, Issue 20) – KÖZÖS SEGÉDFÜGGVÉNYEK
%% (az optimalizálók blokkja; a kinematikát itt a f1_link_errors / f1_euler_rot adja,
%%  mert a számoló programban a calc_link_errors / euler_to_rot nested függvény)
%% =====================================================================

function F1 = f1_rules_2026(axle)
% A C10 szabályokból adódó kényszerek alapértékei egy tengelyre ('front' / 'rear').
%
% KOORDINÁTÁK: a kód saját rendszere marad (X előre, Y balra, Z fel, Z = 0 a TALAJ,
% bal kerék: Y > 0). Az F1 Z = 0 referenciasík a talaj felett F1.RefPlaneZ magasságban van.
%
% WHEEL COORDINATE SYSTEM (WCS) – a C10.7.2 felniméretekből, a C10.2.6b setup-kerékből
% (YW = -168) és a C10.10.1 szélességi határból levezetve:
%   origó: a kerék tengelyén, a felni BELSŐ síkjában;  YW: a kerék tengelye, BEFELÉ pozitív;
%   ZW: YW-re merőleges, felfelé.  A gumi közepe (a kód WC pontja) YW = F1.WC_YW-nél van.
% Legality Setup (C10.1): toe = 0, camber = -3° elöl / -1° hátul. A kód kinematikája a
% kereket a design pózban függőlegesnek veszi; az F1 ellenőrzések a legality cambert
% használják (a szabály is így írja elő a CAD-ellenőrzést).
    axle = lower(strtrim(axle));
    F1.Enable  = true;
    F1.Axle    = axle;
    F1.IsFront = strcmp(axle, 'front');

    if F1.IsFront
        F1.LegalCamber    = -3;           % C10.1b [deg]
        F1.WCS_Zrange     = [290 320];    % C10.1c  WCS origó Z az F1 Z=0 síkhoz [mm]
        F1.WCS_Ymax       = 603;          % C10.10.1 WCS origó max. Y [mm]
        F1.OutboardZWmin  = -100;         % C10.3.4b [mm]
        F1.TyreRadius     = 705/2;        % Pirelli 2026 első gumi Ø705 mm (csak ellenőrzéshez)
        F1.Rim.MountWidth = 315;          % C10.7.2a Tyre Mounting Width
        F1.Rim.Width      = 334;          % C10.7.2a Overall Width (ref.)
        F1.RefPlaneZ      = 45;           % [mm] <- SAJÁT: F1 Z=0 sík magassága a talaj felett (Legality Setup)
    else
        F1.LegalCamber    = -1;
        F1.WCS_Zrange     = [225 285];
        F1.WCS_Ymax       = 525;
        F1.OutboardZWmin  = -40;
        F1.TyreRadius     = 710/2;        % Pirelli 2026 hátsó gumi Ø710 mm
        F1.Rim.MountWidth = 401.3;
        F1.Rim.Width      = 420.3;
        F1.RefPlaneZ      = 95;           % [mm] <- SAJÁT
    end
    F1.Rim.InboardLip   = 10.5;           % C10.7.2a
    F1.Rim.OutboardLip  = 8.5;            % C10.7.2a
    F1.WC_YW            = -(F1.Rim.InboardLip + F1.Rim.MountWidth/2);  % első: -168 (= C10.2.6b), hátsó: -211.15
    F1.Rim.OuterRadius  = 496/2;          % C10.7.2a Lip External Diameter
    F1.Rim.BeadRadius   = 462.5/2;        % C10.7.2a Rim Diameter
    F1.Rim.MinThickness = 2.5;            % C10.7.2f
    F1.Rim.InnerRadius  = 215;            % [mm] <- SAJÁT: a felni belső (hordó) sugara a CAD-ből (RV-RIM-MIN)
    F1.Rim.CenterOffset = F1.Rim.Width/2 + F1.WC_YW;   % felniközép a WC-hez képest, a kifelé mutató tengely mentén

    F1.OutboardYWmax = 0;                 % C10.3.4a: outboard pontok YW <= 0
    F1.Drum.Enable = false;               % C10.3.4c / C3.14.2: a Drum nincs a C10 szövegben -> töltsd ki, majd true
    F1.Drum.Radius = NaN;                 % [mm] a Drum sugara a YW tengely körül
    F1.Drum.YW     = [NaN NaN];           % [YW_min YW_max] a Drum axiális kiterjedése

    F1.ZWgradMax         = 1;             % C10.3.1 [deg] ...
    F1.ZWgradWindow      = 10;            % ... ennyi [mm] rugóúton
    F1.IncidenceHeaveMax = 5;             % C10.3.6c [deg] rugóút
    F1.IncidenceSteerMax = 1;             % C10.3.6c [deg] kormányzás
    F1.CheckDz    = -30:5:30;             % [mm] az F1 heave-ellenőrzés pózai (a 10 mm-es ablakhoz 5 mm-es lépés kell)
    F1.NoMountBox = [];                   % C10.3.10 (hátul): PU tiltott doboz [xmin xmax; ymin ymax; zmin zmax], [] = ki

    % --- csak első tengely ---
    F1.PairMinDX      = 300;              % C10.3.5 [mm]
    F1.PairMinZ       = 250;              % C10.3.5 [mm, F1 Z]
    F1.JackAngle      = 12;               % C10.2.6b [deg]
    F1.JackMax        = 2;                % C10.2.6b [mm]
    F1.LockToeIn      = 23;               % C10.3.7 [deg] (+ = toe-in)
    F1.LockToeOut     = 21;               % C10.3.7 [deg]
    F1.MaxRackTravel  = Inf;              % [mm] ha véges: a lockhoz szükséges rack-út korlátja
    F1.SteerCheckRack = 30;               % [mm] C10.3.6c kormányzási tartomány (±rack)

    % --- pushrod (rocker optimalizálók) ---
    F1.PushrodOnMember       = false;     % true: a pushrod egy másik tagra (lengőkarra) köt -> C10.3.4 d-f
    F1.PushrodExcYWmax       = 50;        % C10.3.4d [mm]
    F1.PushrodExcLineDist    = 25;        % C10.3.4e [mm]
    F1.CheckPushrodIncidence = true;      % C10.3.6c a pushrodra (kör keresztmetszetnél állítsd false-ra)
end

function [n0, zw0] = f1_wheel_axes(F1)
% Legality Setup kerék-tengely (bal kerék): n0 = KIFELÉ mutató forgástengely, zw0 = ZW.
% Negatív camber: a kerék teteje befelé dől -> a kifelé mutató tengely felfelé dől.
    phi = -deg2rad(F1.LegalCamber);
    n0  = [0;  cos(phi); sin(phi)];
    zw0 = [0; -sin(phi); cos(phi)];
end

function O = f1_wcs_origin(WC, n, F1)
% WCS origó: WC = O + WC_YW*YW, YW = -n  ->  O = WC + WC_YW*n
    O = WC(:) + F1.WC_YW * n(:);
end

function [yw, zw, r] = f1_wcs_coords(P, WC, n, zw_ax, F1)
% P (Nx3) pontok WCS koordinátái: YW (befelé +), ZW, és a YW tengelytől mért sugár.
    O  = f1_wcs_origin(WC, n, F1)';
    D  = P - O;
    yw = -D * n(:);
    zw =  D * zw_ax(:);
    r  = sqrt(max(sum(D.^2, 2) - yw.^2, 0));
end

function f1_check_wheel_static(WC, F1, label)
% C10.1c / C10.10.1 / gumiméret – a WC rögzített, ezért induláskori ellenőrzés.
    if ~F1.Enable, return; end
    n0  = f1_wheel_axes(F1);
    O   = f1_wcs_origin(WC, n0, F1);
    zF1 = O(3) - F1.RefPlaneZ;
    fprintf('[F1 %s] WCS origó: |Y| = %.1f mm (max %g) | Z_F1 = %.1f mm (%g..%g) | WC Z = %.1f mm (gumi sugár %.1f)\n', ...
        label, abs(O(2)), F1.WCS_Ymax, zF1, F1.WCS_Zrange(1), F1.WCS_Zrange(2), WC(3), F1.TyreRadius);
    if abs(O(2)) > F1.WCS_Ymax + 1e-6
        warning('F1 C10.10.1: a WCS origó |Y| = %.1f > %g mm (túl széles nyomtáv)!', abs(O(2)), F1.WCS_Ymax);
    end
    if zF1 < F1.WCS_Zrange(1) || zF1 > F1.WCS_Zrange(2)
        warning('F1 C10.1c: a WCS origó Z_F1 = %.1f mm, kívül esik a %g..%g tartományon (WC Z / F1.RefPlaneZ)!', ...
            zF1, F1.WCS_Zrange(1), F1.WCS_Zrange(2));
    end
    if abs(WC(3) - F1.TyreRadius) > 20
        warning('A kerékközép magassága (%.1f mm) nem F1 gumiméret (sugár ~%.1f mm). A kódban Z = 0 a talaj!', ...
            WC(3), F1.TyreRadius);
    end
end

function f1_check_outboard_point(P, WC, F1, label, on_member)
% Egy NEM optimalizált outboard bekötési pont C10.3.4 ellenőrzése (figyelmeztetés).
% on_member = true: a tag egy másik tagra köt (pl. pushrod a lengőkaron) -> C10.3.4d.
    if ~F1.Enable, return; end
    [n0, zw0] = f1_wheel_axes(F1);
    [yw, zw, r] = f1_wcs_coords(P(:)', WC, n0, zw0, F1);
    if on_member
        fprintf('[F1] %s: YW = %.1f mm (C10.3.4d: <= %g)\n', label, yw, F1.PushrodExcYWmax);
        if yw > F1.PushrodExcYWmax
            warning('F1 C10.3.4d: %s túl beljebb van (YW = %.1f > %g mm)!', label, yw, F1.PushrodExcYWmax);
        end
    else
        fprintf('[F1] %s: YW = %.1f mm (<= %g), ZW = %.1f mm (>= %g), r = %.1f mm\n', ...
            label, yw, F1.OutboardYWmax, zw, F1.OutboardZWmin, r);
        if yw > F1.OutboardYWmax, warning('F1 C10.3.4a: %s YW = %.1f > %g mm!', label, yw, F1.OutboardYWmax); end
        if zw < F1.OutboardZWmin, warning('F1 C10.3.4b: %s ZW = %.1f < %g mm!', label, zw, F1.OutboardZWmin); end
        if F1.Drum.Enable && (r > F1.Drum.Radius || yw < F1.Drum.YW(1) || yw > F1.Drum.YW(2))
            warning('F1 C10.3.4c: %s a Drumon kívül van!', label);
        end
    end
end

function R = f1_axis_rot(a, t)
% Forgatási mátrix az (origón átmenő) a tengely körül t [rad] szöggel (Rodrigues).
    a = a(:) / norm(a);
    W = [0 -a(3) a(2); a(3) 0 -a(1); -a(2) a(1) 0];
    R = eye(3) + sin(t) * W + (1 - cos(t)) * (W * W);
end

function R = f1_rot_between(u, v)
% Minimális forgatás az u iránytól a v irányig.
    u = u(:) / norm(u); v = v(:) / norm(v);
    w = cross(u, v); s = norm(w); c = u' * v;
    if s < 1e-12, R = eye(3); return; end
    W = [0 -w(3) w(2); w(3) 0 -w(1); -w(2) w(1) 0];
    R = eye(3) + W + W * W * ((1 - c) / s^2);
end

function t = f1_signed_angle(v0, v1, a)
% v0 -> v1 előjeles szöge az a tengely körül [rad].
    a  = a(:) / norm(a);
    v0 = v0(:) - a * (a' * v0(:));
    v1 = v1(:) - a * (a' * v1(:));
    t  = atan2(a' * cross(v0, v1), v0' * v1);
end

function m0 = f1_major_axis0(L)
% C10.3.6c feltevés: a keresztmetszet főtengelye a Legality Setupban vízszintes
% és merőleges a terhelési vonalra (szárnyprofilú tag).
    m0 = cross(L(:), [0; 0; 1]);
    if norm(m0) < 1e-9, m0 = [1; 0; 0]; end
    m0 = m0 / norm(m0);
end

function a = f1_incidence(m)
% A főtengely és a Z = 0 sík szöge [deg].
    a = asind(max(-1, min(1, m(3) / norm(m))));
end

function d = f1_seg_rim_dist(p0, p1, center, axis, r_in, r_out, half_w)
% Előjeles távolság szakasz és felni-gyűrű (r_in..r_out, ±half_w) között (< 0: behatolás).
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
% Pont előjeles távolsága egy tengelyirányú dobozhoz (box = [xmin xmax; ymin ymax; zmin zmax]); < 0: belül.
    q = max(box(:,1)' - P(:)', P(:)' - box(:,2)');
    s = norm(max(q, 0)) + min(max(q), 0);
end

function [names, vals] = f1_add(names, vals, name, v)
    names{end+1} = name; vals{end+1} = v(:);
end

function f1_report(names, vals, label)
% Az F1 kényszerek összesítése (c <= 0 = megfelel).
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
% Pózsorozat megoldása melegindítással a 0-hoz legközelebbi pózból kifelé.
% mode = 'dz' (heave: váz Z -= v) vagy 'dy' (kormány: a steer_idx vázpont Y += v).
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
% Az upright pontok adott pózban.
    R   = f1_euler_rot(q(3), q(4), q(5));
    WCk = [q(1), q(2), WC_init(3)];
    Kk  = (WCk(:) + R * K_loc')';
end

function inc = f1_member_incidences(C0, K0, C, K, hinge)
% C10.3.6c: a tagok keresztmetszet-főtengelyének dőlésváltozása [deg] a Legality Setuphoz képest.
% hinge(i,:) = [a b]: az i. tag az a-b vázpontokon átmenő csuklótengely körül fordul (A-kar szára);
% hinge(i,:) = [0 0]: kétgömbcsuklós rúd -> minimális elfordulás.
    n = size(C0, 1); inc = zeros(n, 1);
    for i = 1:n
        L0 = K0(i,:) - C0(i,:);
        m0 = f1_major_axis0(L0);
        if hinge(i,1) > 0
            a0 = C0(hinge(i,2),:) - C0(hinge(i,1),:);
            a1 = C(hinge(i,2),:)  - C(hinge(i,1),:);
            Rh = f1_rot_between(a0, a1);                  % a váz elfordulása (heave/steer: I)
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
% Design (= Legality Setup) póz: C10.3.4 a-c, C10.3.5 (elöl), C10.3.10.
    [n0, zw0] = f1_wheel_axes(F1);
    [yw, zw, r] = f1_wcs_coords(Kout, WC, n0, zw0, F1);
    [names, vals] = f1_add(names, vals, 'C10.3.4a outboard pontok YW <= 0 [mm]', yw - F1.OutboardYWmax);
    [names, vals] = f1_add(names, vals, sprintf('C10.3.4b outboard pontok ZW >= %g [mm]', F1.OutboardZWmin), ...
        F1.OutboardZWmin - zw);
    if F1.Drum.Enable
        [names, vals] = f1_add(names, vals, 'C10.3.4c outboard pontok a Drumon belül [mm]', ...
            [r - F1.Drum.Radius; F1.Drum.YW(1) - yw; yw - F1.Drum.YW(2)]);
    else
        [names, vals] = f1_add(names, vals, 'C10.3.4c Drum (KIKAPCSOLVA – töltsd ki: F1.Drum)', -ones(3*numel(yw), 1));
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
% Rugóút mentén: C10.3.1 (ZW oldalnézeti szöge max. 1° / 10 mm) és C10.3.6c (±5°).
    nM = size(Km, 1);
    L0 = sqrt(sum((Km - C).^2, 2));
    K_loc = Km - WC_init;
    dzs = F1.CheckDz(:)'; np = numel(dzs);
    [Q, ok, Cp] = f1_pose_sweep(C, K_loc, WC_init, L0, dzs, 'dz', 0);
    [~, zw0] = f1_wheel_axes(F1);
    th  = nan(1, np);
    inc = (10 + F1.IncidenceHeaveMax) * ones(nM, np);   % sikertelen póz -> sértés
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
                    g(end+1, 1) = 10; %#ok<AGROW>
                else
                    g(end+1, 1) = abs(th(j) - th(i)) - F1.ZWgradMax; %#ok<AGROW>
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
% Kormányzás mentén (WC Z állandó, mint a kód kormányzási modelljében): C10.3.6c ±1°.
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

%% ---------------- F1 – multilink specifikus kényszerek (= optimalizáló) ----------------

function [c, ceq, names, vals] = f1_nonlcon_ML(x, WC_init, F1, Collision)
% Az összes F1 2026 kényszer a multilinkre (c <= 0 = megfelel). 4 kimenettel a riporthoz is.
    ceq = []; names = {}; vals = {};
    if ~F1.Enable, c = zeros(0, 1); return; end
    C = reshape(x(1:15), [5,3]);
    K = reshape(x(16:30), [5,3]);
    hinge = zeros(5, 2);                                   % 5 kétgömbcsuklós rúd

    [names, vals] = f1_static_cons(C, K, WC_init, F1, [], names, vals);
    [names, vals] = f1_heave_cons(C, K, WC_init, F1, hinge, names, vals);
    if F1.IsFront && isfield(Collision, 'steer_range') && Collision.steer_range > 0
        [names, vals] = f1_steer_cons(C, K, WC_init, F1, hinge, 5, names, vals);
    end
    c = vertcat(vals{:});
end