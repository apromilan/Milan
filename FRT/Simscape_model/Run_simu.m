clc
clear all
close all

% LOG="log1_200Hz_corrected.csv";
% log_reader(LOG); 
% Point_setup;
% LOG = "Acceleration\acceleration.csv";
LOG = "Cornering\cornering.csv";
% LOG = "Braking\braking.csv";
motion(LOG)
Simulation_setup;