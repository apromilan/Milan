clc
close all
clear all

%% Adatok
% motor
n = load("revolution.mat");
n = n.powertrain_rpm';
M = load("powertrain_torque.mat");
M = M.powertrain_torque';
torque_points = [440, 515, 595, 645, 685, 705, 715, 700, 665]; 

% Erőátvitel
k_v = 4.2; % végáttétel [-]
k_sv = [3.25, 2.35, 1.9, 1.6, 1.35, 1.2, 1.05, 0.9]; % váltó áttételek
eta_mech = 0.96; % mechanikai hatásfok [-]
r_g = 0.360; % dinamikus gördülési sugár [m]

% Járműparaméterek
m = 810.82; % tömeg [kg]
cd = 0.7; % légellenállási tényező [-]
A = 1.6; % homlokfelület [m^2]

% Egyéb paraméterek
rho = 1.2; % légsűrűség [kg/m^3]
emelkedo = [0,5,10,15]; % emelkedő százaléka [%]
g = 9.81; % gravitációs gyorsulás [m/s^2]
f = 0.01; % gördülési tényező [-]

%% Számítás
F_v = k_sv'*k_v*eta_mech*M/r_g;
omega_mot = 2*pi*n/60;
v = omega_mot*r_g./(k_sv'*k_v)*3.6;
omega_motmax = 2*pi*n(1,end)/60;
vmax = omega_motmax*r_g./(min(k_sv)'*k_v)*3.6;
Fmax = min(k_sv)'*k_v*eta_mech*M(1,end)/r_g;
%P1 = k_sv(1)'*k_v*eta_mech*max(M)/r_g;
%P2 = k_sv(2)'*k_v*eta_mech*max(M)/r_g;
%P3 = k_sv(3)'*k_v*eta_mech*max(M)/r_g;
%P4 = k_sv(4)'*k_v*eta_mech*max(M)/r_g;
%P5 = k_sv(5)'*k_v*eta_mech*max(M)/r_g;
%P6 = k_sv(6)'*k_v*eta_mech*max(M)/r_g;
%P_motor = omega_mot .* M; % motorteljesítmény [W]
%P_motor = (v./3.6)'.*F_v'; % motorteljesítmény [W]
%P_motormax = max(P_motor);
%P_kerek = P_motor * eta_mech; % kerékteljesítmény [W]

P_kerek=M.*omega_mot*eta_mech;
%v_kerek=v(:)';
v_kerek=sort(v(:),'ascend');
P_k=max(P_kerek(:));
F_v_kerek=(P_k)./(v_kerek/3.6);
%F_v_kerek=F_v_kerek(:)';
F_v_kerek=sort(F_v_kerek(:,1),'descend');

P_motor = P_kerek/eta_mech;
v_kerek2=sort(v(:),'ascend');
P_kmot=max(P_motor(:));
F_v_kerek2=(P_kmot)./(v_kerek2/3.6);
%F_v_kerek=F_v_kerek(:)';
F_v_kerek2=sort(F_v_kerek2(:,1),'descend');


alfa_1 = atand(emelkedo(1)/100); % 0 emelkedő szöge
alfa_2 = atand(emelkedo(2)/100); % 5 emelkedő szöge
alfa_3 = atand(emelkedo(3)/100); % 10 emelkedő szöge
alfa_4 = atand(emelkedo(4)/100); % 15 emelkedő szöge
F_ut_1 = m*g*(sind(alfa_1)+f*cosd(alfa_1)); % útellenállás
F_ut_2 = m*g*(sind(alfa_2)+f*cosd(alfa_2)); % útellenállás
F_ut_3 = m*g*(sind(alfa_3)+f*cosd(alfa_3)); % útellenállás
F_ut_4 = m*g*(sind(alfa_4)+f*cosd(alfa_4)); % útellenállás
F_leg = 0.5*rho*cd*A*(v./3.6).^2; % légellenállás

F_ell1 = F_ut_1+F_leg; % teljes ellenállás
F_ell2 = F_ut_2+F_leg; % teljes ellenállás
F_ell3 = F_ut_3+F_leg; % teljes ellenállás
F_ell4 = F_ut_4+F_leg; % teljes ellenállás
%F_ell = F_leg+F_ut; % teljes ellenállás

%alfa=[atan(0) atan(0.05) atan(0.10) atan(0.15)];

%F_ell1=m*g*(sin(alfa(1))+f*cos(alfa(1)))+(1/2)*rho*cd*A*(v./3.6).^2;
%F_ell2=m*g*(sin(alfa(2))+f*cos(alfa(2)))+(1/2)*rho*cd*A*(v./3.6).^2;
%F_ell3=m*g*(sin(alfa(3))+f*cos(alfa(3)))+(1/2)*rho*cd*A*(v./3.6).^2;
%F_ell4=m*g*(sin(alfa(4))+f*cos(alfa(4)))+(1/2)*rho*cd*A*(v./3.6).^2;
%16.25

figure()
plot(v', M_v')
hold on
% plot(v_kerek',F_v_kerek', 'g--', 'LineWidth', 2); % motorteljesítmény [kW]
% plot(v_kerek',F_v_kerek2', 'r--', 'LineWidth', 2); % kerékteljesítmény [kW]
% plot(v', F_ell1',"black")
% plot(v', F_ell2',"black")
% plot(v', F_ell3',"black")
% plot(v', F_ell4',"black")
% plot([vmax,vmax],[Fmax,0],"black")
% text([vmax,vmax],[0,0],'v_d_i_n_m_a_x   ',VerticalAlignment='cap',HorizontalAlignment='right',FontSize=12)
% ylim([0 30000])
hold off
yticks([0 5000 10000 15000 20000 25000 30000 35000 40000 45000 50000]);
yticklabels({'0', '5000', '10000', '15000', '20000', '25000','30000','35000','40000','45000','50000'});
xlabel("Sebesség [km/h]")
ylabel("Vonóerő [N]")
legend("1.fokozat","2.fokozat","3.fokozat","4.fokozat","5.fokozat","6.fokozat", "7. fokozat", "8. fokozat", "Kerékteljesítmény [W]","Motorteljesítmény [W]","ellenállás erők 0-15% ") % Adatfeliratok
title("Vonóerő diagram")
grid on
grid minor

save()
