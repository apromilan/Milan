clc
close all
clear all

%% Adatok
n = load("revolution.mat");  
n = n.powertrain_rpm'; % Motorkarakterisztika fordulatszám értékei
M = load("powertrain_torque.mat"); 
M = M.powertrain_torque'; % Motorkarakterisztika nyomaték értékei

k_v = 4.2;
k_sv = [3.25, 2.35, 1.9, 1.6, 1.35, 1.2, 1.05, 0.9];
eta_mech = 0.96;
r_g = 0.360;

%% Minden fokozat + minden rpm pont
F_v = zeros(length(k_sv), length(n));
v_kmh = zeros(length(k_sv), length(n)); % Sebesség minden fokozatban és minden fordulatszámon
M_powertrain = zeros(length(k_sv), length(n)); % Sebesség minden fokozatban és minden fordulatszámon

for i = 1:length(k_sv)
    for j = 1:length(n)
        gear_ratio = k_sv(i) * k_v;
        
        F_v(i,j)     = gear_ratio * eta_mech * M(j) / r_g;
        M_powertrain(i,j) = F_v(i,j) * r_g;                    % Keréknyomaték
        
        omega = 2*pi*n(j)/60;
        v_kmh(i,j) = (omega * r_g / gear_ratio) * 3.6;
    end
end

%% Egy oszlopba rendezés
v_kmh_column = v_kmh(:); % Oszlopba rendezve a v_kmh
M_powertrain_column = M_powertrain(:); % Oszlopba rendezve a M_powertrain

% Rendezés sebesség szerint
[v_sorted, idx] = sort(v_kmh_column);
M_powertrain_sorted = M_powertrain_column(idx); % Sebesség szerint rendezve a nyomatékoszlop (adott sebesség max potenciális nyomatékának megnézéséhez lehet jó)

%% Burkoló görbe (Simulinkhez ajánlott)
v_unique = unique(round(v_sorted,2)); % Egyedi kerekített sebességértékek, erre illesztjük a burkológörbét
M_envelope = zeros(size(v_unique)); % Burkológörbe nyomatékpontjai

for k = 1:length(v_unique)
    mask = abs(v_sorted - v_unique(k)) < 0.3;
    M_envelope(k) = max(M_powertrain_sorted(mask));
end

%% Plot
figure('Position',[100 100 1000 600])
hold on

colors = lines(length(k_sv));
for i = 1:length(k_sv)
    plot(v_kmh(i,:), M_powertrain(i,:), 'Color', colors(i,:), 'LineWidth', 1.3, ...
         'DisplayName', sprintf('%d. fokozat', i));
end

plot(v_unique, M_envelope, 'r-', 'LineWidth', 3.5, ...
     'DisplayName', 'Max keréknyomaték (burkoló)');

xlabel('Sebesség [km/h]');
ylabel('Keréknyomaték [Nm]');
title('Keréknyomaték diagram (váltóval)');
legend('Location','best');
grid on; grid minor;
ylim([0 max(M_powertrain(:))*1.05]);

%% Simulink Lookup Table adatok (nem ez kell, csak a sebesség innen)
speed_sim = linspace(0, max(v_sorted), 4001)'; % teljes sebességtartomány felosztva 3000 részre
M_powertrain_lookup = interp1(v_unique, M_envelope, speed_sim, 'pchip', 'extrap');
% save('powertrain_torque_lookup.mat', 'speed_sim', 'M_powertrain_lookup', 'v_sorted', 'M_powertrain_sorted');

%% F1 RAJTHOZ AJÁNLOTT LOOKUP TABLE
% Burkoló görbe + extra súlyozás az alacsony sebességekre (1. fokozat)

% Extra felbontás alacsony sebességnél (F1 rajt fontos tartománya)
speed_low  = linspace(0, 80, 2501)'; % 80-ig pontosabb adatok
speed_high = linspace(80, max(v_sorted), 1501)'; % figyelni kell hogy a linspaceben szumma 4002 legyen, ha 4001 soros az excel
speed_sim  = [speed_low; speed_high(2:end)];

% Burkoló görbe
M_envelope = interp1(v_unique, M_envelope, speed_sim, 'pchip');

% Alacsony sebességnél erősen favorizáljuk az 1. fokozatot
idx_low = speed_sim <= 65; % azok az indexek, ahol a sebesség 65 vagy az alatti               
M_launch = M_powertrain(1, :); % az 1.fokozat nyomatékpontjai
v1 = v_kmh(1, :); % első fokozat sebességpontjai

M_launch_interp = interp1(v1, M_launch, speed_sim(idx_low), 'pchip', 'extrap');

% Keverés: alacsony sebességnél inkább 1. fokozat, utána burkoló
blend = max(0, 1 - (speed_sim(idx_low)-20)/45);   % sima átmenet

M_final = M_envelope;
M_final(idx_low) = M_envelope(idx_low) .* (1-blend) + M_launch_interp .* blend;

%% Mentés
save('F1_launch_torque_lookup.mat', 'speed_sim', 'M_final', 'M_envelope'); % Ez a lényeg kb, az M_final egy kicsit húzatósabb, az M_envelope a normál max görbe

disp('F1 rajt lookup elkészült.');