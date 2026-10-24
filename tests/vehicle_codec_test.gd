extends SceneTree
func _initialize() -> void:
	var catalog:=load("res://assets/catalog/runtime/catalog.tres") as GarageCatalog
	var count:=0
	for original in catalog.vehicles:
		var json:=JSON.stringify(LeoVehicleCodec.serialize(original))
		var data: Dictionary=JSON.parse_string(json)
		assert(LeoVehicleLibrary.problems(data,"",false).is_empty(),String(original.id))
		var restored:=LeoVehicleCodec.deserialize(data,"user://test")
		for key in LeoVehicleCodec.FIELDS:
			assert(JSON.stringify(LeoVehicleCodec.encode(original.get(key)))==JSON.stringify(LeoVehicleCodec.encode(restored.get(key))),String(original.id)+" "+key)
		assert(original.wheels.size()==restored.wheels.size())
		for i in original.wheels.size():
			assert(original.wheels[i].pivot.is_equal_approx(restored.wheels[i].pivot))
			assert(original.wheels[i].axle==restored.wheels[i].axle)
			assert(original.wheels[i].rotating_groups==restored.wheels[i].rotating_groups)
		count+=1
	var invalid:=LeoVehicleCodec.serialize(catalog.vehicles[0]);invalid.model="../../escape.glb"
	assert(not LeoVehicleLibrary.problems(invalid,"",false).is_empty())
	invalid.model="model.glb";invalid.wheels[0].pivot=[0,"bad",0]
	assert(not LeoVehicleLibrary.problems(invalid,"",false).is_empty())
	print("VEHICLE_CODEC_PASS vehicles=",count," fields=",LeoVehicleCodec.FIELDS.size()," roundtrip_preserves_transforms=true");quit()
