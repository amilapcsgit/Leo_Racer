extends SceneTree
## Authoring-only compression. Exported games read DDS without a compressor.
func _initialize() -> void:
	var folder:="";var maximum:=2048
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicle-folder="):folder=ProjectSettings.globalize_path(arg.trim_prefix("--vehicle-folder="))
		if arg.begins_with("--max-texture="):maximum=clampi(int(arg.trim_prefix("--max-texture=")),128,4096)
	if folder.is_empty():printerr("Specify --vehicle-folder=<folder>");quit(1);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("vehicle.json")))
	var source:=folder.path_join(String(data.get("model","model.glb")))
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	if document.append_from_file(source,state)!=OK:quit(1);return
	var directory:=folder.path_join("optimized");DirAccess.make_dir_recursive_absolute(directory)
	var entries: Array=[];var sizes:=0
	for material_index in state.get_materials().size():
		var material: Material=state.get_materials()[material_index]
		if not material is StandardMaterial3D:continue
		for slot in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture","emission_texture"]:
			var texture: Texture2D=material.get(slot)
			if not texture:continue
			var image:=texture.get_image()
			if not image or image.is_empty():continue
			if image.is_compressed():image.decompress()
			var largest:=maxi(image.get_width(),image.get_height())
			if largest>maximum:image.resize(maxi(1,image.get_width()*maximum/largest),maxi(1,image.get_height()*maximum/largest),Image.INTERPOLATE_LANCZOS)
			image.generate_mipmaps(slot=="normal_texture")
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
			var key: String=(hash.finish().hex_encode()+slot).sha256_text()
			if image.compress(Image.COMPRESS_S3TC,Image.COMPRESS_SOURCE_NORMAL if slot=="normal_texture" else Image.COMPRESS_SOURCE_GENERIC)!=OK:printerr("Texture compression requires the Godot editor toolchain");quit(1);return
			var relative: String="optimized/"+key+".dds"
			if image.save_dds(folder.path_join(relative))!=OK:printerr("DDS authoring unavailable");quit(1);return
			entries.append({"material_index":material_index,"material":material.resource_name,"slot":slot,"file":relative});sizes+=image.get_data_size()
	FileAccess.open(folder.path_join("optimized-textures.json"),FileAccess.WRITE).store_string(JSON.stringify({"format":1,"source_hash":FileAccess.get_sha256(source),"textures":entries},"  ")+"\n")
	print("VEHICLE_TEXTURES_OPTIMIZED count=",entries.size()," gpu_bytes=",sizes," source_glb_unchanged=true");quit()
