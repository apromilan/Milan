function full_kinematic_optimalization_multilink_plot
    clc; clear; close all;

    disp('========================================================');
    disp(' MULTILINK KINEMATIKAI OPTIMALIZÁLÓ (V4.0 - Roll & Ackermann)');
    disp(' - Ackermann százalék számítása mindkét oldal szimulációjával');
    disp(' - Dőlés (Chassis Roll) szimuláció és Camber/Toe optimalizálás');
    disp(' - Egyedi relatív +- határok mind az 5 C és 5 K pontra külön-külön');
    disp(' - GUI támogatás a Kormányzási és Dőlési Célgörbékre is');
    disp(' - Interaktív Plotter dinamikus szűréssel a releváns paraméterekre');
    disp('========================================================');
    disp('TIPP: Az optimalizálás leállításához hozz létre egy "stop_opt.txt"');
    disp('nevű üres fájlt a munkakönyvtárban futás közben!');
    disp('========================================================');

    %% 1. OPTIMALIZÁLÁSI CÉLOK ÉS SÚLYOK MEGADÁSA
    USE_GUI_FOR_CURVES = true; 
    
    % JÁRMŰ ALAPPARAMÉTEREK
    Vehicle.Wheelbase = 3000;   % Tengelytáv [mm] 
    Vehicle.Trackwidth = 1600;  % Első nyomtáv [mm]
    Vehicle.h_CG_SM = 320;          % [mm] rugózott tömeg CG magassága, statikus (anti-squat)
    Vehicle.RearDrivePercent = 100; % [%] hajtás a hátsó tengelyen (RWD = 100)
    Vehicle.SteerRange = 0;     % [mm] kormánymű (rack) sweep tartomány. 0 = NINCS kormányzás (hátsó tengely)
                                % >0 esetén -SteerRange..+SteerRange között csak az Ackermann sweepel

    Target.dz = -30:1:30;
    Target.dy = linspace(-30, 30, 61);
    Target.droll = linspace(-2, 2, 61); % Dőlés szögtartománya [deg]
    
    % --- EXCEL ALAPÚ CÉLGÖRBE KEZELÉS ---
    target_excel = 'Célgörbe_Rear.xlsx';
    loaded_data = {};
    eval_pts = -30:3:30; % -30-tól 30-ig 3-as lépésközzel (21 oszlop)
    eval_pts_roll = linspace(-2, 2, 21); % -2-től 2-ig (21 oszlop) a dőléshez

    if exist(target_excel, 'file') == 2
        disp(['Célgörbe adatok betöltése az Excelből: ', target_excel, '...']);
        loaded_data = readcell(target_excel);
    end

    if USE_GUI_FOR_CURVES
        disp('Grafikus célgörbék meghatározása indul...');
        
        [x_init, y_init] = get_excel_pts(loaded_data, 3, eval_pts);
        Target.Camber = defineTargetCurveGUI('Camber (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Camber [deg]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 4, eval_pts);
        Target.Toe    = defineTargetCurveGUI('Toe (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Toe [deg]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 5, eval_pts);
        Target.RC_Z   = defineTargetCurveGUI('Roll Center Z', -30, 30, 'Rugóút (Z) [mm]', 'RC Magasság [mm]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 17, eval_pts);
        Target.KPI    = defineTargetCurveGUI('KPI (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'KPI [deg]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 18, eval_pts);
        Target.Caster = defineTargetCurveGUI('Caster (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Caster [deg]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 19, eval_pts);
        Target.Trail  = defineTargetCurveGUI('Mechanical Trail (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Trail [mm]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 20, eval_pts);
        Target.Scrub  = defineTargetCurveGUI('Scrub Radius (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Scrub [mm]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 33, eval_pts);
        Target.AntiSquat = defineTargetCurveGUI('Anti-Squat (Heave)', -30, 30, 'Rugóút (Z) [mm]', 'Anti-Squat [%]', x_init, y_init);
        
        if Vehicle.SteerRange > 0
            [x_init, y_init] = get_excel_pts(loaded_data, 21, eval_pts);
            Target.Ackermann = defineTargetCurveGUI('Ackermann', -30, 30, 'Kormánymű (Y) [mm]', 'Ackermann [%]', x_init, y_init);
        else
            Target.Ackermann = 100 + 0*Target.dy;   % hátsó tengely: nincs Ackermann
        end
        
        % GUI a dőlés görbéihez
        [x_init, y_init] = get_excel_pts(loaded_data, 25, eval_pts_roll);
        Target.Camber_Roll = defineTargetCurveGUI('Camber (Roll)', -2, 2, 'Dőlés (Roll) [deg]', 'Camber [deg]', x_init, y_init);
        
        [x_init, y_init] = get_excel_pts(loaded_data, 26, eval_pts_roll);
        Target.Toe_Roll = defineTargetCurveGUI('Toe (Roll)', -2, 2, 'Dőlés (Roll) [deg]', 'Toe [deg]', x_init, y_init);
    else
        disp('Automatikus alapgörbék használata.');
        Target.Camber = -0.02 * Target.dz - 1.0; Target.Toe = 0.0 * Target.dz; Target.RC_Z = 45.0 - 0.05 * abs(Target.dz); 
        Target.KPI = 12.0 + 0.0 * Target.dz; Target.Caster = 5.0 + 0.0 * Target.dz; Target.Trail = 25.0 + 0.0 * Target.dz;
        Target.Scrub = -10.0 + 0.0 * Target.dz; Target.AntiSquat = 0.0 * Target.dz; Target.Ackermann = 100.0 + 0.0 * Target.dy; 
        Target.Camber_Roll = -0.5 * Target.droll; Target.Toe_Roll = 0.0 * Target.droll; 
    end

    % --- CÉLGÖRBÉK KISZEDÉSE ÉS MENTÉSE ---
    out_cell = cell(33, 22); out_cell(:) = {''};
    out_cell{1, 12} = 'Heave'; out_cell(2, 2:22) = num2cell(eval_pts);
    rows = {'Camber', 'Toe', 'RollCenter', 'KPI', 'Caster', 'MechTrail', 'Scrub', 'Ackerman'};
    out_cell(3:10, 1) = rows'; out_cell(3:10, 2:22) = num2cell(zeros(8, 21));
    out_cell(3, 2:22) = num2cell(interp1(Target.dz, Target.Camber, eval_pts, 'pchip', 'extrap'));
    out_cell(4, 2:22) = num2cell(interp1(Target.dz, Target.Toe, eval_pts, 'pchip', 'extrap'));
    out_cell(5, 2:22) = num2cell(interp1(Target.dz, Target.RC_Z, eval_pts, 'pchip', 'extrap'));

    out_cell{12, 12} = 'Heave: KPI/Caster/Trail/Scrub  (Rack: csak Ackermann)'; out_cell(13, 2:22) = num2cell(eval_pts);
    out_cell(14:21, 1) = rows'; out_cell(14:21, 2:22) = num2cell(zeros(8, 21));
    out_cell(17, 2:22) = num2cell(interp1(Target.dz, Target.KPI, eval_pts, 'pchip', 'extrap'));
    out_cell(18, 2:22) = num2cell(interp1(Target.dz, Target.Caster, eval_pts, 'pchip', 'extrap'));
    out_cell(19, 2:22) = num2cell(interp1(Target.dz, Target.Trail, eval_pts, 'pchip', 'extrap'));
    out_cell(20, 2:22) = num2cell(interp1(Target.dz, Target.Scrub, eval_pts, 'pchip', 'extrap'));
    out_cell(21, 2:22) = num2cell(interp1(Target.dy, Target.Ackermann, eval_pts, 'pchip', 'extrap'));

    out_cell{23, 12} = 'Chassis Roll'; out_cell(24, 2:22) = num2cell(eval_pts_roll);
    out_cell(25:32, 1) = rows'; out_cell(25:32, 2:22) = num2cell(zeros(8, 21));
    out_cell(25, 2:22) = num2cell(interp1(Target.droll, Target.Camber_Roll, eval_pts_roll, 'pchip', 'extrap'));
    out_cell(26, 2:22) = num2cell(interp1(Target.droll, Target.Toe_Roll, eval_pts_roll, 'pchip', 'extrap'));
    out_cell{33, 1} = 'AntiSquat (Heave)';
    out_cell(33, 2:22) = num2cell(interp1(Target.dz, Target.AntiSquat, eval_pts, 'pchip', 'extrap'));

    curves_changed = true;
    if ~isempty(loaded_data)
        try
            old_mat = cell2mat(loaded_data([3:10, 14:21, 25:26, 33], 2:22));
            new_mat = cell2mat(out_cell([3:10, 14:21, 25:26, 33], 2:22));
            if max(abs(old_mat(:) - new_mat(:))) < 1e-4
                curves_changed = false;
            end
        catch
        end
    else
        writecell(out_cell, target_excel);
        curves_changed = false; 
        disp(['Létrehozva az alapértelmezett sablon: ', target_excel]);
    end

    if curves_changed
        file_idx = 1;
        while exist(sprintf('Célgörbe_Rear_%d.xlsx', file_idx), 'file') == 2
            file_idx = file_idx + 1;
        end
        new_target_file = sprintf('Célgörbe_Rear_%d.xlsx', file_idx);
        writecell(out_cell, new_target_file);
        disp(['Célgörbék megváltoztak! Új iterációs fájl mentve: ', new_target_file]);
    else
        disp('A célgörbék megegyeznek a betöltöttel, nem készül új másolat.');
    end

    % Optimalizálási Súlyok (Weights)
    % W.Camber = 500; 
    % W.Toe = 500; 
    % W.RC_Z = 50; 
    % W.KPI = 10; 
    % W.Caster = 10; 
    % W.Trail = 30; 
    % W.Scrub = 30; 
    % W.AntiSquat = 20;   % Anti-squat súly (heave sweep, a cél-görbéhez képest, [%]^2)
    % W.Ackermann = 0; 
    % W.Camber_Roll = 300; 
    % W.Toe_Roll = 300;
    % W.Camber = 800; 
    % W.Toe = 800; 
    % W.RC_Z = 30;
    % W.AntiSquat = 20; % JAVÍTÁS: Anti-Dive weight a Cost függvényhez
    % W.KPI = 1000; 
    % W.Caster = 1000; 
    % W.Trail = 300; 
    % W.Scrub = 300; 
    % W.Ackermann = 10;
    % W.Camber_Roll = 5000; 
    % W.Toe_Roll = 5000;

    % W.Camber = 100; 
    % W.Toe = 1000; 
    % W.RC_Z = 5.5;
    % W.KPI = 5; 
    % W.Caster = 5; 
    % W.Trail = 11; 
    % W.Scrub = 11; 
    % W.Ackermann = 0;
    % W.Camber_Roll = 300; 
    % W.Toe_Roll = 300;
    % W.AntiSquat = 50;  

    camber_heave_tol = 0.01;
    toe_heave_tol = 0.01;
    rc_tol = 0.5;
    antisquat_tol = 0.5;
    kpi_tol = 0.5;
    caster_tol = 0.5;
    trail_tol = 0.5;
    scrub_tol = 0.5;
    camber_roll_tol = 0.05;
    toe_roll_tol = 0.01;

    W.Camber = 1/camber_heave_tol^2; 
    W.Toe = 1/toe_heave_tol^2; 
    W.RC_Z = 1/rc_tol^2;
    W.AntiSquat = 1/antisquat_tol^2;
    W.KPI = 1/kpi_tol^2;          
    W.Caster = 1/caster_tol^2;        
    W.Trail = 1/trail_tol^2; 
    W.Scrub = 1/scrub_tol^2; 
    W.Ackermann = 0;      
    W.Camber_Roll = 1/camber_roll_tol^2; 
    W.Toe_Roll = 1/toe_roll_tol^2;



    %% 1a. F1 2026 SZABÁLYZAT (Section C10) – KÉNYSZEREK
    % Az alapértékek szabálypontonként a f1_rules_2026() függvényben vannak (a fájl végén).
    % A saját autódra itt állítsd be:
    F1 = f1_rules_2026('rear');        % 'front' | 'rear'  (ez a hátsó multilink)
    F1.RefPlaneZ       = 95;           % [mm] az F1 Z=0 referenciasík magassága a talaj felett (Legality Setup)
    F1.Rim.InnerRadius = 215;          % [mm] a felni belső (hordó) sugara – CAD / RV-R-RIM-MIN
    % F1.Drum.Enable = true; F1.Drum.Radius = ...; F1.Drum.YW = [..., ...];   % C10.3.4c / C3.14.2
    % F1.NoMountBox  = [xmin xmax; ymin ymax; zmin zmax];                    % C10.3.10: PU-ra nem köthet
    % F1.Enable = false;               % F1 kényszerek ki (eredeti FS működés)

    %% 1b. ÜTKÖZÉS / CLEARANCE PARAMÉTEREK (szerkeszd ide)
    % Rudak: átmérő [mm] – Link 1..5 (a felület, ami nem érhet máshoz)
    Collision.rod_diameter = [20, 20, 20, 20, 12];
    Collision.min_clearance = 5;

    % % Motor (AABB doboz, mm)
    % Collision.motor_center = [0, 557, 193];
    % Collision.motor_size   = [65, 90.5, 65];   % [dx, dy, dz]

    % Motor (Henger, mm)
    % Collision.motor_center = [0, 546.6, 193]; % A henger középpontja
    % Collision.motor_radius = 48;            % A henger sugara (írd be a valós értéket)
    % Collision.motor_length = 160.2;          % A henger teljes hossza
    % Collision.motor_axis   = [0, 1, 0];     % A henger orientációja (pl. Y-tengely mentén fekszik)
    Collision.motor_radius = 48;             % A henger sugara (írd be a valós értéket)
    Collision.motor_length = 160.2;          % A henger teljes hossza
    Collision.motor_y_offset = -63.4;        % Eltolás a kerékközépponttól a tengely mentén (546.6 - 610)

    % Felni (henger a WC körül)
    Collision.rim_inner_radius = 119;
    Collision.rim_outer_radius = 124.5;
    Collision.rim_width        = 195;
    Collision.rim_y_offset     = 0;

    % --- F1 2026: felni a C10.7.2 szerint, nincs agymotor (felülírja a fenti FS értékeket) ---
    if F1.Enable
        Collision.use_motor        = false;
        Collision.rim_inner_radius = F1.Rim.InnerRadius;
        Collision.rim_outer_radius = F1.Rim.OuterRadius;    % Ø496 perem
        Collision.rim_width        = F1.Rim.Width;          % 420.3 / 334
        Collision.rim_y_offset     = F1.Rim.CenterOffset;
        Collision.wheel_axis0      = f1_wheel_axes(F1);     % Legality Setup camber (-1° / -3°)
    else
        Collision.use_motor   = true;
        Collision.wheel_axis0 = [0; 1; 0];
    end

    Collision.penalty = 1e4;   % 2. fázis: soft tartalék (ha kell)
    Collision.steer_range = Vehicle.SteerRange;   % nonlcon ennyi rack-úttal ellenőriz (0 = kihagyja)

    %% 2. BEMENETI ADATOK BEOLVASÁSA EXCELBŐL
    input_excel_file = 'Suspension_Points_Multilink_Rear.xlsx';
    
    if exist(input_excel_file, 'file') ~= 2
        disp(['A(z) ', input_excel_file, ' nem található. Alapértelmezett sablon létrehozása...']);
        init_raw = {
            'Link 1 Chassis', -1608.900, 230.898, 295.532; 
            'Link 1 Upright',  -1587.000, 505.000, 285.000;
            'Link 2 Chassis', -1431.440, 230.017, 267.328;
            'Link 2 Upright', -1487.000, 505.000, 285.000;
            'Link 3 Chassis', -1304.330, 230.345, 179.279;
            'Link 3 Upright', -1495.000, 563.000, 105.000;
            'Link 4 Chassis',  -1654.490, 229.702, 139.370;
            'Link 4 Upright',  -1595.000, 563.000, 105.000;
            'Link 5 Chassis', -1448.000, 228.997, 219.682;
            'Link 5 Upright', -1448.000, 575.000, 190.000;
            'Wheel Center',   -1540, 600, 193
        };
        T_default = cell2table(init_raw, 'VariableNames', {'Name', 'X', 'Y', 'Z'});
        writetable(T_default, input_excel_file);
    end

    disp(['Kezdőpontok betöltése az Excelből: ', input_excel_file, '...']);
    T_in = readtable(input_excel_file);

    C_init = zeros(5,3);
    K_init = zeros(5,3);

    for i = 1:5
        idx_c = find(strcmpi(T_in.Name, sprintf('Link %d Chassis', i)) | strcmpi(T_in.Name, sprintf('Link%d Chassis', i)), 1);
        idx_k = find(strcmpi(T_in.Name, sprintf('Link %d Upright', i)) | strcmpi(T_in.Name, sprintf('Link%d Upright', i)), 1);
        
        if isempty(idx_c) || isempty(idx_k)
            error('Hiba az Excel fájl formátumában: Link %d Chassis vagy Upright hiányzik!', i);
        end
        
        C_init(i,:) = [T_in.X(idx_c), T_in.Y(idx_c), T_in.Z(idx_c)];
        K_init(i,:) = [T_in.X(idx_k), T_in.Y(idx_k), T_in.Z(idx_k)];
    end

    idx_wc = find(strcmpi(T_in.Name, 'Wheel Center'), 1);
    if ~isempty(idx_wc)
        WC_init = [T_in.X(idx_wc), T_in.Y(idx_wc), T_in.Z(idx_wc)];
    else
        WC_init = [-1540, 600, 193]; 
    end

    f1_check_wheel_static(WC_init, F1, F1.Axle);   % C10.1c, C10.10.1, gumiméret
    if F1.Enable && F1.IsFront && Vehicle.SteerRange > 0
        warning(['F1: a C10.2.6b (jacking) és C10.3.7 (lock) ellenőrzés csak a DAA optimalizálóban van, ' ...
                 'a multilink itt hátsó tengelyre készült.']);
    end

    %% 3. RELATÍV BOUNDARY HATÁROK
    % dev_C1 = [-50, 50; -50, 50; -50, 50]; 
    % dev_C2 = [-50, 50; -50, 50; -50, 50]; 
    % dev_C3 = [-50, 50; -50, 50; -50, 50]; 
    % dev_C4 = [-50, 50; -50, 50; -50, 50]; 
    % dev_C5 = [-50, 50; -50, 50; -50, 50]; 
    % 
    % dev_K1 = [-50, 50; -50, 50; -50, 50]; 
    % dev_K2 = [-50, 50; -50, 50; -50, 50]; 
    % dev_K3 = [-50, 50; -50, 50; -50, 50]; 
    % dev_K4 = [-50, 50; -50, 50; -50, 50]; 
    % dev_K5 = [-50, 50; -50, 50; -50, 50];  

    % dev_C1 = [-20, 20; 0, 0; -20, 20]; 
    % dev_C2 = [-20, 20; 0, 0; -20, 20]; 
    % dev_C3 = [-20, 20; 0, 0; -20, 20]; 
    % dev_C4 = [-20, 20; 0, 0; -20, 20]; 
    % dev_C5 = [-20, 20; 0, 0; -20, 20]; 
    % 
    % dev_K1 = [-20, 20; -20, 20; -20, 20]; 
    % dev_K2 = [-20, 20; -20, 20; -20, 20]; 
    % dev_K3 = [-20, 20; -20, 20; -20, 20]; 
    % dev_K4 = [-20, 20; -20, 20; -20, 20]; 
    % dev_K5 = [-20, 20; -20, 20; -20, 20]; 

    dev_C1 = [-40, 40; 0, 0; -40, 40]; 
    dev_C2 = [-40, 40; 0, 0; -40, 40]; 
    dev_C3 = [-40, 40; 0, 0; -40, 40]; 
    dev_C4 = [-40, 40; 0, 0; -40, 40]; 
    dev_C5 = [-40, 40; 0, 0; -40, 40]; 

    dev_K1 = [-60, 60; -60, 60; -60, 60]; 
    dev_K2 = [-60, 60; -60, 60; -60, 60]; 
    dev_K3 = [-60, 60; -60, 60; -60, 60]; 
    dev_K4 = [-60, 60; -60, 60; -60, 60]; 
    dev_K5 = [-60, 60; -60, 60; -60, 60]; 

    % dev_C1 = [-100, 100; 0, 0; -100, 100]; 
    % dev_C2 = [-100, 100; 0, 0; -100, 100]; 
    % dev_C3 = [-100, 100; 0, 0; -100, 100]; 
    % dev_C4 = [-100, 100; 0, 0; -100, 100]; 
    % dev_C5 = [0, 0; 0, 0; 0, 0]; 
    % 
    % dev_K1 = [-100, 100; -100, 100; -100, 100]; 
    % dev_K2 = [-100, 100; -100, 100; -100, 100]; 
    % dev_K3 = [-100, 100; -100, 100; -100, 100]; 
    % dev_K4 = [-100, 100; -100, 100; -100, 100]; 
    % dev_K5 = [-100, 100; -100, 100; -100, 100]; 

    dev_C_min = [ dev_C1(:,1)' ; dev_C2(:,1)' ; dev_C3(:,1)' ; dev_C4(:,1)' ; dev_C5(:,1)' ];
    dev_C_max = [ dev_C1(:,2)' ; dev_C2(:,2)' ; dev_C3(:,2)' ; dev_C4(:,2)' ; dev_C5(:,2)' ];

    dev_K_min = [ dev_K1(:,1)' ; dev_K2(:,1)' ; dev_K3(:,1)' ; dev_K4(:,1)' ; dev_K5(:,1)' ];
    dev_K_max = [ dev_K1(:,2)' ; dev_K2(:,2)' ; dev_K3(:,2)' ; dev_K4(:,2)' ; dev_K5(:,2)' ];

    lb_C_matrix = C_init + dev_C_min;
    ub_C_matrix = C_init + dev_C_max;

    lb_K_matrix = K_init + dev_K_min;
    ub_K_matrix = K_init + dev_K_max;

    x0 = [C_init(:); K_init(:)]; 
    lb = [lb_C_matrix(:); lb_K_matrix(:)]; 
    ub = [ub_C_matrix(:); ub_K_matrix(:)];

    %% 4. OPTIMALIZÁLÁS FUTTATÁSA (2 fázis)
    % 5 független rúd – nincs A-arm összekötés.
    % 1. fázis: ütközések minimalizálása → 0 feasibility felé
    % 2. fázis: kinematikai cost, hard nonlcon, feasible start (ne ugorjon vissza)
    disp('Optimalizálás indítása (30 paraméter: C és K pontok)...');
    disp('--- 1. fázis: Feasibility helyreállítás ---');

    nonlcon_fun = @(x) total_nonlcon_ML(x, WC_init, Collision, F1);   % ütközés + F1 2026 kényszerek
    feas_obj = @(x) feasibility_objective(x, WC_init, Collision, F1);

    [~, ~, f1n, f1v] = f1_nonlcon_ML(x0, WC_init, F1, Collision);
    f1_report(f1n, f1v, 'kiindulási geometria');

    options_feas = optimoptions('fmincon', 'Display', 'iter-detailed', ...
    'Algorithm', 'interior-point', 'MaxFunctionEvaluations', 4000, ...
    'StepTolerance', 1e-6, 'OptimalityTolerance', 1e-6, ...
    'OutputFcn', @stop_optimization_callback);

    tic;
    [x_feas, f_feas] = fmincon(feas_obj, x0, [], [], [], [], lb, ub, [], options_feas);
    toc;
    fprintf('1. fázis: feasibility_objective = %.6f (0 = nincs sértés)\n', f_feas);

    [c_check, ~] = nonlcon_fun(x_feas);
    if isempty(c_check)
        max_c = 0;
    else
        max_c = max([0; c_check(:)]);
    end
    fprintf('1. fázis max(c) = %.4f  (cél: <= 0)\n', max_c);

    disp('--- 2. fázis: Kinematikai optimalizálás (SQP + hard nonlcon) ---');
    obj_fun = @(x) calc_total_cost(x, WC_init, Target, W, Vehicle, Collision);

    options = optimoptions('fmincon', 'Display', 'iter-detailed', ...
    'Algorithm', 'interior-point', 'MaxFunctionEvaluations', 10000, ...
    'StepTolerance', 1e-5, 'OptimalityTolerance', 1e-4, ...
    'ConstraintTolerance', 1e-4, ...
    'OutputFcn', @stop_optimization_callback);

    tic;
    [x_opt, fval] = fmincon(obj_fun, x_feas, [], [], [], [], lb, ub, nonlcon_fun, options);
    toc;

    %% 5. EREDMÉNYEK KIÉRTÉKELÉSE ÉS MENTÉSE
    C_opt = reshape(x_opt(1:15), [5, 3]);
    K_opt = reshape(x_opt(16:30), [5, 3]);
    
    disp('========================================================');
    disp(' OPTIMALIZÁCIÓ BEFEJEZŐDÖTT!');
    disp('========================================================');
    fprintf('Végső hibafüggvény érték: %.4f\n', fval);
    [~, ~, f1n, f1v] = f1_nonlcon_ML(x_opt, WC_init, F1, Collision);
    f1_report(f1n, f1v, 'optimalizált geometria');
    
    base_out_name = 'Optim_Multilink_Rear';
    if exist([base_out_name, '.xlsx'], 'file') ~= 2
        output_excel_file = [base_out_name, '.xlsx'];
    else
        file_idx = 1;
        while exist(sprintf('%s_%d.xlsx', base_out_name, file_idx), 'file') == 2
            file_idx = file_idx + 1;
        end
        output_excel_file = sprintf('%s_%d.xlsx', base_out_name, file_idx);
    end

    out_cell = cell(11, 4);
    for i = 1:5
        out_cell{(i-1)*2 + 1, 1} = sprintf('Link %d Chassis', i);
        out_cell{(i-1)*2 + 1, 2} = C_opt(i,1); out_cell{(i-1)*2 + 1, 3} = C_opt(i,2); out_cell{(i-1)*2 + 1, 4} = C_opt(i,3);
        out_cell{(i-1)*2 + 2, 1} = sprintf('Link %d Upright', i);
        out_cell{(i-1)*2 + 2, 2} = K_opt(i,1); out_cell{(i-1)*2 + 2, 3} = K_opt(i,2); out_cell{(i-1)*2 + 2, 4} = K_opt(i,3);
    end
    out_cell{11, 1} = 'Wheel Center';
    out_cell{11, 2} = WC_init(1); out_cell{11, 3} = WC_init(2); out_cell{11, 4} = WC_init(3);

    T_out = cell2table(out_cell, 'VariableNames', {'Name', 'X', 'Y', 'Z'});
    writetable(T_out, output_excel_file);
    fprintf('Optimalizált pontok elmentve az Excel fájlba: %s\n', output_excel_file);

    %% 6. KINEMATIKAI LEFUTTATÁS ÉS INTERAKTÍV PLOTTER INDÍTÁSA
    disp('Szimulációs eredmények kiszámítása a plotoláshoz...');
    dz_vec = -30:5:30;
    if Vehicle.SteerRange > 0
        dy_vec = -Vehicle.SteerRange:5:Vehicle.SteerRange;
    else
        dy_vec = 0;   % nincs kormányzás
    end
    droll_vec = -2:0.5:2; 
    
    res_init = run_kinematics_sweep(C_init, K_init, WC_init, dz_vec, dy_vec, droll_vec, Vehicle);
    res_opt  = run_kinematics_sweep(C_opt, K_opt, WC_init, dz_vec, dy_vec, droll_vec, Vehicle);

    i0 = find(dz_vec == 0, 1);
    if ~isempty(i0)
        fprintf('Anti-squat (dz=0): kezdeti %.1f %% | optimalizált %.1f %%  (Phi_R: %.2f / %.2f deg)\n', ...
            res_init.AntiSquat(i0), res_opt.AntiSquat(i0), res_init.Phi_R(i0), res_opt.Phi_R(i0));
    end

    launchInteractivePlotterGUI(dz_vec, dy_vec, droll_vec, Target, res_init, res_opt, Vehicle.SteerRange > 0);
end

%% ========================================================================
%  INTERAKTÍV PLOTTER GUI (DINAMIKUS SZŰRÉSSEL)
%  ========================================================================
function launchInteractivePlotterGUI(dz_vec, dy_vec, droll_vec, Target, res_init, res_opt, has_steer)
    % has_steer = false -> a 'Steer Rack' X-tengely opció nem jelenik meg (hátsó tengely)
    if has_steer
        x_types = [1 2 3];
        x_names = {'Wheel Travel (Rugóút Z)', 'Steer Rack (Kormánymű Y)', 'Chassis Roll (Dőlés)'};
    else
        x_types = [1 3];
        x_names = {'Wheel Travel (Rugóút Z)', 'Chassis Roll (Dőlés)'};
    end
    fig = figure('Name', 'Multilink Kinematikai Eredmények - Interaktív Plotter', ...
        'NumberTitle', 'off', 'Position', [150 100 1100 650]);

    ax = axes('Parent', fig, 'Position', [0.08 0.12 0.62 0.8]);
    grid(ax, 'on'); hold(ax, 'on');

    pnl = uipanel('Parent', fig, 'Title', 'Plot Beállítások', 'Position', [0.73 0.05 0.25 0.9]);

    uicontrol(pnl, 'Style', 'text', 'String', 'X Tengely (Független változó):', ...
        'Position', [10 540 220 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    pop_x = uicontrol(pnl, 'Style', 'popupmenu', ...
        'String', x_names, ...
        'Position', [10 515 220 25], 'Callback', @update_x_selection);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y Tengely (Paraméter):', ...
        'Position', [10 460 220 20], 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    pop_y = uicontrol(pnl, 'Style', 'popupmenu', ...
        'String', {'Camber', 'Toe', 'Roll Center Z'}, ... % Alapértelmezés Heave-re
        'Position', [10 435 220 25], 'Callback', @update_plot);

    uicontrol(pnl, 'Style', 'text', 'String', 'X Tartomány (Min / Max):', ...
        'Position', [10 360 220 20], 'HorizontalAlignment', 'left');
    txt_xmin = uicontrol(pnl, 'Style', 'edit', 'String', '-50', 'Position', [10 335 90 25]);
    txt_xmax = uicontrol(pnl, 'Style', 'edit', 'String', '50', 'Position', [110 335 90 25]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'X Skála Frissítése', ...
        'Position', [10 300 200 25], 'Callback', @apply_x_limits);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y Tartomány (Min / Max):', ...
        'Position', [10 240 220 20], 'HorizontalAlignment', 'left');
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', '-5', 'Position', [10 215 90 25]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', '5', 'Position', [110 215 90 25]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Y Skála Frissítése', ...
        'Position', [10 180 200 25], 'Callback', @apply_y_limits);

    update_plot();

    function update_x_selection(~, ~)
        x_type = x_types(get(pop_x, 'Value'));
        
        % Dinamikusan frissítjük az Y tengely legördülő menüjét
        if x_type == 1 % HEAVE
            set(pop_y, 'String', {'Camber', 'Toe', 'Roll Center Z', 'KPI', 'Caster', 'Mechanical Trail', 'Scrub Radius', 'Anti-Squat [%]', 'Phi (Side IC szög)'});
        elseif x_type == 2 % STEER (csak Ackermann)
            set(pop_y, 'String', {'Ackermann %'});
        else % ROLL
            set(pop_y, 'String', {'Camber', 'Toe'});
        end
        
        set(pop_y, 'Value', 1); % Visszaállunk az első elemre
        update_plot();
    end

    function update_plot(~, ~)
        cla(ax); grid(ax, 'on'); hold(ax, 'on');
        
        x_type = x_types(get(pop_x, 'Value'));
        y_type = get(pop_y, 'Value');
        
        if x_type == 1 % HEAVE (RUGÓÚT Z)
            x_data = dz_vec;
            x_label_str = 'Rugóút (Wheel Travel Z) [mm]';
            
            if y_type == 1
                tgt_data = interp1(Target.dz, Target.Camber, dz_vec, 'pchip', 'extrap'); 
                y_label_str = 'Camber [deg]'; init_data = res_init.Camber; opt_data = res_opt.Camber;
            elseif y_type == 2
                tgt_data = interp1(Target.dz, Target.Toe, dz_vec, 'pchip', 'extrap'); 
                y_label_str = 'Toe [deg]'; init_data = res_init.Toe; opt_data = res_opt.Toe;
            elseif y_type == 3
                tgt_data = interp1(Target.dz, Target.RC_Z, dz_vec, 'pchip', 'extrap'); 
                y_label_str = 'RC Height [mm]'; init_data = res_init.RC_Z; opt_data = res_opt.RC_Z;
            elseif y_type == 4
                tgt_data = interp1(Target.dz, Target.KPI, dz_vec, 'pchip', 'extrap');
                y_label_str = 'KPI [deg]'; init_data = res_init.KPI; opt_data = res_opt.KPI;
            elseif y_type == 5
                tgt_data = interp1(Target.dz, Target.Caster, dz_vec, 'pchip', 'extrap');
                y_label_str = 'Caster [deg]'; init_data = res_init.Caster; opt_data = res_opt.Caster;
            elseif y_type == 6
                tgt_data = interp1(Target.dz, Target.Trail, dz_vec, 'pchip', 'extrap');
                y_label_str = 'Trail [mm]'; init_data = res_init.Trail; opt_data = res_opt.Trail;
            elseif y_type == 7
                tgt_data = interp1(Target.dz, Target.Scrub, dz_vec, 'pchip', 'extrap');
                y_label_str = 'Scrub [mm]'; init_data = res_init.Scrub; opt_data = res_opt.Scrub;
            elseif y_type == 8
                tgt_data = interp1(Target.dz, Target.AntiSquat, dz_vec, 'pchip', 'extrap');
                y_label_str = 'Anti-Squat [%]'; init_data = res_init.AntiSquat; opt_data = res_opt.AntiSquat;
            elseif y_type == 9
                tgt_data = [];
                y_label_str = 'Phi_R (Side IC szög) [deg]'; init_data = res_init.Phi_R; opt_data = res_opt.Phi_R;
            end
            
        elseif x_type == 2 % STEER (KORMÁNYMŰ Y)
            x_data = dy_vec;
            x_label_str = 'Kormánymű (Steer Rack Y) [mm]';
            
            % Hátsó tengely: KPI/Caster/Trail/Scrub a Wheel Travel X tengelyen van, itt csak Ackermann
            tgt_data = interp1(Target.dy, Target.Ackermann, dy_vec, 'pchip', 'extrap');
            y_label_str = 'Ackermann [%]'; init_data = res_init.Ackermann; opt_data = res_opt.Ackermann;

        else % ROLL (CHASSIS DŐLÉS)
            x_data = droll_vec;
            x_label_str = 'Dőlés (Chassis Roll) [deg]';
            
            if y_type == 1
                tgt_data = interp1(Target.droll, Target.Camber_Roll, droll_vec, 'pchip', 'extrap'); 
                y_label_str = 'Camber [deg]'; init_data = res_init.Camber_roll; opt_data = res_opt.Camber_roll;
            elseif y_type == 2
                tgt_data = interp1(Target.droll, Target.Toe_Roll, droll_vec, 'pchip', 'extrap'); 
                y_label_str = 'Toe [deg]'; init_data = res_init.Toe_roll; opt_data = res_opt.Toe_roll;
            end
        end

        if ~isempty(tgt_data)
            plot(ax, x_data, tgt_data, 'y:', 'LineWidth', 2.5, 'DisplayName', 'Célgörbe');
        end
        plot(ax, x_data, init_data, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Kiindulási');
        plot(ax, x_data, opt_data, 'b-', 'LineWidth', 2.0, 'DisplayName', 'Optimalizált');

        xlabel(ax, x_label_str); ylabel(ax, y_label_str);
        title(ax, [y_label_str, ' vs. ', x_label_str], 'FontSize', 11);
        legend(ax, 'Location', 'best');

        xlim(ax, [min(x_data), max(x_data)]);
        set(txt_xmin, 'String', num2str(min(x_data)));
        set(txt_xmax, 'String', num2str(max(x_data)));

        yl = ylim(ax);
        set(txt_ymin, 'String', num2str(yl(1), '%.2f'));
        set(txt_ymax, 'String', num2str(yl(2), '%.2f'));
    end

    function apply_x_limits(~, ~)
        xmin_v = str2double(get(txt_xmin, 'String'));
        xmax_v = str2double(get(txt_xmax, 'String'));
        if ~isnan(xmin_v) && ~isnan(xmax_v) && xmax_v > xmin_v
            xlim(ax, [xmin_v, xmax_v]);
        end
    end

    function apply_y_limits(~, ~)
        ymin_v = str2double(get(txt_ymin, 'String'));
        ymax_v = str2double(get(txt_ymax, 'String'));
        if ~isnan(ymin_v) && ~isnan(ymax_v) && ymax_v > ymin_v
            ylim(ax, [ymin_v, ymax_v]);
        end
    end
end

%% ========================================================================
%  INTERAKTÍV GUI CÉLGÖRBÉK MEGADÁSÁRA ÉS MENTÉSÉRE
%  ========================================================================
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
    
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Utolsó Visszavonása (Undo)', 'Position', [10 265 250 28], 'Callback', @undo_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Minden Pont Törlése', 'Position', [10 230 250 28], 'Callback', @clear_points);
    
    uicontrol(pnl, 'Style', 'text', 'String', 'Y min / Y max skála:', 'Position', [10 185 120 20], 'HorizontalAlignment', 'left');
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_min_val), 'Position', [10 160 55 22]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_max_val), 'Position', [70 160 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Skála Beállítása', 'Position', [135 160 125 22], 'Callback', @update_axes_limits);
    
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Megtart / Ugrás (Skip)', 'Position', [10 80 250 35], 'BackgroundColor', [0.85 0.9 0.85], 'Callback', @skip_callback);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Mentés és Folytatás', 'Position', [10 30 250 40], 'BackgroundColor', [0.2 0.7 0.2], 'ForegroundColor', [1 1 1], 'FontWeight', 'bold', 'Callback', @save_callback);
    
    set(fig, 'WindowButtonDownFcn', @click_on_axes);
    update_plot_and_list();
    uiwait(fig);
    
    z_eval = linspace(x_min, x_max, 61)';
    [x_sorted, s_idx] = sort(x_pts); y_sorted = y_pts(s_idx);
    [x_sorted, u_idx] = unique(x_sorted); y_sorted = y_sorted(u_idx);
    
    if length(x_sorted) < 2, x_sorted = [x_min; x_max]; y_sorted = [0; 0]; end
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
        if ~isnan(nx) && ~isnan(ny), x_pts(end+1, 1) = nx; y_pts(end+1, 1) = ny; update_plot_and_list(); end
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
            [xs, s_idx] = sort(x_pts); ys = y_pts(s_idx);
            [xs, u_idx] = unique(xs); ys = ys(u_idx);
            z_fit = linspace(x_min, x_max, 100);
            y_fit = interp1(xs, ys, z_fit, 'pchip', 'extrap');
            plot(ax, z_fit, y_fit, 'b-', 'LineWidth', 2);
        end
        if ~isempty(x_pts), plot(ax, x_pts, y_pts, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); end
        str_list = cell(length(x_pts), 1);
        for i = 1:length(x_pts), str_list{i} = sprintf('%d:  X = %.2f,  Y = %.2f', i, x_pts(i), y_pts(i)); end
        set(lst_points, 'String', str_list);
        if ~isempty(str_list), set(lst_points, 'Value', length(str_list)); end
    end
end

%% ========================================================================
%  STOP OPCIÓ (CALLBACK FÜGGVÉNY)
%  ========================================================================
function stop = stop_optimization_callback(~, ~, ~)
    stop = false;
    if exist('stop_opt.txt', 'file') == 2
        fprintf('\n>>> FELHASZNÁLÓI MEGSZAKÍTÁS: stop_opt.txt észlelve! <<<\n');
        try delete('stop_opt.txt'); catch, end
        stop = true;
    end
end

%% ========================================================================
%  HIBAFÜGGVÉNY (COST FUNCTION)
%  ========================================================================
function cost = calc_total_cost(x, WC_init, Target, W, Vehicle, Collision)
    opt_inner = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-10);
    
    C_curr = reshape(x(1:15), [5, 3]);
    K_curr = reshape(x(16:30), [5, 3]);
    
    L0 = zeros(5,1);
    for i = 1:5, L0(i) = norm(K_curr(i,:) - C_curr(i,:)); end
    K_loc = K_curr - WC_init;
    
    cost = 0;

    % 1. RUGÓÚT VIZSGÁLAT (WHEEL TRAVEL Z) -> Camber, Toe, Roll Center Z
    q0 = [WC_init(1), WC_init(2), 0, 0, 0];
    travel_steps = -30:2:30; 
    for dz = travel_steps
        C_moved = C_curr; C_moved(:,3) = C_curr(:,3) - dz;
        obj_inner = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
        if exitflag <= 0, cost = cost + 1e6; continue; end
        q0 = q_opt; 
        
        R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
        wheel_normal = R_mat * [0; 1; 0];
        camber_act = -atand(wheel_normal(3) / wheel_normal(2));
        toe_act    = -atand(wheel_normal(1) / wheel_normal(2));
        
        target_camber_val = interp1(Target.dz, Target.Camber, dz, 'pchip', 'extrap');
        target_toe_val    = interp1(Target.dz, Target.Toe, dz, 'pchip', 'extrap');
        
        cost = cost + W.Camber * (camber_act - target_camber_val)^2;
        cost = cost + W.Toe    * (toe_act - target_toe_val)^2;
        
        [rc_act, rc_valid, side_ic_act, cp_act] = calculate_RC_Z(C_curr, K_curr, WC_init, dz);
        if rc_valid
            target_rc_val = interp1(Target.dz, Target.RC_Z, dz, 'pchip', 'extrap');
            cost = cost + W.RC_Z * (rc_act - target_rc_val)^2;
        else
            cost = cost + 1e6;
        end

        % Anti-squat (side IC alapján) a rugóút függvényében
        if W.AntiSquat > 0
            as_act = calc_anti_squat(side_ic_act, cp_act, dz, Vehicle);
            if isfinite(as_act)
                cost = cost + W.AntiSquat * (as_act - interp1(Target.dz, Target.AntiSquat, dz, 'pchip', 'extrap'))^2;
            else
                cost = cost + 1e6;   % side IC nem számolható
            end
        end

        % Kormányzási tengely paraméterek (KPI, Caster, Trail, Scrub) a rugóút függvényében
        [kpi_act, caster_act, scrub_act, trail_act] = calc_steer_axis_params(C_moved, q_opt, K_loc, WC_init);
        cost = cost + W.KPI    * (kpi_act    - interp1(Target.dz, Target.KPI,    dz, 'pchip', 'extrap'))^2;
        cost = cost + W.Caster * (caster_act - interp1(Target.dz, Target.Caster, dz, 'pchip', 'extrap'))^2;
        cost = cost + W.Trail  * (trail_act  - interp1(Target.dz, Target.Trail,  dz, 'pchip', 'extrap'))^2;
        cost = cost + W.Scrub  * (scrub_act  - interp1(Target.dz, Target.Scrub,  dz, 'pchip', 'extrap'))^2;

        % % Ütközés: megoldott upright pontok
        % Ütközés soft-penalty (Heave)
        WC_h = [q_opt(1), q_opt(2), WC_init(3)];
        K_h = zeros(5,3);
        for ii = 1:5, K_h(ii,:) = (WC_h' + R_mat * K_loc(ii,:)')'; end
        % pen = multilink_collision_penalty(C_moved, K_h, WC_h, true, Collision);
        % if pen > 0, cost = cost + Collision.penalty * (1 + pen); end
    end

    % 2. KORMÁNYZÁS VIZSGÁLAT (STEER RACK Y) -> csak Ackermann.
    % Hátsó tengelynél (Vehicle.SteerRange = 0) ez a blokk teljesen kimarad.
    if Vehicle.SteerRange > 0 && W.Ackermann > 0
        rack_steps = -Vehicle.SteerRange:2:Vehicle.SteerRange;
        q0_L = [WC_init(1), WC_init(2), 0, 0, 0];

        WC_init_R = WC_init; WC_init_R(2) = -WC_init(2);
        C_curr_R = C_curr; C_curr_R(:,2) = -C_curr(:,2);
        K_curr_R = K_curr; K_curr_R(:,2) = -K_curr(:,2);
        K_loc_R = K_curr_R - WC_init_R;
        q0_R = [WC_init_R(1), WC_init_R(2), 0, 0, 0];

        for dy = rack_steps
            C_steer_L = C_curr; C_steer_L(5,2) = C_curr(5,2) + dy;
            obj_inner_L = @(q) calc_link_errors(q, C_steer_L, K_loc, WC_init, 0, L0);
            [q_opt_L, ~, ~, exitflag_L] = lsqnonlin(obj_inner_L, q0_L, [], [], opt_inner);

            C_steer_R = C_curr_R; C_steer_R(5,2) = C_curr_R(5,2) + dy;
            obj_inner_R = @(q) calc_link_errors(q, C_steer_R, K_loc_R, WC_init_R, 0, L0);
            [q_opt_R, ~, ~, exitflag_R] = lsqnonlin(obj_inner_R, q0_R, [], [], opt_inner);

            if exitflag_L <= 0 || exitflag_R <= 0
                cost = cost + 1e6;
                continue;
            end
            q0_L = q_opt_L; q0_R = q_opt_R;

            R_mat_L = euler_to_rot(q_opt_L(3), q_opt_L(4), q_opt_L(5));
            wheel_normal_L = R_mat_L * [0; 1; 0];
            delta_L = -atand(wheel_normal_L(1) / wheel_normal_L(2));

            R_mat_R = euler_to_rot(q_opt_R(3), q_opt_R(4), q_opt_R(5));
            wheel_normal_R = R_mat_R * [0; 1; 0];
            delta_R = -atand(wheel_normal_R(1) / wheel_normal_R(2));

            if abs(dy) > 1e-4
                if abs(delta_L) > abs(delta_R)
                    delta_in = abs(delta_L); delta_out = abs(delta_R);
                else
                    delta_in = abs(delta_R); delta_out = abs(delta_L);
                end

                L_wb = Vehicle.Wheelbase; W_tr = Vehicle.Trackwidth;
                delta_out_rad = deg2rad(delta_out);
                ideal_ackermann_rad = atan(L_wb / ((L_wb / tan(delta_out_rad)) - W_tr));
                ideal_ackermann_deg = rad2deg(ideal_ackermann_rad);

                ack_perc_act = (delta_in / ideal_ackermann_deg) * 100;
                target_ack_val = interp1(Target.dy, Target.Ackermann, dy, 'pchip', 'extrap');
                cost = cost + W.Ackermann * (ack_perc_act - target_ack_val)^2;
            end
        end
    end

    % % % % 3. DŐLÉS VIZSGÁLAT (CHASSIS ROLL) -> Camber, Toe
    % % % roll_steps = -2:0.2:2;
    % % % q0_roll = [WC_init(1), WC_init(2), 0, 0, 0];
    % % % for droll = roll_steps
    % % %     R_roll = euler_to_rot(deg2rad(droll), 0, 0);
    % % %     C_rolled = (R_roll * C_curr')';
    % % % 
    % % %     obj_inner = @(q) calc_link_errors(q, C_rolled, K_loc, WC_init, 0, L0);
    % % %     [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0_roll, [], [], opt_inner);
    % % %     if exitflag <= 0, cost = cost + 1e6; continue; end
    % % %     q0_roll = q_opt;
    % % % 
    % % %     R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
    % % %     wheel_normal = R_mat * [0; 1; 0];
    % % %     camber_act = atand(wheel_normal(3) / wheel_normal(2));
    % % %     toe_act    = -atand(wheel_normal(1) / wheel_normal(2));
    % % % 
    % % %     target_camber_roll_val = interp1(Target.droll, Target.Camber_Roll, droll, 'pchip', 'extrap');
    % % %     target_toe_roll_val    = interp1(Target.droll, Target.Toe_Roll, droll, 'pchip', 'extrap');
    % % % 
    % % %     cost = cost + W.Camber_Roll * (camber_act - target_camber_roll_val)^2;
    % % %     cost = cost + W.Toe_Roll    * (toe_act - target_toe_roll_val)^2;
    % % % 
    % % %     % Ütközés soft-penalty (Roll)
    % % %     WC_r = [q_opt(1), q_opt(2), WC_init(3)];
    % % %     K_r = zeros(5,3);
    % % %     for ii = 1:5, K_r(ii,:) = (WC_r' + R_mat * K_loc(ii,:)')'; end
    % % %     % pen = multilink_collision_penalty(C_rolled, K_r, WC_r, true, Collision);
    % % %     % if pen > 0, cost = cost + Collision.penalty * (1 + pen); end
    % % % end

    % 3. DŐLÉS VIZSGÁLAT (CHASSIS ROLL) -> Camber, Toe
    %    Ugyanaz a logika, mint a front4.m-ben:
    %    - pure heave RC magasság körül forgatunk
    %    - negatív droll = szemből nézve balra dőlés
    roll_steps = -2:0.2:2;
    q0_roll = [WC_init(1), WC_init(2), 0, 0, 0];

    % Pure heave RC a design pozícióban (dz = 0) → ezt használjuk pivotnak
    [rc_z_pivot, rc_valid] = calculate_RC_Z(C_curr, K_curr, WC_init, 0);
    if ~rc_valid
        rc_z_pivot = 50;   % biztonsági fallback
    end
    pivot = [0; 0; rc_z_pivot];

    for droll = roll_steps
        r_rad = deg2rad(droll);
        % Ugyanaz a mátrix, mint a front4.m-ben
        R_roll = [1 0 0; 
            0 cos(r_rad) -sin(r_rad); 
            0 sin(r_rad)  cos(r_rad)];

        C_rolled = zeros(5,3);
        for i = 1:5
            C_rolled(i,:) = (R_roll * (C_curr(i,:)' - pivot) + pivot)';
        end

        obj_inner = @(q) calc_link_errors(q, C_rolled, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0_roll, [], [], opt_inner);
        if exitflag <= 0
            cost = cost + 1e6;
            continue;
        end
        q0_roll = q_opt;

        R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
        wheel_normal = R_mat * [0; 1; 0];

        % Camber előjel – a te korábbi döntésed szerint (heave-konvenció)
        % Ha a mirroring probléma még fennáll, itt fordíthatod:
        camber_act = -atand(wheel_normal(3) / wheel_normal(2));
        toe_act    = -atand(wheel_normal(1) / wheel_normal(2));

        target_camber_roll_val = interp1(Target.droll, Target.Camber_Roll, droll, 'pchip', 'extrap');
        target_toe_roll_val    = interp1(Target.droll, Target.Toe_Roll, droll, 'pchip', 'extrap');

        cost = cost + W.Camber_Roll * (camber_act - target_camber_roll_val)^2;
        cost = cost + W.Toe_Roll    * (toe_act - target_toe_roll_val)^2;
    end
end

% %% ========================================================================
% %  ÜTKÖZÉS / CLEARANCE (MULTILINK)
% %  ========================================================================
% function pen = multilink_collision_penalty(C, K, WC, is_left, Col)
% % C, K: 5x3; WC: 1x3; is_left: logical
%     pen = 0;
%     n = 5;
%     radii = Col.rod_diameter(:) / 2;
%     if length(radii) < n
%         radii = [radii; repmat(radii(end), n - length(radii), 1)];
%     end
%     gap = Col.min_clearance;
% 
%     % 1) Rúd–rúd
%     for i = 1:n
%         for j = i+1:n
%             d = segment_segment_distance(C(i,:), K(i,:), C(j,:), K(j,:));
%             need = radii(i) + radii(j) + gap;
%             if d < need
%                 pen = max(pen, need - d);
%             end
%         end
%     end
% 
%     % % 2) Rúd–motor (AABB)
%     % mc = Col.motor_center(:);
%     % ms = Col.motor_size(:);
%     % box_min = mc - ms/2;
%     % box_max = mc + ms/2;
%     % for i = 1:n
%     %     d = segment_aabb_distance(C(i,:), K(i,:), box_min, box_max);
%     %     need = radii(i) + gap;
%     %     if d < need
%     %         pen = max(pen, need - d);
%     %     end
%     % end
% 
%     % 2) Rúd–motor (Henger)
%     mc = Col.motor_center(:);
%     m_axis = Col.motor_axis(:);
%     for i = 1:n
%         % Hívjuk a már meglévő henger-távolság függvényt
%         d = segment_finite_cylinder_distance(C(i,:), K(i,:), ...
%             mc, m_axis, Col.motor_radius, Col.motor_length);
% 
%         need = radii(i) + gap;
%         if d < need
%             pen = max(pen, need - d);
%         end
%     end
% 
%     % 3) Rúd–felni
%     wc = WC(:);
%     if is_left
%         axis_dir = [0; 1; 0];
%         rim_center = wc + [0; -Col.rim_y_offset; 0];
%     else
%         axis_dir = [0; -1; 0];
%         rim_center = wc + [0; Col.rim_y_offset; 0];
%     end
%     for i = 1:n
%         d = segment_finite_cylinder_distance(C(i,:), K(i,:), ...
%             rim_center, axis_dir, Col.rim_inner_radius, Col.rim_width);
%         need = radii(i) + gap;
%         if d < need
%             pen = max(pen, need - d);
%         end
%     end
% end
% 
% function d = segment_segment_distance(p1, q1, p2, q2)
%     p1 = p1(:); q1 = q1(:); p2 = p2(:); q2 = q2(:);
%     u = q1 - p1; v = q2 - p2; w0 = p1 - p2;
%     a = dot(u,u); b = dot(u,v); c = dot(v,v);
%     d_ = dot(u,w0); e = dot(v,w0);
%     D = a*c - b*b;
%     if D < 1e-12
%         sc = 0;
%         tc = 0; if c > 1e-12, tc = e/c; end
%     else
%         sc = (b*e - c*d_) / D;
%         tc = (a*e - b*d_) / D;
%     end
%     sc = min(1, max(0, sc));
%     tc = min(1, max(0, tc));
%     d = norm(w0 + sc*u - tc*v);
% end
% 
% function d = segment_aabb_distance(p0, p1, box_min, box_max)
%     p0 = p0(:); p1 = p1(:); box_min = box_min(:); box_max = box_max(:);
%     n = 20; d = inf;
%     for i = 0:n
%         t = i/n;
%         p = p0 + t*(p1-p0);
%         q = min(max(p, box_min), box_max);
%         d = min(d, norm(p - q));
%     end
% end
% 
% function d = segment_finite_cylinder_distance(p0, p1, c_center, c_axis, radius, height)
%     p0 = p0(:); p1 = p1(:); c_center = c_center(:); c_axis = c_axis(:);
%     c_axis = c_axis / (norm(c_axis) + 1e-15);
%     n = 24; d = inf; half_h = height / 2;
%     for i = 0:n
%         t = i/n;
%         p = p0 + t*(p1-p0);
%         w = p - c_center;
%         axial = dot(w, c_axis);
%         radial_vec = w - axial * c_axis;
%         radial = norm(radial_vec);
%         if abs(axial) <= half_h
%             d = min(d, max(0, radial - radius));
%         else
%             if radial <= radius
%                 d = min(d, abs(axial) - half_h);
%             else
%                 d = min(d, norm([radial - radius; abs(axial) - half_h]));
%             end
%         end
%     end
% end

%% ========================================================================
%  ROLL CENTER (RC_Z) SZÁMÍTÁSA
%  ========================================================================
function [rc_z, valid, side_ic, cp_out] = calculate_RC_Z(C_curr, K_curr, WC_init, dz)
    side_ic = [NaN, NaN, NaN]; cp_out = [NaN, NaN, NaN];   % side view IC és CP (világ), anti-squat-hoz
    opt_inner = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-10);
    L0 = zeros(5,1); for i=1:5, L0(i) = norm(K_curr(i,:) - C_curr(i,:)); end
    K_loc = K_curr - WC_init;
    
    rc_steps = [-1, 0, 1]; K_hist = zeros(3, 5, 3); WC_hist = zeros(3, 3);
    q0 = [WC_init(1), WC_init(2), 0, 0, 0]; cp_y = 0; cp_z = 0; cp_x = 0;
    valid = true;
    
    for idx = 1:3
        C_moved = C_curr; 
        C_moved(:,3) = C_curr(:,3) - dz - rc_steps(idx);
        obj_inner = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
        if exitflag <= 0, valid = false; rc_z = NaN; return; end
        q0 = q_opt;
        
        WC_new = [q_opt(1), q_opt(2), WC_init(3)];
        R_mat  = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
        for i = 1:5, K_hist(idx, i, :) = (WC_new' + R_mat * K_loc(i,:)')'; end
        WC_hist(idx, :) = WC_new;
        
        if idx == 2 
            wheel_normal = R_mat * [0; 1; 0];
            unit_normal = wheel_normal / norm(wheel_normal);
            proj_grav = [0;0;-1] - dot([0;0;-1], unit_normal) * unit_normal;
            down_dir = proj_grav / norm(proj_grav);
            t_gnd = (0 - WC_new(3)) / down_dir(3);
            cp = WC_new' + t_gnd * down_dir;
            cp_x = cp(1); cp_y = cp(2); cp_z = cp(3);
        end
    end
    
    A_0 = squeeze(K_hist(2,:,:)); A0 = A_0 - mean(A_0, 1);
    B_m = squeeze(K_hist(1,:,:)); B0_m = B_m - mean(B_m, 1);
    [U_m, ~, V_m] = svd(A0' * B0_m); R_m = V_m * U_m';
    if det(R_m) < 0, V_m(:,3) = -V_m(:,3); R_m = V_m * U_m'; end
    
    B_p = squeeze(K_hist(3,:,:)); B0_p = B_p - mean(B_p, 1);
    [U_p, ~, V_p] = svd(A0' * B0_p); R_p = V_p * U_p';
    if det(R_p) < 0, V_p(:,3) = -V_p(:,3); R_p = V_p * U_p'; end
    
    R_delta = R_p * R_m';
    w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
    w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
    w_z = (R_delta(2,1) - R_delta(1,2)) / 2;
    
    v_11 = (WC_hist(3, :) + [0, 0, 1]) - (WC_hist(1, :) + [0, 0, -1]);
    p11_c = WC_hist(2, :);
    
    if abs(w_x) > 1e-10
        y_ic = p11_c(2) + (-v_11(3) + w_y * (cp_x - p11_c(1))) / w_x;
        z_ic = p11_c(3) + ( v_11(2) + w_z * (cp_x - p11_c(1))) / w_x;
        m_rc = (z_ic - cp_z) / (y_ic - cp_y);
    else
        m_rc = (abs(v_11(3)) > 1e-10) * (-v_11(2) / (v_11(3) + 1e-15));
    end
    
    rc_z = cp_z - m_rc * cp_y;

    % Side View IC (XZ sík, y = cp_y): v_x = 0 és v_z = 0
    if abs(w_y) > 1e-10
        x_ic_s = p11_c(1) + ( v_11(3) + w_x * (cp_y - p11_c(2))) / w_y;
        z_ic_s = p11_c(3) + (-v_11(1) + w_z * (cp_y - p11_c(2))) / w_y;
        side_ic = [x_ic_s, cp_y, z_ic_s];
    else
        side_ic = [Inf, cp_y, Inf];   % IC a végtelenben
    end
    cp_out = [cp_x, cp_y, cp_z];
end

%% ========================================================================
%  KINEMATIKAI SZIMULÁCIÓ (SWEEPS A PLOTOLÁSHOZ)
%  ========================================================================
function res = run_kinematics_sweep(C, K, WC_init, dz_vec, dy_vec, droll_vec, Vehicle)
    opt_inner = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-10);
    K_loc = K - WC_init;
    L0 = zeros(5,1); for i = 1:5, L0(i) = norm(K(i,:) - C(i,:)); end
    
    % 1. RUGÓÚT SWEEP (X = Wheel Travel Z)
    res.Camber = zeros(size(dz_vec)); res.Toe = zeros(size(dz_vec)); res.RC_Z = zeros(size(dz_vec));
    res.KPI = nan(size(dz_vec)); res.Caster = nan(size(dz_vec));
    res.Trail = nan(size(dz_vec)); res.Scrub = nan(size(dz_vec));
    res.AntiSquat = nan(size(dz_vec)); res.Phi_R = nan(size(dz_vec));
    q0 = [WC_init(1), WC_init(2), 0, 0, 0];
    for k = 1:length(dz_vec)
        dz = dz_vec(k);
        C_moved = C; C_moved(:,3) = C(:,3) - dz;
        
        obj_inner = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
        
        if exitflag > 0
            q0 = q_opt;
            R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
            wheel_normal = R_mat * [0; 1; 0];
            res.Camber(k) = -atand(wheel_normal(3) / wheel_normal(2));
            res.Toe(k)    = -atand(wheel_normal(1) / wheel_normal(2));
            
            [rc_val, rc_valid, side_ic_k, cp_k] = calculate_RC_Z(C, K, WC_init, dz);
            if rc_valid, res.RC_Z(k) = rc_val; else, res.RC_Z(k) = NaN; end
            if rc_valid
                [res.AntiSquat(k), res.Phi_R(k)] = calc_anti_squat(side_ic_k, cp_k, dz, Vehicle);
            end

            % KPI, Caster, Trail, Scrub a rugóút függvényében
            [res.KPI(k), res.Caster(k), res.Scrub(k), res.Trail(k)] = calc_steer_axis_params(C_moved, q_opt, K_loc, WC_init);
        end
    end
    
    % 2. KORMÁNYMŰ SWEEP (X = Steer Rack Y) -> csak Ackermann; SteerRange = 0 esetén kimarad
    res.Ackermann = nan(size(dy_vec));
    if Vehicle.SteerRange > 0
        q0_L = [WC_init(1), WC_init(2), 0, 0, 0];
        WC_init_R = WC_init; WC_init_R(2) = -WC_init(2);
        C_R = C; C_R(:,2) = -C(:,2);
        K_R = K; K_R(:,2) = -K(:,2);
        K_loc_R = K_R - WC_init_R;
        q0_R = [WC_init_R(1), WC_init_R(2), 0, 0, 0];

        for k = 1:length(dy_vec)
            dy = dy_vec(k);

            C_steer_L = C; C_steer_L(5,2) = C(5,2) + dy;
            obj_inner_L = @(q) calc_link_errors(q, C_steer_L, K_loc, WC_init, 0, L0);
            [q_opt_L, ~, ~, exitflag_L] = lsqnonlin(obj_inner_L, q0_L, [], [], opt_inner);

            C_steer_R = C_R; C_steer_R(5,2) = C_R(5,2) + dy;
            obj_inner_R = @(q) calc_link_errors(q, C_steer_R, K_loc_R, WC_init_R, 0, L0);
            [q_opt_R, ~, ~, exitflag_R] = lsqnonlin(obj_inner_R, q0_R, [], [], opt_inner);

            if exitflag_L > 0 && exitflag_R > 0
                q0_L = q_opt_L; q0_R = q_opt_R;

                R_mat_L = euler_to_rot(q_opt_L(3), q_opt_L(4), q_opt_L(5));
                wheel_normal_L = R_mat_L * [0; 1; 0];
                delta_L = -atand(wheel_normal_L(1) / wheel_normal_L(2));

                R_mat_R = euler_to_rot(q_opt_R(3), q_opt_R(4), q_opt_R(5));
                wheel_normal_R = R_mat_R * [0; 1; 0];
                delta_R = -atand(wheel_normal_R(1) / wheel_normal_R(2));

                if abs(dy) < 1e-4
                    res.Ackermann(k) = 100;
                else
                    if abs(delta_L) > abs(delta_R)
                        delta_in = abs(delta_L); delta_out = abs(delta_R);
                    else
                        delta_in = abs(delta_R); delta_out = abs(delta_L);
                    end

                    L_wb = Vehicle.Wheelbase; W_tr = Vehicle.Trackwidth;
                    delta_out_rad = deg2rad(delta_out);
                    ideal_ackermann_rad = atan(L_wb / ((L_wb / tan(delta_out_rad)) - W_tr));
                    res.Ackermann(k) = (delta_in / rad2deg(ideal_ackermann_rad)) * 100;
                end
            end
        end
    end

    % % 3. DŐLÉS SWEEP (X = Chassis Roll)
    % res.Camber_roll = zeros(size(droll_vec));
    % res.Toe_roll    = zeros(size(droll_vec));
    % q0_roll = [WC_init(1), WC_init(2), 0, 0, 0];
    % 
    % for k = 1:length(droll_vec)
    %     droll = droll_vec(k);
    %     R_roll = euler_to_rot(deg2rad(droll), 0, 0);
    %     C_rolled = (R_roll * C')';
    % 
    %     obj_inner = @(q) calc_link_errors(q, C_rolled, K_loc, WC_init, 0, L0);
    %     [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0_roll, [], [], opt_inner);
    % 
    %     if exitflag > 0
    %         q0_roll = q_opt;
    %         R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
    %         wheel_normal = R_mat * [0; 1; 0];
    %         res.Camber_roll(k) = atand(wheel_normal(3) / wheel_normal(2));
    %         res.Toe_roll(k)    = -atand(wheel_normal(1) / wheel_normal(2));
    %     end
    % end

    % 3. DŐLÉS SWEEP (X = Chassis Roll)
    res.Camber_roll = zeros(size(droll_vec));
    res.Toe_roll    = zeros(size(droll_vec));
    q0_roll = [WC_init(1), WC_init(2), 0, 0, 0];

    % Pure heave RC a design pozícióban → pivot
    [rc_z_pivot, rc_valid] = calculate_RC_Z(C, K, WC_init, 0);
    if ~rc_valid
        rc_z_pivot = 50;
    end
    pivot = [0; 0; rc_z_pivot];

    for k = 1:length(droll_vec)
        droll = droll_vec(k);
        r_rad = deg2rad(droll);
        R_roll = [1 0 0; 
            0 cos(r_rad) -sin(r_rad); 
            0 sin(r_rad)  cos(r_rad)];

        C_rolled = zeros(5,3);
        for i = 1:5
            C_rolled(i,:) = (R_roll * (C(i,:)' - pivot) + pivot)';
        end

        obj_inner = @(q) calc_link_errors(q, C_rolled, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0_roll, [], [], opt_inner);

        if exitflag > 0
            q0_roll = q_opt;
            R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
            wheel_normal = R_mat * [0; 1; 0];

            res.Camber_roll(k) = -atand(wheel_normal(3) / wheel_normal(2));
            res.Toe_roll(k)    = -atand(wheel_normal(1) / wheel_normal(2));
        end
    end
end

%% ========================================================================
%  SEGÉDFÜGGVÉNYEK
%  ========================================================================
%% ========================================================================
%  ANTI-SQUAT (hátsó tengely, gyorsítás) – a base_program anti-dive képletének hátsó párja
%  anti_squat [%] = ( W * tan(Phi_R) * (%hajtás_hátul/100) / h_CG,SM ) * 100
%  Phi_R = a talaj és a (Contact Patch -> Side IC) egyenes szöge (side view, X előre).
%  Hátsó tengelynél az IC tipikusan a CP ELŐTT (dx > 0) és FELETT (dz > 0) van
%  -> tan(Phi_R) > 0 -> pozitív anti-squat (az anti-dive-hoz képest nincs előjelfordítás).
%  h_CG,SM a vázzal süllyed: statikus érték - aktuális wheel travel (dz).
%  Csak tiszta heave-re értelmezett (dy = 0, roll = 0).
%  ========================================================================
function [anti_squat, phi_R] = calc_anti_squat(side_ic, cp, dz, Vehicle)
    anti_squat = NaN; phi_R = NaN;
    if any(isnan(side_ic)) || any(isnan(cp)), return; end   % kinematika nem oldható

    dx_side = side_ic(1) - cp(1);   % x_IC - x_CP
    dz_side = side_ic(3) - cp(3);   % z_IC - z_CP
    if all(isfinite(side_ic)) && abs(dx_side) > 1.0 && norm(side_ic) < 1e5
        tan_Phi_R = dz_side / dx_side;
    else
        tan_Phi_R = 0;              % párhuzamos / végtelen távoli IC
    end
    phi_R = rad2deg(atan(tan_Phi_R));

    h_CG_current = Vehicle.h_CG_SM - dz;   % vázzal süllyed
    if h_CG_current > 1.0
        anti_squat = (Vehicle.Wheelbase * tan_Phi_R * (Vehicle.RearDrivePercent/100) / h_CG_current) * 100;
    else
        anti_squat = 0;
    end
end

%% ========================================================================
%  KORMÁNYZÁSI TENGELY PARAMÉTEREK (KPI, Caster, Scrub, Trail) – tetszőleges pózban
%  A tie-rod (5. rúd) 'rack' bemenetére számolt pillanatnyi csavartengely (ISA)
%  alapján; C_pos = az adott pózban lévő (elmozgatott) kasszi pontok.
%  ========================================================================
function [kpi, caster, scrub, trail] = calc_steer_axis_params(C_pos, q_sol, K_loc, WC_init)
    kpi = NaN; caster = NaN; scrub = NaN; trail = NaN;

    R_mat = euler_to_rot(q_sol(3), q_sol(4), q_sol(5));
    wheel_normal = R_mat * [0; 1; 0];
    delta_deg = -atand(wheel_normal(1) / wheel_normal(2));

    WC_new = [q_sol(1), q_sol(2), WC_init(3)];
    K_new = zeros(5,3);
    for i = 1:5, K_new(i,:) = (WC_new' + R_mat * K_loc(i,:)')'; end

    J = zeros(6,6);
    for i = 1:5
        vec_link = K_new(i,:) - C_pos(i,:);
        vec_r    = K_new(i,:) - WC_new;
        J(i,1:3) = vec_link; J(i,4:6) = cross(vec_r, vec_link);
    end
    J(6,:) = [0 0 1 0 0 0];

    twist_vector = J \ [0;0;0;0;10;0];
    v_WC  = twist_vector(1:3); omega = twist_vector(4:6);
    omega_norm = norm(omega);
    if omega_norm <= 1e-8
        kpi = 0; caster = 0; scrub = 0; trail = 0;
        return;
    end

    U_vec = omega / omega_norm;
    if U_vec(3) < 0, U_vec = -U_vec; omega = -omega; v_WC = -v_WC; end

    kpi    = atand(-U_vec(2) / U_vec(3));
    caster = atand(-U_vec(1) / U_vec(3));

    unit_normal = wheel_normal / norm(wheel_normal);
    proj_grav   = [0;0;-1] - dot([0;0;-1], unit_normal) * unit_normal;
    down_dir = proj_grav / norm(proj_grav);
    t_gnd = (0 - WC_new(3)) / down_dir(3);
    cp    = WC_new' + t_gnd * down_dir;

    P_isa = WC_new' + cross(omega, v_WC) / (omega_norm^2);
    v_CP_pure = cross(omega, cp - P_isa);
    delta = deg2rad(delta_deg);
    omega_delta = omega(3);

    if abs(omega_delta) > 1e-8
        scrub = -(v_CP_pure(1)*cos(delta) + v_CP_pure(2)*sin(delta)) / omega_delta;
        trail = (v_CP_pure(1)*sin(delta) - v_CP_pure(2)*cos(delta)) / omega_delta;
    else
        scrub = 0; trail = 0;
    end
end

function err = calc_link_errors(q, C_curr, K_loc, WC_init, dz, L0)
    WC_current = [q(1), q(2), WC_init(3) + dz];
    R = euler_to_rot(q(3), q(4), q(5));
    err = zeros(5,1);
    for i = 1:5
        K_current = WC_current' + R * K_loc(i,:)';
        err(i) = norm(K_current' - C_curr(i,:)) - L0(i);
    end
end

function R = euler_to_rot(rx, ry, rz)
    Rx = [1 0 0; 0 cos(rx) -sin(rx); 0 sin(rx) cos(rx)];
    Ry = [cos(ry) 0 sin(ry); 0 1 0; -sin(ry) 0 cos(ry)];
    Rz = [cos(rz) -sin(rz) 0; sin(rz) cos(rz) 0; 0 0 1];
    R = Rz * Ry * Rx;
end

function [x_out, y_out] = get_excel_pts(loaded_data, row_idx, eval_pts)
    x_out = eval_pts(:);
    y_out = zeros(length(eval_pts), 1);
    if ~isempty(loaded_data) && size(loaded_data, 1) >= row_idx && size(loaded_data, 2) >= 22
        for i = 1:length(eval_pts)
            val = loaded_data{row_idx, i+1};
            if isnumeric(val) && ~isnan(val)
                y_out(i) = val;
            end
        end
    end
end

% %% ========================================================================
% %  NONLCON: ÜTKÖZÉSEK SZIGORÚ ELLENŐRZÉSE
% %  ========================================================================
% function [c, ceq] = collision_nonlcon(x, WC_init, Collision)
% ceq = [];
% c = []; % Ebbe gyűjtjük a (szükséges_táv - valós_táv) értékeket. 
% % Ha c > 0, az fmincon tudni fogja, hogy megsértettük a feltételt (c <= 0 a jó).
% 
% C_curr = reshape(x(1:15), [5, 3]);
% K_curr = reshape(x(16:30), [5, 3]);
% L0 = zeros(5,1);
% for i = 1:5, L0(i) = norm(K_curr(i,:) - C_curr(i,:)); end
% K_loc = K_curr - WC_init;
% 
% opt_inner = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-10);
% q0 = [WC_init(1), WC_init(2), 0, 0, 0];
% 
% % 1. Kritikus Heave (Rugóút) pontok ellenőrzése (pl. -30mm és +30mm)
% critical_dz = [-30, 30]; 
% for dz = critical_dz
%     C_moved = C_curr; C_moved(:,3) = C_curr(:,3) - dz;
%     obj_inner = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
%     [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
% 
%     if exitflag > 0
%         R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
%         WC_h = [q_opt(1), q_opt(2), WC_init(3)];
%         K_h = zeros(5,3);
%         for ii = 1:5, K_h(ii,:) = (WC_h' + R_mat * K_loc(ii,:)')'; end
% 
%         % Fűzzük hozzá az ütközési távolságokat a 'c' vektorhoz
%         c = [c; get_collision_distances(C_moved, K_h, WC_h, true, Collision)];
%     end
% end
% 
% % 2. Kritikus Kormányzási pontok (Steer) ellenőrzése (pl. -30mm és +30mm kormánymű)
% critical_dy = [-30, 30];
% for dy = critical_dy
%     C_steer_L = C_curr; C_steer_L(5,2) = C_curr(5,2) + dy;
%     obj_inner = @(q) calc_link_errors(q, C_steer_L, K_loc, WC_init, 0, L0);
%     [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
% 
%     if exitflag > 0
%         R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
%         WC_h = [q_opt(1), q_opt(2), WC_init(3)];
%         K_h = zeros(5,3);
%         for ii = 1:5, K_h(ii,:) = (WC_h' + R_mat * K_loc(ii,:)')'; end
% 
%         c = [c; get_collision_distances(C_steer_L, K_h, WC_h, true, Collision)];
%     end
% end
% end
% 
% function c_vals = get_collision_distances(C, K, WC, is_left, Col)
% c_vals = [];
% n = 5;
% radii = Col.rod_diameter(:) / 2;
% if length(radii) < n
%     radii = [radii; repmat(radii(end), n - length(radii), 1)];
% end
% gap = Col.min_clearance;
% 
% % 1) Rúd-rúd ellenőrzése
% for i = 1:n
%     for j = i+1:n
%         d = segment_segment_distance(C(i,:), K(i,:), C(j,:), K(j,:));
%         need = radii(i) + radii(j) + gap;
%         c_vals(end+1, 1) = need - d; 
%     end
% end
% 
% % 2) Rúd-motor (Henger) ellenőrzése
% mc = Col.motor_center(:);
% m_axis = Col.motor_axis(:);
% for i = 1:n
%     d = segment_finite_cylinder_distance(C(i,:), K(i,:), mc, m_axis, Col.motor_radius, Col.motor_length);
%     need = radii(i) + gap;
%     c_vals(end+1, 1) = need - d;
% end
% 
% % 3) Rúd-felni ellenőrzése
% wc = WC(:);
% if is_left
%     axis_dir = [0; 1; 0];
%     rim_center = wc + [0; -Col.rim_y_offset; 0];
% else
%     axis_dir = [0; -1; 0];
%     rim_center = wc + [0; Col.rim_y_offset; 0];
% end
% for i = 1:n
%     d = segment_finite_cylinder_distance(C(i,:), K(i,:), rim_center, axis_dir, Col.rim_inner_radius, Col.rim_width);
%     need = radii(i) + gap;
%     c_vals(end+1, 1) = need - d;
% end
% end

%% ========================================================================
%  NONLCON: ÜTKÖZÉSEK (DAA-stílus: minden híváskor aktuális x-ből,
%  melegindítás, sikertelen kinematika = nagy sértés, rúd–rúd párok)
%  ========================================================================

%% ========================================================================
%  FEASIBILITY OBJECTIVE (1. fázis): sum(max(0,c).^2)
%  ========================================================================
function f = feasibility_objective(x, WC_init, Collision, F1)
    [c, ~] = total_nonlcon_ML(x, WC_init, Collision, F1);   % ütközés + F1 2026
    if isempty(c)
        f = 0;
    else
        f = sum(max(0, c(:)).^2);
    end
end

% function [c, ceq] = collision_nonlcon(x, WC_init, Collision)
%     ceq = [];
%     c = [];
% 
%     % --- Minden nonlcon-híváskor friss pontok az aktuális x-ből ---
%     C_curr = reshape(x(1:15), [5, 3]);
%     K_curr = reshape(x(16:30), [5, 3]);
%     L0 = zeros(5, 1);
%     for i = 1:5
%         L0(i) = norm(K_curr(i, :) - C_curr(i, :));
%     end
%     K_loc = K_curr - WC_init;   % WC_init rögzített, K_loc az aktuális uprightből
% 
%     opt_inner = optimoptions('lsqnonlin', 'Display', 'off', ...
%         'FunctionTolerance', 1e-10, 'MaxIterations', 80);
%     q0 = [WC_init(1), WC_init(2), 0, 0, 0];
%     n_success = 0;
% 
%     % Heave kritikus pontok: -30 és +30 mm
%     for dz = [-30, 30]
%         C_moved = C_curr;
%         C_moved(:, 3) = C_curr(:, 3) - dz;
%         obj_inner = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
%         [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
%         if exitflag > 0
%             n_success = n_success + 1;
%             q0 = q_opt;   % melegindítás a következő poszhoz
%             R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
%             WC_h = [q_opt(1), q_opt(2), WC_init(3)];
%             K_h = zeros(5, 3);
%             for ii = 1:5
%                 K_h(ii, :) = (WC_h' + R_mat * K_loc(ii, :)')';
%             end
%             unit_normal = R_mat * [0; 1; 0];
%             unit_normal = unit_normal / (norm(unit_normal) + 1e-15);
%             c = [c; get_collision_distances(C_moved, K_h, WC_h, unit_normal, Collision)];
%         end
%     end
% 
%     % Kormányzás kritikus pontok: -steer_range és +steer_range rack (hátsó tengelynél 0 -> kihagyva)
%     q0 = [WC_init(1), WC_init(2), 0, 0, 0];
%     steer_pts = [];
%     if isfield(Collision, 'steer_range') && Collision.steer_range > 0
%         steer_pts = [-Collision.steer_range, Collision.steer_range];
%     end
%     for dy = steer_pts
%         C_steer_L = C_curr;
%         C_steer_L(5, 2) = C_curr(5, 2) + dy;
%         obj_inner = @(q) calc_link_errors(q, C_steer_L, K_loc, WC_init, 0, L0);
%         [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
%         if exitflag > 0
%             n_success = n_success + 1;
%             q0 = q_opt;
%             R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
%             WC_h = [q_opt(1), q_opt(2), WC_init(3)];
%             K_h = zeros(5, 3);
%             for ii = 1:5
%                 K_h(ii, :) = (WC_h' + R_mat * K_loc(ii, :)')';
%             end
%             unit_normal = R_mat * [0; 1; 0];
%             unit_normal = unit_normal / (norm(unit_normal) + 1e-15);
%             c = [c; get_collision_distances(C_steer_L, K_h, WC_h, unit_normal, Collision)];
%         end
%     end
% 
%     % Ha egyetlen kritikus póz sem oldható meg → erős infeasibility jelzés
%     % (üres c-t az fmincon feasible-nek tekintené)
%     if n_success == 0
%         c = 1e3;
%     end
% end
% 
% function c_vals = get_collision_distances(C, K, WC, unit_normal, Col)
%     c_vals = [];
%     n = 5;
%     radii = Col.rod_diameter(:) / 2;
%     if length(radii) < n
%         radii = [radii; repmat(radii(end), n - length(radii), 1)];
%     end
%     gap = Col.min_clearance;
% 
%     % 1) Rúd–rúd
%     %    Közös végpontú párok kihagyása (különben d≈0 → hamis, konstans sértés)
%     for i = 1:n
%         for j = i+1:n
%             share_end = (norm(C(i,:) - C(j,:)) < 1e-6) || (norm(K(i,:) - K(j,:)) < 1e-6) || ...
%                         (norm(C(i,:) - K(j,:)) < 1e-6) || (norm(K(i,:) - C(j,:)) < 1e-6);
%             if share_end
%                 continue;
%             end
%             d = segment_segment_distance(C(i,:), K(i,:), C(j,:), K(j,:));
%             need = radii(i) + radii(j) + gap;
%             c_vals(end+1, 1) = need - d;
%         end
%     end
% 
%     % 2) Rúd–motor (véges henger)
%     % mc = Col.motor_center(:);
%     % m_axis = Col.motor_axis(:);
%     % for i = 1:n
%     %     d = segment_finite_cylinder_distance(C(i,:), K(i,:), mc, m_axis, Col.motor_radius, Col.motor_length);
%     %     need = radii(i) + gap;
%     %     c_vals(end+1, 1) = need - d;
%     % end
%     m_axis = unit_normal(:) / (norm(unit_normal) + 1e-15);
% 
%     % A motor középpontja a kerékközéppontból (WC) van eltolva a tengely mentén
%     mc = WC(:) + Col.motor_y_offset * m_axis;
% 
%     for i = 1:n
%         d = segment_finite_cylinder_distance(C(i,:), K(i,:), mc, m_axis, Col.motor_radius, Col.motor_length);
%         need = radii(i) + gap;
%         c_vals(end+1, 1) = need - d;
%     end
% 
%     % 3) Rúd–felni (gyűrű, tényleges unit_normal)
%     wc = WC(:);
%     rim_axis = unit_normal(:) / (norm(unit_normal) + 1e-15);
%     rim_center = wc + Col.rim_y_offset * rim_axis;
%     r_inner = Col.rim_inner_radius;
%     r_outer = Col.rim_outer_radius;
%     half_w  = Col.rim_width / 2;
%     for i = 1:n
%         d = segment_rim_annulus_distance(C(i,:), K(i,:), rim_center, rim_axis, r_inner, r_outer, half_w);
%         need = radii(i) + gap;
%         c_vals(end+1, 1) = need - d;
%     end
% end

function [c, ceq] = collision_nonlcon(x, WC_init, Collision)
    ceq = [];
    c = [];

    C_curr = reshape(x(1:15), [5, 3]);
    K_curr = reshape(x(16:30), [5, 3]);
    L0 = zeros(5, 1);
    for i = 1:5
        L0(i) = norm(K_curr(i, :) - C_curr(i, :));
    end
    K_loc = K_curr - WC_init;

    opt_inner = optimoptions('lsqnonlin', 'Display', 'off', ...
        'FunctionTolerance', 1e-10, 'MaxIterations', 80);

    % --- Heave kritikus pontok ---
    q0 = [WC_init(1), WC_init(2), 0, 0, 0];
    for dz = [-30, 30]
        C_moved = C_curr;
        C_moved(:, 3) = C_curr(:, 3) - dz;
        obj_inner = @(q) calc_link_errors(q, C_moved, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
        
        if exitflag > 0
            q0 = q_opt;
            R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
            WC_h = [q_opt(1), q_opt(2), WC_init(3)];
            K_h = zeros(5, 3);
            for ii = 1:5
                K_h(ii, :) = (WC_h' + R_mat * K_loc(ii, :)')';
            end
            unit_normal = R_mat * Collision.wheel_axis0(:);   % F1: legality camber
            unit_normal = unit_normal / (norm(unit_normal) + 1e-15);
            c = [c; get_collision_distances(C_moved, K_h, WC_h, unit_normal, Collision)];
        else
            % HA SIKERTELEN: Fix méretű (20 db) büntetés, hogy a c mérete ne változzon
            c = [c; 1000 * ones(20, 1)]; 
        end
    end

    % --- Kormányzás kritikus pontok ---
    q0 = [WC_init(1), WC_init(2), 0, 0, 0];
    steer_pts = [];
    if isfield(Collision, 'steer_range') && Collision.steer_range > 0
        steer_pts = [-Collision.steer_range, Collision.steer_range];
    end
    for dy = steer_pts
        C_steer_L = C_curr;
        C_steer_L(5, 2) = C_curr(5, 2) + dy;
        obj_inner = @(q) calc_link_errors(q, C_steer_L, K_loc, WC_init, 0, L0);
        [q_opt, ~, ~, exitflag] = lsqnonlin(obj_inner, q0, [], [], opt_inner);
        
        if exitflag > 0
            q0 = q_opt;
            R_mat = euler_to_rot(q_opt(3), q_opt(4), q_opt(5));
            WC_h = [q_opt(1), q_opt(2), WC_init(3)];
            K_h = zeros(5, 3);
            for ii = 1:5
                K_h(ii, :) = (WC_h' + R_mat * K_loc(ii, :)')';
            end
            unit_normal = R_mat * Collision.wheel_axis0(:);   % F1: legality camber
            unit_normal = unit_normal / (norm(unit_normal) + 1e-15);
            c = [c; get_collision_distances(C_steer_L, K_h, WC_h, unit_normal, Collision)];
        else
            % HA SIKERTELEN: Fix méretű (20 db) büntetés
            c = [c; 1000 * ones(20, 1)]; 
        end
    end
end

function c_vals = get_collision_distances(C, K, WC, unit_normal, Col)
    c_vals = zeros(20, 1); % Fix méret lefoglalása: 10 + 5 + 5 elem
    idx = 1;
    n = 5;
    radii = Col.rod_diameter(:) / 2;
    if length(radii) < n
        radii = [radii; repmat(radii(end), n - length(radii), 1)];
    end
    gap = Col.min_clearance;

    % 1) Rúd–rúd
    for i = 1:n
        for j = i+1:n
            share_end = (norm(C(i,:) - C(j,:)) < 1e-6) || (norm(K(i,:) - K(j,:)) < 1e-6) || ...
                        (norm(C(i,:) - K(j,:)) < 1e-6) || (norm(K(i,:) - C(j,:)) < 1e-6);
            if share_end
                % Kód kihagyása helyett negatív (azaz biztonságos) értéket adunk
                c_vals(idx) = -100;
            else
                d = segment_segment_distance(C(i,:), K(i,:), C(j,:), K(j,:));
                need = radii(i) + radii(j) + gap;
                c_vals(idx) = need - d;
            end
            idx = idx + 1;
        end
    end

    % 2) Rúd–motor  (F1: nincs agymotor -> biztonságos, fix méretű sorok)
    m_axis = unit_normal(:) / (norm(unit_normal) + 1e-15);
    mc = WC(:) + Col.motor_y_offset * m_axis;
    for i = 1:n
        if isfield(Col, 'use_motor') && ~Col.use_motor
            c_vals(idx) = -100; idx = idx + 1; continue;
        end
        d = segment_finite_cylinder_distance(C(i,:), K(i,:), mc, m_axis, Col.motor_radius, Col.motor_length);
        need = radii(i) + gap;
        c_vals(idx) = need - d;
        idx = idx + 1;
    end

    % 3) Rúd–felni
    wc = WC(:);
    rim_axis = unit_normal(:) / (norm(unit_normal) + 1e-15);
    rim_center = wc + Col.rim_y_offset * rim_axis;
    r_inner = Col.rim_inner_radius;
    r_outer = Col.rim_outer_radius;
    half_w  = Col.rim_width / 2;
    for i = 1:n
        d = segment_rim_annulus_distance(C(i,:), K(i,:), rim_center, rim_axis, r_inner, r_outer, half_w);
        need = radii(i) + gap;
        c_vals(idx) = need - d;
        idx = idx + 1;
    end
end

function d = segment_segment_distance(p1, q1, p2, q2)
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

% function d = segment_finite_cylinder_distance(p0, p1, c_center, c_axis, radius, height)
%     p0 = p0(:); p1 = p1(:); c_center = c_center(:); c_axis = c_axis(:);
%     c_axis = c_axis / (norm(c_axis) + 1e-15);
%     n = 24; d = inf; half_h = height / 2;
%     for i = 0:n
%         t = i/n; p = p0 + t*(p1-p0);
%         w = p - c_center;
%         axial = dot(w, c_axis);
%         radial = norm(w - axial * c_axis);
%         if abs(axial) <= half_h
%             d = min(d, max(0, radial - radius));
%         else
%             if radial <= radius
%                 d = min(d, abs(axial) - half_h);
%             else
%                 d = min(d, norm([radial - radius; abs(axial) - half_h]));
%             end
%         end
%     end
% end

function d = segment_finite_cylinder_distance(p0, p1, c_center, c_axis, radius, height)
% Előjeles távolság: d > 0 kívül, d < 0 belül (penetration).
    p0 = p0(:); p1 = p1(:); c_center = c_center(:); c_axis = c_axis(:);
    c_axis = c_axis / (norm(c_axis) + 1e-15);
    n = 24; d = inf; half_h = height / 2;
    for i = 0:n
        t = i/n; p = p0 + t*(p1-p0);
        w = p - c_center;
        axial = dot(w, c_axis);
        radial = norm(w - axial * c_axis);
        if abs(axial) <= half_h
            d = min(d, radial - radius);   % lehet negatív!
        else
            da = abs(axial) - half_h;
            dr = radial - radius;
            if dr <= 0
                d = min(d, da);
            elseif da <= 0
                d = min(d, dr);
            else
                d = min(d, norm([dr; da]));
            end
        end
    end
end

% function d = segment_rim_annulus_distance(p0, p1, rim_center, rim_axis, r_inner, r_outer, half_w)
%     p0 = p0(:); p1 = p1(:);
%     rim_center = rim_center(:);
%     rim_axis = rim_axis(:) / (norm(rim_axis) + 1e-15);
%     n_samples = 24; d = inf;
%     for k = 0:n_samples
%         t = k / n_samples;
%         pt = p0 + t * (p1 - p0);
%         w = pt - rim_center;
%         axial = dot(w, rim_axis);
%         radial = norm(w - axial * rim_axis);
%         if abs(axial) <= half_w
%             if radial < r_inner
%                 d_pt = r_inner - radial;
%             elseif radial > r_outer
%                 d_pt = radial - r_outer;
%             else
%                 d_pt = 0;
%             end
%             d = min(d, d_pt);
%         end
%     end
%     if isinf(d), d = 1e6; end
% end

function d = segment_rim_annulus_distance(p0, p1, rim_center, rim_axis, r_inner, r_outer, half_w)
% Előjeles: d < 0 a gyűrű anyagában
p0 = p0(:); p1 = p1(:);
rim_center = rim_center(:);
rim_axis = rim_axis(:) / (norm(rim_axis) + 1e-15);
n_samples = 24; d = inf;
for k = 0:n_samples
    t = k / n_samples;
    pt = p0 + t * (p1 - p0);
    w = pt - rim_center;
    axial = dot(w, rim_axis);
    radial = norm(w - axial * rim_axis);
    if abs(axial) <= half_w
        if radial < r_inner
            d_pt = r_inner - radial;
        elseif radial > r_outer
            d_pt = radial - r_outer;
        else
            d_pt = -min(radial - r_inner, r_outer - radial);  % negatív penetration
        end
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

%% ---------------- F1 – multilink specifikus kényszerek ----------------

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

function [c, ceq] = total_nonlcon_ML(x, WC_init, Collision, F1)
% Eredeti ütközés-kényszerek + F1 2026 kényszerek.
    [c1, ceq1] = collision_nonlcon(x, WC_init, Collision);
    [c2, ceq2] = f1_nonlcon_ML(x, WC_init, F1, Collision);
    c = [c1(:); c2(:)]; ceq = [ceq1(:); ceq2(:)];
end
