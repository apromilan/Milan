function FRT_build_models(FRT)
%FRT_BUILD_MODELS Build the two empty suspension model files once.
root = fileparts(mfilename('fullpath'));
models = {fullfile(root, 'half_vehicle_kinematics.slx'), ...
    fullfile(root, 'half_vehicle_KnC.slx')};
for index = 1:numel(models)
    model = models{index};
    [~, modelName] = fileparts(model);
    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(model);
    modelWorkspace = get_param(modelName, 'ModelWorkspace');
    modelWorkspace.assignin('FRT', FRT);
    modelWorkspace.assignin('FRT_geometry', FRT.geometry);
    modelWorkspace.assignin('FRT_suspension', FRT.suspension);
    modelWorkspace.assignin('FRT_collision', FRT.collision);
    modelWorkspace.assignin('FRT_tire', FRT.tire);
    modelWorkspace.assignin('FRT_forceApplication', FRT.forceApplication);
    modelData = get_param(modelName, 'UserData');
    isGenerated = isstruct(modelData) && isfield(modelData, 'FRTGenerated') && ...
        modelData.FRTGenerated;
    if ~isGenerated
        rootBlocks = find_system(modelName, 'SearchDepth', 1, 'Type', 'Block');
        delete_block(rootBlocks(~strcmp(rootBlocks, modelName)));
        if index == 1
            localBuildKinematics(modelName);
        else
            localBuildKnC(modelName);
        end
        set_param(modelName, 'UserDataPersistent', 'on', ...
            'UserData', struct('FRTGenerated', true));
    end
    save_system(modelName, model);
    close_system(modelName, 0);
end
end

function localBuildKinematics(modelName)
add_block('simulink/Ports & Subsystems/In1', [modelName '/WheelTravel'], ...
    'Position', [30 80 80 110]);
add_block('simulink/Ports & Subsystems/In1', [modelName '/Steering'], ...
    'Position', [30 150 80 180]);
add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/KinematicsCore'], ...
    'Position', [150 70 330 190]);
add_block('simulink/User-Defined Functions/Fcn', ...
    [modelName '/CollisionCheck'], 'Expr', ...
    'FRT_collision_eval(u,u,FRT_collision.pairs(1).clearance,FRT_collision.pairs(1).radius,FRT_collision.penalty.stiffness,FRT_collision.penalty.damping)', ...
    'Position', [390 90 600 140]);
add_block('simulink/User-Defined Functions/Fcn', ...
    [modelName '/CollisionPenalty'], 'Expr', ...
    'FRT_collision_penalty(u,FRT_collision.pairs(1).clearance,FRT_collision.pairs(1).radius,FRT_collision.penalty.stiffness)', ...
    'Position', [390 160 600 210]);
add_block('simulink/Signal Routing/Mux', [modelName '/CollisionInputs'], ...
    'Inputs', '2', 'Position', [260 240 290 290]);
add_block('simulink/Ports & Subsystems/Out1', [modelName '/CollisionDistance'], ...
    'Position', [670 90 750 120]);
add_block('simulink/Ports & Subsystems/Out1', [modelName '/CollisionPenaltyOut'], ...
    'Position', [670 155 750 185]);
add_line(modelName, 'WheelTravel/1', 'KinematicsCore/1');
add_line(modelName, 'Steering/1', 'KinematicsCore/2');
add_line(modelName, 'WheelTravel/1', 'CollisionInputs/1');
add_line(modelName, 'Steering/1', 'CollisionInputs/2');
add_line(modelName, 'CollisionInputs/1', 'CollisionCheck/1');
add_line(modelName, 'CollisionCheck/1', 'CollisionDistance/1');
add_line(modelName, 'CollisionCheck/1', 'CollisionPenalty/1');
add_line(modelName, 'CollisionPenalty/1', 'CollisionPenaltyOut/1');
localBuildKinematicsCore([modelName '/KinematicsCore']);
end

function localBuildKinematicsCore(path)
add_block('simulink/Ports & Subsystems/In1', [path '/Travel'], 'Position', [30 40 60 70]);
add_block('simulink/Ports & Subsystems/In1', [path '/Steering'], 'Position', [30 110 60 140]);
add_block('simulink/Ports & Subsystems/Out1', [path '/SegmentA'], 'Position', [250 40 290 70]);
add_block('simulink/Ports & Subsystems/Out1', [path '/SegmentB'], 'Position', [250 110 290 140]);
add_block('simulink/Math Operations/Gain', [path '/TravelGain'], 'Gain', '1', 'Position', [110 35 180 75]);
add_block('simulink/Math Operations/Gain', [path '/SteeringGain'], 'Gain', '1', 'Position', [110 105 180 145]);
add_line(path, 'Travel/1', 'TravelGain/1');
add_line(path, 'TravelGain/1', 'SegmentA/1');
add_line(path, 'Steering/1', 'SteeringGain/1');
add_line(path, 'SteeringGain/1', 'SegmentB/1');
end

function localBuildKnC(modelName)
add_block('simulink/Ports & Subsystems/In1', [modelName '/WheelTravel'], ...
    'Position', [30 60 80 90]);
add_block('simulink/Ports & Subsystems/In1', [modelName '/Steering'], ...
    'Position', [30 120 80 150]);
add_block('simulink/Ports & Subsystems/In1', [modelName '/NormalLoad'], ...
    'Position', [30 180 80 210]);
add_block('simulink/Ports & Subsystems/Subsystem', [modelName '/KnCCore'], ...
    'Position', [150 55 340 220]);
add_block('simulink/Lookup Tables/2-D Lookup Table', [modelName '/LongitudinalTireForce'], ...
    'BreakpointsForDimension1', 'FRT_tire.longitudinal.slip', ...
    'BreakpointsForDimension2', 'FRT_tire.longitudinal.normalLoad', ...
    'Table', 'FRT_tire.longitudinal.force', 'Position', [410 50 570 115]);
add_block('simulink/Lookup Tables/2-D Lookup Table', [modelName '/LateralTireForce'], ...
    'BreakpointsForDimension1', 'FRT_tire.lateral.slipAngle', ...
    'BreakpointsForDimension2', 'FRT_tire.lateral.normalLoad', ...
    'Table', 'FRT_tire.lateral.force', 'Position', [410 150 570 215]);
add_block('simulink/User-Defined Functions/Fcn', [modelName '/Compliance'], ...
    'Expr', 'FRT_compliance_eval(u(1:3),u(4:6),FRT_suspension.front.freePlay.translation,FRT_suspension.front.compliance.bushingK,FRT_suspension.front.compliance.bushingC)', ...
    'Position', [620 80 850 130]);
add_block('simulink/Signal Routing/Mux', [modelName '/ComplianceInputs'], ...
    'Inputs', '2', 'Position', [530 280 580 330]);
add_block('simulink/Ports & Subsystems/Out1', [modelName '/LongitudinalForce'], ...
    'Position', [620 50 700 80]);
add_block('simulink/Ports & Subsystems/Out1', [modelName '/LateralForce'], ...
    'Position', [620 170 700 200]);
add_block('simulink/Ports & Subsystems/Out1', [modelName '/ComplianceReaction'], ...
    'Position', [900 90 1000 120]);
add_line(modelName, 'WheelTravel/1', 'KnCCore/1');
add_line(modelName, 'Steering/1', 'KnCCore/2');
add_line(modelName, 'NormalLoad/1', 'KnCCore/3');
add_line(modelName, 'KnCCore/1', 'LongitudinalTireForce/1');
add_line(modelName, 'NormalLoad/1', 'LongitudinalTireForce/2');
add_line(modelName, 'KnCCore/2', 'LateralTireForce/1');
add_line(modelName, 'NormalLoad/1', 'LateralTireForce/2');
add_line(modelName, 'LongitudinalTireForce/1', 'LongitudinalForce/1');
add_line(modelName, 'LateralTireForce/1', 'LateralForce/1');
add_line(modelName, 'KnCCore/3', 'ComplianceInputs/1');
add_line(modelName, 'WheelTravel/1', 'ComplianceInputs/2');
add_line(modelName, 'ComplianceInputs/1', 'Compliance/1');
add_line(modelName, 'Compliance/1', 'ComplianceReaction/1');
localBuildKnCCore([modelName '/KnCCore']);
end

function localBuildKnCCore(path)
add_block('simulink/Ports & Subsystems/In1', [path '/Travel'], 'Position', [25 30 55 60]);
add_block('simulink/Ports & Subsystems/In1', [path '/Steering'], 'Position', [25 90 55 120]);
add_block('simulink/Ports & Subsystems/In1', [path '/NormalLoad'], 'Position', [25 150 55 180]);
add_block('simulink/Ports & Subsystems/Out1', [path '/Slip'], 'Position', [240 30 280 60]);
add_block('simulink/Ports & Subsystems/Out1', [path '/SlipAngle'], 'Position', [240 90 280 120]);
add_block('simulink/Ports & Subsystems/Out1', [path '/Displacement'], 'Position', [240 150 280 180]);
add_line(path, 'Travel/1', 'Slip/1');
add_line(path, 'Steering/1', 'SlipAngle/1');
add_line(path, 'NormalLoad/1', 'Displacement/1');
end
