class_name LeoLocalPlayer
extends RefCounted
var slot := 0
var profile_id := ""
var player_name := ""
var driver_id: StringName = &"hedgehog"
var vehicle_id: StringName = &"blue"
var preferred_vehicle_id: StringName
var kart: LeoKart
var camera_rig := preload("res://scripts/local/race_camera.gd").new()
var camera: Camera3D
var feedback: Node
var lap_started := 0.
var best_lap := 99999.
var launch_charged := false
var wrong_way := 0.
var slipstream_time := 0.
var slipstream_cooldown := 0.
var horn_cooldown := 0.
var boost_count := 0
var heading := 0.
var roll := 0.
var announcement := ""
var announcement_time := 0.
var photo := false
func _init(index: int = 0) -> void:
 slot=index
 profile_id=Crypto.new().generate_random_bytes(16).hex_encode()
 if index==1:driver_id=&"mario";vehicle_id=&"duster";player_name="Player 2"
func reset_race() -> void:
 camera_rig=preload("res://scripts/local/race_camera.gd").new()
 kart=null;lap_started=0.;best_lap=99999.;launch_charged=false;wrong_way=0.;slipstream_time=0.;slipstream_cooldown=0.;horn_cooldown=0.;boost_count=0;heading=0.;roll=0.;announcement="";announcement_time=0.;photo=false
func selection() -> Dictionary:
 return {"profile_id":profile_id,"name":player_name,"driver":String(driver_id),"vehicle":String(preferred_vehicle_id if not preferred_vehicle_id.is_empty() else vehicle_id)}
func restore(data: Dictionary, catalog: GarageCatalog) -> void:
 profile_id=str(data.get("profile_id",profile_id))
 player_name=str(data.get("name",player_name)).strip_edges().left(32)
 var d:=StringName(str(data.get("driver",driver_id)))
 var v:=StringName(str(data.get("vehicle",vehicle_id)))
 if catalog.driver(d):driver_id=d
 if catalog.vehicle(v):vehicle_id=v;preferred_vehicle_id=&""
 else:preferred_vehicle_id=v;vehicle_id=LeoDefaultRoster.fallback(catalog)
