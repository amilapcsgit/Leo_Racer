extends SceneTree
## Offline authoring step: Terrain3D maps and EZ Tree meshes are saved resources.
func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	for pair in [["Color","AlbedoHeight"],["NormalGL","NormalRoughness"]]:
		var image := Image.load_from_file("res://assets/materials/Concrete034_2K-JPG_%s.jpg"%pair[0])
		image.resize(1024,1024,Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		image.save_png("res://assets/materials/shore_%s.png"%pair[1])
	DirAccess.make_dir_recursive_absolute("res://assets/terrain")
	var terrain := Terrain3D.new()
	terrain.region_size = 256
	terrain.vertex_spacing = 1.0
	terrain.collision_mode = 0
	root.add_child(terrain)
	terrain.collision.mode = Terrain3DCollision.DISABLED
	await process_frame
	var height := Image.create(256,512,false,Image.FORMAT_RF)
	var colors := Image.create(256,512,false,Image.FORMAT_RGBA8)
	for z in range(512):
		for x in range(256):
			var wx := float(x-256)
			var wz := float(z-256)
			var edge := smoothstep(-151.0,-134.0,wx)*(1.0-smoothstep(-129.0,-124.0,wx))
			var dune := .35+pow(maxf(0.0,sin(wz*.046+wx*.16)),2.0)*1.2
			height.set_pixel(x,z,Color(lerpf(-3.0,dune,edge),0,0,1))
			colors.set_pixel(x,z,Color("e4bd83"))
	var maps: Array[Image] = [height,null,colors]
	terrain.data.import_images(maps,Vector3(-256,0,-256),0.0,1.0)
	terrain.data.save_directory("res://assets/terrain")
	terrain.queue_free()
	for variant in range(3):
		var tree := EZTree.new()
		tree.rng_seed = 2026+variant*71
		tree.branch_levels = 2
		tree.branch_children = PackedInt32Array([5,4,2,0])
		tree.bark_tint = Color("91704e")
		tree.leaf_tint = Color("77ab63")
		root.add_child(tree)
		tree.generate()
		var saved := ResourceSaver.save(tree.get_tree_mesh(),"res://assets/models/colombo/shade_tree_%d.res"%variant)
		print("EZ_TREE_BAKED ",variant," ",saved)
		tree.queue_free()
	await process_frame
	print("COLOMBO_ENVIRONMENT_BAKED")
	quit()
