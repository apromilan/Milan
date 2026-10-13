function full_kinematic_optimalization_DAA
% =========================================================================
% DOUBLE A-ARM KINEMATIKAI OPTIMALIZÁLÓ - ANTI-DIVE BŐVÍTÉSSEL
% - opt10.m struktúra / GUI / célgörbék / súlyok / stop / verziókezelés
% - DAA_full3.m kinematika + paraméterszámítás (camber, toe, RC, KPI, ...)
% - Ütközés: rúd–rúd, rúd–motor, rúd–felni (max büntetés)
% - Bővítve: Side IC alapú Anti-Dive számolás és optimalizálás (Heave-re)
% =========================================================================
    % clc; clear; close all;

    disp('========================================================');
    disp(' DOUBLE A-ARM KINEMATIKAI OPTIMALIZÁLÓ (V1.0)');
    disp(' - Ackermann, Heave, Steer, Chassis Roll, Anti-Dive');
    disp(' - Célgörbék GUI + Excel');
    disp(' - Interaktív Plotter');
    disp(' - Ütközés / clearance kényszer');
    disp('========================================================');
    disp('TIPP: Leállításhoz hozd létre a "stop_opt.txt" fájlt!');
    disp('========================================================');

    %% 1. CÉLOK ÉS SÚLYOK
    USE_GUI_FOR_CURVES = true;

    Vehicle.Wheelbase      = 3000;
    Vehicle.Trackwidth     = 1600;
    Vehicle.FrontBrakeBias = 64;   % % front brake bias
    Vehicle.h_CG_SM_static = 320;  % statikus rugózott tömeg CG magasság [mm]

    Target.dz    = -30:1:30;
    Target.dy    = linspace(-30, 30, 61);
    Target.droll = linspace(-2, 2, 61);

    target_excel = 'Célgörbe_Front.xlsx';
    loaded_data = {};
    eval_pts = -30:3:30;
    eval_pts_roll = linspace(-2, 2, 21);

    if exist(target_excel, 'file') == 2
        disp(['Célgörbe betöltése: ', target_excel]);
        loaded_data = readcell(target_excel);
    end

    %% 0. SÚLYOK (a célgörbék bekérése előtt kell megadni!)
    % Kormányzási (rack Y) blokk: ha egy súly = 0, akkor az a mennyiség
    %   - nem kerül be a cost függvénybe (nem is számoljuk ki feleslegesen),
    %   - a GUI nem kéri be hozzá a célgörbét (az Excelből betöltött érték változatlan marad).
    % Példa: W.KPI = 0; W.Caster = 0; W.Ackermann = 0;  ->  kormányzásra csak
    % a Camber_Steer és Toe_Steer célgörbét kell megadni.
    camber_heave_tol = 0.01;
    toe_heave_tol = 0.01;
    rc_tol = 0.5;
    antidive_tol = 0.5;
    camber_steer_tol = 0.01;
    toe_steer_tol = 0.01;
    kpi_tol = 5;
    caster_tol = 5;
    trail_tol = 0.01;
    scrub_tol = 0.01;
    ackerman_tol = 2;
    camber_roll_tol = 0.01;
    toe_roll_tol = 0.01;

    W.Camber = 1/camber_heave_tol^2; 
    W.Toe = 1/toe_heave_tol^2; 
    W.RC_Z = 1/rc_tol^2;
    W.AntiDive = 1/antidive_tol^2;
    W.Camber_Steer = 1/camber_steer_tol^2;   % Camber a kormánymű elmozdulás (Y) függvényében
    W.Toe_Steer    = 1/toe_steer_tol^2;   % Toe a kormánymű elmozdulás (Y) függvényében
    W.KPI = 0;           % 0 -> nincs figyelembe véve
    W.Caster = 0;        % 0 -> nincs figyelembe véve
    W.Trail = 1/trail_tol^2; 
    W.Scrub = 1/scrub_tol^2; 
    W.Ackermann = 0;      % 0 -> nincs figyelembe véve (jobb oldali szimuláció is kimarad)
    W.Camber_Roll = 1/camber_roll_tol^2; 
    W.Toe_Roll = 1/toe_roll_tol^2;

    % W.Camber = 800; 
    % W.Toe = 800; 
    % W.RC_Z = 100;
    % W.AntiDive = 50;
    % W.Camber_Steer = 800;   % Camber a kormánymű elmozdulás (Y) függvényében
    % W.Toe_Steer    = 800;   % Toe a kormánymű elmozdulás (Y) függvényében
    % W.KPI = 0;           % 0 -> nincs figyelembe véve
    % W.Caster = 0;        % 0 -> nincs figyelembe véve
    % W.Trail = 30; 
    % W.Scrub = 30; 
    % W.Ackermann = 0;      % 0 -> nincs figyelembe véve (jobb oldali szimuláció is kimarad)
    % W.Camber_Roll = 800; 
    % W.Toe_Roll = 800;

    % Melyik kormányzási célgörbe aktív (a plotter ez alapján rajzolja a célgörbét)
    Target.Use.Camber_Steer = W.Camber_Steer > 0;
    Target.Use.Toe_Steer    = W.Toe_Steer    > 0;
    Target.Use.KPI          = W.KPI          > 0;
    Target.Use.Caster       = W.Caster       > 0;
    Target.Use.Trail        = W.Trail        > 0;
    Target.Use.Scrub        = W.Scrub        > 0;
    Target.Use.Ackermann    = W.Ackermann    > 0;

    if USE_GUI_FOR_CURVES
        disp('Grafikus célgörbék...');
        [x_init, y_init] = get_excel_pts(loaded_data, 3, eval_pts);
        Target.Camber = defineTargetCurveGUI('Camber (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Camber [deg]', x_init, y_init);

        [x_init, y_init] = get_excel_pts(loaded_data, 4, eval_pts);
        Target.Toe = defineTargetCurveGUI('Toe (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Toe [deg]', x_init, y_init);

        [x_init, y_init] = get_excel_pts(loaded_data, 5, eval_pts);
        Target.RC_Z = defineTargetCurveGUI('Roll Center Z', -30, 30, 'Rugóút (Z) [mm]', 'RC Magasság [mm]', x_init, y_init);
        
        % JAVÍTÁS: Anti-Dive GUI
        [x_init, y_init] = get_excel_pts(loaded_data, 11, eval_pts);
        Target.AntiDive = defineTargetCurveGUI('Anti-Dive (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Anti-Dive [%]', x_init, y_init);

        % Kormányzás (rack Y) célgörbék: csak a 0-nál nagyobb súlyú mennyiségeknél jön fel a GUI
        Target.Camber_Steer = pick_steer_curve(W.Camber_Steer > 0, loaded_data, 14, eval_pts, Target.dy, 'Camber (Kormányzás)', 'Camber [deg]');
        Target.Toe_Steer    = pick_steer_curve(W.Toe_Steer    > 0, loaded_data, 15, eval_pts, Target.dy, 'Toe (Kormányzás)', 'Toe [deg]');
        Target.KPI          = pick_steer_curve(W.KPI          > 0, loaded_data, 17, eval_pts, Target.dy, 'KPI', 'KPI [deg]');
        Target.Caster       = pick_steer_curve(W.Caster       > 0, loaded_data, 18, eval_pts, Target.dy, 'Caster', 'Caster [deg]');
        Target.Trail        = pick_steer_curve(W.Trail        > 0, loaded_data, 19, eval_pts, Target.dy, 'Mechanical Trail', 'Trail [mm]');
        Target.Scrub        = pick_steer_curve(W.Scrub        > 0, loaded_data, 20, eval_pts, Target.dy, 'Scrub Radius', 'Scrub [mm]');
        Target.Ackermann    = pick_steer_curve(W.Ackermann    > 0, loaded_data, 21, eval_pts, Target.dy, 'Ackermann', 'Ackermann [%]');

        [x_init, y_init] = get_excel_pts(loaded_data, 25, eval_pts_roll);
        Target.Camber_Roll = defineTargetCurveGUI('Camber (Roll)', -2, 2, 'Dőlés (Roll) [deg]', 'Camber [deg]', x_init, y_init);

        [x_init, y_init] = get_excel_pts(loaded_data, 26, eval_pts_roll);
        Target.Toe_Roll = defineTargetCurveGUI('Toe (Roll)', -2, 2, 'Dőlés (Roll) [deg]', 'Toe [deg]', x_init, y_init);
    else
        Target.Camber = -0.02*Target.dz - 1.0;
        Target.Toe = 0*Target.dz;
        Target.RC_Z = 45 - 0.05*abs(Target.dz);
        Target.AntiDive = 0*Target.dz;  % Default Anti-dive célgörbe ha nincs GUI
        Target.KPI = 12 + 0*Target.dy;
        Target.Caster = 5 + 0*Target.dy;
        Target.Trail = 25 + 0*Target.dy;
        Target.Scrub = -10 + 0*Target.dy;
        Target.Ackermann = 100 + 0*Target.dy;
        Target.Camber_Steer = 0*Target.dy;
        Target.Toe_Steer = 0*Target.dy;
        Target.Camber_Roll = -0.5*Target.droll;
        Target.Toe_Roll = 0*Target.droll;
    end

    out_cell = cell(32, 22); out_cell(:) = {''};
    out_cell{1,12} = 'Heave'; out_cell(2,2:22) = num2cell(eval_pts);
    rows = {'Camber','Toe','RollCenter','KPI','Caster','MechTrail','Scrub','Ackerman'};
    out_cell(3:10,1) = rows'; out_cell(3:10,2:22) = num2cell(zeros(8,21));
    out_cell(3,2:22) = num2cell(interp1(Target.dz, Target.Camber, eval_pts, 'pchip', 'extrap'));
    out_cell(4,2:22) = num2cell(interp1(Target.dz, Target.Toe, eval_pts, 'pchip', 'extrap'));
    out_cell(5,2:22) = num2cell(interp1(Target.dz, Target.RC_Z, eval_pts, 'pchip', 'extrap'));
    
    % JAVÍTÁS: Anti-Dive hozzáadása Excel 11. sorához
    out_cell{11,1} = 'Anti-Dive'; 
    out_cell(11,2:22) = num2cell(interp1(Target.dz, Target.AntiDive, eval_pts, 'pchip', 'extrap'));

    out_cell{12,12} = 'Rack Movement'; out_cell(13,2:22) = num2cell(eval_pts);
    out_cell(14:21,1) = rows'; out_cell(14:21,2:22) = num2cell(zeros(8,21));
    out_cell(14,2:22) = num2cell(interp1(Target.dy, Target.Camber_Steer, eval_pts, 'pchip', 'extrap'));
    out_cell(15,2:22) = num2cell(interp1(Target.dy, Target.Toe_Steer, eval_pts, 'pchip', 'extrap'));
    out_cell(17,2:22) = num2cell(interp1(Target.dy, Target.KPI, eval_pts, 'pchip', 'extrap'));
    out_cell(18,2:22) = num2cell(interp1(Target.dy, Target.Caster, eval_pts, 'pchip', 'extrap'));
    out_cell(19,2:22) = num2cell(interp1(Target.dy, Target.Trail, eval_pts, 'pchip', 'extrap'));
    out_cell(20,2:22) = num2cell(interp1(Target.dy, Target.Scrub, eval_pts, 'pchip', 'extrap'));
    out_cell(21,2:22) = num2cell(interp1(Target.dy, Target.Ackermann, eval_pts, 'pchip', 'extrap'));

    out_cell{23,12} = 'Chassis Roll'; out_cell(24,2:22) = num2cell(eval_pts_roll);
    out_cell(25:32,1) = rows'; out_cell(25:32,2:22) = num2cell(zeros(8,21));
    out_cell(25,2:22) = num2cell(interp1(Target.droll, Target.Camber_Roll, eval_pts_roll, 'pchip', 'extrap'));
    out_cell(26,2:22) = num2cell(interp1(Target.droll, Target.Toe_Roll, eval_pts_roll, 'pchip', 'extrap'));

    curves_changed = true;
    if ~isempty(loaded_data)
        try
            % A 11. sor is a betöltött adatok közé került az Anti-Dive miatt
            old_mat = cell2mat(loaded_data([3:5,11,14:21,25:26], 2:22));
            new_mat = cell2mat(out_cell([3:5,11,14:21,25:26], 2:22));
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
        while exist(sprintf('Célgörbe_Front_%d.xlsx', file_idx), 'file') == 2
            file_idx = file_idx + 1;
        end
        new_f = sprintf('Célgörbe_Front_%d.xlsx', file_idx);
        writecell(out_cell, new_f);
        disp(['Új célgörbe fájl: ', new_f]);
    else
        disp('Célgörbék változatlanok.');
    end


    %% 1a. F1 2026 SZABÁLYZAT (Section C10) – KÉNYSZEREK
    % Az alapértékek szabálypontonként a f1_rules_2026() függvényben vannak (a fájl végén).
    % A saját autódra itt állítsd be:
    F1 = f1_rules_2026('front');       % 'front' | 'rear'  (ez az első DAA)
    F1.RefPlaneZ       = 45;           % [mm] az F1 Z=0 referenciasík magassága a talaj felett (Legality Setup)
    F1.Rim.InnerRadius = 215;          % [mm] a felni belső (hordó) sugara – CAD / RV-F-RIM-MIN
    F1.SteerCheckRack  = 30;           % [mm] C10.3.6c kormányzási tartomány (±rack)
    F1.MaxRackTravel   = Inf;          % [mm] ha véges: a +23°/-21° lockhoz szükséges rack-út korlátja
    % F1.Drum.Enable = true; F1.Drum.Radius = ...; F1.Drum.YW = [..., ...];   % C10.3.4c / C3.14.2
    % F1.Enable = false;               % F1 kényszerek ki (eredeti FS működés)

    %% 1b. ÜTKÖZÉS / CLEARANCE PARAMÉTEREK
    Collision.rod_diameter_upper = 20;   
    Collision.rod_diameter_lower = 20;   
    Collision.rod_diameter_tie   = 12;   
    Collision.min_clearance      = 5;    

    % Collision.motor_center = [0, 546.6, 193]; 
    % Collision.motor_radius = 48;            
    % Collision.motor_length = 160.2;          
    % Collision.motor_axis   = [0, 1, 0];     

    Collision.motor_radius = 48;             % A henger sugara
    Collision.motor_length = 160.2;          % A henger teljes hossza
    Collision.motor_y_offset = -63.4;        % Eltolás a kerékközépponttól a tengely mentén (546.6 - 610)

    Collision.rim_inner_radius = 117;
    Collision.rim_outer_radius = 124.5;
    Collision.rim_width        = 195;
    Collision.rim_y_offset     = 0;

    % --- F1 2026: felni a C10.7.2 szerint, nincs agymotor (felülírja a fenti FS értékeket) ---
    if F1.Enable
        Collision.use_motor        = false;
        Collision.rim_inner_radius = F1.Rim.InnerRadius;
        Collision.rim_outer_radius = F1.Rim.OuterRadius;    % Ø496 perem
        Collision.rim_width        = F1.Rim.Width;          % 334 / 420.3
        Collision.rim_y_offset     = F1.Rim.CenterOffset;
        Collision.wheel_axis0      = f1_wheel_axes(F1);     % Legality Setup camber (-3° / -1°)
    else
        Collision.use_motor   = true;
        Collision.wheel_axis0 = [0; 1; 0];
    end

    Collision.penalty = 1e0;

    %% 2. DAA HARDPOINTOK
    input_excel = 'Suspension_Points_DAA_Front.xlsx';
    if exist(input_excel, 'file') ~= 2
        disp(['Sablon létrehozása: ', input_excel]);
        init_raw = {
            'Upper Fore Chassis',  148.07,  224,    360;
            'Upper Aft Chassis',  -151.596, 224,    325;
            'Upper Upright',       -15,     555,    275;
            'Lower Fore Chassis',  160,     226,    156;
            'Lower Aft Chassis',  -122.598, 226,    186.806;
            'Lower Upright',         0,     586.76, 105;
            'Tie Rod Rack',         65,     244,    164;
            'Tie Rod Upright',      76,     564,    150;
            'Wheel Center',          0,     600,    193
        };
        T_def = cell2table(init_raw, 'VariableNames', {'Name','X','Y','Z'});
        writetable(T_def, input_excel);
    end

    disp(['Pontok betöltése: ', input_excel]);
    T_in = readtable(input_excel);

    names_C = {'Upper Fore Chassis','Upper Aft Chassis','Lower Fore Chassis','Lower Aft Chassis','Tie Rod Rack'};
    names_K = {'Upper Upright','Lower Upright','Tie Rod Upright'};

    C_init = zeros(5,3);
    K_init = zeros(3,3);
    for i = 1:5
        idx = find(strcmpi(T_in.Name, names_C{i}), 1);
        if isempty(idx), error('Hiányzó pont: %s', names_C{i}); end
        C_init(i,:) = [T_in.X(idx), T_in.Y(idx), T_in.Z(idx)];
    end
    for i = 1:3
        idx = find(strcmpi(T_in.Name, names_K{i}), 1);
        if isempty(idx), error('Hiányzó pont: %s', names_K{i}); end
        K_init(i,:) = [T_in.X(idx), T_in.Y(idx), T_in.Z(idx)];
    end
    idx_wc = find(strcmpi(T_in.Name, 'Wheel Center'), 1);
    if isempty(idx_wc) || ~F1.Enable
        WC_init = [0, 600, 193];                                        % eredeti (FS) viselkedés
    else
        WC_init = [T_in.X(idx_wc), T_in.Y(idx_wc), T_in.Z(idx_wc)];    % F1: kerékközép az Excelből (Ø705 gumi)
    end
    f1_check_wheel_static(WC_init, F1, F1.Axle);   % C10.1c, C10.10.1, gumiméret

    %% 3. BOUNDARY-k
    % dev_C1 = [-100 60; 0 0; -70 100];
    % dev_C2 = [-100 100; 0 0; -100 100];
    % dev_C3 = [-50 100; 0 0; -25 50];
    % dev_C4 = [-100 60; 0 0; -70 100];
    % dev_C5 = [0 0;   0  0;   0  0];
    % 
    % dev_K1 = [-40 40; -40 40; -40 40];
    % dev_K2 = [-40 40; -40 40; -40 40];
    % dev_K3 = [-40 40; -40 40; -40 40];

    dev_C1 = [-40 40; 0 0; -40 40];
    dev_C2 = [-40 40; 0 0; -40 40];
    dev_C3 = [-40 40; 0 0; -40 40];
    dev_C4 = [-40 40; 0 0; -40 40];
    dev_C5 = [-40 40; 0 0; -40 40];

    dev_K1 = [-60 60; -60 60; -60 60];
    dev_K2 = [-60 60; -60 60; -60 60];
    dev_K3 = [-60 60; -60 60; -60 60];

    dev_C_min = [dev_C1(:,1)'; dev_C2(:,1)'; dev_C3(:,1)'; dev_C4(:,1)'; dev_C5(:,1)'];
    dev_C_max = [dev_C1(:,2)'; dev_C2(:,2)'; dev_C3(:,2)'; dev_C4(:,2)'; dev_C5(:,2)'];
    dev_K_min = [dev_K1(:,1)'; dev_K2(:,1)'; dev_K3(:,1)'];
    dev_K_max = [dev_K1(:,2)'; dev_K2(:,2)'; dev_K3(:,2)'];

    lb = [C_init(:) + dev_C_min(:); K_init(:) + dev_K_min(:)];
    ub = [C_init(:) + dev_C_max(:); K_init(:) + dev_K_max(:)];
    x0 = [C_init(:); K_init(:)];

    %% 4. OPTIMALIZÁLÁS
    disp('Optimalizálás indítása (24 paraméter: 5C + 3K)...');
    options = optimoptions('fmincon', 'Display', 'iter-detailed', ...
        'Algorithm', 'interior-point', 'MaxFunctionEvaluations', 5000, ...
        'StepTolerance', 1e-10, 'OptimalityTolerance', 1e-4, ...
        'FiniteDifferenceStepSize', 1e-5, ...   % a belső fsolve/lsqnonlin zaja miatt nagyobb differenciálási lépés
        'OutputFcn', @stop_optimization_callback);

    obj_fun = @(x) calc_total_cost_DAA(x, WC_init, Target, W, Vehicle, Collision);
    nonlcon_fun = @(x) total_nonlcon_DAA(x, WC_init, Collision, F1);   % ütközés + F1 2026 kényszerek

    [~, ~, f1n, f1v] = f1_nonlcon_DAA(x0, WC_init, F1, Collision);
    f1_report(f1n, f1v, 'kiindulási geometria');

    tic;
    [x_opt, fval] = fmincon(obj_fun, x0, [], [], [], [], lb, ub, nonlcon_fun, options);
    toc;

    %% 5. EREDMÉNYEK
    C_opt = reshape(x_opt(1:15), [5,3]);
    K_opt = reshape(x_opt(16:24), [3,3]);

    disp('========================================================');
    disp(' OPTIMALIZÁCIÓ BEFEJEZŐDÖTT!');
    disp('========================================================');
    fprintf('Végső cost: %.4f\n', fval);
    [~, ~, f1n, f1v] = f1_nonlcon_DAA(x_opt, WC_init, F1, Collision);
    f1_report(f1n, f1v, 'optimalizált geometria');

    base_out = 'Optim_DAA_Front';
    if exist([base_out, '.xlsx'], 'file') ~= 2
        out_file = [base_out, '.xlsx'];
    else
        file_idx = 1;
        while exist(sprintf('%s_%d.xlsx', base_out, file_idx), 'file') == 2
            file_idx = file_idx + 1;
        end
        out_file = sprintf('%s_%d.xlsx', base_out, file_idx);
    end

    out_names = [names_C, names_K, {'Wheel Center'}];
    out_pts = [C_opt; K_opt; WC_init];
    out_cell2 = cell(9,4);
    for i = 1:9
        out_cell2{i,1} = out_names{i};
        out_cell2{i,2} = out_pts(i,1);
        out_cell2{i,3} = out_pts(i,2);
        out_cell2{i,4} = out_pts(i,3);
    end
    writetable(cell2table(out_cell2, 'VariableNames', {'Name','X','Y','Z'}), out_file);
    fprintf('Mentve: %s\n', out_file);

    %% 6. SWEEP + PLOTTER
    disp('Szimuláció a plotoláshoz...');
    dz_vec = -30:0.5:30;
    dy_vec = -30:0.5:30;
    droll_vec = -2:0.1:2;

    res_init = run_kinematics_sweep_DAA(C_init, K_init, WC_init, dz_vec, dy_vec, droll_vec, Vehicle, Collision);
    res_opt  = run_kinematics_sweep_DAA(C_opt,  K_opt,  WC_init, dz_vec, dy_vec, droll_vec, Vehicle, Collision);

    launchInteractivePlotterGUI(dz_vec, dy_vec, droll_vec, Target, res_init, res_opt);
end

%% ========================================================================
%  COST FUNCTION (DAA) + ütközésbüntetés + Anti-Dive
%  ========================================================================
function cost = calc_total_cost_DAA(x, WC_init, Target, W, Vehicle, Collision)
    C = reshape(x(1:15), [5,3]);
    K = reshape(x(16:24), [3,3]);
    cost = 0;

    opt_fs = optimoptions('fsolve', 'Display', 'off', 'MaxIterations', 200, ...
        'FunctionTolerance', 1e-12, 'Algorithm', 'levenberg-marquardt');

    heave_steps = -30:2:30;
    for dz = heave_steps
        % JAVÍTÁS: anti_dive átvétele
        [ok, camber, toe, ~, ~, ~, ~, rc_z, anti_dive, pts] = eval_DAA_state(C, K, WC_init, dz, 0, 0, opt_fs, Vehicle);
        if ~ok, cost = cost + 1e6; continue; end
        cost = cost + W.Camber   * (camber - interp1(Target.dz, Target.Camber, dz, 'pchip', 'extrap'))^2;
        cost = cost + W.Toe      * (toe    - interp1(Target.dz, Target.Toe,    dz, 'pchip', 'extrap'))^2;
        cost = cost + W.RC_Z     * (rc_z   - interp1(Target.dz, Target.RC_Z,   dz, 'pchip', 'extrap'))^2;
        cost = cost + W.AntiDive * (anti_dive - interp1(Target.dz, Target.AntiDive, dz, 'pchip', 'extrap'))^2;
    end

    steer_steps = -30:2:30;
    use_ack = W.Ackermann > 0;     % jobb oldali szimuláció csak az Ackermann-hoz kell
    for dy = steer_steps
        [okL, camberL, toeL, kpi, caster, trail, scrub] = eval_DAA_state(C, K, WC_init, 0, dy, 0, opt_fs, Vehicle);
        okR = true; toeR = 0;
        if use_ack
            C_R = C; C_R(:,2) = -C(:,2);
            K_R = K; K_R(:,2) = -K(:,2);
            WC_R = WC_init; WC_R(2) = -WC_init(2);
            [okR, ~, toeR] = eval_DAA_state(C_R, K_R, WC_R, 0, dy, 0, opt_fs, Vehicle);
        end
        if ~okL || ~okR, cost = cost + 1e6; continue; end

        % Camber / Toe a kormánymű elmozdulás függvényében (bal kerék)
        if W.Camber_Steer > 0
            cost = cost + W.Camber_Steer * (camberL - interp1(Target.dy, Target.Camber_Steer, dy, 'pchip', 'extrap'))^2;
        end
        if W.Toe_Steer > 0
            cost = cost + W.Toe_Steer * (toeL - interp1(Target.dy, Target.Toe_Steer, dy, 'pchip', 'extrap'))^2;
        end

        if W.KPI > 0
            cost = cost + W.KPI    * (kpi    - interp1(Target.dy, Target.KPI,    dy, 'pchip', 'extrap'))^2;
        end
        if W.Caster > 0
            cost = cost + W.Caster * (caster - interp1(Target.dy, Target.Caster, dy, 'pchip', 'extrap'))^2;
        end
        if W.Trail > 0
            cost = cost + W.Trail  * (trail  - interp1(Target.dy, Target.Trail,  dy, 'pchip', 'extrap'))^2;
        end
        if W.Scrub > 0
            cost = cost + W.Scrub  * (scrub  - interp1(Target.dy, Target.Scrub,  dy, 'pchip', 'extrap'))^2;
        end

        if use_ack && abs(dy) > 1e-4
            dL = abs(toeL); dR = abs(toeR);
            if dL > dR, din = dL; dout = dR; else, din = dR; dout = dL; end
            if abs(dout) > 1e-6
                ideal = rad2deg(atan(Vehicle.Wheelbase / (Vehicle.Wheelbase/tan(deg2rad(dout)) - Vehicle.Trackwidth)));
                ack = (din / ideal) * 100;
            else
                ack = 100;
            end
            cost = cost + W.Ackermann * (ack - interp1(Target.dy, Target.Ackermann, dy, 'pchip', 'extrap'))^2;
        end
    end

    roll_steps = -2:0.2:2;
    for droll = roll_steps
        [ok, camber, toe] = eval_DAA_state(C, K, WC_init, 0, 0, droll, opt_fs, Vehicle);
        if ~ok, cost = cost + 1e6; continue; end
        cost = cost + W.Camber_Roll * (camber - interp1(Target.droll, Target.Camber_Roll, droll, 'pchip', 'extrap'))^2;
        cost = cost + W.Toe_Roll    * (toe    - interp1(Target.droll, Target.Toe_Roll,    droll, 'pchip', 'extrap'))^2;
    end
end

%% ========================================================================
%  DAA ÁLLAPOT
%  ========================================================================
function [ok, camber, toe, kpi, caster, trail, scrub, rc_z, anti_dive, pts_out] = ...
    eval_DAA_state(C, K, WC_init, dz, dy, roll_deg, opts, Vehicle)
    
    ok = false;
    camber = 0; toe = 0; kpi = 0; caster = 0; trail = 0; scrub = 0; rc_z = 0; anti_dive = 0;
    pts_out = struct();

    p1 = C(1,:); p2 = C(2,:); p3 = K(1,:);
    p4 = C(3,:); p5 = C(4,:); p6 = K(2,:);
    p7 = C(5,:); p8 = K(3,:);
    p15 = WC_init(:)';

    L13  = norm(p1 - p3);  L23  = norm(p2 - p3);
    L46  = norm(p4 - p6);  L56  = norm(p5 - p6);
    L36  = norm(p3 - p6);  L86  = norm(p8 - p6);  L83 = norm(p8 - p3);
    L78  = norm(p7 - p8);
    L315 = norm(p3 - p15); L615 = norm(p6 - p15); L815 = norm(p8 - p15);

    pivot_z = 0;
    if abs(roll_deg) > 1e-9
        % Rekurzív hívás roll=0-val → pure heave állapot RC-je
        [ok_ph, ~, ~, ~, ~, ~, ~, rc_ph] = eval_DAA_state(C, K, WC_init, dz, 0, 0, opts, Vehicle);
        if ok_ph
            pivot_z = rc_ph;
        else
            pivot_z = 50;   % fallback
        end
    end

    r = deg2rad(roll_deg);
    Rroll = [1 0 0; 0 cos(r) -sin(r); 0 sin(r) cos(r)];
    pivot = [0; 0; pivot_z];

    move_ch = @(p) (Rroll * ([p(1); p(2); p(3) - dz] - pivot) + pivot)';
    c1 = move_ch(p1); c2 = move_ch(p2);
    c4 = move_ch(p4); c5 = move_ch(p5);
    c7 = move_ch(p7);
    c7(2) = c7(2) + dy;

    z15_static = p15(3);
    x7_static = p7(1);
    c7z_target = c7(3);

    x0 = zeros(1,12);
    for ii = 1:3
        q = [p3; p6; p8]; q = q(ii,:);
        q = move_ch(q);
        x0((ii-1)*3+1:(ii-1)*3+3) = q;
    end
    q15 = move_ch(p15);
    q15(3) = z15_static;
    x0(10:12) = q15;

    residual = @(x) daa_residuals(x, c1, c2, c4, c5, c7, ...
        L13, L23, L46, L56, L36, L86, L83, L78, L315, L615, L815, ...
        z15_static, x7_static, c7z_target);

    try
        [xsol, ~, exitflag] = fsolve(residual, x0, opts);
        if exitflag <= 0 && norm(residual(xsol)) > 1e-3
            return;
        end
    catch
        return;
    end

    u_up = xsol(1:3);
    u_lo = xsol(4:6);
    u_tr = xsol(7:9);
    wc   = xsol(10:12);

    A = [p6; p3; p8];
    muA = mean(A, 1);
    A0 = A - muA;
    B = [u_lo; u_up; u_tr];
    muB = mean(B, 1);
    B0 = B - muB;
    H = A0' * B0;
    [U, ~, V] = svd(H);
    Rmat = V * U';
    if det(Rmat) < 0
        V(:,3) = -V(:,3);
        Rmat = V * U';
    end

    wr = abs(WC_init(3));
    pos_top_s    = p15 + [0 0 wr];
    pos_bottom_s = p15 + [0 0 -wr];
    pos_front_s  = p15 + [wr 0 0];
    pos_rear_s   = p15 + [-wr 0 0];

    pos_top_c    = (Rmat * (pos_top_s'    - muA'))' + muB;
    pos_bottom_c = (Rmat * (pos_bottom_s' - muA'))' + muB;
    pos_front_c  = (Rmat * (pos_front_s'  - muA'))' + muB;
    pos_rear_c   = (Rmat * (pos_rear_s'   - muA'))' + muB;

    horiz_vec = pos_front_c - pos_rear_c;
    horiz_vec(3) = 0;
    if norm(horiz_vec) < 1e-6
        heading_unit = [1 0 0];
    else
        heading_unit = horiz_vec / norm(horiz_vec);
    end
    transverse_unit = [-heading_unit(2), heading_unit(1), 0];
    vert_vec = pos_top_c - pos_bottom_c;
    tilt_lateral  = dot(vert_vec, transverse_unit);
    tilt_vertical = dot(vert_vec, [0 0 1]);
    camber = rad2deg(atan2(tilt_lateral, tilt_vertical));

    initial_normal = [0; 1; 0];
    current_normal = Rmat * initial_normal;
    unit_normal = current_normal / norm(current_normal);
    if abs(unit_normal(2)) > 1e-6
        toe = -rad2deg(atan(unit_normal(1) / unit_normal(2)));
    else
        toe = 90 * sign(unit_normal(1));
    end
    if WC_init(2) < 0, toe = -toe; end

    gravity_dir = [0; 0; -1];
    proj_grav = gravity_dir - dot(gravity_dir, unit_normal) * unit_normal;
    if norm(proj_grav) > 1e-6
        down_dir = proj_grav / norm(proj_grav);
    else
        down_dir = [0; 0; -1];
    end
    t_gnd = (0 - wc(3)) / down_dir(3);
    cp = (wc(:) + t_gnd * down_dir)';

    kingpin_vec = u_up - u_lo;
    kingpin_vec = kingpin_vec / norm(kingpin_vec);

    if abs(kingpin_vec(3)) > 1e-8
        t_ground = -u_up(3) / kingpin_vec(3);
        kingpin_ground = u_up + t_ground * kingpin_vec;
        kg_x = kingpin_ground(1);
        kg_y = kingpin_ground(2);
    else
        kg_x = wc(1);
        kg_y = wc(2);
    end

    kpi_projection = [kingpin_vec(2); kingpin_vec(3)];
    kpi_projection = kpi_projection / norm(kpi_projection);
    kpi = -rad2deg(atan2(kpi_projection(1), abs(kpi_projection(2))));
    if WC_init(2) < 0, kpi = -kpi; end

    caster_projection = [kingpin_vec(1); kingpin_vec(3)];
    caster_projection = caster_projection / norm(caster_projection);
    caster = -rad2deg(atan2(caster_projection(1), caster_projection(2)));

    scrub = cp(2) - kg_y;
    if WC_init(2) < 0, scrub = -scrub; end
    trail = kg_x - cp(1);

    % JAVÍTÁS: RC Z és Anti-Dive számítása egy függvényben
    [rc_z, anti_dive] = compute_kinematic_centers(C, K, WC_init, dz, opts, ...
        L13, L23, L46, L56, L36, L86, L83, L78, L315, L615, L815, ...
        z15_static, p7(1), unit_normal, wr, muA, A0, Rmat, muB, cp, Vehicle);

    pts_out.c1 = c1; pts_out.c2 = c2; pts_out.c4 = c4; pts_out.c5 = c5; pts_out.c7 = c7;
    pts_out.u_up = u_up; pts_out.u_lo = u_lo; pts_out.u_tr = u_tr; pts_out.wc = wc;
    pts_out.is_left = (WC_init(2) >= 0);

    ok = true;
end

% JAVÍTÁS: kibővítettük a függvényt hogy az anti_dive paramétert is visszavezesse (RC_Z mellett)
function [rc_z, anti_dive] = compute_kinematic_centers(C, K, WC_init, dz, opts, ...
        L13, L23, L46, L56, L36, L86, L83, L78, L315, L615, L815, ...
        z15_static, x7_static, unit_normal_c, wr, muA, A0, Rmat_c, muB_c, cp_c, Vehicle)
    
    rc_z = cp_c(3);
    anti_dive = 0;
    try
        pts = cell(1, 3);
        for si = 1:3
            ddz = dz + (si - 2);
            p1 = C(1,:); p2 = C(2,:); p3 = K(1,:);
            p4 = C(3,:); p5 = C(4,:); p6 = K(2,:);
            p7 = C(5,:); p8 = K(3,:); p15 = WC_init(:)';

            c1 = [p1(1), p1(2), p1(3)-ddz];
            c2 = [p2(1), p2(2), p2(3)-ddz];
            c4 = [p4(1), p4(2), p4(3)-ddz];
            c5 = [p5(1), p5(2), p5(3)-ddz];
            c7 = [p7(1), p7(2), p7(3)-ddz];

            x0 = [p3(1), p3(2), p3(3)-ddz, ...
                  p6(1), p6(2), p6(3)-ddz, ...
                  p8(1), p8(2), p8(3)-ddz, ...
                  p15(1), p15(2), z15_static];

            resf = @(x) daa_residuals(x, c1, c2, c4, c5, c7, ...
                L13, L23, L46, L56, L36, L86, L83, L78, L315, L615, L815, ...
                z15_static, x7_static, c7(3));
            [xsol, ~, ef] = fsolve(resf, x0, opts);
            if ef <= 0, return; end
            pts{si} = struct('u', xsol(1:3), 'lo', xsol(4:6), 'tr', xsol(7:9), 'wc', xsol(10:12));
        end

        Bm = [pts{1}.lo; pts{1}.u; pts{1}.tr];
        muBm = mean(Bm,1); B0m = Bm - muBm;
        Hm = A0' * B0m;
        [Um,~,Vm] = svd(Hm);
        Rm = Vm*Um'; if det(Rm)<0, Vm(:,3)=-Vm(:,3); Rm=Vm*Um'; end

        Bp = [pts{3}.lo; pts{3}.u; pts{3}.tr];
        muBp = mean(Bp,1); B0p = Bp - muBp;
        Hp = A0' * B0p;
        [Up,~,Vp] = svd(Hp);
        Rp = Vp*Up'; if det(Rp)<0, Vp(:,3)=-Vp(:,3); Rp=Vp*Up'; end

        R_delta = Rp * Rm';
        w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
        w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
        w_z = (R_delta(2,1) - R_delta(1,2)) / 2;

        p15_m = pts{1}.wc + [0, 0, dz - 1];
        p15_p = pts{3}.wc + [0, 0, dz + 1];
        p15_c = pts{2}.wc + [0, 0, dz];
        v_15 = p15_p - p15_m;

        cp_x = cp_c(1); cp_y = cp_c(2); cp_z = cp_c(3);

        % Front IC (RC_Z-hez)
        if abs(w_x) > 1e-10
            y_ic = p15_c(2) + (-v_15(3) + w_y * (cp_x - p15_c(1))) / w_x;
            z_ic = p15_c(3) + ( v_15(2) + w_z * (cp_x - p15_c(1))) / w_x;
            fic = [cp_x, y_ic, z_ic] - [0, 0, dz];
            if abs(fic(2) - cp_y) > 1e-6
                m = (fic(3) - cp_z) / (fic(2) - cp_y);
                rc_z = cp_z - m * cp_y;
            end
        end

        % JAVÍTÁS: Side IC alapján Anti-Dive érték kiszámítása
        if abs(w_y) > 1e-10
            x_ic = p15_c(1) + ( v_15(3) + w_x * (cp_y - p15_c(2))) / w_y;
            z_ic_s = p15_c(3) + (-v_15(1) + w_z * (cp_y - p15_c(2))) / w_y;
            sic = [x_ic, cp_y, z_ic_s] - [0, 0, dz];
            
            dx_side = sic(1) - cp_x;
            dz_side = sic(3) - cp_z;
            
            if abs(dx_side) > 1.0 && norm(sic) < 1e5
                tan_Phi_F = dz_side / (-dx_side);
                
                h_CG_SM_current = Vehicle.h_CG_SM_static - dz;
                if h_CG_SM_current > 1.0
                    anti_dive = (Vehicle.Wheelbase * tan_Phi_F * (Vehicle.FrontBrakeBias / 100) / h_CG_SM_current) * 100;
                end
            end
        end

    catch
    end
end

function res = daa_residuals(x, c1, c2, c4, c5, c7, ...
        L13, L23, L46, L56, L36, L86, L83, L78, L315, L615, L815, ...
        z15_static, x7_static, c7z_target)
    u  = x(1:3); lo = x(4:6); tr = x(7:9); wc = x(10:12);
    res = zeros(12, 1);
    res(1)  = norm(c1 - u)  - L13;
    res(2)  = norm(c2 - u)  - L23;
    res(3)  = norm(c4 - lo) - L46;
    res(4)  = norm(c5 - lo) - L56;
    res(5)  = norm(u - lo)  - L36;
    res(6)  = norm(tr - lo) - L86;
    res(7)  = norm(tr - u)  - L83;
    res(8)  = norm(c7 - tr) - L78;
    res(9)  = norm(u - wc)  - L315;
    res(10) = norm(lo - wc) - L615;
    res(11) = norm(tr - wc) - L815;
    res(12) = wc(3) - z15_static;
end

function res = run_kinematics_sweep_DAA(C, K, WC_init, dz_vec, dy_vec, droll_vec, Vehicle, Collision)
    opts = optimoptions('fsolve', 'Display', 'off', 'MaxIterations', 200, ...
        'FunctionTolerance', 1e-12, 'Algorithm', 'levenberg-marquardt');

    res.Camber = nan(size(dz_vec)); res.Toe = nan(size(dz_vec)); 
    res.RC_Z = nan(size(dz_vec)); res.AntiDive = nan(size(dz_vec));
    for k = 1:length(dz_vec)
        [ok, camber, toe, ~, ~, ~, ~, rc_z, anti_dive] = eval_DAA_state(C, K, WC_init, dz_vec(k), 0, 0, opts, Vehicle);
        if ok
            res.Camber(k) = camber; res.Toe(k) = toe; res.RC_Z(k) = rc_z; res.AntiDive(k) = anti_dive;
        end
    end

    res.KPI = nan(size(dy_vec)); res.Caster = nan(size(dy_vec));
    res.Trail = nan(size(dy_vec)); res.Scrub = nan(size(dy_vec));
    res.Ackermann = nan(size(dy_vec));
    res.Camber_steer = nan(size(dy_vec)); res.Toe_steer = nan(size(dy_vec));

    C_R = C; C_R(:,2) = -C(:,2);
    K_R = K; K_R(:,2) = -K(:,2);
    WC_R = WC_init; WC_R(2) = -WC_init(2);

    for k = 1:length(dy_vec)
        dy = dy_vec(k);
        [okL, camberL, toeL, kpi, caster, trail, scrub] = eval_DAA_state(C, K, WC_init, 0, dy, 0, opts, Vehicle);
        [okR, ~, toeR] = eval_DAA_state(C_R, K_R, WC_R, 0, dy, 0, opts, Vehicle);
        if okL
            res.KPI(k) = kpi; res.Caster(k) = caster;
            res.Camber_steer(k) = camberL; res.Toe_steer(k) = toeL;
            res.Trail(k) = trail; res.Scrub(k) = scrub;
        end
        if okL && okR
            if abs(dy) < 1e-4
                res.Ackermann(k) = 100;
            else
                dL = abs(toeL); dR = abs(toeR);
                if dL > dR, din = dL; dout = dR; else, din = dR; dout = dL; end
                if abs(dout) > 1e-6
                    ideal = rad2deg(atan(Vehicle.Wheelbase / (Vehicle.Wheelbase/tan(deg2rad(dout)) - Vehicle.Trackwidth)));
                    res.Ackermann(k) = (din / ideal) * 100;
                else
                    res.Ackermann(k) = 100;
                end
            end
        end
    end

    res.Camber_roll = nan(size(droll_vec));
    res.Toe_roll = nan(size(droll_vec));
    for k = 1:length(droll_vec)
        [ok, camber, toe] = eval_DAA_state(C, K, WC_init, 0, 0, droll_vec(k), opts, Vehicle);
        if ok
            res.Camber_roll(k) = camber; res.Toe_roll(k) = toe;
        end
    end
end

%% ========================================================================
%  SEGÉDFÜGGVÉNYEK ÉS ÜTKÖZÉS NONLCON
%  ========================================================================

function err = calc_link_errors(q, C, K_loc, WC_init, ~, L0)
    WC_curr = [q(1), q(2), WC_init(3)];
    R_mat = euler_to_rot(q(3), q(4), q(5));
    err = zeros(5, 1);
    for i = 1:5
        K_curr_i = (WC_curr' + R_mat * K_loc(i,:)')';
        err(i) = norm(K_curr_i - C(i,:)) - L0(i);
    end
end

function R = euler_to_rot(rx, ry, rz)
    Rx = [1, 0, 0; 0, cos(rx), -sin(rx); 0, sin(rx), cos(rx)];
    Ry = [cos(ry), 0, sin(ry); 0, 1, 0; -sin(ry), 0, cos(ry)];
    Rz = [cos(rz), -sin(rz), 0; sin(rz), cos(rz), 0; 0, 0, 1];
    R = Rz * Ry * Rx;
end

function [c, ceq] = collision_nonlcon(x, WC_init, Collision)
    % JAVÍTÁS: a kényszervektor hossza MINDIG ugyanannyi (pózonként 18 sor),
    % és csak akkor fogadjuk el a pózt, ha a láncösszeállítás tényleg zárt
    % (maradék ~0). Különben fmincon-nak inkonzisztens a kényszer-Jacobi.
    ceq = [];
    C_curr = reshape(x(1:15), [5, 3]);
    K_base = reshape(x(16:24), [3, 3]); 
    K_curr = [K_base(1, :); K_base(1, :); K_base(2, :); K_base(2, :); K_base(3, :)];
    
    L0 = zeros(5,1);
    for i = 1:5, L0(i) = norm(K_curr(i,:) - C_curr(i,:)); end
    K_loc = K_curr - WC_init;

    opt_inner = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-10, ...
        'StepTolerance', 1e-12, 'MaxIterations', 400);

    % --- Kritikus pózok: MINDEN heave (dz) x kormányzás (dy) kombináció ---
    dz_list = [0, -30, 30];   % dz=0 elöl: ebből indul a +-30 (folytonos megoldás)
    dy_list = [-30, 0, 30];
    q0_default = [WC_init(1), WC_init(2), 0, 0, 0];

    n_rows_pose = 18;         % 8 rúd-rúd + 5 rúd-motor + 5 rúd-felni
    c = zeros(numel(dy_list) * numel(dz_list) * n_rows_pose, 1);
    row = 0;

    for dy = dy_list
        q_ref = q0_default;   % az adott kormányzási állás dz=0 megoldása
        for dz = dz_list
            C_pose = C_curr;
            C_pose(:, 3) = C_curr(:, 3) - dz;       % heave
            C_pose(5, 2) = C_curr(5, 2) + dy;       % kormányzás (rack Y)
            obj_inner = @(q) calc_link_errors(q, C_pose, K_loc, WC_init, 0, L0);

            [q_opt, resn, ~, exitflag] = lsqnonlin(obj_inner, q_ref, [], [], opt_inner);
            solved = (exitflag > 0) && (resn < 1e-8);
            if ~solved && ~isequal(q_ref, q0_default)
                % tartalék: indulás az alap pózból
                [q_opt, resn, ~, exitflag] = lsqnonlin(obj_inner, q0_default, [], [], opt_inner);
                solved = (exitflag > 0) && (resn < 1e-8);
            end

            if solved
                if dz == 0, q_ref = q_opt; end
                R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
                WC_h = [q_opt(1), q_opt(2), WC_init(3)];
                K_h = zeros(5,3);
                for ii = 1:5, K_h(ii,:) = (WC_h' + R_mat * K_loc(ii,:)')'; end
                unit_normal = R_mat * Collision.wheel_axis0(:);   % F1: legality camber
                unit_normal = unit_normal / (norm(unit_normal) + 1e-15);
                c_pose = get_collision_distances(C_pose, K_h, WC_h, unit_normal, Collision);
            else
                c_pose = 50 * ones(n_rows_pose, 1);   % nem összeszerelhető póz -> nagy büntetés
            end
            c(row+1 : row+n_rows_pose) = c_pose(:);
            row = row + n_rows_pose;
        end
    end
end

function c_vals = get_collision_distances(C, K, WC, unit_normal, Col)
    c_vals = [];
    n = 5;
    radii = [Col.rod_diameter_upper; Col.rod_diameter_upper; Col.rod_diameter_lower; Col.rod_diameter_lower; Col.rod_diameter_tie] / 2;
    if length(radii) < n, radii = [radii; repmat(radii(end), n - length(radii), 1)]; end
    gap = Col.min_clearance;

    ignore_pairs = [1, 2; 3, 4];  
    for i = 1:n
        for j = i+1:n
            is_a_arm = false;
            for k = 1:size(ignore_pairs, 1)
                if (i == ignore_pairs(k,1) && j == ignore_pairs(k,2)) || (j == ignore_pairs(k,1) && i == ignore_pairs(k,2))
                    is_a_arm = true; break;
                end
            end
            if is_a_arm, continue; end
            d = segment_segment_distance(C(i,:), K(i,:), C(j,:), K(j,:));
            need = radii(i) + radii(j) + gap;
            c_vals(end+1, 1) = need - d;
        end
    end

    % mc = Col.motor_center(:); m_axis = Col.motor_axis(:);
    % for i = 1:n
    %     d = segment_finite_cylinder_distance(C(i,:), K(i,:), mc, m_axis, Col.motor_radius, Col.motor_length);
    %     need = radii(i) + gap;
    %     c_vals(end+1, 1) = need - d;
    % end

    % Az agymotor tengelye megegyezik a felni (kerék) aktuális forgástengelyével
    m_axis = unit_normal(:) / (norm(unit_normal) + 1e-15);

    % A motor középpontja a kerékközéppontból (WC) van eltolva a tengely mentén
    mc = WC(:) + Col.motor_y_offset * m_axis;

    for i = 1:n
        if isfield(Col, 'use_motor') && ~Col.use_motor
            c_vals(end+1, 1) = -100; continue;   % F1: nincs agymotor (fix méretű, biztonságos sor)
        end
        d = segment_finite_cylinder_distance(C(i,:), K(i,:), mc, m_axis, Col.motor_radius, Col.motor_length);
        need = radii(i) + gap;
        c_vals(end+1, 1) = need - d;
    end

    wc = WC(:);
    rim_axis = unit_normal(:) / (norm(unit_normal) + 1e-15);
    rim_center = wc + Col.rim_y_offset * rim_axis;
    r_inner = Col.rim_inner_radius; r_outer = Col.rim_outer_radius; half_w  = Col.rim_width / 2;
    for i = 1:n
        d = segment_rim_annulus_distance(C(i,:), K(i,:), rim_center, rim_axis, r_inner, r_outer, half_w);
        need = radii(i) + gap;
        c_vals(end+1, 1) = need - d;
    end
end

function d = segment_segment_distance(p1, q1, p2, q2)
    p1 = p1(:); q1 = q1(:); p2 = p2(:); q2 = q2(:);
    u = q1 - p1; v = q2 - p2; w0 = p1 - p2;
    a = dot(u,u); b = dot(u,v); c = dot(v,v);
    d_ = dot(u,w0); e = dot(v,w0);
    D = a*c - b*b;
    if D < 1e-12, sc = 0; tc = 0; if c > 1e-12, tc = e/c; end
    else, sc = (b*e - c*d_) / D; tc = (a*e - b*d_) / D; end
    sc = min(1, max(0, sc)); tc = min(1, max(0, tc));
    d = norm(w0 + sc*u - tc*v);
end

function s = box_sdf_2d(a, b)
    % Előjeles távolság egy (radiális, axiális) téglalaptól:
    % a, b = a téglalap széleitől mért előjeles távolság (negatív = belül).
    % Kívül: euklideszi távolság, belül: negatív behatolási mélység.
    s = norm([max(a, 0), max(b, 0)]) + min(max(a, b), 0);
end

function d = segment_finite_cylinder_distance(p0, p1, c_center, c_axis, radius, height)
    % JAVÍTÁS: előjeles távolság. A régi max(0, ...) levágás miatt a behatolás
    % mélysége nem látszott (c = need - 0 = állandó plató, nulla gradiens),
    % ezért akadt meg a feasibility pontosan a "rúdsugár + clearance" értéken.
    p0 = p0(:); p1 = p1(:); c_center = c_center(:); c_axis = c_axis(:);
    c_axis = c_axis / (norm(c_axis) + 1e-15);
    n = 60; d = inf; half_h = height / 2;
    for i = 0:n
        t = i/n; p = p0 + t*(p1-p0); w = p - c_center;
        axial = dot(w, c_axis); radial = norm(w - axial * c_axis);
        d = min(d, box_sdf_2d(radial - radius, abs(axial) - half_h));
    end
end

function d = segment_rim_annulus_distance(p0, p1, rim_center, rim_axis, r_inner, r_outer, half_w)
    % JAVÍTÁS: a felni vékony gyűrű (r_inner..r_outer, +-half_w) előjeles
    % távolsága. Nincs többé "d = 0" plató és nincs "1e6" ugrás sem, ha a
    % szakasz egyetlen mintapontja sem esik a felni axiális tartományába.
    p0 = p0(:); p1 = p1(:); rim_center = rim_center(:); rim_axis = rim_axis(:) / (norm(rim_axis) + 1e-15);
    n_samples = 60; d = inf;
    for k = 0:n_samples
        t = k / n_samples; pt = p0 + t * (p1 - p0); w = pt - rim_center;
        axial = dot(w, rim_axis); radial = norm(w - axial * rim_axis);
        dr = max(r_inner - radial, radial - r_outer);   % <0: a gyűrű falában van
        d = min(d, box_sdf_2d(dr, abs(axial) - half_w));
    end
end

%% ========================================================================
%  GUI ÉS PLOTTER
%  ========================================================================

function stop = stop_optimization_callback(~, ~, ~)
    stop = false;
    if exist('stop_opt.txt', 'file') == 2
        fprintf('\n>>> FELHASZNÁLÓI MEGSZAKÍTÁS: stop_opt.txt észlelve! <<<\n');
        try, delete('stop_opt.txt'); catch, end
        stop = true;
    end
end

function curve_out = pick_steer_curve(use_gui, loaded_data, row_idx, eval_pts, x_target, name, y_label)
    % use_gui = true  : GUI-ban bekéri a görbét (Excelből betöltött kezdőpontokkal)
    % use_gui = false : nem kéri be (a súly 0), az Excelben lévő értéket tartja meg,
    %                   így az Excel nem módosul és a cost sem használja.
    [x_init, y_init] = get_excel_pts(loaded_data, row_idx, eval_pts);
    if use_gui
        curve_out = defineTargetCurveGUI(name, -30, 30, 'Kormánymű (Y) [mm]', y_label, x_init, y_init);
    else
        disp(['Célgörbe kihagyva (súly = 0): ', name]);
        curve_out = interp1(x_init, y_init, x_target(:), 'pchip', 'extrap');
    end
    curve_out = curve_out(:);
end

function [x_out, y_out] = get_excel_pts(loaded_data, row_idx, eval_pts)
    x_out = eval_pts(:); y_out = zeros(length(eval_pts), 1);
    if ~isempty(loaded_data) && size(loaded_data,1) >= row_idx && size(loaded_data,2) >= 22
        for i = 1:length(eval_pts)
            val = loaded_data{row_idx, i+1};
            if isnumeric(val) && ~isnan(val), y_out(i) = val; end
        end
    end
end

function curve_out = defineTargetCurveGUI(name, x_min, x_max, x_label, y_label, init_x, init_y)
    if nargin >= 7 && ~isempty(init_x)
        x_pts = init_x(:); y_pts = init_y(:);
    else
        x_pts = [x_min; 0; x_max]; y_pts = [0; 0; 0];
    end

    fig = figure('Name', ['Célgörbe Szerkesztő: ', name], 'NumberTitle', 'off', 'Position', [200 150 1000 600], 'MenuBar', 'none', 'ToolBar', 'figure', 'DockControls', 'off');
    ax = axes('Parent', fig, 'Position', [0.08 0.12 0.58 0.8]);
    grid(ax, 'on'); hold(ax, 'on'); xlabel(ax, x_label); ylabel(ax, y_label);

    y_min_val = min(y_pts) - 2; y_max_val = max(y_pts) + 2;
    if y_min_val == y_max_val, y_min_val = y_min_val - 5; y_max_val = y_max_val + 5; end
    xlim(ax, [x_min, x_max]); ylim(ax, [y_min_val, y_max_val]);

    pnl = uipanel('Parent', fig, 'Title', 'Vezérlők & Pontok', 'Position', [0.69 0.05 0.29 0.9]);
    uicontrol(pnl, 'Style', 'text', 'String', 'Pontok listája (X, Y):', 'Position', [10 490 200 20], 'HorizontalAlignment', 'left');
    lst_points = uicontrol(pnl, 'Style', 'listbox', 'Position', [10 340 250 150]);

    uicontrol(pnl, 'Style', 'text', 'String', 'X:', 'Position', [10 305 20 20]);
    txt_x = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [30 305 55 22]);
    uicontrol(pnl, 'Style', 'text', 'String', 'Y:', 'Position', [90 305 20 20]);
    txt_y = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [110 305 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Hozzáad', 'Position', [170 305 90 22], 'Callback', @add_point_manual);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Kijelölt Pont Törlése', 'Position', [10 270 250 28], 'Callback', @delete_selected_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Utolsó Visszavonása (Undo)', 'Position', [10 235 250 28], 'Callback', @undo_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Minden Pont Törlése', 'Position', [10 200 250 28], 'Callback', @clear_points);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y min / Y max skála:', 'Position', [10 160 120 20], 'HorizontalAlignment', 'left');
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_min_val), 'Position', [10 135 55 22]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_max_val), 'Position', [70 135 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Skála Beállítása', 'Position', [135 135 125 22], 'Callback', @update_axes_limits);

    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Megtart / Ugrás (Skip)', 'Position', [10 80 250 35], 'BackgroundColor', [0.85 0.9 0.85], 'Callback', @skip_callback);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Mentés és Folytatás', 'Position', [10 30 250 40], 'BackgroundColor', [0.2 0.7 0.2], 'ForegroundColor', [1 1 1], 'FontWeight', 'bold', 'Callback', @save_callback);

    set(fig, 'WindowButtonDownFcn', @click_on_axes);
    update_plot_and_list();
    uiwait(fig);

    z_eval = linspace(x_min, x_max, 61)';
    if isempty(x_pts), x_sorted = [x_min; x_max]; y_sorted = [0; 0];
    else, [x_sorted, s_idx] = sort(x_pts); y_sorted = y_pts(s_idx); [x_sorted, u_idx] = unique(x_sorted); y_sorted = y_sorted(u_idx); end
    if length(x_sorted) < 2, x_sorted = [x_min; x_max]; y_sorted = [0; 0]; end
    curve_out = interp1(x_sorted, y_sorted, z_eval, 'pchip', 'extrap');

    if ishandle(fig), close(fig); end

    function click_on_axes(~, ~)
        cp = get(ax, 'CurrentPoint'); cx = cp(1,1); cy = cp(1,2);
        xl = xlim(ax); yl = ylim(ax);
        if cx >= xl(1) && cx <= xl(2) && cy >= yl(1) && cy <= yl(2), x_pts(end+1, 1) = cx; y_pts(end+1, 1) = cy; update_plot_and_list(); end
    end
    function add_point_manual(~, ~)
        nx = str2double(get(txt_x, 'String')); ny = str2double(get(txt_y, 'String'));
        if ~isnan(nx) && ~isnan(ny), x_pts(end+1, 1) = nx; y_pts(end+1, 1) = ny; update_plot_and_list(); end
    end
    function delete_selected_point(~, ~)
        if isempty(x_pts), return; end
        idx = get(lst_points, 'Value');
        if isempty(idx) || idx < 1 || idx > length(x_pts), return; end
        x_pts(idx) = []; y_pts(idx) = []; update_plot_and_list();
    end
    function undo_point(~, ~)
        if ~isempty(x_pts), x_pts(end) = []; y_pts(end) = []; update_plot_and_list(); end
    end
    function clear_points(~, ~)
        x_pts = []; y_pts = []; update_plot_and_list();
    end
    function update_axes_limits(~, ~)
        ymin_n = str2double(get(txt_ymin, 'String')); ymax_n = str2double(get(txt_ymax, 'String'));
        if ~isnan(ymin_n) && ~isnan(ymax_n) && ymax_n > ymin_n, ylim(ax, [ymin_n, ymax_n]); end
    end
    function skip_callback(~, ~), uiresume(fig); end
    function save_callback(~, ~), uiresume(fig); end

    function update_plot_and_list()
        cla(ax); grid(ax, 'on'); hold(ax, 'on');
        if length(x_pts) >= 2
            [xs, s_idx] = sort(x_pts); ys = y_pts(s_idx); [xs, u_idx] = unique(xs); ys = ys(u_idx);
            z_fit = linspace(x_min, x_max, 100); y_fit = interp1(xs, ys, z_fit, 'pchip', 'extrap');
            plot(ax, z_fit, y_fit, 'b-', 'LineWidth', 2);
        end
        if ~isempty(x_pts), plot(ax, x_pts, y_pts, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); end
        str_list = cell(length(x_pts), 1);
        for i = 1:length(x_pts), str_list{i} = sprintf('%d:  X = %.2f,  Y = %.2f', i, x_pts(i), y_pts(i)); end
        set(lst_points, 'String', str_list);
        if ~isempty(str_list)
            set(lst_points, 'Value', min(get(lst_points, 'Value'), length(str_list)));
            if get(lst_points, 'Value') < 1, set(lst_points, 'Value', length(str_list)); end
        end
    end
end

function launchInteractivePlotterGUI(dz_vec, dy_vec, droll_vec, Target, res_init, res_opt)
    fig = figure('Name', 'DAA Kinematikai Eredmények - Interaktív Plotter', 'NumberTitle', 'off', 'Position', [150 100 1100 650]);
    ax = axes('Parent', fig, 'Position', [0.08 0.12 0.62 0.8]); grid(ax, 'on'); hold(ax, 'on');
    pnl = uipanel('Parent', fig, 'Title', 'Plot Beállítások', 'Position', [0.73 0.05 0.25 0.9]);

    uicontrol(pnl, 'Style', 'text', 'String', 'X Tengely:', 'Position', [10 540 220 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    pop_x = uicontrol(pnl, 'Style', 'popupmenu', 'String', {'Wheel Travel (Z)', 'Steer Rack (Y)', 'Chassis Roll'}, 'Position', [10 515 220 25], 'Callback', @update_x_selection);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y Tengely:', 'Position', [10 460 220 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    pop_y = uicontrol(pnl, 'Style', 'popupmenu', 'String', {'Camber', 'Toe', 'Roll Center Z', 'Anti-Dive'}, 'Position', [10 435 220 25], 'Callback', @update_plot);

    uicontrol(pnl, 'Style', 'text', 'String', 'X Min / Max:', 'Position', [10 360 220 20]);
    txt_xmin = uicontrol(pnl, 'Style', 'edit', 'String', '-50', 'Position', [10 335 90 25]);
    txt_xmax = uicontrol(pnl, 'Style', 'edit', 'String', '50', 'Position', [110 335 90 25]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'X Skála', 'Position', [10 300 200 25], 'Callback', @apply_x_limits);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y Min / Max:', 'Position', [10 240 220 20]);
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', 'auto', 'Position', [10 215 90 25]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', 'auto', 'Position', [110 215 90 25]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Y Skála', 'Position', [10 180 200 25], 'Callback', @apply_y_limits);

    uicontrol(pnl, 'Style', 'checkbox', 'String', 'Kezdeti', 'Value', 1, 'Position', [10 120 100 25], 'Tag', 'chk_init', 'Callback', @update_plot);
    uicontrol(pnl, 'Style', 'checkbox', 'String', 'Optimált', 'Value', 1, 'Position', [120 120 100 25], 'Tag', 'chk_opt', 'Callback', @update_plot);
    uicontrol(pnl, 'Style', 'checkbox', 'String', 'Célgörbe', 'Value', 1, 'Position', [10 90 100 25], 'Tag', 'chk_tgt', 'Callback', @update_plot);

    update_x_selection();

    function update_x_selection(~, ~)
        xi = get(pop_x, 'Value');
        switch xi
            case 1, set(pop_y, 'String', {'Camber','Toe','Roll Center Z','Anti-Dive'}); set(txt_xmin,'String','-30'); set(txt_xmax,'String','30');
            case 2, set(pop_y, 'String', {'KPI','Caster','Trail','Scrub','Ackermann','Camber','Toe'}); set(txt_xmin,'String','-30'); set(txt_xmax,'String','30');
            case 3, set(pop_y, 'String', {'Camber','Toe'}); set(txt_xmin,'String','-2'); set(txt_xmax,'String','2');
        end
        set(pop_y, 'Value', 1);
        update_plot();
    end

    function apply_x_limits(~, ~)
        xl = [str2double(get(txt_xmin,'String')), str2double(get(txt_xmax,'String'))];
        if all(isfinite(xl)), xlim(ax, xl); end
    end
    function apply_y_limits(~, ~)
        ys1 = get(txt_ymin,'String'); ys2 = get(txt_ymax,'String');
        if strcmpi(ys1,'auto') || strcmpi(ys2,'auto'), ylim(ax, 'auto');
        else, yl = [str2double(ys1), str2double(ys2)]; if all(isfinite(yl)), ylim(ax, yl); end; end
    end

    function update_plot(~, ~)
        cla(ax); hold(ax, 'on'); grid(ax, 'on');
        xi = get(pop_x, 'Value'); yi = get(pop_y, 'Value');
        ynames = get(pop_y, 'String'); yname = ynames{yi};
        show_init = get(findobj(fig, 'Tag', 'chk_init'), 'Value');
        show_opt  = get(findobj(fig, 'Tag', 'chk_opt'), 'Value');
        show_tgt  = get(findobj(fig, 'Tag', 'chk_tgt'), 'Value');
        tgt_active = true;   % 0 súlyú (nem optimalizált) mennyiségnél nincs célgörbe

        switch xi
            case 1
                x = dz_vec; xlab = 'Wheel Travel Z [mm]';
                switch yname
                    case 'Camber', yi_i = res_init.Camber; yi_o = res_opt.Camber; yt = Target.Camber; xt = Target.dz;
                    case 'Toe',    yi_i = res_init.Toe;    yi_o = res_opt.Toe;    yt = Target.Toe;    xt = Target.dz;
                    case 'Roll Center Z', yi_i = res_init.RC_Z; yi_o = res_opt.RC_Z; yt = Target.RC_Z; xt = Target.dz;
                    case 'Anti-Dive', yi_i = res_init.AntiDive; yi_o = res_opt.AntiDive; yt = Target.AntiDive; xt = Target.dz;
                end
            case 2
                x = dy_vec; xlab = 'Steer Rack Y [mm]';
                switch yname
                    case 'KPI',       yi_i = res_init.KPI;       yi_o = res_opt.KPI;       yt = Target.KPI;       xt = Target.dy; tgt_active = Target.Use.KPI;
                    case 'Camber',    yi_i = res_init.Camber_steer; yi_o = res_opt.Camber_steer; yt = Target.Camber_Steer; xt = Target.dy; tgt_active = Target.Use.Camber_Steer;
                    case 'Toe',       yi_i = res_init.Toe_steer;    yi_o = res_opt.Toe_steer;    yt = Target.Toe_Steer;    xt = Target.dy; tgt_active = Target.Use.Toe_Steer;
                    case 'Caster',    yi_i = res_init.Caster;    yi_o = res_opt.Caster;    yt = Target.Caster;    xt = Target.dy; tgt_active = Target.Use.Caster;
                    case 'Trail',     yi_i = res_init.Trail;     yi_o = res_opt.Trail;     yt = Target.Trail;     xt = Target.dy; tgt_active = Target.Use.Trail;
                    case 'Scrub',     yi_i = res_init.Scrub;     yi_o = res_opt.Scrub;     yt = Target.Scrub;     xt = Target.dy; tgt_active = Target.Use.Scrub;
                    case 'Ackermann', yi_i = res_init.Ackermann; yi_o = res_opt.Ackermann; yt = Target.Ackermann; xt = Target.dy; tgt_active = Target.Use.Ackermann;
                end
            case 3
                x = droll_vec; xlab = 'Chassis Roll [deg]';
                switch yname
                    case 'Camber', yi_i = res_init.Camber_roll; yi_o = res_opt.Camber_roll; yt = Target.Camber_Roll; xt = Target.droll;
                    case 'Toe',    yi_i = res_init.Toe_roll;    yi_o = res_opt.Toe_roll;    yt = Target.Toe_Roll;    xt = Target.droll;
                end
        end

        if show_init, plot(ax, x, yi_i, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Kezdeti'); end
        if show_opt,  plot(ax, x, yi_o, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Optimált'); end
        if show_tgt && tgt_active,  plot(ax, xt, yt, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Célgörbe'); end
        xlabel(ax, xlab); ylabel(ax, yname); legend(ax, 'Location', 'best');
        apply_x_limits();
    end
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

%% ---------------- F1 KINEMATIKAI KÉNYSZEREK (DAA / multilink optimalizáló) ----------------
% A kinematikát a fájl saját calc_link_errors / euler_to_rot függvényei adják (5 tag + merev upright,
% WC Z rögzített), pontosan úgy, mint a collision_nonlcon-ban.

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
        obj = @(q) calc_link_errors(q, Ck, K_loc, WC_init, 0, L0);
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
    R   = euler_to_rot(q(3), q(4), q(5));
    WCk = [q(1), q(2), WC_init(3)];
    Kk  = (WCk(:) + R * K_loc')';
end

function inc = f1_member_incidences(C0, K0, C, K, hinge)
% C10.3.6c: a tagok keresztmetszet-főtengelyének dőlésváltozása [deg] a Legality Setuphoz képest.
% hinge(i,:) = [a b]: az i. tag az a-b vázpontokon átmenő csuklótengely körül fordul (A-kar szára);
% hinge(i,:) = [0 0]: kétgömbcsuklós rúd -> minimális elfordulás (a saját tengely körüli spin
% kinematikailag nem definiált, a valóságban a rod-end / flexure határozza meg).
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
        R  = euler_to_rot(Q(k,3), Q(k,4), Q(k,5));
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

%% ---------------- F1 – DAA (első tengely) specifikus kényszerek ----------------

function [names, vals] = f1_kingpin_cons(C, Kb, WC, F1, radii, gap, Col, names, vals)
% Rögzített lengőkarok mellett (Legality Setup, rögzített rocker; a pushrod a lengőkaron
% vagy a gömbcsukló közelében) az upright a királycsap (alsó -> felső gömbcsukló) körül fordul:
%   C10.2.6b: ±12° kerékszögön a 700 mm-es setup-gömb (közepe = WC) alsó pontjának,
%             azaz a WC Z-jének változása <= 2 mm
%   C10.3.7 : +23° (toe-in) / -21° (toe-out) elérhető, és a felni nem ér a tagokhoz.
%             A szabály szerint a kormányzás ehhez leválasztható -> a kormányösszekötőt csak
%             akkor vizsgáljuk, ha a rack (csak Y-ban mozogva) el tudja érni a pózt.
    n0 = f1_wheel_axes(F1);
    P  = Kb(2,:)'; a = Kb(1,:)' - P; a = a / norm(a);
    al = deg2rad(-70:0.25:70); N = numel(al);
    delta = zeros(1, N); dzc = zeros(1, N);
    for k = 1:N
        Rk = f1_axis_rot(a, al(k));
        nk = Rk * n0;  delta(k) = asind(nk(1));            % bal kerék, X előre: + = toe-in
        wk = P + Rk * (WC(:) - P); dzc(k) = wk(3) - WC(3);
    end

    % C10.2.6b
    if max(delta) >= F1.JackAngle && min(delta) <= -F1.JackAngle
        cj = max(abs(dzc(abs(delta) <= F1.JackAngle))) - F1.JackMax;
    else
        cj = 10;
    end
    [names, vals] = f1_add(names, vals, sprintf('C10.2.6b kerékközép Z-változás ±%g° kerékszögön <= %g mm [mm]', ...
        F1.JackAngle, F1.JackMax), cj);

    % C10.3.7 – elérhetőség
    [names, vals] = f1_add(names, vals, sprintf('C10.3.7 elérhető toe-in >= %g° és toe-out >= %g° [deg]', ...
        F1.LockToeIn, F1.LockToeOut), [F1.LockToeIn - max(delta); F1.LockToeOut + min(delta)]);

    % C10.3.7 – felni-tag szabadmagasság a két lock pózban (+ szükséges rack-út)
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
            c_rim((t-1)*5 + 5) = -1;     % a kormányösszekötő így nem éri el (kormánykar cserélhető)
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
% Az összes F1 2026 kényszer a DAA-ra (c <= 0 = megfelel). 4 kimenettel a riporthoz is.
    ceq = []; names = {}; vals = {};
    if ~F1.Enable, c = zeros(0, 1); return; end
    C  = reshape(x(1:15), [5,3]);
    Kb = reshape(x(16:24), [3,3]);
    Km = [Kb(1,:); Kb(1,:); Kb(2,:); Kb(2,:); Kb(3,:)];   % 5 tag (virtuális szétbontás, C10.3.2)
    hinge = [1 2; 1 2; 3 4; 3 4; 0 0];                     % A-karok szárai a csuklótengelyük körül
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

function [c, ceq] = total_nonlcon_DAA(x, WC_init, Collision, F1)
% Eredeti ütközés-kényszerek + F1 2026 kényszerek.
    [c1, ceq1] = collision_nonlcon(x, WC_init, Collision);
    [c2, ceq2] = f1_nonlcon_DAA(x, WC_init, F1, Collision);
    c = [c1(:); c2(:)]; ceq = [ceq1(:); ceq2(:)];
end
