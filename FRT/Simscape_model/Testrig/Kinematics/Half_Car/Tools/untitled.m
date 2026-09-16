% 1. Hardpoint koordináták megadása [X, Y, Z] méterben
hp.L.UCA_in  = [0.0, -0.4, 0.45];
hp.L.UCA_out = [0.0, -0.7, 0.40];
hp.L.LCA_in  = [0.0, -0.3, 0.20];
hp.L.LCA_out = [0.0, -0.75, 0.18];
hp.L.contactPatch = [0.0, -0.75, 0.0];

% Jobb oldal (szimmetrikus Y tengelyre)
hp.R.UCA_in  = [0.0, 0.4, 0.45];
hp.R.UCA_out = [0.0, 0.7, 0.40];
hp.R.LCA_in  = [0.0, 0.3, 0.20];
hp.R.LCA_out = [0.0, 0.75, 0.18];
hp.R.contactPatch = [0.0, 0.75, 0.0];

% 2. Függvény hívása
eredmeny = rollCenterFromHardpoints("doubleWishbone", hp);

% 3. Eredmény kiíratása
disp("Roll Center YZ síkban (Y, Z):");
disp(eredmeny.RC_YZ);