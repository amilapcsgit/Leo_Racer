@tool
class_name VehicleDefinition
extends Resource
enum DriverPolicy { SEATED, IDENTITY_ONLY, FIXED, CABIN }
@export var id: StringName
@export var display_name := "New vehicle"
@export var model_path := ""
@export var preview_scene := ""
@export var compiled_bounds: Dictionary = {}
@export var estimated_bytes := 0
@export var fixed_driver_model_path := ""
@export var model: PackedScene:
	get:
		return model if model else LeoAssets.scene(model_path)
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
@export var fixed_driver_model: PackedScene:
	get:
		return fixed_driver_model if fixed_driver_model else (LeoAssets.scene(fixed_driver_model_path) if not fixed_driver_model_path.is_empty() else null)
## Optional pelvis-anchored fits keyed by driver identity.
@export var driver_fits: Dictionary = {}
@export var hovering := false
@export var preserve_materials := true
@export var visual_profile := ""
@export var lighting: Array = []
@export var actions: Array = []
@export var thumbnail: Texture2D:
	get:
		return thumbnail if thumbnail else (LeoAssets.texture(thumbnail_path) if not thumbnail_path.is_empty() else null)
@export var setup_complete := false
@export_multiline var attribution := ""
var content_folder := ""
var content_data: Dictionary = {}
var official := true
var thumbnail_path := ""

func boost_emitters() -> PackedVector3Array:
	# Imported electric cars still need visible arcade boost without exhaust pipes.
	# Derive positions in vehicle coordinates; normalization is already reflected
	# in collision dimensions, so the model's scale must not be applied again.
	if not exhausts.is_empty() or (official and id!=&"duster_2024"):return exhausts
	var half_width:=collision_size.x*.28
	var height:=maxf(.25,collision_position.y-collision_size.y*.25)
	var rear:=collision_position.z+collision_size.z*.5+.12
	return PackedVector3Array([Vector3(collision_position.x-half_width,height,rear),Vector3(collision_position.x+half_width,height,rear)])

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
