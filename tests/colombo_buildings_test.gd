extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/colombo_city/recipes.json"))
	assert(data.recipes.size()==12)
	var checks:=0
	for recipe in data.recipes:
		assert(recipe.entrance and recipe.complete_roof)
		var model:Node3D=load(recipe.path).instantiate()
		assert(model.get_child_count()==recipe.components.size())
		var supported_roofs:=0
		for component in recipe.components:
			assert(component.scale_xyz[0]>0 and component.scale_xyz[1]>0 and component.scale_xyz[2]>0)
			if component.role in ["roof_cap","pitched_roof"]:
				assert(component.position[1]>3.1,"A roof cannot be used as a ground-floor building")
				supported_roofs+=1
			if component.role=="storefront":assert(component.position[1]==0.)
		assert(supported_roofs>=2)
		checks+=1;model.free()
	print("COLOMBO_BUILDINGS_PASS recipes=",checks);quit()
