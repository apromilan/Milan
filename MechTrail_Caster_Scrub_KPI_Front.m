clc
clear all
close all

%% Loading Tyre Data

Lat = load("C:\Users\aprom\Desktop\Milan\FRT\Tyre analysis\Round 9\Tyre Data\F1\B2356run17_f1.mat");
Long = load("C:\Users\aprom\Desktop\Milan\FRT\Tyre analysis\Round 9\Tyre Data\F1\B2356run51_f1.mat");

% Zoomolás az adott szakaszra
latETmin = 925.819;
latETmax = 928.929;
longETmin = 921.589;
longETmax = 923.699;
latidx = Lat.ET >= latETmin & Lat.ET <= latETmax;
longidx = Long.ET >= longETmin & Long.ET <= longETmax;
MZ = Lat.MZ(latidx);
FY = Lat.FY(latidx);
FX = Long.FX(longidx);
FX = linspace(FX(1), FX(end), length(FY))';
SA = linspace(0, 12, length(MZ));
SR = linspace(0, 0.2, length(FX));

%% Mechanical Trail

mechanical_trail = readmatrix("C:\Users\aprom\Desktop\Milan\BME\8. félév\Autómérnök\Futóműtervezés\F1 Suspension\Mechtrail_and_scrub.xlsx", "Range",'A2:A12');
mechanical_trail = [mechanical_trail(1), mechanical_trail(2, end)*0.8];
t_mech = linspace(mechanical_trail(1), mechanical_trail(end), length(FY))';

%% Scrub Radius

scrub_radius = readmatrix("C:\Users\aprom\Desktop\Milan\BME\8. félév\Autómérnök\Futóműtervezés\F1 Suspension\Mechtrail_and_scrub.xlsx", "Range",'B2:B12');
scrub_radius = [scrub_radius(1), scrub_radius(2, end)*0.8];
scrub = linspace(scrub_radius(1), scrub_radius(end), length(FY))';

% Dive-ra
scrub_radius_brake = readmatrix("C:\Users\aprom\Desktop\Milan\BME\8. félév\Autómérnök\Futóműtervezés\F1 Suspension\Mechtrail_and_scrub.xlsx", "Range",'C2:C22');
scrub_radius_brake = [scrub_radius_brake(1), scrub_radius_brake(2, end)*0.8];
scrub_brake = linspace(scrub_radius_brake(1), scrub_radius_brake(end), length(FY))';

%% Pneumatic Trail

t_pneu = -MZ./FY;

%% Összenyomaték

MZ_lat = FY.*(t_mech+t_pneu)/1000; % cél: max 500 Nm
MZ_long = FX.*scrub/1000; % cél: max 150 Nm (ez kanyarodásra)
MZ_long_brake = FX.*scrub_brake/1000; % cél: max 150 Nm (ez fékezésre)

MZ_sum = MZ_lat+MZ_long;

%% Mekkora legyen a scrub és mechtrail?

mechtrail = (1000*500-FY.*t_pneu)./FY;
scrubr = 1000*150./FX;

figure('Name','Kúszási szög - Keresztirányú önbeállító nyomaték görbe', 'WindowState','maximized')
plot(SA, MZ_lat);
xlabel("Kúszási Szög [°]", "FontSize",18);
ylabel("Önbeállító nyomaték [Nm]", "FontSize",18);
grid on;
grid minor;

figure('Name','Szlip - Hosszirányú önbeállító nyomaték görbe', 'WindowState','maximized')
plot(SR, MZ_long_brake);
xlabel("Szlip [-]", "FontSize",18);
ylabel("Önbeállító nyomaték [Nm]", "FontSize",18);
grid on;
grid minor;

figure('Name','Kúszási szög - Önbeállító nyomaték görbe', 'WindowState','maximized')
plot(SA, MZ_sum);
xlabel("Kúszási Szög [°]", "FontSize",18);
ylabel("Önbeállító nyomaték [Nm]", "FontSize",18);
grid on;
grid minor;


%%% Elbasztam mert berugózásra néztem az értékváltozást, pedig kormányzásra kellett volna %%%
% amugy beraktam a kanyarodast megszorozva mindkettőt 0.8-cal