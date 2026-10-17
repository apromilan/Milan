%% RODFORCE CALCULATOR - MATLAB valtozat (elol: dupla A-kar, hatul: MULTILINK)
% Eredeti: Peter Pungor, BME Formula Racing Team (Mathematica, V1.2)
% Rudeerok a GG-diagram korbeforgatasaval. A hardpointokat Excelbol olvassa.
%
% Koordinata-rendszer: X elore, Y balra, Z felfele, Z = 0 a talaj. Pontok mm-ben.
% Pozitiv ero: huzott, negativ: nyomott rud.
%
% Rudak sorrendje:
%   DAA (elol):      1-UCAfront 2-UCArear 3-LCAfront 4-LCArear 5-Pushrod 6-Tierod
%                    (pushrod: rocker Excelbol, mint hatul)
%   MULTILINK (hatul): 1-Link1 2-Link2 3-Link3 4-Link4 5-Link5 6-Pushrod
% Multilinknel mind az 5 link ketgombcsuklos rud (egy-egy ismeretlen eroval),
% a pushrod a rocker "Pushrod Rocker" pontjara koti, igy szinten 6 ismeretlen / 6 egyenlet.
%
% FONTOS: a hatso Multi_Points_Rear.xlsx es az Optim_Rocker_Multi_Rear.xlsx
% ugyanabban a koordinata-rendszerben legyen (ahogy a base programban is).

clear; clc; close all;

%% 1) Fajlok / beallitasok
cfg.frontFile   = 'DAA_Points_Front.xlsx';          % ures '' = elso kihagyva
cfg.frontRocker = 'Optim_Rocker_DAA_Front.xlsx';    % <-- IDE IRD A SAJAT ELSO ROCKER EXCEL NEVED (Pushrod Upright / Pushrod Rocker); ures '' = kezi pontok lent
cfg.rearFile    = 'Multi_Points_Rear.xlsx';         % hatso multilink: Link 1..5 Chassis/Upright + Wheel Center
cfg.rearRocker  = 'Optim_Rocker_Multi_Rear.xlsx';   % hatso rocker: Pushrod Upright / Pushrod Rocker
cfg.nAlpha      = 360;       % alpha felbontas
cfg.csvFile     = 'rodforce_results.csv';

%% 2) Auto parameterek
car.g           = 9.81;
car.MaxLat      = 5;
car.MaxLong     = 4;
car.hCOG        = 0.32;
car.TrackF      = 1.6;
car.TrackR      = 1.6;
car.WB          = 3;
car.Mass        = 750;
car.wdF         = 0.45;
car.QuarterMass = 94.5/4;
car.DownF       = 0.5*0.45*1.2*6.4*(180/3.6)^2;
car.DownR       = 0.5*0.55*1.2*6.4*(180/3.6)^2;
% car.muK = car.Mass / (car.Mass*car.g + car.DownF + car.DownR);
car.muTyre = 1.5;


%% 3) Ami NINCS az Excelben -> kezzel megadando [mm]
% ELSO (DAA): a pushrod mindket vegpontja a cfg.frontRocker Excelbol jon
% (Pushrod Rocker = chassis-oldal, Pushrod Upright = upright-oldal).
% Tartalek: ha cfg.frontRocker ures, a regi kezi ertek kell (chassis-oldal), az upright-oldal = Upper Upright.
% Ha az Excel mellett is megadod, a kezi chassis-oldali pont felulirja az Excelt; ures [] = Excel.
manual.front.pushrodCH = [];   % regi kezi ertek: [-18.18 144 553.99]
% Negyed-auto sulypontja; ures [] = a kerekkozeppont (Wheel Center) pontja
manual.front.CoG       = [];

% HATSO (multilink): a pushrod mindket vegpontja az Optim_Rocker_Multi_Rear.xlsx-bol jon
% (Pushrod Rocker = chassis-oldal, Pushrod Upright = upright-oldal).
% Ha kezzel felul akarod irni a chassis-oldali pontot, ird ide [x y z] mm-ben; ures [] = Excel.
manual.rear.pushrodCH  = [];
manual.rear.CoG        = [];

%% 4) Szamolas
alpha = linspace(0, 2*pi, cfg.nAlpha + 1);

corners = struct('name', {}, 'type', {}, 'file', {}, 'rockerFile', {}, 'axle', {}, 'man', {});
if ~isempty(cfg.frontFile)
    corners(end+1) = struct('name', 'FL', 'type', 'DAA', 'file', cfg.frontFile, ...
        'rockerFile', cfg.frontRocker, 'axle', 'F', 'man', manual.front);
end
if ~isempty(cfg.rearFile)
    corners(end+1) = struct('name', 'RL', 'type', 'ML', 'file', cfg.rearFile, ...
        'rockerFile', cfg.rearRocker, 'axle', 'R', 'man', manual.rear);
end
if isempty(corners)
    error('Sem az elso, sem a hatso fajl nincs megadva.');
end

csvData = alpha(:);
csvHead = {'alpha'};

for k = 1:numel(corners)
    c = corners(k);

    if strcmp(c.type, 'ML')
        P = readPointsML(c.file, c.rockerFile, c.man);
        rodNames = {'Link 1','Link 2','Link 3','Link 4','Link 5','Pushrod'};
    else
        P = readPointsDAA(c.file, c.rockerFile, c.man);
        rodNames = {'UCA front','UCA rear','LCA front','LCA rear','Pushrod','Tierod'};
    end
    res = solveCorner(P, car, alpha, c.axle);

    % --- Rudeerok: min/max ---
    fprintf('\n===== %s (%s) =====\n', c.name, c.type);
    fprintf('%-12s %12s %12s\n', 'Rud', 'Min [N]', 'Max [N]');
    for i = 1:6
        fprintf('%-12s %12.2f %12.2f\n', rodNames{i}, min(res.F(i,:)), max(res.F(i,:)));
    end

    % --- Rudeerok abrai ---
    figure('Name', [c.name ' rudeerok'], 'NumberTitle', 'off');
    for i = 1:6
        subplot(2,3,i);
        plot(alpha, res.F(i,:), 'LineWidth', 1.2); grid on;
        xlabel('alpha [rad]'); ylabel('F [N]');
        title([c.name ' ' rodNames{i}]); xlim([0 2*pi]);
    end

    % --- Csapagyero (bearing): csak A-karnal ertelmes ---
    % Multilinknel nincs A-kar csapagy: minden link ketgombcsuklos rud, a csuklo ereje = a rudero.
    if strcmp(c.type, 'DAA')
        UCAb = res.Fvec{1} + res.Fvec{2} + res.Fvec{5};   % UCA front + UCA rear + pushrod
        LCAb = res.Fvec{3} + res.Fvec{4};                 % LCA front + LCA rear
        UCAbV = sqrt(sum(UCAb.^2, 1));
        LCAbV = sqrt(sum(LCAb.^2, 1));

        [mx, iU] = max(UCAbV);
        fprintf('%s UCA bearing: min %.2f N, max %.2f N, vektor a maximumnal [x y z] = [%.1f %.1f %.1f]\n', ...
            c.name, min(UCAbV), mx, UCAb(:,iU));
        [mx, iL] = max(LCAbV);
        fprintf('%s LCA bearing: min %.2f N, max %.2f N, vektor a maximumnal [x y z] = [%.1f %.1f %.1f]\n', ...
            c.name, min(LCAbV), mx, LCAb(:,iL));

        figure('Name', [c.name ' bearing'], 'NumberTitle', 'off');
        subplot(1,2,1); plot(alpha, UCAbV, 'LineWidth', 1.2); grid on;
        xlabel('alpha [rad]'); ylabel('F [N]'); title([c.name ' UCA bearing']); xlim([0 2*pi]);
        subplot(1,2,2); plot(alpha, LCAbV, 'LineWidth', 1.2); grid on;
        xlabel('alpha [rad]'); ylabel('F [N]'); title([c.name ' LCA bearing']); xlim([0 2*pi]);
    end

    % --- CSV adatok ---
    for i = 1:6
        csvData = [csvData, res.Fvec{i}']; %#ok<AGROW>
        csvHead = [csvHead, strcat(strrep([c.name '_' rodNames{i}], ' ', ''), {'_x','_y','_z'})]; %#ok<AGROW>
    end
end

%% 5) Mentes CSV-be (az eredeti SaveForceValues megfeleloje, dialogus nelkul)
T = array2table(csvData, 'VariableNames', csvHead);
writetable(T, cfg.csvFile);
fprintf('\nEredmenyek mentve: %s\n', cfg.csvFile);


%% ====================== SEGEDFUGGVENYEK ======================

function P = readPointsDAA(file, rockerFile, man)
% ELSO dupla A-kar: hardpointok beolvasasa az Excelbol (Name | X | Y | Z oszlopok)
% A pushrod a rocker Excelbol (Pushrod Rocker / Pushrod Upright); ha nincs rocker fajl, a kezi pontok.
    T = readtable(file);
    UCAf   = getPoint(T, 'Upper Fore Chassis');
    UCAr   = getPoint(T, 'Upper Aft Chassis');
    LCAf   = getPoint(T, 'Lower Fore Chassis');
    LCAr   = getPoint(T, 'Lower Aft Chassis');
    TieCH  = getPoint(T, 'Tie Rod Rack');
    UCAUR  = getPoint(T, 'Upper Upright');
    LCAUR  = getPoint(T, 'Lower Upright');
    TieUR  = getPoint(T, 'Tie Rod Upright');
    wc     = getPoint(T, 'Wheel Center');

    if ~isempty(rockerFile)
        if exist(rockerFile, 'file') ~= 2
            error('A fajl nem talalhato: %s', rockerFile);
        end
        TR     = readtable(rockerFile);
        PushUR = getPoint(TR, 'Pushrod Upright');
        PushCH = getPoint(TR, 'Pushrod Rocker');
        if ~isempty(man.pushrodCH), PushCH = man.pushrodCH; end
    else
        if isempty(man.pushrodCH)
            error('Az elso pushrodhoz vagy a cfg.frontRocker Excel, vagy a manual.front.pushrodCH kell.');
        end
        PushCH = man.pushrodCH;
        PushUR = UCAUR;                 % mint az eredetiben: Pushrod1UR = UCA1UR
    end

    % 6 rud: chassis-oldali es upright-oldali vegpontok (6x3)
    P.CH = [UCAf; UCAr; LCAf; LCAr; PushCH; TieCH];
    P.UR = [UCAUR; UCAUR; LCAUR; LCAUR; PushUR; TieUR];
    P.CP = [wc(1) wc(2) 0];             % talajerintesi pont = kerekkozeppont a talajra vetitve
    if isempty(man.CoG), P.CoG = wc; else, P.CoG = man.CoG; end
end

function P = readPointsML(file, rockerFile, man)
% HATSO multilink: Link 1..5 (Chassis/Upright) + pushrod (rocker -> upright)
    if exist(file, 'file') ~= 2
        error('A fajl nem talalhato: %s', file);
    end
    if exist(rockerFile, 'file') ~= 2
        error('A fajl nem talalhato: %s', rockerFile);
    end
    T  = readtable(file);
    TR = readtable(rockerFile);

    CH = zeros(5,3);  UR = zeros(5,3);
    for i = 1:5
        CH(i,:) = getPointAny(T, {sprintf('Link %d Chassis', i), sprintf('Link%d Chassis', i)});
        UR(i,:) = getPointAny(T, {sprintf('Link %d Upright', i), sprintf('Link%d Upright', i)});
    end
    wc = getPointAny(T, {'Wheel Center', 'WheelCenter'});

    pushUR = getPoint(TR, 'Pushrod Upright');
    pushCH = getPoint(TR, 'Pushrod Rocker');
    if ~isempty(man.pushrodCH), pushCH = man.pushrodCH; end

    % 6 rud: Link1..Link5 + Pushrod (6x3)
    P.CH = [CH; pushCH];
    P.UR = [UR; pushUR];
    P.CP = [wc(1) wc(2) 0];
    if isempty(man.CoG), P.CoG = wc; else, P.CoG = man.CoG; end
end

function p = getPoint(T, name)
    idx = find(strcmpi(strtrim(string(T.Name)), name), 1);
    if isempty(idx)
        error('Nem talalhato a "%s" pont az Excelben.', name);
    end
    p = [T.X(idx), T.Y(idx), T.Z(idx)];
end

function p = getPointAny(T, names)
% Tobb lehetseges nev kozul az elso talalt pont
    nm = strtrim(string(T.Name));
    for k = 1:numel(names)
        idx = find(strcmpi(nm, names{k}), 1);
        if ~isempty(idx)
            p = [T.X(idx), T.Y(idx), T.Z(idx)];
            return;
        end
    end
    error('Nem talalhato az Excelben egyik sem: %s', strjoin(string(names), ' | '));
end

function Fz = wheelLoad(car, GGx, GGy, axle)
% Kerekterheles (bal kerek), az eredeti Fz1 / Fz3 kepletek
    if axle == 'F'
        Fz = car.Mass*car.g*car.wdF*0.5 ...
           - car.Mass*GGx*car.hCOG/car.WB*0.5 ...
           - car.Mass*GGy*car.hCOG/car.TrackF*0.5 + car.DownF/2;
    else
        Fz = car.Mass*car.g*(1 - car.wdF)*0.5 ...
           + car.Mass*GGx*car.hCOG/car.WB*0.5 ...
           - car.Mass*GGy*car.hCOG/car.TrackR*0.5 + car.DownR/2;
    end
end

function res = solveCorner(P, car, alpha, axle)
% Egyensuly: erok es nyomatekok osszege = 0 (6 ismeretlen, 6 egyenlet)
% P.CH / P.UR: 6x3 chassis- es upright-oldali vegpontok (a rudak sorrendjeben)
    m = car.QuarterMass;  g = car.g;

    D = P.CH - P.UR;                          % iranyvektorok: upright -> chassis
    D = D ./ sqrt(sum(D.^2, 2));              % normalizalas

    R = P.CH - P.CoG;                         % karok a sulypontbol (a hatasvonal ugyanaz, mint az upright pontbol)
    Mcols = zeros(3,6);
    for i = 1:6
        Mcols(:,i) = cross(R(i,:), D(i,:))';
    end
    A = [D'; Mcols];                          % 6x6 egyutthato-matrix

    if rcond(A) < 1e-9
        warning(['A 6x6 egyutthato-matrix (majdnem) szingularis (rcond = %.2e): ' ...
                 'a rudak nem kotnek le minden szabadsagi fokot, vagy hibas pont van az Excelben.'], rcond(A));
    end

    N = numel(alpha);
    F = zeros(6, N);
    for n = 1:N
        a   = alpha(n);
        GGx = g*car.MaxLong*sin(a);
        GGy = g*car.MaxLat*cos(a);

        Fz  = wheelLoad(car, GGx, GGy, axle);
        % mu = M/(M*g + DownF + DownR);
        % Fcp = [Fz*GGx/g; Fz*GGy/g; Fz];       % talaj-kerek eroi
        % Fcp = [Fz*GGx*mu; Fz*GGy*mu; Fz];
        Fz  = max(wheelLoad(car, GGx, GGy, axle), 0);       % elemelkedő kerék: Fz = 0
        % Fcp = [Fz*GGx*car.muK; Fz*GGy*car.muK; Fz];         % talaj-kerek eroi
        Fcp = [Fz*car.muTyre*sin(a); Fz*car.muTyre*cos(a); Fz];

        bF = [m*GGx; m*GGy; 0] + [0; 0; m*g] - Fcp;
        bM = -cross((P.CP - P.CoG)', Fcp);

        F(:,n) = A \ [bF; bM];
    end

    res.F = F;
    res.D = D;
    res.Fvec = cell(1,6);
    for i = 1:6
        res.Fvec{i} = D(i,:)' * F(i,:);       % 3xN erovektorok
    end
end