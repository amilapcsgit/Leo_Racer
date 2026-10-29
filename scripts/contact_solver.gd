class_name LeoContactSolver
extends RefCounted
## Contact response shares the existing CharacterBody driving path.
static var pair_frame := -1
static var pairs: Dictionary={}
static func remove_closing(velocity: Vector3, normal: Vector3) -> Vector3:
	return velocity-normal*minf(0.,velocity.dot(normal))
static func solve(kart: LeoKart, incoming: Vector3) -> void:
	var frame:=Engine.get_physics_frames()
	if pair_frame!=frame:pair_frame=frame;pairs.clear()
	for i in kart.get_slide_collision_count():
		var hit:=kart.get_slide_collision(i)
		var normal:=hit.get_normal()
		if absf(normal.y)>.6:continue
		var other:=hit.get_collider() as LeoKart
		var relative:=incoming-(other.velocity if other else Vector3.ZERO)
		var closing:=maxf(0.,-relative.dot(normal))
		if closing<.15:continue
		if other:
			if other.finished or other.retired:continue
			var key:="%d:%d"%[mini(kart.get_instance_id(),other.get_instance_id()),maxi(kart.get_instance_id(),other.get_instance_id())]
			if pairs.has(key):continue
			pairs[key]=true
			# Damped equal-mass impulse: no pair kinetic-energy gain.
			kart.velocity=incoming+normal*closing*(1.+LeoArcadeDynamics.RESTITUTION)*.5
			other.velocity-=normal*closing*(1.+LeoArcadeDynamics.RESTITUTION)*.5
			other.speed=signf(other.speed)*minf(absf(other.speed),Vector2(other.velocity.x,other.velocity.z).length())
		else:kart.velocity=remove_closing(incoming,normal)+normal*closing*LeoArcadeDynamics.RESTITUTION
		kart.speed=signf(kart.speed)*minf(absf(kart.speed),Vector2(kart.velocity.x,kart.velocity.z).length())
		kart.report_contact(hit.get_position(),normal,relative,other,"paint" if other else String(hit.get_collider().get_meta("contact_surface","concrete")))
		if other:other.report_contact(hit.get_position(),-normal,-relative,kart,"paint")
		incoming=kart.velocity
