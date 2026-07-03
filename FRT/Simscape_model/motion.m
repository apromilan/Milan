function motion(LOG)
data = readtable(LOG);

% Data
timestamps = data.Time; 
steering_angle = timeseries(single(data.steering_angle), timestamps);
acceleration_pedal = timeseries(single(data.acceleration_pedal)/100, timestamps);
brake_pedal = timeseries(single(data.brake_pedal), timestamps);
% engine_torque = timeseries(single(data.engine_torque_3), timestamps);
gear = timeseries(single(data.gear), timestamps);
engine_rpm = timeseries(single(data.engine_rpm), timestamps);

% Data back to workspace for the from workspace block
assignin('base', 'steering_angle', steering_angle);
assignin('base', 'acceleration_pedal', acceleration_pedal);
assignin('base', 'brake_pedal', brake_pedal);
% assignin('base', 'engine_torque', engine_torque);
assignin('base', 'gear', gear);
assignin('base', 'engine_rpm', engine_rpm);

end    


% nyomaték + kormányzás (pilóta model) -> nyomaték/gördülési sugar = vonóerő (tartomány, amit ki lehet vezérelni) *
% gázpedál állás-> ezt korlátozza a gumi Fx értéke, ami slip ratio és normálerő függő -> statikus helyzetben lesz fz, tehát fx is a gumin 
% -> első iterációban (rg*w-v)/rg*w, ezzel max kipörgés lesz, de nagyon kicsi fx veszteség a nagyon kicsi fz miatt, de elindul
% -> utána mehet a (rg*w-v)/v képlet -> itt lesz akkor fx mindig a gumi felől, ez addig korlátoz, amíg nem mászik túl a
% vonóerőn -> utána a motor korlátoz (padlógáz de nem megy eset) -> jön a váltás itt azt találtam ki, hogy rajtnál 40%
% gázállás (lineáris nyomaték-fojtóüszelep viszony), majd megnézem mikor jönne a max nyomaték (ez stepenként lenne) és
% ott van 80% gázon, itt a váltás a 2-es nyomatékgörbéjét folytatja 0,8-cal szorozva és a végéig 100%-ra megy fel és onnan
% az eredeti nyomatékgörbe megy tovább.