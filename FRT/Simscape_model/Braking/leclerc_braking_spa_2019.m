clc
clear 

% Bármit be lehet tenni, de lehetőleg előtte meg kellene nézni az adott gyorsítást, hogy egyenes kormánnyal van-e
filename = '1_tel.json';
str = fileread(filename);

% 2. Átalakítjuk MATLAB struktúrává
data = jsondecode(str);

% Most már hozzáférsz az adatokhoz, pl.:
% disp(data.nev);

% brake = data.tel.brake(:);
time = data.tel.time(:);     
gear = data.tel.gear(:);
rpm = data.tel.rpm(:);

% =============================================
% 1. Releváns szakasz kivágása
% =============================================

% Szakaszok kivágása
% brake_segment = brake(911:936);
brake1 = linspace(100, 90, 19);
brake2 = linspace(90, 60, 7);
braking = [brake1, brake2]';
time_segment = time(911:936);
gear_segment = gear(911:936);
rpm_segment = rpm(911:936);

% =============================================
% 2. 4001 pontra resampling (mindkettő)
% =============================================
n_new = 4001;

% Normalizált x tengely
x_old = linspace(0, 1, length(time_segment));
x_new = linspace(0, 1, n_new);

% Resampling
% brake_pedal = interp1(x_old, brake_segment, x_new, 'pchip');
braking = interp1(x_old, braking, x_new, 'pchip');
time_new  = interp1(x_old, time_segment,     x_new, 'pchip');
gear_new = interp1(x_old, gear_segment,     x_new, 'pchip');
rpm_new = interp1(x_old, rpm_segment,     x_new, 'pchip');

% =============================================
% Mentés
% =============================================
brake_pedal = braking';
time_new = time_new';
gear_new = round(gear_new');
rpm_new = rpm_new';
save('braking_pedal.mat', 'brake_pedal');
save('braking_time.mat', 'time_new');
save('braking_gears.mat', 'gear_new');
save('braking_rpm.mat', 'rpm_new');