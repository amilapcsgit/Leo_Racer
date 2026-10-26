extends RefCounted
## Converts authoring resources to a self-contained, shared, script-free graph.
var folder: String
var namespace_path: String
var files: Dictionary={}
var cache: Dictionary={}
var save_serial:=0
func _init(destination: String, prefix: String) -> void:
	folder=destination;namespace_path=prefix
	DirAccess.make_dir_recursive_absolute(folder.path_join("resources"))
func resource(original: Resource) -> Resource:
	if not original:return null
	if original.resource_path.begins_with(namespace_path):return original
	var key:=original.get_instance_id()
	if cache.has(key):return cache[key]
	var value: Resource
	if original is Texture2D:
		var image: Image=original.get_image()
		if not image:return original
		if original.resource_path.get_extension().to_lower()=="exr" and image.is_compressed():image.decompress()
		var hdr: bool=image.get_format() in [Image.FORMAT_RF,Image.FORMAT_RGF,Image.FORMAT_RGBF,Image.FORMAT_RGBAF,Image.FORMAT_RH,Image.FORMAT_RGH,Image.FORMAT_RGBH,Image.FORMAT_RGBAH,Image.FORMAT_RGBE9995]
		if not image.is_compressed() and not hdr:
			var panorama: bool=image.get_width()==4096 and image.get_height()==2048
			if maxi(image.get_width(),image.get_height())>2048 and not panorama:image.resize(2048*image.get_width()/maxi(image.get_width(),image.get_height()),2048*image.get_height()/maxi(image.get_width(),image.get_height()))
			image.generate_mipmaps();image.compress(Image.COMPRESS_S3TC)
		elif not image.has_mipmaps():image.generate_mipmaps()
		value=ImageTexture.create_from_image(image)
	elif original is MultiMesh:
		var instances:=MultiMesh.new()
		instances.transform_format=original.transform_format
		instances.use_colors=original.use_colors;instances.use_custom_data=original.use_custom_data
		instances.mesh=resource(original.mesh);instances.instance_count=original.instance_count
		if not original.buffer.is_empty():instances.buffer=original.buffer
		instances.visible_instance_count=original.visible_instance_count
		value=instances
	else:
		value=original.duplicate(false)
		cache[key]=value
		if value is LightmapGIData:
			var lightmaps: Array[TextureLayered]=[];var masks: Array[TextureLayered]=[]
			for texture in original.lightmap_textures:lightmaps.append(resource(texture))
			for texture in original.shadowmask_textures:masks.append(resource(texture))
			value.lightmap_textures=lightmaps;value.shadowmask_textures=masks
		elif value is TextureLayered:
			var layers: Array[Image]=[]
			for index in original.get_layers():
				var layer: Image=original.get_layer_data(index)
				if original.resource_path.get_extension().to_lower()=="exr" and layer.is_compressed():layer.decompress()
				layers.append(layer)
			var array:=Texture2DArray.new();array.create_from_images(layers);value=array
		elif value is ArrayMesh:
			for i in value.get_surface_count():value.surface_set_material(i,resource(original.surface_get_material(i)))
		elif value is StandardMaterial3D:
			for field in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture","emission_texture"]:
				if original.get(field):value.set(field,resource(original.get(field)))
		elif value is ShaderMaterial:
			value.shader=resource(original.shader)
			for property in original.shader.get_shader_uniform_list():
				var parameter: Variant=original.get_shader_parameter(property.name)
				if parameter!=null:value.set_shader_parameter(property.name,resource(parameter) if parameter is Resource else parameter)
		elif value is MultiMesh:value.mesh=resource(original.mesh)
		# Sky, Environment and other native bake resources can retain nested textures.
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name!="script":
				var child: Variant=value.get(property.name)
				if child is Resource:value.set(property.name,resource(child))
	var local:=folder.path_join("resources/resource_%06d.res"%save_serial);save_serial+=1
	if ResourceSaver.save(value,local)!=OK:push_error("Could not save "+local);return null
	var virtual:=namespace_path+"resources/"+FileAccess.get_sha256(local)+".res"
	files[virtual]=local;value.take_over_path(virtual);cache[key]=value
	return value
func prepare(node: Node) -> void:
	node.scene_file_path="";node.set_script(null)
	if node is MeshInstance3D:
		node.mesh=resource(node.mesh)
		if node.material_override:node.material_override=resource(node.material_override)
		for i in node.get_surface_override_material_count():
			if node.get_surface_override_material(i):node.set_surface_override_material(i,resource(node.get_surface_override_material(i)))
	if node is MultiMeshInstance3D:
		node.multimesh=resource(node.multimesh)
		if node.material_override:node.material_override=resource(node.material_override)
	if node is Label3D and node.font:node.font=resource(node.font)
	if node is LightmapGI and node.light_data:
		node.light_data=resource(node.light_data);node.environment_custom_sky=null;node.environment_mode=LightmapGI.ENVIRONMENT_MODE_DISABLED
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name!="script":
			var value: Variant=node.get(property.name)
			if value is Resource:node.set(property.name,resource(value))
	for child in node.get_children():prepare(child)
func flatten(node: Node) -> Node:
	var fresh: Node=ClassDB.instantiate(node.get_class())
	if not String(node.name).is_empty():fresh.name=node.name
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["script","owner","scene_file_path","name"]:
			fresh.set(property.name,node.get(property.name))
	for child in node.get_children():fresh.add_child(flatten(child))
	return fresh
func pack(node: Node,name: String) -> String:
	# Reconstruct nodes to remove hidden PackedScene instance-state dependencies.
	var flat:=flatten(node);prepare(flat);own(flat,flat)
	var scene:=PackedScene.new();scene.pack(flat)
	var path:=folder.path_join(name+".scn");ResourceSaver.save(scene,path);flat.free()
	var virtual:=namespace_path+name+".scn";files[virtual]=path
	return virtual
func own(node: Node,owner_node: Node) -> void:
	for child in node.get_children():child.owner=owner_node;own(child,owner_node)
func flush(destination: String) -> bool:
	var packer:=PCKPacker.new()
	if packer.pck_start(destination)!=OK:return false
	for virtual in files:
		if packer.add_file(virtual,files[virtual])!=OK:return false
	return packer.flush()==OK
