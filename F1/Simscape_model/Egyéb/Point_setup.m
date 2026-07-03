%Manual mode excitation data
freq=1;
gains=[1,1,1,1];
randfreqs=[0.390625;0.78125;1.171875;1.5625;1.953125;2.34375;2.734375;3.125;3.515625;3.90625;4.296875;4.6875;5.078125;5.46875;5.859375;6.25;6.640625;7.03125;7.421875;7.8125;8.203125;8.59375;8.984375;9.375;9.765625;10.15625;10.546875;10.9375;11.328125;11.71875;12.109375;12.5;12.890625;13.28125;13.671875;14.0625;14.453125;14.84375;15.234375;15.625];
randamps=[10.49591923;4.705476284;0.662549913;0.384269953;0.311593354;0.209382221;0.204325601;0.154739559;0.136765137;0.102525115;0.08531332;0.081781358;0.072900273;0.063704491;0.044159256;0.031387117;0.023464901;0.025956012;0.024276853;0.024827089;0.02619116;0.035721079;0.031663958;0.026932528;0.023164477;0.022238526;0.027051585;0.027686883;0.02799874;0.023082441;0.021116797;0.019620154;0.021030517;0.02045726;0.022874877;0.018103965;0.011119875;0.005522729;0.004848736;0.005350151];
randdelay=rand([38,1]);
a_x=1*9.81*0;
a_y=0.2*9.81*0;

%% Quarter 1
%UCA
UCA_front_1=[142.910; 130.958; 518.738];
UCA_rear_1=[-423.62; 168.674; 400.738];
UCA_upright_1=[17.877; 700.155; 465.617];
%LCA
LCA_front_1=[205.47; 126.962; 324.866];
LCA_rear_1=[-407.28; 161.941; 274.481];
LCA_upright_1=[37.956; 725.943; 240.82];
%Wheel
WheelCenter_1=[0; 830; 360];
ContactPatch_1=[0; 830; 0];
%Damper
Damper_chassis_1=[21.475; 40; 520];
Rocker_center_1=[21.475; 210.822; 463.784];
%Tierod
Tierod_inner_1=[170.14; 130.958; 490.912];
Tierod_upright_1=[-30.185; 670.263; 409.492];
%Pushrod
Pushrod_upright_1 = [21.475; 711.066; 295.199];
Pushrod_rocker_1=[21.475; 239.881; 492.269];
%Rocker
Damper_rocker_1=[21.475; 206; 520];
Droplink_rocker_1=[-46.95; 210; 520];
%ARB
Droplink_ARB_1=[-74.5; 0; 520];
ARB_1=[21.475; 0; 520];

%% Quarter 2
%UCA
UCA_front_2=diag([1,-1,1])*UCA_front_1;
UCA_rear_2=diag([1,-1,1])*UCA_rear_1;
UCA_upright_2=diag([1,-1,1])*UCA_upright_1;
%LCA
LCA_front_2=diag([1,-1,1])*LCA_front_1;
LCA_rear_2=diag([1,-1,1])*LCA_rear_1;
LCA_upright_2=diag([1,-1,1])*LCA_upright_1;
%Wheel
WheelCenter_2=diag([1,-1,1])*WheelCenter_1;
ContactPatch_2=diag([1,-1,1])*ContactPatch_1;
%Damper
Damper_chassis_2=diag([1,-1,1])*Damper_chassis_1;
Rocker_center_2=diag([1,-1,1])*Rocker_center_1;
%Tierod
Tierod_inner_2=diag([1,-1,1])*Tierod_inner_1;
Tierod_upright_2=diag([1,-1,1])*Tierod_upright_1;
%Pushrod
Pushrod_upright_2=diag([1,-1,1])*Pushrod_upright_1;
Pushrod_rocker_2=diag([1,-1,1])*Pushrod_rocker_1;
%Rocker
Damper_rocker_2=diag([1,-1,1])*Damper_rocker_1;
% Droplink_rocker_2=diag([1,-1,1])*Droplink_rocker_1;
Droplink_rocker_2 = [6; -210; 520];
%ARB
% Droplink_ARB_2=diag([1,-1,1])*Droplink_ARB_1;
Droplink_ARB_2 = [33.550; 0; 520];
ARB_2=diag([1,-1,1])*ARB_1;

%% Quarter 3
%UCA
UCA_front_3=[-2610.18 ; 149.557; 421.424];
UCA_rear_3=[-3021.19; 79.993; 452.424];
UCA_upright_front_3=[-2916.942; 734.117; 450.646];
UCA_upright_rear_3=[-3030.467; 707.836; 448.340];
%LCA
LCA_front_3=[-2606.68; 153.689; 321.311];
LCA_rear_3=[-2987.79; 77.777; 322.804];
LCA_upright_front_3=[-2967.954; 733.688; 307.922];
LCA_upright_rear_3=[-3100.502; 733.665; 297.614];
%Wheel
WheelCenter_3=[-3000; 775; 360];
ContactPatch_3=[-3000; 775; 0];
%Damper
Damper_chassis_3=[-2671.370; 50.000; 200.000];
Rocker_center_3=[-2878.342; 182.051; 216.568];
%Tierod
Tierod_inner_3=[-2480.31; 133.848; 369.589];
Tierod_upright_3=[-2848.341; 687.484; 378.422];
%Pullrod
Pullrod_upright_3=[-2942.829; 680.416; 529.881];
Pullrod_rocker_3=[-2942.829; 199.933; 206.054];
%Rocker
Damper_rocker_3=[-2855.812; 126.206; 186.815];
Droplink_rocker_3=[-2741.91; 101.449; 464.403];
%ARB
Droplink_ARB_3=[-2800.63; 101.449; 464.403];
ARB_3=[-2800.63; 0; 464.403];

%% Quarter 4
%UCA
UCA_front_4=diag([1,-1,1])*UCA_front_3;
UCA_rear_4=diag([1,-1,1])*UCA_rear_3;
UCA_upright_front_4=diag([1,-1,1])*UCA_upright_front_3;
UCA_upright_rear_4=diag([1,-1,1])*UCA_upright_rear_3;
%LCA
LCA_front_4=diag([1,-1,1])*LCA_front_3;
LCA_rear_4=diag([1,-1,1])*LCA_rear_3;
LCA_upright_front_4=diag([1,-1,1])*LCA_upright_front_3;
LCA_upright_rear_4=diag([1,-1,1])*LCA_upright_rear_3;
%Wheel
WheelCenter_4=diag([1,-1,1])*WheelCenter_3;
ContactPatch_4=diag([1,-1,1])*ContactPatch_3;
%Damper
Damper_chassis_4=diag([1,-1,1])*Damper_chassis_3;
Rocker_center_4=diag([1,-1,1])*Rocker_center_3;
%Tierod
Tierod_inner_4=diag([1,-1,1])*Tierod_inner_3;
Tierod_upright_4=diag([1,-1,1])*Tierod_upright_3;
%Pullrod
Pullrod_upright_4=diag([1,-1,1])*Pullrod_upright_3;
Pullrod_rocker_4=diag([1,-1,1])*Pullrod_rocker_3;
%Rocker
Damper_rocker_4=diag([1,-1,1])*Damper_rocker_3;
Droplink_rocker_4=diag([1,-1,1])*Droplink_rocker_3;
%ARB
Droplink_ARB_4=diag([1,-1,1])*Droplink_ARB_3;
ARB_4=diag([1,-1,1])*ARB_3;


%% Additional parameters
COG = [-1650; 0; 300]; %sprung mass cog

PLANETARY_GEAR_RATIO = 15;
R_WHEEL = single(0.360); %m
% k_t=300; %[N/mm]
% c_t=0;
% c_t1=1000;
ARB_diameter=10;
ARB_K_tors_front=409; %[Nm/rad]
ARB_K_tors_rear=271; %[Nm/rad]
Droplink_diameter=18;
UCA_diameter=18;
LCA_diameter=18;
Tierod_front_diameter=8;
Tierod_rear_diameter=18;
Pushrod_diameter=18;
Pullrod_diameter=18;
Damper_stiffness=500*175.127; %[lbf/in]*conversion constant=[N/m]
% Damper_characteristics_velocity=[-250,-225,-200,-175,-150,-125,-100,-75,-50,-25,-12.5,0,12.5,25,50,75,100,125,150,175,200,225,250]; %[mm/s]
% Damper_characteristics_force=[-190,-165,-140,-120,-95,-75,-50,-30,-20,-15,-10,0,10,15,35,60,85,110,140,180,220,255,300];%[N]
% Damping_lin=polyfit(Damper_characteristics_velocity,Damper_characteristics_force,1);
% Damping_lin=Damping_lin(1)*1000; %[Ns/m]
% Damping_lin = 4000;
mu0=2.5;
mu=2.4;
Rack_diameter=14;
%Inertial quantities
% m_s0=198.860;
% Theta_S=[12.15,62.71,61.82];
% m10=12.608;
% m30=12.688;
% m_tyre=3.7;
% m_rim=1.6;
% m_upright=1.55;
% m1=m10-(m_tyre+m_rim+m_upright);
% m3=m30-(m_tyre+m_rim+m_upright);
% m_rocker_front=0.0499;
% m_rocker_rear=0.0626;
% m_damper_front=0.542;
% m_damper_rear=0.542;
% m_pushrod_front=0.104;
% m_pullrod_rear=0.096;
% m_droplink_front=0.106;
% m_droplink_rear=0.083;
% m_ARB_lever_front=0.026;
% m_ARB_lever_rear=0.026;
% m_ARB_front=0.192;
% m_ARB_rear=0.149;
% m_UCA_front=0.41;
% m_UCA_rear=0.378;
% m_LCA_front=0.394;
% m_LCA_rear=0.340;
% m_tierod_front=0.109;
% m_tierod_rear=0.116;
% m_s=m_s0-(m_rocker_front+m_rocker_rear+m_damper_front+m_damper_front+m_droplink_front+m_droplink_rear+m_ARB_lever_front+m_ARB_lever_rear+m_ARB_front+m_ARB_rear)*2;

m_s0=720.82;
m_s0_driver = 800;
Theta_S=[310, 1250, 1350];
m10=21.5;
m30=21.5;
m_tyre=10;
m_rim=10;
m_upright=1.5;
m1=m10-(m_tyre+m_rim+m_upright);
m3=m30-(m_tyre+m_rim+m_upright);
m_rocker_front=0.5;
m_rocker_rear=0.5;
m_damper_front=0.8;
m_damper_rear=0.8;
m_pushrod_front=0.504;
m_pullrod_rear=0.596;
m_droplink_front=0.106;
m_droplink_rear=0.083;
m_ARB_lever_front=0.026;
m_ARB_lever_rear=0.026;
m_ARB_front=0.192;
m_ARB_rear=0.149;
m_UCA_front=0.41;
m_UCA_rear=0.378;
m_LCA_front=0.894;
m_LCA_rear=0.840;
m_tierod_front=0.409;
m_tierod_rear=0.416;
m_s=m_s0-(m_rocker_front+m_rocker_rear+m_damper_front+m_damper_front+m_droplink_front+m_droplink_rear+m_ARB_lever_front+m_ARB_lever_rear+m_ARB_front+m_ARB_rear)*2;
damping_ratio = 0.7;
c_krit = 2*sqrt(Damper_stiffness*(m_s0/4));
c = damping_ratio*c_krit;
Damping_lin = c;
% PLANETARY_GEAR_RATIO = 15;
% R_WHEEL = single(0.360); %m
% k_t=300; %[N/mm] %spacial contact force
% c_t=0;  %idk
% c_t1=1000; %idk %spacial contact force
% ARB_diameter=14;  %idk
% ARB_K_tors_front=108; %[Nm/rad] %idk 409
% ARB_K_tors_rear=110; %[Nm/rad]  %idk 271
% Droplink_diameter=18;           %idk
% UCA_diameter=18;                %idk
% LCA_diameter=18;                %idk
% Tierod_front_diameter=8;        %idk
% Tierod_rear_diameter=18;        %idk
% Pushrod_diameter=18;            %idk start
% Pullrod_diameter = 18;
% Damper_stiffness=175*175.127; %[lbf/in]*conversion constant=[N/m]
% Damper_characteristics_velocity=[-250,-225,-200,-175,-150,-125,-100,-75,-50,-25,-12.5,0,12.5,25,50,75,100,125,150,175,200,225,250]; %[mm/s]
% Damper_characteristics_force=[-190,-165,-140,-120,-95,-75,-50,-30,-20,-15,-10,0,10,15,35,60,85,110,140,180,220,255,300];%[N]
% Damping_lin=polyfit(Damper_characteristics_velocity,Damper_characteristics_force,1);
% Damping_lin=Damping_lin(1)*1000; %[Ns/m]
% mu0=2.5; %spacial contact force
% mu=2.4;  %spacial contact force
% Rack_diameter=14;  %idk end
% %Inertial quantities
% m_s0=720.82;
% Theta_S=[310, 1250, 1350]; %not sure (sprung now)
% m10=90;  %calculated
% m30=90;  %calcualted
% m_tyre=40;
% m_rim=0; %the whole wheel mass is in tyre
% m_upright=0.8;
% m1=m10-(m_tyre+m_rim+m_upright); %motor+gearbox ig+brakes
% m3=m30-(m_tyre+m_rim+m_upright); %motor
% m_rocker_front=0.21; %itt gatya nagyon nem annyi volt eddig???
% m_rocker_rear=0.22;
% m_damper_front=1.38/2; %/2 cause 2 dampers
% m_damper_rear=1.43/2;
% m_pushrod_front=0.1;
% m_pullrod_rear=0.09;
% m_droplink_front=0.106; %nincs kb jó lehet
% m_droplink_rear=0.083;  %nincs
% m_ARB_lever_front=0.026;
% m_ARB_lever_rear=0.026;
% m_ARB_front=0.192; %nincs  jó lehet
% m_ARB_rear=0.149;  %nincs
% m_UCA_front=0.1; %caculated
% m_UCA_rear=0.1;  %calculated
% m_LCA_front=0.1; %calculated
% m_LCA_rear=0.1;  %calculated
% m_tierod_front=0.109;
% m_tierod_rear=0.116;
% m_s=194.5;   %m_s0-(m_rocker_front+m_rocker_rear+m_damper_front+m_damper_front+m_droplink_front+m_droplink_rear+m_ARB_lever_front+m_ARB_lever_rear+m_ARB_front+m_ARB_rear)*2;
spring_stiffness=700*175.127; %[lbf/in]*conversion constant=[N/m]
ARB_K_tors_front=409; %[Nm/rad]
ARB_K_tors_rear=271; %[Nm/rad]
damping_ratio = 0.7;
c_krit = 2*sqrt(spring_stiffness*(m_s0_driver/4));
c = damping_ratio*c_krit;
damping_coefficient = c;

%% Calculated quantities
ARB_front_length=ARB_1(2)*2;
ARB_lever_front_length=abs(ARB_1(1)-Droplink_ARB_1(1));
Droplink_front_length=norm(Droplink_ARB_1-Droplink_rocker_1);

ARB_rear_length=ARB_3(2)*2;
ARB_lever_rear_length=abs(ARB_3(1)-Droplink_ARB_3(1));
Droplink_rear_length=norm(Droplink_ARB_3-Droplink_rocker_3);

Damper_front_length=norm(Damper_chassis_1-Damper_rocker_1);
Damper_rear_length=norm(Damper_chassis_3-Damper_rocker_3);

Pushrod_front_length=norm(Pushrod_rocker_1-Pushrod_upright_1);
Pullrod_rear_length=norm(Pullrod_rocker_3-Pullrod_upright_3);

Tierod_front_length=norm(Tierod_inner_1-Tierod_upright_1);
Tierod_rear_length=norm(Tierod_inner_3-Tierod_upright_3);

%%%%% Rocker 3D tengely: 
% Creoban berakni az axis-ra egy új koordinátarendszert, ami a fő CS0-tól van offsetelve
% Sheet-re ráállni, majd "set Z normal to screen"
% Simscapben a rigid transformnál rotation sequence, majd x-y-z
% Oda beírni, amit kiír a creo, majd a revolute joint után ugyanazok a számok, csak z-y-x a sorrend és az értékek is
% megfordulnak

% State target hatul a rockernel : 78,429 maybe

%%%%% Quarter 1 %%%%%
UCA_front_1_vec=UCA_front_1-UCA_upright_1; % rúd irányvektora
UCA_front_1_center=(UCA_front_1+UCA_upright_1)/2; % rúd közepe a térben
UCA_rear_1_vec=UCA_rear_1-UCA_upright_1; % hátsó rúd rúd irányvektora
UCA_rear_1_center=(UCA_rear_1+UCA_upright_1)/2; % hátsó közepe rúd közepe a térben
UCA_front_front_length=norm(UCA_front_1_vec); % első rúd hossza
UCA_front_rear_length=norm(UCA_rear_1_vec); % hátsó rúd hossza
UCA_front_1_vec_unit=UCA_front_1_vec/UCA_front_front_length; % első rúd irányvektora
UCA_rear_1_vec_unit=UCA_rear_1_vec/UCA_front_rear_length; % hátsó rúd iránxvektora
Base_to_UCA_front_1=vrrotvec2mat(vrrotvec([0;0;1],UCA_front_1_vec_unit)); % A bázis Z tengely elforgatása a lokális rúdirányba
UCA_front_1_rot=inv(Base_to_UCA_front_1)*vrrotvec2mat(vrrotvec(UCA_front_1_vec_unit,UCA_rear_1_vec_unit))*(Base_to_UCA_front_1);
UCA_front_1_trans=inv(Base_to_UCA_front_1)*(UCA_rear_1_center-UCA_front_1_center);
UCA_to_pushrod_1_trans=inv(Base_to_UCA_front_1)*(Pushrod_upright_1-UCA_front_1_center);

LCA_front_1_vec=LCA_front_1-LCA_upright_1;
LCA_front_1_center=(LCA_front_1+LCA_upright_1)/2;
LCA_rear_1_vec=LCA_rear_1-LCA_upright_1;
LCA_rear_1_center=(LCA_rear_1+LCA_upright_1)/2;
LCA_front_front_length=norm(LCA_front_1_vec);
LCA_front_rear_length=norm(LCA_rear_1_vec);
LCA_front_1_vec_unit=LCA_front_1_vec/LCA_front_front_length;
LCA_rear_1_vec_unit=LCA_rear_1_vec/LCA_front_rear_length;
Base_to_LCA_front_1=vrrotvec2mat(vrrotvec([0;0;1],LCA_front_1_vec_unit));
LCA_front_1_rot=inv(Base_to_LCA_front_1)*vrrotvec2mat(vrrotvec(LCA_front_1_vec_unit,LCA_rear_1_vec_unit))*(Base_to_LCA_front_1);
LCA_front_1_trans=inv(Base_to_LCA_front_1)*(LCA_rear_1_center-LCA_front_1_center);


%%%%% Quarter 2 %%%%%
UCA_front_2_vec=UCA_front_2-UCA_upright_2;
UCA_front_2_center=(UCA_front_2+UCA_upright_2)/2;
UCA_rear_2_vec=UCA_rear_2-UCA_upright_2;
UCA_rear_2_center=(UCA_rear_2+UCA_upright_2)/2;
UCA_front_2_vec_unit=UCA_front_2_vec/UCA_front_front_length;
UCA_rear_2_vec_unit=UCA_rear_2_vec/UCA_front_rear_length;
Base_to_UCA_front_2=vrrotvec2mat(vrrotvec([0;0;1],UCA_front_2_vec_unit));
UCA_front_2_rot=inv(Base_to_UCA_front_2)*vrrotvec2mat(vrrotvec(UCA_front_2_vec_unit,UCA_rear_2_vec_unit))*(Base_to_UCA_front_2);
UCA_front_2_trans=inv(Base_to_UCA_front_2)*(UCA_rear_2_center-UCA_front_2_center);
UCA_to_pushrod_2_trans=inv(Base_to_UCA_front_2)*(Pushrod_upright_2-UCA_front_2_center);

LCA_front_2_vec=LCA_front_2-LCA_upright_2;
LCA_front_2_center=(LCA_front_2+LCA_upright_2)/2;
LCA_rear_2_vec=LCA_rear_2-LCA_upright_2;
LCA_rear_2_center=(LCA_rear_2+LCA_upright_2)/2;
LCA_front_front_length=norm(LCA_front_2_vec);
LCA_front_rear_length=norm(LCA_rear_2_vec);
LCA_front_2_vec_unit=LCA_front_2_vec/LCA_front_front_length;
LCA_rear_2_vec_unit=LCA_rear_2_vec/LCA_front_rear_length;
Base_to_LCA_front_2=vrrotvec2mat(vrrotvec([0;0;1],LCA_front_2_vec_unit));
LCA_front_2_rot=inv(Base_to_LCA_front_2)*vrrotvec2mat(vrrotvec(LCA_front_2_vec_unit,LCA_rear_2_vec_unit))*(Base_to_LCA_front_2);
LCA_front_2_trans=inv(Base_to_LCA_front_2)*(LCA_rear_2_center-LCA_front_2_center);

%%%%% Quarter 3 %%%%%

% Upper Front
UCA_front_3_vec=UCA_front_3-UCA_upright_front_3;
UCA_front_3_center=(UCA_front_3+UCA_upright_front_3)/2;
UCA_rear_front_length=norm(UCA_front_3_vec);
UCA_front_3_vec_unit=UCA_front_3_vec/UCA_rear_front_length;
Base_UCA_front_3_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_3_vec_unit));
UCA_front_3_trans = [0; 0; 0];

% Upper Rear
UCA_rear_3_vec=UCA_rear_3-UCA_upright_rear_3;
UCA_rear_3_center=(UCA_rear_3+UCA_upright_rear_3)/2;
UCA_rear_rear_length=norm(UCA_rear_3_vec);
UCA_rear_3_vec_unit=UCA_rear_3_vec/UCA_rear_rear_length;
Base_UCA_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_3_vec_unit));
UCA_rear_3_trans = [0; 0; 0];

% Pullrod
Pullrod_rear_3_vec = Pullrod_rocker_3-Pullrod_upright_3;
Pullrod_rear_3_center = (Pullrod_rocker_3+Pullrod_upright_3)/2;
Pullrod_rear_rear_length=norm(Pullrod_rear_3_vec);
Pullrod_rear_3_vec_unit=Pullrod_rear_3_vec/Pullrod_rear_rear_length;
Base_Pullrod_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],Pullrod_rear_3_vec_unit));
Pullrod_rear_3_trans = [0; 0; 0];

% Lower Front
UCA_front_3_vec=UCA_front_3-UCA_upright_front_3;
UCA_front_3_center=(UCA_front_3+UCA_upright_front_3)/2;
UCA_rear_front_length=norm(UCA_front_3_vec);
UCA_front_3_vec_unit=UCA_front_3_vec/UCA_rear_front_length;
Base_UCA_front_3_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_3_vec_unit));
UCA_front_3_trans = [0; 0; 0];

% Lower Rear
UCA_rear_3_vec=UCA_rear_3-UCA_upright_rear_3;
UCA_rear_3_center=(UCA_rear_3+UCA_upright_rear_3)/2;
UCA_rear_rear_length=norm(UCA_rear_3_vec);
UCA_rear_3_vec_unit=UCA_rear_3_vec/UCA_rear_rear_length;
Base_UCA_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_3_vec_unit));
UCA_rear_3_trans = [0; 0; 0];


% UCA_rear_3_vec=UCA_rear_3-UCA_upright_rear_3;
% UCA_rear_3_center=(UCA_rear_3+UCA_upright_rear_3)/2;
% 
% UCA_rear_rear_length=norm(UCA_rear_3_vec);
% 
% UCA_rear_3_vec_unit=UCA_rear_3_vec/UCA_rear_rear_length;
% Base_to_UCA_front_3=vrrotvec2mat(vrrotvec([0;0;1],UCA_front_3_vec_unit));
% UCA_front_3_rot=inv(Base_to_UCA_front_3)*vrrotvec2mat(vrrotvec(UCA_front_3_vec_unit,UCA_rear_3_vec_unit))*(Base_to_UCA_front_3);
% UCA_front_3_trans=inv(Base_to_UCA_front_3)*(UCA_rear_3_center-UCA_front_3_center);
% UCA_to_pullrod_3_trans=inv(Base_to_UCA_front_3)*(Pullrod_upright_3-UCA_front_3_center);

% LCA_front_3_vec=LCA_front_3-LCA_upright_front_3;
% LCA_front_3_center=(LCA_front_3+LCA_upright_front_3)/2;
% LCA_rear_3_vec=LCA_rear_3-LCA_upright_rear_3;
% LCA_rear_3_center=(LCA_rear_3+LCA_upright_rear_3)/2;
% LCA_rear_front_length=norm(LCA_front_3_vec);
% LCA_rear_rear_length=norm(LCA_rear_3_vec);
% LCA_front_3_vec_unit=LCA_front_3_vec/LCA_rear_front_length;
% LCA_rear_3_vec_unit=LCA_rear_3_vec/LCA_rear_rear_length;
% Base_to_LCA_front_3=vrrotvec2mat(vrrotvec([0;0;1],LCA_front_3_vec_unit));
% LCA_front_3_rot=inv(Base_to_LCA_front_3)*vrrotvec2mat(vrrotvec(LCA_front_3_vec_unit,LCA_rear_3_vec_unit))*(Base_to_LCA_front_3);
% LCA_front_3_trans=inv(Base_to_LCA_front_3)*(LCA_rear_3_center-LCA_front_3_center);

%%%%% Quarter 4 %%%%%
UCA_front_4_vec=UCA_front_4-UCA_upright_front_4;
UCA_front_4_center=(UCA_front_4+UCA_upright_front_4)/2;
UCA_rear_4_vec=UCA_rear_4-UCA_upright_rear_4;
UCA_rear_4_center=(UCA_rear_4+UCA_upright_rear_4)/2;
UCA_front_4_vec_unit=UCA_front_4_vec/UCA_rear_front_length;
UCA_rear_4_vec_unit=UCA_rear_4_vec/UCA_rear_rear_length;
Base_to_UCA_front_4=vrrotvec2mat(vrrotvec([0;0;1],UCA_front_4_vec_unit));
UCA_front_4_rot=inv(Base_to_UCA_front_4)*vrrotvec2mat(vrrotvec(UCA_front_4_vec_unit,UCA_rear_4_vec_unit))*(Base_to_UCA_front_4);
UCA_front_4_trans=inv(Base_to_UCA_front_4)*(UCA_rear_4_center-UCA_front_4_center);
UCA_to_pullrod_4_trans=inv(Base_to_UCA_front_4)*(Pullrod_upright_4-UCA_front_4_center);

LCA_front_4_vec=LCA_front_4-LCA_upright_front_4;
LCA_front_4_center=(LCA_front_4+LCA_upright_front_4)/2;
LCA_rear_4_vec=LCA_rear_4-LCA_upright_rear_4;
LCA_rear_4_center=(LCA_rear_4+LCA_upright_rear_4)/2;
LCA_rear_front_length=norm(LCA_front_4_vec);
LCA_rear_rear_length=norm(LCA_rear_4_vec);
LCA_front_4_vec_unit=LCA_front_4_vec/LCA_rear_front_length;
LCA_rear_4_vec_unit=LCA_rear_4_vec/LCA_rear_rear_length;
Base_to_LCA_front_4=vrrotvec2mat(vrrotvec([0;0;1],LCA_front_4_vec_unit));
LCA_front_4_rot=inv(Base_to_LCA_front_4)*vrrotvec2mat(vrrotvec(LCA_front_4_vec_unit,LCA_rear_4_vec_unit))*(Base_to_LCA_front_4);
LCA_front_4_trans=inv(Base_to_LCA_front_4)*(LCA_rear_4_center-LCA_front_4_center);

%%%%% Steering %%%%%
Rack_length=norm(Tierod_inner_2-Tierod_inner_1);
Rack_center=(Tierod_inner_2+Tierod_inner_1)/2;
