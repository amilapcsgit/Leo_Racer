extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:errors.append(message);push_error(message)
func run() -> void:
 var game: Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
 var water: MeshInstance3D
 for node in game.world.find_children("*","MeshInstance3D",true,false):
  if node.get_meta("surface_role","")=="water":water=node
 check(water!=null,"Shared lake exists in exported resident scene")
 if water:
  var material:=water.material_override as ShaderMaterial
  check(material.get_shader_parameter("ocean")==false,"Colombo lake mode retained")
  check(material.get_shader_parameter("shaped_shoreline")==true,"Observed lake shoreline mode retained")
  var tint=material.get_shader_parameter("deep_color")
  check(tint is Color and tint.is_equal_approx(Color("225e5c")),"Lake tint survives shader remap")
  check(material.get_shader_parameter("shore_distance") is Texture2D,"Baked shoreline distance texture retained")
 var terrain:=0;var leaf:=0
 for node in game.world.find_children("*","GeometryInstance3D",true,false):
  if node.get_meta("surface_role","")=="terrain_detail":
   var material:=node.material_override as ShaderMaterial;terrain+=1
   check(material.get_shader_parameter("landscaped")==true,"Grass selector retained")
   check(material.get_shader_parameter("coastal")==false,"Old shoreline sand coordinates disabled")
  if node is MultiMeshInstance3D and String(node.get_meta("shared_asset","")).contains("shade_tree"):
   var mat:=node.multimesh.mesh.surface_get_material(1) as ShaderMaterial
   if mat:
    var tint=mat.get_shader_parameter("tint");check(tint!=null,"Premade foliage tint retained");leaf+=1
 check(terrain>0 and leaf>0,"Loaded terrain and natural tree materials checked")
 var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"terrain_cells":terrain,"tree_batches":leaf}
 FileAccess.open("res://build/kandy/material-retention.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("KANDY_MATERIAL_RETENTION ",JSON.stringify(report));await game.quit_game(0 if errors.is_empty() else 2)
