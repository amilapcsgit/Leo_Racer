class_name LeoVehiclePresentation
extends RefCounted
## Runtime derivatives only: original portable definitions and models stay intact.
static var cache: Dictionary={}
static var profiles: Dictionary={}

static func bounds(node: Node3D, pose: Transform3D=Transform3D.IDENTITY) -> AABB:
	var transform:=pose*node.transform
	var result:=AABB()
	if node is MeshInstance3D and node.mesh:result=transform*node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var box:=bounds(child,transform)
			if box.size.length_squared()>0.:result=box if result.size.length_squared()==0. else result.merge(box)
	return result

static func resolve(source: VehicleDefinition) -> VehicleDefinition:
	if not source or source.has_meta("presentation_resolved"):return source
	var key:=source.get_instance_id()
	if cache.has(key):return cache[key]
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/vehicle-presentation-v1.json"))
	var measured:=AABB()
	if not source.compiled_bounds.is_empty():
		measured=source.normalization*AABB(LeoVehicleCodec.vector(source.compiled_bounds.position),LeoVehicleCodec.vector(source.compiled_bounds.size))
	else:
		var model:=source.model.instantiate() as Node3D
		model.transform=source.normalization*model.transform
		measured=bounds(model)
		model.free()
	var entry: Dictionary=profiles.get(String(source.id),{})
	var factor:=1.
	if source.id==&"bigster":factor=1./1.3
	elif entry.has("length"):factor=float(entry.length)/maxf(.001,measured.size.z)
	else:factor=minf(4.4/maxf(.001,measured.size.z),minf(2./maxf(.001,measured.size.x),1.8/maxf(.001,measured.size.y)))
	var resolved:=source.duplicate(true) as VehicleDefinition
	# Resource.duplicate copies exported fields, not runtime package classification.
	resolved.official=source.official
	resolved.content_folder=source.content_folder
	resolved.content_data=source.content_data
	resolved.thumbnail_path=source.thumbnail_path
	resolved.normalization=Transform3D(source.normalization.basis.scaled(Vector3.ONE*factor),source.normalization.origin*factor)
	resolved.collision_size=source.collision_size*factor
	resolved.collision_position=source.collision_position*factor
	resolved.camera_height=source.camera_height*factor
	resolved.seat=scaled_fit(source.seat,factor)
	resolved.driver_fits={}
	for driver in source.driver_fits:resolved.driver_fits[driver]=scaled_fit(source.driver_fits[driver],factor)
	resolved.exhausts=PackedVector3Array()
	for point in source.exhausts:resolved.exhausts.append(point*factor)
	for i in resolved.wheels.size():
		resolved.wheels[i]=source.wheels[i].duplicate(true)
		# Pivots and feature anchors are model-local: normalization scales them.
		resolved.wheels[i].radius=source.wheels[i].radius*factor
	var final_bounds:=AABB(measured.position*factor,measured.size*factor)
	resolved.preview_target=final_bounds.get_center()
	resolved.preview_distance=maxf(6.,final_bounds.size.length()*1.65)
	resolved.set_meta("presentation_resolved",true)
	resolved.set_meta("presentation_bounds",final_bounds)
	resolved.set_meta("presentation_audit",{"id":String(source.id),"factor":factor,"before":LeoVehicleCodec.encode(measured.size),"after":LeoVehicleCodec.encode(final_bounds.size),"reference":entry.get("source","Fantasy passenger envelope 4.4 x 2.0 x 1.8 m"),"target_length":entry.get("length",0.)})
	cache[key]=resolved
	return resolved

static func scaled_fit(pose: Transform3D,factor: float) -> Transform3D:
	return Transform3D(pose.basis.scaled(Vector3.ONE*factor),pose.origin*factor)
