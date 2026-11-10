function Bearing_Calc5()
% BEARING_CALC4  Kerékcsapágy-méretező: KÉT RADIÁLIS CSAPÁGY (A, B), külön axiális csapágy NÉLKÜL
%
%   Futtatás:  Bearing_Calc5
%
%   Az axiális (oldal-) erőt a két radiális csapágy viszi el. Három elrendezés:
%     1) Kúpgörgős pár        - az Fa megoszlik A és B között, a radiális erők
%                               indukált axiális erőt hoznak létre (0,5*Fr/Y)
%     2) Ferde hatásvonalú golyós pár (40 fok) - ugyanígy (indukált erő = 1,14*Fr)
%     3) Mélyhornyú golyós pár - az egyik a RÖGZÍTŐ (viszi az Fa-t), a másik
%                               az ÚSZTATÓ (csak radiális terhelés)
%
%   ÚJ (v5): a kerékerők Fz/Fx/Fy-ként adhatók meg; a program figyelembe veszi a
%   kerékdőlést, az Fy*R billenőnyomatékot, a fék tangenciális erejét a féktárcsa
%   helyzetével (hosszirányú erő hatása), és tájékoztatóul a scrub radius/utánfutás
%   miatti kormányzási nyomatékot.
%
%   MENET:
%     1. elvárások (élettartam, s0 ...)
%     2. elrendezés kiválasztása
%     3. kerékerők + geometria -> radiális reakcióerők A-n és B-n
%     4. ELŐZETES TÁBLÁZAT (mekkora C és C0 kell, mit kell a katalógusból kikeresni)
%     5. mindkét csapágy katalógusadatai
%     6. a pár együttes számítása (axiális erőelosztás + élettartam + statika)
%     7. VÉGSŐ TÁBLÁZAT; szükség esetén jelölt csere és újraszámolás
%
%   BÁRMELYIK kérdésnél 'q' = megszakítás (főmenü). Enter = az alapérték.
%   A fájl UTF-8 kódolású. Az eredményeket első használatnál ellenőrizd egy
%   ismert példán (katalógus-példa / gyártói online számoló).

clc;
fprintf('==========================================================\n');
fprintf('   KERÉKCSAPÁGY-MÉRETEZŐ - 2 radiális csapágy (ISO 281)\n');
fprintf('==========================================================\n');
fprintf('Az eredmény tájékoztató jellegű; a végleges választást a gyártó\n');
fprintf('katalógusa / online számolója (SKF Bearing Select, Schaeffler\n');
fprintf('Medias, NSK) alapján ellenőrizd.\n');

while true
    fprintf('\n---------------- FŐMENÜ ----------------\n');
    fprintf('  1) Kerékcsapágy-számítás (A és B radiális csapágy)   [Enter = ez]\n');
    fprintf('  2) Súgó\n');
    fprintf('  0) Kilépés   (újraindítás: Bearing_Calc5)\n');
    fprintf('Választás: ');
    s = strtrim(input('', 's'));
    if isempty(s), s = '1'; end
    switch s
        case '1'
            try
                runCalculation();
            catch ME
                if strcmp(ME.identifier, 'csap:abort')
                    fprintf('\n[Megszakítva] Visszatértél a főmenübe.\n');
                else
                    rethrow(ME);
                end
            end
        case '2'
            showHelp();
        case {'0', 'q', 'Q'}
            fprintf('\nKilépés. Újraindítás: Bearing_Calc5\n');
            return;
        otherwise
            fprintf('  Érvénytelen választás.\n');
    end
end
end

%% ======================= SÚGÓ =======================
function showHelp()
fprintf('\n================ SÚGÓ ================\n');
fprintf('Két radiális csapágy (A = külső/kerékhez közelebbi, B = belső) viszi a kerékerőket.\n');
fprintf('Az axiális erő (oldalerő) útja az elrendezéstől függ:\n\n');
fprintf(' KÚPGÖRGŐS vagy FERDE HATÁSVONALÚ pár (X vagy O elrendezés):\n');
fprintf('   Minden csapágy csak az egyik irányú axiális erőt tudja felvenni. A radiális\n');
fprintf('   erő indukált axiális erőt hoz létre (kúpgörgős: 0,5*Fr/Y, ferde: 1,14*Fr),\n');
fprintf('   amit a másik csapágynak kell ellensúlyoznia. Az Fa előjele dönti el, melyik\n');
fprintf('   csapágy kapja közvetlenül: az egyik irányú Fa az A-t, a másik a B-t terheli.\n');
fprintf('   Szerkezeti szabály (a belső gyűrűs alkatrészre, tengelyre/orsóra ható erő):\n');
fprintf('     O elrendezés (hátul-hátul): kifelé (kerék felé) mutató erőt az A veszi fel,\n');
fprintf('     X elrendezés (szemben-szemben): kifelé mutató erőt a B veszi fel.\n');
fprintf('   Ezt a katalógus ábráján (terhelési hatásvonalak) mindenképp ellenőrizd.\n\n');
fprintf(' MÉLYHORNYÚ GOLYÓS pár:\n');
fprintf('   Az egyik csapágy RÖGZÍTŐ: ez viszi az Fa-t mindkét irányban (P = X*Fr+Y*Fa),\n');
fprintf('   a másik ÚSZTATÓ: csak radiális terhelést kap, axiálisan szabadon mozoghat.\n');
fprintf('   Ha mindkettőt axiálisan beszorítod, az erőmegoszlás határozatlan, ezt a\n');
fprintf('   program nem kezeli.\n\n');
fprintf('Fogalmak:\n');
fprintf('  C   alap dinamikus teherbírás [N] | C0 alap statikus teherbírás [N]\n');
fprintf('  P   ekvivalens dinamikus terhelés = X*Fr + Y*Fa (vagy Fr, ha Fa/Fr <= e)\n');
fprintf('  L10h  üzemóra, amit a csapágyak 90%%-a kibír | a1 megbízhatóság, aISO kenés/szennyezés\n');
fprintf('  s0  statikus biztonság = C0 / P0 | Cu fáradási határterhelés | kappa = nu/nu1\n\n');
fprintf('Kezelés: Enter = alapérték, q = megszakítás (főmenü), 0 a főmenüben = kilépés.\n');
fprintf('======================================\n');
fprintf('Enter a visszatéréshez...');
input('', 's');
end

%% ======================= EGY SZÁMÍTÁS =======================
function runCalculation()
G   = globalParams();
arr = chooseArrangement();

fprintf('\n=== 3. lépés: kerékerők, felfüggesztés- és csapágygeometria ===\n');
fprintf('\n');
fprintf('   kerék síkja       A csapágy           B csapágy\n');
fprintf('   (az erők itt hatnak)  (külső)         (belső)\n');
fprintf('        |<-- aA -->|<-------- l -------->|\n');
fprintf('        |           |                     |\n');
fprintf('   ------+-----------+---------------------+------------  tengely\n');
fprintf('\n');
fprintf('  Koordinátarendszer: x = előre, y = a járműtől KIFELÉ (a kerék felé), z = felfelé.\n');
fprintf('  A kerékerők az érintkezési pontban hatnak A KERÉKRE:\n');
fprintf('    Fz = függőleges erő (terhelés, felfelé = pozitív)\n');
fprintf('    Fx = hosszirányú erő (előre = pozitív, fékezésnél negatív)\n');
fprintf('    Fy = oldalerő (kifelé = pozitív; a kanyar külső kerekén általában NEGATÍV)\n');
fprintf('  A program a kerékdőlés, a fékerő és az Fy*R billenőnyomaték hatását a\n');
fprintf('  kerékagy egyensúlyából számolja (vektoros, előjelhelyes).\n');
LC = askLoads('Kerékerők terhelési esetei');

fprintf('\nCsapágygeometria:\n');
if any(strcmp(arr.t, {'trb', 'acb40'}))
    fprintf('  FIGYELEM: kúpgörgős / ferde hatásvonalú csapágynál az aA és l értékét a\n');
    fprintf('  HATÁSOS KÖZÉPPONTOKTÓL (a terhelési hatásvonalak metszéspontjától) mérd,\n');
    fprintf('  a katalógusban megadott "a" mérték alapján. Csapágycsere után ez változik.\n');
end
aA = askNum('A csapágy távolsága a kerék síkjától aA [mm]', [], ...
    'A kerék (felni/gumi) középsíkjától az A csapágy (hatásos) közepéig, a tengely mentén. Nagyobb aA -> nagyobb reakcióerő.');
l = askNum('A és B csapágy távolsága l [mm]', [], ...
    'Minél nagyobb, annál kisebbek a reakcióerők.');
R = askNum('Dinamikus gördülési sugár R [mm]', [], ...
    'Az érintkezési pont és a kerékközéppont távolsága. Az oldalerő (Fy*R) billenőnyomatékához és a fékerő számításához (F_fék = Fx*R/r_b).');
if l <= 0
    fprintf('  Az l távolságnak pozitívnak kell lennie.\n'); return;
end

fprintf('\nFelfüggesztés / kerékállás:\n');
cam = askNum('Kerékdőlés gamma [fok] (pozitív = a kerék teteje kifelé dől)', 0, ...
    'Tipikusan negatív (pl. -1,5). Az Fz így axiális komponenst is ad: Fa = Fy*cos(g) - Fz*sin(g), a radiális erő pedig Fz*cos(g) + Fy*sin(g).');

fprintf('\nFékezés (a hosszirányú erő a féktárcsán/féknyergen keresztül terheli az agyat):\n');
rb = askNum('Fékerő effektív sugara r_b [mm] (0 = a fékerő hatását nem modellezem)', [], ...
    'A féktárcsa effektív súrlódási sugara. A fék a kerék forgatónyomatékát (Fx*R) tangenciális erővé alakítja a tárcsán, ennek helye a tengely mentén nem a kerék síkja.');
kBr = 1; kDr = 0; th = 0; dr = 0;
if rb > 0
    kBr = askNum('Fx < 0 (fékezés) esetén a mechanikus fék által felvett hányad [0..1]', 1, ...
        '1 = a teljes hosszirányú erőt a fék tartja. Ha motorfék / rekuperáció is van, ennél kisebb.');
    kDr = askNum('Fx > 0 (hajtás) esetén a mechanikus fék által felvett hányad [0..1]', 0, ...
        '0 = hajtáskor a nyomatékot a féltengely viszi, nem a fék (a féltengely tiszta nyomaték, erőt nem ad).');
    th  = askNum('A féknyereg szöge a kerékközépponthoz képest [fok]', 0, ...
        'Oldalnézetben (x előre, z felfelé): előre = 0, felfelé = 90, hátra = 180, lefelé = 270.');
    dr  = askNum('A féktárcsa súrlódó síkja a kerék síkjától BEFELÉ [mm]', 0, ...
        'Pozitív = a jármű belseje felé (a szokásos). A fékerő ezen a karon billenti az agyat. Negatív = a kerék síkján túl kifelé.');
end

fprintf('\nA kerékerők billenőnyomatékának kezelése:\n');
mode = askChoice('Az Fy*R nyomaték előjelkezelése', ...
    {'Vektoros, előjelhelyes (pontos, ha az erők előjelei helyesek)', ...
     'Konzervatív (mindkét előjelre számol, a rosszabbat veszi)'}, ...
    {'Az Fz, Fx, Fy előjeleit a fenti koordinátarendszer szerint kell megadni.', ...
     'Ha nem biztos az előjel (pl. jobb/bal kerék, kanyar iránya), ez a biztonságosabb.'});

fprintf('\nKormányzási geometria (TÁJÉKOZTATÓ, a csapágyterhelést nem befolyásolja):\n');
fprintf('  A kerékcsapágyak a kerékkel együtt mozognak a kormányzási tengely körül, ezért a\n');
fprintf('  scrub radius és az utánfutás a csapágyerőkben nem jelenik meg. A kormányzási\n');
fprintf('  tengely (csuklók, kormányrúd) nyomatékát viszont ezekből lehet becsülni.\n');
rs = askNum('Kormánylegördülési sugár (scrub radius) [mm] (0 = kihagyom)', 0, ...
    'A kormányzási tengely talppontja és az érintkezési pont közötti oldalirányú távolság. Fx*rs a kormányzási tengely körüli nyomaték (kb.).');
tr = askNum('Összes utánfutási kar (mechanikai + pneumatikus) [mm] (0 = kihagyom)', 0, ...
    'Fy*tr a kormányzási tengely körüli nyomaték (kb.). Az utánfutási és kingpin szög hatása itt nem szerepel.');

Fz = LC(:,1); Fx = LC(:,2); Fy = LC(:,3); n = LC(:,4);
q  = LC(:,5)/sum(LC(:,5));
nm = sum(q.*n);
if nm <= 0
    fprintf('  Az átlagos fordulatszám nulla, nem számolható.\n'); return;
end

g  = cam*pi/180;
Fa = Fy*cos(g) - Fz*sin(g);      % tengely menti (axiális) erő, kifelé +
Fu = Fy*sin(g) + Fz*cos(g);      % radiális erő a kerék síkjában (kerékdőléssel döntött "felfelé")
Fr = hypot(Fx, Fu);              % a kerékből jövő radiális erő nagysága
[FA, FB, Fbr] = bearingReactions(Fx, Fu, Fa, aA, l, R, rb, th, dr, kBr, kDr, mode);

fprintf('\nA csapágyakra ható erők alapadatai esetenként [N]:\n');
fprintf('  eset |  Fa (axiális) |  Fr (radiális) |  fékerő a tárcsán\n');
for i = 1:numel(Fr)
    fprintf('  %3d  | %13.1f | %14.1f | %17.1f\n', i, Fa(i), Fr(i), Fbr(i));
end
if rs ~= 0 || tr ~= 0
    fprintf('\nTájékoztató: kormányzási tengely körüli nyomatékok nagyságrendje [Nm]\n');
    fprintf('(csak a kormányzás/csuklók terhelése, a csapágyméretezést NEM érinti):\n');
    fprintf('  eset | |Fx|*scrub | |Fy|*utánfutás\n');
    for i = 1:numel(Fr)
        fprintf('  %3d  | %9.1f | %13.1f\n', i, abs(Fx(i))*rs/1000, abs(Fy(i))*tr/1000);
    end
end
fprintf('\nRadiális reakcióerők esetenként [N]:\n  eset |   F_A   |   F_B   |   Fa (külső)\n');
for i = 1:numel(Fr)
    fprintf('  %3d  | %7.1f | %7.1f | %9.1f\n', i, FA(i), FB(i), Fa(i));
end

% ---- előzetes becslés (kúpgörgősnél Y = 1,5 feltételezéssel) ----
Yest = 1.5;
[FaA, FaB] = axialLoads(arr, Fa, FA, FB, Yest, Yest);
pre = cell(1, 2);
pre{1} = prelim(arr.t, arr.p, FA, FaA, n, q, nm, G);
pre{2} = prelim(arr.t, arr.p, FB, FaB, n, q, nm, G);
printRequirements(arr, pre, G);
fprintf('\nEnter, ha kikerested a jelölteket és mehetünk tovább (q = megszakítás): ');
checkAbort(input('', 's'));

% ---- katalógusadatok mindkét csapágyra ----
names = {'A csapágy', 'B csapágy'};
locs  = {'külső, kerékhez közelebbi', 'belső, kerékhez távolabbi'};
D = cell(1, 2);
for k = 1:2
    D{k} = askCatalog(names{k}, locs{k}, arr, pre{k}, nm);
end

% ---- együttes számítás, szükség esetén csere ----
while true
    Ypair = [Yest Yest];
    if strcmp(arr.t, 'trb')
        Ypair = [D{1}.par.Y, D{2}.par.Y];
    end
    [FaA, FaB] = axialLoads(arr, Fa, FA, FB, Ypair(1), Ypair(2));

    fprintf('\n--- Axiális terhelés elosztása a csapágyak között [N] ---\n');
    fprintf('  eset | Fa külső |  Fa az A-n |  Fa a B-n\n');
    for i = 1:numel(Fr)
        fprintf('  %3d  | %8.1f | %10.1f | %9.1f\n', i, Fa(i), FaA(i), FaB(i));
    end

    res = cell(1, 2);
    [res{1}, D{1}] = evalBearing(names{1}, locs{1}, arr, D{1}, FA, FaA, n, q, nm, G, 1, 2);
    [res{2}, D{2}] = evalBearing(names{2}, locs{2}, arr, D{2}, FB, FaB, n, q, nm, G, 2, 2);
    printSummary(res, arr);

    okA = strcmp(res{1}.verdict, 'MEGFELEL');
    okB = strcmp(res{2}.verdict, 'MEGFELEL');
    if okA && okB, def = 0; elseif ~okA && okB, def = 1; elseif okA && ~okB, def = 2; else, def = 3; end
    ch = askNum('Cseréled a jelölt csapágyat? (0 = nem, 1 = A, 2 = B, 3 = mindkettő)', def, ...
        'Új katalógusadatokat kér; a terhelések és az elrendezés megmaradnak. Kúpgörgős/ferde pároknál az egyik csere a másik terhelését is megváltoztatja.');
    if ~any(ch == [1 2 3]), break; end
    if ch == 1 || ch == 3, D{1} = askCatalog(names{1}, locs{1}, arr, pre{1}, nm); end
    if ch == 2 || ch == 3, D{2} = askCatalog(names{2}, locs{2}, arr, pre{2}, nm); end
end
fprintf('\nA számítás kész. Visszatérsz a főmenübe.\n');
end

%% ======================= ELRENDEZÉS VÁLASZTÁSA =======================
function arr = chooseArrangement()
fprintf('\n=== 2. lépés: csapágyelrendezés (két radiális csapágy, axiális csapágy nélkül) ===\n');
names = {'Kúpgörgős csapágypár (pl. 30xxx, 32xxx)', ...
         'Ferde hatásvonalú golyóscsapágy-pár, 40 fok (pl. 73xx B)', ...
         'Mélyhornyú golyóscsapágy-pár: rögzítő + úsztató (pl. 6xxx)'};
expl  = {'Az Fa megoszlik A és B között; az indukált axiális erőt a program számolja (0,5*Fr/Y). Kell: e, Y, Y0.', ...
         'Mint a kúpgörgős, de indukált erő = 1,14*Fr. Nagy axiális terhelhetőség, golyós a súrlódás kisebb.', ...
         'Az egyik csapágy rögzít és viszi az Fa-t, a másik axiálisan szabad. Kisebb axiális erőre jó. Kell: f0.'};
idx = askChoice('Melyik elrendezést használod?', names, expl);
keys = {'trb', 'acb40', 'dgbb'};
arr.t    = keys{idx};
arr.name = names{idx};
arr.p    = 3; if strcmp(arr.t, 'trb'), arr.p = 10/3; end

if idx < 3
    arr.first = askChoice('A POZITÍV Fa-t melyik csapágy veszi fel KÖZVETLENÜL?', ...
        {'A csapágy (külső, kerékhez közelebbi)', 'B csapágy (belső)'}, ...
        {'Pl. O elrendezésnél a kifelé mutató erőt az A veszi fel (súgó: 2. pont).', ...
         'Pl. X elrendezésnél a kifelé mutató erőt a B veszi fel. A negatív Fa a másik csapágyat terheli.'});
else
    arr.first = askChoice('Melyik csapágy a RÖGZÍTŐ (viszi az Fa-t)?', ...
        {'A csapágy (külső, kerékhez közelebbi)', 'B csapágy (belső)'}, ...
        {'Az Fa abszolút értéke erre a csapágyra hat, irányától függetlenül.', ...
         'A másik (A) csapágy lesz az úsztató.'});
end
end

%% ======================= AXIÁLIS ERŐK ELOSZTÁSA A PÁRBAN =======================
function [FaA, FaB] = axialLoads(arr, Fa, FrA, FrB, YA, YB)
% Visszaadja az A és B csapágyra jutó axiális erőt esetenként (Fa: külső, előjeles).
z = zeros(size(Fa));
if strcmp(arr.t, 'dgbb')
    if arr.first == 1, FaA = abs(Fa); FaB = z; else, FaA = z; FaB = abs(Fa); end
    return;
end
if strcmp(arr.t, 'trb')
    IA = 0.5*FrA/YA;  IB = 0.5*FrB/YB;      % indukált axiális erők
else
    IA = 1.14*FrA;    IB = 1.14*FrB;
end
if arr.first == 1, I1 = IA; I2 = IB; else, I1 = IB; I2 = IA; end
% 1-es csapágy: a pozitív Fa-t közvetlenül viseli. Egyensúly: Fa1 = Fa + Fa2,
% és minden csapágyra Fa_i >= saját indukált erő.
c   = (Fa + I2 >= I1);
Fa2 = I2;
Fa2(~c) = I1(~c) - Fa(~c);
Fa1 = Fa + Fa2;
if arr.first == 1, FaA = Fa1; FaB = Fa2; else, FaA = Fa2; FaB = Fa1; end
end

%% ======================= GLOBÁLIS PARAMÉTEREK =======================
function G = globalParams()
fprintf('\n=== 1. lépés: elvárások ===\n');
fprintf('Ezekhez az értékekhez hasonlítja a program mindkét csapágyat.\n');
G.Lreq = askNum('Elvárt élettartam [üzemóra]', 1000, ...
    'Hány órát kell kibírnia a csapágynak. Pl. megtett út / átlagsebesség.');
G.crit = askChoice('Melyik élettartamra vonatkozik az elvárás?', { ...
    'L10h (alap élettartam, 90% megbízhatóság)', ...
    'Lnm (módosított élettartam: a1*aISO*L10)'}, { ...
    'A megfelelés az alap képleten dől el, kenési hatások nélkül. A szokásos, egyszerűbb eset.', ...
    'A megfelelés a módosított élettartamon dől el: számít a megbízhatóság, a kenés és a szennyezettség.'});
rel = [90 95 96 97 98 99];
a1v = [1 0.64 0.55 0.47 0.37 0.25];     % ISO 281:2007 a1 értékek
G.rel = askNum('Megbízhatóság [%] (90, 95, 96, 97, 98, 99)', 90, ...
    'Mekkora eséllyel bírja ki a csapágy az élettartamot. 90% a katalógus-alap.');
[~, k] = min(abs(rel - G.rel));
G.a1 = a1v(k);
fprintf('  -> a1 = %.2f (%d%% megbízhatóság)\n', G.a1, rel(k));
G.fsh = askNum('Ütési/csúcstényező a statikus ellenőrzéshez (csúcs/normál)', 2, ...
    'A legnagyobb terhelést ennyivel szorozza a statikus ellenőrzéshez. Ha az eseteid már csúcsterhelést tartalmaznak (padka, ütés), írj 1-et.');
G.s0 = askNum('Kívánt statikus biztonság s0 (C0/P0)', 2, ...
    'Irányérték: 1,5..2 normál üzem, >=2 kerékcsapágy. A fenti ütési tényezővel együtt hat.');
end

%% ======================= TERHELÉSEK BEKÉRÉSE =======================
function LC = askLoads(titleTxt)
fprintf('\n=== %s ===\n', titleTxt);
fprintf('Add meg Nx5 mátrixként (soronként egy terhelési eset):\n');
fprintf('    [Fz[N]   Fx[N]   Fy[N]   n[1/min]   idő[%%]]\n');
fprintf('  Fz = függőleges erő (terhelés, felfelé +), Fx = hosszirányú erő (előre +, fékezés -),\n');
fprintf('  Fy = oldalerő (kifelé +, a kanyar külső kerekén általában -), n = fordulatszám,\n');
fprintf('  idő%% = az eset súlya (mennyi ideig áll fenn az üzem során).\n');
fprintf('Példa egy esetre:   [3000 0 -2500 800 100]\n');
fprintf('Példa több esetre:  [2000 0 0 800 60; 3500 -1500 -2800 600 30; 4500 -3000 0 300 10]\n');
fprintf('(n = v/(2*pi*r_din)*60, pl. 60 km/h és r = 0,25 m esetén kb. 637 1/min)\n');
while true
    fprintf('LC = ');
    s = input('', 's');
    checkAbort(s);
    LC = str2num(s); %#ok<ST2NM>
    okFmt = isnumeric(LC) && ~isempty(LC) && size(LC,2) == 5;
    if okFmt
        okFmt = all(LC(:,1) >= 0) && all(LC(:,4) >= 0) && all(LC(:,5) >= 0) && sum(LC(:,5)) > 0;
    end
    if okFmt, break; end
    fprintf('  Hibás bemenet: Nx5 mátrix kell (Fz, n, idő nemnegatív; Fx és Fy lehet negatív), vagy q = megszakítás.\n');
end
if abs(sum(LC(:,5)) - 100) > 1e-6
    fprintf('  (az idő%% összege %.1f, a program 100%%-ra normalizálja)\n', sum(LC(:,5)));
end
end

%% ======================= ELŐZETES BECSLÉS ÉS TÁBLÁZAT =======================
function s = prelim(t, p, Fr, Fa, n, q, nm, G)
[P, P0] = prelimLoads(t, Fr, Fa);
s.Peq   = (sum(q.*n.*P.^p)/nm)^(1/p);
s.Creq  = s.Peq*(60*nm*G.Lreq/1e6)^(1/p);
s.C0req = G.s0*G.fsh*max(P0);
s.FrMax = max(Fr);
s.FaMax = max(Fa);
s.nm    = nm;
end

function [P, P0] = prelimLoads(t, Fr, Fa)
P = zeros(size(Fr)); P0 = P;
for i = 1:numel(Fr)
    switch t
        case 'dgbb',  P(i) = max(Fr(i), 0.56*Fr(i) + 1.5*Fa(i));  P0(i) = max(Fr(i), 0.6*Fr(i) + 0.5*Fa(i));
        case 'acb40', P(i) = max(Fr(i), 0.35*Fr(i) + 0.57*Fa(i)); P0(i) = max(Fr(i), 0.5*Fr(i) + 0.26*Fa(i));
        case 'trb',   P(i) = max(Fr(i), 0.4*Fr(i) + 1.5*Fa(i));   P0(i) = max(Fr(i), 0.5*Fr(i) + 0.75*Fa(i));
    end
end
end

function printRequirements(arr, pre, G)
fprintf('\n');
fprintf('==========================================================================================\n');
fprintf('   ELŐZETES ÖSSZEFOGLALÓ: mit kell a katalógusból kikeresned?\n');
fprintf('==========================================================================================\n');
fprintf('Elrendezés: %s\n', arr.name);
fprintf('Elvárás: L10h%s >= %.0f h, s0 >= %.1f (ütési tényező x%.1f)\n', ...
        ternary(G.crit == 2, ' (Lnm)', ''), G.Lreq, G.s0, G.fsh);
fprintf('(A P, C értékek becslések; kúpgörgősnél Y = 1,5 feltételezéssel.)\n\n');
nm3 = {'A (külső)', 'B (belső)'};
fprintf(' #  %-11s %9s %9s %8s %9s %10s %10s\n', 'Csapágy', 'Fr,max[N]', 'Fa,max[N]', 'n_átl', 'P_bec[N]', 'C >= [N]', 'C0 >= [N]');
fprintf('------------------------------------------------------------------------------------------\n');
for k = 1:2
    s = pre{k};
    fprintf('%2d  %-11s %9.0f %9.0f %8.0f %9.0f %10.0f %10.0f\n', k, nm3{k}, ...
        s.FrMax, s.FaMax, s.nm, s.Peq, s.Creq, s.C0req);
end
fprintf('------------------------------------------------------------------------------------------\n\n');
fprintf('Kikeresendő mindkét csapágyhoz: %s\n\n', neededData(arr.t));
katalogus('Keress most jelölt csapágyat A-hoz és B-hez', { ...
    'Olyat, amelynek C és C0 értéke legalább akkora, mint a táblázat "C >=" és "C0 >=" oszlopában', ...
    'és belefér a beépítési méretekbe (furat d, külső átmérő D, szélesség B)', ...
    'Kúpgörgős/ferde pároknál A és B legyen azonos típusú, és kösd az O/X elrendezéshez', ...
    'Jegyezd fel a fent felsorolt adatokat, a következő lépésben mindkettőt kérem'});
end

function s = neededData(t)
extra = ' (+ Cu és üzemi viszkozitás, ha módosított élettartamot is számolsz)';
switch t
    case 'dgbb',  s = ['C, C0, d, D, f0, Cu, határfordulatszám, Frm (min. radiális terhelés)' extra];
    case 'acb40', s = ['C, C0, d, D, Cu, határfordulatszám, Frm, hatásos középpont (a)' extra];
    case 'trb',   s = ['C, C0, d, D, e, Y, Y0, határfordulatszám, Frm, hatásos középpont (a)' extra];
    otherwise,    s = '-';
end
end

function s = typeSpecificHint(t)
switch t
    case 'dgbb',  s = 'Mélyhornyú golyós: olvasd ki az f0 tényezőt is (az e, Y értékeket a program interpolálja)';
    case 'acb40', s = 'Ferde hatásvonalú, 40 fok: A és B párban, O vagy X elrendezésben; a katalógusban a pár hatásos középpontja (a) is szerepel';
    case 'trb',   s = 'Kúpgörgős: e, Y, Y0 a katalógus méretsor-táblázatából, és a hatásos középpont (a) a geometriához';
    otherwise,    s = '';
end
end

%% ======================= KATALÓGUSADATOK EGY CSAPÁGYRA =======================
function D = askCatalog(name, loc, arr, req, nm)
t = arr.t;
katalogus(sprintf('%s (%s): jelölt csapágy adatai', name, loc), { ...
    sprintf('Olyat, amelyre C >= %.0f N és C0 >= %.0f N (becslés)', req.Creq, req.C0req), ...
    'belefér a beépítési méretekbe (d, D, B)', ...
    sprintf('Kikeresendő: %s', neededData(t)), ...
    typeSpecificHint(t)});
D.C    = askNum('C  (alap dinamikus teherbírás) [N]', [], ...
    'Katalógus: "Basic dynamic load rating C". Ebből számolja a program az élettartamot.');
D.C0   = askNum('C0 (alap statikus teherbírás) [N]', [], ...
    'Katalógus: "Basic static load rating C0". Ebből a statikus biztonságot.');
D.dd   = askNum('d (furatátmérő) [mm]', [], 'A csapágy belső átmérője (a módosított élettartamhoz kell).');
D.DD   = askNum('D (külső átmérő) [mm]', [], 'A csapágy külső átmérője.');
D.Cu   = askNum('Cu (fáradási határterhelés) [N] (0 = nem ismert)', 0, ...
    'Katalógus: "Fatigue load limit Pu/Cu". Ha 0, az aISO-t magadnak kell megadnod a gyártó számolójából.');
D.nlim = askNum('Határfordulatszám [1/min] (0 = kihagyom)', 0, ...
    'Katalógus: "Limiting speed". Ha az üzemi fordulatszám nagyobb, a csapágy nem alkalmas.');
D.par  = askTypeParams(t, struct(), D.C0);
D.Frm  = askNum('Frm minimális radiális terhelés [N] (0 = kihagyom)', 0, ...
    'Katalógus: "Minimum load". Minden terhelési esetben Fr >= Frm legyen (az 1%-nál rövidebb esetek kivételével).');
D.aISOprev = 1;
D.doMod = askNum('Számoljunk módosított élettartamot Lnm = a1*aISO*L10? (1 = igen, 0 = nem)', 1, ...
    '0 esetén aISO = 1, vagyis Lnm = a1*L10h.');
D.nu = 0; D.ec = 1; D.nu1 = 1;
if D.doMod
    dm = (D.dd + D.DD)/2;
    if nm < 1000
        D.nu1 = 45000*nm^(-0.83)*dm^(-0.5);
    else
        D.nu1 = 4500*nm^(-0.5)*dm^(-0.5);
    end
    fprintf('  Közepes átmérő dm = %.1f mm, nm = %.0f 1/min\n', dm, nm);
    fprintf('  Szükséges viszkozitás (nu1) = %.1f mm^2/s\n', D.nu1);
    katalogus('Kenőanyag-adat', { ...
        'Kenőolaj / zsír alapolajának kinematikai viszkozitása az ÜZEMI hőmérsékleten [mm^2/s]', ...
        '(zsírnál: a zsír adatlapjából az alapolaj viszkozitása 40 és 100 C-on, abból interpolálj)'});
    D.nu = askNum('Üzemi viszkozitás nu [mm^2/s]', [], ...
        'Ebből kappa = nu/nu1. Kappa > 1 jó kenést, kappa < 1 vékony kenőfilmet jelent.');
    ecIdx = askChoice('Szennyezettségi tényező ec (ISO 281, dm<100 mm irányértékek)', { ...
        '1.00  extrém tisztaság (laboratórium)', ...
        '0.70  nagyon tiszta (zárt, élettartamra zsírozott, jó tömítés)', ...
        '0.55  normál tisztaság (védőlemezes, finom szűrés)', ...
        '0.40  enyhe szennyezés', ...
        '0.20  tipikus szennyezés (kerék, közepes tömítés)', ...
        '0.05  súlyos szennyezés'}, { ...
        'Csak laborkörülmények között valós.', ...
        'Pl. zárt (2RS) csapágy jó tömítéssel.', ...
        'Pl. védőlemezes csapágy, szűrt kenés.', ...
        'Kisebb szennyeződés, de nem steril.', ...
        'Tipikus autós/kerék beépítés.', ...
        'Nagyon szennyezett környezet.'});
    ecv = [1 0.7 0.55 0.4 0.2 0.05]; D.ec = ecv(ecIdx);
end
end

function par = askTypeParams(t, par, C0)
par.C0 = C0;
switch t
    case 'dgbb'
        par.f0 = askNum('f0 tényező (katalógus)', [], ...
            'A mélyhornyú golyóscsapágy méretsor-táblázatában (kb. 12..15). Ebből számolja a program az e és Y tényezőket: f0*Fa/C0 alapján.');
    case 'trb'
        par.e  = askNum('e (katalógus)', [], 'Határérték: ha Fa/Fr <= e, akkor P = Fr.');
        par.Y  = askNum('Y (katalógus, Fa/Fr > e esetén)', [], 'P = 0.4*Fr + Y*Fa, ha Fa/Fr > e. Az indukált axiális erő is ebből jön (0,5*Fr/Y).');
        par.Y0 = askNum('Y0 (katalógus, statikus)', [], 'P0 = 0.5*Fr + Y0*Fa.');
end
end

%% ======================= EGY CSAPÁGY ELLENŐRZÉSE =======================
function [R, D] = evalBearing(name, loc, arr, D, Fr, Fa, n, q, nm, G, idx, total)
t = arr.t; p = arr.p;
fprintf('\n');
fprintf('##########################################################################\n');
fprintf('# %d/%d. csapágy: %s (%s)\n', idx, total, upper(name), loc);
fprintf('# Rá ható terhelés: Fr,max = %.0f N, Fa,max = %.0f N, átlagos n = %.0f 1/min\n', ...
        max(Fr), max(Fa), nm);
fprintf('##########################################################################\n');

Pdyn = zeros(size(Fr)); P0i = zeros(size(Fr));
for i = 1:numel(Fr)
    [Pdyn(i), P0i(i)] = eqLoad(t, D.par, Fr(i), Fa(i));
end
Peq  = (sum(q.*n.*Pdyn.^p)/nm)^(1/p);
L10  = (D.C/Peq)^p;
L10h = 1e6/(60*nm)*L10;

P0max = G.fsh*max(P0i);
s0act = D.C0/P0max;

minOK = true; minTxt = 'nincs megadva';
if D.Frm > 0
    loaded = q*100 >= 1;
    minOK = all(Fr(loaded) >= D.Frm);
    minTxt = sprintf('Frm = %.0f N, min(Fr) = %.0f N', D.Frm, min(Fr(loaded)));
end
speedOK = true;
if D.nlim > 0, speedOK = (max(n) <= D.nlim); end

if strcmp(t, 'dgbb') && max(Fa) > 0.5*D.C0
    fprintf('  FIGYELEM: Fa,max > 0,5*C0 - mélyhornyú golyós csapágynál túl nagy axiális terhelés (katalógus: max. Fa/C0).\n');
end

aISO = 1;
if D.doMod
    kappa = D.nu/D.nu1;
    if any(strcmp(t, {'dgbb', 'acb40'})) && D.Cu > 0
        aISO = aISOball(kappa, D.ec, D.Cu, Peq);
        fprintf('  kappa = %.2f, aISO (golyóscsapágy, ISO 281 képlet) = %.2f\n', kappa, aISO);
    else
        katalogus('aISO kiolvasása', { ...
            'Ehhez a típushoz (vagy Cu nélkül) a program nem számol aISO-t.', ...
            'Használd a gyártó online számolóját (SKF Bearing Select, Medias, NSK) vagy a katalógus aISO diagramját', ...
            sprintf('Bemenet hozzá: kappa = %.2f, ec = %.2f, Cu/P = %.3f, Peq = %.0f N', kappa, D.ec, D.Cu/Peq, Peq)});
        aISO = askNum('aISO értéke (1 = nincs hatás)', D.aISOprev, ...
            'Az Enter az előző értéket veszi. Nem konzervatív, ha a kenés rossz (kappa < 1).');
        D.aISOprev = aISO;
    end
end
Lnmh = G.a1*aISO*L10h;

if G.crit == 1, Lcheck = L10h; else, Lcheck = Lnmh; end
okLife = Lcheck >= G.Lreq;
okStat = s0act >= G.s0;
ok = okLife && okStat && minOK && speedOK;

fprintf('\n=== Eredmények: %s ===\n', name);
fprintf('  Eset |   Fr [N] |   Fa [N] | n [1/min] | idő%% |   P [N] |  P0 [N]\n');
for i = 1:numel(Fr)
    fprintf('  %3d  | %8.1f | %8.1f | %9.0f | %4.1f | %7.1f | %7.1f\n', ...
        i, Fr(i), Fa(i), n(i), q(i)*100, Pdyn(i), P0i(i));
end
fprintf('\n  Ekvivalens dinamikus terhelés Peq = %.1f N\n', Peq);
fprintf('  C/P = %.2f\n', D.C/Peq);
fprintf('  Alap élettartam L10 = %.2f millió ford.,  L10h = %.0f h  (elvárt %.0f h)\n', L10, L10h, G.Lreq);
if D.doMod
    fprintf('  Módosított Lnm = a1*aISO*L10 = %.2f*%.2f*L10  ->  Lnm,h = %.0f h\n', G.a1, aISO, Lnmh);
end
fprintf('  Statikus: P0,max (ütéssel) = %.0f N, s0 = C0/P0 = %.2f (kívánt %.1f)\n', P0max, s0act, G.s0);
fprintf('  Minimális terhelés: %s -> %s\n', minTxt, okStr(minOK));
if D.nlim > 0
    fprintf('  Fordulatszám: nmax = %.0f, határ = %.0f -> %s\n', max(n), D.nlim, okStr(speedOK));
end
fprintf('\n  Élettartam: %s | Statika: %s | Min. terhelés: %s | Fordulat: %s\n', ...
    okStr(okLife), okStr(okStat), okStr(minOK), okStr(speedOK));
if ok
    fprintf('  >>> MEGFELEL ennél a csapágynál.\n');
    verdict = 'MEGFELEL';
else
    fprintf('  >>> NEM FELEL MEG. Válassz nagyobb C/C0 értékű (vagy más típusú) csapágyat.\n');
    verdict = 'NEM FELEL MEG';
end

R = struct('name', name, 'verdict', verdict, 'L10h', L10h, 'Lnmh', Lnmh, 's0', s0act, ...
           'Peq', Peq, 'C', D.C, 'C0', D.C0, 'dd', D.dd, 'DD', D.DD, 'FaMax', max(Fa));
end

%% ======================= EKVIVALENS TERHELÉSEK =======================
function [P, P0] = eqLoad(t, par, Fr, Fa)
switch t
    case 'dgbb'
        x  = [0.172 0.345 0.689 1.03 1.38 2.07 3.45 5.17 6.89];
        ev = [0.19 0.22 0.26 0.28 0.30 0.34 0.38 0.42 0.44];
        Yv = [2.30 1.99 1.71 1.55 1.45 1.31 1.15 1.04 1.00];
        xi = min(max(par.f0*Fa/par.C0, x(1)), x(end));
        e = interp1(x, ev, xi); Y = interp1(x, Yv, xi);
        if Fr > 0 && Fa/Fr <= e + 1e-9, P = Fr; else, P = 0.56*Fr + Y*Fa; end
        P0 = max(Fr, 0.6*Fr + 0.5*Fa);
    case 'acb40'
        e = 1.14;
        if Fr > 0 && Fa/Fr <= e + 1e-9, P = Fr; else, P = 0.35*Fr + 0.57*Fa; end
        P0 = max(Fr, 0.5*Fr + 0.26*Fa);
    case 'trb'
        if Fr > 0 && Fa/Fr <= par.e + 1e-9, P = Fr; else, P = 0.4*Fr + par.Y*Fa; end
        P0 = max(Fr, 0.5*Fr + par.Y0*Fa);
end
end

%% ======================= aISO (golyóscsapágy, ISO 281) =======================
function a = aISOball(kappa, ec, Cu, P)
% ISO 281:2007 radiális golyóscsapágyakra. A képletet emlékezetből írtam be,
% ezért érdemes egy ismert példán (gyártói számoló) ellenőrizni!
k = min(max(kappa, 0.4), 4);
if k >= 4
    A = 2.5671 - 2.2649/k^0.054381;
elseif k >= 1
    A = 2.5671 - 1.9987/k^0.19087;
else
    A = 2.5671 - 1.9987/k^0.071739;
end
base = 1 - A^0.83*(ec*Cu/P)^(1/3);
if base <= 0
    a = 50;
else
    a = min(0.1*base^(-9.3), 50);
end
end

%% ======================= VÉGSŐ ÖSSZEFOGLALÓ =======================
function printSummary(res, arr)
fprintf('\n');
fprintf('==========================================================================================\n');
fprintf('   VÉGSŐ ÖSSZEFOGLALÓ - %s\n', arr.name);
fprintf('==========================================================================================\n');
fprintf(' #  %-10s %-10s %8s %8s %8s %8s %9s %9s %6s  %s\n', 'Csapágy', 'd x D[mm]', 'C[N]', 'C0[N]', 'Peq[N]', 'Fa,max', 'L10h[h]', 'Lnm,h[h]', 's0', 'Eredmény');
fprintf('------------------------------------------------------------------------------------------\n');
for k = 1:numel(res)
    r = res{k};
    fprintf('%2d  %-10s %4.0fx%-5.0f %8.0f %8.0f %8.0f %8.0f %9.0f %9.0f %6.2f  %s\n', k, r.name, ...
        r.dd, r.DD, r.C, r.C0, r.Peq, r.FaMax, r.L10h, r.Lnmh, r.s0, r.verdict);
end
fprintf('------------------------------------------------------------------------------------------\n');
fprintf('\n[KATALÓGUS / BEÉPÍTÉS] Végső ellenőrzőlista (a program ezt már nem tudja):\n');
fprintf('  - beépítési méretek (d, D, B, sarokrádiusz, vállméretek)\n');
fprintf('  - tengely/furat tűrés és illesztés (a gyártó illesztési táblázata)\n');
fprintf('  - üzemi hőmérséklet, hőtágulás, csapágyhézag / előfeszítés (kúpgörgős, ferde pároknál a beállítás!)\n');
fprintf('  - tömítés, zsír/olaj típusa, utánkenési intervallum\n');
fprintf('  - mélyhornyú párnál: az úsztató csapágy valóban szabadon mozdulhat-e axiálisan\n');
fprintf('  - az Fa tényleges iránya és az O/X elrendezés összhangja (melyik csapágy veszi fel közvetlenül)\n');
fprintf('  - az Fz/Fx/Fy előjelei (x előre, y kifelé, z felfelé) jobb és bal keréken egyaránt, és a féknyereg szöge\n');
end

%% ======================= CSAPÁGY-REAKCIÓERŐK A KERÉKAGY EGYENSÚLYÁBÓL =======================
function [FA, FB, Fbr] = bearingReactions(Fx, Fu, Fa, aA, l, R, rb, th, dr, kBr, kDr, mode)
% A kerékagy egyensúlya a TENGELYRE MERŐLEGES (x, u) síkban (u = a kerék síkjában
% "felfelé", kerékdőléssel döntve). Az agyra ható erők:
%   - a gumi erői az érintkezési pontban (R-rel a középpont alatt): Fx, Fu, és az Fa
%     axiális erő, ami Fa*R billenőnyomatékot ad,
%   - a fékerő a féktárcsán: tangenciális erő a tárcsa síkjában (dr-rel befelé a kerék
%     síkjától), nagysága kfék*Fx*R/rb (a forgatónyomaték egyensúlyából),
%   - az A és B csapágy radiális reakciója (aA, ill. aA+l távolságra a kerék síkjától).
% Erőegyensúly:   RA + RB = -(Fp + Fb)
% Nyomatékegyensúly (tengelyre merőleges komponens), a kerék síkjára felírva:
%   -aA*RA - (aA+l)*RB = -R*Fa*[0 1] + dr*Fb
N   = numel(Fx);
Fp  = [Fx(:), Fu(:)];
Fbr = zeros(N, 1);
Fbv = zeros(N, 2);
if rb > 0
    k   = kBr*(Fx(:) < 0) + kDr*(Fx(:) >= 0);
    Fbr = k.*R.*Fx(:)/rb;                  % előjeles tangenciális fékerő [N]
    t   = [sind(th), -cosd(th)];           % tangenciális irány a féknyereg szögénél
    Fbv = Fbr*t;                           % Nx2
end
S = -Fp - Fbv;
if mode == 1, signs = 1; else, signs = [1 -1]; end
FA = zeros(N, 1); FB = zeros(N, 1);
for sg = signs
    if mode == 1, Fm = Fa(:); else, Fm = sg*abs(Fa(:)); end
    M  = -(R*Fm)*[0 1] + dr*Fbv;           % Nx2
    RB = -(M + aA*S)/l;
    RA = S - RB;
    FA = max(FA, sqrt(sum(RA.^2, 2)));
    FB = max(FB, sqrt(sum(RB.^2, 2)));
end
end

%% ======================= SEGÉDFÜGGVÉNYEK =======================
function katalogus(titleTxt, lines)
fprintf('\n');
fprintf('  ######################################################\n');
fprintf('  # [KATALÓGUS] %s\n', titleTxt);
fprintf('  ######################################################\n');
for i = 1:numel(lines)
    if ~isempty(lines{i})
        fprintf('  #  - %s\n', lines{i});
    end
end
fprintf('  ######################################################\n');
end

function s = okStr(b)
if b, s = 'OK'; else, s = 'NEM OK'; end
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end

function checkAbort(s)
% 'q' (vagy 'kilep') beírására megszakítja a számítást -> főmenü
if any(strcmpi(strtrim(s), {'q', 'kilep', 'kilép'}))
    error('csap:abort', 'Megszakítva');
end
end

function v = askNum(txt, def, expl)
% txt = kérdés, def = alapérték ([] = nincs), expl = magyarázó szöveg
if nargin > 2 && ~isempty(expl)
    fprintf('     -> %s\n', expl);
end
if nargin > 1 && ~isempty(def)
    fprintf('%s [%g] (q = megszakítás): ', txt, def);
else
    fprintf('%s (q = megszakítás): ', txt);
end
while true
    s = input('', 's');
    checkAbort(s);
    if isempty(strtrim(s)) && nargin > 1 && ~isempty(def)
        v = def; return;
    end
    v = str2double(s);
    if ~isnan(v), return; end
    fprintf('  Nem szám, próbáld újra (q = megszakítás): ');
end
end

function k = askChoice(txt, opts, expl)
% opts = lehetőségek, expl = hozzájuk tartozó magyarázatok (ugyanolyan hosszú cell)
fprintf('\n%s\n', txt);
for i = 1:numel(opts)
    fprintf('  %d) %s\n', i, opts{i});
    if nargin > 2 && numel(expl) >= i && ~isempty(expl{i})
        fprintf('       -> %s\n', expl{i});
    end
end
while true
    fprintf('Választás (q = megszakítás): ');
    s = input('', 's');
    checkAbort(s);
    k = str2double(s);
    if ~isnan(k) && k >= 1 && k <= numel(opts) && k == round(k), return; end
    fprintf('  Érvénytelen választás.\n');
end
end
