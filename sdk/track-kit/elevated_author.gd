@tool
extends Node3D
## Standalone, offline authoring. The exported content contains no tool scripts.
@export_dir var source_world := "res://inputs/world"
@export_dir var data_folder := "res://data/kandy"
@export_dir var destination := "res://exported"
@export var track_id := "kandy_lake"
@export var display_name := "Kandy Lake Circuit"
@export var course_revision := 1
@export var procedural_seed := 311
@export_tool_button("1 Import Geography (offline)") var import_action: Callable=import_geography
@export_tool_button("2 Edit Course / refresh Road Generator") var edit_action: Callable=edit_course
@export_tool_button("3 Dress Scenery") var dress_action: Callable=dress_scenery
@export_tool_button("4 Validate") var validate_action: Callable=validate
@export_tool_button("5 Export Track") var export_action: Callable=export_track
var route: Dictionary={}
var geography: Dictionary={}
var corrections: Dictionary={}
var points:=PackedVector3Array()
var length:=0.
var road_half:=9.
var last_error:=""
var terrain_image: Image
var terrain_info: Dictionary
var paint: Dictionary={}
var rng:=RandomNumberGenerator.new()
var building_count:=0
var native_road_meshes:=0
var terrain_clearance: Dictionary={}
var shared_scenery: Dictionary={}
var shared_builder: RefCounted
var terrain_cutter: RefCounted
var landmark_exclusions: Array[PackedVector2Array]=[]
func read(path: String) -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(path))
func fail(message: String) -> bool:last_error=message;push_error(message);return false
func import_geography() -> void:
	var python:=ProjectSettings.globalize_path("res://author-python/python.exe")
	if not FileAccess.file_exists(python):fail("Use the bundled SDK Python to import an archived Earth2Road world");return
	var output: Array=[]
	var result:=OS.execute(python,[ProjectSettings.globalize_path("res://tools/prepare_kandy.py"),"--world",ProjectSettings.globalize_path(source_world),"--output",ProjectSettings.globalize_path(data_folder)],output,true)
	if result!=0:fail("Offline geography import failed: "+str(output));return
	print("GEOGRAPHY_IMPORTED offline=true")
func load_data() -> bool:
	if not FileAccess.file_exists(data_folder.path_join("course.json")):return fail("Import geography and provide course.json first")
	route=read(data_folder.path_join("course.json"));geography=read(data_folder.path_join("geography.json"));points.clear()
	for p in route.points:points.append(Vector3(p[0],p[1],p[2]))
	landmark_exclusions.clear()
	for landmark in geography.get("landmarks",[]):
		var polygon:=PackedVector2Array()
		for p in landmark.footprint:polygon.append(Vector2(p[0],p[1]))
		for expanded in Geometry2D.offset_polygon(polygon,6.):landmark_exclusions.append(expanded)
	length=float(route.length);road_half=float(route.get("width",18.))*.5;rng.seed=procedural_seed
	var corrections_file:=data_folder.path_join("corrections.json")
	corrections=read(corrections_file) if FileAccess.file_exists(corrections_file) else {}
	if not get_node_or_null("SceneryCorrections"):
		var authored:=Node3D.new();authored.name="SceneryCorrections";add_child(authored);authored.owner=self
	terrain_info=read(data_folder.path_join("terrain.json"))
	terrain_image=Image.create_from_data(int(terrain_info.size),int(terrain_info.size),false,Image.FORMAT_RF,FileAccess.get_file_as_bytes(data_folder.path_join("terrain.r32")))
	return true
func sample(distance: float,lane: float=0.) -> Vector3:
	var f:=fposmod(distance,length)/length*points.size();var i:=int(f)
	var t:=(points[(i+1)%points.size()]-points[posmod(i-1,points.size())]).normalized()
	return points[i].lerp(points[(i+1)%points.size()],f-i)+Vector3(-t.z,0,t.x).normalized()*lane
func frame(distance: float) -> Basis:
	var t:=(sample(distance+1)-sample(distance-1)).normalized();var side:=Vector3(-t.z,0,t.x).normalized()
	return Basis(side,side.cross(t).normalized(),-t)
func ground(x: float,z: float) -> float:
	var u:=clampf((x-float(terrain_info.origin[0]))/float(terrain_info.spacing),0,int(terrain_info.size)-1)
	var v:=clampf((z-float(terrain_info.origin[1]))/float(terrain_info.spacing),0,int(terrain_info.size)-1)
	var x0:=floori(u);var z0:=floori(v);var x1:=mini(x0+1,int(terrain_info.size)-1);var z1:=mini(z0+1,int(terrain_info.size)-1)
	return lerpf(lerpf(terrain_image.get_pixel(x0,z0).r,terrain_image.get_pixel(x1,z0).r,u-x0),lerpf(terrain_image.get_pixel(x0,z1).r,terrain_image.get_pixel(x1,z1).r,u-x0),v-z0)
func clear_group(label: String) -> Node3D:
	var old:=get_node_or_null(label)
	if old:old.free()
	var node:=Node3D.new();node.name=label;add_child(node);node.owner=self;return node
func edit_course() -> void:
	if route.is_empty() and not load_data():return
	var path:=get_node_or_null("Route") as Path3D
	if not path:
		path=Path3D.new();path.name="Route";path.curve=Curve3D.new();path.curve.closed=true;path.curve.bake_interval=1.;add_child(path);path.owner=self
		for i in range(0,points.size(),32):
			var tangent:=(points[(i+32)%points.size()]-points[posmod(i-32,points.size())])/6.
			path.curve.add_point(points[i],-tangent,tangent)
	var curve:=path.curve;var count:=points.size();length=curve.get_baked_length();points.clear()
	for i in count:points.append(curve.sample_baked(length*i/count,false))
	length=0.
	for i in points.size():length+=points[i].distance_to(points[(i+1)%points.size()])
	var holder:=clear_group("RoadAuthoring");var manager:=RoadManager.new();manager.auto_refresh=false;holder.add_child(manager)
	var container:=RoadContainer.new();container._auto_refresh=false;container.density=3.;manager.add_child(container)
	shared_builder=load("res://shared_srilanka_scenery.gd").new(self)
	container.material_resource=shared_builder.pbr("surface.asphalt")
	var handles: Array[RoadPoint]=[]
	for i in curve.point_count:
		var point:=RoadPoint.new();point.name="Point%03d"%i;container.add_child(point);point.position=curve.get_point_position(i)
		var tangent:=curve.get_point_out(i).normalized();point.basis=Basis.looking_at(-tangent,Vector3.UP)
		point.prior_mag=curve.get_point_in(i).length();point.next_mag=curve.get_point_out(i).length()
		point.traffic_dir=[RoadPoint.LaneDir.REVERSE,RoadPoint.LaneDir.FORWARD];point.lane_width=road_half;point.shoulder_width_l=0.;point.shoulder_width_r=0.;point.gutter_profile=Vector2.ZERO
		handles.append(point)
	for i in handles.size():handles[i].prior_pt_init=handles[i].get_path_to(handles[posmod(i-1,handles.size())]);handles[i].next_pt_init=handles[i].get_path_to(handles[(i+1)%handles.size()])
	container.rebuild_segments(true)
	var connector:=RoadTerrain3DConnector.new();connector.auto_refresh=false;connector.road_manager=manager;holder.add_child(connector)
	load("res://scene_instances.gd") # Portable instancing helper.
	load("res://resource_baker.gd").new("res://.author-scratch","res://author/").own(holder,self)
	var helpers:=clear_group("CourseHelpers")
	for slot in 6:
		var marker:=Marker3D.new();marker.name="Grid_%d"%(slot+1);helpers.add_child(marker);marker.transform=Transform3D(frame(-8.-floori(slot/2.)*10.),sample(-8.-floori(slot/2.)*10.,-3.2 if slot%2==0 else 3.2))
	for i in 8:
		var marker:=Marker3D.new();marker.name="Checkpoint_Recovery_%d"%i;helpers.add_child(marker);marker.transform=Transform3D(frame(length*(i+.025)/8.),sample(length*(i+.025)/8.))
	load("res://resource_baker.gd").new("res://.author-scratch","res://author/").own(helpers,self)
	print("ROAD_AUTHOR_READY handles=",handles.size()," metres=",length)
func material(color: String) -> StandardMaterial3D:
	if not paint.has(color):
		var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.85;paint[color]=m
	return paint[color]
func box(parent: Node3D,size: Vector3,position_at: Vector3,color: String) -> MeshInstance3D:
	var m:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;m.mesh=mesh;m.position=position_at;m.material_override=material(color);parent.add_child(m);return m
func label(parent: Node3D,text: String,position_at: Vector3,yaw: float=0.,font_path: String="") -> void:
	var node:=Label3D.new();node.text=text;node.font_size=64;node.pixel_size=.018;node.position=position_at;node.rotation.y=yaw;node.modulate=Color("fff5d6");node.outline_size=8;node.no_depth_test=false
	if not font_path.is_empty():var font:=FontFile.new();font.data=FileAccess.get_file_as_bytes(font_path);node.font=font
	parent.add_child(node)
func barriers_and_collision(resident: Node3D) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail_mesh:=BoxMesh.new();rail_mesh.size=Vector3(.35,.8,length/points.size()+.25)
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=rail_mesh;mm.instance_count=points.size()*2
	var mark_mesh:=BoxMesh.new();mark_mesh.size=Vector3(.16,.015,2.5)
	var rail_transforms: Array[Transform3D]=[];var mark_transforms: Array[Transform3D]=[]
	var marks:=MultiMesh.new();marks.transform_format=MultiMesh.TRANSFORM_3D;marks.mesh=mark_mesh;marks.instance_count=int(length/7.)
	for i in points.size():
		var s:=length*i/points.size();var next:=length*(i+1)/points.size()
		for v in [sample(s,-road_half),sample(next,-road_half),sample(s,road_half),sample(s,road_half),sample(next,-road_half),sample(next,road_half)]:surface.add_vertex(v+Vector3.UP*.015)
		for j in 2:
			var body:=StaticBody3D.new();body.transform=Transform3D(frame(s),sample(s,-road_half-.5 if j==0 else road_half+.5)+Vector3.UP*.4)
			var shape:=CollisionShape3D.new();var collision:=BoxShape3D.new();collision.size=rail_mesh.size;shape.shape=collision;body.add_child(shape);resident.add_child(body);mm.set_instance_transform(i*2+j,body.transform);rail_transforms.append(body.transform)
	for i in marks.instance_count:mark_transforms.append(Transform3D(frame(i*7.),sample(i*7.)+Vector3.UP*.035))
	var rails:=MultiMeshInstance3D.new();rails.multimesh=mm;rails.material_override=material("c9c9bb");resident.add_child(rails);load("res://scene_instances.gd").store(rails,rail_transforms)
	var lines:=MultiMeshInstance3D.new();lines.multimesh=marks;lines.material_override=material("eae4c9");resident.add_child(lines);load("res://scene_instances.gd").store(lines,mark_transforms)
	var floor_node:=StaticBody3D.new();var collision:=CollisionShape3D.new();collision.shape=surface.commit().create_trimesh_shape();floor_node.add_child(collision);resident.add_child(floor_node)
func building(parent: Node3D,position_at: Vector3,yaw: float,index: int) -> void:
	for reserved in landmark_exclusions:
		if Geometry2D.is_point_in_polygon(Vector2(position_at.x,position_at.z),reserved):return
	for area in corrections.get("exclude_buildings",[]):
		var polygon:=PackedVector2Array()
		for p in area:polygon.append(Vector2(p[0],p[1]))
		if Geometry2D.is_point_in_polygon(Vector2(position_at.x,position_at.z),polygon):return
	if shared_builder.presentation.is_reserved(position_at,12.):return
	var recipes:=["tea_shop","shophouse","lake_residence","balcony_house","fort_apartments","bakery","market_terrace","commercial_corner","courtyard_shops","coast_cafe","fort_corner","garden_cafe"]
	var scene:=load("res://library/recipes/"+recipes[index%recipes.size()]+".tscn") as PackedScene
	var house:=scene.instantiate() as Node3D;house.position=position_at;house.rotation.y=yaw;parent.add_child(house);building_count+=1
	# A real foundation hides sloping terrain below each retained modular recipe.
	var bounds:=AABB();var first:=true
	for node in house.find_children("*","MeshInstance3D",true,false):
		var local: AABB=(house.global_transform.affine_inverse()*node.global_transform)*node.get_aabb();bounds=local if first else bounds.merge(local);first=false
	var highest:=-INF;var lowest:=INF;var clear:=terrain_cutter
	for x in [bounds.position.x,bounds.end.x]:
		for z in [bounds.position.z,bounds.end.z]:
			var p: Vector3=house.global_transform*Vector3(x,0,z)
			if clear.distance(Vector2(p.x,p.z))<17.:house.free();building_count-=1;return
			for reserved in landmark_exclusions:
				if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),reserved):house.free();building_count-=1;return
			var y:=ground(p.x,p.z);highest=maxf(highest,y);lowest=minf(lowest,y)
	house.position.y=highest+.08-bounds.position.y
	var foundation_height:=maxf(.65,highest-lowest+.65)
	box(house,Vector3(bounds.size.x+.1,foundation_height,bounds.size.z+.1),Vector3(bounds.get_center().x,bounds.position.y-foundation_height*.5,bounds.get_center().z),"999587")
	var shader:=load("res://building_material.gdshader") as Shader
	for node in house.find_children("*","MeshInstance3D",true,false):
		for i in node.mesh.get_surface_count():
			var old: Material=node.get_active_material(i)
			if old is StandardMaterial3D and old.albedo_texture:
				var key:="facade_"+str(old.albedo_texture.get_instance_id())+"_"+str(index%5)
				if not paint.has(key):
					var finish:=ShaderMaterial.new();finish.shader=shader;finish.set_shader_parameter("source_atlas",old.albedo_texture);finish.set_shader_parameter("local_atlas",load("res://art/local_materials_atlas.png"));finish.set_shader_parameter("plaster_tint",[Color("dfd9c4"),Color("b8c7b7"),Color("d8c3a4"),Color("e7ddc4"),Color("c2c9c7")][index%5]);paint[key]=finish
				node.set_surface_override_material(i,paint[key])
func dress_scenery() -> void:
	if route.is_empty():
		if not load_data():return
		edit_course()
	var resident:=clear_group("Resident");var details:=clear_group("Details");building_count=0
	barriers_and_collision(resident)
	for side in [-1.,1.]:
		var paving:=SurfaceTool.new();paving.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in points.size():
			var s:=length*i/points.size();var n:=length*(i+1)/points.size()
			for v in [sample(s,side*road_half),sample(n,side*road_half),sample(s,side*(road_half+8.)),sample(s,side*(road_half+8.)),sample(n,side*road_half),sample(n,side*(road_half+8.))]:paving.set_normal(Vector3.UP);paving.add_vertex(v+Vector3.UP*.025)
		var walk:=MeshInstance3D.new();walk.mesh=paving.commit();walk.material_override=shared_builder.pbr("surface.paving");resident.add_child(walk)
	# Static terrain baking keeps the native extension out of exported tracks.
	var terrain:=get_node_or_null("TerrainAuthoring") as Terrain3D
	if not terrain:
		terrain=Terrain3D.new();terrain.name="TerrainAuthoring";terrain.vertex_spacing=float(terrain_info.spacing);terrain.region_size=Terrain3D.SIZE_128
		var saved:=data_folder.path_join("authored-terrain")
		if DirAccess.dir_exists_absolute(saved):terrain.data_directory=saved
		add_child(terrain);terrain.owner=self
		var images: Array[Image]=[terrain_image,null,null];if terrain.data.get_region_count()==0:terrain.data.import_images(images,Vector3(float(terrain_info.origin[0]),0,float(terrain_info.origin[1])),0,1)
	terrain_cutter=load("res://terrain_corridor.gd").new(points);var cutter=terrain_cutter
	var landscape:=MeshInstance3D.new();landscape.mesh=cutter.cut(terrain.bake_mesh(2),150.,"backdrop");landscape.position.y=-4.;landscape.set_meta("surface_role","terrain_backdrop");var terrain_mat:=ShaderMaterial.new();terrain_mat.shader=load("res://shared/kandy_ground.gdshader");terrain_mat.set_shader_parameter("landscaped",true);terrain_mat.set_shader_parameter("coastal",false);terrain_mat.set_shader_parameter("ground_albedo",load("res://shared/materials/Concrete034_2K-JPG_Color.jpg"));terrain_mat.set_shader_parameter("ground_normal",load("res://shared/materials/Concrete034_2K-JPG_NormalGL.jpg"));landscape.material_override=terrain_mat;landscape.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;resident.add_child(landscape)
	# Decorative near terrain is streamed; only the cheap distant silhouette stays resident.
	# Graded grass verges close the pavement-to-cut-terrain join without covering asphalt.
	for side in [-1.,1.]:
		var verge:=SurfaceTool.new();verge.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in points.size():
			var s:=length*i/points.size();var n:=length*(i+1)/points.size()
			var a:=sample(s,side*17.);var b:=sample(n,side*17.);var c:=sample(s,side*21.);var d:=sample(n,side*21.)
			a.y+=.025;b.y+=.025;c.y=ground(c.x,c.z)-.03;d.y=ground(d.x,d.z)-.03
			for vertex in [a,b,c,c,b,d]:verge.set_normal(Vector3.UP);verge.add_vertex(vertex)
		var join:=MeshInstance3D.new();join.mesh=verge.commit();join.material_override=terrain_mat;join.set_meta("surface_role","terrain_verge");resident.add_child(join)
	var faces: PackedVector3Array=cutter.cut(terrain.bake_mesh(1),20.,"detail").get_faces();terrain_clearance=cutter.report;var patches: Dictionary={}
	for i in range(0,faces.size(),3):
		var center: Vector3=(faces[i]+faces[i+1]+faces[i+2])/3.;var key:=Vector2i(floori(center.x/200),floori(center.z/200))
		if not patches.has(key):patches[key]=PackedVector3Array()
		patches[key].append_array([faces[i],faces[i+1],faces[i+2]])
	for key in patches:
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in patches[key]:tool.add_vertex(vertex)
		tool.generate_normals();var tile:=MeshInstance3D.new();tile.mesh=tool.commit();tile.material_override=terrain_mat;tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tile.set_meta("cell",key);tile.set_meta("surface_role","terrain_detail");details.add_child(tile)
	var connector:=get_node("RoadAuthoring").find_child("*",true,false)
	for node in get_node("RoadAuthoring").find_children("*","RoadTerrain3DConnector",true,false):node.terrain=terrain
	terrain.visible=false;terrain.set_physics_process(false)
	if Engine.is_editor_hint():
		var saved:=data_folder.path_join("authored-terrain");DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saved));terrain.data.save_directory(saved)
	# Lake footprint follows the observed OSM polygon.
	var polygon:=PackedVector2Array()
	for p in geography.lake:polygon.append(Vector2(p[0],p[1]))
	if polygon[0].is_equal_approx(polygon[-1]):polygon.resize(polygon.size()-1)
	var triangles:=Geometry2D.triangulate_polygon(polygon);var water:=SurfaceTool.new();water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:water.set_normal(Vector3.UP);water.set_tangent(Plane(Vector3.RIGHT,1.));water.set_uv(polygon[index]*.05);water.add_vertex(Vector3(polygon[index].x,-1.1,polygon[index].y))
	var lake:=MeshInstance3D.new();lake.name="KandyLakeColomboWater";lake.set_meta("surface_role","water");lake.mesh=water.commit();var water_mat:=ShaderMaterial.new();water_mat.shader=load("res://shared/city_water.gdshader");water_mat.set_shader_parameter("ocean",false);water_mat.set_shader_parameter("deep_color",Color("225e5c"));water_mat.set_shader_parameter("shallow_color",Color("477d68"));water_mat.set_shader_parameter("lake_center",Vector2.ZERO);water_mat.set_shader_parameter("lake_radius",300.);var water_info: Dictionary=read(data_folder.path_join("water.json"));water_mat.set_shader_parameter("shaped_shoreline",true);water_mat.set_shader_parameter("shore_distance",load(data_folder.path_join("shore_distance.png")));water_mat.set_shader_parameter("shore_origin",Vector2(water_info.origin[0],water_info.origin[1]));water_mat.set_shader_parameter("shore_extent",Vector2(water_info.extent[0],water_info.extent[1]));lake.material_override=water_mat;resident.add_child(lake)
	var wall:=clear_group("WallSource");var wall_mesh:=BoxMesh.new();wall_mesh.size=Vector3(.45,.65,length/points.size()+.1)
	var cloud_mesh:=SphereMesh.new();cloud_mesh.radius=.55;cloud_mesh.height=1.1;cloud_mesh.radial_segments=8;cloud_mesh.rings=4
	var walls: Array[Transform3D]=[];var caps: Array[Transform3D]=[]
	for i in range(0,points.size()):
		var s:=length*i/points.size();var p:=sample(s,15.);p.y-=.15;walls.append(Transform3D(frame(s),p+Vector3.UP*.6));caps.append(Transform3D(frame(s).scaled(Vector3(.4,.55,1.)),p+Vector3.UP*1.15))
	batch(resident,wall_mesh,walls,"e4e1d2");batch(resident,cloud_mesh,caps,"f1eee0");wall.free()
	for i in int(length/13.):
		var s:=i*13.;var p:=sample(s,-26.-rng.randf_range(0,2));p.y=ground(p.x,p.z)
		if i%9==0:continue
		building(details,p,atan2(frame(s).x.x,frame(s).x.z),i)
	var source_index:=0
	for b in geography.buildings:
		var center:=Vector2.ZERO
		for p in b.footprint:center+=Vector2(p[0],p[1])
		center/=b.footprint.size()
		if center.length()>1100 or source_index%5!=0:source_index+=1;continue
		var near:=INF
		for i in range(0,points.size(),8):near=minf(near,Vector2(points[i].x,points[i].z).distance_to(center))
		if near>65 and near<240 and ground(center.x,center.y)<45 and not Geometry2D.is_point_in_polygon(center,polygon):building(details,Vector3(center.x,ground(center.x,center.y),center.y),rng.randf()*TAU,source_index)
		source_index+=1
	# Premade roof modules compose the north-shore landmark massing.
	var island:=Node3D.new();island.position=Vector3(30,-.5,10);resident.add_child(island)
	var mound:=CylinderMesh.new();mound.top_radius=12.;mound.bottom_radius=15.;mound.height=1.5;var island_mesh:=MeshInstance3D.new();island_mesh.mesh=mound;island_mesh.material_override=material("798354");island.add_child(island_mesh)
	shared_scenery=shared_builder.dress(details)
	shared_scenery.batching=load("res://static_scenery_batcher.gd").bake(details)
	print("SCENERY_DRESSED buildings=",building_count," terrain=Terrain3D baked=true")
func batch(parent: Node3D,mesh: Mesh,transforms: Array[Transform3D],color: String) -> void:
	if not mesh:fail("Missing source mesh");return
	var groups: Dictionary={}
	for transform in transforms:
		var key:=Vector2i(floori(transform.origin.x/200),floori(transform.origin.z/200))
		if not groups.has(key):groups[key]=[]
		groups[key].append(transform)
	for key in groups:
		var m:=MultiMesh.new();m.transform_format=MultiMesh.TRANSFORM_3D;m.mesh=mesh;m.instance_count=groups[key].size()
		for i in m.instance_count:m.set_instance_transform(i,groups[key][i])
		var node:=MultiMeshInstance3D.new();node.multimesh=m;if not color.is_empty():node.material_override=material(color)
		node.position=Vector3.ZERO;node.set_meta("cell",key);parent.add_child(node)
		var retained: Array[Transform3D]=[]
		for transform in groups[key]:retained.append(transform)
		load("res://scene_instances.gd").store(node,retained)
func validate() -> bool:
	if points.size()<16:return fail("No course")
	if road_half<7.:return fail("Race corridor must be at least 14m wide")
	for i in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()];var c:=points[(i+2)%points.size()]
		var horizontal:=Vector2(b.x-a.x,b.z-a.z).length();var next_horizontal:=Vector2(c.x-b.x,c.z-b.z).length()
		if horizontal<.01 or absf(b.y-a.y)/horizontal>.06005:return fail("Invalid grade")
		if absf((b.y-a.y)/horizontal-(c.y-b.y)/next_horizontal)/((horizontal+next_horizontal)*.5)>.001005:return fail("Vertical radius below 1000m")
		for j in range(i+20,points.size()-20):
			if a.distance_to(points[j])<20.:return fail("Overlapping race corridors")
	print("TRACK_VALIDATED length=",length);return true
func export_track() -> bool:
	if not validate():return false
	if terrain_clearance.is_empty() or not shared_scenery.has("batching"):return fail("Terrain/scenery assembly did not finish; export cancelled")
	var folder:=ProjectSettings.globalize_path(destination).path_join(track_id);DirAccess.make_dir_recursive_absolute(folder)
	var authored_signature:=authoring_fingerprint()+JSON.stringify(Array(points))+str(procedural_seed)
	var prefix:="res://mods/tracks/"+track_id+"/"+authored_signature.sha256_text().left(16)+"/"
	var baker=load("res://resource_baker.gd").new(folder.get_base_dir().path_join(".bake-"+track_id),prefix)
	var resident:=get_node("Resident").duplicate() as Node3D
	native_road_meshes=0
	for node in get_node("RoadAuthoring").find_children("*","MeshInstance3D",true,false):
		if node.mesh:
			var mesh:=MeshInstance3D.new();mesh.mesh=node.mesh;mesh.material_override=node.get_active_material(0);mesh.transform=global_transform.affine_inverse()*node.global_transform;mesh.set_meta("surface_role","race_road");resident.add_child(mesh);native_road_meshes+=1
	if native_road_meshes==0:resident.free();return fail("Road Generator did not produce meshes")
	var scene_path: String=baker.pack(resident,"resident");resident.free()
	var groups: Dictionary={}
	for node in get_node("Details").get_children()+get_node("SceneryCorrections").get_children():
		var key: Vector2i=node.get_meta("cell",Vector2i(floori(node.position.x/200),floori(node.position.z/200)))
		if not groups.has(key):groups[key]=[]
		groups[key].append(node)
	var cells: Array=[]
	for key in groups:
		var root_node:=Node3D.new();var id:="cell_%d_%d"%[key.x,key.y]
		for node in groups[key]:root_node.add_child(node.duplicate())
		var path: String=baker.pack(root_node,id);root_node.free();cells.append({"id":id,"center":[key.x*200+100,key.y*200+100],"scene":path})
	var visual: Texture2D=baker.resource(load("res://art/environment/daylight.png"));var radiance: Texture2D=baker.resource(load("res://art/environment/daylight.exr"))
	if not baker.flush(folder.path_join("scenery.pck")):return fail("Could not write scenery pack")
	var route_points: Array=[]
	for p in points:route_points.append([p.x,p.y,p.z])
	route.points=route_points;route.length=length
	for i in 8:route.features.recoveries[i].distance=length*(i+.025)/8.
	var manifest:={"format":1,"asset_api":3,"id":track_id,"name":display_name,"version":"1.0.1","course_revision":course_revision,"core":{"min":"2.3.1","max_major":2},"surface_profile":"arcade_elevation_v1","world_kind":"external","scene":scene_path,"route":"route.json","dependencies":[],"packs":[{"file":"scenery.pck","sha256":FileAccess.get_sha256(folder.path_join("scenery.pck"))}],"lighting":{"sun_angles":[-62,-120,0],"sun_color":"fff4df","sun_energy":1.25,"ambient_energy":.7,"sky_top":"479bce","sky_horizon":"d0e4dc"}}
	manifest.authored_signage=true
	manifest.lighting.sky_visual_path=visual.resource_path;manifest.lighting.sky_lighting_path=radiance.resource_path;manifest.lighting.sky_horizon_offset=0.
	manifest.lighting.sun_energy=1.1;manifest.lighting.ambient_energy=.55
	for name in ["manifest.json","route.json","cells.json","provenance.json"]:
		var data: Dictionary=manifest if name=="manifest.json" else route if name=="route.json" else {"format":1,"cells":cells} if name=="cells.json" else read(data_folder.path_join("job.json"))
		FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	FileAccess.open(folder.path_join("LICENSE.txt"),FileAccess.WRITE).store_string("Map-derived data: © OpenStreetMap contributors, ODbL 1.0. Terrain: Mapzen Terrarium / SRTM source attribution. Generated material atlas: original Leo Racer artwork. Modular buildings: retained source CC-BY notices in licenses. Terrain3D and Road Generator: MIT, authoring only.\n")
	var preview:=Image.create(640,360,false,Image.FORMAT_RGB8);preview.fill(Color("203d34"))
	for p in points:
		var pixel:=Vector2i(clampi(roundi(p.x*.45+320),1,638),clampi(roundi(p.z*.45+180),1,358))
		for x in range(-1,2):
			for y in range(-1,2):preview.set_pixel(pixel.x+x,pixel.y+y,Color("52d8df"))
	preview.save_png(folder.path_join("preview.png"))
	DirAccess.make_dir_recursive_absolute(folder.path_join("licenses"))
	for name in DirAccess.get_files_at("res://licenses"):
		DirAccess.copy_absolute("res://licenses/"+name,folder.path_join("licenses").path_join(name))
	DirAccess.copy_absolute("res://art/provenance.json",folder.path_join("image-provenance.json"))
	for name in DirAccess.get_files_at("res://art/fonts"):
		if name.ends_with(".txt"):DirAccess.copy_absolute("res://art/fonts/"+name,folder.path_join("licenses").path_join(name))
	for name in ["geography.json","job.json"]:DirAccess.copy_absolute(data_folder.path_join(name),folder.path_join(name))
	var baked_job: Dictionary=read(data_folder.path_join("job.json"))
	var max_grade:=0.;var max_curvature:=0.
	for i in points.size():
		var a:=points[i];var b:=points[(i+1)%points.size()];var c:=points[(i+2)%points.size()]
		var h:=Vector2(b.x-a.x,b.z-a.z).length();var hn:=Vector2(c.x-b.x,c.z-b.z).length();var grade:=(b.y-a.y)/h
		max_grade=maxf(max_grade,absf(grade));max_curvature=maxf(max_curvature,absf(grade-(c.y-b.y)/hn)/((h+hn)*.5))
	baked_job.baked_max_grade=max_grade;baked_job.baked_minimum_vertical_radius_m=1./maxf(max_curvature,.000000001)
	baked_job.terrain_clearance=terrain_clearance;baked_job.shared_scenery=shared_scenery;
	baked_job.baked_length_m=length;baked_job.seed=procedural_seed;baked_job.uniform_3d_samples=points.size();baked_job.tools={"road_generator":"0.9.5","terrain3d":"1.0.2","godot":Engine.get_version_info().string};baked_job.native_road_meshes=native_road_meshes;baked_job.scenery_cells=cells.size();baked_job.export_namespace=prefix
	FileAccess.open(folder.path_join("provenance.json"),FileAccess.WRITE).store_string(JSON.stringify(baked_job,"  "))
	var sums: Dictionary={}
	for name in DirAccess.get_files_at(folder):
		if name!="checksums.json":sums[name]=FileAccess.get_sha256(folder.path_join(name))
	FileAccess.open(folder.path_join("checksums.json"),FileAccess.WRITE).store_string(JSON.stringify(sums,"  "))
	print("ELEVATED_TRACK_EXPORTED ",JSON.stringify({"id":track_id,"length":length,"cells":cells.size(),"buildings":building_count,"native_road_meshes":native_road_meshes,"resources":baker.files.size(),"core_export_invoked":false}));return true

func fingerprint_folder(path: String,hashing: HashingContext) -> void:
	var files:=DirAccess.get_files_at(path);files.sort()
	for name in files:
		if name.ends_with(".import") or name.ends_with(".uid") or name==".gdignore":continue
		var file:=path.path_join(name);hashing.update((file+FileAccess.get_sha256(file)).to_utf8_buffer())
	var directories:=DirAccess.get_directories_at(path);directories.sort()
	for name in directories:
		if not name.begins_with("."):fingerprint_folder(path.path_join(name),hashing)
func authoring_fingerprint() -> String:
	if Engine.is_editor_hint() and EditorInterface.get_edited_scene_root()==self:EditorInterface.save_scene()
	var hashing:=HashingContext.new();hashing.start(HashingContext.HASH_SHA256)
	for path in [data_folder,"res://library","res://art","res://shared","res://assets/models","res://addons/EZ-Tree-Godot-Port"]:fingerprint_folder(path,hashing)
	for name in ["elevated_author.gd","terrain_corridor.gd","shared_srilanka_scenery.gd","static_scenery_batcher.gd","kandy_presentation.gd","resource_baker.gd","building_material.gdshader","billboard_depth.gdshader"]:hashing.update(FileAccess.get_sha256("res://"+name).to_utf8_buffer())
	if not scene_file_path.is_empty():hashing.update(FileAccess.get_sha256(scene_file_path).to_utf8_buffer())
	return hashing.finish().hex_encode()
