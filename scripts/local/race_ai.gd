class_name LeoRaceAI
extends RefCounted
## Decisions only. The ordinary vehicle controller owns all motion and progress.
var lane := 0.0
var commitment := 0.0
var patience := 1.0
var preferred_side := 1.0
var stalled := 0.0
var reverse_left := 0.0
var recovery_wait := 0.0
var decision_left := 0.0
var target_speed := 0.0
var clear_distance := 1000.0
var initialized := false
var obstacles: Dictionary = {}

func reset(seed_value: int, initial_lane: float) -> void:
	var rng := RandomNumberGenerator.new();rng.seed=seed_value
	patience=rng.randf_range(.9,1.25);preferred_side=-1.0 if rng.randf()<.5 else 1.0
	lane=initial_lane;commitment=0.;stalled=0.;reverse_left=0.;recovery_wait=0.;decision_left=0.;initialized=true
	obstacles.clear()

func neighbors(kart: LeoKart) -> Array:
	var parent := kart.get_parent()
	return parent.karts if parent and parent.get("karts") is Array else []

func corridor(kart: LeoKart, candidate: float, peers: Array) -> Dictionary:
	var gap: float=obstacles.get(candidate,1000.)
	var leader_speed := 0.0 if gap<1000. else kart.boosted_ceiling()
	var blocked := gap<maxf(5.,absf(kart.speed)*1.2)
	var rear_blocked := false
	for other: LeoKart in peers:
		if other==kart or other.retired or other.finished:continue
		var distance := kart.circuit.delta_distance(kart.last_s,other.last_s)
		if absf(distance)>100.:continue
		var offset := other.road_offset
		var side_margin := (kart.definition.collision_size.x+other.definition.collision_size.x)*.5+.65
		var side := Vector3(-kart.circuit.direction(kart.last_s).z,0,kart.circuit.direction(kart.last_s).x).normalized()
		offset+=clampf(other.velocity.dot(side)*.5,-2.,2.)
		if absf(offset-candidate)>side_margin:continue
		var length_margin := (kart.definition.collision_size.z+other.definition.collision_size.z)*.5
		if distance>=0 and distance-length_margin<gap:
			gap=maxf(0.,distance-length_margin);leader_speed=maxf(0.,other.speed)
		if absf(distance)<length_margin+2. or (distance<0 and distance>-length_margin-maxf(5.,(other.speed-kart.speed)*1.5)):blocked=true
		if distance<=0 and distance>-length_margin-maxf(5.,(other.speed-kart.speed)*1.5):rear_blocked=true
	return {"gap":gap,"speed":leader_speed,"blocked":blocked,"rear_blocked":rear_blocked}

func obstacle_distance(kart: LeoKart, candidate: float) -> float:
	if not kart.is_inside_tree():return 1000.
	var space := kart.get_world_3d().direct_space_state
	var stride := maxf(12.,absf(kart.speed)*.45)
	var margin := kart.definition.collision_size.x*.42
	for step in 3:
		for side: float in [-margin,0.,margin]:
			var a := kart.circuit.sample(kart.last_s+float(step)*stride,candidate+side)+Vector3.UP
			var b := kart.circuit.sample(kart.last_s+float(step+1)*stride,candidate+side)+Vector3.UP
			var query := PhysicsRayQueryParameters3D.create(a,b,1,[kart.get_rid()])
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and absf(hit.normal.y)<.65:return float(step)*stride+a.distance_to(hit.position)
	return 1000.

func corner_speed(kart: LeoKart, available_speed: float) -> float:
	var result := available_speed
	var track := kart.circuit
	var horizon := maxf(45.,absf(kart.speed)*2.2)
	var lateral := maxf(5.,kart.race_ai_lateral_acceleration)
	for i in range(1,9):
		var distance := horizon*float(i)/8.
		var before := track.direction(kart.last_s+distance-6.)
		var after := track.direction(kart.last_s+distance+6.)
		var curvature := absf(before.signed_angle_to(after,Vector3.UP))/12.
		var limit := sqrt(lateral/maxf(curvature,.0001))
		if track.elevated:limit*=clampf(1.-absf(after.y-before.y)*.8,.75,1.)
		result=minf(result,sqrt(limit*limit+2.*26.*maxf(0.,distance-8.)))
	return result

func commands(kart: LeoKart, dt: float) -> Dictionary:
	if not initialized:reset(kart.racer_id*7919+int(kart.circuit.length),kart.ai_lane)
	commitment=maxf(0.,commitment-dt);decision_left-=dt;recovery_wait=maxf(0.,recovery_wait-dt)
	var bound := maxf(0.,kart.circuit.width_at(kart.last_s)*.5-kart.definition.collision_size.x*.5-1.2)
	var peers := neighbors(kart)
	lane=clampf(lane,-bound,bound)
	var current := corridor(kart,lane,peers)
	if decision_left<=0.:
		decision_left=.15
		var chosen := lane
		var best := -INF
		for candidate: float in [-minf(3.8,bound),0.,minf(3.8,bound),lane]:
			obstacles[candidate]=obstacle_distance(kart,candidate)
			var path := corridor(kart,candidate,peers)
			if path.blocked and absf(candidate-lane)>.25:continue
			var score := minf(path.gap,65.)-absf(candidate-lane)*1.5+candidate*preferred_side*.08
			if absf(candidate-lane)<.25:score+=5. if commitment>0 else 1.
			if score>best:best=score;chosen=candidate
		if commitment<=0. or current.blocked or current.gap<3.:
			if absf(chosen-lane)>.25:lane=chosen;commitment=patience*1.25
	current=corridor(kart,lane,peers);clear_distance=current.gap
	var bend := absf(kart.circuit.direction(kart.last_s).signed_angle_to(kart.circuit.direction(kart.last_s+26.),Vector3.UP))
	var look := lerpf(8.+absf(kart.speed)*.36,9.+absf(kart.speed)*.18,clampf(bend,0.,1.))
	var projected := kart.road_offset
	var aim_lane := move_toward(projected,lane,look*.20)
	var target := kart.circuit.sample(kart.last_s+look,aim_lane)
	var direction := (target-kart.position).normalized()
	var error := wrapf(atan2(-direction.x,-direction.z)-kart.rotation.y,-PI,PI)
	var steering := clampf(-error*2.2,-1.,1.)
	target_speed=corner_speed(kart,kart.boosted_ceiling() if kart.boost_time>0 else kart.max_speed)
	var follow_gap := 3.+maxf(0.,kart.speed)*.4*patience
	if current.gap<follow_gap+maxf(0.,kart.speed-current.speed)*1.5:
		target_speed=minf(target_speed,maxf(0.,current.speed+(current.gap-follow_gap)*.8))
	if absf(error)>1.:target_speed=minf(target_speed,12.)
	var throttle := 1.0 if kart.speed<target_speed-.7 else 0.0
	if kart.speed>target_speed+1.:throttle=-1.
	if kart.speed<.25 and target_speed<1.:throttle=0.
	if kart.active and absf(kart.wheel_motion_speed)<.5:stalled+=dt
	else:stalled=maxf(0.,stalled-dt*2.)
	var recover := false
	if stalled>2. and reverse_left<=0. and recovery_wait<=0.:
		reverse_left=1.1;recovery_wait=5.
	if reverse_left>0.:
		reverse_left=maxf(0.,reverse_left-dt)
		throttle=-1. if not current.rear_blocked else 0.;steering=-steering
		if reverse_left<=0. and stalled>2.:recover=true;stalled=0.
	var boost_ok: bool= kart.boost_fuel>=1. and kart.next_gate>1 and kart.speed>15. and absf(error)<.12 and current.gap>maxf(45.,kart.speed*2.) and corner_speed(kart,kart.boosted_ceiling())>=kart.boosted_ceiling()*.97 and reverse_left<=0.
	return {"steer":steering,"throttle":throttle,"drift":false,"boost":boost_ok,"recover":recover}
