class_name LeoContactSolver
extends RefCounted
## Contact response shares the existing CharacterBody driving path.
static var pair_frame := -1
static var pairs: Dictionary={}
static func remove_closing(velocity: Vector3, normal: Vector3) -> Vector3:
	return velocity-normal*minf(0.,velocity.dot(normal))
static func pair_response(a: Vector3,b: Vector3,normal: Vector3) -> Array[Vector3]:
	var closing:=maxf(0.,-(a-b).dot(normal))
	# Inelastic equal-mass contact preserves tangent and momentum, losing energy.
	var impulse:=normal*closing*.5
	return [a+impulse,b-impulse]
static func solve(kart: LeoKart, incoming: Vector3) -> void:
	var frame:=Engine.get_physics_frames()
	if pair_frame!=frame:pair_frame=frame;pairs.clear()
	for i in kart.get_slide_collision_count():
		var hit:=kart.get_slide_collision(i)
		var normal:=hit.get_normal()
		var other:=hit.get_collider() as LeoKart
		if absf(normal.y)>.6 and not other:continue
		if other:
			# Vehicle roofs cannot act as launch ramps or moving platforms.
			kart.velocity.y=minf(kart.velocity.y,maxf(0.,incoming.y))
		if Vector2(normal.x,normal.z).length_squared()<.001:continue
		normal=Vector3(normal.x,0.,normal.z).normalized()
		var relative:=incoming-(other.velocity if other else Vector3.ZERO)
		var closing:=maxf(0.,-relative.dot(normal))
		# Tangential contact still produces a sustained scrape event.
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
			other.speed=signf(other.speed)*minf(absf(other.speed),Vector2(other.velocity.x,other.velocity.z).length())
		else:kart.velocity=remove_closing(incoming,normal)
		kart.speed=signf(kart.speed)*minf(absf(kart.speed),Vector2(kart.velocity.x,kart.velocity.z).length())
		kart.report_contact(hit.get_position(),normal,relative,other,"paint" if other else String(hit.get_collider().get_meta("contact_surface","concrete")))
		if other:other.report_contact(hit.get_position(),-normal,-relative,kart,"paint")
		incoming=kart.velocity
