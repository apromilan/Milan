# FRT Simscape model architecture

Run `FRT_init` before opening or simulating any model:

```matlab
FRT = FRT_init;
```

The initializer publishes the complete `FRT` structure and the block-facing handles `FRT_geometry`, `FRT_suspension`, `FRT_collision`, `FRT_tire`, `FRT_forceApplication`, and `FRT_fullMotion` to the base workspace. The hard-point source remains `suspension_points_fred.xlsx`; all lengths are converted from millimetres to metres.

## Common subsystem contract

Each axle subsystem should have these masked or model-workspace parameters, all defaulting to the corresponding `FRT` field:

- `HardPoints`: axle hard-point structure.
- `WheelRadius`: `FRT.geometry.wheelRadius`.
- `Spring`: `FRT.suspension.front` or `FRT.suspension.rear`.
- `ForceApplication`: the relevant entry of `FRT.forceApplication`.
- `Visualization`: optional STEP geometry only; it must not define dynamics.

Use Simscape Multibody `World Frame`, `Mechanism Configuration`, `Solver Configuration`, `Rigid Transform`, `Revolute Joint`, `Spherical Joint`, `Universal Joint`, `Solid`, and `Rigid Transform` blocks. Use `Spatial Contact Force` for contact where the geometry can be represented by supported primitive surfaces. Use Simulink-PS Converters only at physical signal boundaries.

## Model 1: pure kinematics and collision check

Copy `half_vehicle_kinematics.slx` to `FRT_Model1_Kinematics.slx`. Keep the existing rigid suspension topology, but remove compliance elements and all bushing/free-play blocks.

1. Create `FrontAxle` and `RearAxle` subsystems. Each contains the hard-point rigid transforms, the upright, wheel, and the existing actuator inputs.
2. Drive wheel travel and steering with prescribed motion or simple external force blocks. Use ideal joints and rigid links only; do not add springs, dampers, bushings, or backlash.
3. Add `CollisionCheck` as a measurement subsystem. For each configured pair in `FRT.collision.pairs`, expose the two body segment endpoints from the axle subsystem.
4. Compute closest segment distance `d` and penetration `delta = max(0, clearance - d)` through the `FRT_collision_eval` and `FRT_collision_penalty` functions called by the Fcn blocks. Apply the configured penalty force only when `delta > 0`:

   `Fn = Kcollision*delta + Ccollision*max(0,-d(delta)/dt)`

   The force direction is the shortest-segment normal. Log `d`, `delta`, and `Fn` for every pair. If exact PDF section 4.2 uses a different distance primitive or sign convention, that MATLAB Function block is the single replacement point.
5. Route collision status to a Dashboard/To Workspace block and optionally stop the simulation when `stopAtFirstContact` is true.

This model answers: can the linkage travel through its intended range without collision? It does not represent deformation or joint clearance.

## Model 2: K&C with advanced forces

Copy `half_vehicle_KnC.slx` to `FRT_Model2_KnC.slx`.

1. Preserve the kinematic axle topology from Model 1.
2. Replace rigid joint connections at the specified interfaces with compliant bushings. Implement each bushing as three translational and three rotational spring-damper channels. Parameters come from `FRT.suspension.<axle>.compliance`.
3. Implement free-play as a dead-zone displacement before the bushing force is generated. For scalar displacement `x`, use:

   `xeff = sign(x)*max(abs(x)-freePlay,0)`

   `F = K*xeff + C*xdot`.

   For a six-degree-of-freedom bushing, apply the same rule component-wise with the translation and rotation tolerances from `FRT.suspension.<axle>.freePlay`.
4. Create `TireForces` as a masked subsystem with two 2-D Lookup Table blocks per wheel. Inputs are slip (or slip angle) and normal load. The maps are `FRT.tire.longitudinal.force` and `FRT.tire.lateral.force`; breakpoints are the matching fields in `FRT.tire.longitudinal` and `FRT.tire.lateral`. Set interpolation to `linear` and extrapolation to `clip`.
5. Apply longitudinal and lateral forces through separate `External Force and Torque` blocks. Set their application point to `FRT_forceApplication.<wheel>.longitudinal` and `.lateral`. Keep the point in the wheel/upright frame and use a `Rigid Transform` to place it; this makes the point adjustable without rewiring the model.
6. Log wheel-center forces, alignment changes, compliance deflection, and free-play engagement. Do not reuse Model 1 collision penalty forces as tire forces.

## Model 3: integrated full-motion model

Create `FRT_full_motion.slx` as a new top-level model with four physical subsystems: `Chassis`, `FrontAxle`, `RearAxle`, and `TireRoadInteraction`.

- `Chassis`: one `Solid` with `FRT.fullMotion.chassis.mass` and inertia, connected to a six-degree-of-freedom joint. Add gravity and aerodynamic force inputs.
- `Heave`: connect the chassis vertical coordinate to a prescribed base/lift input or a force actuator. Use front and rear suspension spring-damper force paths; expose travel limits from the suspension data.
- `FrontSteering`: add a rack or revolute steering actuator only inside `FrontAxle`. Map rack displacement to left/right wheel steer using `FRT.fullMotion.steering.rackRatio`; enforce `maxAngle` and `maxRate`. The rear axle has no steering actuator and remains kinematically fixed in yaw.
- `Roll`: use a chassis roll revolute coordinate or an equivalent roll joint about the vehicle longitudinal axis. Apply the roll restoring and damping torque from `FRT.fullMotion.roll.rollStiffness` and `.rollDamping`; tire lateral forces and left/right suspension reactions generate the external roll moment.
- `TireRoadInteraction`: calculate normal load from contact, then evaluate the same LUTs as Model 2. Apply forces at the configurable points in `FRT_forceApplication`.
- Add sensors for chassis heave, roll angle/rate, steering angle, each wheel travel, normal load, and lateral tire force. Log them in `logsout` with stable signal names.

## Build order and checks

1. Run `FRT_init` and verify `FRT.geometry.front` and `FRT.geometry.rear` contain the expected hard-point fields.
2. Build and validate Model 1 first. Check zero compliance deflection and collision distance at static pose.
3. Enable Model 2 compliance and verify free-play produces zero reaction inside its dead zone, then a continuous spring-damper reaction outside it.
4. Validate each LUT independently with a unit test or a one-wheel test harness before connecting all four wheels.
5. Build Model 3 last. Start with heave only, then add front steering, then roll coupling.
6. Use `Mechanism Configuration` and `Solver Configuration` once per physical network. Avoid duplicate solver blocks inside subsystems.

The two binary reference models are populated by `FRT_build_models` when their root scope is empty. The generated first pass is a parameterized signal-level harness; the physical Multibody bodies and joints should then be inserted into `KinematicsCore` and `KnCCore` using the matching blocks from `testrig_susp_knc.slx` and the quarter-car testrigs. This keeps the binary template topology available as the authoritative Simscape reference.
