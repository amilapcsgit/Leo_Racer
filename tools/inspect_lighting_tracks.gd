extends SceneTree
var records: Array=[]
func _initialize() -> void:run.call_deferred()
func walk(node: Node,path: String) -> void:
	path+="/"+String(node.name)
	var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh else null
	if mesh:
		var materials: Array=[]
		for index in mesh.get_surface_count():
			var material: Material=node.get_active_material(index) if node is MeshInstance3D else node.material_override if node.material_override else mesh.surface_get_material(index)
			materials.append({"name":material.resource_name if material else "","shader":material.shader.code if material is ShaderMaterial else "","path":material.resource_path if material else ""})
		records.append({"node":path,"kind":node.get_class(),"bounds":str(mesh.get_aabb()),"metadata":node.get_meta_list(),"shared_asset":node.get_meta("shared_asset",""),"materials":materials})
	for child in node.get_children():walk(child,path)
func run() -> void:
	var base:=ProjectSettings.globalize_path("res://build/Preview-2.6.0/GameAssets")
	LeoAssets.configure(base);LeoAssets.mount_packs()
	for key in ["kandy_lake","colombo_city"]:
		var folder:=base.path_join("tracks/"+key);var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
		for pack in manifest.get("packs",[]):ProjectSettings.load_resource_pack(folder.path_join(pack.file),false)
		var scene:=load(manifest.scene) as PackedScene;var node:=scene.instantiate();records.clear();walk(node,"")
		FileAccess.open("res://build/inspect-lighting-"+key+".json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
		node.free()
	quit()
