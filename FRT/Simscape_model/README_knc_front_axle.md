# Elso futomu K&C es compliance modell

## Fajlok

- `Testrig/Kinematics/Kinematics_Front_Axle.slx`: ketpont-szimmetrikus K&C parancsinterfesz.
- `Testrig/Kinematics/Compliance_Front_Axle.slx`: ugyanez kulso ero/nyomatek es freeplay-compliance aktualassal.
- `build_knc_front_axle_models.m`: a ket modell ujraepitese.

Mindket modell bemenete `Cmd_Jounce`, `Cmd_Steer`, `Cmd_Camber`. A `TwoPoint_Interface`
bal oldali parancsa `[jounce, steer, camber]`, a jobb oldali parancsa
`[jounce, -steer, -camber]`. A `Collision_Check` kimenetei: `Min_Clearance`,
`Contact_Flag`, `First_Contact_Time`.

## Hasznalat

MATLAB-ban a projekt gyokerbol:

```matlab
knc_front_axle_init
[normalOut, normal] = run_knc_front_axle('normal');
[combinedOut, combined] = run_knc_front_axle('combined');
[freeplayOut, freeplay] = run_compliance_front_axle('freeplay');
```

A compliance modell tovabbi bemenetei `Load_Force` es `Load_Torque` (3 elemu,
SI egyseges vektorok). A freeplay torveny parameterei:
`Freeplay_Threshold`, `Freeplay_Stiffness`, `Freeplay_Damping`.
