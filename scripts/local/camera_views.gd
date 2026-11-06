class_name LeoCameraViews
extends RefCounted
const NAMES := {"chase":"Chase","ghost":"Ghost","cockpit":"Cockpit"}
const BODY_BITS := [1<<14,1<<15]
const DRIVER_BITS := [1<<12,1<<13]
static var profiles: Dictionary={}

static func profile(vehicle: VehicleDefinition) -> Dictionary:
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/camera-views-v1.json"))
	var data: Dictionary=profiles.get(String(vehicle.id),{}) if vehicle.official else {}
	if data.is_empty():data=vehicle.camera_views
	var eye: Variant=data.get("eye",[])
	if not data.get("cockpit",false) or not LeoVehicleCodec.finite_vector(eye):return {}
	var angles: Variant=data.get("rotation_degrees",[0,0,0])
	if not LeoVehicleCodec.finite_vector(angles):return {}
	for angle in angles:
		if absf(float(angle))>360.:return {}
	var position:=LeoVehicleCodec.vector(eye)
	if not position.is_finite() or position.length()>10.:return {}
	return data

static func available(vehicle: VehicleDefinition) -> Array[String]:
	var result: Array[String]=["chase","ghost"]
	if not profile(vehicle).is_empty():result.append("cockpit")
	return result

static func effective(local: LeoLocalPlayer) -> String:
	if not is_instance_valid(local.kart):return "chase"
	return local.camera_view if local.camera_view in available(local.kart.definition) else "chase"

static func cycle(local: LeoLocalPlayer) -> void:
	if not is_instance_valid(local.kart):return
	var choices:=available(local.kart.definition)
	local.camera_view=choices[(choices.find(effective(local))+1)%choices.size()]
	local.camera_rig.reset()
	local.camera_transition=.16

static func tag(kart: LeoKart) -> void:
	if not kart.is_player or kart.local_slot not in [0,1]:return
	if not profile(kart.definition).is_empty():
		var cabin:=OmniLight3D.new();cabin.name="CockpitReadabilityLight";cabin.position=Vector3(-.35,1.25,.15)
		cabin.omni_range=1.8;cabin.light_energy=.4;cabin.light_color=Color("dce9ff");cabin.shadow_enabled=false
		cabin.light_cull_mask=BODY_BITS[kart.local_slot];cabin.visible=false;kart.visual.add_child(cabin)
	# Dedicated render layers change visibility only; physics remains shared.
	for node in kart.visual.find_children("*","GeometryInstance3D",true,false):
		if node.is_set_as_top_level():continue
		var original: int=node.layers
		var driver:=is_instance_valid(kart.driver) and (kart.driver==node or kart.driver.is_ancestor_of(node))
		node.layers=(original & (1<<16)) | (DRIVER_BITS[kart.local_slot] if driver else BODY_BITS[kart.local_slot])
		node.set_meta("camera_source_layers",original)
	LeoCockpitSystems.install(kart)

static func visibility(local: LeoLocalPlayer) -> void:
	var mode:=effective(local)
	var mask: int=local.camera.cull_mask | BODY_BITS[local.slot] | DRIVER_BITS[local.slot] | LeoCockpitSystems.MIRROR_BITS[0] | LeoCockpitSystems.MIRROR_BITS[1]
	if mode=="ghost":mask&=~(BODY_BITS[local.slot]|DRIVER_BITS[local.slot]|LeoCockpitSystems.MIRROR_BITS[local.slot])
	elif mode=="cockpit":mask&=~DRIVER_BITS[local.slot]
	var cabin:=local.kart.visual.get_node_or_null("CockpitReadabilityLight")
	if cabin:cabin.visible=mode=="cockpit"
	local.camera.cull_mask=mask & ~(1<<16) # Lighting receiver layer is never a visibility bypass.
