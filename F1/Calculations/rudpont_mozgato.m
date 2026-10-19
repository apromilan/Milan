% --- Pont mozgatasa a ket pont altal meghatarozott egyenes menten ---
clear; clc;

% Alappontok (2D vagy 3D, a dimenzio automatikusan kezelt)
% P1 = [60.474, 650, 505.769];      % rogzitett pont
% P2 = [200, 150, 505];      % mozgatando pont
P1 = [-37.875, 213.337, 586.014];      % rogzitett pont
P2 = [-37.875, 705.641, 281];      % mozgatando pont


% Mozgatas merteke: pozitiv = tavolodas, negativ = kozeledes
delta = -40;          % pl. 2 egysegnyivel kozelebb

% Egyseg iranyvektor P1-bol P2 fele
v = P2 - P1;
d0 = norm(v);
if d0 == 0
    error('A ket pont egybeesik, az egyenes iranya nem hatarozhato meg.');
end
u = v / d0;

% Uj tavolsag es uj pozicio
d_uj = d0 + delta;
P2_uj = P1 + u * d_uj;

% Eredmenyek
fprintf('Eredeti tavolsag: %.4f\n', d0);
fprintf('Uj tavolsag:      %.4f\n', norm(P2_uj - P1));
fprintf('Uj P2 pozicio:    %s\n', mat2str(P2_uj, 5));

% Abrazolas
figure; hold on; grid on; axis equal;
if numel(P1) == 3
    plot3([P1(1) P2(1)], [P1(2) P2(2)], [P1(3) P2(3)], 'k--');   % eredeti egyenes
    plot3(P1(1), P1(2), P1(3), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    plot3(P2(1), P2(2), P2(3), 'ro', 'MarkerSize', 10);
    plot3(P2_uj(1), P2_uj(2), P2_uj(3), 'gs', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    zlabel('z'); view(3);
else
    plot([P1(1) P2(1)], [P1(2) P2(2)], 'k--');
    plot(P1(1), P1(2), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
    plot(P2(1), P2(2), 'ro', 'MarkerSize', 10);
    plot(P2_uj(1), P2_uj(2), 'gs', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
end
xlabel('x'); ylabel('y');
legend('Egyenes', 'P1 (rogzitett)', 'P2 (eredeti)', 'P2 (uj)');
title('Pont mozgatasa az egyenes menten');