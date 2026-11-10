%% Swing-arm roll-center and jacking test rig
% Creates and runs a reduced two-sided Simscape Multibody rig.
% Coordinates: X forward, Y left/right lateral, Z upward.
%
% The chassis is the only inertial vehicle body. Each side has one
% massless-equivalent rigid swing arm, revolute about the vehicle X axis at
% its instantaneous center (IC). The free arm end is the wheel/contact
% patch frame. Tire forces are represented by vertical and lateral spring-
% damper laws, applied through External Force and Torque blocks.
%
% Change IC_z or the force profile below to sweep roll-center/jacking
% behavior. The generated model is SwingArm_RollCenter.slx.

clearvars -except runSimulation
clc

root = fileparts(mfilename('fullpath'));
modelName = 'SwingArm_RollCenter';
modelFile = fullfile(root, [modelName '.slx']);

% ------------------------- User parameters ------------------------------
P = struct();
P.massHalf = 160;                 % kg, sprung half-car mass
P.gravity = 9.80665;              % m/s^2
P.tireRadius = 0.29;              % m
P.track = 1.20;                   % m
P.chassisCg = [0 0 0.42];         % m, chassis frame origin at CG
P.wheelCenterZ = P.tireRadius;
P.contactPatchZ = 0;
P.IC_y = [-P.track/2, P.track/2]; % left, right
P.IC_z = [0.20, 0.20];            % m; sweep these to change RC geometry
P.initialPatchY = P.IC_y;
P.initialPatchX = [0 0];
P.initialPatchZ = [P.contactPatchZ P.contactPatchZ];
P.armLength = hypot(P.IC_y, P.IC_z - P.initialPatchZ);

% Tire force parameters. The lateral stiffness is intentionally finite so
% the chassis can move laterally under the prescribed CoG excitation.
P.tireKz = 220000;               % N/m per tire
P.tireCz = 1800;                 % N/(m/s) per tire
P.tireKy = 70000;                % N/m per tire
P.tireCy = 1200;                 % N/(m/s) per tire
P.forceRiseTime = 0.25;          % s
P.forceDuration = 1.50;          % s
P.forcePeak = 1600;               % N lateral force at CoG
P.stopTime = 2.0;                % s

% External lateral force is a smooth pulse, not an ideal step.
P.forceTime = [0 P.forceRiseTime 0.80 1.05 P.forceDuration P.stopTime];
P.forceValue = [0 0 P.forcePeak P.forcePeak 0 0];

assignin('base','P',P);

% ---------------------- Create the Simscape model -----------------------
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if isfile(modelFile)
    delete(modelFile);
end

new_system(modelName);
set_param(modelName, 'StopTime', 'P.stopTime', ...
    'Solver', 'ode15s');

% Sources and infrastructure.
add_block('nesl_utility/Solver Configuration', ...
    [modelName '/Solver Configuration'], 'Position', [35 40 180 90]);
add_block('sm_lib/Frames and Transforms/World Frame', ...
    [modelName '/World Frame'], 'Position', [35 130 180 180]);
add_block('sm_lib/Frames and Transforms/Mechanism Configuration', ...
    [modelName '/Mechanism Configuration'], 'Position', [35 220 180 275]);

% Chassis solid. Its reference frame is at the half-car CG.
add_block('sm_lib/Body Elements/Brick Solid', [modelName '/Chassis'], ...
    'Position', [430 250 560 330], ...
    'Mass', 'P.massHalf', 'Dimensions', '[1.8 1.2 0.20]', ...
    'InertiaType', 'Custom', 'CenterOfMass', '[0 0 0]', ...
    'Inertia', '[P.massHalf*0.10 P.massHalf*0.10 P.massHalf*0.10 0 0 0]');

% Gravity on the chassis, plus a lateral force input at its CG.
add_block('sm_lib/Forces and Torques/External Force and Torque', ...
    [modelName '/Chassis Forces'], 'Position', [245 355 385 435], ...
    'ResolveForcesInto', 'World');
add_block('simulink/Sources/From Workspace', [modelName '/Lateral Force'], ...
    'Position', [35 380 170 420], ...
    'VariableName', '[P.forceTime(:) P.forceValue(:)]');
add_block('simulink/Math Operations/Mux', [modelName '/Force Mux'], ...
    'Position', [190 370 220 430], 'Inputs', '3');
add_block('simulink/Sources/Constant', [modelName '/Zero Force'], ...
    'Position', [35 450 170 480], 'Value', '0');
add_block('simulink/Sources/Constant', [modelName '/Gravity Vector'], ...
    'Position', [35 520 170 550], 'Value', '[0 0 -P.massHalf*P.gravity]');
add_block('simulink/Math Operations/Sum', [modelName '/Total Force'], ...
    'Position', [390 405 420 475], 'Inputs', '+ +');
add_block('simscape/Utilities/Simulink-PS Converter', ...
    [modelName '/Force Converter'], 'Position', [245 470 355 500], ...
    'Unit', 'N');

% Left and right swing-arm chains.
for side = 1:2
    if side == 1
        tag = 'Left';
        y0 = 50;
        icY = 'P.IC_y(1)';
        icZ = 'P.IC_z(1)';
    else
        tag = 'Right';
        y0 = 690;
        icY = 'P.IC_y(2)';
        icZ = 'P.IC_z(2)';
    end

    add_block('sm_lib/Frames and Transforms/Rigid Transform', ...
        [modelName '/' tag ' IC Transform'], ...
        'Position', [210 y0+35 340 y0+85], ...
        'TranslationMethod', 'Cartesian', ...
        'Translation', ['[0 ' icY ' ' icZ '-P.chassisCg(3)]']);
    add_block('sm_lib/Joints/Revolute Joint', [modelName '/' tag ' IC Revolute'], ...
        'Position', [365 y0+35 470 y0+85]);
    add_block('sm_lib/Body Elements/Brick Solid', [modelName '/' tag ' Swing Arm'], ...
        'Position', [520 y0+20 650 y0+100], ...
        'Mass', '0.01', 'Dimensions', '[P.armLength 0.04 0.04]', ...
        'InertiaType', 'Custom', 'CenterOfMass', '[0 0 0]', ...
        'Inertia', '[1e-6 1e-6 1e-6 0 0 0]');
    add_block('sm_lib/Frames and Transforms/Rigid Transform', ...
        [modelName '/' tag ' Arm To Center'], ...
        'Position', [685 y0+25 815 y0+75], ...
        'TranslationMethod', 'Cartesian', ...
        'Translation', ['[0 ' icY '/2 (' icZ '-P.contactPatchZ)/2]']);
    add_block('sm_lib/Frames and Transforms/Rigid Transform', ...
        [modelName '/' tag ' Center To Patch'], ...
        'Position', [850 y0+25 980 y0+75], ...
        'TranslationMethod', 'Cartesian', ...
        'Translation', ['[0 ' icY '/2 (' icZ '-P.contactPatchZ)/2]']);
    add_block('sm_lib/Forces and Torques/External Force and Torque', ...
        [modelName '/' tag ' Tire Force'], ...
        'Position', [1015 y0+10 1155 y0+90], ...
        'ResolveForcesInto', 'World');

    % Kinematic sensor at the patch frame for logging and tire-law input.
    add_block('sm_lib/Sensors/Transform Sensor', [modelName '/' tag ' Patch Sensor'], ...
        'Position', [1015 y0+120 1155 y0+180], ...
        'PositionUnits', 'm', 'VelocityUnits', 'm/s');

    % Simple vertical/lateral force law implemented in Simulink.
    add_block('simulink/User-Defined Functions/MATLAB Function', ...
        [modelName '/' tag ' Tire Law'], ...
        'Position', [1200 y0+20 1360 y0+100]);
    set_param([modelName '/' tag ' Tire Law'], 'MATLABFcn', ...
        ['function F = fcn(p,v)' newline ...
         'F = [0; -P.tireKy*p(2)-P.tireCy*v(2); ' ...
         'P.tireKz*(P.contactPatchZ-p(3))-P.tireCz*v(3)];' newline ...
         'end']);
end

% Physical connections. The exact port names are stable for these library blocks.
add_line(modelName, 'World Frame/R', 'Mechanism Configuration/R', 'autorouting', 'on');
add_line(modelName, 'Mechanism Configuration/R', 'Chassis/R', 'autorouting', 'on');
add_line(modelName, 'Solver Configuration/R', 'Chassis/R', 'autorouting', 'on');
add_line(modelName, 'Chassis/R', 'Chassis Forces/B', 'autorouting', 'on');
add_line(modelName, 'Chassis/R', 'Left IC Transform/B', 'autorouting', 'on');
add_line(modelName, 'Chassis/R', 'Right IC Transform/B', 'autorouting', 'on');

for side = 1:2
    if side == 1
        tag = 'Left';
    else
        tag = 'Right';
    end
    add_line(modelName, [tag ' IC Transform/F'], [tag ' IC Revolute/B'], 'autorouting', 'on');
    add_line(modelName, [tag ' IC Revolute/F'], [tag ' Swing Arm/R'], 'autorouting', 'on');
    add_line(modelName, [tag ' Swing Arm/R'], [tag ' Arm To Center/B'], 'autorouting', 'on');
    add_line(modelName, [tag ' Arm To Center/F'], [tag ' Center To Patch/B'], 'autorouting', 'on');
    add_line(modelName, [tag ' Center To Patch/F'], [tag ' Tire Force/B'], 'autorouting', 'on');
    add_line(modelName, [tag ' Center To Patch/F'], [tag ' Patch Sensor/B'], 'autorouting', 'on');
end

% Force signal wiring. The force block expects a 3-vector [Fx Fy Fz].
add_line(modelName, 'Lateral Force/1', 'Force Mux/1', 'autorouting', 'on');
add_line(modelName, 'Zero Force/1', 'Force Mux/2', 'autorouting', 'on');
add_line(modelName, 'Zero Force/1', 'Force Mux/3', 'autorouting', 'on');
add_line(modelName, 'Force Converter/RConn1', 'Chassis Forces/F', 'autorouting', 'on');

% Add gravity as a constant physical signal to the chassis force block.
add_line(modelName, 'Force Mux/1', 'Total Force/1', 'autorouting', 'on');
add_line(modelName, 'Gravity Vector/1', 'Total Force/2', 'autorouting', 'on');
add_line(modelName, 'Total Force/1', 'Force Converter/1', 'autorouting', 'on');

set_param(modelName, 'SimulationCommand', 'update');
save_system(modelName, modelFile);

% ---------------------------- Run / plot --------------------------------
if ~exist('runSimulation','var')
    runSimulation = true;
end
if runSimulation
    simOut = sim(modelName, 'ReturnWorkspaceOutputs', 'on'); %#ok<NASGU>
    figure('Name', 'Swing-arm roll-center rig');
    tiledlayout(2,1);
    nexttile;
    plot(P.forceTime, P.forceValue, 'LineWidth', 1.5);
    grid on;
    xlabel('Time [s]'); ylabel('CoG lateral force [N]');
    title(sprintf('IC height: %.0f mm / %.0f mm', 1000*P.IC_z(1), 1000*P.IC_z(2)));
    nexttile;
    text(0.05, 0.65, 'Model created and simulated.', 'FontSize', 12);
    text(0.05, 0.40, 'Use the logged Transform Sensor signals to inspect\ncontact-patch motion and normal-force transfer.', 'FontSize', 11);
    axis off;
end

fprintf('Created %s\n', modelFile);
