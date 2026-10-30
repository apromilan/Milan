

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
    ARB_front_diameter=10;
    Droplink_front_diameter=18;
    UCA_front_diameter=18;
    LCA_front_diameter=18;
    Tierod_front_diameter=8;
    Push_pull_rod_front_diameter=18;
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

        R_normal_1 = pointsToRotationMatrix(Rocker_center_1, Rocker_axis_1);
        R_back_1 = R_normal_1';
        R_normal_2 = pointsToRotationMatrix(Rocker_center_2, Rocker_axis_2);
        R_back_2 = R_normal_2';

elseif contains(front_sheet, 'Front_4') || contains(front_sheet, 'Front_5')

    ARB_front_length = ARB_1(2)*2;
    ARB_lever_front_length = abs(ARB_1(1)-Droplink_ARB_1(1));
    Droplink_front_length = norm(Droplink_ARB_1-Droplink_rocker_1);
    Damper_front_length = norm(Damper_chassis_1-Damper_rocker_1);
    Tierod_front_length = norm(Tierod_inner_1-Tierod_upright_1);

    % Diameters
    ARB_front_diameter=10;
    Droplink_front_diameter=18;
    UCA_front_diameter=18;
    LCA_front_diameter=18;
    Tierod_front_diameter=8;
    Push_pull_rod_front_diameter=18;
    Rack_diameter=14;

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

        R_normal_1 = pointsToRotationMatrix(Rocker_center_1, Rocker_axis_1);
        R_back_1 = R_normal_1';
        R_normal_2 = pointsToRotationMatrix(Rocker_center_2, Rocker_axis_2);
        R_back_2 = R_normal_2';

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
    ARB_rear_diameter=10;
    Droplink_rear_diameter=18;
    UCA_rear_diameter=18;
    LCA_rear_diameter=18;
    Tierod_rear_diameter=8;
    Push_pull_rod_rear_diameter=18;

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

    R_normal_3 = pointsToRotationMatrix(Rocker_center_3, Rocker_axis_3);
    R_back_3 = R_normal_3';
    R_normal_4 = pointsToRotationMatrix(Rocker_center_4, Rocker_axis_4);
    R_back_4 = R_normal_4';

elseif contains(rear_sheet, 'Rear_4') || contains(rear_sheet, 'Rear_5')

    ARB_rear_length = ARB_3(2)*2;
    ARB_lever_rear_length = abs(ARB_3(1)-Droplink_ARB_3(1));
    Droplink_rear_length = norm(Droplink_ARB_3-Droplink_rocker_3);
    Damper_rear_length = norm(Damper_chassis_3-Damper_rocker_3);
    Tierod_rear_length = norm(Tierod_inner_3-Tierod_upright_3);

    % Diameters
    ARB_rear_diameter=10;
    Droplink_rear_diameter=18;
    UCA_rear_diameter=18;
    LCA_rear_diameter=18;
    Tierod_rear_diameter=8;
    Push_pull_rod_rear_diameter=18;

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

        R_normal_3 = pointsToRotationMatrix(Rocker_center_3, Rocker_axis_3);
        R_back_3 = R_normal_3';
        R_normal_4 = pointsToRotationMatrix(Rocker_center_4, Rocker_axis_4);
        R_back_4 = R_normal_4';

else
    error('Elírtad haver');
end

%% Parameters

% Bruh
PLANETARY_GEAR_RATIO = 15;
R_WHEEL = 0.36;

wheelbase = 3;
front_track = 1.6;
rear_track = 1.6;
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
parameterStruct = mfeval.readTIR('Tyre Models\F1_tyre_modell_v5.tir');
fl_static_toe = 0;
fr_static_toe = 0;
rl_static_toe = 0;
rr_static_toe = 0;
fl_static_camber = 0;
fr_static_camber = 0;
rl_static_camber = 0;
rr_static_camber = 0;

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
m_push_pull_rod_front=0.504;
m_push_pull_rod_rear=0.596;
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
% front_spring = 8000;
front_spring = 600;
front_spring_stiffness = front_spring*175.127; %[lbf/in]*conversion constant=[N/m]
front_static_length = 183.484; % mm
front_static_motion_ratio = 0.687; % needs optkin
front_lower_limit_motion_ratio = 0.671; % needs optkin
front_upper_limit_motion_ratio = 0.701; % needs optkin
front_wheel_fz = m_s0_driver*weight_distribution/2*g;
front_static_spring_force = front_wheel_fz*front_static_motion_ratio;
front_static_spring_compression = front_static_spring_force/front_spring_stiffness*1000; % mm! ez lesz a delta x, amit hozzá kell adni a beépítési hosszhoz és kijön a equilibrium position
front_equilibrium_position = front_static_length+front_static_spring_compression;
front_lower_limit = front_static_length-15/front_lower_limit_motion_ratio;
front_upper_limit = front_static_length+15/front_upper_limit_motion_ratio;
ARB_K_tors_front = 409; %[Nm/rad]
front_damping_ratio = 0.7;
front_c_krit = 2*sqrt(front_spring_stiffness/front_static_motion_ratio^2*(m_sprung*weight_distribution)/2);
front_c = front_damping_ratio*front_c_krit;
front_damping_coefficient = front_c*front_static_motion_ratio^2;
front_roll_center = 100;
pitch_center = 200;

% Rear 
% rear_spring = 8000;
rear_spring = 700;
rear_spring_stiffness = rear_spring*175.127; %[lbf/in]*conversion constant=[N/m]
rear_static_length = 176.208; % mm
rear_static_motion_ratio = 0.743; % needs optkin
rear_lower_limit_motion_ratio = 0.703; % needs optkin
rear_upper_limit_motion_ratio = 0.778; % needs optkin
rear_wheel_fz = m_s0_driver*(1-weight_distribution)/2*g;
rear_static_spring_force = rear_wheel_fz*rear_static_motion_ratio;
rear_static_spring_compression = rear_static_spring_force/rear_spring_stiffness*1000; % mm! ez lesz a delta x, amit hozzá kell adni a beépítési hosszhoz és kijön a equilibrium position
rear_equilibrium_position = rear_static_length+rear_static_spring_compression;
rear_lower_limit = rear_static_length-15/rear_lower_limit_motion_ratio;
rear_upper_limit = rear_static_length+15/rear_upper_limit_motion_ratio;
ARB_K_tors_rear = 271; % [Nm/rad]
rear_damping_ratio = 0.7;
rear_c_krit = 2*sqrt(rear_spring_stiffness/rear_static_motion_ratio^2*(m_sprung*(1-weight_distribution))/2);
rear_c = rear_damping_ratio*rear_c_krit;
rear_damping_coefficient = rear_c*rear_static_motion_ratio^2;
rear_roll_center = 130;

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

function R = pointsToRotationMatrix(P1, P2)
% POINTS_TO_ROTATION_MATRIX Kiszámolja a 3x3-as forgatási mátrixot két pontból
% Bemenet: P1 és P2 (1x3 vagy 3x1 vektorok, pl. [x, y, z])
% Kimenet: R (3x3 forgatási mátrix / DCM)

% Vektor a két pont között
v = P2 - P1;

% Ellenőrzés: ha a két pont egybeesik, nem lehet irányt meghatározni
if norm(v) == 0
    error('A két pont egybeesik, a forgatási mátrix nem számítható ki!');
end

% 1. Lokális Z-tengely (fő irány) kiszámítása és normálása
z_vec = v / norm(v);

% Biztosítjuk, hogy sorvektor legyen (1x3) a stabil keresztszorzathoz
z_vec = z_vec(:)'; 

% 2. Up-Vector (segédvektor) kiválasztása
% Ellenőrizzük, hogy a z_vec mennyire párhuzamos a globális Z-tengellyel [0, 0, 1]
% Ha a z komponens abszolút értéke majdnem 1, akkor párhuzamos (vagy egybeesik)
tol = 0.99; % Tolerancia (abs(0.99) kb. 8 fokos eltérést enged meg)

if abs(z_vec(3)) > tol
    % Szingularitás elkerülése: ha párhuzamos a Z-vel, a globális Y-t használjuk
    up_vec = [0, 1, 0];
    % disp('Infó: A vektor majdnem párhuzamos a globális Z-vel. Up-vector átállítva Y-ra.');
else
    % Alapértelmezett eset: a globális Z-t használjuk Up-Vectornak
    up_vec = [0, 0, 1];
end

% 3. Lokális X-tengely kiszámítása
% Az X merőleges lesz a segédvektorra és a lokális Z-tengelyre
x_vec = cross(up_vec, z_vec);
x_vec = x_vec / norm(x_vec); % Normálás egységvektorrá

% 4. Lokális Y-tengely kiszámítása
% Az Y merőleges a lokális Z-re és a frissen kiszámolt X-re
y_vec = cross(z_vec, x_vec);
% (Nem kell normálni, mert z_vec és x_vec ortogonális egységvektorok)

% 5. Forgatási mátrix összeállítása
% A tengelyvektorok a mátrix oszlopai lesznek (Direction Cosine Matrix formátum)
R = [x_vec(:), y_vec(:), z_vec(:)];
end