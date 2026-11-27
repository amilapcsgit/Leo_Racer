extends SceneTree
## Derivative scenes only. Collision nodes and all authored placements survive.
var destination: String
var track: LeoTrackDefinition
var circuit: LeoCircuit
var fixtures: Array=[]
var fixture_keys: Dictionary={}
var split_meshes:=0
var generated_meshes:=0
var baker
var material_cache: Dictionary={}
var shader_cache: Dictionary={}
var lod_cache: Dictionary={}
var lod_meshes:=0
func _initialize() -> void:run.call_deferred()
func pose(node: Node3D) -> Transform3D:
	var result:=node.transform;var parent:=node.get_parent()
	while parent is Node3D:result=parent.transform*result;parent=parent.get_parent()
	return result
func transforms(node: MultiMeshInstance3D) -> Array[Transform3D]:
	var result: Array[Transform3D]=[]
	var buffer: PackedFloat32Array=node.get_meta("instance_buffer",PackedFloat32Array())
	var stride:=16 if node.multimesh.use_colors else 12
	for i in node.multimesh.instance_count:
		if buffer.size()>=i*stride+12:
			var at:=i*stride
			result.append(Transform3D(Basis(Vector3(buffer[at],buffer[at+4],buffer[at+8]),Vector3(buffer[at+1],buffer[at+5],buffer[at+9]),Vector3(buffer[at+2],buffer[at+6],buffer[at+10])),Vector3(buffer[at+3],buffer[at+7],buffer[at+11])))
		else:result.append(node.multimesh.get_instance_transform(i))
	return result
func add_fixture(point: Vector3,basis: Basis) -> void:
	var key:=str(point.snapped(Vector3.ONE*.05))
	if fixture_keys.has(key):return
	fixture_keys[key]=true
	var projection:=circuit.project(point)
	var target:=circuit.sample(projection.distance,signf(projection.offset)*circuit.width_at(projection.distance)*.22)+Vector3.UP*.05
	fixtures.append({"position":vec(point),"target":vec(target),"yaw":basis.get_euler().y})
func vec(point: Vector3) -> Array:return [point.x,point.y,point.z]
func distance_material(original: Material,near: bool) -> ShaderMaterial:
	var key:=str(original.get_instance_id())+str(near)
	if material_cache.has(key):return material_cache[key]
	var material:=ShaderMaterial.new();var shader:=Shader.new();var code: String
	if original is ShaderMaterial:
		code=original.shader.code
		if code.contains("float road_hash"):code=preload("res://shaders/road_premium.gdshader").code
		elif code.contains("uv=world.xz/1.5"):code=preload("res://shaders/city_road.gdshader").code
		shader.code=code;material.shader=shader
		for field in original.shader.get_shader_uniform_list():
			var value: Variant=original.get_shader_parameter(field.name)
			if value!=null:material.set_shader_parameter(field.name,value)
		if code.contains("base_albedo_gain"):material.set_shader_parameter("base_albedo_gain",.54)
	else:
		code="shader_type spatial; uniform vec4 albedo : source_color; uniform float roughness; uniform float metal; uniform bool vertex_color; void fragment(){ ALBEDO=albedo.rgb*(vertex_color ? COLOR.rgb : vec3(1.));ROUGHNESS=roughness;METALLIC=metal;}"
		shader.code=code;material.shader=shader
		var source:=original as StandardMaterial3D
		material.set_shader_parameter("albedo",source.albedo_color if source else Color.WHITE);material.set_shader_parameter("roughness",source.roughness if source else .7);material.set_shader_parameter("metal",source.metallic if source else 0.);material.set_shader_parameter("vertex_color",source.vertex_color_use_as_albedo if source else false)
	var expression:="length(VERTEX)>150." if near else "length(VERTEX)<=150."
	var pattern:=RegEx.new();pattern.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	code=pattern.sub(code,"void fragment(){ if("+expression+")discard;",false)
	if not shader_cache.has(code):
		shader=Shader.new();shader.code=code;shader_cache[code]=shader
	material.shader=shader_cache[code]
	material_cache[key]=material;return material
func process_instances(node: MultiMeshInstance3D) -> void:
	if not node.multimesh or not node.multimesh.mesh:return
	var poses:=transforms(node);var mesh_size:=node.multimesh.mesh.get_aabb().size
	if mesh_size.distance_to(Vector3(1.6,.14,.4))<.05:
		for item in poses:add_fixture(pose(node)*item.origin,pose(node).basis*item.basis)
		return
	# Coarse roadside furniture remains globally lit; road and paving receive fixture beams.
func emit_vertex(tool: SurfaceTool,arrays: Array,index: int) -> void:
	if arrays[Mesh.ARRAY_NORMAL]!=null and not arrays[Mesh.ARRAY_NORMAL].is_empty():tool.set_normal(arrays[Mesh.ARRAY_NORMAL][index])
	if arrays[Mesh.ARRAY_TANGENT]!=null and not arrays[Mesh.ARRAY_TANGENT].is_empty():
		var tangent: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT];tool.set_tangent(Plane(tangent[index*4],tangent[index*4+1],tangent[index*4+2],tangent[index*4+3]))
	if arrays[Mesh.ARRAY_TEX_UV]!=null and not arrays[Mesh.ARRAY_TEX_UV].is_empty():tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
	if arrays[Mesh.ARRAY_TEX_UV2]!=null and not arrays[Mesh.ARRAY_TEX_UV2].is_empty():tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][index])
	if arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty():tool.set_color(arrays[Mesh.ARRAY_COLOR][index])
	tool.add_vertex(arrays[Mesh.ARRAY_VERTEX][index])
func process_mesh(node: MeshInstance3D) -> void:
	if not node.mesh is ArrayMesh or node.skin or node.mesh.get_blend_shape_count()>0:return
	var bounds:=pose(node)*node.mesh.get_aabb()
	if maxf(bounds.size.x,bounds.size.z)<=32. or bounds.size.y>8.:return
	var path:=String(node.name).to_lower();var parent:=node.get_parent()
	while parent:path+="/"+String(parent.name).to_lower();parent=parent.get_parent()
	if "precinct" in path or "temple" in path or "arch" in path:return
	if String(node.get_meta("surface_role","")) in ["terrain_backdrop","terrain_detail","terrain_verge","water"]:return
	var eligible: bool="bakedcolombocourse" in path
	for surface in node.mesh.get_surface_count():
		var material:=node.get_active_material(surface) as ShaderMaterial
		if material and (material.shader.code.contains("road_hash") or material.shader.code.contains("uv=world.xz*.45")):eligible=true
	if not eligible:return
	if absf(float(circuit.project(bounds.get_center()).offset))>35.:return
	var pieces: Dictionary={}
	for surface in node.mesh.get_surface_count():
		if node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return
		var arrays:=node.mesh.surface_get_arrays(surface)
		if arrays.is_empty():continue
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count:=indices.size() if not indices.is_empty() else vertices.size()
		var groups: Dictionary={}
		for i in range(0,count-2,3):
			var a:=indices[i] if not indices.is_empty() else i;var b:=indices[i+1] if not indices.is_empty() else i+1;var c:=indices[i+2] if not indices.is_empty() else i+2
			var center:=pose(node)*((vertices[a]+vertices[b]+vertices[c])/3.)
			var section:=floori(float(circuit.project(center).distance)/16.)
			if not groups.has(section):groups[section]=PackedInt32Array()
			groups[section].append_array(PackedInt32Array([a,b,c]))
		for section in groups:
			var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for index in groups[section]:emit_vertex(tool,arrays,index)
			tool.index();var mesh:=tool.commit();mesh.surface_set_material(0,distance_material(node.get_active_material(surface),true))
			var child:=MeshInstance3D.new();child.name="RoadLightCell_%d_%d"%[section,surface];child.mesh=mesh;child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.gi_mode=node.gi_mode;child.layers=node.layers|(1<<16);child.visibility_range_end=190.;child.set_meta("street_receiver",true);child.set_meta("polish_applied",true);node.add_child(child);generated_meshes+=1
	for surface in node.mesh.get_surface_count():node.set_surface_override_material(surface,distance_material(node.get_active_material(surface),false))
	node.material_override=null
	node.set_meta("polish_applied",true);node.set_meta("street_receiver",false);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;split_meshes+=1
func walk(node: Node) -> void:
	# Only visit original children. Newly generated cells are already final.
	var children:=node.get_children()
	if node is MultiMeshInstance3D:process_instances(node)
	elif node is MeshInstance3D:process_mesh(node)
	# LOD0 remains the supplied geometry. Only optional distant index buffers
	# change; collision shapes and source resource files are never modified.
	if node is MeshInstance3D and not node.get_meta("street_receiver",false):node.mesh=scenery_lods(node.mesh)
	elif node is MultiMeshInstance3D and node.multimesh:
		var mesh:=scenery_lods(node.multimesh.mesh)
		if mesh!=node.multimesh.mesh:node.multimesh=node.multimesh.duplicate();node.multimesh.mesh=mesh
	for child in children:walk(child)
func scenery_lods(mesh: Mesh) -> Mesh:
	if not mesh is ArrayMesh or mesh.get_blend_shape_count()>0:return mesh
	var id:=mesh.get_instance_id()
	if lod_cache.has(id):return lod_cache[id]
	var vertices:=0
	for surface in mesh.get_surface_count():vertices+=mesh.surface_get_array_len(surface)
	if vertices<512:lod_cache[id]=mesh;return mesh
	var importer:=ImporterMesh.from_mesh(mesh);importer.generate_lods(25.,60.,[])
	var prepared:=importer.get_mesh();lod_cache[id]=prepared;lod_meshes+=1;return prepared
func save_scene(path: String,name: String) -> String:
	var packed:=load(path) as PackedScene
	if not packed:return ""
	var node:=packed.instantiate() as Node3D;walk(node)
	var virtual: String=baker.pack(node,name);node.free();return virtual
func run() -> void:
	destination="res://build/lighting-content/GameAssets"
	var only_track:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--assets="):destination=arg.trim_prefix("--assets=")
		if arg.begins_with("--only-track="):only_track=arg.trim_prefix("--only-track=")
	if LeoAssets.configure(destination)!=OK or LeoAssets.mount_packs()!=OK:quit(2);return
	var reports: Array=[]
	for definition in LeoTrackDefinition.discover():
		if definition.id=="astra_coast":continue
		if not only_track.is_empty() and definition.id!=only_track:continue
		track=definition;circuit=LeoCircuit.new(track);fixtures.clear();fixture_keys.clear();material_cache.clear();split_meshes=0;generated_meshes=0
		shader_cache.clear()
		lod_cache.clear();lod_meshes=0
		if not track.mount():push_error(track.error);quit(2);return
		var disk:=ProjectSettings.globalize_path("res://build/lighting-compiled/"+track.id)
		baker=load("res://sdk/track-kit/resource_baker.gd").new(disk,"res://mods/tracks/"+track.id+"/lighting/")
		baker.retained_prefixes.assign(["res://"])
		var manifest:=track.metadata.duplicate(true)
		manifest.scene=save_scene(manifest.scene,"resident")
		if manifest.scene.is_empty():quit(2);return
		if manifest.has("backdrop"):manifest.backdrop=save_scene(manifest.backdrop,"backdrop")
		var cells_path:=track.folder.path_join("cells.json")
		if FileAccess.file_exists(cells_path):
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cells_path))
			for cell in data.cells:cell.scene=save_scene(cell.scene,"cell_"+String(cell.id))
			FileAccess.open(cells_path,FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
		var target:=track.folder.path_join("lighting.pck")
		if not baker.flush(target):quit(2);return
		manifest.packs.append({"file":"lighting.pck","sha256":FileAccess.get_sha256(target)})
		if track.id=="kandy_lake":
			manifest.course_revision=2;var route:=track.route.duplicate(true);route.boosts=[.09,.165,.33,.495,.57,.71,.84,.975]
			FileAccess.open(track.folder.path_join("route.json"),FileAccess.WRITE).store_string(JSON.stringify(route,"  ")+"\n")
		FileAccess.open(track.folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"  ")+"\n")
		FileAccess.open(track.folder.path_join("illumination.json"),FileAccess.WRITE).store_string(JSON.stringify({"format":1,"fixtures":fixtures,"preserved_placements":true},"  ")+"\n")
		reports.append({"track":track.id,"fixtures":fixtures.size(),"split_meshes":split_meshes,"generated_meshes":generated_meshes,"lod_meshes":lod_meshes,"collision_changed":false})
		print("LIGHTING_TRACK_COMPILED ",reports[-1])
	FileAccess.open(destination.path_join("lighting-compile.json"),FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS","tracks":reports},"  ")+"\n")
	quit()
