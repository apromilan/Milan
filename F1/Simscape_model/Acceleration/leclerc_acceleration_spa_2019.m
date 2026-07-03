clc
clear 

% Bármit be lehet tenni, de lehetőleg előtte meg kellene nézni az adott gyorsítást, hogy egyenes kormánnyal van-e
filename = '1_tel.json';
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
first_100_idx = find(throttle >= 100, 1, 'first');

if isempty(first_100_idx)
    error('Nincs 100-as throttle érték!');
end

decrease_idx = find(throttle(first_100_idx:end) < 100, 1, 'first');

if isempty(decrease_idx)
    end_idx = length(throttle);
else
    end_idx = first_100_idx + decrease_idx - 2;   % utolsó 100-as index
end

% Szakaszok kivágása
throttle_segment = throttle(1:end_idx);
time_segment     = time(1:end_idx);
gear_segment = gear(1:end_idx);
rpm_segment = rpm(1:end_idx);

% fprintf('Eredeti szakasz hossza: %d pont\n', length(throttle_segment));

% =============================================
% 2. 4001 pontra resampling (mindkettő)
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

% =============================================
% Ellenőrzés
% =============================================
% disp(['Új vektorok hossza: ', num2str(length(acc_pedal))]);
% disp(['Kezdő idő: ', num2str(time_new(1)), ' s']);
% disp(['Végső idő: ', num2str(time_new(end)), ' s']);

% Görbe ellenőrzése
figure('Position',[100 100 1000 600]);

% subplot(2,1,1);
% plot(acc_pedal, 'r-', 'LineWidth', 1.5);
% title('Acceleration Pedal (4001 pont)');
% ylabel('Throttle (%)');
% grid on;

% subplot(2,1,2);
plot(time_new, acc_pedal, 'b-', 'LineWidth', 1.5);
title('Throttle vs Time');
xlabel('Time (s)');
ylabel('Throttle (%)');
grid on;

% =============================================
% Mentés
% =============================================
acc_pedal = acc_pedal';
time_new = time_new';
gear_new = round(gear_new');
rpm_new = rpm_new';
save('acceleration_pedal.mat', 'acc_pedal');
save('acceleration_time.mat', 'time_new');
save('acceleration_gears.mat', 'gear_new');
save('acceleration_rpm.mat', 'rpm_new');