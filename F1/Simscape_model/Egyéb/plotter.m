% ======================= Common settings =======================
windowSize = 20;  % Moving average window
ts_simu = out.simout;  % Simulink time series
log=readtable(LOG);

% Define the signal map (name, col in log, col in simscpae output, plot enabled)
signal_map = {
    'Droplink 1',           nan,    1,      0;
    'Pushrod 1',            275,    2,      1;
    'UCA_front 1',          276,    3,      1;
    'UCA_rear 1',           nan,    4,      0;
    'LCA_front 1',          277,    5,      1;
    'LCA_rear 1',           278,    6,      1;
    'tierod 1',             274,    7,      0;

    'Droplink 3',           nan,    8,      0;
    'Pushrod 3',            280,    9,      1;
    'UCA_front 3',          281,   10,      1;
    'UCA_rear 3',           nan,   11,      0;
    'LCA_front 3',          282,   12,      1;
    'LCA_rear 3',           283,   13,      1;
    'tierod 3',             279,   14,      0;
};
%additional data for debugging(name, col in log, plot enabled)
data_map = { 
    'ax',                   88, 0;
    'ay',                   89,  0;
    'vx',                   12,  0;
    'steering angle',       100,  0;
};
% ======================= Plot: log vs sim =======================
% Extract time
time_log = log{:,1};
time_sim = ts_simu.Time;
for i = 1:size(signal_map,1)
    
    name = signal_map{i,1};
    log_col = signal_map{i,2};
    sim_col = signal_map{i,3};
    enabled = signal_map{i,4};

    if ~enabled
        continue;
    end

    signal_log = log{:,log_col};
    signal_sim = ts_simu.Data(:,sim_col);
    % Smooth
    signal_log = movmean(signal_log, windowSize);
    signal_sim = movmean(signal_sim, windowSize);
    
    % Align time range
    start_time = max(time_log(1), time_sim(1));
    end_time   = min(time_log(end), time_sim(end));
    log_idx = (time_log >= start_time) & (time_log <= end_time);
    sim_idx = (time_sim >= start_time) & (time_sim <= end_time);
    
    % Interpolate log to sim time
    common_time = time_sim(sim_idx);
    log_aligned = interp1(time_log(log_idx), signal_log(log_idx), common_time, 'linear');
    sim_aligned = signal_sim(sim_idx);
    
    % Offset alignment
    offset = mean(sim_aligned - log_aligned, 'omitnan');
    signal_log_aligned = signal_log + offset;
    
    % Plot
    figure
    % yyaxis left
    plot(time_log, signal_log_aligned, 'b--','LineWidth', 1.3, 'DisplayName', 'LOG (aligned + smoothed)')
    hold on
    plot(time_sim, signal_sim, 'r-','LineWidth', 1.3, 'DisplayName', 'Simscape (smoothed)')
    ylabel('Rod force')
    
    % %plot addtional data
    % yyaxis right
    % 
    % % Generate unique colors for each enabled data_map signal
    % enabled_indices = find(cell2mat(data_map(:,3)) == 1);  % Get indices of enabled signals
    % color_list = lines(numel(enabled_indices));            % Generate that many distinct colors
    % color_idx = 1;
    % 
    % for j = 1:size(data_map,1)
    %     data_name = data_map{j,1};
    %     data_col  = data_map{j,2};
    %     data_enabled = data_map{j,3};
    % 
    %     if ~data_enabled
    %         continue;
    %     end
    % 
    %     data_signal = log{:,data_col};
    % 
    %     % correct steering angle
    %     if strcmp(data_name, 'steering angle')
    %         data_signal = (data_signal - 90) * -1;  
    %     end
    % 
    %     plot(time_log, data_signal,'-' ,'LineWidth', 1.0, 'DisplayName', data_name, 'Color', color_list(color_idx,:));
    %     color_idx = color_idx + 1;
    % end
    xlabel('Time [s]')
    % ylabel('Secondary Data Value')
    title(name)
    legend('Location','best')
    grid on
end
