@tool
class_name VehicleDefinition
extends Resource
enum DriverPolicy { SEATED, IDENTITY_ONLY, FIXED }
@export var id: StringName
@export var display_name := "New vehicle"
@export var model: PackedScene
@export var normalization := Transform3D.IDENTITY
@export var wheels: Array[WheelBinding] = []
@export var collision_size := Vector3(2.15,1.4,3.5)
@export var collision_position := Vector3(0,.78,0)
@export var max_speed := 33.0
## Metres/second. Zero retains the original arcade multiplier.
@export var boosted_speed := 0.0
@export var electric_boost := false
@export var braking_regeneration := 0.0
@export var ai_lateral_acceleration := 0.0
@export var acceleration := 18.0
@export var handling := 1.0
@export var camera_height := 0.0
@export var preview_target := Vector3(0,.9,0)
@export var preview_distance := 7.6
@export var exhausts := PackedVector3Array([Vector3(-.5,.47,2.05),Vector3(.5,.47,2.05)])
@export var driver_policy: DriverPolicy = DriverPolicy.SEATED
@export var seat := Transform3D.IDENTITY
@export var fixed_driver_id: StringName
@export var fixed_driver_model: PackedScene
## Optional pelvis-anchored fits keyed by driver identity.
@export var driver_fits: Dictionary = {}
@export var hovering := false
@export var preserve_materials := true
@export var thumbnail: Texture2D
@export var setup_complete := false
@export_multiline var attribution := ""

func problems() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("Stable ID is required")
	if not model: errors.append("Model is required")
	if driver_policy==DriverPolicy.FIXED and fixed_driver_id.is_empty(): errors.append("Fixed driver ID is required")
	if boosted_speed>0 and boosted_speed<max_speed: errors.append("Boost ceiling must be at least normal speed")
	if not setup_complete: errors.append("One-time orientation, wheels and seating setup is incomplete")
	if wheels.is_empty() and not hovering: errors.append("Bind wheels or explicitly enable hovering")
	for w in wheels:
		if w.rotating_groups.is_empty() or w.radius<=0 or w.axle.length()<.99: errors.append("Invalid wheel binding")
	return errors
