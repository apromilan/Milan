function FRT = FRT_init()
%FRT_INIT Load and derive parameters for the three FRT suspension models.
%   FRT = FRT_INIT loads suspension hard-points, derives geometry and
%   vehicle properties, and publishes FRT to the base workspace.
%
root = fileparts(mfilename('fullpath'));
pointFile = fullfile(root, 'suspension_points_fred.xlsx');
tireFile = fullfile(root, 'Tyre Models', ...
    'Hoosier_43075_16x7_5_10_LCO_7inch.tir');
frontSheet = "Front_3";
rearSheet = "Rear_3";

if ~isfile(pointFile)
    error('FRT:init:PointFileMissing', 'Hard-point file not found: %s', pointFile);
end

FRT = struct();
FRT.meta = struct('root', root, 'pointFile', pointFile, ...
    'tireFile', tireFile, 'frontSheet', frontSheet, 'rearSheet', rearSheet);
FRT.units = struct('length', 'm', 'force', 'N', 'angle', 'rad', ...
    'torque', 'N*m', 'stiffness', 'N/m');

% Geometry is stored in metres and mirrored about the vehicle centre plane.
FRT.geometry = struct();
FRT.geometry.front = localReadAxlePoints(pointFile, frontSheet, 1);
FRT.geometry.rear = localReadAxlePoints(pointFile, rearSheet, 3);
FRT.geometry.wheelbase = 1.540;
FRT.geometry.frontTrack = 1.220;
FRT.geometry.rearTrack = 1.200;
FRT.geometry.wheelRadius = 0.193;
FRT.geometry.cog = [-0.77009; 0; 0.27271];
FRT.geometry.cop = [-FRT.geometry.wheelbase * 0.45; 0; 0.100];

FRT.vehicle = struct();
FRT.vehicle.gravity = 9.81;
FRT.vehicle.mass = struct('sprung', 179.6 + 75, 'driver', 75, ...
    'tire', 3.2, 'rim', 0.78, 'upright', 0.88 + 3.13 + 7.08 + 0.66);
FRT.vehicle.mass.unsprung = FRT.vehicle.mass.tire + FRT.vehicle.mass.rim + ...
    FRT.vehicle.mass.upright;
FRT.vehicle.mass.total = FRT.vehicle.mass.sprung + 4 * FRT.vehicle.mass.unsprung;
FRT.vehicle.weightDistributionFront = 0.49;
FRT.vehicle.inertia = diag([38.215, 121.714, 96.280]);
FRT.vehicle.aero = struct('CL', 5, 'CD', 1, 'area', 1.6, 'airDensity', 1.22);
FRT.vehicle.driveline = struct('gearRatio', 12.13, 'wheelInertia', 0.2);

% Axle spring and damper data. Values are wheel-rate inputs; the lever ratio
% converts between wheel and spring coordinates in the model subsystems.
FRT.suspension = struct();
FRT.suspension.front = localSuspensionData(225, 1.256, 0.7, ...
    FRT.vehicle.mass.sprung * FRT.vehicle.weightDistributionFront / 2, 409, 123);
FRT.suspension.rear = localSuspensionData(225, 1.081, 0.7, ...
    FRT.vehicle.mass.sprung * (1 - FRT.vehicle.weightDistributionFront) / 2, 271, 125);
FRT.suspension.front.freePlay = struct('translation', 0.0005, 'rotation', 0.001);
FRT.suspension.rear.freePlay = struct('translation', 0.0005, 'rotation', 0.001);
FRT.suspension.front.compliance = struct('bushingK', diag([2e5 2e5 3e5]), ...
    'bushingC', diag([150 150 250]), 'jointK', 1e5, 'jointC', 75);
FRT.suspension.rear.compliance = FRT.suspension.front.compliance;

% Model 1 collision settings. Each pair is evaluated from the closest
% distance between two configured line segments in a MATLAB Function block.
FRT.collision = struct();
FRT.collision.enabled = true;
FRT.collision.pairs = [
    struct('name', 'rod_to_rod', 'bodyA', "LCA", 'bodyB', "UCA", 'clearance', 0.003, 'radius', 0.009); ...
    struct('name', 'rod_to_motor', 'bodyA', "pushPullRod", 'bodyB', "motorHousing", 'clearance', 0.004, 'radius', 0.018); ...
    struct('name', 'motor_to_rim', 'bodyA', "motorHousing", 'bodyB', "innerRim", 'clearance', 0.002, 'radius', 0.018)];
FRT.collision.penalty = struct('stiffness', 2e6, 'damping', 250, ...
    'enableStop', true, 'stopAtFirstContact', false);
FRT.collision.forceDirection = "shortest_segment_normal";

% Model 2 tire-force maps. Replace these arrays with measured or exported
% maps without changing the Simulink architecture.
FRT.tire = struct();
FRT.tire.file = tireFile;
FRT.tire.longitudinal = struct('slip', [-0.20 -0.10 -0.05 0 0.05 0.10 0.20], ...
    'normalLoad', [500 1000 1500 2000], ...
    'force', [ -900 -700 -450 0 450 700 900; ...
               -1800 -1400 -900 0 900 1400 1800; ...
               -2700 -2100 -1350 0 1350 2100 2700; ...
               -3600 -2800 -1800 0 1800 2800 3600]);
FRT.tire.lateral = struct('slipAngle', deg2rad([-12 -8 -4 0 4 8 12]), ...
    'normalLoad', [500 1000 1500 2000], ...
    'force', [ -700 -620 -400 0 400 620 700; ...
               -1400 -1240 -800 0 800 1240 1400; ...
               -2100 -1860 -1200 0 1200 1860 2100; ...
               -2800 -2480 -1600 0 1600 2480 2800]);
FRT.tire.interpolation = "linear";
FRT.tire.extrapolation = "clip";
FRT.forceApplication = struct();
FRT.forceApplication.frontLeft = struct('longitudinal', [0.770; 0.610; 0.193], ...
    'lateral', [0.770; 0.610; 0.193]);
FRT.forceApplication.frontRight = FRT.forceApplication.frontLeft;
FRT.forceApplication.rearLeft = struct('longitudinal', [-0.770; 0.600; 0.193], ...
    'lateral', [-0.770; 0.600; 0.193]);
FRT.forceApplication.rearRight = FRT.forceApplication.rearLeft;

% Model 3 inputs and chassis degrees of freedom.
FRT.fullMotion = struct();
FRT.fullMotion.heave = struct('enabled', true, 'initialPosition', 0, ...
    'initialVelocity', 0, 'inputLimit', 0.10);
FRT.fullMotion.steering = struct('enabled', true, 'frontOnly', true, ...
    'rackRatio', 0.050, 'maxAngle', deg2rad(25), 'maxRate', deg2rad(180));
FRT.fullMotion.roll = struct('enabled', true, 'initialAngle', 0, ...
    'initialRate', 0, 'rollStiffness', 1200, 'rollDamping', 180);
FRT.fullMotion.chassis = struct('mass', FRT.vehicle.mass.sprung, ...
    'inertia', FRT.vehicle.inertia, 'gravityHeight', FRT.geometry.cog(3));

FRT.model = struct('kinematics', "half_vehicle_kinematics", ...
    'compliance', "half_vehicle_KnC", 'fullMotion', "FRT_full_motion");

assignin('base', 'FRT', FRT);
assignin('base', 'FRT_geometry', FRT.geometry);
assignin('base', 'FRT_suspension', FRT.suspension);
assignin('base', 'FRT_collision', FRT.collision);
assignin('base', 'FRT_tire', FRT.tire);
assignin('base', 'FRT_forceApplication', FRT.forceApplication);
assignin('base', 'FRT_fullMotion', FRT.fullMotion);
FRT_build_models(FRT);
end

function axle = localReadAxlePoints(fileName, sheetName, firstWheelIndex)
tableData = readtable(fileName, 'Sheet', sheetName, 'TextType', 'string');
required = ["Point", "X", "Y", "Z"];
if ~all(ismember(required, string(tableData.Properties.VariableNames)))
    error('FRT:init:PointColumns', 'Sheet %s must contain Point, X, Y, and Z columns.', sheetName);
end
axle = struct();
for row = 1:height(tableData)
    pointName = char(tableData.Point(row));
    point = [tableData.X(row); tableData.Y(row); tableData.Z(row)] / 1000;
    axle.(sprintf('%s_%d', pointName, firstWheelIndex)) = point;
    axle.(sprintf('%s_%d', pointName, firstWheelIndex + 1)) = ...
        [point(1); -point(2); point(3)];
end
end

function data = localSuspensionData(springLbfIn, motionRatio, dampingRatio, quarterMass, arbTorsion, rollCenter)
data = struct();
data.springRate = springLbfIn * 175.127;
data.motionRatio = motionRatio;
data.arbTorsionalStiffness = arbTorsion;
data.rollCenter = rollCenter / 1000;
data.criticalDamping = 2 * sqrt(data.springRate / motionRatio^2 * quarterMass);
data.damping = dampingRatio * data.criticalDamping * motionRatio^2;
data.staticWheelLoad = quarterMass * 9.81;
data.staticSpringForce = data.staticWheelLoad * motionRatio;
end
