function optimize_tierod_fixed_dimensions()
    clc; clear; close all;

    % =========================================================================
    % 1. GEOMETRIAI ALAPADATOK (A te fájlod pontjai)
    % =========================================================================
    Geo.wheel_radius = 360;
    tengelytav = 3000;      % [mm] - Írd át a valós járműved értékére!
    elso_nyomtav = 1660;    % [mm]

    % Alap pontok mátrixa [X, Y, Z]
    Geo.pts_base = [
        142.910, 130.958, 588.738;  % 1: Front left upper arm fore (Chassis)
       -423.620, 168.674, 470.738;  % 2: Front left upper arm aft (Chassis)
        -51.340, 691.900, 521.820;  % 3: Front left upper arm upright
        205.470, 126.962, 394.866;  % 4: Front left lower arm fore (Chassis)
       -407.280, 161.941, 344.481;  % 5: Front left lower arm aft (Chassis)
        -20.720, 746.210, 303.980;  % 6: Front left lower arm upright
        170.140, 130.958, 540.912;  % 7: Front left tie rod chassis
         25.017, 696.430, 481.810;  % 8: Front left tie rod upright (Kezdő tipp)
          0.000, 830.000, 360.000   % 9: Front left wheel center
    ];

    % Elvárt kormányzási paraméterek
    delta_kulso_target = 30.8;
    ackerman_szazalek_target = 57.0;

    % Kép szerinti elméleti Ackerman szög számítása
    ackerman_ideal_deg = rad2deg(atan( tengelytav / ( (tengelytav / tand(delta_kulso_target)) - elso_nyomtav ) ));
    delta_belso_required = (ackerman_szazalek_target * ackerman_ideal_deg) / 100;

    % Fix lengőkar hosszak (Chassis pontokhoz képest)
    Geo.L13 = norm(Geo.pts_base(3,:) - Geo.pts_base(1,:));
    Geo.L23 = norm(Geo.pts_base(3,:) - Geo.pts_base(2,:));
    Geo.L46 = norm(Geo.pts_base(6,:) - Geo.pts_base(4,:));
    Geo.L56 = norm(Geo.pts_base(6,:) - Geo.pts_base(5,:));
    
    % Csonkállvány belső pontjainak fix alap távolságai (csak a 3, 6, 9 pontoké, a P8-at dinamikusan mérjük)
    Geo.L36 = norm(Geo.pts_base(3,:) - Geo.pts_base(6,:));
    Geo.L39 = norm(Geo.pts_base(3,:) - Geo.pts_base(9,:));
    Geo.L69 = norm(Geo.pts_base(6,:) - Geo.pts_base(9,:));

    % Kormányszár (Steering Arm) hossz kényszer meghatározása a Kingpin (P3-P6) tengelytől
    v_kp = Geo.pts_base(3,:) - Geo.pts_base(6,:);
    u_kp = v_kp / norm(v_kp);
    target_steering_arm = norm(cross(Geo.pts_base(8,:) - Geo.pts_base(6,:), u_kp)); 

    % SVD orientáció-követés statikus mátrixai (a te kódodból)
    upright_pts_idx = [3, 6, 9];
    Geo.A_static = Geo.pts_base(upright_pts_idx, :)';
    Geo.muA = mean(Geo.A_static, 2);
    Geo.initial_normal = [0; 1; 0];
    Geo.upright_pts_idx = upright_pts_idx;

    fprintf('--- Szimulációs Előfeltételek ---\n');
    fprintf('Megkövetelt fix kormányszár hossz:           %.3f mm\n', target_steering_arm);
    fprintf('Elvárt valós belső szög (%.1f%% Ackermanhoz): %.4f fok\n\n', ackerman_szazalek_target, delta_belso_required);

    % =========================================================================
    % 2. OPTIMALIZÁLÁS (FMINCON)
    % =========================================================================
    P8_start = Geo.pts_base(8,:);

    options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'interior-point', ...
                           'StepTolerance', 1e-8, 'ConstraintTolerance', 1e-7, 'MaxFunctionEvaluations', 2000);

    fprintf('Optimalizálás futtatása a te kódod lsqnonlin kényszermegoldójára építve...\n');
    
    [P8_opt, fval] = fmincon(@(P8) obj_ackerman_system(P8, Geo, delta_kulso_target, delta_belso_required, tengelytav, elso_nyomtav), ...
                             P8_start, [], [], [], [], [], [], ...
                             @(P8) nonlin_constraints_system(P8, Geo, target_steering_arm, delta_belso_required), options);

    % =========================================================================
    % 3. VÉGSŐ KIÉRTÉKELÉS
    % =========================================================================
    [~, act_ackerman, delta_kulso_elert, rack_travel_final] = obj_ackerman_system(P8_opt, Geo, delta_kulso_target, delta_belso_required, tengelytav, elso_nyomtav);
    [~, ceq] = nonlin_constraints_system(P8_opt, Geo, target_steering_arm, delta_belso_required);

    fprintf('\n==================================================\n');
    fprintf('          OPTIMALIZÁLÁS VÉGEREDMÉNYE              \n');
    fprintf('==================================================\n');
    fprintf('Optimális P8 pont (Tie rod upright koordinátái):\n');
    fprintf('  X (Hosszirány):   %8.4f mm\n', P8_opt(1));
    fprintf('  Y (Keresztirány): %8.4f mm\n', P8_opt(2));
    fprintf('  Z (Magasság):     %8.4f mm\n', P8_opt(3));
    fprintf('--------------------------------------------------\n');
    fprintf('Szükséges kormánymű elmozdulás (Rack travel): %.3f mm\n', rack_travel_final);
    fprintf('Elért szimulált külső szög:  %.4f fok (Cél: %.4f fok)\n', delta_kulso_elert, delta_kulso_target);
    fprintf('Elért Ackerman százalék:    %.2f %%  (Cél: %.2f %%)\n', act_ackerman, ackerman_szazalek_target);
    fprintf('Kormányszár hossz eltérés:   %.6f mm\n', ceq(1));
    fprintf('Bump Steer (Toe elváltozás) a kanyarodott íven:\n');
    fprintf('  +20mm berugózáskor:       %.6f fok\n', ceq(2));
    fprintf('  -20mm kirugózáskor:       %.6f fok\n', ceq(3));
    fprintf('==================================================\n');
end

% =========================================================================
% ACKERMAN CÉLFÜGGVÉNY
% =========================================================================
function [cost, ackerman_percent, delta_kulso_sim, rack_travel] = obj_ackerman_system(P8, Geo, delta_kulso_target, delta_belso_req, tengelytav, elso_nyomtav)
    
    L_tierod = norm(P8 - Geo.pts_base(7,:));
    
    % 1. Megkeressük azt a rack elmozdulást, ami megadja a belső kormányszöget
    opt_sub = optimset('Display', 'off', 'TolX', 1e-7);
    rack_travel = fminsearch(@(rack_tr) residual_rack_for_toe(rack_tr, P8, L_tierod, Geo, delta_belso_req, 0), 20, opt_sub);
    
    % 2. Ellentétes irányú elmozdulás a külső oldalon
    rack_travel_outer = -rack_travel; 
    
    % Kinematika futtatása a külső oldali rack állásra (dz = 0)
    pts_outer = solve_complete_wishbone(P8, L_tierod, Geo, rack_travel_outer, 0);
    
    % SVD szögmérés
    delta_kulso_sim = compute_toe_via_svd(pts_outer, Geo);
    
    % Ackerman arány számítása
    ackerman_ideal_sim = rad2deg(atan( tengelytav / ( (tengelytav / tand(delta_kulso_sim)) - elso_nyomtav ) ));
    ackerman_percent = (delta_belso_req / ackerman_ideal_sim) * 100;
    
    cost = (delta_kulso_sim - delta_kulso_target)^2;
end

% =========================================================================
% NONLIN KÉNYSZEREK (BUMP STEER + STEERING ARM)
% =========================================================================
function [c, ceq] = nonlin_constraints_system(P8, Geo, target_steering_arm, delta_belso_req)
    c = [];
    ceq = zeros(3,1);
    
    % 1. Kormányszár hossz megtartása
    v_kp = Geo.pts_base(3,:) - Geo.pts_base(6,:);
    u_kp = v_kp / norm(v_kp);
    current_steering_arm = norm(cross(P8 - Geo.pts_base(6,:), u_kp));
    ceq(1) = current_steering_arm - target_steering_arm;

    L_tierod = norm(P8 - Geo.pts_base(7,:));

    % 2. Rack pozíció kanyarodáskor
    opt_sub = optimset('Display', 'off', 'TolX', 1e-7);
    rack_travel_steered = fminsearch(@(rack_tr) residual_rack_for_toe(rack_tr, P8, L_tierod, Geo, delta_belso_req, 0), 20, opt_sub);

    % 3. Bump Steer sweep kanyarodott állapotban (+20mm és -20mm)
    travels = [20, -20];
    for i = 1:2
        dz = travels(i);
        pts_bumped = solve_complete_wishbone(P8, L_tierod, Geo, rack_travel_steered, dz);
        toe_bumped = compute_toe_via_svd(pts_bumped, Geo);
        ceq(i+1) = toe_bumped - delta_belso_req;
    end
end

% =========================================================================
% HÁTTÉR KINEMATIKAI MEGOLDÓK
% =========================================================================
function err = residual_rack_for_toe(rack_travel, P8, L_tierod, Geo, target_toe, dz)
    pts = solve_complete_wishbone(P8, L_tierod, Geo, rack_travel, dz);
    current_toe = compute_toe_via_svd(pts, Geo);
    err = (current_toe - target_toe)^2;
end

function pts_solved = solve_complete_wishbone(P8, L_tierod, Geo, rack_travel, dz)
    % Ideiglenes ponttáblázat létrehozása
    pts = Geo.pts_base;
    pts(8, :) = P8; 
    pts(7, 2) = pts(7, 2) + rack_travel; 
    
    free_indices = [3, 6, 8, 9];
    
    % Inicializáljuk a keresési vektort a te kódod mintájára
    x0 = [];
    for idx = free_indices
        x0 = [x0, pts(idx, :)];
    end
    
    % KIGYŰJTJÜK A CSONKÁLLVÁNY MEREVSÉGI TÁVOLSÁGAIT (Belevéve a vizsgált P8 pontot is!)
    % Így a csonkállvány merev testként mozog, mátrixszorzások nélkül.
    upright_pts = [3, 6, 8, 9];
    pairs = nchoosek(upright_pts, 2);
    L_upright_pairs = zeros(size(pairs,1), 1);
    for k = 1:size(pairs,1)
        L_upright_pairs(k) = norm(pts(pairs(k,2), :) - pts(pairs(k,1), :));
    end
    
    target_z9 = Geo.pts_base(9,3) + dz;
    
    % Megoldás a te lsqnonlin-alapú kényszerfüggvényeddel
    options_lsq = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-12, 'MaxIterations', 500);
    [x_res, ~] = lsqnonlin(@(x) internal_residuals(x, pts, Geo, L_tierod, pairs, L_upright_pairs, free_indices, target_z9), x0, [], [], options_lsq);
    
    % Visszaalakítás pont-mátrixszá
    pts_solved = pts;
    k = 1;
    for idx = free_indices
        pts_solved(idx, :) = x_res(k : k+2);
        k = k + 3;
    end
end

% A TE SAJÁT KÓDOD ALAPJÁN MŰKÖDŐ KÉNYSZER-MARADÉK FÜGGVÉNY (Dimenzióhibák nélkül)
function residuals = internal_residuals(x_free, points_matrix, Geo, L_tierod, pairs, L_upright_pairs, free_indices, target_z9)
    pts = points_matrix;
    k = 1;
    for idx = free_indices
        pts(idx, :) = x_free(k : k+2);
        k = k + 3;
    end
    
    % 1. Lengőkar ágak hossztartása (Chassis gömbfejek fixek)
    r(1) = norm(pts(3, :) - pts(1, :)) - Geo.L13;
    r(2) = norm(pts(3, :) - pts(2, :)) - Geo.L23;
    r(3) = norm(pts(6, :) - pts(4, :)) - Geo.L46;
    r(4) = norm(pts(6, :) - pts(5, :)) - Geo.L56;
    
    % 2. Kormányösszekötő (Tie rod) hossza
    r(5) = norm(pts(8, :) - pts(7, :)) - L_tierod;
    
    % 3. Csonkállvány merevségi kényszerei a te logikád szerint
    % (Biztosítja, hogy P3, P6, P8, P9 távolsága zéró torzulást szenvedjen)
    for k_pair = 1:size(pairs,1)
        r(5 + k_pair) = norm(pts(pairs(k_pair,2), :) - pts(pairs(k_pair,1), :)) - L_upright_pairs(k_pair);
    end
    
    % Kimeneti vektor építése + Kerékközép magasság kényszer
    residuals = zeros(length(r) + 1, 1);
    for i = 1:length(r)
        residuals(i) = r(i);
    end
    residuals(end) = pts(9, 3) - target_z9;
end

% A te SVD-alapú kerékszög követő algoritmusod
function toe_deg = compute_toe_via_svd(pts, Geo)
    B_curr = pts(Geo.upright_pts_idx, :)';
    muB = mean(B_curr, 2);
    H = (Geo.A_static - Geo.muA) * (B_curr - muB)';
    [U, ~, V] = svd(H);
    R = V * U';
    if det(R) < 0, R = V * diag([1, 1, -1]) * U'; end
    unit_normal = R * Geo.initial_normal;
    
    % Kormányszög (Toe) abszolút értéke pontosan a te képleted alapján
    toe_deg = -rad2deg(atan2(unit_normal(1), unit_normal(2)));
    toe_deg = abs(toe_deg); 
end