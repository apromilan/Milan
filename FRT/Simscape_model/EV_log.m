function EV_log(LOG)
data = readtable(LOG);

% Data
timestamps = data.Time; 
steering_angle = timeseries(single(data.steering_angle), timestamps);
acceleration_pedal = timeseries(single(data.acceleration_pedal)/100, timestamps);
brake_pedal = timeseries(single(data.brake_pedal), timestamps);
% engine_torque = timeseries(single(data.engine_torque_3), timestamps);
gear = timeseries(single(data.gear), timestamps);
engine_rpm = timeseries(single(data.engine_rpm), timestamps);

% Data back to workspace for the from workspace block
assignin('base', 'steering_angle', steering_angle);
assignin('base', 'acceleration_pedal', acceleration_pedal);
assignin('base', 'brake_pedal', brake_pedal);
% assignin('base', 'engine_torque', engine_torque);
assignin('base', 'gear', gear);
assignin('base', 'engine_rpm', engine_rpm);

end    