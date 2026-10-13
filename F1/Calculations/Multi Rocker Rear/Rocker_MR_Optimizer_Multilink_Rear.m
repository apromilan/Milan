function Rocker_MR_Optimizer_Multilink
% =========================================================================
% PUSHROD/ROCKER MOTION RATIO OPTIMALIZÁLÓ (MULTILINK)
%
% - Multilink kinematika (5 lengőkar, Euler-orientációjú upright)
% - Rocker logika: azonos a DAA Rocker_MR_Optimizer10-zel
% - Optimalizálandó: Rocker Center, Pushrod Rocker, Damper Rocker
% - Rocker Axis fix, sík normálisa mentén eltolható
% - Heave: kasztni le, WC Z a földön marad
% - MR = |dWheel / dDamper|
% =========================================================================
    clc; clear; close all;

    disp('========================================================');
    disp(' ROCKER MOTION RATIO OPTIMALIZÁLÓ (MULTILINK)');
    disp(' - Multilink kinematika + DAA-azonos rocker logika');
    disp(' - 3 rocker-pont optimalizálható (Axis fixálva)');
    disp(' - Csak Motion Ratio görbére optimalizál');
    disp('========================================================');
    disp('TIPP: Leállításhoz hozd létre a "stop_opt.txt" fájlt!');
    disp('========================================================');

    plane_choice = questdlg('Szeretnéd tartani az eredeti Rocker sík dőlését (Center-Damper-Pushrod), vagy a program válassza ki szabadon?', ...
        'Rocker Sík Kényszer', 'Saját sík tartása (Kényszer)', 'Program választja', 'Program választja');
    % ENFORCE_ROCKER_PLANE = strcmp(plane_choice, 'Saját sík tartása (Kényszer)');
    ENFORCE_ROCKER_PLANE = false;
    
    %% 3. PONTRENDSZER BETÖLTÉSE (Multilink + Rocker)
    [pts0, fixed_mask] = load_all_points();
    disp('Pontok betöltve (default + Excel override).');
    
    default_dist = norm(pts0(14).pos - pts0(13).pos); % 13: Axis, 14: Center
    p_c_def = pts0(14).pos;
    p_p_def = pts0(11).pos; % 11: Pushrod Rocker
    p_d_def = pts0(15).pos; % 15: Damper Rocker
    default_area = 0.5 * norm(cross(p_p_def - p_c_def, p_d_def - p_c_def));
    
    prompt = {'Kérem a Rocker Axis (13) és Center (14) távolságát mm-ben (Üres = auto):', ...
              'Kérem a maximális Rocker felületet mm^2-ben (Üres = auto):'};
    dlgtitle = 'Rocker Paraméterek';
    dims = [1 60];
    definput = {num2str(default_dist, '%.2f'), num2str(default_area, '%.2f')};
    answer = inputdlg(prompt, dlgtitle, dims, definput);
    
    if isempty(answer)
        TARGET_AXIS_DIST = [];
        TARGET_MAX_AREA = [];
    else
        if isempty(answer{1})
            TARGET_AXIS_DIST = [];
            disp('Rocker Axis - Center távolság optimalizálása engedélyezve a solver számára.');
        else
            TARGET_AXIS_DIST = str2double(answer{1});
            fprintf('Rocker Axis - Center távolság fixálva: %.2f mm\n', TARGET_AXIS_DIST);
        end
        if isempty(answer{2})
            TARGET_MAX_AREA = [];
            disp('Rocker felület mérete nincs korlátozva.');
        else
            TARGET_MAX_AREA = str2double(answer{2});
            fprintf('Rocker felület maximálva: %.2f mm^2\n', TARGET_MAX_AREA);
        end
    end

    %% 1. JÁRMŰ PARAMÉTEREK
    USE_GUI_FOR_CURVES = true;

    % <- a saját F1 autó adatai (tömeg, rugó, gumi): ezeket a szabályzat nem rögzíti
    Vehicle.sm_mass     = 208;
    Vehicle.Trackwidth  = 1600;
    Vehicle.K_spring    = 225 * 175.127; % N/m
    Vehicle.K_tire      = 588 * 175.127; % N/m
    Vehicle.Inertia_RC  = 14.9;

    Collision.rod_diameter_pushrod = 20;   
    Collision.min_clearance        = 5;    
    Collision.motor_radius         = 48;             
    Collision.motor_length         = 160.2;          
    Collision.motor_y_offset       = -63.4;        
    Collision.rim_inner_radius     = 117;
    Collision.rim_outer_radius     = 124.5;
    Collision.rim_width            = 195;
    Collision.rim_y_offset         = 0;

    %% 1c. F1 2026 SZABÁLYZAT (Section C10)
    % A rocker a szabályzat szerint csak C10.4.1-et kell teljesítse (egy rocker kerekenként, a vázon
    % rögzített tengely körül forog) – ezt a modell felépítése eleve biztosítja. A pushrod viszont
    % felfüggesztési tag: a felnihez (C10.7.2), a bekötési ponthoz (C10.3.4) és a
    % keresztmetszet-dőléshez (C10.3.6c) tartozó kényszerek ide is kellenek.
    F1 = f1_rules_2026('rear');       % 'front' | 'rear'
    F1.RefPlaneZ       = 95;           % [mm] az F1 Z=0 referenciasík magassága a talaj felett
    F1.Rim.InnerRadius = 215;          % [mm] a felni belső (hordó) sugara – CAD / RV-RIM-MIN
    F1.PushrodOnMember = false;       % a pushrod az uprightra köt (C10.3.4 a-c)
    % F1.CheckPushrodIncidence = false;   % kör keresztmetszetű pushrodnál (C10.3.6c nem köt)
    % F1.Enable = false;                  % F1 kényszerek ki (eredeti FS működés)
    if F1.Enable
        Collision.use_motor        = false;                 % F1: nincs agymotor
        Collision.rim_inner_radius = F1.Rim.InnerRadius;    % C10.7.2 felni
        Collision.rim_outer_radius = F1.Rim.OuterRadius;
        Collision.rim_width        = F1.Rim.Width;
        Collision.rim_y_offset     = F1.Rim.CenterOffset;
        Collision.wheel_axis0      = f1_wheel_axes(F1)';    % Legality Setup camber
    else
        Collision.use_motor   = true;
        Collision.wheel_axis0 = [0, 1, 0];
    end
    f1_check_wheel_static(pts0(17).pos, F1, F1.Axle);
    f1_check_outboard_point(pts0(12).pos, pts0(17).pos, F1, 'Pushrod Upright', F1.PushrodOnMember);


    %% 2. CÉLGÖRBÉK BEÁLLÍTÁSA (CSAK MR)
    Target.dz = -15:1:15;
    eval_pts  = -15:1:15;

    target_excel = 'Célgörbe_Rocker_MR0.xlsx';
    loaded_data = {};
    if exist(target_excel, 'file') == 2
        disp(['Célgörbe betöltése: ', target_excel]);
        loaded_data = readcell(target_excel);
    end

    if USE_GUI_FOR_CURVES
        disp('Grafikus célgörbe szerkesztése...');
        [x_init, y_init] = get_excel_pts(loaded_data, 3, eval_pts);
        Target.MR = defineTargetCurveGUI('Motion Ratio Célgörbe', -30, 30, ...
            'Rugóút (Z) [mm]', 'Motion Ratio [-]', x_init, y_init);
    else
        Target.MR = 1.2 * ones(size(Target.dz));
    end

    num_eval = length(eval_pts);
    out_cell = cell(3, 20); out_cell(:) = {''};
    out_cell{1, 9} = 'Heave';
    out_cell(2, 2:num_eval+1) = num2cell(eval_pts);
    out_cell(3, 1) = {'Motion_Ratio'};
    out_cell(3, 2:num_eval+1) = num2cell(interp1(Target.dz, Target.MR, eval_pts, 'pchip', 'extrap'));

    curves_changed = true;
    if ~isempty(loaded_data)
        try
            old_mat = cell2mat(loaded_data(3, 2:num_eval+1));
            new_mat = cell2mat(out_cell(3, 2:num_eval+1));
            if max(abs(old_mat(:)-new_mat(:))) < 1e-4
                curves_changed = false;
            end
        catch
        end
    else
        writecell(out_cell, target_excel);
        curves_changed = false;
        disp(['Sablon létrehozva: ', target_excel]);
    end
    
    if curves_changed
        file_idx = 1;
        while exist(sprintf('Célgörbe_Rocker_MR0_%d.xlsx', file_idx), 'file') == 2
            file_idx = file_idx + 1;
        end
        new_f = sprintf('Célgörbe_Rocker_MR0_%d.xlsx', file_idx);
        writecell(out_cell, new_f);
        disp(['Új célgörbe fájl mentve: ', new_f]);
    else
        disp('Célgörbe változatlan.');
    end

    %% 4. OPTIMALIZÁLANDÓ PONTOK VÁLASZTÁSA
    rocker_ids   = [11 12 13 14 15 16];
    rocker_names = {'Rod Rocker','Rod Upright','Rocker Axis','Rocker Center','Damper Rocker','Damper Chassis'};
    [sel, ok] = listdlg('PromptString', 'Mely pontokat iterálhassa a solver? (a többi fix)', ...
        'ListString', rocker_names, 'InitialValue', [1 4 5], ...
        'SelectionMode', 'multiple', 'ListSize', [320 140]);
    if ~ok || isempty(sel), sel = [1 4 5]; end
    opt_idx = rocker_ids(sel);
    
    x0 = [];
    for i = opt_idx, x0 = [x0, pts0(i).pos]; end
    dev = 30;                       % ide per-pont értéket is írhatsz
    lb = x0 - dev;  ub = x0 + dev;

    x_ref = x0;
    opts_p = optimoptions('fmincon','Display','off','Algorithm','sqp');
    x0 = fmincon(@(x) sum((x - x_ref).^2), x_ref, [],[],[],[], lb, ub, ...
        @(x) geo_only_nonlcon(x, pts0, opt_idx, TARGET_AXIS_DIST), opts_p);
    fprintf('Indulópont elmozdulás a feasible geometriához: %.2f mm\n', norm(x0 - x_ref));

    %% 5. OPTIMALIZÁLÁS
    disp('Optimalizálás indítása...');
    options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 5000, 'StepTolerance', 1e-20, ...
        'OutputFcn', @stop_optimization_callback);

    obj_fun = @(x) calc_mr_cost(x, pts0, fixed_mask, opt_idx, Target, Vehicle);
    nonlcon_fun = @(x) rocker_collision_and_plane_nonlcon(x, pts0, opt_idx, ...
        Collision, ENFORCE_ROCKER_PLANE, TARGET_AXIS_DIST, TARGET_MAX_AREA, F1);

    tic;
    % d0  = pts0(12).pos - pts0(11).pos;
    % Aeq = [zeros(3,3), -eye(3), eye(3), zeros(3,3)];   % p12 - p11 = d0
    % beq = d0(:);

    % [x_opt, fval] = fmincon(obj_fun, x0, [], [], Aeq, beq, lb, ub, nonlcon_fun, options);

    [x_opt, fval] = fmincon(obj_fun, x0, [], [], [], [], lb, ub, nonlcon_fun, options);
    toc;

    %% 6. EREDMÉNYEK
    disp('========================================================');
    disp(' OPTIMALIZÁCIÓ BEFEJEZŐDÖTT!');
    disp('========================================================');
    fprintf('Végső hiba (cost): %.4f\n', fval);

    pts_opt = pts0;
    k = 1;
    for i = 1:length(opt_idx)
        pts_opt(opt_idx(i)).pos = x_opt(k:k+2);
        k = k + 3;
    end

    base_out = 'Optim_Rocker_MR';
    if exist([base_out, '.xlsx'], 'file') ~= 2
        out_file = [base_out, '.xlsx'];
    else
        file_idx = 1;
        while exist(sprintf('%s_%d.xlsx', base_out, file_idx), 'file') == 2
            file_idx = file_idx + 1;
        end
        out_file = sprintf('%s_%d.xlsx', base_out, file_idx);
    end

    pts_names = {'Pushrod Rocker','Pushrod Upright','Rocker Axis','Rocker Center', ...
                 'Damper Rocker','Damper Chassis'};
    rocker_candidates = [11, 12, 13, 14, 15, 16];
    
    out_cell2 = cell(6,4);
    for i = 1:6
        out_cell2{i,1} = pts_names{i};
        out_cell2{i,2} = pts_opt(rocker_candidates(i)).pos(1);
        out_cell2{i,3} = pts_opt(rocker_candidates(i)).pos(2);
        out_cell2{i,4} = pts_opt(rocker_candidates(i)).pos(3);
    end
    writetable(cell2table(out_cell2, 'VariableNames', {'Name','X','Y','Z'}), out_file);
    fprintf('Mentve: %s\n', out_file);

    [f_ride_init, f_roll_init, MR_init, KWH_init, KRoll_init] = ...
        sweep_kinematics(x0, pts0, fixed_mask, opt_idx, Target.dz, Vehicle);
    [f_ride_opt,  f_roll_opt,  MR_opt,  KWH_opt,  KRoll_opt]  = ...
        sweep_kinematics(x_opt, pts0, fixed_mask, opt_idx, Target.dz, Vehicle);

    figure('Name', 'Rocker Motion Ratio Eredmények', 'Position', [50, 100, 1200, 400]);

    subplot(1,3,1); hold on; grid on;
    plot(Target.dz, Target.MR, 'k--', 'LineWidth', 2, 'DisplayName', 'Célgörbe (MR)');
    plot(Target.dz, MR_init, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kezdeti MR');
    plot(Target.dz, MR_opt,  'r-', 'LineWidth', 2,   'DisplayName', 'Optimált MR');
    xlabel('Rugóút (Z) [mm]'); ylabel('Motion Ratio [-]'); title('Motion Ratio (MR)'); legend('Location','best');
    
    subplot(1,3,2); hold on; grid on;
    plot(Target.dz, KWH_init, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kezdeti');
    plot(Target.dz, KWH_opt,  'r-', 'LineWidth', 2,   'DisplayName', 'Optimált');
    xlabel('Rugóút (Z) [mm]'); ylabel('Wheel Rate Heave [N/mm]'); title('Wheel Rate (Heave)'); legend('Location','best');

    subplot(1,3,3); hold on; grid on;
    plot(Target.dz, f_ride_init, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kezdeti');
    plot(Target.dz, f_ride_opt,  'r-', 'LineWidth', 2,   'DisplayName', 'Optimált');
    xlabel('Rugóút (Z) [mm]'); ylabel('Ride Frequency [Hz]'); title('Ride Frequency'); legend('Location','best');
end

%% ========================================================================
%  PONT BETÖLTÉS – Multilink (Link 1-5) + Rocker
%  ========================================================================
function [points, fixed_mask] = load_all_points()
    points = struct('name', {}, 'pos', {}, 'fixed', {});

    points(1).name  = 'Link 1 Chassis';      points(1).pos = [-163.296, 223.853, 275.001];   points(1).fixed = true;
    points(2).name  = 'Link 1 Upright';      points(2).pos = [-47.619,  547.730, 271.831];   points(2).fixed = false;
    points(3).name  = 'Link 2 Chassis';      points(3).pos = [113.529,  229.240, 328.857];   points(3).fixed = true;
    points(4).name  = 'Link 2 Upright';      points(4).pos = [-6.093,   532.775, 255.714];   points(4).fixed = false;
    points(5).name  = 'Link 3 Chassis';      points(5).pos = [185.427,  221.378, 153.270];   points(5).fixed = true;
    points(6).name  = 'Link 3 Upright';      points(6).pos = [3.690,    575.746, 119.329];   points(6).fixed = false;
    points(7).name  = 'Link 4 Chassis';      points(7).pos = [-134.228, 176.043, 144.655];   points(7).fixed = true;
    points(8).name  = 'Link 4 Upright';      points(8).pos = [-9.584,   590.008, 103.664];   points(8).fixed = false;
    points(9).name  = 'Link 5 Chassis';      points(9).pos = [65.000,   244.000, 164.000];   points(9).fixed = true;
    points(10).name = 'Link 5 Upright';      points(10).pos = [107.837, 517.127, 186.890];   points(10).fixed = false;
    
    points(11).name = 'Pushrod Rocker';      points(11).pos = [-48.025, 153.151, 582.198]; points(11).fixed = false;
    points(12).name = 'Pushrod Upright';     points(12).pos = [-20.475, 482.786, 305.000]; points(12).fixed = false;
    points(13).name = 'Rocker Axis';         points(13).pos = [-84.470, 155.712, 545.260]; points(13).fixed = true;
    points(14).name = 'Rocker Center';       points(14).pos = [-86.840, 169.822, 563.784]; points(14).fixed = false;
    points(15).name = 'Damper Rocker';       points(15).pos = [-78.900, 110.016, 611.104]; points(15).fixed = false;
    points(16).name = 'Damper Chassis';      points(16).pos = [-253.279, 82.017, 610.122]; points(16).fixed = true;
    
    points(17).name = 'Wheel Center';        points(17).pos = [0, 610, 193];               points(17).fixed = false;

    % Multilink Excel override
    ml_file = '';
    d = dir('Multi_Points_Rear*.xlsx');
    if ~isempty(d)
        [~, idx] = sort([d.datenum], 'descend');
        ml_file = d(idx(1)).name;
    elseif exist('Suspension_Points_Multilink.xlsx', 'file') == 2
        ml_file = 'Suspension_Points_Multilink.xlsx';
    end
    if ~isempty(ml_file)
        disp(['Multilink pontok: ', ml_file]);
        T = readtable(ml_file);
        map = containers.Map( ...
            {'Link 1 Chassis','Link 1 Upright','Link 2 Chassis','Link 2 Upright', ...
             'Link 3 Chassis','Link 3 Upright','Link 4 Chassis','Link 4 Upright', ...
             'Link 5 Chassis','Link 5 Upright','Wheel Center'}, ...
            {1,2,3,4,5,6,7,8,9,10,17});
        for i = 1:height(T)
            nm = T.Name{i};
            if isKey(map, nm)
                idx = map(nm);
                points(idx).pos = [T.X(i), T.Y(i), T.Z(i)];
            end
        end
    end

    % Rocker Excel override
    rocker_file = 'Suspension_Points_Rocker.xlsx';
    if exist(rocker_file, 'file') == 2
        disp(['Rocker pontok: ', rocker_file]);
        T = readtable(rocker_file);
        map = containers.Map( ...
            {'Rocker Center','Rocker Axis','Rocker Pushrod','Rocker Damper', ...
             'Damper Chassis','Pushrod Upright', 'Pushrod Rocker', 'Damper Rocker'}, ...
            {14,13,11,15,16,12,11,15});
        for i = 1:height(T)
            nm = T.Name{i};
            if isKey(map, nm)
                idx = map(nm);
                points(idx).pos = [T.X(i), T.Y(i), T.Z(i)];
            end
        end
    else
        disp('Rocker sablon létrehozása: Suspension_Points_Rocker.xlsx');
        init_raw = {
            'Rocker Center',   points(14).pos(1), points(14).pos(2), points(14).pos(3);
            'Rocker Axis',     points(13).pos(1), points(13).pos(2), points(13).pos(3);
            'Rocker Pushrod',  points(11).pos(1), points(11).pos(2), points(11).pos(3);
            'Rocker Damper',   points(15).pos(1), points(15).pos(2), points(15).pos(3);
            'Damper Chassis',  points(16).pos(1), points(16).pos(2), points(16).pos(3);
            'Pushrod Upright', points(12).pos(1), points(12).pos(2), points(12).pos(3)
        };
        T_def = cell2table(init_raw, 'VariableNames', {'Name','X','Y','Z'});
        writetable(T_def, rocker_file);
    end
    
    points(12).fixed = true;
    points(13).fixed = true;
    points(14).fixed = true;
    points(16).fixed = true;

    fixed_mask = [points.fixed];
end

%% ========================================================================
%  COST (CSAK MR ALAPJÁN) – DAA-azonos
%  ========================================================================
function cost = calc_mr_cost(x, pts0, fixed_mask, opt_idx, Target, Veh)
    [~, ~, MR_vec, ~, ~] = sweep_kinematics(x, pts0, fixed_mask, opt_idx, Target.dz, Veh);

    if any(isnan(MR_vec))
        cost = 1e6;
        return;
    end
    cost = sum((MR_vec(:) - Target.MR(:)).^2);
end

%% ========================================================================
%  KINEMATIKAI ÁLLAPOT
%  Ugyanaz a multilink heave, mint a full_kinematic_optimalization_multilink:
%    - Kasztni (C) Z-je -= dz
%    - WC Z fix (föld)
%    - q = [WC_x, WC_y, rx, ry, rz]  →  5 link hossz (lsqnonlin)
%  + DAA rocker: PR, DR szabad, 5 távolságkényszer + pushrod hossz
%  ========================================================================
function [pts_out, q_out] = get_kinematic_state(dz, pts_base, geo, q0, opts)
    % q = [WC_x, WC_y, rx, ry, rz, PRx, PRy, PRz, DRx, DRy, DRz]  (1x11)

    C = geo.C_design;
    C(:,3) = C(:,3) - dz;                          % kasztni le
    Axis   = geo.Axis_design;   Axis(3)   = Axis(3)   - dz;
    Center = geo.Center_design; Center(3) = Center(3) - dz;
    DampCh = geo.DampCh_design; DampCh(3) = DampCh(3) - dz;

    obj = @(q) multilink_rocker_residuals(q, C, geo.K_loc, geo.WC_init, ...
        geo.L0, Axis, Center, geo.L_pr, geo.L_rocker);

    q_out = q0;
    try
        [qsol, resnorm, ~, exitflag] = lsqnonlin(obj, q0, [], [], opts);
        if exitflag <= 0 && resnorm > 1e-6
            pts_out = [];
            return;
        end
        q_out = qsol;
    catch
        pts_out = [];
        return;
    end

    pts_out = pts_base;
    WC = [qsol(1), qsol(2), geo.WC_init(3)];
    R  = euler_to_rot(qsol(3), qsol(4), qsol(5));
    PR = qsol(6:8);   % 1x3
    DR = qsol(9:11);  % 1x3

    for i = 1:5
        pts_out(2*i-1).pos = C(i,:);
    end
    pts_out(13).pos = Axis;
    pts_out(14).pos = Center;
    pts_out(16).pos = DampCh;

    K_idx = [2, 4, 6, 8, 10, 12];
    for i = 1:6
        pts_out(K_idx(i)).pos = (WC(:) + R * geo.K_loc(i,:)')';
    end
    pts_out(11).pos = PR;
    pts_out(15).pos = DR;
    pts_out(17).pos = WC;
end

%% ========================================================================
%  Residual – azonos a full_kinematic multilink calc_link_errors-szel
%  + pushrod + rocker (minden vektor 1x3)
%  ========================================================================
function res = multilink_rocker_residuals(q, C, K_loc, WC_init, L0, Axis, Center, L_pr, L_rocker)
    WC = [q(1), q(2), WC_init(3)];          % 1x3, Z fix
    R  = euler_to_rot(q(3), q(4), q(5));
    PR = [q(6), q(7), q(8)];                % 1x3
    DR = [q(9), q(10), q(11)];              % 1x3

    res = zeros(11, 1);

    % --- 5 link hossz (ugyanaz, mint calc_link_errors) ---
    for i = 1:5
        Ku = (WC(:) + R * K_loc(i,:)')';   % 1x3
        res(i) = norm(Ku - C(i,:)) - L0(i);
    end

    % --- Pushrod hossz: PR → Pushrod Upright (K_loc 6. sor) ---
    PU = (WC(:) + R * K_loc(6,:)')';       % 1x3
    res(6) = norm(PR - PU) - L_pr;

    % --- Rocker merevség (DAA-azonos 5 távolság, Axis+Center kasztni) ---
    res(7)  = norm(PR - Axis)   - L_rocker(1);  % PR – Axis
    res(8)  = norm(PR - Center) - L_rocker(2);  % PR – Center
    res(9)  = norm(DR - Axis)   - L_rocker(3);  % DR – Axis
    res(10) = norm(DR - Center) - L_rocker(4);  % DR – Center
    res(11) = norm(PR - DR)     - L_rocker(5);  % PR – DR
end

function R = euler_to_rot(rx, ry, rz)
    % Azonos a full_kinematic_optimalization_multilink euler_to_rot-jával
    Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
    Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
    Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
    R = Rz * Ry * Rx;
end

%% ========================================================================
%  Design geometria
%  ========================================================================
function geo = build_geo(pts)
    WC = pts(17).pos;                       % 1x3
    geo.WC_init = WC;

    geo.C_design = zeros(5,3);
    for i = 1:5
        geo.C_design(i,:) = pts(2*i-1).pos; % Link i Chassis
    end

    K_idx = [2, 4, 6, 8, 10, 12];            % upright + pushrod upright
    geo.K_loc = zeros(6,3);
    for i = 1:6
        geo.K_loc(i,:) = pts(K_idx(i)).pos - WC;
    end

    geo.L0 = zeros(5,1);
    for i = 1:5
        geo.L0(i) = norm(pts(2*i).pos - pts(2*i-1).pos);
    end

    geo.L_pr = norm(pts(11).pos - pts(12).pos);

    geo.L_rocker = [
        norm(pts(11).pos - pts(13).pos);    % PR – Axis
        norm(pts(11).pos - pts(14).pos);    % PR – Center
        norm(pts(15).pos - pts(13).pos);    % DR – Axis
        norm(pts(15).pos - pts(14).pos);    % DR – Center
        norm(pts(11).pos - pts(15).pos)     % PR – DR
    ];

    geo.Axis_design   = pts(13).pos;
    geo.Center_design = pts(14).pos;
    geo.DampCh_design = pts(16).pos;
end

%% ========================================================================
%  KINEMATIKAI SWEEP – DAA-azonos MR számítás
%  ========================================================================
function [f_ride_vec, f_roll_vec, MR_vec, KWH_vec, KRoll_vec] = ...
        sweep_kinematics(x, pts0, fixed_mask, opt_idx, dz_vec, Veh)

    N = length(dz_vec);
    f_ride_vec = nan(1, N);
    f_roll_vec = nan(1, N);
    MR_vec     = nan(1, N);
    KWH_vec    = nan(1, N);
    KRoll_vec  = nan(1, N);

    pts = pts0;
    k = 1;
    for i = 1:length(opt_idx)
        pts(opt_idx(i)).pos = x(k:k+2);
        k = k + 3;
    end

    geo = build_geo(pts);

    % lsqnonlin – ugyanaz, mint a full_kinematic multilink opt_inner
    opts = optimoptions('lsqnonlin', 'Display', 'off', ...
        'FunctionTolerance', 1e-10, 'MaxIterations', 80);

    q0 = [geo.WC_init(1), geo.WC_init(2), 0, 0, 0, ...
          pts(11).pos(1), pts(11).pos(2), pts(11).pos(3), ...
          pts(15).pos(1), pts(15).pos(2), pts(15).pos(3)];

    delta_z = 0.5;

    for i = 1:N
        dz = dz_vec(i);

        [pts_m, qm] = get_kinematic_state(dz - delta_z, pts, geo, q0, opts);
        [pts_p, qp] = get_kinematic_state(dz + delta_z, pts, geo, q0, opts);

        if isempty(pts_m) || isempty(pts_p)
            continue;
        end

        % Melegindítás a következő ponthoz
        q0 = qp;

        L_m = norm(pts_m(15).pos - pts_m(16).pos);
        L_p = norm(pts_p(15).pos - pts_p(16).pos);

        d_damper = L_p - L_m;
        if abs(d_damper) < 1e-12
            continue;
        end
        % MR = |dWheel / dDamper|  (DAA: abs a biztonság kedvéért)
        MR = abs((2 * delta_z) / d_damper);
        if ~isfinite(MR) || MR <= 0
            continue;
        end
        MR_vec(i) = MR;

        K_wheel_s = (Veh.K_spring / 1000) / (MR^2);
        KWH_vec(i) = K_wheel_s;

        K_t = Veh.K_tire / 1000;
        K_ride = (K_t * K_wheel_s) / (K_t + K_wheel_s);
        f_ride_vec(i) = (1/(2*pi)) * sqrt((K_ride * 1000 * 4) / Veh.sm_mass);

        T_m = Veh.Trackwidth / 1000;
        K_wheel_N_m = K_wheel_s * 1000;
        K_Roll_Front_Nm_rad = K_wheel_N_m * (T_m^2) / 2;
        KRoll_vec(i) = K_Roll_Front_Nm_rad * (pi / 180);
        f_roll_vec(i) = (1/(2*pi)) * sqrt(K_Roll_Front_Nm_rad / Veh.Inertia_RC);
    end
end

%% ========================================================================
%  GUI / STOP / EXCEL – DAA-azonos
%  ========================================================================
function stop = stop_optimization_callback(~, ~, ~)
    stop = false;
    if exist('stop_opt.txt', 'file') == 2
        fprintf('\n>>> FELHASZNÁLÓI MEGSZAKÍTÁS: stop_opt.txt észlelve! <<<\n');
        try, delete('stop_opt.txt'); catch, end
        stop = true;
    end
end

function [x_out, y_out] = get_excel_pts(loaded_data, row_idx, eval_pts)
    x_out = eval_pts(:);
    y_out = zeros(length(eval_pts), 1);
    if ~isempty(loaded_data) && size(loaded_data,1) >= row_idx
        for i = 1:length(eval_pts)
            if size(loaded_data,2) >= i+1
                val = loaded_data{row_idx, i+1};
                if isnumeric(val) && ~isnan(val)
                    y_out(i) = val;
                end
            end
        end
    end
end

function curve_out = defineTargetCurveGUI(name, x_min, x_max, x_label, y_label, init_x, init_y)
    if nargin >= 7 && ~isempty(init_x)
        x_pts = init_x(:);
        y_pts = init_y(:);
    else
        x_pts = [x_min; 0; x_max];
        y_pts = [0; 0; 0];
    end

    fig = figure('Name', ['Célgörbe Szerkesztő: ', name], ...
        'NumberTitle', 'off', 'Position', [200 150 1000 600], ...
        'MenuBar', 'none', 'ToolBar', 'figure', 'DockControls', 'off');

    ax = axes('Parent', fig, 'Position', [0.08 0.12 0.58 0.8]);
    grid(ax, 'on'); hold(ax, 'on');
    xlabel(ax, x_label); ylabel(ax, y_label);

    y_min_val = min(y_pts) - 0.2; y_max_val = max(y_pts) + 0.2;
    if y_min_val == y_max_val, y_min_val = y_min_val - 0.5; y_max_val = y_max_val + 0.5; end
    xlim(ax, [x_min, x_max]); ylim(ax, [y_min_val, y_max_val]);

    pnl = uipanel('Parent', fig, 'Title', 'Vezérlők & Pontok', 'Position', [0.69 0.05 0.29 0.9]);

    uicontrol(pnl, 'Style', 'text', 'String', 'Pontok listája (X, Y):', ...
        'Position', [10 490 200 20], 'HorizontalAlignment', 'left');
    lst_points = uicontrol(pnl, 'Style', 'listbox', 'Position', [10 340 250 150]);

    uicontrol(pnl, 'Style', 'text', 'String', 'X:', 'Position', [10 305 20 20]);
    txt_x = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [30 305 55 22]);
    uicontrol(pnl, 'Style', 'text', 'String', 'Y:', 'Position', [90 305 20 20]);
    txt_y = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [110 305 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Hozzáad', ...
        'Position', [170 305 90 22], 'Callback', @add_point_manual);

    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Kijelölt Pont Törlése', ...
        'Position', [10 270 250 28], 'Callback', @delete_selected_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Utolsó Visszavonása (Undo)', ...
        'Position', [10 235 250 28], 'Callback', @undo_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Minden Pont Törlése', ...
        'Position', [10 200 250 28], 'Callback', @clear_points);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y min / Y max skála:', ...
        'Position', [10 160 120 20], 'HorizontalAlignment', 'left');
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_min_val), 'Position', [10 135 55 22]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_max_val), 'Position', [70 135 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Skála Beállítása', ...
        'Position', [135 135 125 22], 'Callback', @update_axes_limits);

    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Megtart / Ugrás (Skip)', ...
        'Position', [10 80 250 35], 'BackgroundColor', [0.85 0.9 0.85], 'Callback', @skip_callback);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Mentés és Folytatás', ...
        'Position', [10 30 250 40], 'BackgroundColor', [0.2 0.7 0.2], ...
        'ForegroundColor', [1 1 1], 'FontWeight', 'bold', 'Callback', @save_callback);

    set(fig, 'WindowButtonDownFcn', @click_on_axes);
    update_plot_and_list();
    uiwait(fig);

    z_eval = linspace(x_min, x_max, 31)';
    if isempty(x_pts)
        x_sorted = [x_min; x_max]; y_sorted = [1; 1];
    else
        [x_sorted, s_idx] = sort(x_pts); y_sorted = y_pts(s_idx);
        [x_sorted, u_idx] = unique(x_sorted); y_sorted = y_sorted(u_idx);
    end
    if length(x_sorted) < 2
        x_sorted = [x_min; x_max]; y_sorted = [1; 1];
    end
    curve_out = interp1(x_sorted, y_sorted, z_eval, 'pchip', 'extrap');

    if ishandle(fig), close(fig); end

    function click_on_axes(~, ~)
        cp = get(ax, 'CurrentPoint'); cx = cp(1,1); cy = cp(1,2);
        xl = xlim(ax); yl = ylim(ax);
        if cx >= xl(1) && cx <= xl(2) && cy >= yl(1) && cy <= yl(2)
            x_pts(end+1, 1) = cx; y_pts(end+1, 1) = cy;
            update_plot_and_list();
        end
    end
    function add_point_manual(~, ~)
        nx = str2double(get(txt_x, 'String')); ny = str2double(get(txt_y, 'String'));
        if ~isnan(nx) && ~isnan(ny)
            x_pts(end+1, 1) = nx; y_pts(end+1, 1) = ny;
            update_plot_and_list();
        end
    end
    function delete_selected_point(~, ~)
        if isempty(x_pts), return; end
        idx = get(lst_points, 'Value');
        if isempty(idx) || idx < 1 || idx > length(x_pts), return; end
        x_pts(idx) = []; y_pts(idx) = [];
        update_plot_and_list();
    end
    function undo_point(~, ~)
        if ~isempty(x_pts)
            x_pts(end) = []; y_pts(end) = [];
            update_plot_and_list();
        end
    end
    function clear_points(~, ~)
        x_pts = []; y_pts = [];
        update_plot_and_list();
    end
    function update_axes_limits(~, ~)
        ymin_n = str2double(get(txt_ymin, 'String'));
        ymax_n = str2double(get(txt_ymax, 'String'));
        if ~isnan(ymin_n) && ~isnan(ymax_n) && ymax_n > ymin_n
            ylim(ax, [ymin_n, ymax_n]);
        end
    end
    function skip_callback(~, ~), uiresume(fig); end
    function save_callback(~, ~), uiresume(fig); end

    function update_plot_and_list()
        cla(ax); grid(ax, 'on'); hold(ax, 'on');
        if length(x_pts) >= 2
            [xs, s_idx] = sort(x_pts); ys = y_pts(s_idx);
            [xs, u_idx] = unique(xs); ys = ys(u_idx);
            z_fit = linspace(x_min, x_max, 100);
            y_fit = interp1(xs, ys, z_fit, 'pchip', 'extrap');
            plot(ax, z_fit, y_fit, 'b-', 'LineWidth', 2);
        end
        if ~isempty(x_pts)
            plot(ax, x_pts, y_pts, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        end
        str_list = cell(length(x_pts), 1);
        for i = 1:length(x_pts)
            str_list{i} = sprintf('%d:  X = %.2f,  Y = %.2f', i, x_pts(i), y_pts(i));
        end
        set(lst_points, 'String', str_list);
        if ~isempty(str_list)
            set(lst_points, 'Value', min(get(lst_points, 'Value'), length(str_list)));
            if get(lst_points, 'Value') < 1
                set(lst_points, 'Value', length(str_list));
            end
        end
    end
end

%% ========================================================================
%  NONLCON: ÜTKÖZÉS, SÍK, FELÜLET – DAA-azonos logika
%  ========================================================================
function [c, ceq] = rocker_collision_and_plane_nonlcon(x, pts0, opt_idx, ...
    Collision, EnforcePlane, TargetAxisDist, TargetMaxArea, F1)

    c = [];
    ceq = [];

    pts = pts0;
    k = 1;
    for i = 1:length(opt_idx)
        pts(opt_idx(i)).pos = x(k:k+2);
        k = k + 3;
    end

    % % Axis – Center távolság
    % if ~isempty(TargetAxisDist) && any(ismember(opt_idx, [13 14]))
    %     current_dist = norm(pts(14).pos - pts(13).pos);
    %     ceq(end+1) = current_dist - TargetAxisDist;
    % end
    % 
    % % Sík kényszer
    % if EnforcePlane && any(ismember(opt_idx, [11 14 15]))
    %     p_c_orig = pts0(14).pos;
    %     p_d_orig = pts0(15).pos;
    %     p_p_orig = pts0(11).pos;
    %     n_orig = cross(p_d_orig - p_c_orig, p_p_orig - p_c_orig);
    %     n_orig = n_orig / (norm(n_orig) + 1e-15);
    % 
    %     p_c_new = pts(14).pos;
    %     ceq(end+1) = dot(pts(15).pos - p_c_new, n_orig);
    %     ceq(end+1) = dot(pts(11).pos - p_c_new, n_orig);
    % end

    [c_g, ceq_g] = rocker_geometry_constraints(pts, opt_idx, TargetAxisDist);
    ceq = [ceq, ceq_g];
    c   = [c(:); c_g(:)];
    
    % Max felület
    if ~isempty(TargetMaxArea)
        p_c_new = pts(14).pos;
        p_p_new = pts(11).pos;
        p_d_new = pts(15).pos;
        current_area = 0.5 * norm(cross(p_p_new - p_c_new, p_d_new - p_c_new));
        c(end+1) = current_area - TargetMaxArea;
    end

    % Ütközés a mozgástartományban
    geo = build_geo(pts);
    opts = optimoptions('lsqnonlin', 'Display', 'off', ...
        'FunctionTolerance', 1e-10, 'MaxIterations', 80);
    q0 = [geo.WC_init(1), geo.WC_init(2), 0, 0, 0, ...
          pts(11).pos(1), pts(11).pos(2), pts(11).pos(3), ...
          pts(15).pos(1), pts(15).pos(2), pts(15).pos(3)];

    dz_col_vec = linspace(-30, 30, 7);
    rim_axis = Collision.wheel_axis0(:)';     % F1: Legality Setup camber (FS: [0 1 0])

    % F1 C10.3.6c: pushrod keresztmetszet-dőlés a rugóút mentén (Legality Setup = design)
    do_inc = F1.Enable && F1.CheckPushrodIncidence;
    L_pr0  = pts(11).pos - pts(12).pos;
    m_pr0  = f1_major_axis0(L_pr0);

    for dz = dz_col_vec
        [pts_dz, q0] = get_kinematic_state(dz, pts, geo, q0, opts);

        if isempty(pts_dz)
            c(end+1, 1) = 1e3;
            c(end+1, 1) = 1e3;
            if do_inc, c(end+1, 1) = 1e3; end
            continue;
        end

        p11 = pts_dz(11).pos;
        p12 = pts_dz(12).pos;
        wc  = pts_dz(17).pos;

        if Collision.use_motor
            mc = wc + Collision.motor_y_offset * rim_axis;
            d_motor = segment_finite_cylinder_distance(p11, p12, mc, rim_axis, ...
                Collision.motor_radius, Collision.motor_length);
            need_motor = (Collision.rod_diameter_pushrod / 2) + Collision.min_clearance;
            c(end+1, 1) = need_motor - d_motor;
        else
            c(end+1, 1) = -100;   % F1: nincs agymotor (fix méretű, biztonságos sor)
        end

        if do_inc
            m_pr = f1_rot_between(L_pr0, p11 - p12) * m_pr0;
            c(end+1, 1) = abs(f1_incidence(m_pr) - f1_incidence(m_pr0)) - F1.IncidenceHeaveMax;
        end

        rim_center = wc + Collision.rim_y_offset * rim_axis;
        d_rim = segment_rim_annulus_distance(p11, p12, rim_center, rim_axis, ...
            Collision.rim_inner_radius, Collision.rim_outer_radius, Collision.rim_width / 2);
        need_rim = (Collision.rod_diameter_pushrod / 2) + Collision.min_clearance;
        c(end+1, 1) = need_rim - d_rim;
    end
end

function [c, ceq] = geo_only_nonlcon(x, pts0, opt_idx, TargetAxisDist)
pts = pts0; k = 1;
for i = 1:length(opt_idx), pts(opt_idx(i)).pos = x(k:k+2); k = k + 3; end
[c, ceq] = rocker_geometry_constraints(pts, opt_idx, TargetAxisDist);
end

function [c_g, ceq_g] = rocker_geometry_constraints(pts, opt_idx, TargetAxisDist)
A  = pts(13).pos;  C  = pts(14).pos;       % Axis, Center
PR = pts(11).pos;  DR = pts(15).pos;       % rod rocker, damper rocker
PU = pts(12).pos;  DC = pts(16).pos;       % rod upright, damper chassis
c_g = [];  ceq_g = [];

if ismember(14, opt_idx) || ismember(13, opt_idx)
    n = (C - A) / (norm(C - A) + 1e-12);   % tengely irány = sík normális
    ceq_g = [dot(n, C  - DC), ...          % Center a síkban
        dot(n, PR - DC), ...          % rod rocker pont a síkban
        dot(n, DR - DC), ...          % damper rocker pont a síkban
        dot(n, PU - DC)];             % rod upright pont a síkban
end

if ~isempty(TargetAxisDist) && (ismember(13, opt_idx) || ismember(14, opt_idx))
    ceq_g(end+1) = norm(C - A) - TargetAxisDist;
end
end

%% ========================================================================
%  TÁVOLSÁGSZÁMÍTÓ FÜGGVÉNYEK – DAA-azonos
%  ========================================================================
function d = segment_finite_cylinder_distance(p0, p1, c_center, c_axis, radius, height)
    p0 = p0(:); p1 = p1(:); c_center = c_center(:); c_axis = c_axis(:);
    c_axis = c_axis / (norm(c_axis) + 1e-15);
    n = 24; d = inf; half_h = height / 2;
    for i = 0:n
        t = i/n; p = p0 + t*(p1-p0); w = p - c_center;
        axial = dot(w, c_axis); radial = norm(w - axial * c_axis);
        if abs(axial) <= half_h, d = min(d, max(0, radial - radius));
        else
            if radial <= radius, d = min(d, abs(axial) - half_h);
            else, d = min(d, norm([radial - radius; abs(axial) - half_h])); end
        end
    end
end

function d = segment_rim_annulus_distance(p0, p1, rim_center, rim_axis, r_inner, r_outer, half_w)
    p0 = p0(:); p1 = p1(:); rim_center = rim_center(:);
    rim_axis = rim_axis(:) / (norm(rim_axis) + 1e-15);
    n_samples = 24; d = inf;
    for k = 0:n_samples
        t = k / n_samples; pt = p0 + t * (p1 - p0); w = pt - rim_center;
        axial = dot(w, rim_axis); radial = norm(w - axial * rim_axis);
        if abs(axial) <= half_w
            if radial < r_inner, d_pt = r_inner - radial;
            elseif radial > r_outer, d_pt = radial - r_outer;
            else, d_pt = 0; end
            d = min(d, d_pt);
        end
    end
    if isinf(d), d = 1e6; end
end

%% =====================================================================
%% F1 2026 SZABÁLYZAT (Section C10, Issue 20) – KÖZÖS SEGÉDFÜGGVÉNYEK
%% (mind a 4 optimalizálóban azonos blokk)
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
% C10.1c / C10.10.1 / gumiméret – a WC az optimalizálás alatt rögzített, ezért induláskori ellenőrzés.
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

function d = f1_point_line_dist(P, A, B)
% Pont távolsága az A-B egyenestől (terhelési vonal).
    u = (B(:) - A(:)) / norm(B - A); w = P(:) - A(:);
    d = norm(w - u * (u' * w));
end

function s = f1_side_yz(P, A, B)
% Elölnézetben (YZ) a P pont előjeles távolsága az A-B egyenestől.
    e = [B(2) - A(2), B(3) - A(3)]; w = [P(2) - A(2), P(3) - A(3)];
    s = (e(1) * w(2) - e(2) * w(1)) / (norm(e) + 1e-12);
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
