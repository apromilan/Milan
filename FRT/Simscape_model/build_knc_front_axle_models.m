function build_knc_front_axle_models
%BUILD_KNC_FRONT_AXLE_MODELS Build the front-axle K&C and compliance models.

root = fileparts(mfilename('fullpath'));
assignDefaultParameters;
kinematicsPath = fullfile(root, 'Testrig', 'Kinematics', 'Kinematics_Front_Axle.slx');
compliancePath = fullfile(root, 'Testrig', 'Kinematics', 'Compliance_Front_Axle.slx');
backupPath = fullfile(root, 'Testrig', 'Kinematics', 'Kinematics_Front_Axle_original.slx');

if isfile(kinematicsPath) && ~isfile(backupPath)
    copyfile(kinematicsPath, backupPath);
end

function assignDefaultParameters
defaults = struct( ...
    'Nominal_Clearance', 0.080, ...
    'Jounce_Clearance_Coeff', 1.00, ...
    'Steer_Clearance_Coeff', 0.12, ...
    'Camber_Clearance_Coeff', 0.10, ...
    'Freeplay_Threshold', 0.010, ...
    'Freeplay_Stiffness', 1.5e5, ...
    'Freeplay_Damping', 1.2e3);
names = fieldnames(defaults);
for index = 1:numel(names)
    assignin('base', names{index}, defaults.(names{index}));
end
end

createKinematicsModel(kinematicsPath);
createComplianceModel(compliancePath);
end

function createKinematicsModel(modelPath)
model = 'Kinematics_Front_Axle';
createCleanModel(model, modelPath);

addCommandInports(model, false);
addTwoPointInterface(model);
addCollisionSubsystem(model, 'Collision_Check', [500 120 700 330]);

add_block('simulink/Sinks/Out1', [model '/Left_Command'], ...
    'Position', [760 80 790 100]);
add_block('simulink/Sinks/Out1', [model '/Right_Command'], ...
    'Position', [760 120 790 140]);
add_block('simulink/Sinks/Out1', [model '/Min_Clearance'], ...
    'Position', [760 190 790 210]);
add_block('simulink/Sinks/Out1', [model '/Contact_Flag'], ...
    'Position', [760 230 790 250]);
add_block('simulink/Sinks/Out1', [model '/First_Contact_Time'], ...
    'Position', [760 270 790 290]);

add_line(model, 'Cmd_Jounce/1', 'TwoPoint_Interface/1', 'autorouting', 'on');
add_line(model, 'Cmd_Steer/1', 'TwoPoint_Interface/2', 'autorouting', 'on');
add_line(model, 'Cmd_Camber/1', 'TwoPoint_Interface/3', 'autorouting', 'on');
add_line(model, 'TwoPoint_Interface/1', 'Left_Command/1', 'autorouting', 'on');
add_line(model, 'TwoPoint_Interface/2', 'Right_Command/1', 'autorouting', 'on');

connectCollisionAtRoot(model);
addMultibodyReferenceKernel(model, [80 360 380 520]);
finalizeModel(model, modelPath);
end

function createComplianceModel(modelPath)
model = 'Compliance_Front_Axle';
createCleanModel(model, modelPath);

addCommandInports(model, true);
addTwoPointInterface(model);
addCollisionSubsystem(model, 'Collision_Check', [520 120 720 330]);
addFreeplaySubsystem(model, 'Freeplay_Compliance', [520 370 720 500]);
addPhysicalLoadActuation(model, [760 380 1080 580]);

add_block('simulink/Sinks/Out1', [model '/Left_Command'], ...
    'Position', [800 70 830 90]);
add_block('simulink/Sinks/Out1', [model '/Right_Command'], ...
    'Position', [800 110 830 130]);
add_block('simulink/Sinks/Out1', [model '/Min_Clearance'], ...
    'Position', [800 180 830 200]);
add_block('simulink/Sinks/Out1', [model '/Contact_Flag'], ...
    'Position', [800 220 830 240]);
add_block('simulink/Sinks/Out1', [model '/First_Contact_Time'], ...
    'Position', [800 260 830 280]);
add_block('simulink/Sinks/Out1', [model '/Compliance_Force'], ...
    'Position', [800 450 830 470]);

add_line(model, 'Cmd_Jounce/1', 'TwoPoint_Interface/1', 'autorouting', 'on');
add_line(model, 'Cmd_Steer/1', 'TwoPoint_Interface/2', 'autorouting', 'on');
add_line(model, 'Cmd_Camber/1', 'TwoPoint_Interface/3', 'autorouting', 'on');
add_line(model, 'TwoPoint_Interface/1', 'Left_Command/1', 'autorouting', 'on');
add_line(model, 'TwoPoint_Interface/2', 'Right_Command/1', 'autorouting', 'on');
connectCollisionAtRoot(model);

add_line(model, 'Cmd_Jounce/1', 'Freeplay_Compliance/1', 'autorouting', 'on');
add_line(model, 'Freeplay_Compliance/1', 'Compliance_Force/1', 'autorouting', 'on');
add_line(model, 'Load_Force/1', 'Physical_Load_Actuation/1', 'autorouting', 'on');
add_line(model, 'Load_Torque/1', 'Physical_Load_Actuation/2', 'autorouting', 'on');
add_line(model, 'Freeplay_Compliance/1', 'Physical_Load_Actuation/3', 'autorouting', 'on');

finalizeModel(model, modelPath);
end

function createCleanModel(model, modelPath)
if bdIsLoaded(model)
    close_system(model, 0);
end
if isfile(modelPath)
    delete(modelPath);
end
new_system(model);
open_system(model);
set_param(model, 'StopTime', '2', 'Solver', 'ode23t', ...
    'SaveOutput', 'on', 'SaveFormat', 'Dataset', ...
    'ReturnWorkspaceOutputs', 'on');
end

function addCommandInports(model, includeLoads)
add_block('simulink/Sources/In1', [model '/Cmd_Jounce'], ...
    'Position', [30 80 60 100]);
add_block('simulink/Sources/In1', [model '/Cmd_Steer'], ...
    'Position', [30 120 60 140]);
add_block('simulink/Sources/In1', [model '/Cmd_Camber'], ...
    'Position', [30 160 60 180]);
if includeLoads
    add_block('simulink/Sources/In1', [model '/Load_Force'], ...
        'PortDimensions', '3', 'Position', [30 410 60 430]);
    add_block('simulink/Sources/In1', [model '/Load_Torque'], ...
        'PortDimensions', '3', 'Position', [30 450 60 470]);
end
end

function addTwoPointInterface(model)
subsystem = [model '/TwoPoint_Interface'];
add_block('simulink/Ports & Subsystems/Subsystem', subsystem, ...
    'Position', [250 60 440 190]);
clearSubsystem(subsystem);

add_block('simulink/Sources/In1', [subsystem '/Cmd_Jounce'], ...
    'Position', [25 35 55 55]);
add_block('simulink/Sources/In1', [subsystem '/Cmd_Steer'], ...
    'Position', [25 75 55 95]);
add_block('simulink/Sources/In1', [subsystem '/Cmd_Camber'], ...
    'Position', [25 115 55 135]);
add_block('simulink/Math Operations/Gain', [subsystem '/Right_Steer_Sign'], ...
    'Gain', '-1', 'Position', [110 70 150 100]);
add_block('simulink/Math Operations/Gain', [subsystem '/Right_Camber_Sign'], ...
    'Gain', '-1', 'Position', [110 110 150 140]);
add_block('simulink/Signal Routing/Mux', [subsystem '/Left_Command_Vector'], ...
    'Inputs', '3', 'Position', [200 30 205 85]);
add_block('simulink/Signal Routing/Mux', [subsystem '/Right_Command_Vector'], ...
    'Inputs', '3', 'Position', [200 100 205 155]);
add_block('simulink/Sinks/Out1', [subsystem '/Left_Command'], ...
    'Position', [270 50 300 70]);
add_block('simulink/Sinks/Out1', [subsystem '/Right_Command'], ...
    'Position', [270 125 300 145]);

add_line(subsystem, 'Cmd_Jounce/1', 'Left_Command_Vector/1');
add_line(subsystem, 'Cmd_Steer/1', 'Left_Command_Vector/2');
add_line(subsystem, 'Cmd_Camber/1', 'Left_Command_Vector/3');
add_line(subsystem, 'Cmd_Jounce/1', 'Right_Command_Vector/1');
add_line(subsystem, 'Cmd_Steer/1', 'Right_Steer_Sign/1');
add_line(subsystem, 'Right_Steer_Sign/1', 'Right_Command_Vector/2');
add_line(subsystem, 'Cmd_Camber/1', 'Right_Camber_Sign/1');
add_line(subsystem, 'Right_Camber_Sign/1', 'Right_Command_Vector/3');
add_line(subsystem, 'Left_Command_Vector/1', 'Left_Command/1');
add_line(subsystem, 'Right_Command_Vector/1', 'Right_Command/1');
end

function addCollisionSubsystem(model, name, position)
subsystem = [model '/' name];
add_block('simulink/Ports & Subsystems/Subsystem', subsystem, ...
    'Position', position);
clearSubsystem(subsystem);

add_block('simulink/Sources/In1', [subsystem '/Cmd_Jounce'], ...
    'Position', [20 30 50 50]);
add_block('simulink/Sources/In1', [subsystem '/Cmd_Steer'], ...
    'Position', [20 70 50 90]);
add_block('simulink/Sources/In1', [subsystem '/Cmd_Camber'], ...
    'Position', [20 110 50 130]);
add_block('simulink/Math Operations/Abs', [subsystem '/Abs_Jounce'], ...
    'Position', [85 25 115 55]);
add_block('simulink/Math Operations/Abs', [subsystem '/Abs_Steer'], ...
    'Position', [85 65 115 95]);
add_block('simulink/Math Operations/Abs', [subsystem '/Abs_Camber'], ...
    'Position', [85 105 115 135]);
add_block('simulink/Math Operations/Gain', [subsystem '/Jounce_Clearance_Loss'], ...
    'Gain', 'Jounce_Clearance_Coeff', 'Position', [145 25 190 55]);
add_block('simulink/Math Operations/Gain', [subsystem '/Steer_Clearance_Loss'], ...
    'Gain', 'Steer_Clearance_Coeff', 'Position', [145 65 190 95]);
add_block('simulink/Math Operations/Gain', [subsystem '/Camber_Clearance_Loss'], ...
    'Gain', 'Camber_Clearance_Coeff', 'Position', [145 105 190 135]);
add_block('simulink/Sources/Constant', [subsystem '/Nominal_Clearance'], ...
    'Value', 'Nominal_Clearance', 'Position', [145 160 190 180]);
add_block('simulink/Math Operations/Sum', [subsystem '/Clearance_Sum'], ...
    'Inputs', '+---', 'Position', [245 65 275 145]);
add_block('simulink/Sources/Constant', [subsystem '/Zero'], ...
    'Value', '0', 'Position', [315 105 345 125]);
add_block('simulink/Logic and Bit Operations/Relational Operator', ...
    [subsystem '/Contact_Compare'], 'Operator', '<=', ...
    'Position', [375 90 420 120]);
add_block('simulink/Discrete/Unit Delay', [subsystem '/First_Contact_Memory'], ...
    'InitialCondition', '-1', 'Position', [490 180 525 210]);
add_block('simulink/Logic and Bit Operations/Relational Operator', ...
    [subsystem '/Unset_Compare'], 'Operator', '<', ...
    'Position', [555 170 600 200]);
add_block('simulink/Logic and Bit Operations/Logical Operator', ...
    [subsystem '/New_Contact'], 'Operator', 'AND', ...
    'Position', [630 125 670 165]);
add_block('simulink/Sources/Clock', [subsystem '/Clock'], ...
    'Position', [630 205 660 225]);
add_block('simulink/Signal Routing/Switch', [subsystem '/First_Contact_Switch'], ...
    'Criteria', 'u2 ~= 0', 'Threshold', '0', ...
    'Position', [705 160 745 215]);
add_block('simulink/Sinks/Out1', [subsystem '/Min_Clearance'], ...
    'Position', [475 75 505 95]);
add_block('simulink/Sinks/Out1', [subsystem '/Contact_Flag'], ...
    'Position', [475 110 505 130]);
add_block('simulink/Sinks/Out1', [subsystem '/First_Contact_Time'], ...
    'Position', [805 180 835 200]);

add_line(subsystem, 'Cmd_Jounce/1', 'Abs_Jounce/1');
add_line(subsystem, 'Cmd_Steer/1', 'Abs_Steer/1');
add_line(subsystem, 'Cmd_Camber/1', 'Abs_Camber/1');
add_line(subsystem, 'Abs_Jounce/1', 'Jounce_Clearance_Loss/1');
add_line(subsystem, 'Abs_Steer/1', 'Steer_Clearance_Loss/1');
add_line(subsystem, 'Abs_Camber/1', 'Camber_Clearance_Loss/1');
add_line(subsystem, 'Nominal_Clearance/1', 'Clearance_Sum/1');
add_line(subsystem, 'Jounce_Clearance_Loss/1', 'Clearance_Sum/2');
add_line(subsystem, 'Steer_Clearance_Loss/1', 'Clearance_Sum/3');
add_line(subsystem, 'Camber_Clearance_Loss/1', 'Clearance_Sum/4');
add_line(subsystem, 'Clearance_Sum/1', 'Min_Clearance/1');
add_line(subsystem, 'Clearance_Sum/1', 'Contact_Compare/1');
add_line(subsystem, 'Zero/1', 'Contact_Compare/2');
add_line(subsystem, 'Contact_Compare/1', 'Contact_Flag/1');
add_line(subsystem, 'First_Contact_Memory/1', 'Unset_Compare/1');
add_line(subsystem, 'Zero/1', 'Unset_Compare/2');
add_line(subsystem, 'Contact_Compare/1', 'New_Contact/1');
add_line(subsystem, 'Unset_Compare/1', 'New_Contact/2');
add_line(subsystem, 'Clock/1', 'First_Contact_Switch/1');
add_line(subsystem, 'New_Contact/1', 'First_Contact_Switch/2');
add_line(subsystem, 'First_Contact_Memory/1', 'First_Contact_Switch/3');
add_line(subsystem, 'First_Contact_Switch/1', 'First_Contact_Memory/1');
add_line(subsystem, 'First_Contact_Switch/1', 'First_Contact_Time/1');
end

function connectCollisionAtRoot(model)
add_line(model, 'Cmd_Jounce/1', 'Collision_Check/1', 'autorouting', 'on');
add_line(model, 'Cmd_Steer/1', 'Collision_Check/2', 'autorouting', 'on');
add_line(model, 'Cmd_Camber/1', 'Collision_Check/3', 'autorouting', 'on');
add_line(model, 'Collision_Check/1', 'Min_Clearance/1', 'autorouting', 'on');
add_line(model, 'Collision_Check/2', 'Contact_Flag/1', 'autorouting', 'on');
add_line(model, 'Collision_Check/3', 'First_Contact_Time/1', 'autorouting', 'on');
end

function addFreeplaySubsystem(model, name, position)
subsystem = [model '/' name];
add_block('simulink/Ports & Subsystems/Subsystem', subsystem, 'Position', position);
clearSubsystem(subsystem);
add_block('simulink/Sources/In1', [subsystem '/Relative_Travel'], ...
    'Position', [25 45 55 65]);
add_block('simulink/Sources/Constant', [subsystem '/Zero_Velocity'], ...
    'Value', '0', 'Position', [25 95 55 115]);
add_block('simulink/Math Operations/Abs', [subsystem '/Travel_Magnitude'], ...
    'Position', [95 40 125 70]);
add_block('simulink/Sources/Constant', [subsystem '/Freeplay_Threshold_Value'], ...
    'Value', 'Freeplay_Threshold', 'Position', [95 95 135 115]);
add_block('simulink/Math Operations/Sum', [subsystem '/Excess_Travel'], ...
    'Inputs', '+-', 'Position', [160 55 190 85]);
add_block('simulink/Discontinuities/Saturation', [subsystem '/Freeplay_Deadzone'], ...
    'UpperLimit', 'inf', 'LowerLimit', '0', 'Position', [225 55 270 85]);
add_block('simulink/Math Operations/Gain', [subsystem '/Freeplay_Spring'], ...
    'Gain', 'Freeplay_Stiffness', 'Position', [305 55 350 85]);
add_block('simulink/Math Operations/Gain', [subsystem '/Freeplay_Damper'], ...
    'Gain', 'Freeplay_Damping', 'Position', [305 110 350 140]);
add_block('simulink/Math Operations/Sum', [subsystem '/Force_Magnitude'], ...
    'Inputs', '++', 'Position', [385 75 415 125]);
add_block('simulink/Math Operations/Sign', [subsystem '/Travel_Sign'], ...
    'Position', [225 15 270 40]);
add_block('simulink/Math Operations/Product', [subsystem '/Signed_Force'], ...
    'Position', [450 65 480 105]);
add_block('simulink/Sinks/Out1', [subsystem '/Compliance_Force'], ...
    'Position', [525 75 555 95]);
add_line(subsystem, 'Relative_Travel/1', 'Travel_Magnitude/1');
add_line(subsystem, 'Travel_Magnitude/1', 'Excess_Travel/1');
add_line(subsystem, 'Freeplay_Threshold_Value/1', 'Excess_Travel/2');
add_line(subsystem, 'Excess_Travel/1', 'Freeplay_Deadzone/1');
add_line(subsystem, 'Freeplay_Deadzone/1', 'Freeplay_Spring/1');
add_line(subsystem, 'Zero_Velocity/1', 'Freeplay_Damper/1');
add_line(subsystem, 'Freeplay_Spring/1', 'Force_Magnitude/1');
add_line(subsystem, 'Freeplay_Damper/1', 'Force_Magnitude/2');
add_line(subsystem, 'Relative_Travel/1', 'Travel_Sign/1');
add_line(subsystem, 'Travel_Sign/1', 'Signed_Force/1');
add_line(subsystem, 'Force_Magnitude/1', 'Signed_Force/2');
add_line(subsystem, 'Signed_Force/1', 'Compliance_Force/1');
end

function addPhysicalLoadActuation(model, position)
subsystem = [model '/Physical_Load_Actuation'];
add_block('simulink/Ports & Subsystems/Subsystem', subsystem, 'Position', position);
clearSubsystem(subsystem);
load_system('sm_lib');

add_block('simulink/Sources/In1', [subsystem '/Load_Force'], ...
    'PortDimensions', '3', 'Position', [20 35 50 55]);
add_block('simulink/Sources/In1', [subsystem '/Load_Torque'], ...
    'PortDimensions', '3', 'Position', [20 75 50 95]);
add_block('simulink/Sources/In1', [subsystem '/Freeplay_Force'], ...
    'Position', [20 115 50 135]);
add_block('simulink/Sources/Constant', [subsystem '/Force_X_Zero'], ...
    'Value', '0', 'Position', [85 105 115 125]);
add_block('simulink/Sources/Constant', [subsystem '/Force_Z_Zero'], ...
    'Value', '0', 'Position', [85 145 115 165]);
add_block('simulink/Signal Routing/Mux', [subsystem '/Freeplay_Force_Vector'], ...
    'Inputs', '3', 'Position', [150 105 155 165]);
add_block('simulink/Math Operations/Sum', [subsystem '/Total_Force'], ...
    'Inputs', '++', 'Position', [200 42 230 88]);
add_block('nesl_utility/Simulink-PS Converter', [subsystem '/Force_PS'], ...
    'Position', [270 40 320 70]);
add_block('nesl_utility/Simulink-PS Converter', [subsystem '/Torque_PS'], ...
    'Position', [270 85 320 115]);
add_block('sm_lib/Frames and Transforms/World Frame', [subsystem '/World'], ...
    'Position', [390 150 430 190]);
add_block('sm_lib/Utilities/Mechanism Configuration', [subsystem '/Mechanism_Configuration'], ...
    'Position', [390 235 450 275]);
add_block('nesl_utility/Solver Configuration', [subsystem '/Solver_Configuration'], ...
    'Position', [390 290 450 330]);
add_block('sm_lib/Forces and Torques/External Force and Torque', ...
    [subsystem '/External_Force_and_Torque'], 'Position', [470 80 585 210]);
set_param([subsystem '/External_Force_and_Torque'], ...
    'EnableForce', 'on', 'EnableTorque', 'on');
add_block('sm_lib/Joints/6-DOF Joint', [subsystem '/Free_Body_Joint'], ...
    'Position', [525 245 595 295]);
add_block('sm_lib/Body Elements/Brick Solid', [subsystem '/Load_Body'], ...
    'Position', [650 120 710 180]);

add_line(subsystem, 'Force_X_Zero/1', 'Freeplay_Force_Vector/1');
add_line(subsystem, 'Freeplay_Force/1', 'Freeplay_Force_Vector/2');
add_line(subsystem, 'Force_Z_Zero/1', 'Freeplay_Force_Vector/3');
add_line(subsystem, 'Load_Force/1', 'Total_Force/1');
add_line(subsystem, 'Freeplay_Force_Vector/1', 'Total_Force/2');
add_line(subsystem, 'Total_Force/1', 'Force_PS/1');
add_line(subsystem, 'Load_Torque/1', 'Torque_PS/1');

forcePS = get_param([subsystem '/Force_PS'], 'PortHandles');
torquePS = get_param([subsystem '/Torque_PS'], 'PortHandles');
external = get_param([subsystem '/External_Force_and_Torque'], 'PortHandles');
world = get_param([subsystem '/World'], 'PortHandles');
solid = get_param([subsystem '/Load_Body'], 'PortHandles');
solver = get_param([subsystem '/Solver_Configuration'], 'PortHandles');
transform = get_param([subsystem '/Free_Body_Joint'], 'PortHandles');
add_line(subsystem, forcePS.RConn, external.LConn(1));
add_line(subsystem, torquePS.RConn, external.LConn(2));
add_line(subsystem, world.RConn, transform.LConn);
add_line(subsystem, transform.RConn, solid.RConn);
add_line(subsystem, external.RConn, solid.RConn);
add_line(subsystem, solver.RConn, world.RConn);
end

function addMultibodyReferenceKernel(model, position)
subsystem = [model '/Multibody_Reference_Kernel'];
add_block('simulink/Ports & Subsystems/Subsystem', subsystem, 'Position', position);
clearSubsystem(subsystem);
load_system('sm_lib');
add_block('sm_lib/Frames and Transforms/World Frame', [subsystem '/World'], ...
    'Position', [40 80 80 120]);
add_block('sm_lib/Utilities/Mechanism Configuration', [subsystem '/Mechanism_Configuration'], ...
    'Position', [40 175 100 215]);
add_block('nesl_utility/Solver Configuration', [subsystem '/Solver_Configuration'], ...
    'Position', [40 240 100 280]);
add_block('sm_lib/Frames and Transforms/Rigid Transform', [subsystem '/Rigid_Transform'], ...
    'Position', [150 75 220 125]);
add_block('sm_lib/Body Elements/Brick Solid', [subsystem '/Reference_Body'], ...
    'Position', [290 75 350 135]);
world = get_param([subsystem '/World'], 'PortHandles');
transform = get_param([subsystem '/Rigid_Transform'], 'PortHandles');
solid = get_param([subsystem '/Reference_Body'], 'PortHandles');
solver = get_param([subsystem '/Solver_Configuration'], 'PortHandles');
add_line(subsystem, world.RConn, transform.LConn);
add_line(subsystem, transform.RConn, solid.RConn);
add_line(subsystem, solver.RConn, world.RConn);
end

function clearSubsystem(subsystem)
lines = find_system(subsystem, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
if ~isempty(lines)
    delete_line(lines);
end
blocks = find_system(subsystem, 'SearchDepth', 1, 'Type', 'Block');
for index = 2:numel(blocks)
    delete_block(blocks{index});
end
end

function finalizeModel(model, modelPath)
set_param(model, 'SimulationCommand', 'update');
save_system(model, modelPath);
close_system(model, 0);
end
