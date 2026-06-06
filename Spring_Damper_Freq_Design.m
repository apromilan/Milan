clc
clear all
close all

% Rocker, Spring and Damping Designer Calculation

%% Determine the usable wheel travel (maybe the lowest + some additional because of bumps)

compression = 20; % mm
tension = 5; % mm
wheel_travel = compression+tension; % mm

%% Determining wheel rate from the reaction of the car how fast it reacts to the bumps and forces

% Ride fequency

full_m_sprung = 720;
weight_dist = 0.45;
m_sprung = full_m_sprung*weight_dist/2; % kg
ride_frequency = 7; % Hz
wheel_rate = m_sprung*(2*pi*ride_frequency)^2; % N/m

%% Determining the motion ratio. MR = Wheel travel / damper travel. 
% During compression the target is the degressive characteristics (the damper should move more and more than the wheel).
% During tension its better to have a progressive curve, because the inside
% tyre will not "disturb" the motion with its stiffness, which would result
% some jacking force.

MR = 0.578; % -, it is a vector by the way
MR_average = MR; % -

%% Spring stiffness, this is that we should use in order to get the wanted wheel rate

spring_stiffness = wheel_rate*MR^2; % N/m
s = spring_stiffness/175.175;

%% Static load on a wheel and on a damper

F_wheel_static = m_sprung*9.81; % N
F_damper_static = F_wheel_static*MR; % N

%% Calculating preload 
% Preload means the amount of distance that is between the length of the
% spring in its equlibirum position and when the spring is placed in the
% car and the suspension is in its maximum tensioned state.

damper_tension_travel = tension/MR; % mm
F_preload_damper = F_damper_static-(spring_stiffness*(damper_tension_travel/1000)); % m
spring_preload_mm = F_preload_damper/(spring_stiffness/1000);

%% Effect of Aero
% We have to make sure that the damper and spring will be long enough to
% not reach their limits (bump stops) under heavy loads, which means most of the time high speed
% cornering or any steady state cornering with high lateral acceleration.
v_kmh = 270; % km/h
v = v_kmh / 3.6; % m/s
rho = 1.225; % kg/m^3
cl = 4.0; %
A = 1.6; %
aero_balance_front = 0.45; % 
F_aero_total = 0.5 * rho * v^2 * cl*A; % 
F_aero_wheel = (F_aero_total * aero_balance_front) / 2; % 

% Wheel displacement due to aero force in mm
wheel_compression_aero = (F_aero_wheel / wheel_rate) * 1000; % mm 
% Total damper force with preload and aero force
F_damper_total_aero = F_preload_damper+(F_aero_wheel*MR);

% Damper displacement due to aero force in mm
damper_compression_aero = wheel_compression_aero / MR;

%% Damper length

damper_stroke = wheel_travel/MR_average;  % mm (ezt statikus MR-rel nincs sok értelme nézni)
% The damper length is coming from the kinematics model with the motion ratio
% Now we can choose a damper based on its length
% The shortest state has to be shorter, than the length at maximum
% compression.
% The longest state has to be longer, than the length at maximum tension.

bump_damper = 6 / MR; % 6 mm bump
margin_damper = 2.5; % 2.5 mm for safety

min_required_damper_stroke = damper_compression_aero+bump_damper+margin_damper;

%% Check

% Damping coefficient
c = 35000; % Ns/m

ride_frequency_check = 1/(2*pi)*sqrt(wheel_rate/m_sprung);
c_crit = c/(4*pi*m_sprung*ride_frequency_check)/MR^2;
c_critical_wheel = 2 * sqrt(wheel_rate * m_sprung);
c_wheel = c / (MR^2); 
relative_damping = c_wheel / c_critical_wheel;

% % Ride Frequency with tyre stiffness
k_tire = 1000000; % basic tyre radial stiffness
k_total = (wheel_rate * k_tire) / (wheel_rate + k_tire);
ride_frequency_real = 1/(2*pi) * sqrt(k_total / m_sprung);

