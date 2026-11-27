@tool
extends EditorPlugin
func _enter_tree() -> void:
	if "--bake-neutral260" in OS.get_cmdline_user_args():run.call_deferred()
func controls(node: Node, result: Array[Button]) -> void:
	if node is Button and String(node.text)=="Bake Lightmaps":result.append(node)
	for child in node.get_children():controls(child,result)
func run() -> void:
	await get_tree().create_timer(2.).timeout
	for key in ["KandyPrecinct_mahaweli","KandyPrecinct_tooth_temple","KandyStartArch"]:
		EditorInterface.open_scene_from_path("res://baked/"+key+".tscn")
		await get_tree().create_timer(1.).timeout
		var scene:=EditorInterface.get_edited_scene_root()
		var gi:=scene.get_node("BakedIndirectLight") as LightmapGI
		gi.environment_mode=LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
		gi.environment_custom_color=Color(.5,.5,.5);gi.environment_custom_energy=.35
		gi.environment_custom_sky=null;gi.bounces=2;gi.quality=LightmapGI.BAKE_QUALITY_MEDIUM
		for light in scene.find_children("*","Light3D",true,false):light.light_bake_mode=Light3D.BAKE_DISABLED
		# This is a new isolated project: its baked/ directory contains only copies.
		gi.light_data=LightmapGIData.new()
		ResourceSaver.save(gi.light_data,"res://baked/"+key+".lmbake")
		gi.light_data.take_over_path("res://baked/"+key+".lmbake")
		EditorInterface.get_selection().clear();EditorInterface.get_selection().add_node(gi);EditorInterface.edit_node(gi);EditorInterface.inspect_object(gi)
		await get_tree().create_timer(1.).timeout
		var buttons: Array[Button]=[];controls(EditorInterface.get_base_control(),buttons)
		if buttons.is_empty():push_error("No native lightmap bake control");get_tree().quit(2);return
		print("NEUTRAL_BAKE_BEGIN ",key);buttons[0].pressed.emit()
		await get_tree().create_timer(1.).timeout
		EditorInterface.save_scene()
		if gi.light_data.lightmap_textures.is_empty():push_error("Neutral lightmap missing");get_tree().quit(2);return
		print("NEUTRAL_BAKE_DONE ",key)
	print("NEUTRAL_BAKE_ALL_DONE");get_tree().quit()
