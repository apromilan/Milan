function reaction = FRT_compliance_eval(displacement, velocity, translationFreePlay, stiffness, damping)
%FRT_COMPLIANCE_EVAL Apply component-wise free-play and spring-damper reaction.
effectiveDisplacement = sign(displacement) .* max(abs(displacement) - translationFreePlay, 0);
reaction = stiffness .* effectiveDisplacement + damping .* velocity;
end
