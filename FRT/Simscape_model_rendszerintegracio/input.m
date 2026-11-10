function input(LOG)
data = readtable(LOG);

% Data
timestamps = data.Time; 
steering_angle = timeseries(single(data.steering_angle), timestamps);
torque1 = timeseries(single(data.Torque1), timestamps);
torque2 = timeseries(single(data.Torque2), timestamps);
torque3= timeseries(single(data.Torque3), timestamps);
torque4= timeseries(single(data.Torque4), timestamps);

% Data back to workspace for the from workspace block
assignin('base', 'steering_angle', steering_angle);
assignin('base', 'torque1', torque1);
assignin('base', 'torque2', torque2);
assignin('base', 'torque3', torque3);
assignin('base', 'torque4', torque4);

end    
