function Simulation_Setup_GUI_v2(mode)
% =========================================================================
% SIMULATION SETUP – grafikus felület a Simulation.slx paraméterezéséhez
% =========================================================================
if nargin < 1, mode = 'gui'; end
STATE_FILE = 'Simulation_setup_state.mat';

if strcmpi(mode, 'headless')
    L = load(STATE_FILE, 'S');
    run_export(migrate_state(L.S));
    disp('Simulation_setup: a változók a base workspace-be töltve (headless).');
    return;
end

S = default_state();
defs = param_defs();
srcItems = {'Lineáris (csillapítási arányból)', 'Grafikus / kézi megadás', 'Paraméteres (Mátrixból kiválasztva)', 'Excelből betöltés'};
excTypes = {'Nincs', 'Sine', 'Cosine', 'Square', 'Sawtooth', 'Triangle', 'Step', 'Random (spektrum)'};
DH = struct();                       % damper panel handle-ök
EH = struct();                       % gerjesztés handle-ök
PT = struct('h', {}, 'cat', {});     % paraméter táblák

fig = uifigure('Name', 'Simulation Setup – futómű paraméterező', 'Position', [40 40 1350 800]);
gl0 = uigridlayout(fig, [1 1]); gl0.Padding = [0 0 0 0];
tg = uitabgroup(gl0);

%% ===================== 1. FÜL: FELFÜGGESZTÉSPONTOK =====================
t1 = uitab(tg, 'Title', '1 | Felfüggesztéspontok');
g1 = uigridlayout(t1, [5 2]);
g1.RowHeight = {34, 34, '1x', 34, 130};
g1.ColumnWidth = {'1x', '1x'};

r1 = uigridlayout(g1, [1 3]); r1.Layout.Row = 1; r1.Layout.Column = [1 2]; r1.Padding = [0 0 0 0];
r1.ColumnWidth = {180, '1x', 340};
uibutton(r1, 'Text', 'Excel betöltése...', 'ButtonPushedFcn', @(~,~) onLoadExcel());
lblFile = uilabel(r1, 'Text', '(nincs fájl betöltve)');
uibutton(r1, 'Text', 'Lapok újratöltése (eldobja a módosításokat)', 'ButtonPushedFcn', @(~,~) load_sheets());

r2 = uigridlayout(g1, [1 4]); r2.Layout.Row = 2; r2.Layout.Column = [1 2]; r2.Padding = [0 0 0 0];
r2.ColumnWidth = {90, '1x', 90, '1x'};
uilabel(r2, 'Text', 'Első lap:');
ddF = uidropdown(r2, 'Items', {'-'}, 'ValueChangedFcn', @(~,~) load_sheets());
uilabel(r2, 'Text', 'Hátsó lap:');
ddR = uidropdown(r2, 'Items', {'-'}, 'ValueChangedFcn', @(~,~) load_sheets());

pnlF = uipanel(g1, 'Title', 'Első felfüggesztés pontjai (X, Y, Z [mm]) – duplakattintással szerkeszthető');
pnlF.Layout.Row = 3; pnlF.Layout.Column = 1;
gF = uigridlayout(pnlF, [1 1]);
tblF = uitable(gF, 'ColumnName', {'Pont', 'X', 'Y', 'Z'}, 'ColumnEditable', [false true true true], ...
    'ColumnFormat', {'char', 'numeric', 'numeric', 'numeric'}, 'RowName', {}, ...
    'CellEditCallback', @(~,~) onPointEdit());
pnlR = uipanel(g1, 'Title', 'Hátsó felfüggesztés pontjai (X, Y, Z [mm]) – duplakattintással szerkeszthető');
pnlR.Layout.Row = 3; pnlR.Layout.Column = 2;
gR = uigridlayout(pnlR, [1 1]);
tblR = uitable(gR, 'ColumnName', {'Pont', 'X', 'Y', 'Z'}, 'ColumnEditable', [false true true true], ...
    'ColumnFormat', {'char', 'numeric', 'numeric', 'numeric'}, 'RowName', {}, ...
    'CellEditCallback', @(~,~) onPointEdit());

r4 = uigridlayout(g1, [1 3]); r4.Layout.Row = 4; r4.Layout.Column = [1 2]; r4.Padding = [0 0 0 0];
r4.ColumnWidth = {380, '1x', 280};
uibutton(r4, 'Text', 'Pontok elfogadása + származtatott paraméterek számítása', 'FontWeight', 'bold', ...
    'ButtonPushedFcn', @(~,~) onAccept());
lblStatus = uilabel(r4, 'Text', 'Nincs elfogadva', 'FontColor', [0.8 0 0], 'FontWeight', 'bold');
uibutton(r4, 'Text', 'Elfogadott pontok mentése Excelbe', 'ButtonPushedFcn', @(~,~) onSavePts());

txtSum = uitextarea(g1, 'Editable', 'off');
txtSum.Layout.Row = 5; txtSum.Layout.Column = [1 2];

%% ===================== 2. FÜL: PARAMÉTEREK =====================
t2 = uitab(tg, 'Title', '2 | Paraméterek');
g2 = uigridlayout(t2, [1 1]);
tg2 = uitabgroup(g2);
paramCats = {'Jármű geometria', 'Tömegek', 'Inerciák', 'Hajtás', 'Aerodinamika', 'Futómű setup', 'Méretek (átmérők)', 'Spring-damper számítás'};
for k = 1:numel(paramCats)
    tt = uitab(tg2, 'Title', paramCats{k});
    gg = uigridlayout(tt, [1 1]);
    hT = make_param_table(gg, paramCats{k});
    PT(end+1) = struct('h', hT, 'cat', paramCats{k}); %#ok<AGROW>
end
tt = uitab(tg2, 'Title', 'Gumimodell');
gg = uigridlayout(tt, [3 3]);
gg.RowHeight = {30, 30, '1x'}; gg.ColumnWidth = {100, '1x', 150};
uilabel(gg, 'Text', 'TIR fájl:');
edTir = uieditfield(gg, 'text', 'Value', S.PRM.ui_tir_file, 'ValueChangedFcn', @(~,~) onTir());
uibutton(gg, 'Text', 'Tallózás...', 'ButtonPushedFcn', @(~,~) onTirBrowse());
lblTir = uilabel(gg, 'Text', ''); lblTir.Layout.Row = 2; lblTir.Layout.Column = [1 3];
onTir();

%% ===================== 3. FÜL: RUGÓZÁS =====================
t3 = uitab(tg, 'Title', '3 | Rugózás');
g3 = uigridlayout(t3, [2 2]);
g3.ColumnWidth = {540, '1x'}; g3.RowHeight = {'1x', '1x'};
keys = {'front', 'rear'};
spCats = {'Rugózás elöl', 'Rugózás hátul'};
spNames = {'Első', 'Hátsó'};
for k = 1:2
    pn = uipanel(g3, 'Title', [spNames{k} ' – rugó, ARB, mozgásviszony, rugóhatárok, csillapítás']);
    pn.Layout.Row = k; pn.Layout.Column = 1;
    gi = uigridlayout(pn, [1 1]);
    hT = make_param_table(gi, spCats{k});
    PT(end+1) = struct('h', hT, 'cat', spCats{k}); %#ok<AGROW>
    pd = uipanel(g3, 'Title', [spNames{k} ' csillapítási tényező karakterisztika (c = f(v))']);
    pd.Layout.Row = k; pd.Layout.Column = 2;
    build_damper_panel(pd, keys{k});
end

%% ===================== 4. FÜL: GERJESZTÉS =====================
t4 = uitab(tg, 'Title', '4 | Gerjesztés');
g4 = uigridlayout(t4, [1 2]); g4.ColumnWidth = {420, '1x'};
pc = uipanel(g4, 'Title', 'Gerjesztés paraméterei');
gc = uigridlayout(pc, [15 2]);
gc.RowHeight = repmat({28}, 1, 15); gc.ColumnWidth = {170, '1x'}; gc.Scrollable = 'on';
uilabel(gc, 'Text', 'Gerjesztés típusa');
EH.type = uidropdown(gc, 'Items', excTypes, 'Value', S.exc.type, 'ValueChangedFcn', @(~,~) onExcChange());
add_num('Amplitúdó (modell egysége)', 'amp');
add_num('Frekvencia [Hz]', 'freq');
add_num('Fázis [°]', 'phase');
add_num('Offset', 'offset');
add_num('Kitöltés (Square, 0..1)', 'duty');
add_num('Step időpont [s]', 'step_t');
add_num('Step kezdőérték', 'step_init');
add_num('Step végérték', 'step_final');
add_num('Szimulációs idő [s]', 'tend');
add_num('Mintaidő [s]', 'ts');
uilabel(gc, 'Text', 'Kerék szorzók (FL FR RL RR)');
gg4 = uigridlayout(gc, [1 4]); gg4.Padding = [0 0 0 0];
EH.gains = gobjects(1, 4);
for q = 1:4
    EH.gains(q) = uieditfield(gg4, 'numeric', 'Value', S.exc.gains(q), 'ValueChangedFcn', @(~,~) onExcChange());
end
uilabel(gc, 'Text', 'Kerék fáziseltolás [°]');
gg5 = uigridlayout(gc, [1 4]); gg5.Padding = [0 0 0 0];
EH.phasew = gobjects(1, 4);
for q = 1:4
    EH.phasew(q) = uieditfield(gg5, 'numeric', 'Value', S.exc.phasew(q), 'ValueChangedFcn', @(~,~) onExcChange());
end
add_num('a_x [m/s²]', 'a_x');
add_num('a_y [m/s²]', 'a_y');

pr = uigridlayout(g4, [2 1]); pr.RowHeight = {'1x', 190};
EH.ax = uiaxes(pr);
pr2 = uigridlayout(pr, [1 2]); pr2.ColumnWidth = {'1x', 230}; pr2.Padding = [0 0 0 0];
EH.rtbl = uitable(pr2, 'ColumnName', {'randfreqs [Hz]', 'randamps'}, 'ColumnEditable', [true true], ...
    'Data', [S.exc.randfreqs(:) S.exc.randamps(:)], 'RowName', {}, 'CellEditCallback', @(~,~) onRandEdit());
uibutton(pr2, 'Text', 'randdelay újragenerálása', 'ButtonPushedFcn', @(~,~) onRandDelay());
update_exc_enable(); update_exc_plot();

%% ===================== 5. FÜL: EXPORT =====================
t5 = uitab(tg, 'Title', '5 | Export');
g5 = uigridlayout(t5, [2 1]); g5.RowHeight = {40, '1x'};
r5 = uigridlayout(g5, [1 4]); r5.ColumnWidth = {340, 160, 160, '1x'}; r5.Padding = [0 0 0 0];
uibutton(r5, 'Text', 'Számítás + export a base workspace-be', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~,~) onExport());
uibutton(r5, 'Text', 'Állapot mentése...', 'ButtonPushedFcn', @(~,~) onSaveState());
uibutton(r5, 'Text', 'Állapot betöltése...', 'ButtonPushedFcn', @(~,~) onLoadState());
uilabel(r5, 'Text', 'GUI nélkül: Simulation_setup(''headless'')');
r6 = uigridlayout(g5, [1 2]); r6.Padding = [0 0 0 0];
txtLog = uitextarea(r6, 'Editable', 'off', 'Value', {'Kész.'});
tblSum = uitable(r6, 'ColumnName', {'Változó', 'Érték'}, 'RowName', {}, 'ColumnWidth', {230, 'auto'});

%% ===================== NESTED FÜGGVÉNYEK =====================

    function onLoadExcel()
        [f, p] = uigetfile({'*.xlsx;*.xls;*.xlsm', 'Excel fájlok'}, 'Felfüggesztéspontok Excel');
        if isequal(f, 0), return; end
        S.xlsx_file = fullfile(p, f);
        try
            sh = cellstr(sheetnames(S.xlsx_file));
        catch ME
            uialert(fig, ME.message, 'Hiba'); return;
        end
        ddF.Items = sh; ddR.Items = sh;
        iF = find(contains(sh, 'Front_3'), 1); if isempty(iF), iF = find(contains(sh, 'Front'), 1); end
        iR = find(contains(sh, 'Rear_3'), 1);  if isempty(iR), iR = find(contains(sh, 'Rear'), 1); end
        if isempty(iF), iF = 1; end
        if isempty(iR), iR = 1; end
        ddF.Value = sh{iF}; ddR.Value = sh{iR};
        lblFile.Text = S.xlsx_file;
        load_sheets();
    end

    function load_sheets()
        if isempty(S.xlsx_file), return; end
        try
            TF = readtable(S.xlsx_file, 'Sheet', ddF.Value);
            TR = readtable(S.xlsx_file, 'Sheet', ddR.Value);
        catch ME
            uialert(fig, ME.message, 'Hiba'); return;
        end
        S.front_sheet = ddF.Value; S.rear_sheet = ddR.Value;
        S.front_data = tbl2cell(TF); S.rear_data = tbl2cell(TR);
        S.front_acc = []; S.rear_acc = [];
        populate_points();
        set_status(false);
        txtSum.Value = {'Pontok betöltve – módosítás után nyomd meg az ELFOGADÁS gombot.'};
    end

    function populate_points()
        tblF.Data = S.front_data;
        tblR.Data = S.rear_data;
    end

    function onPointEdit()
        S.front_data = tblF.Data;
        S.rear_data = tblR.Data;
        S.front_acc = []; S.rear_acc = [];
        set_status(false);
    end

    function set_status(ok)
        if ok
            lblStatus.Text = 'ELFOGADVA (a számítás ezekből a pontokból megy)';
            lblStatus.FontColor = [0 0.5 0];
        else
            lblStatus.Text = 'Nincs elfogadva (módosítva / nem számolt)';
            lblStatus.FontColor = [0.8 0 0];
        end
    end

    function onAccept()
        if isempty(S.front_data) || isempty(S.rear_data)
            uialert(fig, 'Előbb tölts be egy Excelt a pontokkal.', 'Nincs adat'); return;
        end
        S.front_data = tblF.Data; S.rear_data = tblR.Data;
        try
            Tf = cell2table(S.front_data, 'VariableNames', {'Point', 'X', 'Y', 'Z'});
            Tr = cell2table(S.rear_data,  'VariableNames', {'Point', 'X', 'Y', 'Z'});
            P = build_full_prm(S);
            V = compute_suspension(S.front_sheet, S.rear_sheet, Tf, Tr, P);
            S.front_acc = Tf; S.rear_acc = Tr;
        catch ME
            S.front_acc = []; S.rear_acc = [];
            set_status(false);
            uialert(fig, ME.message, 'Számítási hiba'); return;
        end
        set_status(true);
        txtSum.Value = geometry_summary(V);
    end

    function onSavePts()
        if isempty(S.front_acc) || isempty(S.rear_acc)
            uialert(fig, 'Nincsenek elfogadott pontok.', 'Nincs mit menteni'); return;
        end
        try
            fn = 'Suspension_points_accepted.xlsx';
            writetable(S.front_acc, fn, 'Sheet', S.front_sheet);
            writetable(S.rear_acc,  fn, 'Sheet', S.rear_sheet);
            uialert(fig, ['Mentve: ' fullfile(pwd, fn)], 'Mentve', 'Icon', 'success');
        catch ME
            uialert(fig, ME.message, 'Hiba');
        end
    end

    function hTbl = make_param_table(parent, cat)
        [data, flds] = param_rows(cat);
        hTbl = uitable(parent, 'Data', data, 'ColumnName', {'Változó', 'Érték', 'Leírás'}, ...
            'ColumnEditable', [false true false], 'ColumnFormat', {'char', 'numeric', 'char'}, ...
            'ColumnWidth', {190, 110, 'auto'}, 'RowName', {}, 'UserData', flds, ...
            'CellEditCallback', @(src, evt) onParamEdit(src, evt));
    end

    function [data, flds] = param_rows(cat)
        idx = find(strcmp(defs(:, 1), cat));
        flds = defs(idx, 2);
        data = cell(numel(idx), 3);
        for qq = 1:numel(idx)
            fld = defs{idx(qq), 2};
            data{qq, 1} = fld;
            data{qq, 2} = S.PRM.(fld);
            dsc = defs{idx(qq), 4};
            if strncmp(fld, 'ui_', 3), dsc = [dsc ' [GUI-bemenet, nem exportálódik]']; end
            if strncmp(fld, 'sd_', 3), dsc = [dsc ' [az SD struct-ba kerül]']; end
            data{qq, 3} = dsc;
        end
    end

    function onParamEdit(src, evt)
        rr = evt.Indices(1);
        fld = src.UserData{rr};
        nv = evt.NewData;
        if ~isnumeric(nv) || ~isscalar(nv) || ~isfinite(nv)
            src.Data{rr, 2} = evt.PreviousData; return;
        end
        S.PRM.(fld) = nv;
        refresh_damper_plot();
    end

    function onTir()
        S.PRM.ui_tir_file = edTir.Value;
        if isfile(S.PRM.ui_tir_file)
            lblTir.Text = 'A fájl megtalálható.'; lblTir.FontColor = [0 0.5 0];
        else
            lblTir.Text = 'A fájl nem található az aktuális mappához képest!'; lblTir.FontColor = [0.8 0 0];
        end
    end

    function onTirBrowse()
        [f, p] = uigetfile({'*.tir', 'TIR gumimodell'}, 'Gumimodell kiválasztása');
        if isequal(f, 0), return; end
        edTir.Value = fullfile(p, f);
        onTir();
    end

    % ---------- 3. fül: lengéscsillapító ----------
    function build_damper_panel(pd, key)
        gd = uigridlayout(pd, [5 1]); 
        gd.RowHeight = {30, 65, 30, '1x', 24};
        
        % 1. Sor: Megadás módja
        dr1 = uigridlayout(gd, [1 2]); dr1.Padding = [0 0 0 0]; dr1.ColumnWidth = {110, '1x'};
        uilabel(dr1, 'Text', 'Megadás módja:');
        DH.(key).src = uidropdown(dr1, 'Items', srcItems, 'Value', srcItems{S.damper.(key).source}, ...
            'ValueChangedFcn', @(~,~) onDamperSource(key));
        
        % 2. Sor: Mátrix Oszlopválasztók (Low/High Speed x Comp/Rebound)
        pnlMatrix = uipanel(gd, 'Title', 'Oszloponkénti kiválasztás (1-6. sorok)');
        gMat = uigridlayout(pnlMatrix, [2 4]);
        gMat.Padding = [2 2 2 2]; gMat.RowHeight = {18, 22}; gMat.ColumnWidth = {'1x', '1x', '1x', '1x'};
        
        uilabel(gMat, 'Text', 'Low Comp', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        uilabel(gMat, 'Text', 'Low Reb', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        uilabel(gMat, 'Text', 'High Comp', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        uilabel(gMat, 'Text', 'High Reb', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        
        opts = {'1 (Zöld)', '2 (Kék)', '3 (Narancs)', '4 (Világoszöld)', '5 (Piros)', '6 (Világoskék)'};
        DH.(key).dd_lc = uidropdown(gMat, 'Items', opts, 'ItemsData', 1:6, 'Value', S.damper.(key).sel_lc, 'ValueChangedFcn', @(~,~) onMatrixChange(key));
        DH.(key).dd_lr = uidropdown(gMat, 'Items', opts, 'ItemsData', 1:6, 'Value', S.damper.(key).sel_lr, 'ValueChangedFcn', @(~,~) onMatrixChange(key));
        DH.(key).dd_hc = uidropdown(gMat, 'Items', opts, 'ItemsData', 1:6, 'Value', S.damper.(key).sel_hc, 'ValueChangedFcn', @(~,~) onMatrixChange(key));
        DH.(key).dd_hr = uidropdown(gMat, 'Items', opts, 'ItemsData', 1:6, 'Value', S.damper.(key).sel_hr, 'ValueChangedFcn', @(~,~) onMatrixChange(key));
        DH.(key).pnlMatrix = pnlMatrix;

        % 3. Sor: Szerkesztés & Excel funkciók
        dr2 = uigridlayout(gd, [1 4]); dr2.Padding = [0 0 0 0]; dr2.ColumnWidth = {'1x', '1x', 100, 130};
        DH.(key).edit = uibutton(dr2, 'Text', 'Szerkesztés (grafikus)...', 'ButtonPushedFcn', @(~,~) onDamperEdit(key));
        DH.(key).file = uidropdown(dr2, 'Items', {'(nincs fájl)'}, 'ItemsData', {''}, 'ValueChangedFcn', @(~,~) onDamperFile(key));
        DH.(key).browse = uibutton(dr2, 'Text', 'Tallózás...', 'ButtonPushedFcn', @(~,~) onDamperBrowse(key));
        DH.(key).save = uibutton(dr2, 'Text', 'Mentés Excelbe', 'ButtonPushedFcn', @(~,~) onDamperSave(key));
        
        DH.(key).ax = uiaxes(gd);
        DH.(key).info = uilabel(gd, 'Text', '');
        
        refresh_damper_files(key);
        update_damper_controls(key);
        refresh_damper_plot();
    end

    function update_damper_controls(key)
        s = S.damper.(key).source;
        DH.(key).edit.Enable = (s == 2);
        DH.(key).pnlMatrix.Enable = (s == 3);
        DH.(key).file.Enable = (s == 4);
        DH.(key).browse.Enable = (s == 4);
        DH.(key).save.Enable = (s > 1);
    end

    function onMatrixChange(key)
        S.damper.(key).sel_lc = DH.(key).dd_lc.Value;
        S.damper.(key).sel_lr = DH.(key).dd_lr.Value;
        S.damper.(key).sel_hc = DH.(key).dd_hc.Value;
        S.damper.(key).sel_hr = DH.(key).dd_hr.Value;
        
        vmax = S.PRM.(['ui_' key '_vmax']);
        [v, c_val] = generate_custom_damper(S.damper.(key).sel_lc, S.damper.(key).sel_lr, ...
                                         S.damper.(key).sel_hc, S.damper.(key).sel_hr, vmax);
        S.damper.(key).v = v;
        S.damper.(key).F = c_val; % Itt a csillapítási tényezőt tároljuk!
        DH.(key).info.Text = sprintf('Csillapítási tényező karakterisztika összeállítva (Low/High speed)');
        refresh_damper_plot();
    end

    function refresh_damper_files(key)
        dd = dir('Damper_Char_*.xlsx');
        names = {dd.name};
        paths = cellfun(@(n) fullfile(pwd, n), names, 'UniformOutput', false);
        ex = S.damper.(key).extra;
        for qq = 1:numel(ex)
            if ~any(strcmp(paths, ex{qq}))
                [~, nm, e] = fileparts(ex{qq});
                names{end+1} = [nm e]; %#ok<AGROW>
                paths{end+1} = ex{qq}; %#ok<AGROW>
            end
        end
        if isempty(names)
            DH.(key).file.Items = {'(nincs fájl)'};
            DH.(key).file.ItemsData = {''};
        else
            DH.(key).file.Items = names;
            DH.(key).file.ItemsData = paths;
            if ~isempty(S.damper.(key).file) && any(strcmp(paths, S.damper.(key).file))
                DH.(key).file.Value = S.damper.(key).file;
            end
        end
    end

    function onDamperSource(key)
        s = find(strcmp(DH.(key).src.Value, srcItems), 1);
        S.damper.(key).source = s;
        update_damper_controls(key);
        if s == 2 && isempty(S.damper.(key).v), seed_damper(key); end
        if s == 3, onMatrixChange(key); return; end
        if s == 4
            refresh_damper_files(key);
            onDamperFile(key);
            return;
        end
        refresh_damper_plot();
    end

    function onDamperFile(key)
        p = DH.(key).file.Value;
        if isempty(p)
            DH.(key).info.Text = 'Nincs Damper_Char_*.xlsx fájl kiválasztva.';
            refresh_damper_plot(); return;
        end
        try
            [v, F] = load_char_excel(p);
        catch ME
            uialert(fig, ME.message, 'Hiba'); return;
        end
        S.damper.(key).v = v; S.damper.(key).F = F; S.damper.(key).file = p;
        DH.(key).info.Text = ['Betöltve Excelből: ' p];
        refresh_damper_plot();
    end

    function onDamperBrowse(key)
        [f, p] = uigetfile({'*.xlsx;*.xls', 'Excel'}, 'Karakterisztika Excel');
        if isequal(f, 0), return; end
        S.damper.(key).extra{end+1} = fullfile(p, f);
        S.damper.(key).file = fullfile(p, f);
        refresh_damper_files(key);
        onDamperFile(key);
    end

    function onDamperSave(key)
        D = S.damper.(key);
        if isempty(D.v), uialert(fig, 'Nincs mentendő karakterisztika.', 'Üres'); return; end
        fname = save_char_excel(['Damper_Char_' upper(key(1)) key(2:end)], D.v, D.F);
        S.damper.(key).file = fullfile(pwd, fname);
        refresh_damper_files(key);
        DH.(key).info.Text = ['Mentve Excelbe: ' fname];
    end

    function onDamperEdit(key)
        if isempty(S.damper.(key).v), seed_damper(key); end
        D = S.damper.(key);
        vmax = S.PRM.(['ui_' key '_vmax']);
        [x, y] = defineCurveGUI(['lengéscsillapító – ' key], -vmax, vmax, ...
            'Damper sebesség [m/s] (+ = összenyomás)', 'Csillapítási tényező c [N*s/m]', D.v, D.F);
        if numel(x) < 2, return; end
        S.damper.(key).v = x(:); S.damper.(key).F = y(:);
        fname = save_char_excel(['Damper_Char_' upper(key(1)) key(2:end)], x, y);
        S.damper.(key).file = fullfile(pwd, fname);
        refresh_damper_files(key);
        DH.(key).info.Text = ['Elmentve Excelbe: ' fname];
        refresh_damper_plot();
    end

    function seed_damper(key)
        c = preview_damping(S.PRM, key);
        vmax = S.PRM.(['ui_' key '_vmax']);
        v = [-vmax; 0; vmax];
        S.damper.(key).v = v; S.damper.(key).F = [c; c; c];
    end

    function refresh_damper_plot()
        % Kirajzolja az Első és Hátsó csillapítók c(v) karakterisztikáit
        for ky = {'front', 'rear'}
            key = ky{1};
            if ~isfield(DH, key) || ~isfield(DH.(key), 'ax'), continue; end
            ax = DH.(key).ax; cla(ax); hold(ax, 'on'); grid(ax, 'on');
            vmax = S.PRM.(['ui_' key '_vmax']);
            D = S.damper.(key);
            
            % Saját tengely karakterisztikája
            if D.source == 1 || isempty(D.v)
                c = preview_damping(S.PRM, key);
                plot(ax, [-vmax vmax], [c c], 'b-', 'LineWidth', 2, 'DisplayName', key);
                title(ax, sprintf('Lineáris: c = %.1f Ns/m', c));
            else
                [xs, ia] = unique(D.v(:)); ys = D.F(:); ys = ys(ia);
                vg = linspace(-vmax, vmax, 21);
                plot(ax, vg, interp1(xs, ys, vg, 'pchip', 'extrap'), 'b-', 'LineWidth', 2, 'DisplayName', 'Aktuális');
                plot(ax, xs, ys, 'ro', 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');
                title(ax, 'Kiválasztott c(v) karakterisztika');
            end
            
            % Halvány összehasonlítás a másik tengellyel
            otherKey = 'rear'; if strcmp(key, 'rear'), otherKey = 'front'; end
            D_other = S.damper.(otherKey);
            if ~isempty(D_other.v) && numel(D_other.v) >= 2
                [xs_o, ia_o] = unique(D_other.v(:)); ys_o = D_other.F(:); ys_o = ys_o(ia_o);
                vg_o = linspace(-vmax, vmax, 21);
                plot(ax, vg_o, interp1(xs_o, ys_o, vg_o, 'pchip', 'extrap'), '--', 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'DisplayName', ['Másik (' otherKey ')']);
            end
            
            legend(ax, 'Location', 'northwest');
            xlabel(ax, 'Sebesség [m/s]'); ylabel(ax, 'Csillapítási tényező c [N*s/m]');
        end
    end

    % ---------- 4. fül: gerjesztés ----------
    function add_num(label, field)
        uilabel(gc, 'Text', label);
        EH.(field) = uieditfield(gc, 'numeric', 'Value', S.exc.(field), 'ValueChangedFcn', @(~,~) onExcChange());
    end

    function onExcChange()
        S.exc.type = EH.type.Value;
        fl = {'amp', 'freq', 'phase', 'offset', 'duty', 'step_t', 'step_init', 'step_final', 'tend', 'ts', 'a_x', 'a_y'};
        for qq = 1:numel(fl)
            S.exc.(fl{qq}) = EH.(fl{qq}).Value;
        end
        S.exc.duty = min(max(S.exc.duty, 0), 1);
        S.exc.ts = max(S.exc.ts, 1e-6);
        S.exc.tend = max(S.exc.tend, S.exc.ts);
        for qq = 1:4
            S.exc.gains(qq) = EH.gains(qq).Value;
            S.exc.phasew(qq) = EH.phasew(qq).Value;
        end
        update_exc_enable(); update_exc_plot();
    end

    function update_exc_enable()
        tp = S.exc.type;
        periodic = any(strcmp(tp, {'Sine', 'Cosine', 'Square', 'Sawtooth', 'Triangle'}));
        isstep = strcmp(tp, 'Step');
        isrand = strcmp(tp, 'Random (spektrum)');
        none = strcmp(tp, 'Nincs');

        toOnOff = @(cond) char(string(get_onoff_cell(cond)));

        EH.amp.Enable = toOnOff(periodic); 
        EH.freq.Enable = toOnOff(periodic); 
        EH.phase.Enable = toOnOff(periodic);
        EH.duty.Enable = toOnOff(strcmp(tp, 'Square'));
        EH.offset.Enable = toOnOff(~none);
        EH.step_t.Enable = toOnOff(isstep); 
        EH.step_init.Enable = toOnOff(isstep); 
        EH.step_final.Enable = toOnOff(isstep);

        if isrand
            EH.rtbl.Enable = 'on';
        else
            EH.rtbl.Enable = 'off';
        end
    end

    function update_exc_plot()
        E = S.exc;
        tsp = max(E.ts, E.tend / 4000);
        t = (0:tsp:E.tend)';
        y = exc_signal(E, t);
        cla(EH.ax); hold(EH.ax, 'on');
        plot(EH.ax, t, y, 'LineWidth', 1.2);
        grid(EH.ax, 'on');
        legend(EH.ax, {'FL', 'FR', 'RL', 'RR'}, 'Location', 'best');
        xlabel(EH.ax, 'Idő [s]'); ylabel(EH.ax, 'Gerjesztés');
        title(EH.ax, ['Előnézet: ' E.type]);
    end

    function onRandEdit()
        d = EH.rtbl.Data;
        S.exc.randfreqs = d(:, 1); S.exc.randamps = d(:, 2);
        update_exc_plot();
    end

    function onRandDelay()
        S.exc.randdelay = rand([38, 1]);
        update_exc_plot();
    end

    function populate_exc()
        E = S.exc;
        EH.type.Value = E.type;
        fl = {'amp', 'freq', 'phase', 'offset', 'duty', 'step_t', 'step_init', 'step_final', 'tend', 'ts', 'a_x', 'a_y'};
        for qq = 1:numel(fl)
            EH.(fl{qq}).Value = E.(fl{qq});
        end
        for qq = 1:4
            EH.gains(qq).Value = E.gains(qq);
            EH.phasew(qq).Value = E.phasew(qq);
        end
        EH.rtbl.Data = [E.randfreqs(:) E.randamps(:)];
        update_exc_enable(); update_exc_plot();
    end

    % ---------- 5. fül ----------
    function log_msg(msg)
        txtLog.Value = [txtLog.Value; {[datestr(now, 'HH:MM:SS') '  ' msg]}];
    end

    function onExport()
        if isempty(S.front_acc) || isempty(S.rear_acc)
            uialert(fig, 'Előbb fogadd el a felfüggesztéspontokat (1. fül)!', 'Nincsenek elfogadott pontok'); return;
        end
        try
            V = run_export(S);
            save_state(STATE_FILE, S);
        catch ME
            log_msg(['HIBA: ' ME.message]);
            uialert(fig, ME.message, 'Export hiba'); return;
        end
        nv = numel(fieldnames(V));
        log_msg(sprintf('%d változó exportálva a base workspace-be. Állapot: %s', nv, STATE_FILE));
        sn = {'m_sprung', 'm_s0_driver', 'front_spring_stiffness', 'rear_spring_stiffness', ...
              'front_static_spring_compression', 'rear_static_spring_compression', ...
              'front_damping_coefficient', 'rear_damping_coefficient', 'Rack_length'};
        data = {};
        for qq = 1:numel(sn)
            if isfield(V, sn{qq}), data(end+1, :) = {sn{qq}, num2str(V.(sn{qq}), '%.4g')}; end %#ok<AGROW>
        end
        tblSum.Data = data;
    end

    function onSaveState()
        [f, p] = uiputfile('*.mat', 'Állapot mentése', 'Simulation_setup_state.mat');
        if isequal(f, 0), return; end
        S.front_data = tblF.Data; S.rear_data = tblR.Data;
        save_state(fullfile(p, f), S);
        log_msg(['Állapot mentve: ' fullfile(p, f)]);
    end

    function onLoadState()
        [f, p] = uigetfile('*.mat', 'Állapot betöltése');
        if isequal(f, 0), return; end
        L2 = load(fullfile(p, f), 'S');
        S = migrate_state(L2.S);
        refresh_all();
        log_msg(['Állapot betöltve: ' fullfile(p, f)]);
    end

    function refresh_all()
        try
            sh = cellstr(sheetnames(S.xlsx_file));
        catch
            sh = {S.front_sheet, S.rear_sheet};
        end
        ddF.Items = sh; ddR.Items = sh;
        if any(strcmp(sh, S.front_sheet)), ddF.Value = S.front_sheet; end
        if any(strcmp(sh, S.rear_sheet)),  ddR.Value = S.rear_sheet;  end
        if isempty(S.xlsx_file), lblFile.Text = '(nincs fájl betöltve)'; else, lblFile.Text = S.xlsx_file; end
        populate_points();
        set_status(~isempty(S.front_acc) && ~isempty(S.rear_acc));
        for kk = 1:numel(PT)
            [dd2, ~] = param_rows(PT(kk).cat);
            PT(kk).h.Data = dd2;
        end
        edTir.Value = S.PRM.ui_tir_file; onTir();
        for ky = {'front', 'rear'}
            key = ky{1};
            DH.(key).src.Value = srcItems{S.damper.(key).source};
            refresh_damper_files(key); update_damper_controls(key);
        end
        refresh_damper_plot();
        populate_exc();
    end

end   % === Simulation_setup ===


%% =========================================================================
%  LOKÁLIS SEGÉDFÜGGVÉNYEK
%  =========================================================================

function [v_vec, c_vec] = generate_custom_damper(idx_lc, idx_lr, idx_hc, idx_hr, vmax)
% Összeállítja a c(v) csillapítási tényező karakterisztikát [N*s/m]
% A Mátrix sorai a beállításokat hordozzák (1-6), míg az oszlopok:
% 1: Low Comp | 2: Low Reb | 3: High Comp | 4: High Reb (Mindegyik N*s/m egységben)
    damper_matrix = [
        6188.9, 5108.1, 2253.6, 2040.3; % 1. Zöld
        3500.0, 3000.0, 1929.4, 1402.4; % 2. Kék
        2500.0, 2100.0, 1659.3, 1457.8; % 3. Narancs
        1800.0, 1500.0, 1029.9, 1212.2; % 4. Világoszöld
        1200.0, 1000.0,  621.4,  569.6; % 5. Piros
         944.1,  601.9,  445.1,  386.4  % 6. Világoskék
    ];

    c_lc = damper_matrix(idx_lc, 1);
    c_lr = damper_matrix(idx_lr, 2);
    c_hc = damper_matrix(idx_hc, 3);
    c_hr = damper_matrix(idx_hr, 4);

    low_speed_range = 0.05;  % 50 mm/s a váltási pont (low-speed tartomány)
    high_speed_range = vmax; % Max sebesség

    % A sebesség töréspontjai
    v_vec = [-high_speed_range; -low_speed_range; 0; low_speed_range; high_speed_range];
    c_vec = zeros(size(v_vec));

    % Csillapítási tényező hozzárendelése a sebességtartományokhoz
    c_vec(1) = c_hr; % High Speed Rebound (v < -0.05 m/s)
    c_vec(2) = c_lr; % Low Speed Rebound  (-0.05 m/s <= v < 0)
    c_vec(3) = (c_lc + c_lr) / 2; % 0 sebességnél folytonos átmenet
    c_vec(4) = c_lc; % Low Speed Compression (0 < v <= 0.05 m/s)
    c_vec(5) = c_hc; % High Speed Compression (v > 0.05 m/s)
end

function save_state(file, S) %#ok<INUSD>
    save(file, 'S');
end

function V = run_export(S)
    P = build_full_prm(S);
    V = compute_suspension(S.front_sheet, S.rear_sheet, S.front_acc, S.rear_acc, P);
    fn = fieldnames(V);
    for ii = 1:numel(fn)
        assignin('base', fn{ii}, V.(fn{ii}));
    end
    export_sd_buses(V);
end

function S = migrate_state(S)
    d = param_defs();
    for q = 1:size(d, 1)
        if ~isfield(S.PRM, d{q, 2}), S.PRM.(d{q, 2}) = d{q, 3}; end
    end
end

function export_sd_buses(V)
    if ~isfield(V, 'SD'), return; end
    try
        info = Simulink.Bus.createObject(V.SD);
        assignin('base', 'SD_Bus', evalin('base', info.busName));
        evalin('base', ['clear ' info.busName]);

        o = SpringDamper_Dyn(V.SD.MR_static, zeros(4, 1), V.SD);
        clear SpringDamper_Dyn
        info2 = Simulink.Bus.createObject(o);
        assignin('base', 'SD_Out_Bus', evalin('base', info2.busName));
        evalin('base', ['clear ' info2.busName]);

        oq = SpringDamper_DynQ(V.SD.MR_static(1), 0, V.SD, 1);
        clear SpringDamper_DynQ
        info3 = Simulink.Bus.createObject(oq);
        assignin('base', 'SD_OutQ_Bus', evalin('base', info3.busName));
        evalin('base', ['clear ' info3.busName]);
    catch ME
        warning('Simulation_setup:bus', ['Bus létrehozása nem sikerült: ' ME.message]);
    end
end

function C = tbl2cell(T)
    C = [cellstr(string(T.Point)), num2cell(T.X), num2cell(T.Y), num2cell(T.Z)];
end

function S = default_state()
    S.xlsx_file = '';
    S.front_sheet = 'Front_3';
    S.rear_sheet = 'Rear_3';
    S.front_data = {}; S.rear_data = {};
    S.front_acc = [];  S.rear_acc = [];
    d = param_defs();
    for q = 1:size(d, 1)
        S.PRM.(d{q, 2}) = d{q, 3};
    end
    S.PRM.ui_tir_file = 'Tyre Models\Hoosier_43075_16x7_5_10_LCO_7inch.tir';
    
    % Damper alapértelmezések: 3. opció (Paraméteres), mindegyikhez 1-es index
    S.damper.front = struct('source', 3, 'v', [], 'F', [], 'file', '', 'extra', {{}}, 'sel_lc', 1, 'sel_lr', 1, 'sel_hc', 1, 'sel_hr', 1);
    S.damper.rear  = struct('source', 3, 'v', [], 'F', [], 'file', '', 'extra', {{}}, 'sel_lc', 1, 'sel_lr', 1, 'sel_hc', 1, 'sel_hr', 1);
    
    S.exc.type = 'Nincs';
    S.exc.amp = 1; S.exc.freq = 4; S.exc.phase = 0; S.exc.offset = 0; S.exc.duty = 0.5;
    S.exc.step_t = 1; S.exc.step_init = 0; S.exc.step_final = 1;
    S.exc.tend = 10; S.exc.ts = 0.001;
    S.exc.gains = [1 1 1 1];
    S.exc.phasew = [0 0 0 0];
    S.exc.a_x = 1*9.81*0;
    S.exc.a_y = 0.2*9.81*0;
    S.exc.randfreqs = [0.390625;0.78125;1.171875;1.5625;1.953125;2.34375;2.734375;3.125;3.515625;3.90625;4.296875;4.6875;5.078125;5.46875;5.859375;6.25;6.640625;7.03125;7.421875;7.8125;8.203125;8.59375;8.984375;9.375;9.765625;10.15625;10.546875;10.9375;11.328125;11.71875;12.109375;12.5;12.890625;13.28125;13.671875;14.0625;14.453125;14.84375;15.234375;15.625];
    S.exc.randamps = [10.49591923;4.705476284;0.662549913;0.384269953;0.311593354;0.209382221;0.204325601;0.154739559;0.136765137;0.102525115;0.08531332;0.081781358;0.072900273;0.063704491;0.044159256;0.031387117;0.023464901;0.025956012;0.024276853;0.024827089;0.02619116;0.035721079;0.031663958;0.026932528;0.023164477;0.022238526;0.027051585;0.027686883;0.02799874;0.023082441;0.021116797;0.019620154;0.021030517;0.02045726;0.022874877;0.018103965;0.011119875;0.005522729;0.004848736;0.005350151];
    S.exc.randdelay = rand([38, 1]);
end

function d = param_defs()
    d = {
    'Jármű geometria', 'wheelbase',          1.54,    'Tengelytáv [m]';
    'Jármű geometria', 'front_track',        1.22,    'Első nyomtáv [m]';
    'Jármű geometria', 'rear_track',         1.20,    'Hátsó nyomtáv [m]';
    'Jármű geometria', 'ui_COG_x',          -770.09,  'Rugózott tömeg COG X [mm]';
    'Jármű geometria', 'ui_COG_y',           0,       'Rugózott tömeg COG Y [mm]';
    'Jármű geometria', 'ui_COG_z',           272.71,  'Rugózott tömeg COG Z [mm]';
    'Jármű geometria', 'aero_distribution',  0.45,    'Aero nyomásközéppont eloszlás [-]';
    'Jármű geometria', 'ui_COP_z',           100,     'COP Z magasság [mm]';
    'Jármű geometria', 'g',                  9.81,    'Nehézségi gyorsulás [m/s^2]';
    'Jármű geometria', 'front_cog_height',   0.22,    'Első COG magasság [m]';
    'Jármű geometria', 'rear_cog_height',    0.31,    'Hátsó COG magasság [m]';
    'Jármű geometria', 'weight_distribution',0.49,    'Első tengely tömegaránya [-]';
    'Jármű geometria', 'wheel_radius',       0.193,   'Kerékrádiusz [m]';
    'Tömegek', 'm_tyre',        3.2,     'Gumi [kg]';
    'Tömegek', 'm_rim',         0.78,    'Felni [kg]';
    'Tömegek', 'ui_m_upright_body', 0.88, 'Rudak (upright) [kg]';
    'Tömegek', 'ui_m_brake',    3.13,    'Fék [kg]';
    'Tömegek', 'ui_m_motor',    7.08,    'Motor [kg]';
    'Tömegek', 'ui_m_gearbox',  0.66,    'Hajtómű [kg]';
    'Tömegek', 'ui_m10_extra',  0.4158,  'm10: 1102-es assembly (rudak) tömege [kg]';
    'Tömegek', 'ui_m30_extra',  0.4158,  'm30: ugyanez hátul [kg]';
    'Tömegek', 'm_s0',          179.6,   'Rugózott tömeg vezető nélkül [kg]';
    'Tömegek', 'm_fuel',        0,       'Üzemanyag [kg]';
    'Tömegek', 'm_driver',      75,      'Vezető [kg]';
    'Tömegek', 'm_rocker_front',0.1975,  'Rocker első [kg]';
    'Tömegek', 'm_rocker_rear', 0.1955,  'Rocker hátsó [kg]';
    'Tömegek', 'm_damper_front',0.8225,  'Lengéscsillapító első [kg]';
    'Tömegek', 'm_damper_rear', 0.8287,  'Lengéscsillapító hátsó [kg]';
    'Tömegek', 'm_push_pull_rod_front', 0.1031, 'Push/pull rúd első [kg]';
    'Tömegek', 'm_push_pull_rod_rear',  0.0912, 'Push/pull rúd hátsó [kg]';
    'Tömegek', 'm_droplink_front', 0.0485, 'Droplink első [kg]';
    'Tömegek', 'm_droplink_rear',  0.0485, 'Droplink hátsó [kg]';
    'Tömegek', 'm_ARB_lever_front',0.008,  'ARB kar első [kg]';
    'Tömegek', 'm_ARB_lever_rear', 0.008,  'ARB kar hátsó [kg]';
    'Tömegek', 'm_ARB_front',   0.0696,  'ARB első [kg]';
    'Tömegek', 'm_ARB_rear',    0.0696,  'ARB hátsó [kg]';
    'Tömegek', 'm_UCA_front',   0.2327,  'Felső lengőkar első [kg]';
    'Tömegek', 'm_UCA_rear',    0.1814,  'Felső lengőkar hátsó [kg]';
    'Tömegek', 'm_LCA_front',   0.2259,  'Alsó lengőkar első [kg]';
    'Tömegek', 'm_LCA_rear',    0.2244,  'Alsó lengőkar hátsó [kg]';
    'Tömegek', 'm_tierod_front',0.0708,  'Kormányrúd első [kg]';
    'Tömegek', 'm_tierod_rear', 0.067,   'Kormányrúd hátsó [kg]';
    'Tömegek', 'm_aerodynamics',13,      'Aerodinamikai elemek [kg]';
    'Tömegek', 'm_chassis',     20,      'Alváz [kg]';
    'Inerciák', 'roll_inertia',  38.215,  'Roll inercia [kgm^2]';
    'Inerciák', 'pitch_inertia', 121.714, 'Pitch inercia [kgm^2]';
    'Inerciák', 'yaw_inertia',   96.280,  'Yaw inercia [kgm^2]';
    'Inerciák', 'tyre_IXX',      0.651/4, 'Gumi IXX (kerekenként) [kgm^2]';
    'Hajtás', 'PLANETARY_GEAR_RATIO', 12.13, 'Bolygómű áttétel [-]';
    'Hajtás', 'R_WHEEL',         0.193,   'Kerékrádiusz [m]';
    'Hajtás', 'I_engine',        0.2,     'Motor inercia [kgm^2]';
    'Hajtás', 'I_powertrain',    0.0013,  'Hajtáslánc inercia [kgm^2]';
    'Aerodinamika', 'cl',  5,    'Felhajtóerő-tényező [-]';
    'Aerodinamika', 'cd',  1,    'Légellenállás-tényező [-]';
    'Aerodinamika', 'A',   1.6,  'Referencia felület [m^2]';
    'Aerodinamika', 'rho', 1.22, 'Levegő sűrűsége [kg/m^3]';
    'Futómű setup', 'fl_static_toe',    0, 'Statikus toe FL';
    'Futómű setup', 'fr_static_toe',    0, 'Statikus toe FR';
    'Futómű setup', 'rl_static_toe',    0, 'Statikus toe RL';
    'Futómű setup', 'rr_static_toe',    0, 'Statikus toe RR';
    'Futómű setup', 'fl_static_camber', 0, 'Statikus camber FL';
    'Futómű setup', 'fr_static_camber', 0, 'Statikus camber FR';
    'Futómű setup', 'rl_static_camber', 0, 'Statikus camber RL';
    'Futómű setup', 'rr_static_camber', 0, 'Statikus camber RR';
    'Méretek (átmérők)', 'ARB_front_diameter',            10, 'ARB első átmérő [mm]';
    'Méretek (átmérők)', 'Droplink_front_diameter',       18, 'Droplink első átmérő [mm]';
    'Méretek (átmérők)', 'UCA_front_diameter',            18, 'UCA első átmérő [mm]';
    'Méretek (átmérők)', 'LCA_front_diameter',            18, 'LCA első átmérő [mm]';
    'Méretek (átmérők)', 'Tierod_front_diameter',          8, 'Kormányrúd első átmérő [mm]';
    'Méretek (átmérők)', 'Push_pull_rod_front_diameter',  18, 'Push/pull rúd első átmérő [mm]';
    'Méretek (átmérők)', 'Rack_diameter',                 14, 'Fogasléc átmérő [mm]';
    'Méretek (átmérők)', 'ARB_rear_diameter',             10, 'ARB hátsó átmérő [mm]';
    'Méretek (átmérők)', 'Droplink_rear_diameter',        18, 'Droplink hátsó átmérő [mm]';
    'Méretek (átmérők)', 'UCA_rear_diameter',             18, 'UCA hátsó átmérő [mm]';
    'Méretek (átmérők)', 'LCA_rear_diameter',             18, 'LCA hátsó átmérő [mm]';
    'Méretek (átmérők)', 'Tierod_rear_diameter',           8, 'Kormányrúd hátsó átmérő [mm]';
    'Méretek (átmérők)', 'Push_pull_rod_rear_diameter',   18, 'Push/pull rúd hátsó átmérő [mm]';
    'Spring-damper számítás', 'sd_m_NSM_F',     41.8/4,        'Első sarki rugózatlan tömeg [kg] (SpringDamper_Calc: m_NSM_F) - ellenőrizd!';
    'Spring-damper számítás', 'sd_m_NSM_R',     41.8/4,        'Hátsó sarki rugózatlan tömeg [kg] (SpringDamper_Calc: m_NSM_R) - ellenőrizd!';
    'Spring-damper számítás', 'sd_K_tire',      588*175.127,   'Gumiabroncs függőleges merevség [N/m] (588 lbs/in)';
    'Spring-damper számítás', 'sd_K_HEAVE_F',   0,             'Első heave stabilizátor droplink-merevség [N/m] (0 = nincs)';
    'Spring-damper számítás', 'sd_K_HEAVE_R',   0,             'Hátsó heave stabilizátor droplink-merevség [N/m] (0 = nincs)';
    'Spring-damper számítás', 'sd_MR_ARB_F',    0.85,          'Első stabilizátor motion ratio (statikus) - csak heave stab.-nál számít';
    'Spring-damper számítás', 'sd_MR_ARB_R',    0.80,          'Hátsó stabilizátor motion ratio (statikus) - csak heave stab.-nál számít';
    'Spring-damper számítás', 'sd_f_max',       50,            'A_RMS frekvenciarács felső határa [Hz]';
    'Spring-damper számítás', 'sd_f_n',         500,           'A_RMS frekvenciarács pontszáma [db]';
    'Spring-damper számítás', 'sd_xi_min',      0.1,           'xi-rács alsó határa az A_RMS-optimumhoz [-]';
    'Spring-damper számítás', 'sd_xi_max',      1.5,           'xi-rács felső határa az A_RMS-optimumhoz [-]';
    'Spring-damper számítás', 'sd_xi_n',        80,            'xi-rács pontszáma [db]';
    'Spring-damper számítás', 'sd_opt_enable',  1,             'xi_opt / A_RMS_opt számítása (1 = igen, 0 = nem; kikapcsolva gyorsabb)';
    'Spring-damper számítás', 'sd_opt_tol',     0.01,          'Optimum újraszámolása, ha a wheel rate ennyi (relatív) értéknél többet változott';
    'Rugózás elöl', 'front_spring',                    225,   'Rugóállandó [lbf/in]';
    'Rugózás elöl', 'front_static_motion_ratio',       1.256, 'Statikus mozgásviszony';
    'Rugózás elöl', 'front_lower_limit_motion_ratio',  0.981, 'Mozgásviszony alsó limitnél';
    'Rugózás elöl', 'front_upper_limit_motion_ratio',  1.468, 'Mozgásviszony felső limitnél';
    'Rugózás elöl', 'ui_front_travel_down',            33,    'Kerékút lefelé [mm]';
    'Rugózás elöl', 'ui_front_travel_up',              29,    'Kerékút felfelé [mm]';
    'Rugózás elöl', 'ARB_K_tors_front',                409,   'ARB csavarmerevség [Nm/rad]';
    'Rugózás elöl', 'front_damping_ratio',             0.7,   'Csillapítási arány [-]';
    'Rugózás elöl', 'front_roll_center',               123,   'Roll center magasság [mm]';
    'Rugózás elöl', 'pitch_center',                    198,   'Pitch center magasság [mm]';
    'Rugózás elöl', 'ui_front_vmax',                   0.5,   'Karakterisztika sebességtartomány [m/s]';
    'Rugózás hátul', 'rear_spring',                    225,   'Rugóállandó [lbf/in]';
    'Rugózás hátul', 'rear_static_motion_ratio',       1.081, 'Statikus mozgásviszony';
    'Rugózás hátul', 'rear_lower_limit_motion_ratio',  1.006, 'Mozgásviszony alsó limitnél';
    'Rugózás hátul', 'rear_upper_limit_motion_ratio',  1.161, 'Mozgásviszony felső limitnél';
    'Rugózás hátul', 'ui_rear_travel_down',            33,    'Kerékút lefelé [mm]';
    'Rugózás hátul', 'ui_rear_travel_up',              29,    'Kerékút felfelé [mm]';
    'Rugózás hátul', 'ARB_K_tors_rear',                271,   'ARB csavarmerevség [Nm/rad]';
    'Rugózás hátul', 'rear_damping_ratio',             0.7,   'Csillapítási arány [-]';
    'Rugózás hátul', 'rear_roll_center',               125,   'Roll center magasság [mm]';
    'Rugózás hátul', 'ui_rear_vmax',                   0.5,   'Karakterisztika sebességtartomány [m/s]';
    };
end

function c = preview_damping(PRM, key)
    m_up = PRM.ui_m_upright_body + PRM.ui_m_brake + PRM.ui_m_motor + PRM.ui_m_gearbox;
    m10 = PRM.ui_m10_extra + m_up; m30 = PRM.ui_m30_extra + m_up;
    m_sprung = PRM.m_s0 + PRM.m_fuel + PRM.m_driver - 2*m10 - 2*m30;
    if strcmp(key, 'front')
        k = PRM.front_spring*175.127; MR = PRM.front_static_motion_ratio;
        share = PRM.weight_distribution; zeta = PRM.front_damping_ratio;
    else
        k = PRM.rear_spring*175.127; MR = PRM.rear_static_motion_ratio;
        share = 1 - PRM.weight_distribution; zeta = PRM.rear_damping_ratio;
    end
    ckrit = 2*sqrt(k/MR^2*(m_sprung*share)/2);
    c = real(zeta*ckrit*MR^2);
end

function P = build_full_prm(S)
    P = S.PRM;
    E = S.exc;
    P.freq = E.freq;
    P.gains = E.gains(:)';
    P.randfreqs = E.randfreqs(:);
    P.randamps = E.randamps(:);
    P.randdelay = E.randdelay(:);
    P.a_x = E.a_x;
    P.a_y = E.a_y;
    t = (0:E.ts:E.tend)';
    P.exc_type = E.type;
    P.exc_enable = double(~strcmp(E.type, 'Nincs'));
    P.exc_amp = E.amp; P.exc_freq = E.freq; P.exc_phase = E.phase; P.exc_offset = E.offset;
    P.exc_duty = E.duty;
    P.exc_step_time = E.step_t; P.exc_step_init = E.step_init; P.exc_step_final = E.step_final;
    P.exc_tend = E.tend; P.exc_sample_time = E.ts;
    P.exc_phase_wheels = E.phasew(:)';
    P.exc_ts = [t, exc_signal(E, t)];
    for ky = {'front', 'rear'}
        key = ky{1};
        D = S.damper.(key);
        use = D.source > 1 && numel(D.v) >= 2;
        P.(['ui_' key '_damper_mode']) = double(use);
        if use
            vmax = S.PRM.(['ui_' key '_vmax']);
            vg = linspace(-vmax, vmax, 21)';
            [xs, ia] = unique(D.v(:));
            Fy = D.F(:); Fy = Fy(ia);
            P.(['ui_' key '_char_v']) = vg;
            P.(['ui_' key '_char_F']) = interp1(xs, Fy, vg, 'pchip', 'extrap'); % Ez adja át a c(v) értékeket
        else
            P.(['ui_' key '_char_v']) = [-1; 1];
            P.(['ui_' key '_char_F']) = [0; 0];
        end
    end
end

function y = exc_signal(E, t)
    t = t(:); n = numel(t);
    y = zeros(n, 4);
    if strcmp(E.type, 'Nincs'), return; end
    for w = 1:4
        ph = E.phase + E.phasew(w);
        switch E.type
            case 'Sine'
                s = E.amp*sin(2*pi*E.freq*t + deg2rad(ph));
            case 'Cosine'
                s = E.amp*cos(2*pi*E.freq*t + deg2rad(ph));
            case 'Square'
                p = mod(E.freq*t + ph/360, 1);
                s = E.amp*(2*(p < E.duty) - 1);
            case 'Sawtooth'
                p = mod(E.freq*t + ph/360, 1);
                s = E.amp*(2*p - 1);
            case 'Triangle'
                p = mod(E.freq*t + ph/360, 1);
                s = E.amp*(1 - 2*abs(2*mod(p + 0.25, 1) - 1));
            case 'Step'
                s = E.step_init + (E.step_final - E.step_init)*(t >= E.step_t);
            case 'Random (spektrum)'
                m = min([numel(E.randfreqs), numel(E.randamps), numel(E.randdelay)]);
                s = zeros(n, 1);
                for k = 1:m
                    s = s + E.randamps(k)*sin(2*pi*E.randfreqs(k)*t + 2*pi*E.randdelay(k));
                end
            otherwise
                s = zeros(n, 1);
        end
        y(:, w) = E.offset + E.gains(w)*s;
    end
end

function lines = geometry_summary(V)
    names = {'Damper_front_length', 'Damper_rear_length', 'ARB_front_length', 'ARB_rear_length', ...
        'ARB_lever_front_length', 'ARB_lever_rear_length', 'Droplink_front_length', 'Droplink_rear_length', ...
        'Push_pull_rod_front_length', 'Push_pull_rod_rear_length', 'Tierod_front_length', 'Tierod_rear_length', ...
        'Rack_length', 'front_equilibrium_position', 'rear_equilibrium_position', ...
        'front_lower_limit', 'front_upper_limit', 'rear_lower_limit', 'rear_upper_limit'};
    lines = {'Az ELFOGADOTT pontokból számolt származtatott értékek [mm]:'};
    for q = 1:numel(names)
        if isfield(V, names{q})
            lines{end+1, 1} = sprintf('  %-30s %10.3f', names{q}, V.(names{q})); %#ok<AGROW>
        end
    end
    lines{end+1, 1} = '(A unit vektorok, forgatási mátrixok, transzlációk is frissültek; export a 5. fülön.)';
end

function [v, F] = load_char_excel(path)
    C = readcell(path);
    rv = C(1, 2:end); rf = C(2, 2:end);
    keep = cellfun(@(x) isnumeric(x) && isscalar(x) && ~isnan(x), rv) & ...
           cellfun(@(x) isnumeric(x) && isscalar(x) && ~isnan(x), rf);
    v = cell2mat(rv(keep)); F = cell2mat(rf(keep));
    v = v(:); F = F(:);
    [v, ia] = unique(v); F = F(ia);
end

function fname = save_char_excel(prefix, v, F)
    v = v(:)'; F = F(:)';
    out = [{'Velocity [m/s]'}, num2cell(v); {'Damping Coeff [N*s/m]'}, num2cell(F)];
    idx = 0;
    while true
        if idx == 0, fname = [prefix '.xlsx']; else, fname = sprintf('%s_%d.xlsx', prefix, idx); end
        if ~isfile(fname)
            writecell(out, fname); return;
        end
        try
            [v0, F0] = load_char_excel(fname);
            if numel(v0) == numel(v) && max(abs(v0(:)' - v)) < 1e-9 && max(abs(F0(:)' - F)) < 1e-9
                return;
            end
        catch
        end
        idx = idx + 1;
    end
end

function [x_out, y_out] = defineCurveGUI(name, x_min, x_max, x_label, y_label, init_x, init_y)
    x_pts = init_x(:);
    y_pts = init_y(:);
    x0_keep = x_pts; y0_keep = y_pts;

    fig = figure('Name', ['Karakterisztika szerkesztő: ', name], ...
        'NumberTitle', 'off', 'Position', [200 150 1000 600], ...
        'MenuBar', 'none', 'ToolBar', 'figure', 'DockControls', 'off');

    ax = axes('Parent', fig, 'Position', [0.08 0.12 0.58 0.8]);
    grid(ax, 'on'); hold(ax, 'on');
    xlabel(ax, x_label); ylabel(ax, y_label);
    [y_min_val, y_max_val] = auto_ylim(y_pts);
    xlim(ax, [x_min, x_max]); ylim(ax, [y_min_val, y_max_val]);

    pnl = uipanel('Parent', fig, 'Title', 'Vezérlők & Pontok', 'Position', [0.69 0.05 0.29 0.9]);

    uicontrol(pnl, 'Style', 'text', 'String', 'Pontok listája (X, Y):', ...
        'Position', [10 490 200 20], 'HorizontalAlignment', 'left');
    lst_points = uicontrol(pnl, 'Style', 'listbox', 'Position', [10 340 250 150]);

    uicontrol(pnl, 'Style', 'text', 'String', 'X:', 'Position', [10 305 20 20]);
    txt_x = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [30 305 55 22]);
    uicontrol(pnl, 'Style', 'text', 'String', 'Y:', 'Position', [90 305 20 20]);
    txt_y = uicontrol(pnl, 'Style', 'edit', 'String', '0', 'Position', [110 305 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Hozzáad', ...
        'Position', [170 305 90 22], 'Callback', @add_point_manual);

    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Kijelölt Pont Törlése', ...
        'Position', [10 270 250 28], 'Callback', @delete_selected_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Utolsó Visszavonása (Undo)', ...
        'Position', [10 235 250 28], 'Callback', @undo_point);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Minden Pont Törlése', ...
        'Position', [10 200 250 28], 'Callback', @clear_points);

    uicontrol(pnl, 'Style', 'text', 'String', 'Y min / Y max skála:', ...
        'Position', [10 160 120 20], 'HorizontalAlignment', 'left');
    txt_ymin = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_min_val), 'Position', [10 135 55 22]);
    txt_ymax = uicontrol(pnl, 'Style', 'edit', 'String', num2str(y_max_val), 'Position', [70 135 55 22]);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Skála Beállítása', ...
        'Position', [135 135 125 22], 'Callback', @update_axes_limits);

    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Megtart / Ugrás (Skip)', ...
        'Position', [10 80 250 35], 'BackgroundColor', [0.85 0.9 0.85], 'Callback', @skip_callback);
    uicontrol(pnl, 'Style', 'pushbutton', 'String', 'Mentés és Folytatás', ...
        'Position', [10 30 250 40], 'BackgroundColor', [0.2 0.7 0.2], ...
        'ForegroundColor', [1 1 1], 'FontWeight', 'bold', 'Callback', @save_callback);

    set(fig, 'WindowButtonDownFcn', @click_on_axes);
    update_plot_and_list();
    uiwait(fig);

    if isempty(x_pts)
        x_out = []; y_out = [];
    else
        [x_out, ia] = unique(x_pts);
        y_out = y_pts(ia);
    end
    if ishandle(fig), close(fig); end

    function click_on_axes(~, ~)
        cp = get(ax, 'CurrentPoint'); cx = cp(1,1); cy = cp(1,2);
        xl = xlim(ax); yl = ylim(ax);
        if cx >= xl(1) && cx <= xl(2) && cy >= yl(1) && cy <= yl(2)
            x_pts(end+1, 1) = cx; y_pts(end+1, 1) = cy;
            update_plot_and_list();
        end
    end
    function add_point_manual(~, ~)
        nx = str2double(get(txt_x, 'String')); ny = str2double(get(txt_y, 'String'));
        if ~isnan(nx) && ~isnan(ny)
            x_pts(end+1, 1) = nx; y_pts(end+1, 1) = ny;
            update_plot_and_list();
        end
    end
    function delete_selected_point(~, ~)
        if isempty(x_pts), return; end
        idx = get(lst_points, 'Value');
        if isempty(idx) || idx < 1 || idx > length(x_pts), return; end
        x_pts(idx) = []; y_pts(idx) = [];
        update_plot_and_list();
    end
    function undo_point(~, ~)
        if ~isempty(x_pts)
            x_pts(end) = []; y_pts(end) = [];
            update_plot_and_list();
        end
    end
    function clear_points(~, ~)
        x_pts = []; y_pts = [];
        update_plot_and_list();
    end
    function update_axes_limits(~, ~)
        ymin_n = str2double(get(txt_ymin, 'String'));
        ymax_n = str2double(get(txt_ymax, 'String'));
        if ~isnan(ymin_n) && ~isnan(ymax_n) && ymax_n > ymin_n
            ylim(ax, [ymin_n, ymax_n]);
        end
    end
    function skip_callback(~, ~)
        x_pts = x0_keep; y_pts = y0_keep;
        uiresume(fig);
    end
    function save_callback(~, ~)
        uiresume(fig);
    end

    function update_plot_and_list()
        cla(ax); grid(ax, 'on'); hold(ax, 'on');
        if length(x_pts) >= 2
            [xs, s_idx] = sort(x_pts); ys = y_pts(s_idx);
            [xs, u_idx] = unique(xs); ys = ys(u_idx);
            if numel(xs) >= 2
                z_fit = linspace(x_min, x_max, 200);
                y_fit = interp1(xs, ys, z_fit, 'pchip', 'extrap');
                plot(ax, z_fit, y_fit, 'b-', 'LineWidth', 2);
            end
        end
        if ~isempty(x_pts)
            plot(ax, x_pts, y_pts, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        end
        str_list = cell(length(x_pts), 1);
        for i = 1:length(x_pts)
            str_list{i} = sprintf('%d:  X = %.4g,  Y = %.4g', i, x_pts(i), y_pts(i));
        end
        set(lst_points, 'String', str_list);
        if ~isempty(str_list)
            set(lst_points, 'Value', min(max(get(lst_points, 'Value'), 1), length(str_list)));
        end
    end
end

function [lo, hi] = auto_ylim(y)
    if isempty(y), lo = 0; hi = 5000; return; end
    rg = max(y) - min(y);
    pad = max(0.15*rg, 100);
    lo = max(0, min(y) - pad); hi = max(y) + pad;
end

function V = compute_suspension(front_sheet, rear_sheet, front_points, rear_points, PRM)
fn = fieldnames(PRM);
for ii = 1:numel(fn)
    eval([fn{ii} ' = PRM.(fn{ii});']);
end

for i = 1:height(front_points)
    rawName = front_points.Point{i};
    baseName = strtrim(rawName);
    X_val = front_points.X(i);
    Y_val = front_points.Y(i);
    Z_val = front_points.Z(i);
    varName1 = [baseName, '1'];
    vectorValue1 = [X_val; Y_val; Z_val];
    eval([varName1 ' = vectorValue1;']);
    varName2 = [baseName, '2'];
    vectorValue2 = [X_val; Y_val * -1; Z_val];
    eval([varName2 ' = vectorValue2;']);
end

if contains(front_sheet, 'Front_1') || contains(front_sheet, 'Front_2') || contains(front_sheet, 'Front_3')
    ARB_front_length = ARB_1(2)*2;
    ARB_lever_front_length = abs(ARB_1(1)-Droplink_ARB_1(1));
    Droplink_front_length = norm(Droplink_ARB_1-Droplink_rocker_1);
    Damper_front_length = norm(Damper_chassis_1-Damper_rocker_1);
    Push_pull_rod_front_length = norm(Push_pull_rod_rocker_1-Push_pull_rod_upright_1);
    Tierod_front_length = norm(Tierod_inner_1-Tierod_upright_1);

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

    UCA_front_1_vec=UCA_front_1-UCA_upright_front_1;
    UCA_front_1_center=(UCA_front_1+UCA_upright_front_1)/2;
    UCA_front_front_length=norm(UCA_front_1_vec);
    UCA_front_1_vec_unit=UCA_front_1_vec/UCA_front_front_length;
    Base_UCA_front_1_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_1_vec_unit));
    UCA_front_1_trans = [0; 0; 0];
    
    UCA_rear_1_vec=UCA_rear_1-UCA_upright_rear_1;
    UCA_rear_1_center=(UCA_rear_1+UCA_upright_rear_1)/2;
    UCA_front_rear_length=norm(UCA_rear_1_vec);
    UCA_rear_1_vec_unit=UCA_rear_1_vec/UCA_front_rear_length;
    Base_UCA_rear_1_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_1_vec_unit));
    UCA_rear_1_trans = [0; 0; 0];
    
    Push_pull_rod_front_1_vec = Push_pull_rod_rocker_1-Push_pull_rod_upright_1;
    Push_pull_rod_front_1_center = (Push_pull_rod_rocker_1+Push_pull_rod_upright_1)/2;
    Push_pull_rod_front_length=norm(Push_pull_rod_front_1_vec);
    Push_pull_rod_front_1_vec_unit=Push_pull_rod_front_1_vec/Push_pull_rod_front_length;
    Base_Push_pull_rod_front_1_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_front_1_vec_unit));
    Push_pull_rod_front_1_trans = [0; 0; 0];
    
    LCA_front_1_vec=LCA_front_1-LCA_upright_front_1;
    LCA_front_1_center=(LCA_front_1+LCA_upright_front_1)/2;
    LCA_front_front_length=norm(LCA_front_1_vec);
    LCA_front_1_vec_unit=LCA_front_1_vec/LCA_front_front_length;
    Base_LCA_front_1_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_1_vec_unit));
    LCA_front_1_trans = [0; 0; 0];
    
    LCA_rear_1_vec=LCA_rear_1-LCA_upright_rear_1;
    LCA_rear_1_center=(LCA_rear_1+LCA_upright_rear_1)/2;
    LCA_front_rear_length=norm(LCA_rear_1_vec);
    LCA_rear_1_vec_unit=LCA_rear_1_vec/LCA_front_rear_length;
    Base_LCA_rear_1_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_rear_1_vec_unit));
    LCA_rear_1_trans = [0; 0; 0];

    UCA_front_2_vec=UCA_front_2-UCA_upright_front_2;
    UCA_front_2_center=(UCA_front_2+UCA_upright_front_2)/2;
    UCA_front_front_length=norm(UCA_front_2_vec);
    UCA_front_2_vec_unit=UCA_front_2_vec/UCA_front_front_length;
    Base_UCA_front_2_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_2_vec_unit));
    UCA_front_2_trans = [0; 0; 0];
    
    UCA_rear_2_vec=UCA_rear_2-UCA_upright_rear_2;
    UCA_rear_2_center=(UCA_rear_2+UCA_upright_rear_2)/2;
    UCA_front_rear_length=norm(UCA_rear_2_vec);
    UCA_rear_2_vec_unit=UCA_rear_2_vec/UCA_front_rear_length;
    Base_UCA_rear_2_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_2_vec_unit));
    UCA_rear_2_trans = [0; 0; 0];
    
    Push_pull_rod_front_2_vec = Push_pull_rod_rocker_2-Push_pull_rod_upright_2;
    Push_pull_rod_front_2_center = (Push_pull_rod_rocker_2+Push_pull_rod_upright_2)/2;
    Push_pull_rod_front_length=norm(Push_pull_rod_front_2_vec);
    Push_pull_rod_front_2_vec_unit=Push_pull_rod_front_2_vec/Push_pull_rod_front_length;
    Base_Push_pull_rod_front_2_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_front_2_vec_unit));
    Push_pull_rod_front_2_trans = [0; 0; 0];
    
    LCA_front_2_vec=LCA_front_2-LCA_upright_front_2;
    LCA_front_2_center=(LCA_front_2+LCA_upright_front_2)/2;
    LCA_front_front_length=norm(LCA_front_2_vec);
    LCA_front_2_vec_unit=LCA_front_2_vec/LCA_front_front_length;
    Base_LCA_front_2_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_2_vec_unit));
    LCA_front_2_trans = [0; 0; 0];
    
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
    error('Ismeretlen első lap neve: %s', front_sheet);
end

for i = 1:height(rear_points)
    rawName = rear_points.Point{i};
    baseName = strtrim(rawName);
    X_val = rear_points.X(i);
    Y_val = rear_points.Y(i);
    Z_val = rear_points.Z(i);
    varName1 = [baseName, '3'];
    vectorValue1 = [X_val; Y_val; Z_val];
    eval([varName1 ' = vectorValue1;']);
    varName2 = [baseName, '4'];
    vectorValue2 = [X_val; Y_val * -1; Z_val];
    eval([varName2 ' = vectorValue2;']);
end

if contains(rear_sheet, 'Rear_1') || contains(rear_sheet, 'Rear_2') || contains(rear_sheet, 'Rear_3')
    ARB_rear_length = ARB_3(2)*2;
    ARB_lever_rear_length = abs(ARB_3(1)-Droplink_ARB_3(1));
    Droplink_rear_length = norm(Droplink_ARB_3-Droplink_rocker_3);
    Damper_rear_length = norm(Damper_chassis_3-Damper_rocker_3);
    Push_pull_rod_rear_length = norm(Push_pull_rod_rocker_3-Push_pull_rod_upright_3);
    Tierod_rear_length = norm(Tierod_inner_3-Tierod_upright_3);

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

    UCA_front_3_vec=UCA_front_3-UCA_upright_front_3;
    UCA_front_3_center=(UCA_front_3+UCA_upright_front_3)/2;
    UCA_rear_front_length=norm(UCA_front_3_vec);
    UCA_front_3_vec_unit=UCA_front_3_vec/UCA_rear_front_length;
    Base_UCA_front_3_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_3_vec_unit));
    UCA_front_3_trans = [0; 0; 0];
    
    UCA_rear_3_vec=UCA_rear_3-UCA_upright_rear_3;
    UCA_rear_3_center=(UCA_rear_3+UCA_upright_rear_3)/2;
    UCA_rear_rear_length=norm(UCA_rear_3_vec);
    UCA_rear_3_vec_unit=UCA_rear_3_vec/UCA_rear_rear_length;
    Base_UCA_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_3_vec_unit));
    UCA_rear_3_trans = [0; 0; 0];
    
    Push_pull_rod_rear_3_vec = Push_pull_rod_rocker_3-Push_pull_rod_upright_3;
    Push_pull_rod_rear_3_center = (Push_pull_rod_rocker_3+Push_pull_rod_upright_3)/2;
    Push_pull_rod_rear_length=norm(Push_pull_rod_rear_3_vec);
    Push_pull_rod_rear_3_vec_unit=Push_pull_rod_rear_3_vec/Push_pull_rod_rear_length;
    Base_Push_pull_rod_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_rear_3_vec_unit));
    Push_pull_rod_rear_3_trans = [0; 0; 0];
    
    LCA_front_3_vec=LCA_front_3-LCA_upright_front_3;
    LCA_front_3_center=(LCA_front_3+LCA_upright_front_3)/2;
    LCA_rear_front_length=norm(LCA_front_3_vec);
    LCA_front_3_vec_unit=LCA_front_3_vec/LCA_rear_front_length;
    Base_LCA_front_3_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_3_vec_unit));
    LCA_front_3_trans = [0; 0; 0];
    
    LCA_rear_3_vec=LCA_rear_3-LCA_upright_rear_3;
    LCA_rear_3_center=(LCA_rear_3+LCA_upright_rear_3)/2;
    LCA_rear_rear_length=norm(LCA_rear_3_vec);
    LCA_rear_3_vec_unit=LCA_rear_3_vec/LCA_rear_rear_length;
    Base_LCA_rear_3_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_rear_3_vec_unit));
    LCA_rear_3_trans = [0; 0; 0];

    UCA_front_4_vec=UCA_front_4-UCA_upright_front_4;
    UCA_front_4_center=(UCA_front_4+UCA_upright_front_4)/2;
    UCA_rear_front_length=norm(UCA_front_4_vec);
    UCA_front_4_vec_unit=UCA_front_4_vec/UCA_rear_front_length;
    Base_UCA_front_4_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_front_4_vec_unit));
    UCA_front_4_trans = [0; 0; 0];

    UCA_rear_4_vec=UCA_rear_4-UCA_upright_rear_4;
    UCA_rear_4_center=(UCA_rear_4+UCA_upright_rear_4)/2;
    UCA_rear_rear_length=norm(UCA_rear_4_vec);
    UCA_rear_4_vec_unit=UCA_rear_4_vec/UCA_rear_rear_length;
    Base_UCA_rear_4_rot = vrrotvec2mat(vrrotvec([0;0;1],UCA_rear_4_vec_unit));
    UCA_rear_4_trans = [0; 0; 0];

    Push_pull_rod_rear_4_vec = Push_pull_rod_rocker_4-Push_pull_rod_upright_4;
    Push_pull_rod_rear_4_center = (Push_pull_rod_rocker_4+Push_pull_rod_upright_4)/4;
    Push_pull_rod_rear_length=norm(Push_pull_rod_rear_4_vec);
    Push_pull_rod_rear_4_vec_unit=Push_pull_rod_rear_4_vec/Push_pull_rod_rear_length;
    Base_Push_pull_rod_rear_4_rot = vrrotvec2mat(vrrotvec([0;0;1],Push_pull_rod_rear_4_vec_unit));
    Push_pull_rod_rear_4_trans = [0; 0; 0];

    LCA_front_4_vec=LCA_front_4-LCA_upright_front_4;
    LCA_front_4_center=(LCA_front_4+LCA_upright_front_4)/2;
    LCA_rear_front_length=norm(LCA_front_4_vec);
    LCA_front_4_vec_unit=LCA_front_4_vec/LCA_rear_front_length;
    Base_LCA_front_4_rot = vrrotvec2mat(vrrotvec([0;0;1],LCA_front_4_vec_unit));
    LCA_front_4_trans = [0; 0; 0];

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
    error('Ismeretlen hátsó lap neve: %s', rear_sheet);
end

COG = [ui_COG_x; ui_COG_y; ui_COG_z];
COP = [-wheelbase*aero_distribution*1000; 0; ui_COP_z];
a = wheelbase*(1-weight_distribution);
b = wheelbase*weight_distribution;
try
    parameterStruct = mfeval.readTIR(ui_tir_file);
catch ME
    warning('Simulation_setup:tir', 'A .tir fájl nem tölthető be (%s): %s', ui_tir_file, ME.message);
    parameterStruct = [];
end

m_upright = ui_m_upright_body+ui_m_brake+ui_m_motor+ui_m_gearbox;
m10 = ui_m10_extra+m_upright;
m30 = ui_m30_extra+m_upright;
m1 = m10-(m_tyre+m_rim+m_upright);
m3 = m30-(m_tyre+m_rim+m_upright);
m_s0_driver = m_s0+m_fuel+m_driver;
m_sprung = m_s0_driver-2*m10-2*m30; 
m_s = m_s0-(m_rocker_front+m_rocker_rear+m_damper_front+m_damper_front+m_droplink_front+m_droplink_rear+m_ARB_lever_front+m_ARB_lever_rear+m_ARB_front+m_ARB_rear)*2;

Theta_S = [roll_inertia, pitch_inertia, yaw_inertia];
tyre_IYY = m_tyre*wheel_radius^2;
vehicle_inertia_at_wheel_2wd = m_s0_driver/2*wheel_radius^2;
vehicle_inertia_at_wheel_4wd = m_s0_driver/4*wheel_radius^2;

front_spring_stiffness = front_spring*175.127;
front_static_length = Damper_front_length;
front_wheel_fz = m_s0_driver*weight_distribution/2*g;
front_static_spring_force = front_wheel_fz*front_static_motion_ratio;
front_static_spring_compression = front_static_spring_force/front_spring_stiffness*1000;
front_equilibrium_position = front_static_length+front_static_spring_compression;
front_lower_limit = front_static_length-ui_front_travel_down/front_lower_limit_motion_ratio;
front_upper_limit = front_static_length+ui_front_travel_up/front_upper_limit_motion_ratio;
front_c_krit = 2*sqrt(front_spring_stiffness/front_static_motion_ratio^2*(m_sprung*weight_distribution)/2);
front_c = front_damping_ratio*front_c_krit;
front_damping_coefficient = front_c*front_static_motion_ratio^2;

rear_spring_stiffness = rear_spring*175.127;
rear_static_length = Damper_rear_length;
rear_wheel_fz = m_s0_driver*(1-weight_distribution)/2*g;
rear_static_spring_force = rear_wheel_fz*rear_static_motion_ratio;
rear_static_spring_compression = rear_static_spring_force/rear_spring_stiffness*1000;
rear_equilibrium_position = rear_static_length+rear_static_spring_compression;
rear_lower_limit = rear_static_length-ui_rear_travel_down/rear_lower_limit_motion_ratio;
rear_upper_limit = rear_static_length+ui_rear_travel_up/rear_upper_limit_motion_ratio;
rear_c_krit = 2*sqrt(rear_spring_stiffness/rear_static_motion_ratio^2*(m_sprung*(1-weight_distribution))/2);
rear_c = rear_damping_ratio*rear_c_krit;
rear_damping_coefficient = rear_c*rear_static_motion_ratio^2;

if ui_front_damper_mode == 1
    front_damper_vel = ui_front_char_v(:);
    front_damper_force = ui_front_char_F(:);
else
    front_damper_vel = ui_front_vmax*[-1; 1];
    front_damper_force = [front_damping_coefficient; front_damping_coefficient];
end
front_damper_use_char = (ui_front_damper_mode == 1);

if ui_rear_damper_mode == 1
    rear_damper_vel = ui_rear_char_v(:);
    rear_damper_force = ui_rear_char_F(:);
else
    rear_damper_vel = ui_rear_vmax*[-1; 1];
    rear_damper_force = [rear_damping_coefficient; rear_damping_coefficient];
end
rear_damper_use_char = (ui_rear_damper_mode == 1);

static_load = g*m_s0_driver;
static_load_fl = m_s0_driver*weight_distribution/2*g;
static_load_fr = m_s0_driver*weight_distribution/2*g;
static_load_rl = m_s0_driver*(1-weight_distribution)/2*g;
static_load_rr = m_s0_driver*(1-weight_distribution)/2*g;

Rack_length = norm(Tierod_inner_2-Tierod_inner_1);
Rack_center = (Tierod_inner_2+Tierod_inner_1)/2;

sd_nF = max(round(sd_f_n), 2);
sd_nX = max(round(sd_xi_n), 3);
SD = struct();
SD.k_spring   = [front_spring_stiffness*ones(2,1); rear_spring_stiffness*ones(2,1)];
SD.m1         = [m_sprung*weight_distribution/2*ones(2,1); m_sprung*(1-weight_distribution)/2*ones(2,1)];
SD.m2         = [sd_m_NSM_F*ones(2,1); sd_m_NSM_R*ones(2,1)];
SD.MR_static  = [front_static_motion_ratio*ones(2,1); rear_static_motion_ratio*ones(2,1)];
SD.K_heave    = [sd_K_HEAVE_F*ones(2,1); sd_K_HEAVE_R*ones(2,1)];
SD.MR_arb     = [sd_MR_ARB_F*ones(2,1); sd_MR_ARB_R*ones(2,1)];
SD.K_tire     = sd_K_tire;
SD.f_vec      = linspace(0, sd_f_max, sd_nF).';
SD.xi_grid    = linspace(sd_xi_min, sd_xi_max, sd_nX).';
SD.opt_enable = double(sd_opt_enable > 0);
SD.opt_tol    = sd_opt_tol;

V = struct();
vars = who;
skip = {'PRM', 'fn', 'ii', 'vars', 'skip', 'V', 'jj', 'nm', 'i', 'ME', 'rawName', 'baseName', ...
        'X_val', 'Y_val', 'Z_val', 'varName1', 'varName2', 'vectorValue1', 'vectorValue2'};
for jj = 1:numel(vars)
    nm = vars{jj};
    if any(strcmp(nm, skip)) || strncmp(nm, 'ui_', 3) || strncmp(nm, 'sd_', 3), continue; end
    V.(nm) = eval(nm);
end
end

function R = pointsToRotationMatrix(P1, P2)
v = P2 - P1;
if norm(v) == 0
    error('A két pont egybeesik, a forgatási mátrix nem számítható ki!');
end
z_vec = v / norm(v);
z_vec = z_vec(:)'; 
tol = 0.99;
if abs(z_vec(3)) > tol
    up_vec = [0, 1, 0];
else
    up_vec = [0, 0, 1];
end
x_vec = cross(up_vec, z_vec);
x_vec = x_vec / norm(x_vec);
y_vec = cross(z_vec, x_vec);
R = [x_vec(:), y_vec(:), z_vec(:)];
end

function str = get_onoff_cell(cond)
opts = {'off', 'on'};
str = opts{cond + 1};
end