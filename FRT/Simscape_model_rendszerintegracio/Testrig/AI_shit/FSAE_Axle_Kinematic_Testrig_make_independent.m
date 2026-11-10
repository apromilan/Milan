modelFile = fullfile(fileparts(mfilename('fullpath')), ...
    'FSAE_Axle_Kinematic_Testrig.slx');
modelName = 'FSAE_Axle_Kinematic_Testrig';

try
    load_system(modelFile);
catch exception
    if ~bdIsLoaded(modelName)
        rethrow(exception)
    end
end

set_param(modelName, 'PostLoadFcn', '');
set_param(modelName, 'CloseFcn', '');
save_system(modelName, modelFile);
close_system(modelName, 0);

fprintf('PostLoadFcn and CloseFcn cleared from %s.\n', modelFile);
