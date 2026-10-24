class_name LeoVehicleCodec
extends RefCounted
## JSON adapter; never evaluates expressions or accepts user scripts.
const FIELDS := ["display_name","collision_size","collision_position","max_speed","boosted_speed","electric_boost","braking_regeneration","ai_lateral_acceleration","acceleration","handling","camera_height","preview_target","preview_distance","exhausts","driver_policy","seat","normalization","driver_fits","hovering","preserve_materials","fixed_driver_id","setup_complete","attribution"]

static func encode(value: Variant) -> Variant:
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Transform3D:return {"basis":[encode(value.basis.x),encode(value.basis.y),encode(value.basis.z)],"origin":encode(value.origin)}
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[String(key)]=encode(value[key])
		return result
	if value is PackedVector3Array:
		var result: Array=[]
		for item in value:result.append(encode(item))
		return result
	return String(value) if value is StringName else value

static func vector(value: Variant) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func transform(value: Dictionary) -> Transform3D:
	return Transform3D(Basis(vector(value.basis[0]),vector(value.basis[1]),vector(value.basis[2])),vector(value.origin))

static func serialize(vehicle: VehicleDefinition) -> Dictionary:
	var data: Dictionary={"format":1,"vehicle_api":1,"id":String(vehicle.id),"version":"1.0.0","core":{"min":"2.2.0","max_major":2},"model":"model.glb","thumbnail":"thumbnail.png","dependencies":[],"wheels":[]}
	for key in FIELDS:data[key]=encode(vehicle.get(key))
	for wheel in vehicle.wheels:
		data.wheels.append({"rotating":Array(wheel.rotating_groups).map(func(p):return String(p)),"stationary":Array(wheel.stationary_groups).map(func(p):return String(p)),"steering":wheel.steering,"axle":encode(wheel.axle),"pivot":encode(wheel.pivot),"radius":wheel.radius})
	return data

static func deserialize(data: Dictionary, folder: String) -> VehicleDefinition:
	var vehicle:=VehicleDefinition.new();vehicle.id=StringName(data.id)
	vehicle.max_speed=165./3.6;vehicle.boosted_speed=55.;vehicle.acceleration=18.;vehicle.handling=1.
	for key in FIELDS:
		if not data.has(key):continue
		var value: Variant=data[key]
		if key in ["collision_size","collision_position","preview_target"]:value=vector(value)
		elif key in ["seat","normalization"]:value=transform(value)
		elif key=="driver_fits":
			value={}
			for driver in data[key]:value[driver]=transform(data[key][driver])
		elif key=="exhausts":
			value=PackedVector3Array()
			for point in data[key]:value.append(vector(point))
		vehicle.set(key,value)
	vehicle.model_path=folder.path_join(String(data.get("model","model.glb")))
	for item in data.get("wheels",[]):
		var wheel:=WheelBinding.new()
		for path in item.get("rotating",[]):wheel.rotating_groups.append(NodePath(path))
		for path in item.get("stationary",[]):wheel.stationary_groups.append(NodePath(path))
		wheel.steering=bool(item.get("steering",false));wheel.pivot=vector(item.get("pivot",[0,0,0]));wheel.axle=vector(item.get("axle",[1,0,0]));wheel.radius=float(item.get("radius",.4));vehicle.wheels.append(wheel)
	return vehicle
