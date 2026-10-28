class_name LeoVehicleFeatures
extends Node3D
## Declarative, per-instance vehicle lamps and cosmetic actions. No content scripts.
var brake_materials: Array[StandardMaterial3D] = []
var headlights: Array[SpotLight3D] = []
var tail_lights: Array[OmniLight3D] = []
var groups: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var diagnostics: PackedStringArray = []
var braking := false
var reversing := false
var headlights_on := true

static func install(body: Node3D, definition: VehicleDefinition) -> Node3D:
	var lamps: Array = definition.lighting
	if lamps.is_empty() and definition.visual_profile == "bigster_pbr_v1":lamps = legacy_lamps(body)
	if lamps.is_empty() and definition.actions.is_empty():return null
	var controller := LeoVehicleFeatures.new()
	controller.name = "VehicleLighting"
	body.add_child(controller)
	controller.configure(body, lamps, definition.actions)
	return controller

static func legacy_lamps(body: Node3D) -> Array:
	var result: Array = []
	for node in body.find_children("*", "MeshInstance3D", true, false):
		if not (String(node.name).contains("headlight") or String(node.name).contains("taillight") or String(node.name).contains("chmsl")):continue
		for i in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(i)
			if not material:continue
			var role := "head" if material.resource_name.begins_with("Lamp_Head_") else "brake" if material.resource_name.begins_with("Lamp_TailBrake_") else ""
			if role.is_empty():continue
			result.append({"role":role,"targets":[{"node":String(body.get_path_to(node)),"material":material.resource_name}]})
	for side in [-1., 1.]:
		result.append({"role":"head","anchor":[side*.64,.91,-2.09],"range":26.,"energy":2.2})
		result.append({"role":"brake","anchor":[side*.77,1.05,2.19],"range":1.35,"energy":.8})
	return result

static func local_pose(node: Node3D, root: Node3D) -> Transform3D:
	var pose := node.transform
	var parent := node.get_parent()
	while parent is Node3D and parent != root:
		pose = parent.transform * pose
		parent = parent.get_parent()
	return pose

func configure(body: Node3D, lamps: Array, authored_actions: Array) -> void:
	for entry in lamps:
		var materials: Array[StandardMaterial3D] = []
		var valid := true
		for target in entry.get("targets", []):
			var node := body.get_node_or_null(NodePath(target.node)) as MeshInstance3D
			var found := false
			if node and node.mesh:
				for i in node.mesh.get_surface_count():
					var old := node.get_active_material(i) as StandardMaterial3D
					if old and old.resource_name == target.material:
						# Deliberately separate surfaces even when the source shares materials.
						var material := old.duplicate() as StandardMaterial3D
						node.set_surface_override_material(i, material)
						materials.append(material);found = true
			if not found:valid = false;diagnostics.append("Missing lamp target: " + String(target.node) + " / " + String(target.material))
		if not valid:continue
		var role: String = entry.role
		var color := Color(.86,.94,1.) if role in ["head","reverse"] else Color(1.,.008,.012)
		for material in materials:
			material.emission_enabled = true;material.emission = color
			if role == "brake":brake_materials.append(material)
		var light: Light3D
		if entry.has("anchor"):
			light = SpotLight3D.new() if role == "head" else OmniLight3D.new()
			light.position = LeoVehicleCodec.vector(entry.anchor)
			light.light_color = color;light.shadow_enabled = false
			light.distance_fade_enabled = true;light.distance_fade_begin = 35.;light.distance_fade_length = 15.
			if light is SpotLight3D:
				light.rotation_degrees = LeoVehicleCodec.vector(entry.get("rotation",[-5,0,0]))
				light.spot_range = float(entry.get("range",26.));light.spot_angle = 32.
				headlights.append(light)
			else:
				light.omni_range = float(entry.get("range",2.))
				if role in ["tail","brake"]:tail_lights.append(light)
			add_child(light)
		groups.append({"role":role,"materials":materials,"light":light,"running":bool(entry.get("running",true)),"energy":float(entry.get("energy",2.2 if role=="head" else .8))})
	for entry in authored_actions:
		var state: Dictionary = {"definition":entry.duplicate(true),"progress":0.,"open":false,"targets":[],"player":null}
		var valid := true
		if entry.get("type","transform") == "animation":
			var player := body.get_node_or_null(NodePath(entry.player)) as AnimationPlayer
			if not player or not player.has_animation(entry.clip):valid = false
			else:
				# Manual sampling prevents a shared/imported autoplay from owning this action.
				player.stop();state.player = player
		else:
			for target in entry.get("targets",[]):
				var node := body.get_node_or_null(NodePath(target.node)) as Node3D
				if not node:valid = false;continue
				state.targets.append({"node":node,"base":node.transform,"data":target})
		if valid:actions.append(state)
		else:diagnostics.append("Missing action target: " + String(entry.get("name","Vehicle action")))
	update_state(false)
	for message in diagnostics:push_warning(message)

var projected_headlights_allowed:=true
func set_headlight_projection(allowed: bool) -> void:
	if projected_headlights_allowed==allowed:return
	projected_headlights_allowed=allowed;update_state(braking,reversing)
func update_state(is_braking: bool, is_reversing: bool = false) -> void:
	braking = is_braking;reversing = is_reversing
	for group in groups:
		var strength := 0.
		match group.role:
			"head":strength = 3. if headlights_on else 0.
			"tail":strength = .45 if headlights_on else 0.
			"brake":strength = 3.5 if braking else (.45 if headlights_on and group.running else 0.)
			"reverse":strength = 3.5 if reversing else 0.
		for material in group.materials:
			material.emission_energy_multiplier = strength
			# Lens colour remains readable without bloom in Compatibility.
			material.albedo_color = Color(.8,.86,.92) if group.role=="reverse" else material.albedo_color
		if group.light:
			group.light.light_energy = group.energy * strength / (3. if group.role=="head" else 3.5)
			group.light.visible = strength > 0. and (group.role!="head" or projected_headlights_allowed)

func toggle_headlights() -> void:
	headlights_on = not headlights_on;update_state(braking,reversing)

func trigger(slot: int) -> bool:
	for state in actions:
		if int(state.definition.slot)==slot:state.open = not state.open;return true
	return false

func action_name(slot: int) -> String:
	for state in actions:
		if int(state.definition.slot)==slot:return String(state.definition.name)
	return "Unassigned"

func _process(dt: float) -> void:
	for state in actions:
		state.progress = move_toward(float(state.progress),1. if state.open else 0.,dt/float(state.definition.get("duration",1.2)))
		var t: float = smoothstep(0.,1.,float(state.progress))
		if state.player:
			var player: AnimationPlayer = state.player
			player.play(state.definition.clip);player.seek(t*player.get_animation(state.definition.clip).length,true);player.pause()
		else:
			for target in state.targets:
				var data: Dictionary = target.data
				var closed := Transform3D(Basis.from_euler(LeoVehicleCodec.vector(data.get("closed_rotation",[0,0,0]))*PI/180.),LeoVehicleCodec.vector(data.get("closed_position",[0,0,0])))
				var opened := Transform3D(Basis.from_euler(LeoVehicleCodec.vector(data.get("open_rotation",[0,0,0]))*PI/180.),LeoVehicleCodec.vector(data.get("open_position",[0,0,0])))
				target.node.transform = target.base * closed.interpolate_with(opened,t)

static func driving_state(speed: float, accelerator: float, brake: float, active: bool, ai: bool = false, ai_target: float = 0.) -> Vector2:
	if not active:return Vector2.ZERO
	var reversing_now := speed < -.25
	var brake_now := (brake>.1 and not reversing_now) or (accelerator>.1 and reversing_now)
	if ai:brake_now = speed>.5 and ai_target<speed-.5
	return Vector2(float(brake_now),float(reversing_now and (brake>.1 or accelerator>.1)))
