function log_reader(LOG)
    log = readtable(LOG);
    % log = log(2:end,:); %removing the dimensions from the table

    %%accelerations from log
    timestamps = log.Time; %- log.Time(1); %ensures timing starts from zero
    timeseries_ax = timeseries(-(single(log.AccX_Bosch * 9.81)), timestamps);
    timeseries_ay = timeseries(-(single(log.AccY_Bosch * 9.81)), timestamps);
    timeseries_log= timeseries(log, timestamps);

    
    N = length(timeseries_ax.Data);
    gravity_z = -9.81 * ones(N, 1);

    combined_accel = [timeseries_ax.Data, timeseries_ay.Data, gravity_z];
    timeseries_log_accel = timeseries(combined_accel, timestamps);

    % aero
    C_L = single(4.5);
    A = single(1);
    RHO = single(1.225);
    C_D = single(0.3);
    H_AERO = single(290);
    AERO_DIST_FRONT = single(0.65);
    COG=[-1650; 0; 300];
    wheelbase=3000;
    
    timeseries_downforce = timeseries((single(log.v_x).^2) * 0.5 * C_L * A * RHO, timestamps);
    timeseries_drag = timeseries((single(log.v_x).^2) * 0.5 * C_D * A * RHO, timestamps);
    timeseries_pitch_moment= (timeseries_downforce*(abs(COG(1))-(1-AERO_DIST_FRONT)*wheelbase)+timeseries_drag*(COG(3)-H_AERO))*0.001;

    %fz
    timeseries_fz1 = timeseries(single(log.VDC_Fz_FL), timestamps);
    timeseries_fz2 = timeseries(single(log.VDC_Fz_FR), timestamps);
    timeseries_fz3 = timeseries(single(log.VDC_Fz_RL), timestamps);
    timeseries_fz4 = timeseries(single(log.VDC_Fz_RR), timestamps);
    timeseries_steering_angle = timeseries(single(-1*deg2rad(log.STA1_position-90)), timestamps);
    timeseries_steering_angle.Data = filloutliers(timeseries_steering_angle.Data, 'linear', 'movmedian', 5); %clean outliers

    %amk forque limits
    timeseries_AMK1_Torque_Limit_Positive = timeseries(single(log.AMK1_Torque_Limit_Positive), timestamps);
    timeseries_AMK2_Torque_Limit_Positive = timeseries(single(log.AMK2_Torque_Limit_Positive), timestamps);
    timeseries_AMK3_Torque_Limit_Positive = timeseries(single(log.AMK3_TorqueLimitPositive), timestamps);
    timeseries_AMK4_Torque_Limit_Positive = timeseries(single(log.AMK4_TorqueLimitPositive), timestamps);
    timeseries_AMK1_Torque_Limit_Negative = timeseries(single(log.AMK1_Torque_Limit_Negative), timestamps);
    timeseries_AMK2_Torque_Limit_Negative = timeseries(single(log.AMK2_Torque_Limit_Negative), timestamps);
    timeseries_AMK3_Torque_Limit_Negative = timeseries(single(log.AMK3_TorqueLimitNegative), timestamps);
    timeseries_AMK4_Torque_Limit_Negative = timeseries(single(log.AMK4_TorqueLimitNegative), timestamps);


    %to workspace
    assignin('base', 'timeseries_log', timeseries_log);
    assignin('base', 'timeseries_log_accel', timeseries_log_accel);
    assignin('base', 'timeseries_downforce', timeseries_downforce);
    assignin('base', 'timeseries_drag', timeseries_drag);
    assignin('base', 'timeseries_pitch_moment', timeseries_pitch_moment);

    assignin('base', 'timeseries_fz1', timeseries_fz1);
    assignin('base', 'timeseries_fz2', timeseries_fz2);
    assignin('base', 'timeseries_fz3', timeseries_fz3);
    assignin('base', 'timeseries_fz4', timeseries_fz4);
    assignin('base', 'timeseries_steering_angle', timeseries_steering_angle);

    assignin('base', 'AMK1_Torque_Limit_Positive', timeseries_AMK1_Torque_Limit_Positive);
    assignin('base', 'AMK2_Torque_Limit_Positive', timeseries_AMK2_Torque_Limit_Positive);
    assignin('base', 'AMK3_Torque_Limit_Positive', timeseries_AMK3_Torque_Limit_Positive);
    assignin('base', 'AMK4_Torque_Limit_Positive', timeseries_AMK4_Torque_Limit_Positive);
    assignin('base', 'AMK1_Torque_Limit_Negative', timeseries_AMK1_Torque_Limit_Negative);
    assignin('base', 'AMK2_Torque_Limit_Negative', timeseries_AMK2_Torque_Limit_Negative);
    assignin('base', 'AMK3_Torque_Limit_Negative', timeseries_AMK3_Torque_Limit_Negative);
    assignin('base', 'AMK4_Torque_Limit_Negative', timeseries_AMK4_Torque_Limit_Negative);



end    