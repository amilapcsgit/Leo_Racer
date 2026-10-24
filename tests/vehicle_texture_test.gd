extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var path:=ProjectSettings.globalize_path("res://build/content-vehicles/pony/model.glb")
	var data:=LeoVehicleImporter.optimization(path)
	assert(not data.is_empty())
	var scene:=await LeoAssets.scene_async(path,self);assert(scene!=null)
	var node:=scene.instantiate();var compressed:=0
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(i)
			if material is StandardMaterial3D and material.albedo_texture:
				assert(material.albedo_texture.get_image().is_compressed());compressed+=1
	assert(compressed>0)
	node.free();print("VEHICLE_TEXTURE_TEST PASS compressed_materials=",compressed," runtime_compressor_used=false");quit()
