function force = FRT_collision_penalty(distance, clearance, radius, stiffness)
%FRT_COLLISION_PENALTY Convert clearance violation into a scalar penalty.
force = stiffness * max(0, clearance + radius - distance);
end
