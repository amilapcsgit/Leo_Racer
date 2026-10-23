class_name LeoArtProfile
extends Resource
## One editable art direction resource; simulation never reads these values.
@export var sun_color := Color("ffdfac")
@export var sun_energy := 1.8
@export var sun_angles := Vector3(-16.0, -145.0, 0.0)
@export var exposure := .80
@export var ambient_energy := .40
@export var sky_top := Color("1e5f74")
@export var sky_horizon := Color("e07a5f")
@export var haze_color := Color("dc864b")
@export var haze_density := .0009
@export var bloom_intensity := .55
@export var cobalt := Color("1d4ed8")
@export var gold := Color("d4af37")
@export var city_palette: PackedColorArray = PackedColorArray([Color("b95046"),Color("137e83"),Color("be8638"),Color("705078"),Color("c9b692"),Color("a43d68")])
@export var camera_boost_peak := 14.0
@export var camera_boost_hold := 9.0
@export var camera_roll_degrees := 5.0
@export var landmark_position := Vector3(-105,.07,-235)
@export_file("*.glb") var world_model := "res://assets/models/lotus_coast.glb"
@export_file("*.glb") var landmark_model := "res://assets/models/lotus_tower.glb"
@export var landmark_scale := .85
@export var road_roughness := .35
@export var bay_fog_density := .008
@export var foliage_near_distance := 100.0
@export var foliage_far_distance := 220.0
@export_file("*.png") var sky_visual_path := ""
@export_file("*.exr") var sky_lighting_path := ""
@export var sky_horizon_offset := .017
@export var transport_positions := PackedVector3Array([Vector3(-71,0,30),Vector3(-72,0,-4),Vector3(112,0,-48),Vector3(58,0,125)])
@export var reserve_transport_bays := false
@export var bus_position := Vector3(-71.5,0,53)

func transport_position(index: int,circuit: LeoCircuit) -> Vector3:
	var p:=transport_positions[index]
	var projected:=circuit.project(p)
	if absf(projected.offset)<17.5:p=circuit.sample(projected.distance,17.5*signf(projected.offset))
	return p

func parking_clear(p: Vector3,circuit: LeoCircuit,extra: float=0.0) -> bool:
	if not reserve_transport_bays:return true
	for index in range(transport_positions.size()+1):
		var bus:=index==transport_positions.size()
		var center:=bus_position if bus else transport_position(index,circuit)
		var t:=circuit.direction(circuit.project(center).distance)
		var normal:=Vector3(-t.z,0,t.x)
		var relative:=p-center
		if absf(relative.dot(t))<(6.3 if bus else 2.6)+extra and absf(relative.dot(normal))<(1.6 if bus else 1.15)+extra:return false
	return true
