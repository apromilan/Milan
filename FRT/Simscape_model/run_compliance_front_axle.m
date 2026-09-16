function [simOut, result] = run_compliance_front_axle(scenario)
%RUN_COMPLIANCE_FRONT_AXLE Simulate the physical-load/freeplay axle model.

if nargin < 1
    scenario = 'freeplay';
end
knc_front_axle_init;

switch lower(scenario)
    case 'freeplay'
        command = [0.040, 0.20, 0.05];
        loadForce = [0 3500 0];
        loadTorque = [0 0 250];
    otherwise
        error('run_compliance_front_axle:UnknownScenario', ...
            'Use ''freeplay''.');
end

time = [0; 2];
input = Simulink.SimulationData.Dataset;
input = input.addElement(timeseries(repmat(command(1), 2, 1), time), 'Cmd_Jounce');
input = input.addElement(timeseries(repmat(command(2), 2, 1), time), 'Cmd_Steer');
input = input.addElement(timeseries(repmat(command(3), 2, 1), time), 'Cmd_Camber');
input = input.addElement(timeseries(repmat(loadForce, 2, 1), time), 'Load_Force');
input = input.addElement(timeseries(repmat(loadTorque, 2, 1), time), 'Load_Torque');

modelPath = fullfile(fileparts(mfilename('fullpath')), ...
    'Testrig', 'Kinematics', 'Compliance_Front_Axle.slx');
open_system(modelPath);
model = 'Compliance_Front_Axle';
simIn = Simulink.SimulationInput(model);
simIn = simIn.setExternalInput(input);
simOut = sim(simIn);
result = postprocess_knc_front_axle(simOut);
complianceForce = simOut.get('yout').getElement('Compliance_Force').Values.Data(end);
result.complianceForce = complianceForce;

if abs(complianceForce) <= 0
    error('run_compliance_front_axle:FreeplayNotCrossed', ...
        'The freeplay threshold was not crossed.');
end
fprintf('freeplay: compliance force = %.3f N, min clearance = %.6f m, contact = %d\n', ...
    complianceForce, result.minClearance, result.contactFlag);
end
