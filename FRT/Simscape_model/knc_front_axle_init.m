function parameters = knc_front_axle_init
%KNC_FRONT_AXLE_INIT Define the common front-axle K&C parameters.

root = fileparts(mfilename('fullpath'));
addpath(root);

parameters = struct( ...
    'Nominal_Clearance', 0.080, ...
    'Jounce_Clearance_Coeff', 1.00, ...
    'Steer_Clearance_Coeff', 0.12, ...
    'Camber_Clearance_Coeff', 0.10, ...
    'Freeplay_Threshold', 0.010, ...
    'Freeplay_Stiffness', 1.5e5, ...
    'Freeplay_Damping', 1.2e3);

names = fieldnames(parameters);
for index = 1:numel(names)
    assignin('base', names{index}, parameters.(names{index}));
end

kinematicsPath = fullfile(root, 'Testrig', 'Kinematics', 'Kinematics_Front_Axle.slx');
compliancePath = fullfile(root, 'Testrig', 'Kinematics', 'Compliance_Front_Axle.slx');
if ~isfile(kinematicsPath) || ~isfile(compliancePath)
    build_knc_front_axle_models;
end
end
