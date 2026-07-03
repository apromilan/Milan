clc
clear 
% 252-278

filename = 'C:\Users\Milán\Desktop\FRT\GitHub\Mechanical-codes\Simscape_model\F1 Logok\ham_13_tel.json';
str = fileread(filename);

% 2. Átalakítjuk MATLAB struktúrává
data = jsondecode(str);

% Most már hozzáférsz az adatokhoz, pl.:
% disp(data.nev);

throttle = data.tel.throttle(:);
time = data.tel.time(:);     
gear = data.tel.gear(:);
rpm = data.tel.rpm(:);

% =============================================
% 1. Releváns szakasz kivágása
% =============================================
% Szakaszok kivágása
throttle_segment = throttle(252:278);
time_segment     = time(252:278);
gear_segment = gear(252:278);
rpm_segment = rpm(252:278);
steering_in = linspace(0, 60, 11);
steering_mid = 60*ones(1, 5);
steering_out = linspace(60, 0, 11);
steering = [steering_in, steering_mid, steering_out]';

% fprintf('Eredeti szakasz hossza: %d pont\n', length(throttle_segment));

% =============================================
% 2. 4001 pontra resampling 
% =============================================
n_new = 4001;

% Normalizált x tengely
x_old = linspace(0, 1, length(throttle_segment));
x_new = linspace(0, 1, n_new);

% Resampling
acc_pedal = interp1(x_old, throttle_segment, x_new, 'pchip');
time_new  = interp1(x_old, time_segment,     x_new, 'pchip');
gear_new = interp1(x_old, gear_segment,     x_new, 'pchip');
rpm_new = interp1(x_old, rpm_segment,     x_new, 'pchip');
steering_angle = interp1(x_old, steering, x_new, 'pchip');

% =============================================
% Mentés
% =============================================
acc_pedal = acc_pedal';
time_new = time_new';
gear_new = round(gear_new');
rpm_new = rpm_new';
steering_angle = steering_angle';
save('cornering_pedal.mat', 'acc_pedal');
save('cornering_time.mat', 'time_new');
save('cornering_gears.mat', 'gear_new');
save('cornering_rpm.mat', 'rpm_new');
save('cornering_steering.mat', 'steering_angle');
