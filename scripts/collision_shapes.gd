class_name LeoCollisionShapes
extends RefCounted
static var profiles: Dictionary={}
static func definitions(vehicle: VehicleDefinition) -> Array:
	if profiles.is_empty():profiles=JSON.parse_string(FileAccess.get_file_as_string("res://assets/config/collision-shapes-v278.json"))
	var authored: Array=profiles.get(String(vehicle.id),[]) if vehicle.official else []
	if authored.is_empty():authored=vehicle.contact_shapes
	var result: Array=[]
	for row in authored.slice(0,4):
		if not row is Dictionary or not row.get("size_fraction",null) is Array or not row.get("center_fraction",null) is Array:continue
		if not LeoVehicleCodec.finite_vector(row.size_fraction) or not LeoVehicleCodec.finite_vector(row.center_fraction):continue
		var size:=LeoVehicleCodec.vector(row.size_fraction)*vehicle.collision_size
		var offset:=LeoVehicleCodec.vector(row.center_fraction)*vehicle.collision_size
		if not size.is_finite() or not offset.is_finite() or size.x<=0. or size.y<=0. or size.z<=0.:continue
		if size.x>vehicle.collision_size.x or size.y>vehicle.collision_size.y or size.z>vehicle.collision_size.z:continue
		if not AABB(vehicle.collision_position-vehicle.collision_size*.5-Vector3.ONE*.001,vehicle.collision_size+Vector3.ONE*.002).encloses(AABB(vehicle.collision_position+offset-size*.5,size)):continue
		result.append({"size":size,"position":vehicle.collision_position+offset})
	if result.is_empty():result.append({"size":vehicle.collision_size,"position":vehicle.collision_position})
	return result
static func install(kart: LeoKart) -> void:
	for row in definitions(kart.definition):
		var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=row.size;collider.shape=shape;collider.position=row.position;kart.add_child(collider)
