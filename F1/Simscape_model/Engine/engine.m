%% Nyomaték karakterisztika - 2. képhez hasonló alak
clear; clc;

% % === EREDETI ADATOK ===
% rpm_orig = [4000, 6000, 8000, 10500, 12000];
% torque_orig = [460, 570, 625, 710, 665];

% === KIEGÉSZÍTETT IRÁNYÍTÓPONTOK (hogy jobb legyen az alak) ===
% rpm_points = [4000, 4500, 5200, 6000, 7200, 8500, 9800, 10800, 12000];
rpm_points = [4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500, 8000, 8500, 9000, 9500, 10000, 10500, 11000, 11500, 12000, 12500, 13000, 13500, 14000, 14500, 15000];
torque_points = [677, 688, 705, 712, 724, 728, 730, 734, 736, 740, 735, 730 720, 712, 694, 680, 668, 650, 640, 630, 615, 600, 580];
% torque_points = [677, 688, 705, 712, 724, 728, 727, 726, 725, 721, 716, 708, 694, 678, 647, 619, 594, 570, 545, 520, 488, 457, 422];
% torque_points = [440, 515, 595, 645, 685, 705, 715, 700, 665];
% torque_points = [540, 585, 625, 665, 685, 705, 715, 700, 685]; % laposított
% torque_points = [670, 680, 690, 700, 708, 712, 715, 710, 700]; % laposított v2
% torque_points = [460, 535, 615, 665, 705, 725, 735, 720, 685]; % hozzáadva 20
% torque_points = [420, 495, 575, 625, 665, 685, 695, 680, 645]; % kivonva 20
% torque_points = [400, 475, 555, 605, 645, 665, 675, 660, 625]; % kivonva 40

% 4001 pontos egyenletes rács
powertrain_rpm = linspace(4000, 15000, 4001)';

% Interpoláció
powertrain_torque = interp1(rpm_points, torque_points, powertrain_rpm, 'pchip');   % pchip = sima + nem leng

%% Ábrázolás
figure('Position',[100 100 900 550]);
% plot(rpm_orig, torque_orig, 'o', 'MarkerSize',9, 'LineWidth',1.5, 'DisplayName','Eredeti mérési pontok');
hold on;
plot(rpm_points, torque_points, 'x', 'MarkerSize',8, 'LineWidth',1.5, 'Color','r');
plot(powertrain_rpm, powertrain_torque, 'LineWidth',2.2, 'Color',[0.85 0.33 0.1], 'DisplayName','Nyomaték karakterisztika');

grid on;
xlabel('Fordulatszám [RPM]');
ylabel('Teljes nyomaték [Nm]');
title('Motor nyomaték karakterisztika');
legend('Location','southeast');
set(gca,'FontSize',12);

% Export
% assignin('base','rpm_vec', rpm);
% assignin('base','torque_vec', torque);
save('powertrain_torque.mat', 'powertrain_torque');
save('revolution.mat', 'powertrain_rpm');
fprintf('Kész! 4001 pontos vektor létrehozva.\n');