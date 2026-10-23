class_name LeoKart
extends CharacterBody3D

# The steering response, visual lean, wheel animation and speed-driven engine
# audio extend Kenney's MIT Racing Starter Kit. A constrained CharacterBody
# replaces its sphere to make barrier contact and race recovery deterministic.
signal gate_crossed(kart, gate)
signal boosted(kart, source)
signal drift_changed(kart, enabled)
signal impacted(kart, point, normal, strength)
signal recovered(kart)
var circuit: LeoCircuit
var racer_id := 0
var racer_name := "Sonic"
var is_player := false
var control_input: LeoPlayerInput
var local_slot := -1
var retired := false
var race_boost_ceiling := 0.
var race_ai_lateral_acceleration := -1.
var active := false
var finished := false
var finish_time := 0.0
var progress := -10.0
var next_gate := 0
var lap := 1
var nearest_index := -1
var last_s := 0.0
var speed := 0.0
var max_speed := 33.0
var acceleration := 18.0
var handling := 1.0
var steer := 0.0
var drift_charge := 0.0
var drifting := false
var boost_time := 0.0
var boost_cooldown := 0.0
var boost_fuel := 1.0
var drift_direction := 0.0
var air_hop := 0.0
var visual: Node3D
var chassis: Node3D
var driver: Node3D
var wheels: Array[Node3D] = []
var wheel_steering_pivots: Array[Node3D] = []
var wheel_spin_pivots: Array[Node3D] = []
var wheel_roll := 0.0
var wheel_motion_speed := 0.0
var wheel_visual_speed := 0.0
var flames: Array[MeshInstance3D] = []
var exhaust_trails: Array[GPUParticles3D] = []
var effect_clock := 0.0
var spark_left: GPUParticles3D
var spark_right: GPUParticles3D
var tire_sparks: Array[GPUParticles3D] = []
var engine: AudioStreamPlayer
var skid: AudioStreamPlayer
var boost_sound: AudioStreamPlayer
var impact: AudioStreamPlayer
var ai_lane := 0.0
var ai_phase := 0.0
var auto_drive := false
var bump_cooldown := 0.0
var effects: LeoKartEffects
var impact_feedback_cooldown := 0.0
var vehicle_key := "blue"
var wheel_radius := .49
var exhaust_positions: Array[Vector3] = []
var rear_tire_positions: Array[Vector3] = []
var camera_height_offset := 0.0
var engine_pitch := 1.0
var stuck_time := 0.0
var definition: VehicleDefinition
var wheel_radii: Array[float] = []
var wheel_axes: Array[Vector3] = []
var wheel_angles: Array[float] = []

static func chassis_path(key: String) -> String:
	return GarageCatalog.shared().vehicle(key).model.resource_path

static func driver_path(key: String) -> String:
	return GarageCatalog.shared().driver(key).seated_model.resource_path

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func vehicle_spec(key: String) -> Dictionary:
	var v := GarageCatalog.shared().vehicle(key)
	return {"driver_position":[v.seat.origin.x,v.seat.origin.y,v.seat.origin.z],"driver_scale":[v.seat.basis.get_scale().x,v.seat.basis.get_scale().y,v.seat.basis.get_scale().z],"collision_size":[v.collision_size.x,v.collision_size.y,v.collision_size.z],"collision_position":[v.collision_position.x,v.collision_position.y,v.collision_position.z],"wheel_radius":v.wheels[0].radius if not v.wheels.is_empty() else .49,"exhausts":v.exhausts}

static func seat_driver(model: Node3D,key: String) -> void:
	model.transform = GarageCatalog.shared().vehicle(key).seat * model.transform

func setup(track: LeoCircuit, id: int, player: bool, animal: String, kart_color: String) -> void:
	circuit = track
	racer_id = id
	is_player = player
	vehicle_key = kart_color
	definition = GarageCatalog.shared().vehicle(kart_color)
	max_speed = definition.max_speed
	acceleration = definition.acceleration
	handling = definition.handling
	wheel_radius = definition.wheels[0].radius if not definition.wheels.is_empty() else .49
	camera_height_offset = definition.camera_height
	engine_pitch = .65 if kart_color=="race_bus" else (1.22 if kart_color in ["race_tuk","colombo_tuk"] else (1.12 if kart_color.begins_with("formula") else 1.0))
	for p in definition.exhausts: exhaust_positions.append(p)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	visual = VehicleAssembler.assemble(definition,GarageCatalog.shared().driver(animal))
	add_child(visual)
	chassis = visual.get_node("Chassis")
	driver = visual.get_node_or_null("Driver")
	for binding in definition.wheels:
		if not binding.steering: rear_tire_positions.append(chassis.transform * binding.pivot)
		attach_binding(binding)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = definition.collision_size
	collision.shape = shape
	collision.position = definition.collision_position
	add_child(collision)
	collision_layer = 2
	collision_mask = 1 | 2
	floor_snap_length = .5
	for exhaust_index in exhaust_positions.size():
		var f := MeshInstance3D.new()
		f.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var m := SphereMesh.new()
		m.radius = .18
		m.height = .8
		m.radial_segments = 16
		m.rings = 8
		f.mesh = m
		f.rotation.x = PI / 2
		f.position = exhaust_positions[exhaust_index]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("47edff")
		material.emission_enabled = true
		material.emission = Color("28b9ff")
		material.emission_energy_multiplier = 4.0
		f.material_override = material
		visual.add_child(f)
		flames.append(f)
		var core := MeshInstance3D.new()
		core.mesh = m
		core.scale = Vector3(.5, .84, .5)
		var core_material := material.duplicate() as StandardMaterial3D
		core_material.albedo_color = Color("e5ffff")
		core_material.emission = Color("baffff")
		core.material_override = core_material
		f.add_child(core)
		exhaust_trails.append(make_particles(exhaust_positions[exhaust_index], true))
	for i in rear_tire_positions.size():
		var tire := rear_tire_positions[i]
		var sparks := make_particles(Vector3(tire.x,.2,tire.z))
		tire_sparks.append(sparks)
		if i == 0: spark_left = sparks
		elif i == 1: spark_right = sparks
	if is_player:
		engine = sound("engine.ogg", -22, true)
		skid = sound("skid.ogg", -50, true)
		boost_sound = sound("boost.wav", -12, false)
		impact = sound("impact.ogg", -14, false)
	ai_phase = float(id) * 1.73
	ai_lane = [-3.8, 0.0, 3.8, -2.5, 2.5, 0.5][id % 6]
	effects = LeoKartEffects.new()
	visual.add_child(effects)
	effects.setup(self)
	reset_physics_interpolation()

func attach_binding(binding: WheelBinding) -> void:
	var steering_pivot := Node3D.new()
	steering_pivot.name = "WheelSteering"+str(wheels.size())
	steering_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	chassis.add_child(steering_pivot)
	steering_pivot.position = binding.pivot
	steering_pivot.set_meta("front",binding.steering)
	var spin_pivot := Node3D.new()
	spin_pivot.name = "WheelRolling"
	steering_pivot.add_child(spin_pivot)
	var first: Node3D
	for path in binding.rotating_groups:
		var group := VehicleAssembler.find_group(chassis,path)
		if not group: push_error("Unresolved wheel binding: "+String(path)); continue
		if not first: first=group
		group.reparent(spin_pivot,true)
	for path in binding.stationary_groups:
		var group := VehicleAssembler.find_group(chassis,path)
		if group: group.reparent(steering_pivot,true)
	wheels.append(first)
	wheel_steering_pivots.append(steering_pivot)
	wheel_spin_pivots.append(spin_pivot)
	wheel_radii.append(binding.radius)
	wheel_axes.append(binding.axle.normalized())
	wheel_angles.append(0.)

func animate_wheels(dt: float) -> void:
	# Rebuild from a bounded angle, avoiding accumulated basis drift and the
	# Euler decomposition discontinuities that made the front tires wobble.
	# Integrate the filtered speed analytically so rolling is consistent at
	# different render rates, including when a collision stops the chassis.
	var decay := exp(-28.0 * dt)
	var travel := wheel_motion_speed * dt + (wheel_visual_speed - wheel_motion_speed) * (1.0 - decay) / 28.0
	wheel_visual_speed = wheel_motion_speed + (wheel_visual_speed - wheel_motion_speed) * decay
	if absf(wheel_visual_speed) < .005 and absf(wheel_motion_speed) < .005:
		wheel_visual_speed = 0
	wheel_roll = wrapf(wheel_roll - travel / wheel_radius, -PI, PI)
	for i in wheel_spin_pivots.size():
		var steering_pivot := wheel_steering_pivots[i]
		steering_pivot.basis = Basis(Vector3.UP, -steer * .35 if steering_pivot.get_meta("front") else 0.0)
		wheel_angles[i] = wrapf(wheel_angles[i] - travel / wheel_radii[i], -PI, PI)
		wheel_spin_pivots[i].basis = Basis(wheel_axes[i], wheel_angles[i])

func update_wheel_motion(movement: Vector3, dt: float) -> void:
	# Include the final soft-barrier correction as well as move_and_slide.
	# Commanded speed remains high while pushing a wall and cannot drive rims.
	var forward := -global_basis.z
	forward.y = 0
	wheel_motion_speed = clampf(movement.dot(forward.normalized()) / maxf(dt, .00001), -max_speed * 1.6, max_speed * 1.6)
	if absf(wheel_motion_speed) < .025: wheel_motion_speed = 0

func sound(file: String, volume: float, playing: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/" + file)
	if playing and p.stream is AudioStreamOggVorbis:
		(p.stream as AudioStreamOggVorbis).loop = true
	p.volume_db = volume
	add_child(p)
	if playing: p.play()
	return p

func stop_audio() -> void:
	for child in get_children():
		if child is AudioStreamPlayer: child.stop()

func make_particles(p: Vector3, exhaust := false) -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.position = p
	fx.amount = 40 if exhaust else 30
	fx.lifetime = .34 if exhaust else .4
	fx.local_coords = false
	fx.visibility_aabb = AABB(Vector3(-8, -3, -10), Vector3(16, 12, 24))
	fx.emitting = false
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, .05 if exhaust else .5, 1)
	material.spread = 12 if exhaust else 32
	material.initial_velocity_min = 5 if exhaust else 2
	material.initial_velocity_max = 9 if exhaust else 5
	material.gravity = Vector3.ZERO if exhaust else Vector3(0, -3, 0)
	material.scale_min = .5
	material.scale_max = 1.25
	var gradient := Gradient.new()
	gradient.set_color(0, Color("bdffff") if exhaust else Color("fff9bb"))
	gradient.set_color(1, Color(0.08, .4, 1, 0) if exhaust else Color(1, .3, .02, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	fx.process_material = material
	var mesh := SphereMesh.new()
	mesh.radius = .08 if exhaust else .065
	mesh.height = .16 if exhaust else .13
	mesh.radial_segments = 6
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color("19c8ff") if exhaust else Color("ffb61e")
	mat.emission_energy_multiplier = 2.4
	mesh.material = mat
	fx.draw_pass_1 = mesh
	visual.add_child(fx)
	return fx

func place(distance: float, lane: float) -> void:
	position = circuit.sample(distance, lane) + Vector3.UP * .12
	var t := circuit.direction(distance)
	rotation.y = atan2(-t.x, -t.z)
	progress = distance
	last_s = fposmod(distance, circuit.length)
	nearest_index = int(last_s / circuit.step)
	velocity = Vector3.ZERO
	speed = 0
	stuck_time = 0
	wheel_motion_speed = 0
	wheel_visual_speed = 0
	reset_physics_interpolation()

func recover() -> void:
	var safe := maxf(0, (next_gate - 1) * circuit.length / LeoCircuit.GATES) + 2.0
	var lane := (-3.2 if local_slot==0 else 3.2) if local_slot>=0 else (0.0 if is_player else ai_lane)
	var chosen := circuit.sample(safe,lane)+Vector3.UP*.2
	if is_inside_tree() and definition:
		var query:=PhysicsShapeQueryParameters3D.new()
		var recovery_shape:=BoxShape3D.new();recovery_shape.size=definition.collision_size
		query.shape=recovery_shape;query.collision_mask=2;query.exclude=[get_rid()]
		var found:=false
		for setback in [0.,3.,6.]:
			for candidate in [lane,-lane,0.,-5.5,5.5]:
				var point:=circuit.sample(safe-setback,candidate)+Vector3.UP*.2
				var facing:=circuit.direction(safe-setback)
				var basis:=Basis(Vector3.UP,atan2(-facing.x,-facing.z))
				query.transform=Transform3D(basis,point+basis*definition.collision_position)
				if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
					chosen=point;safe-=setback;found=true;break
			if found:break
		if not found:return
	position = chosen
	var t := circuit.direction(safe)
	rotation.y = atan2(-t.x, -t.z)
	progress = safe
	last_s = fposmod(safe, circuit.length)
	nearest_index = int(last_s / circuit.step)
	velocity = Vector3.ZERO
	speed = 0
	stuck_time = 0
	drifting = false
	drift_charge = 0
	boost_time = 0
	steer = 0
	visual.rotation = Vector3.ZERO
	wheel_motion_speed = 0
	wheel_visual_speed = 0
	reset_physics_interpolation()
	recovered.emit(self)

func boost(duration: float, source: String) -> void:
	boost_time = maxf(boost_time, duration)
	boosted.emit(self, source)
	if is_player and boost_sound: boost_sound.play()

func boosted_ceiling() -> float:
	if race_boost_ceiling>0:return race_boost_ceiling
	return definition.boosted_speed*(max_speed/definition.max_speed) if definition and definition.boosted_speed>0 else max_speed*1.4

func _physics_process(dt: float) -> void:
	if not circuit: return
	boost_time = maxf(0, boost_time - dt)
	boost_cooldown = maxf(0, boost_cooldown - dt)
	bump_cooldown = maxf(0, bump_cooldown - dt)
	impact_feedback_cooldown = maxf(0,impact_feedback_cooldown-dt)
	var throttle := 0.0
	var desired_steer := 0.0
	var want_drift := false
	var ai_speed := max_speed
	if active:
		if is_player and not auto_drive:
			throttle = control_input.throttle() if control_input else Input.get_axis("brake", "accelerate")
			desired_steer = control_input.steering() if control_input else Input.get_axis("left", "right")
			want_drift = (control_input.value("drift")>.5 if control_input else Input.is_action_pressed("drift")) and absf(speed) > 12 and (drifting or absf(desired_steer) > .12)
			if (control_input.consume("boost") if control_input else Input.is_action_just_pressed("boost")) and boost_fuel >= 1:
				boost_fuel = 0
				boost(1.6, "HYBRID E-BOOST" if definition.electric_boost else "NITRO BOOST")
		else:
			var bend_ahead := absf(circuit.direction(last_s).signed_angle_to(circuit.direction(last_s+26),Vector3.UP))
			var look := lerpf(8.0+absf(speed)*.36,9.0+absf(speed)*.18,clampf(bend_ahead,0,1))
			var target := circuit.sample(last_s + look, ai_lane + sin(progress * .013 + ai_phase) * .7)
			var dir := (target - position).normalized()
			var desired_yaw := atan2(-dir.x, -dir.z)
			var error := wrapf(desired_yaw - rotation.y, -PI, PI)
			desired_steer = clampf(-error * 2.2, -1, 1)
			var bend := absf(circuit.direction(last_s).signed_angle_to(circuit.direction(last_s + 22), Vector3.UP))
			ai_speed = max_speed * lerpf(1.0, .67, clampf(bend / 1.0, 0, 1))
			var lateral_limit: float=race_ai_lateral_acceleration if race_ai_lateral_acceleration>=0 else definition.ai_lateral_acceleration
			if lateral_limit>0:
				var braking_look:=maxf(26.,absf(speed)*1.25)
				var preview_bend:=absf(circuit.direction(last_s).signed_angle_to(circuit.direction(last_s+braking_look),Vector3.UP))
				ai_speed=minf(ai_speed,sqrt(lateral_limit*braking_look/maxf(preview_bend,.001)))
				bend=maxf(bend,preview_bend)
			throttle = 1 if speed < ai_speed else .15
			if boost_fuel >= 1 and bend < .2 and next_gate > 1:
				boost_fuel = 0
				boost(1.5, "NITRO BOOST")
	steer = lerpf(steer, desired_steer, minf(1, dt * 8))
	if is_player and not auto_drive and throttle < -.1:
		boost_time = 0
		if active and speed>5 and definition.braking_regeneration>0:
			boost_fuel=minf(1.,boost_fuel+dt*definition.braking_regeneration*clampf(speed/max_speed,0,1))
	if want_drift and not drifting:
		drift_direction = signf(desired_steer)
		air_hop = .18
	if drifting and not want_drift:
		if drift_charge >= .65 and throttle >= -.1:
			boost(1.0+minf(drift_charge,2.5)*.35,"SUPER DRIFT" if drift_charge>=1.65 else "DRIFT BOOST")
		drift_charge = 0
	if drifting != want_drift: drift_changed.emit(self,want_drift)
	drifting = want_drift
	if drifting:
		drift_charge = minf(2.5, drift_charge + dt)
		boost_fuel = minf(1, boost_fuel + dt * .12)
	else: boost_fuel = minf(1, boost_fuel + dt * .045)
	var target_speed := max_speed * throttle
	if throttle < 0: target_speed = -10.0
	if boost_time > 0 and active: target_speed = boosted_ceiling()
	if not is_player or auto_drive: target_speed = minf(target_speed, ai_speed * (1.3 if boost_time > 0 else 1.0))
	var rate := acceleration if throttle > .1 else 9.0
	if throttle < 0 and speed > 0: rate = 34
	if boost_time > 0: rate = 35
	if not active: target_speed = 0; rate = 22
	speed = move_toward(speed, target_speed, dt * rate)
	var grip := clampf(absf(speed) / 8, 0, 1)
	var turn_rate := lerpf(2.2, 1.65, clampf(absf(speed) / 40, 0, 1)) * handling
	rotation.y -= steer * turn_rate * grip * dt * (-1.0 if speed < -.1 else 1.0) * (1.12 if drifting else 1.0)
	var forward := -global_basis.z
	var target_vel := forward * speed
	var lateral_grip := 3.0 if drifting else 10.0
	velocity.x = lerpf(velocity.x, target_vel.x, minf(1, dt * lateral_grip))
	velocity.z = lerpf(velocity.z, target_vel.z, minf(1, dt * lateral_grip))
	velocity.y -= 18 * dt
	var motion_origin := global_position
	var contact_velocity := Vector3(velocity.x,0,velocity.z)
	move_and_slide()
	if get_slide_collision_count()>0 and bump_cooldown<=0 and absf(speed)>12 and absf(wheel_motion_speed)>5:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			# Floor contact is continuous; only a closing lateral impact earns feedback.
			if absf(hit.get_normal().y)<.6 and -contact_velocity.dot(hit.get_normal())>5:
				emit_impact_feedback(hit.get_position(),hit.get_normal())
				break
	# Soft continuous barrier response avoids gaps between modular rail meshes.
	var projection := circuit.project(position, nearest_index)
	nearest_index = projection.index
	var offset: float = projection.offset
	var track_normal:=Vector3(-projection.tangent.z,0,projection.tangent.x)
	var footprint:=absf(global_basis.x.dot(track_normal))*definition.collision_size.x*.5+absf(global_basis.z.dot(track_normal))*definition.collision_size.z*.5
	var lane_limit:=maxf(3.,circuit.width_at(projection.distance)*.5-footprint-.15)
	if absf(offset) > lane_limit:
		var normal := Vector3(-projection.tangent.z, 0, projection.tangent.x) * signf(offset)
		position -= normal * (absf(offset) - lane_limit)
		velocity -= normal * maxf(0, velocity.dot(normal))
		speed *= .985
		if is_player and bump_cooldown <= 0 and speed > 12:
			emit_impact_feedback(position+normal*1.0,-normal)
			impact.play()
			bump_cooldown = .65
	update_wheel_motion(global_position - motion_origin, dt)
	if is_player and not auto_drive and active and throttle>.5 and absf(wheel_motion_speed)<.5:
		stuck_time += dt
		if stuck_time>3.0: recover(); return
	else: stuck_time = 0
	var s: float = projection.distance
	var change := circuit.delta_distance(last_s, s)
	last_s = s
	if active and absf(change) < 8:
		progress += change
		var gate_distance := float(next_gate) * circuit.length / LeoCircuit.GATES
		if progress >= gate_distance and change > 0:
			gate_crossed.emit(self, next_gate)
			next_gate += 1
			lap = mini(3, maxi(0, next_gate - 1) / LeoCircuit.GATES + 1)
	if active and boost_cooldown <= 0:
		for fraction in circuit.boosts:
			if absf(circuit.delta_distance(s, float(fraction) * circuit.length)) < 2.5 and absf(offset) < 6.5:
				boost(1.5, "BOOST PAD")
				boost_cooldown = 2.0
	# Kenney-style independent wheel and body response.
	air_hop = move_toward(air_hop, 0, dt * .8)
	visual.position.y = (.20 + sin(Time.get_ticks_msec()*.0018)*.055 if definition.hovering else 0.0) + air_hop + sin(Time.get_ticks_msec() * .018) * .012 * absf(speed) / 33
	visual.rotation.z = lerp_angle(visual.rotation.z, -steer * .075 * grip, dt * 7)
	visual.rotation.y = lerp_angle(visual.rotation.y, -drift_direction * .32 if drifting else 0.0, dt * 6)
	if is_player and engine:
		engine.pitch_scale = lerpf(engine.pitch_scale, (.7 + absf(speed) / 20)*engine_pitch, dt * 3)
		engine.volume_db = -24 if not active else -17
		skid.volume_db = lerpf(skid.volume_db, -13.0 if drifting else -65.0, dt * 8)

func _process(dt: float) -> void:
	if not circuit or not visual: return
	animate_wheels(dt)
	effect_clock += dt
	for flame in flames:
		flame.visible = boost_time > 0 and active
		flame.scale = Vector3(1, 1.6 + sin(effect_clock * 38) * .3, 1)
	for trail in exhaust_trails:
		trail.emitting = boost_time > 0 and active
	for sparks in tire_sparks: sparks.emitting = drifting and drift_charge > .3 and absf(wheel_motion_speed)>4.

func emit_impact_feedback(point: Vector3,normal: Vector3) -> void:
	if impact_feedback_cooldown>0: return
	impact_feedback_cooldown = .35
	impacted.emit(self,point,normal,clampf(absf(speed)/42.0,0,1))
