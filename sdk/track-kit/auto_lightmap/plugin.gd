@tool
extends EditorPlugin
func _enter_tree() -> void:
 if "--bake-kandy-precincts" in OS.get_cmdline_user_args():run.call_deferred()
func controls(node: Node,result: Array[Button]) -> void:
 if node is Button and String(node.text).contains("Bake"):result.append(node)
 for child in node.get_children():controls(child,result)
func run() -> void:
 await get_tree().create_timer(3.).timeout
 var paths: Array[String]=[]
 for name in DirAccess.get_files_at("res://baked"):
  if name.ends_with(".tscn"):
   var requested:=""
   for argument in OS.get_cmdline_user_args():
    if argument.begins_with("--precinct="):requested=argument.trim_prefix("--precinct=")
   if requested.is_empty() or name==requested+".tscn":paths.append("res://baked/"+name)
 paths.sort()
 for path in paths:
  EditorInterface.open_scene_from_path(path)
  await get_tree().create_timer(2.).timeout
  var root:=EditorInterface.get_edited_scene_root()
  var gi:=root.get_node("BakedIndirectLight") as LightmapGI
  EditorInterface.get_selection().clear();EditorInterface.get_selection().add_node(gi);EditorInterface.edit_node(gi);EditorInterface.inspect_object(gi)
  await get_tree().create_timer(1.).timeout
  var buttons: Array[Button]=[];controls(EditorInterface.get_base_control(),buttons)
  var invoked:=false
  for button in buttons:
   print("BAKE_CONTROL ",button.text," visible=",button.is_visible_in_tree())
   if String(button.text)=="Bake Lightmaps":
    print("NATIVE_LIGHTMAP_BEGIN ",path);button.pressed.emit();invoked=true;break
  if not invoked:push_error("Native LightmapGI bake button unavailable");get_tree().quit(2);return
  await get_tree().create_timer(2.).timeout
  EditorInterface.save_scene()
  print("NATIVE_LIGHTMAP_DONE ",path," textures=",gi.light_data.lightmap_textures.size())
  if gi.light_data.lightmap_textures.is_empty():push_error("Native lightmap bake produced no textures");get_tree().quit(2);return
 print("NATIVE_LIGHTMAP_ALL_DONE")
 get_tree().quit()
