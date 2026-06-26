clc
clear all
close all

% LOG="C:\Users\Milán\Desktop\FRT\GitHub\Mechanical-codes\Simscape_model\log1_200Hz_corrected.csv";
% log_reader(LOG); 
% Point_setup;
% LOG = "Acceleration\acceleration.csv";
LOG = "Cornering\cornering.csv";
% LOG = "Braking\braking.csv";
motion(LOG)
Simulation_setup;