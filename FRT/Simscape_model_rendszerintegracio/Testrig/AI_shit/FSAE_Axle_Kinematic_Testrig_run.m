%% Run Formula Student single-axle kinematic/compliance test rig
% Loads the Formula Student decoupled vehicle data, runs the two-wheel
% front-axle rig, and plots suspension metrics.

root = fileparts(mfilename('fullpath'));
fsRoot = root;
mwRoot = fullfile(root, '..', 'mathworks-Simscape-Vehicle-Templates-26.1.4.12');

addpath(genpath(fsRoot));
addpath(genpath(mwRoot));

modelFile = fullfile(fsRoot, 'FSAE_Axle_Kinematic_Testrig.slx');
modelName = 'FSAE_Axle_Kinematic_Testrig';

% Add only the model and data folders needed by this rig.
addpath(genpath(fullfile(fsRoot, 'Scripts_Data')));
addpath(genpath(fullfile(fsRoot, 'Libraries')));
addpath(genpath(fullfile(mwRoot, 'Testrigs')));
addpath(genpath(fullfile(mwRoot, 'Libraries')));

% Load the complete FSAE decoupled configuration.
run(fullfile(fsRoot, 'Scripts_Data', 'Data_Vehicle', ...
    'Vehicle_data_decoupled.m'));

load_system(modelFile);
set_param([modelName '/Axle'], 'AxNum', 'Front');

% Use the Formula Student KnC maneuver and disable the driver/passenger
% effects that are irrelevant for suspension kinematics.
Maneuver = sm_car_maneuverdata_knc(0.05, -0.03, 0.01, 1.3, 0.03, ...
    500, 1200, 1200, 1200, 1200, -0.3);
Vehicle = sm_car_vehcfg_setPeopleOnOff(Vehicle, [0 0 0 0 0], 'SuspA1');
sm_car_config_variants(modelName);

simOut = sim(modelName, 'ReturnWorkspaceOutputs', 'on');

% The rig logs its signals in the standard logsout dataset.
logsout = simOut.get('logsout');
AxNum = 1;
TSuspMetrics = sm_car_knc_plot1toecamber(logsout, AxNum, true, true, false);

disp(TSuspMetrics);

close_system(modelName, 0);
