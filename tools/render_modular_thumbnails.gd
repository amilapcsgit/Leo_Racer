extends SceneTree
func _initialize() -> void: run.call_deferred()
func bounds(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in node.find_children("*","MeshInstance3D",true,false):
		var box: AABB = (node.global_transform.affine_inverse()*child.global_transform)*child.get_aabb()
		result=box if not found else result.merge(box)
		found=true
	return result
func run() -> void:
	var data := GarageCatalog.shared()
	var selector := load("res://scenes/ModularCarSelector.tscn").instantiate() as ModularCarSelector
	selector.configure(data,&"hedgehog",&"blue",true)
	root.add_child(selector)
	selector.size=Vector2(1600,900)
	selector.set_process(false)
	selector.get_node("SubViewportContainer").stretch=false
	selector.viewport.size=Vector2i(512,320)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/art/garage/thumbnails"))
	for v in data.vehicles:
		selector.set_selection(&"hedgehog",v.id)
		selector.camera.position=v.preview_target+Vector3(-.6,.35,-1).normalized()*v.preview_distance
		selector.camera.look_at(v.preview_target)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://assets/art/garage/thumbnails/vehicle_%s.png"%v.id
		selector.viewport.get_texture().get_image().save_png(path)
		# Import occurs after this process; append the serialized texture reference.
		write_reference(v.resource_path,"thumbnail",path)
	for d in data.drivers:
		selector.viewport.size=Vector2i(384,384)
		if is_instance_valid(selector.assembly): selector.assembly.free()
		selector.assembly=d.standing_model.instantiate()
		selector.showroom.add_child(selector.assembly)
		VehicleAssembler.bind_albedo(selector.assembly,d.material_name,d.material_albedo) if d.material_albedo else null
		var box := bounds(selector.assembly)
		var target := box.position+Vector3(box.size.x*.5,box.size.y*.72,box.size.z*.5)
		selector.camera.position=target+Vector3(-.16,.06,-1).normalized()*maxf(.8,box.size.y*1.1)
		selector.camera.look_at(target)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://assets/art/garage/thumbnails/driver_%s.png"%d.id
		selector.viewport.get_texture().get_image().save_png(path)
		write_reference(d.resource_path,"portrait",path)
	selector.queue_free()
	await process_frame
	print("MODULAR_THUMBNAILS_COMPLETE | 16 cars + 6 drivers")
	quit()
func write_reference(resource_path: String, property: String, texture_path: String) -> void:
	var text := FileAccess.get_file_as_string(resource_path)
	var reference := "[ext_resource type=\"Texture2D\" path=\"%s\" id=\"thumb\"]\n"%texture_path
	if not text.contains('id="thumb"'):
		var first := text.find("[sub_resource")
		if first<0: first=text.find("[resource]")
		text=text.insert(first,reference+"\n")
		text+="%s = ExtResource(\"thumb\")\n"%property
	FileAccess.open(resource_path,FileAccess.WRITE).store_string(text)
