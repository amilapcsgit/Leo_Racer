extends SceneTree
const Instances=preload("res://scripts/content/scene_instances.gd")
var folder:="res://assets/tracks/colombo_city"
var mesh_cache: Dictionary={}
var plants:=LeoSriLankaWorld.new()
var cell_placements: Dictionary={}
var cells: Array=[]
var baked_batches:=0
var definition: LeoTrackDefinition
var route: LeoCircuit
var metal: StandardMaterial3D
var lamp: StandardMaterial3D
func _initialize() -> void:run.call_deferred()
func parts(node: Node3D, transform: Transform3D, result: Array) -> void:
	var pose:=transform*node.transform
	if node is MeshInstance3D and node.mesh:result.append({"mesh":node.mesh,"transform":pose})
	for child in node.get_children():
		if child is Node3D:parts(child,pose,result)
func source_meshes(path: String) -> Array:
	if mesh_cache.has(path):return mesh_cache[path]
	var scene:=load(path) as PackedScene
	if not scene:push_error("Missing premade scenery: "+path);quit(1);return []
	var instance:=scene.instantiate() as Node3D;var result: Array=[]
	if path.contains("/srilanka/phoenix"):
		for item in plants._load_model(path.get_file().get_basename()):result.append({"mesh":item[0],"transform":item[1]})
	else:parts(instance,Transform3D.IDENTITY,result)
	instance.free()
	DirAccess.make_dir_recursive_absolute("res://assets/models/colombo_city/meshes")
	for i in result.size():
		var mesh: Mesh=result[i].mesh.duplicate()
		for surface in mesh.get_surface_count():
			var material:=mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				material=material.duplicate();material.vertex_color_use_as_albedo=true
				mesh.surface_set_material(surface,material)
		var target:="res://assets/models/colombo_city/meshes/%s-%d.res"%[path.get_file().get_basename(),i]
		ResourceSaver.save(mesh,target,ResourceSaver.FLAG_CHANGE_PATH|ResourceSaver.FLAG_COMPRESS)
		result[i].mesh=mesh
	mesh_cache[path]=result;return result
func batch(parent: Node3D,path: String, entries: Array, center: Vector3, skyline: bool=false) -> void:
	var items:=source_meshes(path)
	for part in items.size():
		var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true;multimesh.mesh=items[part].mesh;multimesh.instance_count=entries.size()
		var transforms: Array[Transform3D]=[];var colors:=PackedColorArray()
		for i in entries.size():
			var entry: Dictionary=entries[i]
			var scale:=float(entry.scale);var pose:=Transform3D(Basis(Vector3.UP,float(entry.yaw)).scaled(Vector3.ONE*scale),Vector3(entry.position[0],entry.position[1],entry.position[2])-center)
			transforms.append(pose*items[part].transform)
			var color: Array=entry.get("tint",[1.,1.,1.,1.]);colors.append(Color(color[0],color[1],color[2],color[3]))
		var node:=MultiMeshInstance3D.new();node.name=path.get_file().get_basename()+"_%d"%part;node.multimesh=multimesh
		Instances.store(node,transforms,colors)
		node.set_meta("asset_id",path);node.set_meta("part_index",part);node.set_meta("part_transform",items[part].transform)
		node.visibility_range_end=1700. if skyline else 720.;node.visibility_range_end_margin=60.
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if skyline else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(node);node.owner=parent;baked_batches+=1
func save_scene(node: Node3D,path: String) -> void:
	var packed:=PackedScene.new();packed.pack(node)
	if ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)!=OK:push_error("Cannot save scenery "+path);quit(1)
func add_mesh(parent: Node3D,mesh: Mesh,material: Material,position: Vector3,label: String) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.material_override=material;node.position=position;parent.add_child(node);node.owner=parent;return node
func box(parent: Node3D,size: Vector3,position: Vector3,material: Material,label: String) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size;return add_mesh(parent,mesh,material,position,label)
func rectangle(parent: Node3D,size: Vector2,position: Vector3,material: Material,label: String) -> void:
	var mesh:=PlaneMesh.new();mesh.size=size;add_mesh(parent,mesh,material,position,label)
func add_sign(parent: Node3D,key: String,position: Vector3,yaw: float) -> void:
	var material:=StandardMaterial3D.new();material.albedo_texture=load("res://assets/signs/colombo/"+key+".svg");material.roughness=.8
	var quad:=QuadMesh.new();quad.size=Vector2(5.4,1.35)
	var sign:=add_mesh(parent,quad,material,position,key);sign.rotation.y=yaw
	var backing:=box(parent,Vector3(5.5,1.45,.12),position-Vector3(sin(yaw),0,cos(yaw))*.08,metal,"SignBack");backing.rotation.y=yaw
	for x in [-2.,2.]:box(parent,Vector3(.12,2.8,.12),position+Basis(Vector3.UP,yaw)*Vector3(x,-2.,-.08),metal,"SignPost")
func street_details(parent: Node3D,center: Vector3,key: Vector2i) -> void:
	var pole_mesh:=BoxMesh.new();pole_mesh.size=Vector3(.16,6.8,.16);pole_mesh.material=metal
	var head_mesh:=BoxMesh.new();head_mesh.size=Vector3(1.6,.14,.4);head_mesh.material=lamp
	var poles: Array[Transform3D]=[];var heads: Array[Transform3D]=[]
	for s in range(0,int(route.length),42):
		for side in [-1.,1.]:
			var p:=route.sample(s,side*(route.width_at(s)*.5+3.4))
			if Vector2i(floori(p.x/200.),floori(p.z/200.))!=key:continue
			var t:=route.direction(s);var basis:=Basis(Vector3.UP,atan2(t.x,t.z))
			poles.append(Transform3D(basis,p-center+Vector3.UP*3.4));heads.append(Transform3D(basis,p-center+Vector3.UP*6.7+basis.x*.7))
	for pair in [[pole_mesh,poles],[head_mesh,heads]]:
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=pair[0];mm.instance_count=pair[1].size()
		for i in mm.instance_count:mm.set_instance_transform(i,pair[1][i])
		var node:=MultiMeshInstance3D.new();node.multimesh=mm;Instances.store(node,pair[1]);parent.add_child(node);node.owner=parent
	# Opaque road signs, well outside the race barrier.
	var sign_names:=["galle-face","colombo-fort","city-centre","lotus-tower","beira-lake"]
	for i in 20:
		var s:=route.length*(float(i)+.3)/20.;var p:=route.sample(s,route.width_at(s)*.5+5.6)
		if Vector2i(floori(p.x/200.),floori(p.z/200.))==key:
			var t:=route.direction(s);add_sign(parent,sign_names[int(float(i)/4.)],p-center+Vector3.UP*4.2,atan2(-t.x,-t.z))
	# Lake handrails reuse extracted premade railing pieces; posts seat them.
	for i in 250:
		var a:=float(i)*TAU/250.;var p:=Vector3(300+cos(a)*135.,.41,25+sin(a)*135.)
		if Vector2i(floori(p.x/200.),floori(p.z/200.))==key:box(parent,Vector3(.10,.82,.10),p-center,metal,"LakeRailPost")
func backdrop(data: Dictionary) -> void:
	var node:=Node3D.new();node.name="ColomboLandmarksAndCoast"
	var ground:=ShaderMaterial.new();ground.shader=load("res://shaders/city_ground.gdshader")
	rectangle(node,Vector2(2150,2800),Vector3(225,-.075,0),ground,"CityGround")
	var grass:=ShaderMaterial.new();grass.shader=load("res://shaders/city_ground.gdshader");grass.set_shader_parameter("tint",Color("78915b"))
	rectangle(node,Vector2(225,1090),Vector3(-727.5,-.01,25),grass,"GalleFaceGreen")
	rectangle(node,Vector2(120,160),Vector3(-110,-.01,330),grass,"IndependenceGarden")
	var paving:=LeoColomboWorld.pbr_material("res://shaders/paving_pbr.gdshader","PavingStones001")
	for x in [-846.,-614.]:rectangle(node,Vector2(8,1120),Vector3(x,.015,25),paving,"GalleFacePromenade")
	var water:=ShaderMaterial.new();water.shader=load("res://shaders/astra_water.gdshader")
	rectangle(node,Vector2(4000,5000),Vector3(-2850,-.42,0),water,"IndianOcean")
	var lake_surface:=SurfaceTool.new();lake_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a:=float(i)*TAU/96.;var b:=float(i+1)*TAU/96.
		for p in [Vector3(300,.0,25),Vector3(300+cos(b)*125,.0,25+sin(b)*125),Vector3(300+cos(a)*125,.0,25+sin(a)*125)]:lake_surface.set_normal(Vector3.UP);lake_surface.add_vertex(p)
	add_mesh(node,lake_surface.commit(),water,Vector3.ZERO,"BeiraInspiredLake")
	var architecture: Node3D=load("res://assets/models/colombo_city/custom_architecture.glb").instantiate()
	architecture.name="PreservedCustomArchitecture";architecture.position=Vector3(-110,0,330);node.add_child(architecture);architecture.owner=node
	for child in architecture.find_children("*","Node",true,false):child.owner=node
	# Persistent skyline grouped spatially, while street detail streams separately.
	var skyline: Dictionary={}
	for entry in data.placements:
		if not entry.always:continue
		var p:=Vector3(entry.position[0],0,entry.position[2]);var bin:=str(floori(p.x/200.))+"_"+str(floori(p.z/200.))+"|"+String(entry.asset)
		if not skyline.has(bin):skyline[bin]=[]
		skyline[bin].append(entry)
	for entries in skyline.values():batch(node,entries[0].asset,entries,Vector3.ZERO,true)
	save_scene(node,folder+"/backdrop.scn");node.free()
func run() -> void:
	for track in LeoTrackDefinition.discover():
		if track.id=="colombo_city":definition=track
	route=LeoCircuit.new(definition)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/placements.json"))
	metal=LeoRaceVisuals.flat_material(Color("35423d"),.5);metal.roughness=.72
	lamp=LeoRaceVisuals.flat_material(Color("e1deca"),.1);lamp.roughness=.65
	for entry in data.placements:
		if entry.always:continue
		var key:=Vector2i(floori(float(entry.position[0])/200.),floori(float(entry.position[2])/200.))
		if not cell_placements.has(key):cell_placements[key]=[]
		cell_placements[key].append(entry)
	DirAccess.make_dir_recursive_absolute(folder+"/cells")
	for key in cell_placements:
		var center:=Vector3(key.x*200.+100.,0,key.y*200.+100.)
		var node:=Node3D.new();node.name="CityCell_%d_%d"%[key.x,key.y];node.position=center
		var grouped: Dictionary={}
		for entry in cell_placements[key]:
			if not grouped.has(entry.asset):grouped[entry.asset]=[]
			grouped[entry.asset].append(entry)
		for path in grouped:batch(node,path,grouped[path],center)
		street_details(node,center,key)
		var path:=folder+"/cells/%d_%d.scn"%[key.x,key.y];save_scene(node,path)
		cells.append({"id":"%d_%d"%[key.x,key.y],"center":[center.x,center.z],"scene":path,"instances":cell_placements[key].size()})
		node.free();await process_frame
	backdrop(data)
	FileAccess.open(folder+"/cells.json",FileAccess.WRITE).store_string(JSON.stringify({"format":1,"cell_size":200,"cells":cells},"  "))
	var manifest:=definition.metadata;manifest.backdrop="res://assets/tracks/colombo_city/backdrop.scn"
	manifest.exclusions=data.exclusions
	FileAccess.open(folder+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("CITY_SCENERY_BAKED | cells=",cells.size()," | shared_model_resources=",mesh_cache.size()," | spatial_batches=",baked_batches)
	plants.free();quit()
