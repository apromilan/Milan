%parameter file of springdamper_model.slx
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc
clear

MASS = 260; %overall mass [kg]
QUARTER_MASS = 13;
GRAVITY = 9.81;
H_COG = 0.265; %height of center of gravity
WEIGHT_DISTR_FRONT = 0.5; %weight distribution of front axle
SUSP_MASS = 208; %suspended mass
SUSPCOG = 0.283; %height of suspended mass' cog [m]
H_RC_FRONT = 0.0346; %height of front roll center
H_RC_REAR = 0.0779; %height of rear roll center
WHEELBASE = 1.54;
H_PC = 0.1265; %height of pitch center
TRACK_FRONT = 1.2;
TRACK_REAR = 1.16;
PC_TO_FRONT_AXLE = 0.667; %pitch center's distance from front axle [m]
PC_TO_REAR_AXLE = WHEELBASE-0.667; %pitch center's distance from rear axle [m]
PC_TO_SUSPCOG = 0.205; %pitch center's distance from suspended mass' CoG [m]
RC_TO_WHEEL_FRONT = TRACK_FRONT/2; %roll center's distance from wheel [m] (half track)
RC_TO_WHEEL_REAR = TRACK_REAR/2;
RC_TO_SUSPCOG_FRONT = SUSPCOG-H_RC_FRONT; %roll center's distance from suspended mass' CoG [m]
RC_TO_SUSPCOG_REAR = SUSPCOG-H_RC_REAR;

K_S = 26300; %spring stiffness [N/m] 
K_W = 50000; %tire's spring stiffness [N/m]
C_W = 1000; %damping coefficient of tire [Ns/m]
MR_FRONT = 1.112; %static front motion ratio [-]
MR_REAR = 1.053; %static rear motion ratio [-]

ROLL_INERTIA = 12; %roll inertia around suspended mass' CoG [kg*m^2]
ROLL_INERTIA_RC = ROLL_INERTIA + SUSP_MASS*((RC_TO_SUSPCOG_FRONT+RC_TO_SUSPCOG_REAR)/2)^2;
PITCH_INERTIA = 65; %pitch inertia around suspended mass' CoG [kg*m^2]
PITCH_INERTIA_PC = PITCH_INERTIA + SUSP_MASS*PC_TO_SUSPCOG^2; %pitch inertia around pitch axis [kg*m^2]
YAW_INERTIA = 63; %yaw inertia of the suspended mass [kg*m^2]


%%
%low speed adjuster sweep
%damper data
vel = [0 12.5 25 50 75 100 125 150 175 200 225 250]; %velocity [mm/s]

%0-4.3 0-4.3
pull043043 = [0 270 360 460 520 580 605 640 660 680 700 715]; % [N]
push043043 = [0 -240 -310 -380 -425 -475 -500 -520 -550 -570 -595 -610];

%2-4.3 2-4.3           
pull243243 = [0 60 130 300 380 470 515 570 590 615 640 660];
push243243 = [0 -50 -100 -230 -300 -370 -415 -460 -490 -520 -540 -565];
            
%4-4.3 4-4.3           
pull443443 = [0 40 70 170 270 370 430 495 520 555 590 620];
push443443 = [0 -30 -50 -110 -190 -270 -320 -375 -405 -440 -475 -505];
            
%6-4.3 6-4.3           
pull643643 = [0 35 50 100 170 240 310 380 430 480 520 560];
push643643 = [0 -25 -35 -65 -120 -175 -235 -295 -340 -380 -420 -450];
            
%10-4.3 10-4.3           
pull10431043 = [0 20 30 60 90 130 180 230 285 330 385 435];
push10431043 = [0 -15 -20 -25 -50 -85 -120 -160 -200 -240 -280 -315];

%15-4.3 15-4.3          
pull15431543 = [0 10 15 35 60 85 110 140 180 220 255 300];
push15431543 = [0 -10 -15 -20 -30 -50 -75 -95 -120 -140 -165 -190];
            
%25-4.3 25-4.3           
pull25432543 = [0 5 15 30 45 50 65 80 95 110 130 150];
push25432543 = [0 -5 -10 -15 -20 -30 -35 -40 -55 -65 -80 -95];


%%
%high speed adjuster sweep
%damper data

%0-4.3 0-4.3           
pull043043 = [0 270 360 460 520 580 605 640 660 680 700 715];
push043043 = [0 -240 -310 -380 -425 -475 -500 -520 -550 -570 -595 -610];
           
%0-3 0-3           
pull0303 = [0 285 350 400 430 445 465 485 500 520 540 555];
push0303 = [0 -200 -260 -310 -325 -340 -355 -370 -380 -390 -400 -410];
           
%0-2 0-2           
pull0202 = [0 250 265 290 310 325 340 350 365 380 390 400];
push0202 = [0 -180 -200 -230 -240 -250 -260 -262 -265 -270 -275 -280];
           
%0-1 0-1           
pull0101 = [0 145 155 165 175 190 198 205 215 225 235 240];
push0101 = [0 -90 -100 -110 -115 -120 -125 -130 -140 -150 -160 -170];
           
%0-0 0-0           
pull0000 = [0 50 60 65 70 75 80 85 90 95 100 105];
push0000 = [0 -35 -40 -45 -50 -55 -60 -65 -70 -80 -90 -95];


%selector
pull = pull10431043;
push = push15431543;


%%
% %selector 
% %pitch graphs
% pull = pull043043;
% push = push043043;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull043043, push043043");
% 
% pull = pull243243;
% push = push243243;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull243243, push243243");
% 
% pull = pull443443;
% push = push443443;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull443443, push443443");
% 
% pull = pull643643;
% push = push643643;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull643643, push643643");
% 
% pull = pull10431043;
% push = push10431043;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull10431043, push10431043");
% 
% pull = pull15431543;
% push = push15431543;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull15431543, push15431543");
% 
% pull = pull25432543;
% push = push25432543;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Pitch_Angle);
% legend("Pitch Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull25432543, push25432543");
% 
 %%
% %selector
% %roll graphs
% pull = pull043043;
% push = push043043;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Roll_Angle);
% legend("Roll Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull043043, push043043");
% 
% pull = pull243243;
% push = push243243;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Roll_Angle);
% legend("Roll Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull243243, push243243");
% 
% pull = pull443443;
% push = push443443;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Roll_Angle);
% legend("Roll Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull443443, push443443");
% 
% pull = pull643643;
% push = push643643;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Roll_Angle);
% legend("Roll Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull643643, push643643");
% 
% pull = pull10431043;
% push = push10431043;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Roll_Angle);
% legend("Roll Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull10431043, push10431043");
% 
pull = pull15431543;
push = push15431543;
sim("springdamper_model.slx");
figure
plot(ans.tout,ans.Roll_Angle);
legend("Roll Angle [deg]");
xlabel("Time [s]");
ylabel("Angle [deg]");
title("pull15431543, push15431543");

% pull = pull25432543;
% push = push25432543;
% sim("springdamper_model.slx");
% figure
% plot(ans.tout,ans.Roll_Angle);
% legend("Roll Angle [deg]");
% xlabel("Time [s]");
% ylabel("Angle [deg]");
% title("pull25432543, push25432543");

%%
%selector
%bump graphs
% pull = pull043043;
% push = push043043;
% sim("springdamper_model.slx");
% figure
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Front);
% xlabel("Time [s]");
% ylabel("[m]");
% title("pull043043, push043043");
% hold on
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Rear);
% legend("Wheel displacement front [m]","Wheel displacement rear [m]")
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_f);
% hold on
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_r);
% legend("Chassis displacement front [m]","Chassis displacement rear [m]");
% 
% pull = pull0303;
% push = push0303;
% sim("springdamper_model.slx");
% figure
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Front);
% xlabel("Time [s]");
% ylabel("[m]");
% title("pull0303, push0303");
% hold on
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Rear);
% legend("Wheel displacement front [m]","Wheel displacement rear [m]");
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_f);
% hold on
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_r);
% legend("Chassis displacement front [m]","Chassis displacement rear [m]");
% 
% pull = pull0202;
% push = push0202;
% sim("springdamper_model.slx");
% figure
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Front);
% xlabel("Time [s]");
% ylabel("[m]");
% title("pull0202, push0202");
% hold on
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Rear);
% legend("Wheel displacement front [m]","Wheel displacement rear [m]");
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_f);
% hold on
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_r);
% legend("Chassis displacement front [m]","Chassis displacement rear [m]");
% 
% pull = pull0101;
% push = push0101;
% sim("springdamper_model.slx");
% figure
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Front);
% xlabel("Time [s]");
% ylabel("[m]");
% title("pull0101, push0101");
% hold on
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Rear);
% legend("Wheel displacement front [m]","Wheel displacement rear [m]");
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_f);
% hold on
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_r);
% legend("Chassis displacement front [m]","Chassis displacement rear [m]");
% 
% pull = pull0000;
% push = push0000;
% sim("springdamper_model.slx");
% figure
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Front);
% xlabel("Time [s]");
% ylabel("[m]");
% title("pull0000, push0000");
% hold on
% subplot(2,1,1);
% plot(ans.tout,ans.Bump_Rear);
% legend("Wheel displacement front [m]","Wheel displacement rear [m]");
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_f);
% hold on
% subplot(2,1,2);
% plot(ans.tout,ans.Chassis_r);
% legend("Chassis displacement front [m]","Chassis displacement rear [m]");

