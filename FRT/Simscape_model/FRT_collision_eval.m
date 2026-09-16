function [distance, penetration, force] = FRT_collision_eval(segmentA, segmentB, clearance, radius, stiffness, damping)
%FRT_COLLISION_EVAL Evaluate a conservative segment collision penalty.
if numel(segmentA) < 6 || numel(segmentB) < 6
    segmentA = [segmentA(:); zeros(6 - numel(segmentA), 1)];
    segmentB = [segmentB(:); zeros(6 - numel(segmentB), 1)];
end
segmentA = reshape(segmentA, 3, []);
segmentB = reshape(segmentB, 3, []);
if size(segmentA, 2) ~= 2 || size(segmentB, 2) ~= 2
    error('FRT:collision:SegmentShape', 'Each segment must contain two 3-D endpoints.');
end
[distance, pointA, pointB] = localSegmentDistance(segmentA, segmentB);
penetration = max(0, clearance + radius - distance);
if distance > 0
    normal = (pointA - pointB) / distance;
else
    normal = [0; 0; 1];
end
force = stiffness * penetration * normal;
if nargin >= 6 && damping > 0
    force = force;
end
end

function [distance, pointA, pointB] = localSegmentDistance(segmentA, segmentB)
a = segmentA(:, 1);
b = segmentA(:, 2);
c = segmentB(:, 1);
d = segmentB(:, 2);
u = b - a;
v = d - c;
w = a - c;
aa = dot(u, u);
bb = dot(u, v);
cc = dot(v, v);
dd = dot(u, w);
ee = dot(v, w);
determinant = aa * cc - bb * bb;
if aa == 0 && cc == 0
    pointA = a;
    pointB = c;
elseif aa == 0
    parameterB = min(max(ee / cc, 0), 1);
    pointA = a;
    pointB = c + parameterB * v;
elseif cc == 0
    parameterA = min(max(-dd / aa, 0), 1);
    pointA = a + parameterA * u;
elseif determinant < eps
    parameterA = 0;
    parameterB = min(max(ee / cc, 0), 1);
    pointA = a;
    pointB = c + parameterB * v;
else
    parameterA = (bb * ee - cc * dd) / determinant;
    parameterB = (aa * ee - bb * dd) / determinant;
    parameterA = min(max(parameterA, 0), 1);
    parameterB = min(max((bb * parameterA + ee) / cc, 0), 1);
    parameterA = min(max((bb * parameterB - dd) / aa, 0), 1);
    pointA = a + parameterA * u;
    pointB = c + parameterB * v;
end
distance = norm(pointA - pointB);
end
