function base_program_front_double_A_arm_both_sides
% =========================================================================
% Double A-arm (bal + jobb) + Heave + Steer + Roll
% Kinematika: base_program_front_left.m
% Camber/Toe/KPI/Caster/Trail/Scrub/CP/IC/RC: 1:1 base logika
% Struktúra: front4 (mindkét oldal + roll a pure-heave RC körül)
% + Rocker / pushrod / damper Excelből (mint a DAA_Rear-ben) – nincs hardcode
% + Stabilizátor: U-bar vagy Z-bar (Excelből), a megoldott rocker-állásból utólag számolva
% + Tengelyhatárok a felfüggesztés helyzetéből (nincs hardcode)
% =========================================================================

    % clc; clear all; close all;

    %% 0. BEMENETI FÁJLOK / BEÁLLÍTÁSOK
    input_excel_file  = 'DAA_Points_Front.xlsx';        % lengőkar / csonkállvány / tie rod pontok
    input_sheet       = '';                             % '' = első munkalap   (template: 'DAA_Points')
    rocker_excel_file = 'Optim_Rocker_DAA_Front.xlsx';  % rocker pontok: Name | X | Y | Z
    rocker_sheet      = '';                             % (template: 'Rocker')
    % Ha a rocker pontok ugyanabban az Excelben vannak, mint a többi pont: rocker_excel_file = '';
    arb_type          = 'U';                            % 'none' | 'U' | 'Z'
    arb_excel_file    = 'Suspension_Template';                             % '' = ugyanaz a fájl/lap, mint a rocker
    arb_sheet         = 'ARB_U';                             % (template: 'ARB_U' vagy 'ARB_Z')

    %% 1. Pontok definiálása – Excelből olvasás (lengőkarok + rocker + ARB)
    T_in = read_pts_table(input_excel_file, input_sheet);
    [rocker_excel_file, rocker_sheet] = resolve_src(rocker_excel_file, rocker_sheet, input_excel_file, input_sheet);
    T_rock = read_pts_table(rocker_excel_file, rocker_sheet);
    rk_xls = load_rocker(T_rock);
    [arb_excel_file, arb_sheet] = resolve_src(arb_excel_file, arb_sheet, rocker_excel_file, rocker_sheet);
    arb = load_arb(arb_type, arb_excel_file, arb_sheet);
    has_arb = arb.has;
    
    % === Excelből beolvasott pontok ===
    upper_fore_chassis   = get_pt(T_in, 'Upper Fore Chassis');
    upper_aft_chassis    = get_pt(T_in, 'Upper Aft Chassis');
    lower_fore_chassis   = get_pt(T_in, 'Lower Fore Chassis');
    lower_aft_chassis    = get_pt(T_in, 'Lower Aft Chassis');
    tie_rod_rack         = get_pt(T_in, 'Tie Rod Rack');
    upper_upright        = get_pt(T_in, 'Upper Upright');
    lower_upright        = get_pt(T_in, 'Lower Upright');
    tie_rod_upright      = get_pt(T_in, 'Tie Rod Upright');
    wheel_center         = get_pt(T_in, 'Wheel Center');
    
    % === Struct tömb feltöltése ===
    points_L = struct('name', {}, 'pos', {}, 'fixed', {});
    
    % 1 – Felső lengőkar elülső (váz)
    points_L(1).name  = 'Front left upper arm fore';
    points_L(1).pos   = upper_fore_chassis;
    points_L(1).fixed = true;
    
    % 2 – Felső lengőkar hátulsó (váz)
    points_L(2).name  = 'Front left upper arm aft';
    points_L(2).pos   = upper_aft_chassis;
    points_L(2).fixed = true;
    
    % 3 – Felső lengőkar csonkállvány
    points_L(3).name  = 'Front left upper arm upright';
    points_L(3).pos   = upper_upright;
    points_L(3).fixed = false;
    
    % 4 – Alsó lengőkar elülső (váz)
    points_L(4).name  = 'Front left lower arm fore';
    points_L(4).pos   = lower_fore_chassis;
    points_L(4).fixed = true;
    
    % 5 – Alsó lengőkar hátulsó (váz)
    points_L(5).name  = 'Front left lower arm aft';
    points_L(5).pos   = lower_aft_chassis;
    points_L(5).fixed = true;
    
    % 6 – Alsó lengőkar csonkállvány
    points_L(6).name  = 'Front left lower arm upright';
    points_L(6).pos   = lower_upright;
    points_L(6).fixed = false;
    
    % 7 – Kormányösszekötő fogasléc oldala
    points_L(7).name  = 'Front left tie rod rack';
    points_L(7).pos   = tie_rod_rack;
    points_L(7).fixed = false;
    
    % 8 – Kormányösszekötő csonkállvány oldala
    points_L(8).name  = 'Front left tie rod upright';
    points_L(8).pos   = tie_rod_upright;
    points_L(8).fixed = false;
    
    % 9 – Pushrod rocker oldala (Excel: Pushrod Rocker)
    points_L(9).name  = 'Front left pushrod rocker';
    points_L(9).pos   = rk_xls.push_rocker;
    points_L(9).fixed = false;
    
    % 10 – Pushrod csonkállvány oldala (Excel: Pushrod Upright)
    points_L(10).name = 'Front left pushrod upright';
    points_L(10).pos  = rk_xls.push_upright;
    points_L(10).fixed = false;
    
    % 11 – Rocker tengely vázoldali pontja (Excel: Rocker Axis)
    points_L(11).name  = 'Front left rocker pivot lower';
    points_L(11).pos   = rk_xls.axis;
    points_L(11).fixed = true;
    
    % 12 – Rocker tengely center (Excel: Rocker Center)
    points_L(12).name  = 'Front left rocker pivot center';
    points_L(12).pos   = rk_xls.center;
    points_L(12).fixed = true;
    
    % 13 – Damper rocker oldala (Excel: Damper Rocker)
    points_L(13).name = 'Front left damper rocker';
    points_L(13).pos  = rk_xls.damper_rocker;
    points_L(13).fixed = false;
    
    % 14 – Damper váz oldal (Excel: Damper Chassis)
    points_L(14).name = 'Front left damper chassis';
    points_L(14).pos  = rk_xls.damper_chassis;
    points_L(14).fixed = true;
    
    % 15 – Kerék középpont
    points_L(15).name  = 'Front left wheel center';
    points_L(15).pos   = wheel_center;
    points_L(15).fixed = false;
    
    % 16–18 (ARB) már nem része a szolvernek: U/Z-bar utófeldolgozásban (load_arb / solve_arb_state)
    n_pts = numel(points_L);   % 15

    
    points_R = points_L;
    for i = 1:length(points_R)
        points_R(i).name = strrep(points_L(i).name, 'FL', 'FR');
        points_R(i).pos(2) = -points_L(i).pos(2);
        points_R(i).fixed  = points_L(i).fixed;
    end

    wheel_radius = 193;

    %% 2–3. Távolságok + kényszerek (base)
    dist_L = compute_distances(points_L);
    dist_R = compute_distances(points_R);
    constraints_L = build_constraints(dist_L);
    constraints_R = build_constraints(dist_R);

    free_indices = find(~[points_L.fixed]);
    initial_x7_L = points_L(7).pos(1);
    initial_x7_R = points_R(7).pos(1);

    %% 4. Statikus megoldás
    opts_static = optimoptions('lsqnonlin', 'Display', 'off', ...
        'MaxIterations', 5000, 'StepTolerance', 1e-20, 'FunctionTolerance', 1e-20);

    x_init_L = [];
    for i = free_indices, x_init_L = [x_init_L, points_L(i).pos]; end
    [x_sol_L, resL] = lsqnonlin(@(x) compute_all_residuals(x, points_L, constraints_L, free_indices), x_init_L, [], [], opts_static);
    k = 1; for i = free_indices, points_L(i).pos = x_sol_L(k:k+2); k = k+3; end

    x_init_R = [];
    for i = free_indices, x_init_R = [x_init_R, points_R(i).pos]; end
    [x_sol_R, resR] = lsqnonlin(@(x) compute_all_residuals(x, points_R, constraints_R, free_indices), x_init_R, [], [], opts_static);
    k = 1; for i = free_indices, points_R(i).pos = x_sol_R(k:k+2); k = k+3; end

    fprintf('Static residual L: %.3e   R: %.3e\n', resL, resR);

    original_points_L = points_L;
    original_points_R = points_R;

    %% 5. Sweep tartományok
    wheel_travel_range = -30:5:30;
    steering_range     = -30:10:30;
    roll_range         = -2:0.5:2;

    num_z    = length(wheel_travel_range);
    num_r    = length(steering_range);
    num_roll = length(roll_range);

    zero_wheel = find(wheel_travel_range == 0, 1);
    zero_steer = find(steering_range == 0, 1);
    zero_roll  = find(roll_range == 0, 1);

    %% 6. History
    pos_hist_L = zeros(n_pts, 3, num_z, num_r, num_roll);
    pos_hist_R = zeros(n_pts, 3, num_z, num_r, num_roll);

    camber_L = zeros(num_z,num_r,num_roll); toe_L = zeros(num_z,num_r,num_roll);
    camber_R = zeros(num_z,num_r,num_roll); toe_R = zeros(num_z,num_r,num_roll);
    trail_L  = zeros(num_z,num_r,num_roll); scrub_L = zeros(num_z,num_r,num_roll);
    trail_R  = zeros(num_z,num_r,num_roll); scrub_R = zeros(num_z,num_r,num_roll);
    caster_L = zeros(num_z,num_r,num_roll); kpi_L   = zeros(num_z,num_r,num_roll);
    caster_R = zeros(num_z,num_r,num_roll); kpi_R   = zeros(num_z,num_r,num_roll);

    cp_L = zeros(num_z,num_r,num_roll,3); cp_R = zeros(num_z,num_r,num_roll,3);
    fic_L = zeros(num_z,num_r,num_roll,3); fic_R = zeros(num_z,num_r,num_roll,3);
    sic_L = zeros(num_z,num_r,num_roll,3); sic_R = zeros(num_z,num_r,num_roll,3);
    ia_dir_L = zeros(num_z,num_r,num_roll,3); ia_pt_L = zeros(num_z,num_r,num_roll,3);
    ia_dir_R = zeros(num_z,num_r,num_roll,3); ia_pt_R = zeros(num_z,num_r,num_roll,3);

    front_vsa_L = zeros(num_z,num_r,num_roll); side_vsa_L = zeros(num_z,num_r,num_roll);
    front_vsa_R = zeros(num_z,num_r,num_roll); side_vsa_R = zeros(num_z,num_r,num_roll);

    damper_len_L = zeros(num_z,num_r,num_roll); arb_ang_L = zeros(num_z,num_r,num_roll);
    damper_len_R = zeros(num_z,num_r,num_roll); arb_ang_R = zeros(num_z,num_r,num_roll);
    half_track_L = zeros(num_z,num_r,num_roll); half_track_R = zeros(num_z,num_r,num_roll);

    RC_mat = zeros(num_z,num_r,num_roll,3);
    pivot_history = zeros(num_z,1);

    R_hist_L = zeros(num_z,num_r,num_roll,3,3);
    R_hist_R = zeros(num_z,num_r,num_roll,3,3);

    % Rocker / ARB history (rocker sorok: axis, center, pushrod-rocker, damper-rocker, damper-chassis, pushrod-upright)
    rk_rows = [11 12 9 13 14 10];
    RK_static_L = vertcat(original_points_L(rk_rows).pos);
    RK_static_R = vertcat(original_points_R(rk_rows).pos);
    rocker_ang_L = zeros(num_z,num_r,num_roll); rocker_ang_R = zeros(num_z,num_r,num_roll);
    arb_hist  = nan(num_z,num_r,num_roll,6,3);
    arb_phi_L = nan(num_z,num_r,num_roll); arb_phi_R = nan(num_z,num_r,num_roll);
    arb_twist = nan(num_z,num_r,num_roll);

    % Statikus upright (Kabsch A mátrix) – base: pontok 6,3,8
    A_L = [original_points_L(6).pos; original_points_L(3).pos; original_points_L(8).pos];
    muA_L = mean(A_L);
    A0_L = A_L - muA_L;

    A_R = [original_points_R(6).pos; original_points_R(3).pos; original_points_R(8).pos];
    muA_R = mean(A_R);
    A0_R = A_R - muA_R;

    initial_normal_L = [0; 1; 0];   % base
    initial_normal_R = [0;-1; 0];   % jobb

    fixed_indices = find([points_L.fixed]);
    chassis_fixed = fixed_indices;

    quick_opts = optimoptions('fsolve', 'Display', 'off', 'MaxIterations', 5000, ...
        'StepTolerance', 1e-20, 'FunctionTolerance', 1e-20, 'Algorithm', 'levenberg-marquardt');

    static_z15_L = points_L(15).pos(3); static_y7_L = points_L(7).pos(2); static_z7_L = points_L(7).pos(3);
    static_z15_R = points_R(15).pos(3); static_y7_R = points_R(7).pos(2); static_z7_R = points_R(7).pos(3);

    % Statikus kerék pontok (camber cross) – base
    pos_center_s_L = original_points_L(15).pos;
    pos_top_s_L    = pos_center_s_L + [0 0 wheel_radius];
    pos_bottom_s_L = pos_center_s_L + [0 0 -wheel_radius];
    pos_front_s_L  = pos_center_s_L + [wheel_radius 0 0];
    pos_rear_s_L   = pos_center_s_L + [-wheel_radius 0 0];

    pos_center_s_R = original_points_R(15).pos;
    pos_top_s_R    = pos_center_s_R + [0 0 wheel_radius];
    pos_bottom_s_R = pos_center_s_R + [0 0 -wheel_radius];
    pos_front_s_R  = pos_center_s_R + [wheel_radius 0 0];
    pos_rear_s_R   = pos_center_s_R + [-wheel_radius 0 0];

    %% 7. Fő sweep – először csak pozíciók
    fprintf('Szimuláció indítása (Heave + Steer + Roll)...\n');
    current_RC_z = 0;

    for iz = 1:num_z
        dz = wheel_travel_range(iz);

        % Pure heave (steer=0, roll=0) → pure RC Z
        [ptsL_p, ptsR_p] = solve_heave_steer_roll( ...
            original_points_L, original_points_R, constraints_L, constraints_R, ...
            free_indices, chassis_fixed, dz, 0, 0, current_RC_z, ...
            static_z15_L, static_y7_L, static_z7_L, initial_x7_L, ...
            static_z15_R, static_y7_R, static_z7_R, initial_x7_R, quick_opts);

        % Pure-heave RC pivot: base kinematic IC (±1 mm heave perturbáció)
        [~,~,~,~,~,~,cpLp,~,~,~,~] = compute_params_no_ic(ptsL_p, A0_L, muA_L, ...
            initial_normal_L, wheel_radius, pos_top_s_L, pos_bottom_s_L, pos_front_s_L, pos_rear_s_L, true);

        [ptsL_m, ~] = solve_heave_steer_roll( ...
            original_points_L, original_points_R, constraints_L, constraints_R, ...
            free_indices, chassis_fixed, dz-1, 0, 0, current_RC_z, ...
            static_z15_L, static_y7_L, static_z7_L, initial_x7_L, ...
            static_z15_R, static_y7_R, static_z7_R, initial_x7_R, quick_opts);
        [ptsL_pp, ~] = solve_heave_steer_roll( ...
            original_points_L, original_points_R, constraints_L, constraints_R, ...
            free_indices, chassis_fixed, dz+1, 0, 0, current_RC_z, ...
            static_z15_L, static_y7_L, static_z7_L, initial_x7_L, ...
            static_z15_R, static_y7_R, static_z7_R, initial_x7_R, quick_opts);

        [fic_k, ia_dir_k, ia_pt_k] = kinematic_IC_from_three(ptsL_m, ptsL_p, ptsL_pp, A0_L, cpLp, dz);
        RC_pure = compute_RC_from_left(cpLp, ia_pt_k, ia_dir_k);
        pivot_history(iz) = RC_pure(3);
        current_RC_z = RC_pure(3);

        for ir = 1:num_r
            dy = steering_range(ir);
            for iroll = 1:num_roll
                roll_deg = roll_range(iroll);

                [ptsL, ptsR] = solve_heave_steer_roll( ...
                    original_points_L, original_points_R, constraints_L, constraints_R, ...
                    free_indices, chassis_fixed, dz, dy, roll_deg, current_RC_z, ...
                    static_z15_L, static_y7_L, static_z7_L, initial_x7_L, ...
                    static_z15_R, static_y7_R, static_z7_R, initial_x7_R, quick_opts);

                for i = 1:n_pts
                    pos_hist_L(i,:,iz,ir,iroll) = ptsL(i).pos;
                    pos_hist_R(i,:,iz,ir,iroll) = ptsR(i).pos;
                end

                % --- Rocker szög + ARB (utófeldolgozás, a szolver eredményéből) ---
                Rroll_s = roll_matrix(roll_deg);
                RK_L = vertcat(ptsL(rk_rows).pos);
                RK_R = vertcat(ptsR(rk_rows).pos);
                rocker_ang_L(iz,ir,iroll) =  rocker_angle_deg(RK_L, original_points_L(9).pos, dz, Rroll_s, current_RC_z);
                rocker_ang_R(iz,ir,iroll) = -rocker_angle_deg(RK_R, original_points_R(9).pos, dz, Rroll_s, current_RC_z);
                if arb.has
                    D_arb_L = rocker_carry(RK_static_L, RK_L, arb.D_L);
                    D_arb_R = rocker_carry(RK_static_R, RK_R, arb.D_R);
                    [Parb, phL, phR, tw] = solve_arb_state(arb, D_arb_L, D_arb_R, dz, Rroll_s, current_RC_z);
                    arb_hist(iz,ir,iroll,:,:) = Parb;
                    arb_phi_L(iz,ir,iroll) = phL; arb_phi_R(iz,ir,iroll) = phR;
                    arb_twist(iz,ir,iroll) = tw;
                end
            end
        end
        fprintf('  Heave %d/%d (dz=%.1f) pure RC_z=%.2f\n', iz, num_z, dz, current_RC_z);
    end

    %% 8. Paraméterek + IC (base 1:1, második pass a szomszédos heave lépések miatt)
    fprintf('Paraméterek és IC számítás...\n');
    for iz = 1:num_z
        for ir = 1:num_r
            for iroll = 1:num_roll
                % --- BAL ---
                ptsL = pack_pts(pos_hist_L(:,:,iz,ir,iroll), original_points_L);
                [cL,tL,trL,scL,caL,kpL,cpL_,RL,dlenL,aangL,htL] = ...
                    compute_params_no_ic(ptsL, A0_L, muA_L, initial_normal_L, wheel_radius, ...
                    pos_top_s_L, pos_bottom_s_L, pos_front_s_L, pos_rear_s_L, true);

                [ficL_,sicL_,iaDL,iaPL,fvsaL,svsaL] = compute_IC_base( ...
                    pos_hist_L, iz, ir, iroll, A0_L, wheel_travel_range, cpL_, num_z);

                camber_L(iz,ir,iroll)=-cL; toe_L(iz,ir,iroll)=tL;
                trail_L(iz,ir,iroll)=trL; scrub_L(iz,ir,iroll)=scL;
                caster_L(iz,ir,iroll)=caL; kpi_L(iz,ir,iroll)=kpL;
                cp_L(iz,ir,iroll,:)=cpL_; fic_L(iz,ir,iroll,:)=ficL_;
                sic_L(iz,ir,iroll,:)=sicL_; ia_dir_L(iz,ir,iroll,:)=iaDL;
                ia_pt_L(iz,ir,iroll,:)=iaPL;
                front_vsa_L(iz,ir,iroll)=fvsaL; side_vsa_L(iz,ir,iroll)=svsaL;
                damper_len_L(iz,ir,iroll)=dlenL; arb_ang_L(iz,ir,iroll)=aangL;
                half_track_L(iz,ir,iroll)=htL; R_hist_L(iz,ir,iroll,:,:)=RL;

                % --- JOBB ---
                ptsR = pack_pts(pos_hist_R(:,:,iz,ir,iroll), original_points_R);
                [cR,tR,trR,scR,caR,kpR,cpR_,RR,dlenR,aangR,htR] = ...
                    compute_params_no_ic(ptsR, A0_R, muA_R, initial_normal_R, wheel_radius, ...
                    pos_top_s_R, pos_bottom_s_R, pos_front_s_R, pos_rear_s_R, false);

                [ficR_,sicR_,iaDR,iaPR,fvsaR,svsaR] = compute_IC_base( ...
                    pos_hist_R, iz, ir, iroll, A0_R, wheel_travel_range, cpR_, num_z);

                camber_R(iz,ir,iroll)=cR; toe_R(iz,ir,iroll)=tR;
                trail_R(iz,ir,iroll)=trR; scrub_R(iz,ir,iroll)=scR;
                caster_R(iz,ir,iroll)=caR; kpi_R(iz,ir,iroll)=kpR;
                cp_R(iz,ir,iroll,:)=cpR_; fic_R(iz,ir,iroll,:)=ficR_;
                sic_R(iz,ir,iroll,:)=sicR_; ia_dir_R(iz,ir,iroll,:)=iaDR;
                ia_pt_R(iz,ir,iroll,:)=iaPR;
                front_vsa_R(iz,ir,iroll)=fvsaR; side_vsa_R(iz,ir,iroll)=svsaR;
                damper_len_R(iz,ir,iroll)=dlenR; arb_ang_R(iz,ir,iroll)=aangR;
                half_track_R(iz,ir,iroll)=htR; R_hist_R(iz,ir,iroll,:,:)=RR;

                % --- Roll Center (base Optimum Kinematics – mindkét oldal) ---
                RC_mat(iz,ir,iroll,:) = compute_RC_both(cpL_, iaPL, iaDL, cpR_, iaPR, iaDR);
            end
        end
    end

    fprintf('Kész! Interaktív nézet...\n');
    fprintf('Static camber L=%.3f°  R=%.3f°\n', camber_L(zero_wheel,zero_steer,zero_roll), camber_R(zero_wheel,zero_steer,zero_roll));
    fprintf('Static RC = [%.2f, %.2f, %.2f]\n', RC_mat(zero_wheel,zero_steer,zero_roll,1), ...
        RC_mat(zero_wheel,zero_steer,zero_roll,2), RC_mat(zero_wheel,zero_steer,zero_roll,3));
    arb_report(arb, arb_twist(:,zero_steer,zero_roll), arb_twist(zero_wheel,zero_steer,:), roll_range);

    %% 9. Tengelyhatárok – a felfüggesztés összes állapotából (nincs hardcode)
    P_all  = [reshape(permute(pos_hist_L, [1 3 4 5 2]), [], 3); ...
              reshape(permute(pos_hist_R, [1 3 4 5 2]), [], 3); reshape(arb_hist, [], 3)];
    WC_all = [reshape(permute(pos_hist_L(15,:,:,:,:), [1 3 4 5 2]), [], 3); ...
              reshape(permute(pos_hist_R(15,:,:,:,:), [1 3 4 5 2]), [], 3)];
    [xl, yl, zl] = auto_axis_limits(P_all, WC_all, wheel_radius, 191);

    %% 10. Vizualizáció
    fig = figure('Name', 'Double A-arm Both Sides + Heave/Steer/Roll', ...
        'NumberTitle', 'off', 'WindowState', 'maximized');
    ax = axes('Parent', fig, 'Position', [0.05 0.28 0.9 0.68]);
    hold(ax,'on'); grid(ax,'on'); axis(ax,'equal');
    xlabel(ax,'X [mm]'); ylabel(ax,'Y [mm]'); zlabel(ax,'Z [mm]');
    xlim(ax,xl); ylim(ax,yl); zlim(ax,zl);
    view(ax,-35,20);
    light('Parent',ax,'Position',[1 1 1],'Style','infinite');
    lighting(ax,'gouraud'); material(ax,'dull');

    [Xf,Yf] = meshgrid(linspace(xl(1),xl(2),12), linspace(yl(1),yl(2),12));
    Zf = zeros(size(Xf));

    slider_z = uicontrol('Parent',fig,'Style','slider','Units','normalized', ...
        'Position',[0.2 0.18 0.6 0.025],'Min',1,'Max',num_z,'Value',zero_wheel, ...
        'SliderStep',[1/(num_z-1) 5/(num_z-1)],'Callback',@update_ui);
    slider_r = uicontrol('Parent',fig,'Style','slider','Units','normalized', ...
        'Position',[0.2 0.12 0.6 0.025],'Min',1,'Max',num_r,'Value',zero_steer, ...
        'SliderStep',[1/(max(num_r-1,1)) 1],'Callback',@update_ui);
    slider_roll = uicontrol('Parent',fig,'Style','slider','Units','normalized', ...
        'Position',[0.2 0.06 0.6 0.025],'Min',1,'Max',num_roll,'Value',zero_roll, ...
        'SliderStep',[1/(num_roll-1) 1/(num_roll-1)],'Callback',@update_ui);

    txt_z    = uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[0.82 0.17 0.16 0.04],'String','','FontSize',11,'HorizontalAlignment','left');
    txt_r    = uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[0.82 0.11 0.16 0.04],'String','','FontSize',11,'HorizontalAlignment','left');
    txt_roll = uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[0.82 0.05 0.16 0.04],'String','','FontSize',11,'HorizontalAlignment','left');
    txt_rc   = uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[0.02 0.08 0.15 0.08],'String','','FontSize',12,'FontWeight','bold');
    txt_L    = uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[0.01 0.55 0.16 0.35],'String','','FontSize',9,'HorizontalAlignment','left','FontWeight','bold');
    txt_R    = uicontrol('Parent',fig,'Style','text','Units','normalized','Position',[0.83 0.55 0.16 0.35],'String','','FontSize',9,'HorizontalAlignment','left','FontWeight','bold');

    update_ui([],[]);

    function update_ui(~,~)
        w_idx = round(get(slider_z,'Value'));
        s_idx = round(get(slider_r,'Value'));
        r_idx = round(get(slider_roll,'Value'));

        set(txt_z,   'String',sprintf('Wheel Travel: %.1f mm', wheel_travel_range(w_idx)));
        set(txt_r,   'String',sprintf('Rack Travel: %.1f mm', steering_range(s_idx)));
        set(txt_roll,'String',sprintf('Chassis Roll: %.1f °', roll_range(r_idx)));

        rc = squeeze(RC_mat(w_idx,s_idx,r_idx,:));
        set(txt_rc,'String',sprintf('Roll Center Height:\n%.1f mm', rc(3)));

        strL = sprintf(['LEFT:\nCamber: %.2f°\nToe: %.2f°\nKPI: %.2f°\nCaster: %.2f°\n' ...
            'Scrub: %.1f mm\nTrail: %.1f mm\nDamper: %.1f mm\nRocker: %.2f°\nHalf-track: %.1f'], ...
            camber_L(w_idx,s_idx,r_idx), toe_L(w_idx,s_idx,r_idx), ...
            kpi_L(w_idx,s_idx,r_idx), caster_L(w_idx,s_idx,r_idx), ...
            scrub_L(w_idx,s_idx,r_idx), trail_L(w_idx,s_idx,r_idx), ...
            damper_len_L(w_idx,s_idx,r_idx), rocker_ang_L(w_idx,s_idx,r_idx), ...
            half_track_L(w_idx,s_idx,r_idx));
        if has_arb
            strL = [strL sprintf('\nARB blade: %.2f°\nARB twist (%s): %.2f°', arb_phi_L(w_idx,s_idx,r_idx), ...
                arb.type, arb_twist(w_idx,s_idx,r_idx))];
        end
        set(txt_L,'String',strL);

        strR = sprintf(['RIGHT:\nCamber: %.2f°\nToe: %.2f°\nKPI: %.2f°\nCaster: %.2f°\n' ...
            'Scrub: %.1f mm\nTrail: %.1f mm\nDamper: %.1f mm\nRocker: %.2f°\nHalf-track: %.1f'], ...
            camber_R(w_idx,s_idx,r_idx), toe_R(w_idx,s_idx,r_idx), ...
            kpi_R(w_idx,s_idx,r_idx), caster_R(w_idx,s_idx,r_idx), ...
            scrub_R(w_idx,s_idx,r_idx), trail_R(w_idx,s_idx,r_idx), ...
            damper_len_R(w_idx,s_idx,r_idx), rocker_ang_R(w_idx,s_idx,r_idx), ...
            half_track_R(w_idx,s_idx,r_idx));
        if has_arb
            strR = [strR sprintf('\nARB blade: %.2f°', arb_phi_R(w_idx,s_idx,r_idx))];
        end
        set(txt_R,'String',strR);

        cla(ax);
        surf(ax,Xf,Yf,Zf,'FaceColor',[0.92 0.94 0.98],'EdgeColor','none','FaceAlpha',0.45);

        pL_v = squeeze(pos_hist_L(:,:,w_idx,s_idx,r_idx));
        pR_v = squeeze(pos_hist_R(:,:,w_idx,s_idx,r_idx));
        draw_side(ax, pL_v);
        draw_side(ax, pR_v);
        if has_arb
            Parb_v = squeeze(arb_hist(w_idx,s_idx,r_idx,:,:));
            draw_rocker(ax, pL_v(rk_rows,:), Parb_v(1,:));
            draw_rocker(ax, pR_v(rk_rows,:), Parb_v(4,:));
            draw_arb(ax, Parb_v);
        else
            draw_rocker(ax, pL_v(rk_rows,:), []);
            draw_rocker(ax, pR_v(rk_rows,:), []);
        end

        WC_L = squeeze(pos_hist_L(15,:,w_idx,s_idx,r_idx));
        WC_R = squeeze(pos_hist_R(15,:,w_idx,s_idx,r_idx));
        RL = squeeze(R_hist_L(w_idx,s_idx,r_idx,:,:));
        RR = squeeze(R_hist_R(w_idx,s_idx,r_idx,:,:));
        nL = RL * initial_normal_L; nL = nL/norm(nL);
        nR = RR * initial_normal_R; nR = nR/norm(nR);
        draw_tire_simple(ax, WC_L, nL, wheel_radius);
        draw_tire_simple(ax, WC_R, nR, wheel_radius);

        cpLv = squeeze(cp_L(w_idx,s_idx,r_idx,:));
        cpRv = squeeze(cp_R(w_idx,s_idx,r_idx,:));
        plot3(ax,cpLv(1),cpLv(2),cpLv(3),'p','MarkerEdgeColor','k','MarkerFaceColor','y','MarkerSize',12);
        plot3(ax,cpRv(1),cpRv(2),cpRv(3),'p','MarkerEdgeColor','k','MarkerFaceColor','y','MarkerSize',12);

        draw_ic(ax, cpLv, squeeze(fic_L(w_idx,s_idx,r_idx,:)), 'r');
        draw_ic(ax, cpRv, squeeze(fic_R(w_idx,s_idx,r_idx,:)), 'r');

        plot3(ax,rc(1),rc(2),rc(3),'pentagram','MarkerFaceColor','m','MarkerEdgeColor','k','MarkerSize',16);
        plot3(ax,[rc(1) rc(1)],[rc(2) rc(2)],[0 rc(3)],'m--','LineWidth',1.5);

        title(ax,sprintf('Double A-arm | Travel %.1f mm | Rack %.1f mm | Roll %.1f°', ...
            wheel_travel_range(w_idx), steering_range(s_idx), roll_range(r_idx)));
        drawnow;
    end
end

%% ===================== HELPERS =====================
% (a DAA_Rear-rel azonos, ARB-feltételes változat: 15 ponttal az ARB-ág kimarad)

function d = compute_distances(pts)
    d.d13=norm(pts(1).pos-pts(3).pos); d.d23=norm(pts(2).pos-pts(3).pos);
    d.d46=norm(pts(4).pos-pts(6).pos); d.d56=norm(pts(5).pos-pts(6).pos);
    d.d36=norm(pts(3).pos-pts(6).pos); d.d86=norm(pts(8).pos-pts(6).pos);
    d.d83=norm(pts(8).pos-pts(3).pos); d.d78=norm(pts(7).pos-pts(8).pos);
    d.d910=norm(pts(9).pos-pts(10).pos); d.d310=norm(pts(3).pos-pts(10).pos);
    d.d110=norm(pts(1).pos-pts(10).pos); d.d210=norm(pts(2).pos-pts(10).pos);
    d.d911=norm(pts(9).pos-pts(11).pos); d.d912=norm(pts(9).pos-pts(12).pos);
    d.d315=norm(pts(3).pos-pts(15).pos); d.d615=norm(pts(6).pos-pts(15).pos);
    d.d815=norm(pts(8).pos-pts(15).pos); d.d913=norm(pts(9).pos-pts(13).pos);
    d.d1113=norm(pts(11).pos-pts(13).pos); d.d1213=norm(pts(12).pos-pts(13).pos);
    if numel(pts) >= 18   % ARB megléte esetén
        d.d1611=norm(pts(16).pos-pts(11).pos); d.d1612=norm(pts(16).pos-pts(12).pos);
        d.d1617=norm(pts(16).pos-pts(17).pos); d.d169=norm(pts(16).pos-pts(9).pos);
        d.d1718=norm(pts(17).pos-pts(18).pos);
    end
end

function cons = build_constraints(d)
    cons = {};
    with_arb = isfield(d, 'd1611');   % van-e ARB a modellben
    pairs = [1 3 d.d13; 2 3 d.d23; 4 6 d.d46; 5 6 d.d56; 3 6 d.d36; ...
             8 6 d.d86; 8 3 d.d83; 7 8 d.d78; 9 10 d.d910; 3 10 d.d310; ...
             1 10 d.d110; 2 10 d.d210; 9 11 d.d911; 9 12 d.d912; ...
             3 15 d.d315; 6 15 d.d615; 8 15 d.d815; 9 13 d.d913; ...
             11 13 d.d1113; 12 13 d.d1213];
    if with_arb
        pairs = [pairs; 16 11 d.d1611; 16 12 d.d1612; ...
                 16 17 d.d1617; 16 9 d.d169; 17 18 d.d1718];
    end
    for k = 1:size(pairs,1)
        cons = add_dist(cons, pairs(k,1), pairs(k,2), pairs(k,3), with_arb);
    end
end

function cons = add_dist(cons, i, j, len, with_arb)
    cons{end+1} = @(all_pts) norm(all_pts(j).pos - all_pts(i).pos) - len;
    if with_arb
        cons{end+1} = @(all_pts) dot(all_pts(17).pos - all_pts(18).pos, [0 1 0]);
    end
end

function res = compute_all_residuals(x_free, pts_base, cons, free_idx)
    pts = pts_base;
    k = 1;
    for idx = free_idx
        pts(idx).pos = x_free(k:k+2); k = k+3;
    end
    res = zeros(length(cons),1);
    for c = 1:length(cons), res(c) = cons{c}(pts); end
end

function res = compute_residuals_dyn(x_free, pts_base, cons, free_idx, target_z15, target_y7, initial_x7, target_z7)
    pts = pts_base;
    k = 1;
    for idx = free_idx
        pts(idx).pos = x_free(k:k+2); k = k+3;
    end
    res = zeros(length(cons)+4,1);
    for c = 1:length(cons), res(c) = cons{c}(pts); end
    res(end-3) = pts(7).pos(1) - initial_x7;
    res(end-2) = pts(7).pos(3) - target_z7;
    res(end-1) = pts(15).pos(3) - target_z15;
    res(end)   = pts(7).pos(2) - target_y7;
end

function [ptsL_out, ptsR_out] = solve_heave_steer_roll( ...
        origL, origR, consL, consR, free_idx, chassis_fixed, ...
        dz, dy, roll_deg, pivot_z, ...
        sz15L, sy7L, sz7L, ix7L, sz15R, sy7R, sz7R, ix7R, opts)

    ptsL = origL; ptsR = origR;
    r_rad = deg2rad(roll_deg);
    Rroll = [1 0 0; 0 cos(r_rad) -sin(r_rad); 0 sin(r_rad) cos(r_rad)];

    for i = chassis_fixed
        pL = ptsL(i).pos; pL(3) = pL(3) - dz;
        pR = ptsR(i).pos; pR(3) = pR(3) - dz;
        pL = (Rroll * (pL' - [0;0;pivot_z]) + [0;0;pivot_z])';
        pR = (Rroll * (pR' - [0;0;pivot_z]) + [0;0;pivot_z])';
        ptsL(i).pos = pL; ptsR(i).pos = pR;
    end

    % % Kozos rack: mindket oldal ugyanabba az abszolut Y iranyba mozog.
    % % +dy = rack balra (Y+) -> balra kormanyzas mindket kereken.
    % target_y7L = sy7L + dy;
    % target_y7R = sy7R + dy;
    % target_z7L = sz7L - dz;
    % target_z7R = sz7R - dz;

    % Heave + roll a rack design pozícióra is:
    p7L = origL(7).pos; p7L(3) = p7L(3) - dz;
    p7L = (Rroll * (p7L' - [0;0;pivot_z]) + [0;0;pivot_z])';
    p7R = origR(7).pos; p7R(3) = p7R(3) - dz;
    p7R = (Rroll * (p7R' - [0;0;pivot_z]) + [0;0;pivot_z])';

    target_y7L = p7L(2) + dy;   % vagy: sy7L + dy, ha a dy a rolled frame-ben van
    target_y7R = p7R(2) + dy;
    target_z7L = p7L(3);         % ← rolled Z, ne sz7L - dz
    target_z7R = p7R(3);

    x0L = []; x0R = [];
    for idx = free_idx
        pL = origL(idx).pos; pL(3) = pL(3) - dz;
        pR = origR(idx).pos; pR(3) = pR(3) - dz;
        pL = (Rroll * (pL' - [0;0;pivot_z]) + [0;0;pivot_z])';
        pR = (Rroll * (pR' - [0;0;pivot_z]) + [0;0;pivot_z])';
        x0L = [x0L, pL]; x0R = [x0R, pR];
    end

    xL = fsolve(@(x) compute_residuals_dyn(x, ptsL, consL, free_idx, sz15L, target_y7L, ix7L, target_z7L), x0L, opts);
    xR = fsolve(@(x) compute_residuals_dyn(x, ptsR, consR, free_idx, sz15R, target_y7R, ix7R, target_z7R), x0R, opts);

    k = 1;
    for idx = free_idx
        ptsL(idx).pos = xL(k:k+2);
        ptsR(idx).pos = xR(k:k+2);
        k = k+3;
    end
    ptsL_out = ptsL; ptsR_out = ptsR;
end

function pts = pack_pts(P, template)
    pts = template;
    for i = 1:size(P,1)
        pts(i).pos = P(i,:);
    end
end

function [camber, toe, trail, scrub, caster, kpi, cp, R, damper_len, arb_ang, half_track] = ...
    compute_params_no_ic(pts, A0, muA, initial_normal, wheel_radius, ...
                         pos_top_s, pos_bottom_s, pos_front_s, pos_rear_s, is_left)
% ========== 1:1 BASE LOGIKA ==========

    % Kabsch R (base: pontok 6,3,8)
    B = [pts(6).pos; pts(3).pos; pts(8).pos];
    muB = mean(B);
    B0 = B - muB;
    H = A0' * B0;
    [U,~,V] = svd(H);
    R = V * U';
    if det(R) < 0
        V(:,3) = -V(:,3);
        R = V * U';
    end

    % Kerék cross pontok (base)
    pos_top_c    = (R * (pos_top_s'    - muA'))' + muB;
    pos_bottom_c = (R * (pos_bottom_s' - muA'))' + muB;
    pos_front_c  = (R * (pos_front_s'  - muA'))' + muB;
    pos_rear_c   = (R * (pos_rear_s'   - muA'))' + muB;

    % Camber (base tire-cross method)
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
    camber_rad = atan2(tilt_lateral, tilt_vertical);
    camber = -rad2deg(camber_rad);   % base előjel

    % Jobb oldalon a transverse_unit iránya + a normal Y negatív → a cross
    % módszer önmagában is helyes előjelet ad (static ~0), nincs extra flip.

    current_normal = R * initial_normal;
    unit_normal = current_normal / norm(current_normal);

    % Toe (base)
    if abs(unit_normal(2)) > 1e-6
        toe = -rad2deg(atan(unit_normal(1) / unit_normal(2)));
    else
        toe = 90 * sign(unit_normal(1));
    end
    % Jobb oldalon initial_normal Y < 0 → az atan előjele megfordul, ezért:
    if ~is_left
        toe = -toe;
    end

    % ======================= Contact Patch (1:1 base) =======================
    % Gravity projekció a wheel plane-re
    pos_center = pts(15).pos;
    gravity_dir = [0; 0; -1];
    proj_grav = gravity_dir - dot(gravity_dir, unit_normal) * unit_normal;
    if norm(proj_grav) > 1e-6
        down_dir = proj_grav / norm(proj_grav);
    else
        down_dir = [0; 0; -1];  % Ha a sík vízszintes
    end
    % base: t_gnd = (0 - pos_center(3)) / down_dir(3);
    %       cp = pos_center' + t_gnd * down_dir;
    t_gnd = (0 - pos_center(3)) / down_dir(3);
    cp = (pos_center(:) + t_gnd * down_dir)';
    cp_x = cp(1); cp_y = cp(2); cp_z = cp(3);

    % Kingpin (base: upper=3, lower=6)
    pos_upper = pts(3).pos;
    pos_lower = pts(6).pos;
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

    % KPI (base)
    kpi_projection = [kingpin_vec(2); kingpin_vec(3)];
    kpi_projection = kpi_projection / norm(kpi_projection);
    kpi = -rad2deg(atan2(kpi_projection(1), abs(kpi_projection(2))));
    if ~is_left
        kpi = -kpi;   % jobb oldal tükrözés
    end

    % Scrub (base)
    scrub = cp_y - kg_y;
    if ~is_left
        scrub = -scrub;
    end

    % Mechanical trail (base)
    trail = kg_x - cp_x;

    % Caster (base)
    caster_projection = [kingpin_vec(1); kingpin_vec(3)];
    caster_projection = caster_projection / norm(caster_projection);
    caster = -rad2deg(atan2(caster_projection(1), caster_projection(2)));

    % Damper / ARB
    damper_len = norm(pts(13).pos - pts(14).pos);
    if numel(pts) >= 18
        blade = pts(17).pos - pts(18).pos;
        arb_ang = rad2deg(atan2(blade(1), blade(3)));
    else
        arb_ang = NaN;   % nincs ARB
    end
    half_track = abs(cp_y);
end

function [front_ic, side_ic, ia_dir, ia_point, front_vsa, side_vsa] = ...
    compute_IC_base(pos_hist, wheel_step, steer_step, roll_step, A0, wheel_travel_range, cp, num_z)
% ========== 1:1 BASE KINEMATIC IC (perturbáció ±1 heave lépés) ==========
% base_program_front_left.m aktív IC blokk másolata

    cp_x = cp(1); cp_y = cp(2); cp_z = cp(3);

    if num_z > 1
        if wheel_step == 1
            step_m = 1; step_p = 2;
        elseif wheel_step == num_z
            step_m = num_z - 1; step_p = num_z;
        else
            step_m = wheel_step - 1; step_p = wheel_step + 1;
        end

        dz_m = wheel_travel_range(step_m);
        dz_p = wheel_travel_range(step_p);
        dz_c = wheel_travel_range(wheel_step);

        % --- R_m (Kabsch, pontok 6,3,8) ---
        B_m = [reshape(pos_hist(6,:,step_m,steer_step,roll_step), 1, 3);
               reshape(pos_hist(3,:,step_m,steer_step,roll_step), 1, 3);
               reshape(pos_hist(8,:,step_m,steer_step,roll_step), 1, 3)];
        muB_m = mean(B_m);
        B0_m = B_m - muB_m;
        H_m = A0' * B0_m;
        [U_m, ~, V_m] = svd(H_m);
        R_m = V_m * U_m';
        if det(R_m) < 0
            V_m(:,3) = -V_m(:,3);
            R_m = V_m * U_m';
        end

        % --- R_p ---
        B_p = [reshape(pos_hist(6,:,step_p,steer_step,roll_step), 1, 3);
               reshape(pos_hist(3,:,step_p,steer_step,roll_step), 1, 3);
               reshape(pos_hist(8,:,step_p,steer_step,roll_step), 1, 3)];
        muB_p = mean(B_p);
        B0_p = B_p - muB_p;
        H_p = A0' * B0_p;
        [U_p, ~, V_p] = svd(H_p);
        R_p = V_p * U_p';
        if det(R_p) < 0
            V_p(:,3) = -V_p(:,3);
            R_p = V_p * U_p';
        end

        % Kis elfordulás
        R_delta = R_p * R_m';
        w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
        w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
        w_z = (R_delta(2,1) - R_delta(1,2)) / 2;

        % Kerékközéppont a vázhoz viszonyítva (+ dz offset, mint a base-ben)
        p15_m = reshape(pos_hist(15,:,step_m,steer_step,roll_step), 1, 3) + [0, 0, dz_m];
        p15_p = reshape(pos_hist(15,:,step_p,steer_step,roll_step), 1, 3) + [0, 0, dz_p];
        p15_c = reshape(pos_hist(15,:,wheel_step,steer_step,roll_step), 1, 3) + [0, 0, dz_c];

        v_15 = p15_p - p15_m;

        % --- Front View IC (YZ sík, x = cp_x) ---
        % v_y = 0, v_z = 0
        if abs(w_x) > 1e-10
            y_ic = p15_c(2) + (-v_15(3) + w_y * (cp_x - p15_c(1))) / w_x;
            z_ic = p15_c(3) + ( v_15(2) + w_z * (cp_x - p15_c(1))) / w_x;
            front_ic_chassis = [cp_x, y_ic, z_ic];
        else
            front_ic_chassis = [cp_x, cp_y + sign(v_15(2))*1e6, cp_z + 1e6];
        end

        % --- Side View IC (XZ sík, y = cp_y) ---
        % v_x = 0, v_z = 0
        if abs(w_y) > 1e-10
            x_ic = p15_c(1) + ( v_15(3) + w_x * (cp_y - p15_c(2))) / w_y;
            z_ic = p15_c(3) + (-v_15(1) + w_z * (cp_y - p15_c(2))) / w_y;
            side_ic_chassis = [x_ic, cp_y, z_ic];
        else
            side_ic_chassis = [cp_x + sign(v_15(1))*1e6, cp_y, cp_z + 1e6];
        end

        % Vissza world koordinátába (offset visszavonása)
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

    front_vsa = hypot(front_ic(2) - cp_y, front_ic(3) - cp_z);
    side_vsa  = hypot(side_ic(1) - cp_x,  side_ic(3) - cp_z);
end

function [fic, ia_dir, ia_pt] = kinematic_IC_from_three(pts_m, pts_c, pts_p, A0, cp, dz_c)
% Base IC logika három pure-heave állapotból (m = dz-1, c = dz, p = dz+1)
    cp_x = cp(1); cp_y = cp(2); cp_z = cp(3);

    B_m = [pts_m(6).pos; pts_m(3).pos; pts_m(8).pos];
    muB_m = mean(B_m); B0_m = B_m - muB_m;
    H_m = A0' * B0_m;
    [U_m, ~, V_m] = svd(H_m);
    R_m = V_m * U_m';
    if det(R_m) < 0, V_m(:,3) = -V_m(:,3); R_m = V_m * U_m'; end

    B_p = [pts_p(6).pos; pts_p(3).pos; pts_p(8).pos];
    muB_p = mean(B_p); B0_p = B_p - muB_p;
    H_p = A0' * B0_p;
    [U_p, ~, V_p] = svd(H_p);
    R_p = V_p * U_p';
    if det(R_p) < 0, V_p(:,3) = -V_p(:,3); R_p = V_p * U_p'; end

    R_delta = R_p * R_m';
    w_x = (R_delta(3,2) - R_delta(2,3)) / 2;
    w_y = (R_delta(1,3) - R_delta(3,1)) / 2;
    w_z = (R_delta(2,1) - R_delta(1,2)) / 2;

    % Váz-relatív kerékközéppont (base: + dz offset)
    p15_m = pts_m(15).pos + [0, 0, dz_c - 1];
    p15_p = pts_p(15).pos + [0, 0, dz_c + 1];
    p15_c = pts_c(15).pos + [0, 0, dz_c];
    v_15 = p15_p - p15_m;

    if abs(w_x) > 1e-10
        y_ic = p15_c(2) + (-v_15(3) + w_y * (cp_x - p15_c(1))) / w_x;
        z_ic = p15_c(3) + ( v_15(2) + w_z * (cp_x - p15_c(1))) / w_x;
        front_ic_chassis = [cp_x, y_ic, z_ic];
    else
        front_ic_chassis = [cp_x, cp_y + sign(v_15(2))*1e6, cp_z + 1e6];
    end

    fic = front_ic_chassis - [0, 0, dz_c];
    ia_dir = [w_x, w_y, w_z];
    if norm(ia_dir) > 1e-10
        ia_dir = ia_dir / norm(ia_dir);
    end
    ia_pt = fic;
end


function RC = compute_RC_from_left(cp_L, ia_pt_L, ia_dir_L)
% Base single-side mirror method (Optimum Kinematics)
    if norm(ia_dir_L) < 1e-10
        RC = [cp_L(1), 0, cp_L(3)];
        return;
    end
    CP_L = cp_L(:)';
    CP_R = [cp_L(1), -cp_L(2), cp_L(3)];
    IA_pt_R = [ia_pt_L(1), -ia_pt_L(2), ia_pt_L(3)];
    IA_dir_R = [ia_dir_L(1), -ia_dir_L(2), ia_dir_L(3)];

    vec_L = ia_pt_L - CP_L;
    N_L = cross(ia_dir_L, vec_L);
    if norm(N_L)>1e-10, N_L = N_L/norm(N_L); end

    vec_R = IA_pt_R - CP_R;
    N_R = cross(IA_dir_R, vec_R);
    if norm(N_R)>1e-10, N_R = N_R/norm(N_R); end

    d = cross(N_L, N_R);
    if norm(d)>1e-10, d = d/norm(d); else, d = [1 0 0]; end

    A_planes = [N_L; N_R];
    b_planes = [dot(N_L, CP_L); dot(N_R, CP_R)];
    P0 = (pinv(A_planes) * b_planes)';

    x_RC = (CP_L(1)+CP_R(1))/2;
    if abs(d(1))>1e-10
        t_RC = (x_RC - P0(1)) / d(1);
    else
        t_RC = 0;
    end
    RC = P0 + t_RC * d;
end

function RC = compute_RC_both(cp_L, ia_pt_L, ia_dir_L, cp_R, ia_pt_R, ia_dir_R)
% Base Optimum Kinematics – mindkét oldal valós adatai
    if norm(ia_dir_L)<1e-10 || norm(ia_dir_R)<1e-10
        RC = [(cp_L(1)+cp_R(1))/2, 0, (cp_L(3)+cp_R(3))/2];
        return;
    end
    CP_L = cp_L(:)'; CP_R = cp_R(:)';
    IA_pt_L = ia_pt_L(:)'; IA_pt_R = ia_pt_R(:)';
    IA_dir_L = ia_dir_L(:)'; IA_dir_R = ia_dir_R(:)';

    vec_L = IA_pt_L - CP_L;
    N_L = cross(IA_dir_L, vec_L);
    if norm(N_L)>1e-10, N_L = N_L/norm(N_L); end

    vec_R = IA_pt_R - CP_R;
    N_R = cross(IA_dir_R, vec_R);
    if norm(N_R)>1e-10, N_R = N_R/norm(N_R); end

    d = cross(N_L, N_R);
    if norm(d)>1e-10, d = d/norm(d); else, d = [1 0 0]; end

    A_planes = [N_L; N_R];
    b_planes = [dot(N_L, CP_L); dot(N_R, CP_R)];
    P0 = (pinv(A_planes) * b_planes)';

    x_RC = (CP_L(1)+CP_R(1))/2;
    if abs(d(1))>1e-10
        t_RC = (x_RC - P0(1)) / d(1);
    else
        t_RC = 0;
    end
    RC = P0 + t_RC * d;
end

function draw_side(ax, p)
    plot3(ax,[p(1,1) p(3,1) p(2,1)],[p(1,2) p(3,2) p(2,2)],[p(1,3) p(3,3) p(2,3)],'k-','LineWidth',2.5);
    plot3(ax,[p(4,1) p(6,1) p(5,1)],[p(4,2) p(6,2) p(5,2)],[p(4,3) p(6,3) p(5,3)],'k-','LineWidth',2.5);
    plot3(ax,[p(3,1) p(10,1) p(8,1) p(6,1) p(3,1)], ...
             [p(3,2) p(10,2) p(8,2) p(6,2) p(3,2)], ...
             [p(3,3) p(10,3) p(8,3) p(6,3) p(3,3)],'b-','LineWidth',2);
    plot3(ax,[p(7,1) p(8,1)],[p(7,2) p(8,2)],[p(7,3) p(8,3)],'r-','LineWidth',2.5);
    plot3(ax,[p(9,1) p(10,1)],[p(9,2) p(10,2)],[p(9,3) p(10,3)],'g-','LineWidth',2);
    plot3(ax,[p(13,1) p(14,1)],[p(13,2) p(14,2)],[p(13,3) p(14,3)],'m-','LineWidth',2);
    if size(p,1) >= 18
        plot3(ax,[p(16,1) p(17,1) p(18,1)],[p(16,2) p(17,2) p(18,2)],[p(16,3) p(17,3) p(18,3)],'c-','LineWidth',1.5);
    end
    scatter3(ax,p(:,1),p(:,2),p(:,3),25,'k','filled');
end

function draw_tire_simple(ax, center, normal, radius)
    width = 191;
    normal = normal(:)/norm(normal);
    theta = linspace(0,2*pi,40);
    v = null(normal');
    if size(v,2)<2, return; end
    circle = radius*(v(:,1)*cos(theta)+v(:,2)*sin(theta));
    pts1 = center(:)+normal*(width/2)+circle;
    pts2 = center(:)-normal*(width/2)+circle;
    fill3(ax,pts1(1,:),pts1(2,:),pts1(3,:),[0.25 0.25 0.28],'FaceAlpha',0.9,'EdgeColor','none');
    fill3(ax,pts2(1,:),pts2(2,:),pts2(3,:),[0.25 0.25 0.28],'FaceAlpha',0.9,'EdgeColor','none');
    surf(ax,[pts1(1,:);pts2(1,:)],[pts1(2,:);pts2(2,:)],[pts1(3,:);pts2(3,:)], ...
        'FaceColor',[0.15 0.15 0.15],'EdgeColor','none','FaceAlpha',0.95);
end

function draw_ic(ax, cp, ic, col)
    if norm(ic-cp) > 1e4
        dir = (ic-cp)/norm(ic-cp);
        end_pt = cp + dir*2500;
        plot3(ax,[cp(1) end_pt(1)],[cp(2) end_pt(2)],[cp(3) end_pt(3)],[col '--'],'LineWidth',1.5);
    else
        plot3(ax,[cp(1) ic(1)],[cp(2) ic(2)],[cp(3) ic(3)],[col '--'],'LineWidth',1.5);
        plot3(ax,ic(1),ic(2),ic(3),'o','MarkerFaceColor',col,'MarkerEdgeColor','k','MarkerSize',7);
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
