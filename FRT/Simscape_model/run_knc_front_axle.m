function [simOut, result] = run_knc_front_axle(scenario)
%RUN_KNC_FRONT_AXLE Simulate a normal or combined K&C front-axle case.

if nargin < 1
    scenario = 'normal';
end
knc_front_axle_init;

switch lower(scenario)
    case 'normal'
        command = [0.015, 0.00, 0.00];
    case 'combined'
        command = [0.030, 0.25, 0.07];
    otherwise
        error('run_knc_front_axle:UnknownScenario', ...
            'Use ''normal'' or ''combined''.');
end

modelPath = fullfile(fileparts(mfilename('fullpath')), ...
    'Testrig', 'Kinematics', 'Kinematics_Front_Axle.slx');
open_system(modelPath);
model = 'Kinematics_Front_Axle';
input = frontAxleInput(command, [], [], 2);
simIn = Simulink.SimulationInput(model);
simIn = simIn.setExternalInput(input);
simOut = sim(simIn);
result = postprocess_knc_front_axle(simOut);

if result.minClearance <= 0
    error('run_knc_front_axle:UnexpectedContact', ...
        'The %s scenario unexpectedly contacts.', scenario);
end
fprintf('%s: min clearance = %.6f m, contact = %d, first contact = %.6f s\n', ...
    scenario, result.minClearance, result.contactFlag, result.firstContactTime);
end

function input = frontAxleInput(command, loadForce, loadTorque, stopTime)
time = [0; stopTime];
input = Simulink.SimulationData.Dataset;
input = input.addElement(timeseries(repmat(command(1), 2, 1), time), 'Cmd_Jounce');
input = input.addElement(timeseries(repmat(command(2), 2, 1), time), 'Cmd_Steer');
input = input.addElement(timeseries(repmat(command(3), 2, 1), time), 'Cmd_Camber');
if ~isempty(loadForce)
    input = input.addElement(timeseries(repmat(loadForce(:).', 2, 1), time), 'Load_Force');
    input = input.addElement(timeseries(repmat(loadTorque(:).', 2, 1), time), 'Load_Torque');
end
end
