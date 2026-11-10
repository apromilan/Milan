data = readtable("torque_and_steering.csv");
xd = data.steering_angle;
time = (0:0.05:length(xd)*0.05-0.05)';

% Data
timestamps = time; 
steering_angle = timeseries(single(data.steering_angle), timestamps);
torque1 = timeseries(single(data.Torque1), timestamps);
torque2 = timeseries(single(data.Torque2), timestamps);
torque3= timeseries(single(data.Torque3), timestamps);
torque4= timeseries(single(data.Torque4), timestamps);

% Data back to workspace for the from workspace block
% assignin('base', 'steering_angle', steering_angle);
% assignin('base', 'Torque1', torque1);
% assignin('base', 'Torque2', torque2);
% assignin('base', 'Torque3', torque3);
% assignin('base', 'Torque4', torque4);

