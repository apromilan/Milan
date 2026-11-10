function out = SpringDamper_Dyn(MR_in, c_in, SD)
%#codegen
% SPRINGDAMPER_DYN - a SpringDamper_Calc sarki (quarter-car) mennyiségei a PILLANATNYI mozgásra
%  BEMENET: MR_in [4x1] motion ratio (FL FR RL RR), c_in [4x1] damper-oldali c [N*s/m]
%  PARAMÉTER: SD struct (Bus: SD_Bus), a Simulation_Setup_GUI exportálja
%  KIMENET: out (Bus: SD_Out_Bus)
assert(numel(MR_in) == 4 && numel(c_in) == 4);

MR_MIN = 0.05;

persistent MR_last K_cache xi_cache A_cache
if isempty(MR_last)
    MR_last  = SD.MR_static(:);
    K_cache  = zeros(4, 1);
    xi_cache = zeros(4, 1);
    A_cache  = zeros(4, 1);
end

%% Bemenetek tisztítása
MR = zeros(4, 1);
c  = zeros(4, 1);
for i = 1:4
    if isfinite(MR_in(i)) && abs(MR_in(i)) >= MR_MIN
        MR_last(i) = abs(MR_in(i));
    end
    MR(i) = MR_last(i);
    if isfinite(c_in(i)) && c_in(i) > 0
        c(i) = c_in(i);
    end
end

%% Paraméterek
k  = SD.k_spring(:);
m1 = SD.m1(:);
m2 = SD.m2(:);
Kt = SD.K_tire;
f  = SD.f_vec(:);

%% Kerékmerevség, csillapítás, frekvenciák
K_wheel     = k ./ MR.^2;
K_wheel_eff = K_wheel + SD.K_heave(:) ./ (2 * SD.MR_arb(:).^2);
c_wheel     = c ./ MR.^2;
c_crit      = 2 * sqrt(K_wheel_eff .* m1);
c_crit_dmp  = c_crit .* MR.^2;
zeta        = c_wheel ./ c_crit;

f_ride      = sqrt(K_wheel_eff ./ m1) / (2*pi);
K_series    = K_wheel_eff * Kt ./ (K_wheel_eff + Kt);
f_ride_tyre = sqrt(K_series ./ m1) / (2*pi);
f_hop       = sqrt((K_wheel_eff + Kt) ./ m2) / (2*pi);
f_damped    = f_ride .* sqrt(max(1 - zeta.^2, 0));

%% A_RMS a pillanatnyi csillapítással
A_act = zeros(4, 1);
for i = 1:4
    A_act(i) = arms_for_c(c_wheel(i), K_wheel_eff(i), m1(i), m2(i), Kt, f);
end

%% Optimum (cache-elve)
xi_opt = NaN(4, 1);
A_opt  = NaN(4, 1);
c_opt  = NaN(4, 1);
A_pen  = NaN(4, 1);
if SD.opt_enable > 0
    for i = 1:4
        if K_cache(i) <= 0 || abs(K_wheel_eff(i) - K_cache(i)) > SD.opt_tol * K_cache(i)
            [xi_cache(i), A_cache(i)] = arms_optimum(K_wheel_eff(i), m1(i), m2(i), Kt, f, SD.xi_grid(:));
            K_cache(i) = K_wheel_eff(i);
        end
    end
    xi_opt = xi_cache;
    A_opt  = min(A_cache, A_act);
    c_opt  = xi_opt .* c_crit .* MR.^2;
    A_pen  = (A_act ./ A_opt - 1) * 100;
end

%% Tengelyszintű mennyiségek [első; hátsó]
K_heave_axle = [K_wheel_eff(1) + K_wheel_eff(2); K_wheel_eff(3) + K_wheel_eff(4)];
C_heave_axle = [c_wheel(1) + c_wheel(2); c_wheel(3) + c_wheel(4)];
f_ratio_RF   = mean(f_ride(3:4)) / mean(f_ride(1:2));

%% Kimenet
out.MR            = MR;
out.c_damper      = c;
out.K_wheel       = K_wheel;
out.K_wheel_eff   = K_wheel_eff;
out.c_wheel       = c_wheel;
out.c_crit        = c_crit;
out.c_crit_damper = c_crit_dmp;
out.zeta          = zeta;
out.f_ride        = f_ride;
out.f_ride_tyre   = f_ride_tyre;
out.f_hop         = f_hop;
out.f_damped      = f_damped;
out.A_RMS         = A_act;
out.A_RMS_opt     = A_opt;
out.A_RMS_pen     = A_pen;
out.xi_opt        = xi_opt;
out.c_opt         = c_opt;
out.K_heave_axle  = K_heave_axle;
out.C_heave_axle  = C_heave_axle;
out.f_ratio_RF    = f_ratio_RF;
end

function A = arms_for_c(cw, K, m1, m2, Kt, f)
w    = 2 * pi * f(:);
jwc  = 1i * w * cw;
A11  = K - m1 * w.^2 + jwc;
A22  = K + Kt - m2 * w.^2 + jwc;
A12  = -(K + jwc);
Z2   = A11 * Kt ./ (A11 .* A22 - A12.^2);
Af2  = abs(Kt * (Z2 - 1)).^2;
A    = sqrt(sum(diff(f(:)) .* (Af2(1:end-1) + Af2(2:end))) / 2 / (f(end) - f(1)));
end

function [xo, Ao] = arms_optimum(K, m1, m2, Kt, f, xg)
n  = numel(xg);
Av = zeros(n, 1);
cc = 2 * sqrt(K * m1);
for j = 1:n
    Av(j) = arms_for_c(xg(j) * cc, K, m1, m2, Kt, f);
end
[~, idx] = min(Av);
xo = xg(idx);
if idx > 1 && idx < n
    y1 = Av(idx - 1); y2 = Av(idx); y3 = Av(idx + 1);
    d2 = y3 - 2 * y2 + y1;
    if d2 > 0
        xo = xg(idx) - (xg(idx + 1) - xg(idx)) * (y3 - y1) / (2 * d2);
    end
end
Ao = arms_for_c(xo * cc, K, m1, m2, Kt, f);
end