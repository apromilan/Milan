% =========================================================================
% Kerékcsapágy-méretezési Számítási Menet (ISO 281) - MATLAB Script
% FÉKTÁRCSA HATÁSA NÉLKÜL (Szigorúan 3 tizedesjegyre formázott kiírás)
% =========================================================================

clear; clc; close all;
format shortG;
format compact;

fprintf('=========================================================\n');
fprintf(' KERÉKCSAPÁGY-MÉRETEZÉSI SZÁMÍTÁS (Féktárcsa nélkül) \n');
fprintf('=========================================================\n\n');

%% 1. Bemeneti Adatok és Peremfeltételek
Lreq = 10;            % Elvárt élettartam [üzemóra]
a1 = 0.90;            % Megbízhatósági tényező [% / 100] (90%-ra)
s0 = 1;               % Kívánt statikus biztonság [-]
fsh = 1;              % Ütési / csúcstényező [-]
p = 3;                % Terhelési kitevő (3 = golyóscsapágy, 10/3 = görgőscsapágy)

% Terhelési eset adatok
q = [60, 25, 15]' / 100;       % Időarány / súlyozás [% / 100]
n = [1800, 2400, 2400]';       % Fordulatszám [1/min]
FZ = -[5916, 9165, 10909]';     % Függőleges terhelés nagysága [N] (talaj felől felfelé +)
FX = [0, -13000, 0]';          % Hosszirányú erő [N] (előre +, fékezés -)
FY = [0, 0, 14000]';           % Oldalerő [N] (kifelé +)

% Felfüggesztés és geometria (minden méret MILLIMÉTERBEN)
gamma = 0;                    % Kerékdőlési szög [°]
aA = 34;                      % Külső A csapágy távolsága a keréksíktól [mm]
l = 63;                       % A és B csapágy távolsága [mm]
R = 260;                      % Dinamikus gördülési sugár [mm]

% Katalógusadatok (A csapágyra)
C = 56000;                    % Alap dinamikus teherbírás [N]
C0 = 49000;                   % Alap statikus teherbírás [N]
d = 40;                       % Furatátmérő [mm]
D = 80;                       % Külső átmérő [mm]
dm = (d + D) / 2;             % Közepes átmérő [mm]
Cu = 2.08 * 1000;             % Fáradási határterhelés [N]
nlim = 15000;                 % Határfordulatszám [1/min]
e = 0.95;                     % Határérték [-]
X = 0.6;                      % Számítási tényező [-]
Y0 = 0.58;                    % Számítási tényező [-]
Y1 = 0.66;                    % Számítási tényező [-]
Y2 = 1.1;                     % Számítási tényező [-]

%% 2. Számolási Menet (Lépésről Lépésre)

% 1. Lépés: Átlagos fordulatszám kiszámítása
nm = sum(q .* n);
fprintf('1. Lépés: Átlagos fordulatszám: nm = %.3f [1/min]\n\n', nm);

% 2. Lépés: Kerékerők átszámítása a kerékdőlés figyelembevételével
gamma_rad = gamma * pi / 180;
Fa = FY * cos(gamma_rad) - FZ * sin(gamma_rad);    % Axiális erő (kifelé +)
Fu = FY * sin(gamma_rad) + FZ * cos(gamma_rad);    % Radiális erő a keréksíkban
Fr = sqrt(FX.^2 + Fu.^2);                          % Eredő radiális erő

fprintf('2. Lépés: Kerékerők\n');
fprintf('   Axiális erő a tengely mentén: Fa [N] = \n   '); printVec(Fa');
fprintf('   Kerékből jövő eredő radiális erő: Fr [N] = \n   '); printVec(Fr'); fprintf('\n');

% 3. Lépés: Féktárcsa erők
fprintf('3. Lépés: Féktárcsa nélküli üzemmód -> Nincs féktárcsa nyomatéki eltolás.\n\n');

% 4. Lépés: Radiális reakcióerők a kerékagy egyensúlyából (vektorosan, esetenként)
S = -[FX, Fu];                    % Nx2-es mátrix: hosszirányú és keréksíkbeli erők
M = -R * Fa * [0, 1];             % Nx2-es mátrix: billenőnyomaték (Fy*R hatása)

RB = -(M + aA * S) / l;           % B csapágy reakcióvektora
RA = S - RB;                      % A csapágy reakcióvektora

% Euklideszi norma (vektorhossz) kiszámítása sorként (esetenként)
FrA = sqrt(sum(RA.^2, 2));        % Külső A csapágy eredő radiális terhelése [N]
FrB = sqrt(sum(RB.^2, 2));        % Belső B csapágy eredő radiális terhelése [N]

fprintf('4. Lépés: Radiális reakcióerők\n');
fprintf('   Keréksíkról merőleges eredő erő S [N] = \n'); printMat(S);
fprintf('   Billenőnyomaték M [Nmm] = \n'); printMat(M);
fprintf('   Belső B csapágy radiális reakcióvektora RB [N] = \n'); printMat(RB);
fprintf('   Külső A csapágy radiális reakcióvektora RA [N] = \n'); printMat(RA);
fprintf('   A csapágy eredő radiális terhelése FrA [N] = \n   '); printVec(FrA');
fprintf('   B csapágy eredő radiális terhelése FrB [N] = \n   '); printVec(FrB'); fprintf('\n');

% 5. Lépés: Axiális erők eloszlása az A csapágyra
FaA = abs(Fa);                    % A csapágyra ható axiális erő

fprintf('5. Lépés: Axiális erők eloszlása (A csapágy)\n');
fprintf('   A csapágy axiális terhelése: FaA [N] = \n   '); printVec(FaA'); fprintf('\n');

% 6. Lépés: Ekvivalens terhelések kiszámítása (A csapágyra)
ratioA = FaA ./ FrA;
P_A = FrA;
mask = ratioA > e;
P_A(mask) = X * FrA(mask) + Y1 * FaA(mask);

P0_A = max(FrA, 0.5 * FrA + Y0 * FaA);

fprintf('6. Lépés: Ekvivalens terhelések (A csapágy)\n');
fprintf('   Dinamikus ekvivalens terhelés P [N] = \n   '); printVec(P_A');
fprintf('   Statikus ekvivalens terhelés P0 [N] = \n   '); printVec(P0_A'); fprintf('\n');

% 7. Lépés: Súlyozott egyenértékű dinamikus terhelés (ISO 281)
Peq = (sum(q .* n .* (P_A.^p)) / nm)^(1/p);
fprintf('7. Lépés: Egyenértékű dinamikus terhelés: Peq = %.3f [N]\n\n', Peq);

% 8. Lépés: Statikus biztonság ellenőrzése
P0max = fsh * max(P0_A);
s0_tenyleges = C0 / P0max;
statikus_megfelelo = s0_tenyleges >= s0;

fprintf('8. Lépés: Statikus biztonság ellenőrzése\n');
fprintf('   Maximalizált statikus terhelés: P0max = %.3f [N]\n', P0max);
fprintf('   Tényleges statikus biztonság: s0_tényleges = %.3f\n', s0_tenyleges);
fprintf('   Statikus megfelelőség (1=OK, 0=NEM OK): %d\n\n', statikus_megfelelo);

% 9. Lépés: Kenési tényező (ISO 281, dm mm-ben!)
if nm < 1000
    nu1 = 45000 * nm^(-0.83) * dm^(-0.5);
else
    nu1 = 4500 * nm^(-0.5) * dm^(-0.5);
end
nu = 32; 
kappa = nu / nu1;
aISO = 1;

fprintf('9. Lépés: Kenési tényező\n');
fprintf('   Közepes átmérő: dm = %.3f [mm]\n', dm);
fprintf('   Szükséges kinematikai viszkozitás: nu1 = %.3f [mm^2/s]\n', nu1);
fprintf('   Viszkozitási hányados: kappa = %.3f\n', kappa);
fprintf('   Módosító tényező: aISO = %.3f\n\n', aISO);

% 10. Lépés: Élettartam kiszámítása
L10 = (C / Peq)^p;
L10h = (10^6 / (60 * nm)) * L10;
Lnm_h = a1 * aISO * L10h;
elettartam_megfelelo = L10h >= Lreq;

fprintf('10. Lépés: Élettartam kiszámítása\n');
fprintf('   Alap élettartam (L10): %.3f [millió fordulat]\n', L10);
fprintf('   Alap élettartam üzemórában (L10h): %.3f [óra]\n', L10h);
fprintf('   Módosított élettartam (Lnm_h): %.3f [óra]\n', Lnm_h);
fprintf('   Élettartam megfelelőség (1=OK, 0=NEM OK): %d\n\n', elettartam_megfelelo);

fprintf('=========================================================\n');
fprintf(' SZÁMÍTÁS VÉGE \n');
fprintf('=========================================================\n');

%% Formázó segédfüggvények (Mátrixok és Vektorok 3 tizedesjegyre írásához)
function printVec(v)
    for i = 1:length(v)
        fprintf('%12.3f ', v(i));
    end
    fprintf('\n');
end

function printMat(M)
    [rows, cols] = size(M);
    for i = 1:rows
        fprintf('   ');
        for j = 1:cols
            fprintf('%12.3f ', M(i,j));
        end
        fprintf('\n');
    end
end