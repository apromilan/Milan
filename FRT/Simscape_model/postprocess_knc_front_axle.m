function result = postprocess_knc_front_axle(simOut)
%POSTPROCESS_KNC_FRONT_AXLE Extract collision metrics from a simulation.

outputs = simOut.get('yout');
minClearance = outputs.getElement('Min_Clearance').Values.Data;
contactFlag = outputs.getElement('Contact_Flag').Values.Data;
firstContactTime = outputs.getElement('First_Contact_Time').Values.Data;

result = struct( ...
    'minClearance', min(minClearance(:)), ...
    'contactFlag', logical(any(contactFlag(:))), ...
    'firstContactTime', firstContactTime(end));
end
