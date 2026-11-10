function out = SpringDamper_DynQ(MR_in, c_in, SD, corner)
%#codegen
% Egy sarok: corner = 1 FL, 2 FR, 3 RL, 4 RR. MR_in, c_in skalár.
MR_MIN = 0.05;
idx = round(corner);

persistent MR_last K_cache xi_cache A_cache
if isempty(MR_last)
    MR_last  = SD.MR_static(idx);
    K_cache  = 0;
    xi_cache = 0;
    A_cache  = 0;
end

if isfinite(MR_in) && abs(MR_in) >= MR_MIN
    MR_last = abs(MR_in);
end
MR = MR_last;
c = 0;
if isfinite(c_in) && c_in > 0
    c = c_in;
end

k  = SD.k_spring(idx);
m1 = SD.m1(idx);
m2 = SD.m2(idx);
Kt = SD.K_tire;
f  = SD.f_vec(:);

K_wheel     = k / MR^2;
K_wheel_eff = K_wheel + SD.K_heave(idx) / (2 * SD.MR_arb(idx)^2);
c_wheel     = c / MR^2;
c_crit      = 2 * sqrt(K_wheel_eff * m1);
zeta        = c_wheel / c_crit;

f_ride      = sqrt(K_wheel_eff / m1) / (2*pi);
K_series    = K_wheel_eff * Kt / (K_wheel_eff + Kt);
f_ride_tyre = sqrt(K_series / m1) / (2*pi);
f_hop       = sqrt((K_wheel_eff + Kt) / m2) / (2*pi);
f_damped    = f_ride * sqrt(max(1 - zeta^2, 0));

A_act = arms_for_c(c_wheel, K_wheel_eff, m1, m2, Kt, f);

xi_opt = NaN; A_opt = NaN; c_opt = NaN; A_pen = NaN;
if SD.opt_enable > 0
    if K_cache <= 0 || abs(K_wheel_eff - K_cache) > SD.opt_tol * K_cache
        [xi_cache, A_cache] = arms_optimum(K_wheel_eff, m1, m2, Kt, f, SD.xi_grid(:));
        K_cache = K_wheel_eff;
    end
    xi_opt = xi_cache;
    A_opt  = min(A_cache, A_act);
    c_opt  = xi_opt * c_crit * MR^2;
    A_pen  = (A_act / A_opt - 1) * 100;
end

out.MR            = MR;
out.c_damper      = c;
out.K_wheel       = K_wheel;
out.K_wheel_eff   = K_wheel_eff;
out.c_wheel       = c_wheel;
out.c_crit        = c_crit;
out.c_crit_damper = c_crit * MR^2;
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