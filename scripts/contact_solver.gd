class_name LeoContactSolver
extends RefCounted
## Contact response shares the existing CharacterBody driving path.
static var pair_frame := -1
static var pairs: Dictionary={}
const BARRIER_RESTITUTION=.18
const MAX_REBOUND=4.
const HOP_THRESHOLD := 8.0
const MAX_HOP_SPEED := 2.0
const PAIR_RESTITUTION := 0.12

static func fresh_contact(frames: Dictionary, key: Variant, frame: int) -> bool:
	var fresh := frame - int(frames.get(key, -100)) > 2
	frames[key] = frame
	return fresh

static func hop_speed(closing: float) -> float:
	return clampf((closing-HOP_THRESHOLD)*0.12,0.0,MAX_HOP_SPEED)

static func apply_hop(kart: LeoKart, closing: float, share: float = 1.0) -> void:
	if kart.grounded and kart.active and not kart.finished and not kart.retired:
		var lift := hop_speed(closing)*share
		if lift > 0.0:
			kart.velocity.y=maxf(kart.velocity.y,lift)
			kart.impact_hop=true
			kart.grounded=false

static func barrier_response(incoming: Vector3,normal: Vector3,fresh: bool=true) -> Vector3:
	var closing:=maxf(0.,-incoming.dot(normal))
	var outward:=minf(MAX_REBOUND,closing*BARRIER_RESTITUTION) if fresh and closing>=2. else 0.
	return remove_closing(incoming,normal)+normal*outward
static func remove_closing(velocity: Vector3, normal: Vector3) -> Vector3:
	return velocity-normal*minf(0.,velocity.dot(normal))
static func pair_response(a: Vector3,b: Vector3,normal: Vector3) -> Array[Vector3]:
	var closing:=maxf(0.,-(a-b).dot(normal))
	# Equal-mass rebound preserves tangent and momentum while dissipating energy.
	var impulse:=normal*closing*(1.0+PAIR_RESTITUTION)*.5
	return [a+impulse,b-impulse]
static func solve(kart: LeoKart, incoming: Vector3) -> void:
	var frame:=Engine.get_physics_frames()
	if pair_frame!=frame:pair_frame=frame;pairs.clear()
	for i in kart.get_slide_collision_count():
		var hit:=kart.get_slide_collision(i)
		var normal:=hit.get_normal()
		var other:=hit.get_collider() as LeoKart
		if absf(normal.y)>.6 and not other:continue
		var collider := hit.get_collider()
		if collider and collider.get_meta("continuous_road_deck",false):
			# Keep the floor contact and discard the false wall response.
			kart.velocity.x=incoming.x
			kart.velocity.z=incoming.z
			continue
		if other:
			# Vehicle roofs cannot act as launch ramps or moving platforms.
			kart.velocity.y=minf(kart.velocity.y,maxf(0.,incoming.y))
		if Vector2(normal.x,normal.z).length_squared()<.001:continue
		normal=Vector3(normal.x,0.,normal.z).normalized()
		var relative:=incoming-(other.velocity if other else Vector3.ZERO)
		var closing:=maxf(0.,-relative.dot(normal))
		# Record glancing hits too so an uninterrupted scrape cannot relaunch a car.
		var fresh: bool
		if other:
			var peer_id := other.get_instance_id()
			var self_id := kart.get_instance_id()
			fresh = fresh_contact(kart.impact_contact_frames, peer_id, frame)
			other.impact_contact_frames[self_id] = frame
		else:
			var wall_key := "%d:%s" % [hit.get_collider_id(), normal.snapped(Vector3.ONE * .25)]
			fresh = fresh_contact(kart.impact_contact_frames, wall_key, frame)
		if closing<.15:
			if relative.slide(normal).length()>1.:
				kart.report_contact(hit.get_position(),normal,relative,other,"paint" if other else String(hit.get_collider().get_meta("contact_surface","concrete")))
			continue
		kart.contact_this_tick=true
		if other:
			if other.finished or other.retired:continue
			var key:="%d:%d"%[mini(kart.get_instance_id(),other.get_instance_id()),maxi(kart.get_instance_id(),other.get_instance_id())]
			if pairs.has(key):continue
			pairs[key]=true
			var response:=pair_response(incoming,other.velocity,normal)
			kart.velocity=response[0];other.velocity=response[1]
			other.contact_this_tick=true
			if fresh:
				apply_hop(kart,closing,.5)
				apply_hop(other,closing,.5)
			other.speed=signf(other.speed)*minf(absf(other.speed),Vector2(other.velocity.x,other.velocity.z).length())
		else:
			kart.velocity=barrier_response(incoming,normal,fresh)
			if fresh:apply_hop(kart,closing)
			kart.speed=kart.velocity.dot(-kart.global_basis.z)
		kart.speed=signf(kart.speed)*minf(absf(kart.speed),Vector2(kart.velocity.x,kart.velocity.z).length())
		kart.report_contact(hit.get_position(),normal,relative,other,"paint" if other else String(hit.get_collider().get_meta("contact_surface","concrete")))
		if other:other.report_contact(hit.get_position(),-normal,-relative,kart,"paint")
		incoming=kart.velocity
