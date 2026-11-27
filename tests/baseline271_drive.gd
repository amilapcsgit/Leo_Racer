extends LeoKart
# Drive-only regression reference from 2.7.1 commit a34196e.
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
			boost(1.0+minf(drift_charge,2.5)*.35,"SUPER DRIFT" if drift_charge>=1.65 else "DRIFT BOOST","drift",2 if drift_charge>=1.65 else 1)
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
	if grounded and is_on_floor():
		var support:=get_floor_normal()
		var heading:=Vector3(-sin(rotation.y),0,-cos(rotation.y)).slide(support).normalized()
		if heading.length_squared()>.01:basis=basis.slerp(Basis.looking_at(heading,support),1.-exp(-dt*14.)).orthonormalized()
	var forward := -global_basis.z
	var target_vel := forward * speed
	var lateral_grip := (3.0 if drifting else 10.0)*(1. if grounded else LeoArcadeDynamics.AIR_GRIP)
	velocity.x = lerpf(velocity.x, target_vel.x, minf(1, dt * lateral_grip))
	velocity.z = lerpf(velocity.z, target_vel.z, minf(1, dt * lateral_grip))
	if circuit.elevated and is_on_floor():
		var up:=get_floor_normal()
		velocity.y=-(velocity.x*up.x+velocity.z*up.z)/maxf(up.y,.5)
	landing_suppression=maxf(0.,landing_suppression-dt)
	floor_snap_length=LeoArcadeDynamics.SNAP if velocity.y<=0. and grounded else 0.
	velocity.y -= LeoArcadeDynamics.GRAVITY * dt
	var motion_origin := global_position
	var contact_velocity := velocity
	var was_grounded:=grounded
	move_and_slide()
	grounded=is_on_floor()
	if grounded:
		var normal_speed:=maxf(0.,-contact_velocity.dot(get_floor_normal()))
		if not was_grounded and airborne_time>.035 and landing_suppression<=0. and normal_speed>LeoArcadeDynamics.LANDING_THRESHOLD:
			var strength:=clampf(normal_speed/10.,0.,1.)
			dynamics.spring_velocity.x=-strength*1.2
			surface_feedback.emit("landing",strength)
		elif was_grounded and absf(contact_velocity.y-velocity.y)>1. and landing_suppression<=0.:
			surface_feedback.emit("bump",clampf(absf(contact_velocity.y-velocity.y)/12.,.1,.45))
		airborne_time=0.
	else:airborne_time+=dt
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
				boost(1.5, "BOOST PAD","pad")
				boost_cooldown = 2.0
	# Keep the RC's body response; Reduced Motion suppresses presentation offsets.
	var reduced:=bool(get_parent().get("reduced_motion")) if get_parent().get("reduced_motion")!=null else false
	air_hop = move_toward(air_hop, 0, dt * .8)

	var photo:=false
	if is_player and get_parent().get("local_players")!=null:photo=get_parent().local_players[local_slot].photo
	update_suspension(dt,reduced or photo,(global_position-motion_origin)/maxf(dt,.001))
	visual.position.y=(.20 if definition.hovering else 0.) if reduced else ((.20+sin(Time.get_ticks_msec()*.0018)*.055) if definition.hovering else clampf(dynamics.compression.x+air_hop,-.06,.20))
	visual.rotation.z = suspension_roll
	visual.rotation.y = 0. if reduced else lerp_angle(visual.rotation.y, -drift_direction * .32 if drifting else 0.0, dt * 6)
	contact_recoil=Vector3.ZERO
	visual.rotation.x=suspension_pitch
	if is_player and engine:
		if motor_audio:motor_audio.throttle=throttle;motor_audio.update(dt)
		skid.volume_db = lerpf(skid.volume_db, -13.0 if drifting else -65.0, dt * 8)
