class_name LeoKart
extends CharacterBody3D

# The steering response, visual lean, wheel animation and speed-driven engine
# audio extend Kenney's MIT Racing Starter Kit. A constrained CharacterBody
# replaces its sphere to make barrier contact and race recovery deterministic.
signal gate_crossed(kart, gate)
signal boosted(kart, source)
signal drift_changed(kart, enabled)
signal impacted(kart, point, normal, strength)
signal contact_reported(event)
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
var road_offset := 0.0
var checkpoint_missed := false
var last_reported_gate := -1
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
var motor_audio: LeoVehicleAudio
var engine: AudioStreamPlayer
var skid: AudioStreamPlayer
var boost_sound: AudioStreamPlayer
var impact: AudioStreamPlayer
var ai := LeoRaceAI.new()
var ai_seed := 0
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
var damage: LeoCosmeticDamage
var contact_clock:=0.0
var last_contact_at:=-10.0
var contact_recoil:=Vector3.ZERO
var vehicle_lighting: Node

static func chassis_path(key: String) -> String:
	return GarageCatalog.shared().vehicle(key).model.resource_path

static func driver_path(key: String) -> String:
	return GarageCatalog.shared().driver(key).seated_model.resource_path

static func vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func vehicle_spec(key: String) -> Dictionary:
	var v := LeoVehiclePresentation.resolve(GarageCatalog.shared().vehicle(key))
	return {"driver_position":[v.seat.origin.x,v.seat.origin.y,v.seat.origin.z],"driver_scale":[v.seat.basis.get_scale().x,v.seat.basis.get_scale().y,v.seat.basis.get_scale().z],"collision_size":[v.collision_size.x,v.collision_size.y,v.collision_size.z],"collision_position":[v.collision_position.x,v.collision_position.y,v.collision_position.z],"wheel_radius":v.wheels[0].radius if not v.wheels.is_empty() else .49,"exhausts":v.exhausts}

static func seat_driver(model: Node3D,key: String) -> void:
	model.transform = LeoVehiclePresentation.resolve(GarageCatalog.shared().vehicle(key)).seat * model.transform

func setup(track: LeoCircuit, id: int, player: bool, animal: String, kart_color: String, authored: VehicleDefinition = null) -> void:
	circuit = track
	racer_id = id
	is_player = player
	vehicle_key = kart_color
	definition = LeoVehiclePresentation.resolve(authored if authored else GarageCatalog.shared().vehicle(kart_color))
	LeoRaceRules.apply(self)
	wheel_radius = definition.wheels[0].radius if not definition.wheels.is_empty() else .49
	camera_height_offset = definition.camera_height
	engine_pitch = .65 if kart_color=="race_bus" else (1.22 if kart_color in ["race_tuk","colombo_tuk"] else (1.12 if kart_color.begins_with("formula") else 1.0))
	for p in definition.boost_emitters(): exhaust_positions.append(p)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	visual = VehicleAssembler.assemble(definition,GarageCatalog.shared().driver(animal))
	add_child(visual)
	chassis = visual.get_node("Chassis")
	vehicle_lighting = chassis.get_node_or_null("VehicleLighting")
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
		motor_audio=LeoVehicleAudio.new();add_child(motor_audio);motor_audio.setup(self)
	ai_phase = float(id) * 1.73
	ai_lane = [-3.8, 0.0, 3.8, -2.5, 2.5, 0.5][id % 6]
	effects = LeoKartEffects.new()
	visual.add_child(effects)
	effects.setup(self)
	damage=LeoCosmeticDamage.new();visual.add_child(damage);damage.setup(self)
	ai.reset(ai_seed+racer_id*7919+int(circuit.length),ai_lane)
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
	if not circuit.elevated:forward.y = 0
	wheel_motion_speed = clampf(movement.dot(forward.normalized()) / maxf(dt, .00001), -max_speed * 1.6, max_speed * 1.6)
	if absf(wheel_motion_speed) < .025: wheel_motion_speed = 0

func sound(file: String, volume: float, playing: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus="Effects"
	p.stream = load("res://assets/audio/" + file)
	if playing and p.stream is AudioStreamOggVorbis:
		(p.stream as AudioStreamOggVorbis).loop = true
	p.volume_db = volume
	add_child(p)
	if playing: p.play()
	return p

func stop_audio() -> void:
	if effects:effects.stop_contact_audio()
	if motor_audio:motor_audio.stop()
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
	road_offset=lane
	position = circuit.sample(distance, lane) + Vector3.UP * .12
	var t := circuit.direction(distance)
	rotation.y = atan2(-t.x, -t.z)
	if circuit.elevated:basis=circuit.frame_at(distance if not is_nan(distance) else 0.,rotation.y)
	progress = distance
	last_s = fposmod(distance, circuit.length)
	nearest_index = int(last_s / circuit.step)
	velocity = Vector3.ZERO
	speed = 0
	stuck_time = 0
	wheel_motion_speed = 0
	wheel_visual_speed = 0
	reset_physics_interpolation()

func advance_checkpoints(projection: Dictionary, motion: Vector3) -> void:
	var s: float=projection.distance
	var previous:=last_s
	var change:=circuit.delta_distance(previous,s)
	last_s=s
	if not active or finished or retired:return
	var segment:=circuit.length/LeoCircuit.GATES
	var expected:=float(next_gate)*segment
	var gate_s:=fposmod(expected,circuit.length)
	var valid:=motion.length()<=8. and absf(change)<=maxf(2.,motion.length()*2.+1.)
	valid=valid and absf(float(projection.offset))<=circuit.width_at(s)*.5+.5
	valid=valid and absf(position.y-float(projection.center.y))<maxf(3.,definition.collision_size.y)
	var to_gate:=circuit.delta_distance(previous,gate_s)
	if valid and change>0. and to_gate>=-.001 and to_gate<=change+.001:
		var crossed:=next_gate
		next_gate+=1
		lap=mini(3,1+maxi(0,next_gate-1)/LeoCircuit.GATES)
		checkpoint_missed=false
		gate_crossed.emit(self,crossed)
		expected=float(next_gate)*segment
		gate_s=fposmod(expected,circuit.length)
	var relative:=circuit.delta_distance(gate_s,s)
	checkpoint_missed=checkpoint_missed or not valid or (relative>2. and relative<circuit.length*.5)
	# Rank only within the interval after the last validated checkpoint.
	progress=clampf(expected+relative,expected-segment,expected-.001)

func recover() -> void:
	var completed := maxi(0,next_gate-1)
	var safe := float(completed) * circuit.length / LeoCircuit.GATES + 2.0
	var recoveries: Array=circuit.features.get("recoveries",[])
	if recoveries.size()==LeoCircuit.GATES:
		safe=floorf(float(completed)/LeoCircuit.GATES)*circuit.length+float(recoveries[posmod(completed,LeoCircuit.GATES)].distance)
	if next_gate==0:safe=minf(-2.,float(circuit.features.get("grid",{}).get("start",-8.)))
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
				var basis:=circuit.frame_at(safe-setback,atan2(-facing.x,-facing.z)) if circuit.elevated else Basis(Vector3.UP,atan2(-facing.x,-facing.z))
				query.transform=Transform3D(basis,point+basis*definition.collision_position)
				if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
					chosen=point;safe-=setback;found=true;break
			if found:break
		if not found:return
	position = chosen
	var t := circuit.direction(safe)
	rotation.y = atan2(-t.x, -t.z)
	if circuit.elevated:basis=circuit.frame_at(safe,rotation.y)
	progress = safe
	checkpoint_missed=false
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
	road_offset=circuit.project(position,nearest_index).offset
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
	contact_clock+=dt
	impact_feedback_cooldown = maxf(0,impact_feedback_cooldown-dt)
	var throttle := 0.0
	var desired_steer := 0.0
	var want_drift := false
	if active:
		if is_player and not auto_drive:
			throttle = control_input.throttle() if control_input else Input.get_axis("brake", "accelerate")
			desired_steer = control_input.steering() if control_input else Input.get_axis("left", "right")
			want_drift = (control_input.value("drift")>.5 if control_input else Input.is_action_pressed("drift")) and absf(speed) > 12 and (drifting or absf(desired_steer) > .12)
			if (control_input.consume("boost") if control_input else Input.is_action_just_pressed("boost")) and boost_fuel >= 1:
				boost_fuel = 0
				boost(1.6, "HYBRID E-BOOST" if definition.electric_boost else "NITRO BOOST")
		else:
			var command := ai.commands(self,dt)
			if command.recover:recover();return
			throttle=command.throttle;desired_steer=command.steer;want_drift=command.drift
			if command.boost and boost_fuel>=1.:
				boost_fuel=0.;boost(1.6,"HYBRID E-BOOST" if definition.electric_boost else "NITRO BOOST")
	steer = lerpf(steer, desired_steer, minf(1, dt * 8))
	if throttle < -.1:
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
	var rate := acceleration if throttle > .1 else 9.0
	if throttle < 0 and speed > 0: rate = 34
	if boost_time > 0: rate = 35
	if not active: target_speed = 0; rate = 22
	if vehicle_lighting:
		var lamps := LeoVehicleFeatures.driving_state(speed,control_input.value("accelerate") if control_input else maxf(throttle,0.),control_input.value("brake") if control_input else maxf(-throttle,0.),active,not is_player or auto_drive,target_speed)
		vehicle_lighting.update_state(lamps.x>.5,lamps.y>.5)
	speed = move_toward(speed, target_speed, dt * rate)
	var grip := clampf(absf(speed) / 8, 0, 1)
	var turn_rate := lerpf(2.2, 1.65, clampf(absf(speed) / 40, 0, 1)) * handling
	rotation.y -= steer * turn_rate * grip * dt * (-1.0 if speed < -.1 else 1.0) * (1.12 if drifting else 1.0)
	if circuit.elevated:basis=circuit.frame_at(last_s,rotation.y)
	var forward := -global_basis.z
	var target_vel := forward * speed
	var lateral_grip := 3.0 if drifting else 10.0
	velocity.x = lerpf(velocity.x, target_vel.x, minf(1, dt * lateral_grip))
	velocity.z = lerpf(velocity.z, target_vel.z, minf(1, dt * lateral_grip))
	if circuit.elevated and is_on_floor():
		var up:=circuit.frame_at(last_s).y
		velocity.y=-(velocity.x*up.x+velocity.z*up.z)/maxf(up.y,.5)
	velocity.y -= 18 * dt
	var motion_origin := global_position
	var contact_velocity := velocity
	move_and_slide()
	LeoContactSolver.solve(self,contact_velocity)
	# Soft continuous barrier response avoids gaps between modular rail meshes.
	var projection := circuit.project(position, nearest_index)
	nearest_index = projection.index
	var offset: float = projection.offset
	var track_normal:=Vector3(-projection.tangent.z,0,projection.tangent.x)
	if circuit.elevated:track_normal=track_normal.normalized()
	var footprint:=absf(global_basis.x.dot(track_normal))*definition.collision_size.x*.5+absf(global_basis.z.dot(track_normal))*definition.collision_size.z*.5
	var lane_limit:=maxf(3.,circuit.width_at(projection.distance)*.5-footprint-.15)
	# Physical rails handle ordinary contact. Only escaped/invalid positions recover.
	if absf(offset)>lane_limit+maxf(6.,definition.collision_size.length()):
		recover();return
	road_offset=clampf(offset,-lane_limit,lane_limit)
	if circuit.elevated and position.y<float(projection.center.y)-5.:recover();return
	update_wheel_motion(global_position - motion_origin, dt)
	if is_player and not auto_drive and active and throttle>.5 and absf(wheel_motion_speed)<.5:
		stuck_time += dt
		if stuck_time>3.0: recover(); return
	else: stuck_time = 0
	advance_checkpoints(projection,global_position-motion_origin)
	if active and boost_cooldown <= 0:
		for fraction in circuit.boosts:
			if absf(circuit.delta_distance(projection.distance, float(fraction) * circuit.length)) < 2.5 and absf(offset) < 6.5:
				boost(1.5, "BOOST PAD")
				boost_cooldown = 2.0
	# Keep the RC's body response; Reduced Motion suppresses presentation offsets.
	var reduced:=bool(get_parent().get("reduced_motion")) if get_parent().get("reduced_motion")!=null else false
	air_hop = move_toward(air_hop, 0, dt * .8)
	visual.position.y = (.20 if definition.hovering else 0.) if reduced else ((.20 + sin(Time.get_ticks_msec()*.0018)*.055 if definition.hovering else 0.0) + air_hop + sin(Time.get_ticks_msec() * .018) * .012 * absf(speed) / 33)
	visual.rotation.z = 0. if reduced else lerp_angle(visual.rotation.z, -steer * .075 * grip, dt * 7)
	visual.rotation.y = 0. if reduced else lerp_angle(visual.rotation.y, -drift_direction * .32 if drifting else 0.0, dt * 6)
	contact_recoil=Vector3.ZERO if reduced else contact_recoil.move_toward(Vector3.ZERO,dt*1.8)
	visual.rotation.z+=contact_recoil.z;visual.rotation.x=contact_recoil.x
	if is_player and engine:
		if motor_audio:motor_audio.throttle=throttle;motor_audio.update(dt)
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

func report_contact(point: Vector3, normal: Vector3, relative: Vector3, other: LeoKart, surface: String) -> void:
	var closing:=maxf(0.,-relative.dot(normal))
	var tangent:=relative.slide(normal).length()
	var phase:="impact" if contact_clock-last_contact_at>.18 and closing>2. else "scrape"
	last_contact_at=contact_clock
	var event:={"kart":self,"other":other,"point":point,"normal":normal,"normal_speed":closing,"tangent_speed":tangent,"surface":surface,"phase":phase}
	contact_reported.emit(event)
	if phase=="impact":
		var strength:=clampf(closing/35.,0.,1.)
		contact_recoil=Vector3(-.035*strength,0.,global_basis.x.dot(normal)*.055*strength)
		if impact_feedback_cooldown<=0.:
			impact_feedback_cooldown=.18;impacted.emit(self,point,normal,strength)

func _exit_tree() -> void:
	if control_input and control_input.kind=="gamepad" and control_input.device>=0:Input.stop_joy_vibration(control_input.device)
