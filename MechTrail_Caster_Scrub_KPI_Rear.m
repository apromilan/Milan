clc
clear all

%% Loading Tyre Data

Lat = load("C:\Users\aprom\Desktop\Milan\FRT\Tyre analysis\Round 9\Tyre Data\F1\B2356run17_f1.mat");
Long = load("C:\Users\aprom\Desktop\Milan\FRT\Tyre analysis\Round 9\Tyre Data\F1\B2356run51_f1.mat");

% Zoomolás az adott szakaszra
latETmin = 925.819;
latETmax = 927;
longETmin = 921.589;
longETmax = 923.699;
latidx = Lat.ET >= latETmin & Lat.ET <= latETmax;
longidx = Long.ET >= longETmin & Long.ET <= longETmax;
MZ = Lat.MZ(latidx);
FY = Lat.FY(latidx);
FX = Long.FX(longidx);
MZ = linspace(MZ(1), MZ(end), 400)';
FY = linspace(FY(1), FY(end), 400)';
FX = linspace(FX(1), FX(end), length(FY))';

%% Mechanical Trail

mechanical_trail = readmatrix("C:\Users\aprom\Desktop\Milan\BME\8. félév\Autómérnök\Futóműtervezés\F1 Suspension\Mechtrail_and_scrub.xlsx", "Range",'A2:A22');
t_mech = linspace(mechanical_trail(1), mechanical_trail(end), length(FY))';

%% Scrub Radius

scrub_radius = readmatrix("C:\Users\aprom\Desktop\Milan\BME\8. félév\Autómérnök\Futóműtervezés\F1 Suspension\Mechtrail_and_scrub.xlsx", "Range",'B2:B22');
scrub = linspace(scrub_radius(1), scrub_radius(end), length(FY))';

%% Pneumatic Trail

t_pneu = -MZ./FY;

%% Összenyomaték

MZ_lat = FY.*(t_mech+t_pneu)/1000; % cél: max 700 Nm
MZ_long = FX.*scrub/1000; % cél: max 100 Nm

MZ_sum = MZ_lat-MZ_long;

%% Mekkora legyen a scrub és mechtrail?

mechtrail = (1000*700-FY.*t_pneu)./FY; % 47 mm a cél ez már átlagolt
scrubr = 1000*100./FX; % 7,5 mm a cél ez már átlagolt
