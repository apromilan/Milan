%% Sík meghatározása 3 pontból és 4. pont Z koordinátájának kiszámítása
clear; clc;

fprintf('=== Sík meghatározása 3 pontból ===\n\n');

% 1. Három pont bekérése
% fprintf('Add meg az első pont koordinátáit (P1):\n');
% x1 = input('  x1 = ');
% y1 = input('  y1 = ');
% z1 = input('  z1 = ');
% 
% fprintf('\nAdd meg a második pont koordinátáit (P2):\n');
% x2 = input('  x2 = ');
% y2 = input('  y2 = ');
% z2 = input('  z2 = ');
% 
% fprintf('\nAdd meg a harmadik pont koordinátáit (P3):\n');
% x3 = input('  x3 = ');
% y3 = input('  y3 = ');
% z3 = input('  z3 = ');

x1 = 205.47; y1 =126.962 ; z1 = 324.866;
x2 = -407.280; y2 = 161.941; z2 = 274.481;
x3 = 21.475; y3 = 725.943; z3 = 239.577;

% Pontok vektorként
P1 = [x1, y1, z1];
P2 = [x2, y2, z2];
P3 = [x3, y3, z3];

disp(P3)

% Vektorok kiszámítása
v1 = P2 - P1;
v2 = P3 - P1;

% Normálvektor (kereszt szorzat)
N = cross(v1, v2);

% Ellenőrzés: ha a három pont kollineáris (normálvektor = [0 0 0])
if norm(N) < 1e-10
    error('Hiba: A három megadott pont kollineáris! Nem határozható meg egyértelmű sík.');
end

% Sík egyenlet: ax + by + cz + d = 0
a = N(1);
b = N(2);
c = N(3);
d = -dot(N, P1);

fprintf('\nA sík egyenlete: %.4fx + %.4fy + %.4fz + %.4f = 0\n', a, b, c, d);

%% 4. pont Z koordinátájának kiszámítása
fprintf('\n=== 4. pont Z koordinátájának számítása ===\n\n');

x = input('Add meg a 4. pont x koordinátáját: ');
y = input('Add meg a 4. pont y koordinátáját: ');

% Z kiszámítása
if abs(c) < 1e-10
    warning('A sík majdnem függőleges (c ≈ 0). Nem lehet egyértelműen meghatározni z-t adott x,y-hez.');
    z = NaN;
else
    z = -(a*x + b*y + d) / c;
end

fprintf('\nA 4. pont koordinátái: (%.4f, %.4f, %.4f)\n', x, y, z);