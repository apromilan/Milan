%% 
function csapagymeretezo()
% CSAPAGYMERETEZO  Interaktív gördülőcsapágy-méretező (ISO 281 szerinti menet)
%
%   Futtatás:  csapagymeretezo
%
%   FŐMENÜ:  1 = új számítás | 2 = súgó (a program menete) | 0 = kilépés
%   BÁRMELYIK kérdésnél 'q' beírásával megszakítod az aktuális számítást,
%   és visszalépsz a főmenübe (onnan új számítást indíthatsz, vagy kiléphetsz).
%   Enter = a szögletes zárójelben látható alapérték.
%
%   Módok:  1 = radiális csapágy (kombinált Fr + Fa)
%           2 = axiális csapágy (tiszta axiális)
%           3 = kerékcsapágy-elrendezés: 2 radiális csapágy + opcionálisan külön
%               axiális csapágy, a kerékerőkből és az erőkarból számolt
%               reakcióerőkkel (billenőnyomaték figyelembevételével)
%
%   Ahol a gyártói katalógust kell nézni, "[KATALÓGUS]" keretes blokk jelzi.
%   A fájl UTF-8 kódolású. Az eredményeket az első használatnál ellenőrizd
%   egy ismert példán (katalógus-példa / gyártói online számoló).

clc;
fprintf('==========================================================\n');
fprintf('   CSAPÁGYMÉRETEZŐ (ISO 281 alapú)\n');
fprintf('==========================================================\n');
fprintf('Az eredmény tájékoztató jellegű; a végleges választást a gyártó\n');
fprintf('katalógusa / online számolója (SKF Bearing Select, Schaeffler\n');
fprintf('Medias, NSK) alapján ellenőrizd.\n');

while true
    fprintf('\n---------------- FŐMENÜ ----------------\n');
    fprintf('  1) Új számítás indítása\n');
    fprintf('       -> végigvezet a terhelések megadásán, a katalógus-lépéseken és az értékelésen\n');
    fprintf('  2) Súgó: hogyan működik a program, mit jelentenek a választások\n');
    fprintf('  0) Kilépés a programból\n');
    fprintf('       -> újraindítás később: írd be a parancsablakba: csapagymeretezo\n');
    fprintf('  (számítás közben bármelyik kérdésnél: q = megszakítás, vissza ide)\n');
    s = strtrim(input('Választás: ', 's'));
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
            fprintf('\nKilépés. Újraindítás: csapagymeretezo\n');
            return;
        otherwise
            fprintf('  Érvénytelen választás.\n');
    end
end
end

%% ======================= SÚGÓ =======================
function showHelp()
fprintf('\n================ SÚGÓ ================\n');
fprintf('A számítás menete:\n');
fprintf(' 1. Elvárások: élettartam, megbízhatóság, statikus biztonság, ütési tényező.\n');
fprintf(' 2. Üzemmód: radiális / axiális / kerékcsapágy-elrendezés.\n');
fprintf(' 3. Terhelési esetek mátrixa [Fr Fa n idő%%].\n');
fprintf(' 4. Csapágytípus -> a program előzetesen kiírja a szükséges C és C0 értéket.\n');
fprintf(' 5. [KATALÓGUS] jelölt csapágy adatai: C, C0, d, D, Cu, határfordulatszám, f0/e/Y.\n');
fprintf(' 6. A program kiszámolja: ekvivalens terhelés P, alap élettartam L10h,\n');
fprintf('    statikus biztonság s0, minimális terhelés- és fordulatszám-ellenőrzés.\n');
fprintf(' 7. Módosított élettartam (Lnm = a1*aISO*L10): kenőanyag viszkozitás és szennyezettség.\n');
fprintf(' 8. Értékelés: MEGFELEL / NEM FELEL MEG. Ha nem felel meg, másik jelölt csapágy.\n\n');
fprintf('Fogalmak:\n');
fprintf('  C   alap dinamikus teherbírás [N] (élettartamhoz)\n');
fprintf('  C0  alap statikus teherbírás [N] (maradó alakváltozáshoz)\n');
fprintf('  P   ekvivalens dinamikus terhelés = X*Fr + Y*Fa (vagy Fr, ha Fa/Fr <= e)\n');
fprintf('  P0  ekvivalens statikus terhelés\n');
fprintf('  L10h  üzemóra, amit a csapágyak 90%%-a kibír (alap élettartam)\n');
fprintf('  a1  megbízhatósági tényező, aISO kenési/szennyezettségi tényező\n');
fprintf('  Cu  fáradási határterhelés, kappa = tényleges / szükséges viszkozitás\n');
fprintf('  s0  statikus biztonság = C0 / P0\n\n');
fprintf('Kezelés: Enter = alapérték, q = megszakítás (főmenü), 0 a főmenüben = kilépés.\n');
fprintf('======================================\n');
input('Enter a visszatéréshez...', 's');
end

%% ======================= EGY SZÁMÍTÁS =======================
function runCalculation()
G = globalParams();

mode = askChoice('Mit méretezel?', { ...
    'Radiális csapágy (Fr + Fa)', ...
    'Axiális csapágy', ...
    'Kerékcsapágy-elrendezés (2 radiális + opcionális axiális, erőkarral)'}, { ...
    'Egyetlen radiális csapágy, a radiális és axiális erőt Te adod meg. Opcionálisan billenőnyomatékkal.', ...
    'Tiszta axiális csapágy (pl. homlokon lévő axiális golyós/görgős). Csak Fa számít.', ...
    'A kerékerőkből (Fr, Fa) és a geometriából (távolságok, erőkar) a program kiszámolja a reakcióerőket az A és B csapágyon, majd mindegyiket méretezi.'});

res = {};
switch mode
    case 1
        LC = askLoads('Radiális csapágy terhelési esetei');
        M = askNum('Kiegészítő billenőnyomaték a csapágyon M [Nm] (0 = nincs)', 0, ...
            'Ha a kerékerők erőkarral hatnak a csapágyra, erőpár keletkezik. Ide azt a nyomatékot írd, amit EZ a csapágy visel. Ha nincs ilyen: Enter.');
        if M ~= 0
            a = askNum('Hatásos kar a [mm]', [], ...
                'A nyomatékot felvevő erőpár karja. A program minden esetben Fr = Fr + |M|*1000/a értékkel számol.');
            LC(:,1) = LC(:,1) + abs(M)*1000/a;
            fprintf('  -> Fr mindegyik esetben nőtt %.1f N-nal (M/a).\n', abs(M)*1000/a);
            fprintf('  FIGYELEM: egyetlen mélyhornyú golyóscsapágy a billenést rosszul viseli;\n');
            fprintf('  [KATALÓGUS] nézd meg a megengedett elferdülést (szögelfordulást).\n');
        end
        res{end+1} = bearingCheck('Radiális csapágy', 'radial', LC, G);

    case 2
        LC = askLoads('Axiális csapágy terhelési esetei');
        res{end+1} = bearingCheck('Axiális csapágy', 'axial', LC, G);

    case 3
        fprintf('\nKerékterhelések (a kerék síkjában hatnak):\n');
        fprintf('  Fr = radiális erő (pl. sqrt(Fz^2 + Fx^2)), Fa = axiális erő (oldalerő Fy)\n');
        LC = askLoads('Kerékerők terhelési esetei');
        fprintf('\nGeometria:\n');
        aA = askNum('A csapágy (külső, kerékhez közelebbi) távolsága a kerék síkjától aA [mm]', [], ...
            'A kerék síkjától az A csapágy közepéig mért távolság a tengely mentén. Minél nagyobb, annál nagyobb a reakcióerő.');
        l = askNum('A és B csapágy távolsága l [mm]', [], ...
            'Minél nagyobb a csapágytávolság, annál kisebbek a reakcióerők (az erőpár karja nő).');
        R = askNum('Az axiális erő karja a tengelyhez (dinamikus gördülési sugár) R [mm]', [], ...
            'Az oldalerő (Fa) ekkora karral hat a tengelyre, ebből keletkezik a billenőnyomaték: Fa*R.');
        fprintf('\nA program a nyomaték hatását konzervatívan a radiális reakcióhoz ADJA\n');
        fprintf('(abszolút értékek összege), mert az előjel a kanyar irányától függ.\n');
        ax = askChoice('Ki veszi fel az axiális erőt?', { ...
            'A csapágy (külső)', ...
            'B csapágy (belső)', ...
            'Külön axiális csapágy a homlokon (a radiálisok csak radiális erőt kapnak)'}, { ...
            'A kap Fa-t is (kombinált terhelés), B csak radiális erőt. Az A csapágytípusnak bírnia kell az axiális erőt.', ...
            'B kap Fa-t is, A csak radiális erőt.', ...
            'Három ellenőrzés lesz: A (radiális), B (radiális) és a külön axiális csapágy. A radiális csapágyaknál Fa = 0.'});
        Fr = LC(:,1); Fa = LC(:,2);
        FA = Fr*(aA + l)/l + Fa*R/l;
        FB = Fr*aA/l       + Fa*R/l;
        fprintf('\nReakcióerők esetenként [N]:\n  eset |   F_A   |   F_B   |   Fa\n');
        for i = 1:size(LC,1)
            fprintf('  %3d  | %7.1f | %7.1f | %7.1f\n', i, FA(i), FB(i), Fa(i));
        end
        z = zeros(size(Fa));
        switch ax
            case 1, LCA = [FA Fa LC(:,3:4)]; LCB = [FB z LC(:,3:4)];
            case 2, LCA = [FA z LC(:,3:4)];  LCB = [FB Fa LC(:,3:4)];
            case 3, LCA = [FA z LC(:,3:4)];  LCB = [FB z LC(:,3:4)];
        end
        res{end+1} = bearingCheck('A csapágy (radiális)', 'radial', LCA, G);
        res{end+1} = bearingCheck('B csapágy (radiális)', 'radial', LCB, G);
        if ax == 3
            LCX = [z Fa LC(:,3:4)];
            res{end+1} = bearingCheck('Külön axiális csapágy', 'axial', LCX, G);
        end
end

% ---------------- összegzés ----------------
fprintf('\n==========================================================\n');
fprintf('   ÖSSZEGZÉS\n');
fprintf('==========================================================\n');
for i = 1:numel(res)
    r = res{i};
    fprintf('%-28s  %-14s L10h = %.0f h, s0 = %.2f\n', r.name, r.verdict, r.L10h, r.s0);
end
fprintf('\n[KATALÓGUS / BEÉPÍTÉS] Végső ellenőrzőlista (a program ezt már nem tudja):\n');
fprintf('  - beépítési méretek (d, D, B, sarokrádiusz, vállméretek)\n');
fprintf('  - tengely/furat tűrés és illesztés (a gyártó illesztési táblázata)\n');
fprintf('  - üzemi hőmérséklet, hőtágulás, csapágyhézag / előfeszítés\n');
fprintf('  - tömítés, zsír/olaj típusa, utánkenési intervallum\n');
fprintf('  - megengedett elferdülés, rögzítés (szeg, anya, tartógyűrű)\n');
fprintf('  - ha az axiális erő iránya vált, mindkét irányban kell axiális megtámasztás\n');
fprintf('\nA számítás kész. Visszatérsz a főmenübe (ott új számítás vagy kilépés).\n');
end

%% ======================= GLOBÁLIS PARAMÉTEREK =======================
function G = globalParams()
fprintf('\n=== 1. lépés: elvárások ===\n');
fprintf('Ezekhez az értékekhez hasonlítja a program minden csapágyat.\n');
G.Lreq = askNum('Elvárt élettartam [üzemóra]', 1000, ...
    'Hány órát kell kibírnia a csapágynak. Pl. versenyautónál néhány száz óra, személyautónál több ezer.');
G.crit = askChoice('Melyik élettartamra vonatkozik az elvárás?', { ...
    'L10h (alap élettartam, 90% megbízhatóság)', ...
    'Lnm (módosított élettartam: a1*aISO*L10)'}, { ...
    'A megfelelés az alap képleten dől el, kenési hatások nélkül. Ez a szokásos, egyszerűbb eset.', ...
    'A megfelelés a módosított élettartamon dől el: számít a megbízhatóság, a kenés és a szennyezettség.'});
rel = [90 95 96 97 98 99];
a1v = [1 0.64 0.55 0.47 0.37 0.25];     % ISO 281:2007 a1 értékek
G.rel = askNum('Megbízhatóság [%] (90, 95, 96, 97, 98, 99)', 90, ...
    'Mekkora eséllyel bírja ki a csapágy az élettartamot. 90% a katalógus-alap. Nagyobb megbízhatóságnál kisebb az a1, tehát a számított Lnm rövidebb.');
[~, k] = min(abs(rel - G.rel));
G.a1 = a1v(k);
fprintf('  -> a1 = %.2f (%d%% megbízhatóság)\n', G.a1, rel(k));
G.fsh = askNum('Ütési/csúcstényező a statikus ellenőrzéshez (csúcs/normál)', 2, ...
    'A legnagyobb normál terhelést ennyivel szorozza a statikus ellenőrzéshez. Pl. padkára hajtás, ütés: 2..3.');
G.s0 = askNum('Kívánt statikus biztonság s0 (C0/P0)', 2, ...
    'Irányérték: 1.5..2 normál üzem, >=2 kerékcsapágy, nagy ütésnél több. Ha C0/P0 kisebb, a csapágy a statikus ellenőrzésen elbukik.');
end

%% ======================= TERHELÉSEK BEKÉRÉSE =======================
function LC = askLoads(titleTxt)
fprintf('\n=== %s ===\n', titleTxt);
fprintf('Add meg Nx4 mátrixként (soronként egy terhelési eset):\n');
fprintf('    [Fr[N]   Fa[N]   n[1/min]   idő[%%]]\n');
fprintf('  Fr = radiális erő, Fa = axiális erő, n = fordulatszám,\n');
fprintf('  idő%% = az eset súlya (mennyi ideig áll fenn az üzem során).\n');
fprintf('Példa egy esetre:   [1500 300 800 100]\n');
fprintf('Példa több esetre:  [1500 300 800 60; 2500 800 600 30; 3000 1200 300 10]\n');
fprintf('(GG-diagramból származó esetek is mehetnek; a program súlyozott átlagot számol.)\n');
while true
    fprintf('LC = ');
    s = input('', 's');
    checkAbort(s);
    LC = str2num(s); %#ok<ST2NM>
    if isnumeric(LC) && ~isempty(LC) && size(LC,2) == 4 && all(LC(:) >= 0) && sum(LC(:,4)) > 0
        break;
    end
    fprintf('  Hibás bemenet: Nx4, nemnegatív számok kellenek (vagy q = megszakítás).\n');
end
if abs(sum(LC(:,4)) - 100) > 1e-6
    fprintf('  (az idő%% összege %.1f, a program 100%%-ra normalizálja)\n', sum(LC(:,4)));
end
end

%% ======================= CSAPÁGY ELLENŐRZÉS =======================
function R = bearingCheck(name, kind, LC, G)
fprintf('\n=================== %s ===================\n', upper(name));
Fr = LC(:,1); Fa = LC(:,2); n = LC(:,3);
q  = LC(:,4)/sum(LC(:,4));
nm = sum(q.*n);                       % átlagos fordulatszám
if nm <= 0, error('csap:input', 'Az átlagos fordulatszám nulla.'); end

% ----- típus -----
if strcmp(kind,'radial')
    keys  = {'dgbb','acb40','trb','crb','man'};
    names = {'Mélyhornyú golyóscsapágy (pl. 6xxx)', ...
             'Egysoros ferde hatásvonalú golyóscsapágy, 40 fok (pl. 73xx B)', ...
             'Kúpgörgős csapágy (pl. 30xxx, 32xxx)', ...
             'Hengergörgős csapágy (NU/N, csak radiális)', ...
             'Egyéb / kézi megadás (X, Y, e a katalógusból)'};
    expl  = {'Legelterjedtebb. Radiális + kis/közepes axiális erő. Kell hozzá f0 a katalógusból.', ...
             'Radiális + nagyobb axiális erő egy irányban; önmagában nem rögzít, ellencsapágy kell.', ...
             'Nagy radiális + axiális terhelés, párban használva. Kell: e, Y, Y0 a katalógusból.', ...
             'Csak radiális erőt visel (az axiális erőt figyelmen kívül hagyja), nagy radiális teherbírás.', ...
             'Bármilyen más típus: Te adod meg p, e, X, Y, X0, Y0 értékét a katalógus alapján.'};
else
    keys  = {'tb','trt','srt'};
    names = {'Axiális golyóscsapágy (51xxx)', ...
             'Axiális hengergörgős / tűgörgős csapágy (811xx, AXK)', ...
             'Axiális gömbgörgős csapágy (292xx)'};
    expl  = {'Csak axiális erő, radiális erőt nem visel. P = Fa, p = 3.', ...
             'Nagy axiális teherbírás, kis építési magasság. P = Fa, p = 10/3.', ...
             'Axiális + kis radiális erő (Fr <= 0.55*Fa). P = Fa + 1.2*Fr, p = 10/3.'};
end
t = keys{askChoice('Csapágytípus', names, expl)};
p = 3; if any(strcmp(t, {'trb','crb','trt','srt'})), p = 10/3; end
if strcmp(t,'man')
    p = askNum('Élettartam-kitevő p', 3, 'Golyóscsapágy: 3, görgős csapágy: 10/3 (3.333).');
end

if strcmp(kind,'axial') && any(Fr > 0) && ~strcmp(t,'srt')
    fprintf('  FIGYELEM: ez a típus nem visel radiális erőt (Fr>0 az adatokban)!\n');
end

% ----- előzetes becslés -----
[Ppre, P0pre] = prelimLoads(t, Fr, Fa);
Peq_pre   = (sum(q.*n.*Ppre.^p)/nm)^(1/p);
Creq_pre  = Peq_pre*(60*nm*G.Lreq/1e6)^(1/p);
C0req_pre = G.s0*G.fsh*max(P0pre);
fprintf('\n=== 2. lépés: előzetes becslés ===\n');
fprintf('(Az X, Y tényezők csak a kiválasztott csapágy ismeretében pontosak, ezért ez becslés.)\n');
fprintf('  Átlagos fordulatszám:        %.1f 1/min\n', nm);
fprintf('  Becsült ekvivalens terhelés: P ~ %.0f N\n', Peq_pre);
fprintf('  Szükséges alap dinamikus teherbírás:  C  >= %.0f N  (L10h = %.0f h-hoz)\n', Creq_pre, G.Lreq);
fprintf('  Szükséges alap statikus teherbírás:   C0 >= %.0f N  (s0 = %.1f, ütés x%.1f)\n', ...
        C0req_pre, G.s0, G.fsh);
if G.crit == 2
    fprintf('  (Lnm kritériumnál a pontos eredmény a katalógusadatok után, a 6. lépésben dől el.)\n');
end

while true
    % ----- katalógus -----
    katalogus('3. lépés: válassz jelölt csapágyat', { ...
        sprintf('Olyan csapágyat, amelyre C >= %.0f N és C0 >= %.0f N', Creq_pre, C0req_pre), ...
        'a beépítési méretekbe (d, D, B) belefér', ...
        'Olvasd ki: C [N], C0 [N], d [mm], D [mm], Cu (fatigue load limit) [N], határfordulatszám [1/min]', ...
        typeSpecificHint(t)});
    C   = askNum('C  (alap dinamikus teherbírás) [N]', [], ...
        'Katalógus: "Basic dynamic load rating C". Ebből számolja a program az élettartamot.');
    C0  = askNum('C0 (alap statikus teherbírás) [N]', [], ...
        'Katalógus: "Basic static load rating C0". Ebből számolja a program a statikus biztonságot.');
    dd  = askNum('d (furatátmérő) [mm]', [], ...
        'A csapágy belső átmérője. A módosított élettartamhoz kell (dm = (d+D)/2).');
    DD  = askNum('D (külső átmérő) [mm]', [], 'A csapágy külső átmérője.');
    Cu  = askNum('Cu (fáradási határterhelés) [N] (0 = nem ismert)', 0, ...
        'Katalógus: "Fatigue load limit Pu/Cu". Ha 0, a golyóscsapágyaknál nem számolható aISO a programban.');
    nlim = askNum('Határfordulatszám [1/min] (0 = kihagyom)', 0, ...
        'Katalógus: "Limiting speed". Ha az üzemi fordulatszám nagyobb, a csapágy nem alkalmas.');
    par = askTypeParams(t, struct(), C0);

    % ----- ekvivalens terhelés -----
    Pdyn = zeros(size(Fr)); P0i = zeros(size(Fr));
    for i = 1:numel(Fr)
        [Pdyn(i), P0i(i)] = eqLoad(t, par, Fr(i), Fa(i));
    end
    Peq = (sum(q.*n.*Pdyn.^p)/nm)^(1/p);
    L10 = (C/Peq)^p;                         % millió fordulat
    L10h = 1e6/(60*nm)*L10;

    % ----- statika -----
    P0max = G.fsh*max(P0i);
    s0act = C0/P0max;

    % ----- minimális terhelés -----
    minOK = true; minTxt = 'nincs megadva';
    if strcmp(kind,'radial')
        katalogus('4. lépés: minimális radiális terhelés', { ...
            'Katalógus: "Minimum load" képlet / Frm érték az adott csapágyra', ...
            'Ha a terhelés kisebb, a golyók csúszhatnak (kenésfilm-szakadás, kopás)'});
        Frm = askNum('Frm minimális radiális terhelés [N] (0 = kihagyom)', 0, ...
            'Minden terhelési esetben Fr >= Frm legyen (az 1%-nál rövidebb esetek kivételével).');
        if Frm > 0
            minOK = all(Fr >= Frm | q*100 < 1);
            minTxt = sprintf('Frm = %.0f N, min(Fr) = %.0f N', Frm, min(Fr));
        end
    else
        katalogus('4. lépés: minimális axiális terhelés', { ...
            'Katalógus: Fa,min = A*(n/1000)^2 (axiális golyós) vagy megadott minimum'});
        if strcmp(t,'tb')
            A = askNum('A tényező (katalógus) (0 = kihagyom)', 0, ...
                'Fa,min = A*(n/1000)^2. Kis terhelésnél a golyók csúsznak, ezért minimum terhelés kell.');
            if A > 0
                minOK = all(Fa >= A*(n/1000).^2);
                minTxt = sprintf('Fa,min(nmax) = %.0f N, min(Fa) = %.0f N', A*(max(n)/1000)^2, min(Fa));
            end
        else
            Fmin = askNum('Fa,min [N] (katalógus, 0 = kihagyom)', 0, ...
                'A katalógusban megadott minimális axiális terhelés.');
            if Fmin > 0
                minOK = all(Fa >= Fmin);
                minTxt = sprintf('Fa,min = %.0f N, min(Fa) = %.0f N', Fmin, min(Fa));
            end
        end
    end

    % ----- fordulatszám -----
    speedOK = true;
    if nlim > 0, speedOK = (max(n) <= nlim); end

    % ----- módosított élettartam -----
    aISO = 1;
    fprintf('\n=== 5. lépés: módosított élettartam (kenés, szennyezettség) ===\n');
    doMod = askNum('Számoljunk módosított élettartamot Lnm = a1*aISO*L10? (1 = igen, 0 = nem)', 1, ...
        '0 esetén aISO = 1, vagyis Lnm = a1*L10h. 1 esetén kenőanyag-adatokat kér, és aISO-t számol (vagy Te adod meg).');
    if doMod
        dm = (dd + DD)/2;
        if nm < 1000
            nu1 = 45000*nm^(-0.83)*dm^(-0.5);
        else
            nu1 = 4500*nm^(-0.5)*dm^(-0.5);
        end
        fprintf('  Közepes átmérő dm = %.1f mm, nm = %.0f 1/min\n', dm, nm);
        fprintf('  Szükséges viszkozitás (nu1) = %.1f mm^2/s\n', nu1);
        fprintf('  (Ha a tényleges viszkozitás nagyobb, mint nu1, akkor kappa > 1, jó kenés.)\n');
        katalogus('5. lépés: kenőanyag-adat', { ...
            'Kenőolaj / zsír alapolajának kinematikai viszkozitása az ÜZEMI hőmérsékleten [mm^2/s]', ...
            '(zsírnál: a zsír adatlapjából az alapolaj viszkozitása 40 és 100 C-on, abból interpolálj)'});
        nu = askNum('Üzemi viszkozitás nu [mm^2/s]', [], ...
            'Ebből kappa = nu/nu1. Kappa > 1 jó kenést, kappa < 1 vékony kenőfilmet jelent.');
        kappa = nu/nu1;
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
            'Tipikus autós/kerék beépítés: a legtöbb esetben ez a reális.', ...
            'Nagyon szennyezett környezet; az aISO nagyon lecsökken.'});
        ecv = [1 0.7 0.55 0.4 0.2 0.05]; ec = ecv(ecIdx);
        if any(strcmp(t, {'dgbb','acb40'})) && Cu > 0
            aISO = aISOball(kappa, ec, Cu, Peq);
            fprintf('  kappa = %.2f, aISO (golyóscsapágy, ISO 281 képlet) = %.2f\n', kappa, aISO);
        else
            katalogus('5. lépés: aISO kiolvasása', { ...
                'Ehhez a típushoz (vagy Cu nélkül) a program nem számol aISO-t.', ...
                'Használd a gyártó online számolóját (SKF Bearing Select, Medias, NSK) vagy a katalógus aISO diagramját', ...
                sprintf('Bemenet hozzá: kappa = %.2f, ec = %.2f, Cu/P = %.3f', kappa, ec, Cu/Peq)});
            aISO = askNum('aISO értéke (1 = nincs hatás)', 1, ...
                'Az Enter az 1-et veszi. Ez nem feltétlenül konzervatív, ha a kenés rossz (kappa < 1).');
        end
    end
    Lnmh = G.a1*aISO*L10h;

    % ----- értékelés -----
    if G.crit == 1, Lcheck = L10h; else, Lcheck = Lnmh; end
    okLife = Lcheck >= G.Lreq;
    okStat = s0act >= G.s0;
    ok = okLife && okStat && minOK && speedOK;

    fprintf('\n=== 6. lépés: eredmények ===\n');
    fprintf('  Eset |   Fr [N] |   Fa [N] | n [1/min] | idő%% |   P [N] |  P0 [N]\n');
    for i = 1:numel(Fr)
        fprintf('  %3d  | %8.1f | %8.1f | %9.0f | %4.1f | %7.1f | %7.1f\n', ...
            i, Fr(i), Fa(i), n(i), q(i)*100, Pdyn(i), P0i(i));
    end
    fprintf('\n  Ekvivalens dinamikus terhelés Peq = %.1f N\n', Peq);
    fprintf('  C/P = %.2f\n', C/Peq);
    fprintf('  Alap élettartam L10 = %.2f millió ford.,  L10h = %.0f h  (elvárt %.0f h)\n', L10, L10h, G.Lreq);
    if doMod
        fprintf('  Módosított Lnm = a1*aISO*L10 = %.2f*%.2f*L10  ->  Lnm,h = %.0f h\n', G.a1, aISO, Lnmh);
    end
    fprintf('  Statikus: P0,max (ütéssel) = %.0f N, s0 = C0/P0 = %.2f (kívánt %.1f)\n', P0max, s0act, G.s0);
    fprintf('  Minimális terhelés: %s -> %s\n', minTxt, okStr(minOK));
    if nlim > 0
        fprintf('  Fordulatszám: nmax = %.0f, határ = %.0f -> %s\n', max(n), nlim, okStr(speedOK));
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
    fprintf('  [KATALÓGUS] Ellenőrizd még: illesztések, hézag/előfeszítés, tömítés, hőmérséklet.\n');

    R = struct('name', name, 'verdict', verdict, 'L10h', L10h, 's0', s0act, ...
               'Peq', Peq, 'C', C, 'C0', C0, 'aISO', aISO);
    fprintf('\n');
    again = askNum('Próbálsz másik csapágyat ehhez a helyhez? (1 = igen, 0 = nem)', double(~ok), ...
        '1: új katalógusadatokat kér (a terhelések és a típus megmaradnak). 0: kész ezzel a csapágyhellyel.');
    if ~again, break; end
end
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
        if Fr > 0 && Fa/Fr <= e, P = Fr; else, P = 0.56*Fr + Y*Fa; end
        P0 = max(Fr, 0.6*Fr + 0.5*Fa);
    case 'acb40'
        e = 1.14;
        if Fr > 0 && Fa/Fr <= e, P = Fr; else, P = 0.35*Fr + 0.57*Fa; end
        P0 = max(Fr, 0.5*Fr + 0.26*Fa);
    case 'trb'
        if Fr > 0 && Fa/Fr <= par.e, P = Fr; else, P = 0.4*Fr + par.Y*Fa; end
        P0 = max(Fr, 0.5*Fr + par.Y0*Fa);
    case 'crb'
        P = Fr; P0 = Fr;
    case 'man'
        if Fr > 0 && Fa/Fr <= par.e, P = Fr; else, P = par.X*Fr + par.Y*Fa; end
        P0 = max(Fr, par.X0*Fr + par.Y0*Fa);
    case {'tb','trt'}
        P = Fa; P0 = Fa;
    case 'srt'
        P = Fa + 1.2*Fr; P0 = Fa + 2.7*Fr;
end
end

function [P, P0] = prelimLoads(t, Fr, Fa)
P = zeros(size(Fr)); P0 = P;
for i = 1:numel(Fr)
    switch t
        case 'dgbb',  P(i) = max(Fr(i), 0.56*Fr(i) + 1.5*Fa(i)); P0(i) = max(Fr(i), 0.6*Fr(i)+0.5*Fa(i));
        case 'acb40', P(i) = max(Fr(i), 0.35*Fr(i) + 0.57*Fa(i)); P0(i) = max(Fr(i), 0.5*Fr(i)+0.26*Fa(i));
        case 'trb',   P(i) = max(Fr(i), 0.4*Fr(i) + 1.5*Fa(i));   P0(i) = max(Fr(i), 0.5*Fr(i)+0.33*Fa(i));
        case 'crb',   P(i) = Fr(i);                               P0(i) = Fr(i);
        case 'man',   P(i) = Fr(i) + 1.5*Fa(i);                   P0(i) = Fr(i) + 0.5*Fa(i);
        case {'tb','trt'}, P(i) = Fa(i); P0(i) = Fa(i);
        case 'srt',   P(i) = Fa(i) + 1.2*Fr(i); P0(i) = Fa(i) + 2.7*Fr(i);
    end
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
        par.Y  = askNum('Y (katalógus, Fa/Fr > e esetén)', [], 'P = 0.4*Fr + Y*Fa, ha Fa/Fr > e.');
        par.Y0 = askNum('Y0 (katalógus, statikus)', [], 'P0 = 0.5*Fr + Y0*Fa.');
        fprintf('  Megjegyzés: kúpgörgős csapágypárnál a radiális erő axiális összetevőt\n');
        fprintf('  (Fa_ind = 0.5*Fr/Y) hoz létre; ezt a külső axiális erőhöz hozzá kell\n');
        fprintf('  adnod a terhelt csapágy Fa értékében (katalógus, kúpgörgős párok).\n');
    case 'man'
        par.e  = askNum('e (katalógus)', [], 'Határérték: ha Fa/Fr <= e, akkor P = Fr.');
        par.X  = askNum('X (Fa/Fr > e esetén)', [], 'P = X*Fr + Y*Fa, ha Fa/Fr > e.');
        par.Y  = askNum('Y (Fa/Fr > e esetén)', [], 'P = X*Fr + Y*Fa, ha Fa/Fr > e.');
        par.X0 = askNum('X0 (statikus)', [], 'P0 = X0*Fr + Y0*Fa.');
        par.Y0 = askNum('Y0 (statikus)', [], 'P0 = X0*Fr + Y0*Fa.');
end
end

function s = typeSpecificHint(t)
switch t
    case 'dgbb',  s = 'Mélyhornyú golyós: olvasd ki az f0 tényezőt is (az e, Y értékeket a program interpolálja)';
    case 'acb40', s = 'Ferde hatásvonalú, 40 fok: egy csapágy önmagában nem rögzít, ellencsapágy/párosítás kell';
    case 'trb',   s = 'Kúpgörgős: e, Y, Y0 a katalógus méretsor-táblázatából';
    case 'crb',   s = 'Hengergörgős: csak radiális; NJ/NUP kivitel kis axiális erőt visel, az a katalógusban';
    case 'man',   s = 'Kézi mód: e, X, Y, X0, Y0 a katalógus táblázatából';
    case 'tb',    s = 'Axiális golyós: csak axiális, radiális erőt nem visel; tárcsapár (tengely/ház) méretre';
    case 'trt',   s = 'Axiális hengergörgős/tűgörgős: nagy axiális teherbírás, kis építési magasság';
    case 'srt',   s = 'Axiális gömbgörgős: Fr <= 0.55*Fa megengedett; a program P = Fa + 1.2*Fr';
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

%% ======================= SEGÉDFÜGGVÉNYEK =======================
function katalogus(titleTxt, lines)
fprintf('\n');
fprintf('  ######################################################\n');
fprintf('  # [KATALÓGUS] %s\n', titleTxt);
fprintf('  ######################################################\n');
for i = 1:numel(lines)
    fprintf('  #  - %s\n', lines{i});
end
fprintf('  ######################################################\n');
end

function s = okStr(b)
if b, s = 'OK'; else, s = 'NEM OK'; end
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
