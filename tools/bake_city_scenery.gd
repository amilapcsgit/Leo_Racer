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
var terrain=preload("res://tools/city_terrain_author.gd").new()
var grass_material:ShaderMaterial
func _initialize() -> void:run.call_deferred()
func parts(node: Node3D, transform: Transform3D, result: Array) -> void:
	var pose:=transform*node.transform
	if node is MeshInstance3D and node.mesh:result.append({"mesh":node.mesh,"transform":pose})
	for child in node.get_children():
		if child is Node3D:parts(child,pose,result)
func source_meshes(path: String) -> Array:
	if mesh_cache.has(path):return mesh_cache[path]
	if path.ends_with(".svg"):
		var sign_mesh:=QuadMesh.new();sign_mesh.size=Vector2(6.35,.53)
		var sign_mat:=StandardMaterial3D.new();sign_mat.albedo_texture=load(path);sign_mat.roughness=.9
		sign_mesh.material=sign_mat
		var sign_result:Array=[{"mesh":sign_mesh,"transform":Transform3D.IDENTITY}]
		mesh_cache[path]=sign_result;return sign_result
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
				material.roughness=.83;material.metallic=0.;material.metallic_specular=.28
				if path.contains("module_34"):
					var clay:=ShaderMaterial.new();clay.shader=load("res://shaders/city_roof.gdshader");clay.set_shader_parameter("atlas",material.albedo_texture)
					material=clay
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
			var scale:=float(entry.scale)
			var xyz:Array=entry.get("scale_xyz",[scale,scale,scale])
			var pose:=Transform3D(Basis(Vector3.UP,float(entry.yaw)).scaled_local(Vector3(xyz[0],xyz[1],xyz[2])),Vector3(entry.position[0],entry.position[1],entry.position[2])-center)
			transforms.append(pose*items[part].transform)
			var color: Array=entry.get("tint",[1.,1.,1.,1.]);colors.append(Color(color[0],color[1],color[2],color[3]))
		var node:=MultiMeshInstance3D.new();node.name=path.get_file().get_basename()+"_%d"%part;node.multimesh=multimesh
		Instances.store(node,transforms,colors)
		node.set_meta("asset_id",path);node.set_meta("part_index",part);node.set_meta("part_transform",items[part].transform)
		node.visibility_range_end=1700. if skyline else (180. if entries[0].kind in ["street_prop","shop_sign"] else 520.);node.visibility_range_end_margin=45.
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
			if (int(s/42)+int(side))%4==0:continue
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
	ground.set_shader_parameter("ground_albedo",load("res://assets/materials/Concrete034_2K-JPG_Color.jpg"))
	ground.set_shader_parameter("ground_normal",load("res://assets/materials/Concrete034_2K-JPG_NormalGL.jpg"))
	for z in range(-1400,1400,200):
		for x in range(-940,1260,200):
			add_mesh(node,terrain.tile(x,z,200.,200.),ground,Vector3.ZERO,"Ground_%d_%d"%[x,z])
	var grass:=ShaderMaterial.new();grass.shader=load("res://shaders/city_ground.gdshader");grass.set_shader_parameter("tint",Color("78915b"))
	# Green is part of the shaped terrain; paths and old protected garden stay flat.
	var green_marker:=Node3D.new();green_marker.name="GalleFaceGreen";green_marker.set_meta("protected_bounds",[-840,-520,-615,570]);node.add_child(green_marker);green_marker.owner=node
	rectangle(node,Vector2(120,160),Vector3(-110,-.01,330),grass,"IndependenceGarden")
	var paving:=LeoColomboWorld.pbr_material("res://shaders/paving_pbr.gdshader","PavingStones001")
	for x in [-846.,-614.]:rectangle(node,Vector2(8,1120),Vector3(x,.015,25),paving,"GalleFacePromenade")
	var wall_mesh:=BoxMesh.new();wall_mesh.size=Vector3(.9,1.1,5.05);wall_mesh.material=LeoRaceVisuals.flat_material(Color("938f7f"))
	var wall_transforms:Array[Transform3D]=[]
	for z in range(-1350,1400,5):wall_transforms.append(Transform3D(Basis.IDENTITY,Vector3(-851.-4.*sin(z*.003),.02,z)))
	var wall:=MultiMeshInstance3D.new();wall.name="CoastalSeawall";wall.multimesh=MultiMesh.new();wall.multimesh.mesh=wall_mesh
	wall.multimesh.transform_format=MultiMesh.TRANSFORM_3D;wall.multimesh.instance_count=wall_transforms.size();Instances.store(wall,wall_transforms)
	node.add_child(wall);wall.owner=node
	for z in range(-500,550,135):rectangle(node,Vector2(211,5),Vector3(-731,.035,z),paving,"GreenFootpath")
	rectangle(node,Vector2(4,1060),Vector3(-732,.035,25),paving,"GreenSpine")
	var water:=ShaderMaterial.new();water.shader=load("res://shaders/city_water.gdshader")
	rectangle(node,Vector2(6000,7000),Vector3(-3834,-.42,0),water,"IndianOcean")
	var lake_water:=water.duplicate();lake_water.set_shader_parameter("ocean",false)
	lake_water.set_shader_parameter("deep_color",Color("225e5c"));lake_water.set_shader_parameter("shallow_color",Color("477d68"))
	var lake_surface:=SurfaceTool.new();lake_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a:=float(i)*TAU/96.;var b:=float(i+1)*TAU/96.
		for p in [Vector3(300,-.17,25),Vector3(300+cos(b)*(125.+3.*sin(b*3.)),-.17,25+sin(b)*(125.+3.*sin(b*3.))),Vector3(300+cos(a)*(125.+3.*sin(a*3.)),-.17,25+sin(a)*(125.+3.*sin(a*3.)))]:lake_surface.set_normal(Vector3.UP);lake_surface.add_vertex(p)
	add_mesh(node,lake_surface.commit(),lake_water,Vector3.ZERO,"BeiraInspiredLake")
	var architecture: Node3D=load("res://assets/models/colombo_city/custom_architecture.glb").instantiate()
	architecture.name="PreservedCustomArchitecture";architecture.position=Vector3(-110,0,330);node.add_child(architecture);architecture.owner=node
	for child in architecture.find_children("*","Node",true,false):child.owner=node
	# Persistent skyline grouped spatially, while street detail streams separately.
	# Cheap district silhouettes remain when a detailed cell is not resident.
	var hulls:Dictionary={}
	for parcel in data.parcels:
		var key:=Vector2i(floori(parcel.center[0]/200.),floori(parcel.center[1]/200.))
		if not hulls.has(key):hulls[key]=[]
		hulls[key].append(parcel)
	var hull_mesh:=BoxMesh.new();hull_mesh.size=Vector3.ONE
	var hull_material:=ShaderMaterial.new();hull_material.shader=load("res://shaders/city_building_lod.gdshader");hull_mesh.material=hull_material
	for key in hulls:
		var mm:=MultiMesh.new();mm.mesh=hull_mesh;mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.instance_count=hulls[key].size()
		var transforms:Array[Transform3D]=[];var colors:=PackedColorArray()
		for parcel in hulls[key]:
			transforms.append(Transform3D(Basis(Vector3.UP,parcel.yaw).scaled_local(Vector3(parcel.width*.92,parcel.height*.95,parcel.depth*.85)),Vector3(parcel.center[0],parcel.height*.475,parcel.center[1])))
			colors.append(Color(parcel.tint[0],parcel.tint[1],parcel.tint[2],1.))
		var hull:=MultiMeshInstance3D.new();hull.name="DistrictLOD_%d_%d"%[key.x,key.y];hull.multimesh=mm;Instances.store(hull,transforms,colors)
		hull.visibility_range_begin=360.;hull.visibility_range_begin_margin=35.;hull.visibility_range_end=1500.;hull.visibility_range_end_margin=80.
		hull.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.add_child(hull);hull.owner=node
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
	grass_material=ShaderMaterial.new();grass_material.shader=load("res://shaders/city_grass.gdshader")
	for entry in data.placements:
		if entry.always:continue
		var key:=Vector2i(floori(float(entry.position[0])/200.),floori(float(entry.position[2])/200.))
		if not cell_placements.has(key):cell_placements[key]=[]
		cell_placements[key].append(entry)
	DirAccess.make_dir_recursive_absolute(folder+"/cells")
	# Green cells can contain grass even when they contain no buildings.
	for z in range(-3,3):
		for x in range(-5,-3):
			var key:=Vector2i(x,z)
			if not cell_placements.has(key):cell_placements[key]=[]
	for key in cell_placements:
		var center:=Vector3(key.x*200.+100.,0,key.y*200.+100.)
		var node:=Node3D.new();node.name="CityCell_%d_%d"%[key.x,key.y];node.position=center
		var grouped: Dictionary={}
		for entry in cell_placements[key]:
			if not grouped.has(entry.asset):grouped[entry.asset]=[]
			grouped[entry.asset].append(entry)
		for path in grouped:batch(node,path,grouped[path],center)
		street_details(node,center,key)
		terrain.grass(node,center,key,grass_material)
		var path:=folder+"/cells/%d_%d.scn"%[key.x,key.y];save_scene(node,path)
		cells.append({"id":"%d_%d"%[key.x,key.y],"center":[center.x,center.z],"scene":path,"instances":cell_placements[key].size()})
		node.free();await process_frame
	backdrop(data)
	FileAccess.open(folder+"/cells.json",FileAccess.WRITE).store_string(JSON.stringify({"format":1,"cell_size":200,"cells":cells},"  "))
	var manifest:=definition.metadata;manifest.backdrop="res://assets/tracks/colombo_city/backdrop.scn"
	manifest.exclusions=data.exclusions
	manifest.visual_content={"revision":2,"module_inventory":"res://assets/models/colombo_city/modules.json","recipes":"res://assets/models/colombo_city/recipes.json","parcels":"placements.json","terrain":{"tile_m":200,"grid_m":5,"noise_seed":35,"runtime_generation":false},"shoreline":{"coast_x":-853.,"water_y":-.42,"lake_center":[300,25],"lake_radius":125.,"lake_water_y":-.17}}
	FileAccess.open(folder+"/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
	print("CITY_SCENERY_BAKED | cells=",cells.size()," | shared_model_resources=",mesh_cache.size()," | spatial_batches=",baked_batches)
	plants.free();quit()
