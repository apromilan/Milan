

%Manual mode excitation data
freq=1;
gains=[1,1,1,1];
randfreqs=[0.390625;0.78125;1.171875;1.5625;1.953125;2.34375;2.734375;3.125;3.515625;3.90625;4.296875;4.6875;5.078125;5.46875;5.859375;6.25;6.640625;7.03125;7.421875;7.8125;8.203125;8.59375;8.984375;9.375;9.765625;10.15625;10.546875;10.9375;11.328125;11.71875;12.109375;12.5;12.890625;13.28125;13.671875;14.0625;14.453125;14.84375;15.234375;15.625];
randamps=[10.49591923;4.705476284;0.662549913;0.384269953;0.311593354;0.209382221;0.204325601;0.154739559;0.136765137;0.102525115;0.08531332;0.081781358;0.072900273;0.063704491;0.044159256;0.031387117;0.023464901;0.025956012;0.024276853;0.024827089;0.02619116;0.035721079;0.031663958;0.026932528;0.023164477;0.022238526;0.027051585;0.027686883;0.02799874;0.023082441;0.021116797;0.019620154;0.021030517;0.02045726;0.022874877;0.018103965;0.011119875;0.005522729;0.004848736;0.005350151];
randdelay=rand([38,1]);
a_x=1*9.81*0;
a_y=0.2*9.81*0;

% pitch, roll centerekre function-t kell írni, de már megvan csak máshol

%% Suspension

front_sheet = "Front_2";
rear_sheet = "Rear_4";
% ==== 1 = Double A Arm with pullrod attached to UCA ====
% ==== 2 = Double A Arm with pushrod attached to LCA ====
% ==== 3 = Double A Arm with pushrod attached to UCA ====
% ==== 4 = Multilink with pullrod ====
% ==== 5 = Multilink with pushrod ====

% Front
front_points = readtable("suspension_points.xlsx", "Sheet", front_sheet);
for i = 1:height(front_points)
    rawName = front_points.Point{i};
    baseName = rawName;
    X_val = front_points.X(i);
    Y_val = front_points.Y(i);
    Z_val = front_points.Z(i);
    varName1 = [baseName, '1'];
    vectorValue1 = [X_val; Y_val; Z_val];
    assignin('base', varName1, vectorValue1);
    varName2 = [baseName, '2'];
    vectorValue2 = [X_val; Y_val * -1; Z_val];
    assignin('base', varName2, vectorValue2);
end

if contains(front_sheet, 'Front_1') || contains(front_sheet, 'Front_2') || contains(front_sheet, 'Front_3')

    ARB_front_length = ARB_1(2)*2;
    ARB_lever_front_length = abs(ARB_1(1)-Droplink_ARB_1(1));
    Droplink_front_length = norm(Droplink_ARB_1-Droplink_rocker_1);
    Damper_front_length = norm(Damper_chassis_1-Damper_rocker_1);
    Push_pull_rod_front_length = norm(Push_pull_rod_rocker_1-Push_pull_rod_upright_1);
    Tierod_front_length = norm(Tierod_inner_1-Tierod_upright_1);

    % Diameters
    ARB_diameter=10;
    Droplink_diameter=18;
    UCA_diameter=18;
    LCA_diameter=18;
    Tierod_front_diameter=8;
    Tierod_rear_diameter=18;
    Push_pull_rod_diameter=18;
    Rack_diameter=14;

    % Quarter 1 %
        UCA_front_1_vec = UCA_front_1-UCA_upright_1; 
        UCA_front_1_center = (UCA_front_1+UCA_upright_1)/2; 
        UCA_rear_1_vec = UCA_rear_1-UCA_upright_1; 
        UCA_rear_1_center = (UCA_rear_1+UCA_upright_1)/2; 
        UCA_front_front_length = norm(UCA_front_1_vec); 
        UCA_front_rear_length = norm(UCA_rear_1_vec); 
        UCA_front_1_vec_unit = UCA_front_1_vec/UCA_front_front_length;
        UCA_rear_1_vec_unit = UCA_rear_1_vec/UCA_front_rear_length; 
        Base_to_UCA_front_1 = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_1_vec_unit));
        UCA_front_1_rot = inv(Base_to_UCA_front_1)*vrrotvec2mat(vrrotvec(UCA_front_1_vec_unit,UCA_rear_1_vec_unit))*(Base_to_UCA_front_1);
        UCA_front_1_trans = inv(Base_to_UCA_front_1)*(UCA_rear_1_center-UCA_front_1_center);
        UCA_to_push_pull_rod_1_trans = inv(Base_to_UCA_front_1)*(Push_pull_rod_upright_1-UCA_front_1_center);
        
        LCA_front_1_vec = LCA_front_1-LCA_upright_1;
        LCA_front_1_center = (LCA_front_1+LCA_upright_1)/2;
        LCA_rear_1_vec = LCA_rear_1-LCA_upright_1;
        LCA_rear_1_center = (LCA_rear_1+LCA_upright_1)/2;
        LCA_front_front_length = norm(LCA_front_1_vec);
        LCA_front_rear_length = norm(LCA_rear_1_vec);
        LCA_front_1_vec_unit = LCA_front_1_vec/LCA_front_front_length;
        LCA_rear_1_vec_unit = LCA_rear_1_vec/LCA_front_rear_length;
        Base_to_LCA_front_1 = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_1_vec_unit));
        LCA_front_1_rot = inv(Base_to_LCA_front_1)*vrrotvec2mat(vrrotvec(LCA_front_1_vec_unit,LCA_rear_1_vec_unit))*(Base_to_LCA_front_1);
        LCA_front_1_trans = inv(Base_to_LCA_front_1)*(LCA_rear_1_center-LCA_front_1_center);
        LCA_to_push_pull_rod_1_trans = inv(Base_to_LCA_front_1)*(Push_pull_rod_upright_1-LCA_front_1_center);
    
    
    % Quarter 2 %
        UCA_front_2_vec = UCA_front_2-UCA_upright_2; 
        UCA_front_2_center = (UCA_front_2+UCA_upright_2)/2; 
        UCA_rear_2_vec = UCA_rear_2-UCA_upright_2; 
        UCA_rear_2_center = (UCA_rear_2+UCA_upright_2)/2; 
        UCA_front_front_length = norm(UCA_front_2_vec); 
        UCA_front_rear_length = norm(UCA_rear_2_vec); 
        UCA_front_2_vec_unit = UCA_front_2_vec/UCA_front_front_length;
        UCA_rear_2_vec_unit = UCA_rear_2_vec/UCA_front_rear_length; 
        Base_to_UCA_front_2 = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_2_vec_unit));
        UCA_front_2_rot = inv(Base_to_UCA_front_2)*vrrotvec2mat(vrrotvec(UCA_front_2_vec_unit,UCA_rear_2_vec_unit))*(Base_to_UCA_front_2);
        UCA_front_2_trans = inv(Base_to_UCA_front_2)*(UCA_rear_2_center-UCA_front_2_center);
        UCA_to_push_pull_rod_2_trans = inv(Base_to_UCA_front_2)*(Push_pull_rod_upright_2-UCA_front_2_center);
        
        LCA_front_2_vec = LCA_front_2-LCA_upright_2;
        LCA_front_2_center = (LCA_front_2+LCA_upright_2)/2;
        LCA_rear_2_vec = LCA_rear_2-LCA_upright_2;
        LCA_rear_2_center = (LCA_rear_2+LCA_upright_2)/2;
        LCA_front_front_length = norm(LCA_front_2_vec);
        LCA_front_rear_length = norm(LCA_rear_2_vec);
        LCA_front_2_vec_unit = LCA_front_2_vec/LCA_front_front_length;
        LCA_rear_2_vec_unit = LCA_rear_2_vec/LCA_front_rear_length;
        Base_to_LCA_front_2 = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_2_vec_unit));
        LCA_front_2_rot = inv(Base_to_LCA_front_2)*vrrotvec2mat(vrrotvec(LCA_front_2_vec_unit,LCA_rear_2_vec_unit))*(Base_to_LCA_front_2);
        LCA_front_2_trans = inv(Base_to_LCA_front_2)*(LCA_rear_2_center-LCA_front_2_center);
        LCA_to_push_pull_rod_2_trans = inv(Base_to_LCA_front_2)*(Push_pull_rod_upright_2-LCA_front_2_center);

elseif contains(front_sheet, 'Front_4') || contains(front_sheet, 'Front_5')

    ARB_front_length = ARB_1(2)*2;
    ARB_lever_front_length = abs(ARB_1(1)-Droplink_ARB_1(1));
    Droplink_front_length = norm(Droplink_ARB_1-Droplink_rocker_1);
    Damper_front_length = norm(Damper_chassis_1-Damper_rocker_1);
    Push_pull_rod_front_length = norm(Push_pull_rod_rocker_1-Push_pull_rod_upright_1);
    Tierod_front_length = norm(Tierod_inner_1-Tierod_upright_1);

    % Quarter 1 %
        % Upper Front
        UCA_front_1_vec=UCA_front_1-UCA_upright_front_1;
        UCA_front_1_center=(UCA_front_1+UCA_upright_front_1)/2;
        UCA_front_front_length=norm(UCA_front_1_vec);
        UCA_front_1_vec_unit=UCA_front_1_vec/UCA_front_front_length;
        Base_UCA_front_1_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_1_vec_unit));
        UCA_front_1_trans = [0; 0; 0];
        
        % Upper Rear
        UCA_rear_1_vec=UCA_rear_1-UCA_upright_rear_1;
        UCA_rear_1_center=(UCA_rear_1+UCA_upright_rear_1)/2;
        UCA_front_rear_length=norm(UCA_rear_1_vec);
        UCA_rear_1_vec_unit=UCA_rear_1_vec/UCA_front_rear_length;
        Base_UCA_rear_1_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_1_vec_unit));
        UCA_rear_1_trans = [0; 0; 0];
        
        % Push/Pullrod
        Push_pull_rod_front_1_vec = Push_pull_rod_rocker_1-Push_pull_rod_upright_1;
        Push_pull_rod_front_1_center = (Push_pull_rod_rocker_1+Push_pull_rod_upright_1)/2;
        Push_pull_rod_front_length=norm(Push_pull_rod_front_1_vec);
        Push_pull_rod_front_1_vec_unit=Push_pull_rod_front_1_vec/Push_pull_rod_front_length;
        Base_Push_pull_rod_front_1_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_front_1_vec_unit));
        Push_pull_rod_front_1_trans = [0; 0; 0];
        
        % Lower Front
        LCA_front_1_vec=LCA_front_1-LCA_upright_front_1;
        LCA_front_1_center=(LCA_front_1+LCA_upright_front_1)/2;
        LCA_front_front_length=norm(LCA_front_1_vec);
        LCA_front_1_vec_unit=LCA_front_1_vec/LCA_front_front_length;
        Base_LCA_front_1_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_1_vec_unit));
        LCA_front_1_trans = [0; 0; 0];
        
        % Lower Rear
        LCA_rear_1_vec=LCA_rear_1-LCA_upright_rear_1;
        LCA_rear_1_center=(LCA_rear_1+LCA_upright_rear_1)/2;
        LCA_front_rear_length=norm(LCA_rear_1_vec);
        LCA_rear_1_vec_unit=LCA_rear_1_vec/LCA_front_rear_length;
        Base_LCA_rear_1_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_rear_1_vec_unit));
        LCA_rear_1_trans = [0; 0; 0];

    % Quarter 2 %
        % Upper Front
        UCA_front_2_vec=UCA_front_2-UCA_upright_front_2;
        UCA_front_2_center=(UCA_front_2+UCA_upright_front_2)/2;
        UCA_front_front_length=norm(UCA_front_2_vec);
        UCA_front_2_vec_unit=UCA_front_2_vec/UCA_front_front_length;
        Base_UCA_front_2_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_2_vec_unit));
        UCA_front_2_trans = [0; 0; 0];
        
        % Upper Rear
        UCA_rear_2_vec=UCA_rear_2-UCA_upright_rear_2;
        UCA_rear_2_center=(UCA_rear_2+UCA_upright_rear_2)/2;
        UCA_front_rear_length=norm(UCA_rear_2_vec);
        UCA_rear_2_vec_unit=UCA_rear_2_vec/UCA_front_rear_length;
        Base_UCA_rear_2_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_2_vec_unit));
        UCA_rear_2_trans = [0; 0; 0];
        
        % Push/Pullrod
        Push_pull_rod_front_2_vec = Push_pull_rod_rocker_2-Push_pull_rod_upright_2;
        Push_pull_rod_front_2_center = (Push_pull_rod_rocker_2+Push_pull_rod_upright_2)/2;
        Push_pull_rod_front_length=norm(Push_pull_rod_front_2_vec);
        Push_pull_rod_front_2_vec_unit=Push_pull_rod_front_2_vec/Push_pull_rod_front_length;
        Base_Push_pull_rod_front_2_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_front_2_vec_unit));
        Push_pull_rod_front_2_trans = [0; 0; 0];
        
        % Lower Front
        LCA_front_2_vec=LCA_front_2-LCA_upright_front_2;
        LCA_front_2_center=(LCA_front_2+LCA_upright_front_2)/2;
        LCA_front_front_length=norm(LCA_front_2_vec);
        LCA_front_2_vec_unit=LCA_front_2_vec/LCA_front_front_length;
        Base_LCA_front_2_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_2_vec_unit));
        LCA_front_2_trans = [0; 0; 0];
        
        % Lower Rear
        LCA_rear_2_vec=LCA_rear_2-LCA_upright_rear_2;
        LCA_rear_2_center=(LCA_rear_2+LCA_upright_rear_2)/2;
        LCA_front_rear_length=norm(LCA_rear_2_vec);
        LCA_rear_2_vec_unit=LCA_rear_2_vec/LCA_front_rear_length;
        Base_LCA_rear_2_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_rear_2_vec_unit));
        LCA_rear_2_trans = [0; 0; 0];

else
    error('Elírtad haver');
end

% Rear
rear_points = readtable("suspension_points.xlsx", "Sheet",rear_sheet);

for i = 1:height(rear_points)
    rawName = rear_points.Point{i};
    baseName = rawName;
    X_val = rear_points.X(i);
    Y_val = rear_points.Y(i);
    Z_val = rear_points.Z(i);
    varName1 = [baseName, '3'];
    vectorValue1 = [X_val; Y_val; Z_val];
    assignin('base', varName1, vectorValue1);
    varName2 = [baseName, '4'];
    vectorValue2 = [X_val; Y_val * -1; Z_val];
    assignin('base', varName2, vectorValue2);
end

if contains(rear_sheet, 'Rear_1') || contains(rear_sheet, 'Rear_2') || contains(rear_sheet, 'Rear_3')

    ARB_rear_length = ARB_3(2)*2;
    ARB_lever_rear_length = abs(ARB_3(1)-Droplink_ARB_3(1));
    Droplink_rear_length = norm(Droplink_ARB_3-Droplink_rocker_3);
    Damper_rear_length = norm(Damper_chassis_3-Damper_rocker_3);
    Push_pull_rod_rear_length = norm(Push_pull_rod_rocker_3-Push_pull_rod_upright_3);
    Tierod_rear_length = norm(Tierod_inner_3-Tierod_upright_3);

    % Diameters
    ARB_diameter=10;
    Droplink_diameter=18;
    UCA_diameter=18;
    LCA_diameter=18;
    Tierod_front_diameter=8;
    Tierod_rear_diameter=18;
    Push_pull_rod_diameter=18;
    Rack_diameter=14;

    % Quarter 3 %
    UCA_front_3_vec = UCA_front_3-UCA_upright_3; 
    UCA_front_3_center = (UCA_front_3+UCA_upright_3)/2; 
    UCA_rear_3_vec = UCA_rear_3-UCA_upright_3; 
    UCA_rear_3_center = (UCA_rear_3+UCA_upright_3)/2; 
    UCA_rear_front_length = norm(UCA_front_3_vec); 
    UCA_rear_rear_length = norm(UCA_rear_3_vec); 
    UCA_front_3_vec_unit = UCA_front_3_vec/UCA_rear_front_length;
    UCA_rear_3_vec_unit = UCA_rear_3_vec/UCA_rear_rear_length; 
    Base_to_UCA_front_3 = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_3_vec_unit));
    UCA_front_3_rot = inv(Base_to_UCA_front_3)*vrrotvec2mat(vrrotvec(UCA_front_3_vec_unit,UCA_rear_3_vec_unit))*(Base_to_UCA_front_3);
    UCA_front_3_trans = inv(Base_to_UCA_front_3)*(UCA_rear_3_center-UCA_front_3_center);
    UCA_to_push_pull_rod_3_trans = inv(Base_to_UCA_front_3)*(Push_pull_rod_upright_3-UCA_front_3_center);
    
    LCA_front_3_vec = LCA_front_3-LCA_upright_3; 
    LCA_front_3_center = (LCA_front_3+LCA_upright_3)/2; 
    LCA_rear_3_vec = LCA_rear_3-LCA_upright_3; 
    LCA_rear_3_center = (LCA_rear_3+LCA_upright_3)/2; 
    LCA_rear_front_length = norm(LCA_front_3_vec); 
    LCA_rear_rear_length = norm(LCA_rear_3_vec); 
    LCA_front_3_vec_unit = LCA_front_3_vec/LCA_rear_front_length;
    LCA_rear_3_vec_unit = LCA_rear_3_vec/LCA_rear_rear_length; 
    Base_to_LCA_front_3 = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_3_vec_unit));
    LCA_front_3_rot = inv(Base_to_LCA_front_3)*vrrotvec2mat(vrrotvec(LCA_front_3_vec_unit,LCA_rear_3_vec_unit))*(Base_to_LCA_front_3);
    LCA_front_3_trans = inv(Base_to_LCA_front_3)*(LCA_rear_3_center-LCA_front_3_center);
    LCA_to_push_pull_rod_3_trans = inv(Base_to_LCA_front_3)*(Push_pull_rod_upright_3-LCA_front_3_center);
    
    
    % Quarter 4 %
    UCA_front_4_vec = UCA_front_4-UCA_upright_4; 
    UCA_front_4_center = (UCA_front_4+UCA_upright_4)/2; 
    UCA_rear_4_vec = UCA_rear_4-UCA_upright_4; 
    UCA_rear_4_center = (UCA_rear_4+UCA_upright_4)/2; 
    UCA_rear_front_length = norm(UCA_front_4_vec); 
    UCA_rear_rear_length = norm(UCA_rear_4_vec); 
    UCA_front_4_vec_unit = UCA_front_4_vec/UCA_rear_front_length;
    UCA_rear_4_vec_unit = UCA_rear_4_vec/UCA_rear_rear_length; 
    Base_to_UCA_front_4 = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_4_vec_unit));
    UCA_front_4_rot = inv(Base_to_UCA_front_4)*vrrotvec2mat(vrrotvec(UCA_front_4_vec_unit,UCA_rear_4_vec_unit))*(Base_to_UCA_front_4);
    UCA_front_4_trans = inv(Base_to_UCA_front_4)*(UCA_rear_4_center-UCA_front_4_center);
    UCA_to_push_pull_rod_4_trans = inv(Base_to_UCA_front_4)*(Push_pull_rod_upright_4-UCA_front_4_center);
    
    LCA_front_4_vec = LCA_front_4-LCA_upright_4; 
    LCA_front_4_center = (LCA_front_4+LCA_upright_4)/2; 
    LCA_rear_4_vec = LCA_rear_4-LCA_upright_4; 
    LCA_rear_4_center = (LCA_rear_4+LCA_upright_4)/2; 
    LCA_rear_front_length = norm(LCA_front_4_vec); 
    LCA_rear_rear_length = norm(LCA_rear_4_vec); 
    LCA_front_4_vec_unit = LCA_front_4_vec/LCA_rear_front_length;
    LCA_rear_4_vec_unit = LCA_rear_4_vec/LCA_rear_rear_length; 
    Base_to_LCA_front_4 = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_4_vec_unit));
    LCA_front_4_rot = inv(Base_to_LCA_front_4)*vrrotvec2mat(vrrotvec(LCA_front_4_vec_unit,LCA_rear_4_vec_unit))*(Base_to_LCA_front_4);
    LCA_front_4_trans = inv(Base_to_LCA_front_4)*(LCA_rear_4_center-LCA_front_4_center);
    LCA_to_push_pull_rod_4_trans = inv(Base_to_LCA_front_4)*(Push_pull_rod_upright_4-LCA_front_4_center);


elseif contains(rear_sheet, 'Rear_4') || contains(rear_sheet, 'Rear_5')

    ARB_rear_length = ARB_3(2)*2;
    ARB_lever_rear_length = abs(ARB_3(1)-Droplink_ARB_3(1));
    Droplink_rear_length = norm(Droplink_ARB_3-Droplink_rocker_3);
    Damper_rear_length = norm(Damper_chassis_3-Damper_rocker_3);
    Push_pull_rod_rear_length = norm(Push_pull_rod_rocker_3-Push_pull_rod_upright_3);
    Tierod_rear_length = norm(Tierod_inner_3-Tierod_upright_3);

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
        
        % Push/Pullrod
        Push_pull_rod_rear_3_vec = Push_pull_rod_rocker_3-Push_pull_rod_upright_3;
        Push_pull_rod_rear_3_center = (Push_pull_rod_rocker_3+Push_pull_rod_upright_3)/2;
        Push_pull_rod_rear_length=norm(Push_pull_rod_rear_3_vec);
        Push_pull_rod_rear_3_vec_unit=Push_pull_rod_rear_3_vec/Push_pull_rod_rear_length;
        Base_Push_pull_rod_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_rear_3_vec_unit));
        Push_pull_rod_rear_3_trans = [0; 0; 0];
        
        % Lower Front
        LCA_front_3_vec=LCA_front_3-LCA_upright_front_3;
        LCA_front_3_center=(LCA_front_3+LCA_upright_front_3)/2;
        LCA_rear_front_length=norm(LCA_front_3_vec);
        LCA_front_3_vec_unit=LCA_front_3_vec/LCA_rear_front_length;
        Base_LCA_front_3_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_3_vec_unit));
        LCA_front_3_trans = [0; 0; 0];
        
        % Lower Rear
        LCA_rear_3_vec=LCA_rear_3-LCA_upright_rear_3;
        LCA_rear_3_center=(LCA_rear_3+LCA_upright_rear_3)/2;
        LCA_rear_rear_length=norm(LCA_rear_3_vec);
        LCA_rear_3_vec_unit=LCA_rear_3_vec/LCA_rear_rear_length;
        Base_LCA_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_rear_3_vec_unit));
        LCA_rear_3_trans = [0; 0; 0];

    % Quarter 4 %
        % Upper Front
        UCA_front_4_vec=UCA_front_4-UCA_upright_front_4;
        UCA_front_4_center=(UCA_front_4+UCA_upright_front_4)/2;
        UCA_rear_front_length=norm(UCA_front_4_vec);
        UCA_front_4_vec_unit=UCA_front_4_vec/UCA_rear_front_length;
        Base_UCA_front_4_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_4_vec_unit));
        UCA_front_4_trans = [0; 0; 0];
    
        % Upper Rear
        UCA_rear_4_vec=UCA_rear_4-UCA_upright_rear_4;
        UCA_rear_4_center=(UCA_rear_4+UCA_upright_rear_4)/2;
        UCA_rear_rear_length=norm(UCA_rear_4_vec);
        UCA_rear_4_vec_unit=UCA_rear_4_vec/UCA_rear_rear_length;
        Base_UCA_rear_4_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_4_vec_unit));
        UCA_rear_4_trans = [0; 0; 0];
    
        % Push/Pullrod
        Push_pull_rod_rear_4_vec = Push_pull_rod_rocker_4-Push_pull_rod_upright_4;
        Push_pull_rod_rear_4_center = (Push_pull_rod_rocker_4+Push_pull_rod_upright_4)/2;
        Push_pull_rod_rear_length=norm(Push_pull_rod_rear_4_vec);
        Push_pull_rod_rear_4_vec_unit=Push_pull_rod_rear_4_vec/Push_pull_rod_rear_length;
        Base_Push_pull_rod_rear_4_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_rear_4_vec_unit));
        Push_pull_rod_rear_4_trans = [0; 0; 0];
    
        % Lower Front
        LCA_front_4_vec=LCA_front_4-LCA_upright_front_4;
        LCA_front_4_center=(LCA_front_4+LCA_upright_front_4)/2;
        LCA_rear_front_length=norm(LCA_front_4_vec);
        LCA_front_4_vec_unit=LCA_front_4_vec/LCA_rear_front_length;
        Base_LCA_front_4_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_4_vec_unit));
        LCA_front_4_trans = [0; 0; 0];
    
        % Lower Rear
        LCA_rear_4_vec=LCA_rear_4-LCA_upright_rear_4;
        LCA_rear_4_center=(LCA_rear_4+LCA_upright_rear_4)/2;
        LCA_rear_rear_length=norm(LCA_rear_4_vec);
        LCA_rear_4_vec_unit=LCA_rear_4_vec/LCA_rear_rear_length;
        Base_LCA_rear_4_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_rear_4_vec_unit));
        LCA_rear_4_trans = [0; 0; 0];

else
    error('Elírtad haver');
end




% % Quarter 1
% %UCA
% UCA_front_1=[142.910; 130.958; 588.738];
% UCA_rear_1=[-423.620; 168.674; 470.738];
% UCA_upright_1=[-51.340; 691.900; 521.820];
% %LCA
% LCA_front_1=[205.470; 126.962; 394.866];
% LCA_rear_1=[-407.280; 161.941; 344.481];
% LCA_upright_1=[-20.720; 746.210; 303.980];
% %Wheel
% WheelCenter_1=[0; 830; 360];
% ContactPatch_1=[0; 830; 0];
% %Damper
% Damper_chassis_1=[-20.720; 20; 600.784];
% %Tierod
% Tierod_inner_1=[170.14; 130.958; 540.912];
% Tierod_upright_1=[25.017; 696.430; 481.810];
% %Pushrod
% Pushrod_upright_1 = [-20.720; 709.481; 319.812];
% %Rocker
% Rocker_center_1=[-20.720; 120.822; 550.784];
% Pushrod_rocker_1=[-20.720; 140.881; 570.784];
% Damper_rocker_1=[-20.720; 130.881; 600.784];
% Droplink_rocker_1=[-46.95; 210; 520];
% % ARB
% Droplink_ARB_1=[-74.5; 0; 520];
% ARB_1=[21.475; 0; 520];
% 
% % Quarter 2
% %UCA
% UCA_front_2=diag([1,-1,1])*UCA_front_1;
% UCA_rear_2=diag([1,-1,1])*UCA_rear_1;
% UCA_upright_2=diag([1,-1,1])*UCA_upright_1;
% %LCA
% LCA_front_2=diag([1,-1,1])*LCA_front_1;
% LCA_rear_2=diag([1,-1,1])*LCA_rear_1;
% LCA_upright_2=diag([1,-1,1])*LCA_upright_1;
% %Wheel
% WheelCenter_2=diag([1,-1,1])*WheelCenter_1;
% ContactPatch_2=diag([1,-1,1])*ContactPatch_1;
% %Damper
% Damper_chassis_2=diag([1,-1,1])*Damper_chassis_1;
% %Tierod
% Tierod_inner_2=diag([1,-1,1])*Tierod_inner_1;
% Tierod_upright_2=diag([1,-1,1])*Tierod_upright_1;
% %Pushrod
% Pushrod_upright_2=diag([1,-1,1])*Pushrod_upright_1;
% %Rocker
% Rocker_center_2=diag([1,-1,1])*Rocker_center_1;
% Pushrod_rocker_2=diag([1,-1,1])*Pushrod_rocker_1;
% Damper_rocker_2=diag([1,-1,1])*Damper_rocker_1;
% % Droplink_rocker_2=diag([1,-1,1])*Droplink_rocker_1;
% Droplink_rocker_2 = [6; -210; 520];
% % ARB
% Droplink_ARB_2=diag([1,-1,1])*Droplink_ARB_1;
% Droplink_ARB_2 = [33.550; 0; 520];
% ARB_2=diag([1,-1,1])*ARB_1;

% % Quarter 3
% %UCA
% UCA_front_3=[-2610.180; 149.557; 471.424];
% UCA_rear_3=[-3021.190; 79.993; 502.424];
% UCA_upright_front_3=[-2963.942; 704.412; 494.308];
% UCA_upright_rear_3=[-3046.858; 707.128; 505.611];
% %LCA
% LCA_front_3=[-2606.680; 153.689; 371.311];
% LCA_rear_3=[-2987.790; 77.777; 372.804];
% LCA_upright_front_3=[-2968.608; 733.282; 358.001];
% LCA_upright_rear_3=[-3017.324; 737.420; 348.449];
% %Wheel
% WheelCenter_3=[-3000; 775; 360];
% ContactPatch_3=[-3000; 775; 0];
% %Damper
% Damper_chassis_3=[-3051.844; 120.000; 156.805];
% %Tierod
% Tierod_inner_3=[-2480.310; 133.848; 419.589];
% Tierod_upright_3=[-2900.351; 687.442; 430.244];
% %Pullrod
% Pullrod_upright_3=[-2942.829; 655.968; 562.495];
% %Rocker
% Rocker_center_3=[-2881.215; 167.295; 240.816];
% Pullrod_rocker_3=[-2942.829; 194.264; 234.154];
% Damper_rocker_3=[-2918.002; 113.009; 186.805];
% Droplink_rocker_3=[-2741.91; 101.449; 464.403];
% %ARB
% Droplink_ARB_3=[-2800.63; 101.449; 464.403];
% ARB_3=[-2800.63; 0; 464.403];
% 
% % Quarter 4
% %UCA
% UCA_front_4=diag([1,-1,1])*UCA_front_3;
% UCA_rear_4=diag([1,-1,1])*UCA_rear_3;
% UCA_upright_front_4=diag([1,-1,1])*UCA_upright_front_3;
% UCA_upright_rear_4=diag([1,-1,1])*UCA_upright_rear_3;
% %LCA
% LCA_front_4=diag([1,-1,1])*LCA_front_3;
% LCA_rear_4=diag([1,-1,1])*LCA_rear_3;
% LCA_upright_front_4=diag([1,-1,1])*LCA_upright_front_3;
% LCA_upright_rear_4=diag([1,-1,1])*LCA_upright_rear_3;
% %Wheel
% WheelCenter_4=diag([1,-1,1])*WheelCenter_3;
% ContactPatch_4=diag([1,-1,1])*ContactPatch_3;
% %Damper
% Damper_chassis_4=diag([1,-1,1])*Damper_chassis_3;
% %Tierod
% Tierod_inner_4=diag([1,-1,1])*Tierod_inner_3;
% Tierod_upright_4=diag([1,-1,1])*Tierod_upright_3;
% %Pullrod
% Pullrod_upright_4=diag([1,-1,1])*Pullrod_upright_3;
% %Rocker
% Rocker_center_4=diag([1,-1,1])*Rocker_center_3;
% Pullrod_rocker_4=diag([1,-1,1])*Pullrod_rocker_3;
% Damper_rocker_4=diag([1,-1,1])*Damper_rocker_3;
% Droplink_rocker_4=diag([1,-1,1])*Droplink_rocker_3;
% %ARB
% Droplink_ARB_4=diag([1,-1,1])*Droplink_ARB_3;
% ARB_4=diag([1,-1,1])*ARB_3;


%% Parameters

% Bruh
PLANETARY_GEAR_RATIO = 15;
R_WHEEL = 0.36;

wheelbase = 3;
front_track = 1.66;
rear_track = 1.55;
COG = [-1650; 0; 300]; %sprung mass cog
aero_distribution = 0.45; % [%]
COP = [-wheelbase*aero_distribution*1000; 0; 100];
g = 9.81;
front_cog_height = 0.28;
rear_cog_height = 0.33;
weight_distribution = 0.45;
a = wheelbase*(1-weight_distribution);
b = wheelbase*weight_distribution;
wheel_radius = 0.360; %m
% load('C:\Users\aprom\Desktop\Milan\FRT\Tyre analysis\Round 9\Tyre Data\F1\TyreParamsF1');
parameterStruct = mfeval.readTIR('Tyre Models\F1_tyre_modell_v5.tir');

% % Biztosítjuk, hogy sima struktúra legyen
% if ~isstruct(TyreParamsF1)
%     TyreParamsF1 = struct(TyreParamsF1);
% end
% 
% % Base workspace-be rakjuk
% assignin('base', 'TyreParamsF1', TyreParamsF1);
% % % % 1. Busz objektum létrehozása
% % % % Megjegyzés: Ha a struktúrád neve 'TyreParamsF1', a createObject egy 'slBus1' nevű 
% % % % változót hoz létre a Base Workspace-ben.
% % % Simulink.Bus.createObject(TyreParamsF1); 
% % % TyreBus = slBus1; 
% % % clear slBus1; % Takarítás
% % % 
% % % % 2. Simulink Paraméter létrehozása
% % % parameterStruct = Simulink.Parameter; % Használd azt a nevet, amit a hibaüzenet ír!
% % % parameterStruct.Value = TyreParamsF1;
% % % parameterStruct.DataType = 'Bus: TyreBus';
% % % parameterStruct.CoderInfo.StorageClass = 'ExportedGlobal';

% Weights
m10=21.5;
m30=21.5;
m_tyre=8;
m_rim=4;
m_upright=1.5;
m1=m10-(m_tyre+m_rim+m_upright);
m3=m30-(m_tyre+m_rim+m_upright);
m_s0=800.82;
m_fuel = 10;
m_driver = 80;
m_s0_driver = m_s0+m_fuel+m_driver;
m_sprung = m_s0_driver-2*m10-2*m30; 
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

% Inertias
roll_inertia = 310;
pitch_inertia = 1250;
yaw_inertia = 850;
Theta_S = [roll_inertia, pitch_inertia, yaw_inertia];
tyre_IYY = (m_tyre+m_rim)*wheel_radius^2+0.0;
tyre_IXX = 0.651;
vehicle_inertia_at_wheel_2wd = m_s0_driver/2*wheel_radius^2;
vehicle_inertia_at_wheel_4wd = m_s0_driver/4*wheel_radius^2;
I_engine = 0.2;

% Stiffnesses
% A sima erőnél az emelőhatás csak egyszer működik (a karok aránya határozza meg az erőt). 
% A merevségnél azért kell a négyzet, mert az emelő kétszeresen büntet: egyszer lefelezi (ha MR=2) a rugó elmozdulását, másodszor pedig lefelezi (ha MR=2) a rugóból visszajutó erőt is!
% Front
front_spring = 8000;
front_spring_stiffness = front_spring*175.127; %[lbf/in]*conversion constant=[N/m]
front_static_length = 110.881; % mm
front_static_motion_ratio = 1.860; % needs optkin
front_lower_limit_motion_ratio = 1.903; % needs optkin
front_upper_limit_motion_ratio = 1.806; % needs optkin
front_wheel_fz = m_s0_driver*weight_distribution/2*g;
front_static_spring_force = front_wheel_fz*front_static_motion_ratio;
front_static_spring_compression = front_static_spring_force/front_spring_stiffness*1000; % mm! ez lesz a delta x, amit hozzá kell adni a beépítési hosszhoz és kijön a equilibrium position
front_equilibrium_position = front_static_length+front_static_spring_compression;
front_lower_limit = front_static_length-30/front_lower_limit_motion_ratio;
front_upper_limit = front_static_length+30/front_upper_limit_motion_ratio;
ARB_K_tors_front = 409; %[Nm/rad]
front_damping_ratio = 0.7;
front_c_krit = 2*sqrt(front_spring_stiffness/front_static_motion_ratio^2*(m_sprung*weight_distribution)/2);
front_c = front_damping_ratio*front_c_krit;
front_damping_coefficient = front_c*front_static_motion_ratio^2;
front_roll_center = 183.615;
pitch_center = 140;

% Rear 
rear_spring = 8000;
rear_spring_stiffness = rear_spring*175.127; %[lbf/in]*conversion constant=[N/m]
rear_static_length = 137.341; % mm
rear_static_motion_ratio = 1.717; % needs optkin
rear_lower_limit_motion_ratio = 2.131; % needs optkin
rear_upper_limit_motion_ratio = 1.578; % needs optkin
rear_wheel_fz = m_s0_driver*(1-weight_distribution)/2*g;
rear_static_spring_force = rear_wheel_fz*rear_static_motion_ratio;
rear_static_spring_compression = rear_static_spring_force/rear_spring_stiffness*1000; % mm! ez lesz a delta x, amit hozzá kell adni a beépítési hosszhoz és kijön a equilibrium position
rear_equilibrium_position = rear_static_length+rear_static_spring_compression;
rear_lower_limit = rear_static_length-30/rear_lower_limit_motion_ratio;
rear_upper_limit = rear_static_length+30/rear_upper_limit_motion_ratio;
ARB_K_tors_rear = 271; % [Nm/rad]
rear_damping_ratio = 0.7;
rear_c_krit = 2*sqrt(rear_spring_stiffness/rear_static_motion_ratio^2*(m_sprung*(1-weight_distribution))/2);
rear_c = rear_damping_ratio*rear_c_krit;
rear_damping_coefficient = rear_c*rear_static_motion_ratio^2;
rear_roll_center = 100;

% Aerodynamics
cl = 5;
cd = 1;
A = 1.6;
rho = 1.22;

% Gearbox
gear_ratios = [3.25, 2.35, 1.9, 1.6, 1.35, 1.2, 1.05, 0.9]; % 3.25 és 2.35 átírva
final_drive = 4.2;
% gear_idx = gear;

% Engine
load("Engine\powertrain_torque.mat");
load("Engine\revolution.mat");
torque_vector = powertrain_torque;
rpm_vector = powertrain_rpm;

% % Driver 
% acc_pedal = single(acceleration_pedal/100);

% Braking System
max_braking_torque = 5000;
brake_balance = 0.54;

%% Calculated quantities

static_load = g*m_s0_driver;
static_load_fl = m_s0_driver*weight_distribution/2*g;
static_load_fr = m_s0_driver*weight_distribution/2*g;
static_load_rl = m_s0_driver*(1-weight_distribution)/2*g;
static_load_rr = m_s0_driver*(1-weight_distribution)/2*g;

%% Rudak egymáshoz kényszerezése
    

%% Fogasléces kormánymű

%%%%% Steering %%%%%
Rack_length=norm(Tierod_inner_2-Tierod_inner_1);
Rack_center=(Tierod_inner_2+Tierod_inner_1)/2;

%% Setup tippek

%%%%% Rocker 3D tengely: 
% Creoban berakni az axis-ra egy új koordinátarendszert, ami a fő CS0-tól van offsetelve
% Sheet-re ráállni, majd "set Z normal to screen"
% Simscapben a rigid transformnál rotation sequence, majd x-y-z
% Oda beírni, amit kiír a creo, majd a revolute joint után ugyanazok a számok, csak z-y-x a sorrend és az értékek is
% megfordulnak

% State target hatul a rockernel : 78,429 maybe