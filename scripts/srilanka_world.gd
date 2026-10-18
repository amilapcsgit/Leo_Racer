class_name LeoSriLankaWorld
extends LeoColomboWorld
## Presentation only: no physics bodies, checkpoint edits, or race-state changes.
const SRI := "res://assets/models/srilanka/"
const ART := "res://assets/art/srilanka/"
const PORTRAITS := ["portrait_lotus","portrait_leo","portrait_gp","portrait_coast"]
const WIDE := ["coast_race","lotus_coast","colombo_gp","chase_coast"]
var advertising_faces := 0
var national_flags := 0
var transport_count := 0
var transport_placements: Array[Vector3] = []
var plant_materials: Dictionary = {}

func setup(track: LeoCircuit,p: LeoArtProfile) -> void:
	name = "SriLanka2026"
	profile=p
	circuit=track
	_terrain()
	_foliage()
	_boundaries()
	_prom_details()
	_flush()
	_reflections()
	print("SRI_WORLD_READY | instances=%d | adverts=%d | flags=%d | transport=%d"%[count,advertising_faces,national_flags,transport_count])

func _load_model(key: String) -> Array:
	var base_key:=key.get_slice(":",0)
	if not ResourceLoader.exists(SRI+base_key+".glb"):return super._load_model(key)
	if models.has(key):return models[key]
	var scene: Node3D=load(SRI+base_key+".glb").instantiate()
	var entries: Array=[]
	_collect_sri(scene,Transform3D.IDENTITY,entries,key)
	scene.free()
	models[key]=entries
	return entries

func _collect_sri(node: Node,parent: Transform3D,entries: Array,key: String) -> void:
	var tr:=parent
	if node is Node3D:tr=parent*node.transform
	if node is MeshInstance3D:
		var mesh:=node.mesh.duplicate() as Mesh
		for i in mesh.get_surface_count():
			var source:=mesh.surface_get_material(i) as StandardMaterial3D
			var shared_key: String=("phoenix" if key.begins_with("phoenix") else key.trim_suffix("_lod"))+":"+(source.resource_name.get_slice(".",0) if source else "")
			var plant: bool=key.begins_with("phoenix") or key.begins_with("banana")
			if plant and plant_materials.has(shared_key):
				mesh.surface_set_material(i,plant_materials[shared_key])
				continue
			if source and key.contains(":") and source.resource_name=="Body_01":
				var painted:=source.duplicate() as StandardMaterial3D
				painted.albedo_texture=null
				painted.albedo_color=Color(key.get_slice(":",1))
				painted.metallic=.45
				painted.roughness=.3
				mesh.surface_set_material(i,painted)
			if source and (source.resource_name.contains("Leaf") or key.begins_with("banana")):
				var leaf:=ShaderMaterial.new()
				leaf.shader=load("res://shaders/sri_foliage.gdshader")
				leaf.set_shader_parameter("color_map",source.albedo_texture)
				leaf.set_shader_parameter("tint",source.albedo_color)
				leaf.set_shader_parameter("has_normal",source.normal_texture!=null)
				if source.normal_texture:leaf.set_shader_parameter("normal_map",source.normal_texture)
				mesh.surface_set_material(i,leaf)
			if plant:plant_materials[shared_key]=mesh.surface_get_material(i)
		entries.append([mesh,tr])
	for child in node.get_children():_collect_sri(child,tr,entries,key)

func _foliage() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=20261018
	for i in range(int(circuit.length/19.0)):
		var s:=float(i)*19+7
		for side in [-1.0,1.0]:
			var p:=circuit.sample(s,side*(17.5+rng.randf()*2))
			if p.x < -123:continue
			var angle:=rng.randf()*TAU
			var size:=.85+rng.randf()*.28
			if profile.parking_clear(p,circuit,2.8):
				_instance("phoenix_%d"%(i%3),p,size,angle)
				_instance("phoenix_%d_lod"%(i%3),p,size,angle,true)
			for j in range(4):
				var q:=circuit.sample(s+j*4.4,side*(14.0+rng.randf()*1.2))
				if not profile.parking_clear(q,circuit,1.8):continue
				var kind:="banana_detailed" if (i+j)%3 else "banana_simple"
				var scale0:=.85+rng.randf()*.30
				var yaw:=rng.randf()*TAU
				_instance(kind,q,scale0,yaw)
				_instance("banana_detailed_lod" if kind=="banana_detailed" else kind,q,scale0,yaw,true)
				_instance("bush_common_flowers",q+Vector3(1,0,1),.6,rng.randf()*TAU)
	for i in range(24):
		var a:=float(i)*TAU/24
		var p:=Vector3(cos(a)*41,0,-25+sin(a)*41)
		if p.distance_to(circuit.project(p).center)>20:_instance("shade_tree_%d"%(i%3),p,.55,a)

func _flush() -> void:
	super._flush()
	for node in get_children():
		if node is MultiMeshInstance3D:
			var far: bool=node.visibility_range_begin>0
			node.visibility_range_begin=profile.foliage_near_distance if far else 0
			node.visibility_range_end=profile.foliage_far_distance if far else profile.foliage_near_distance
			if far:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _surface(st: SurfaceTool,verts: Array,uvs: Array) -> void:
	for i in [0,2,1,0,3,2]:
		st.set_uv(uvs[i])
		st.add_vertex(verts[i])

func _boundaries() -> void:
	var concrete:=StandardMaterial3D.new()
	concrete.albedo_color=Color("aba394")
	concrete.albedo_texture=load("res://assets/materials/Concrete034_2K-JPG_Color.jpg")
	concrete.normal_enabled=true
	concrete.normal_texture=load("res://assets/materials/Concrete034_2K-JPG_NormalGL.jpg")
	concrete.normal_scale=.5
	concrete.roughness=.72
	concrete.uv1_triplanar=true
	concrete.uv1_world_triplanar=true
	concrete.uv1_scale=Vector3.ONE*.7
	var paint:=StandardMaterial3D.new()
	paint.albedo_texture=load(ART+"curb_stripes.svg")
	paint.roughness=.46
	paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for side in [-1.0,1.0]:
		var curb:=SurfaceTool.new()
		curb.begin(Mesh.PRIMITIVE_TRIANGLES)
		var wall:=SurfaceTool.new()
		wall.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(circuit.points.size()):
			var a:=float(i)*circuit.step
			var b:=float(i+1)*circuit.step
			var u:=[Vector2(a,0),Vector2(a,1),Vector2(b,1),Vector2(b,0)]
			_surface(curb,[circuit.sample(a,side*9.25)+Vector3.UP*.065,circuit.sample(a,side*10.3)+Vector3.UP*.065,circuit.sample(b,side*10.3)+Vector3.UP*.065,circuit.sample(b,side*9.25)+Vector3.UP*.065],u)
			for lane in [10.76,11.24]:
				_surface(wall,[circuit.sample(a,side*lane)+Vector3.UP*.02,circuit.sample(a,side*lane)+Vector3.UP*1.02,circuit.sample(b,side*lane)+Vector3.UP*1.02,circuit.sample(b,side*lane)+Vector3.UP*.02],u)
			_surface(wall,[circuit.sample(a,side*10.76)+Vector3.UP*1.02,circuit.sample(a,side*11.24)+Vector3.UP*1.02,circuit.sample(b,side*11.24)+Vector3.UP*1.02,circuit.sample(b,side*10.76)+Vector3.UP*1.02],u)
		curb.generate_normals()
		wall.generate_normals()
		for item in [[curb,paint,"PaintedCurb"],[wall,concrete,"ConcreteBoundary"]]:
			var node:=MeshInstance3D.new()
			node.name=item[2]
			node.mesh=item[0].commit()
			node.material_override=item[1]
			node.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
			node.add_to_group("sri_boundary")
			add_child(node)

func _art_material(key: String) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_texture=load(ART+key+".png")
	m.roughness=.6
	m.metallic_specular=0.0
	m.emission_enabled=true
	m.emission_texture=m.albedo_texture
	m.emission=Color.WHITE
	m.emission_energy_multiplier=.05
	return m

func _poster(parent: Node3D,key: String,size0: Vector2,offset: Vector3,yaw: float) -> void:
	var face:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=size0
	face.mesh=quad
	face.position=offset
	face.rotation.y=yaw
	face.material_override=_art_material(key)
	face.add_to_group("sri_advertising")
	parent.add_child(face)
	advertising_faces+=1

func _national_flag(parent: Node3D) -> void:
	var flag:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.orientation=PlaneMesh.FACE_Z
	plane.size=Vector2(2.4,1.2)
	plane.subdivide_width=20
	plane.subdivide_depth=6
	flag.mesh=plane
	flag.position=Vector3(1.25,4.8,0)
	var m:=ShaderMaterial.new()
	m.shader=load("res://shaders/sri_flag.gdshader")
	m.set_shader_parameter("flag_map",load("res://assets/flags/sri_lanka_flag.svg"))
	flag.material_override=m
	flag.add_to_group("sri_national_flag")
	parent.add_child(flag)
	national_flags+=1

func _prom_details() -> void:
	var iron:=LeoRaceVisuals.flat_material(Color("253039"),.5)
	for side in [-1.0,1.0]:
		var number:=ceili(float(circuit.points.size())/20.0) if side<0 else int(circuit.length/16.0)
		for i in range(number):
			var s:=float(i)*20*circuit.step if side<0 else float(i)*16+6
			var p:=circuit.sample(s,side*(12.6 if side<0 else 12.8))
			var t:=circuit.direction(s)
			var pole:=Node3D.new()
			pole.position=p
			pole.rotation.y=atan2(-t.x,-t.z)
			add_child(pole)
			# Reuse the existing street-lamp post at this exact circuit anchor.
			if i%2==0:_national_flag(pole)
			else:
				LeoRaceVisuals.mesh_box(pole,Vector3(1.34,2.6,.10),Vector3(.85,4.2,0),iron)
				_poster(pole,PORTRAITS[(i/2)%4],Vector2(1.25,2.5),Vector3(.85,4.2,.06),0)
				_poster(pole,PORTRAITS[(i/2)%4],Vector2(1.25,2.5),Vector3(.85,4.2,-.06),PI)
	# Cover each existing race board with a complete festival campaign image.
	for i in range(6):
		var s:=circuit.length*(.12+i*.14)
		var t:=circuit.direction(s)
		var normal:=Vector3(-t.z,0,t.x)
		var board:=Node3D.new()
		board.position=circuit.sample(s,-14.4)
		board.rotation.y=atan2(normal.x,normal.z)
		add_child(board)
		_poster(board,WIDE[i%4],Vector2(7.8,2.6),Vector3(0,2.6,.19),0)
		_poster(board,WIDE[i%4],Vector2(7.8,2.6),Vector3(0,2.6,-.19),PI)
	for i in range(profile.transport_positions.size()):
		var p:=profile.transport_position(i,circuit)
		var s: float=circuit.project(p).distance
		var t:=circuit.direction(s)
		var projected: Dictionary=circuit.project(p)
		if absf(projected.offset)<17.5:p=circuit.sample(s,17.5*signf(projected.offset))
		var key: String="street_tuk_tuk" if i==0 else "tuk_tuk:"+["a32c3e","cca539","176c60"][i-1]
		_instance(key,p,1.0,atan2(-t.x,-t.z))
		_instance("street_tuk_tuk_lod" if i==0 else "tuk_tuk_lod:"+key.get_slice(":",1),p,1.0,atan2(-t.x,-t.z),true)
		transport_count+=1
		transport_placements.append(p)
	var bus_pos:=profile.bus_position
	_instance("sri_lanka_bus",bus_pos,1.0,0)
	_instance("sri_lanka_bus_lod",bus_pos,1.0,0,true)
	transport_count+=1
	transport_placements.append(bus_pos)
	var title:=LeoRaceVisuals.label(self,"COLOMBO CITY TRANSIT",bus_pos+Vector3(-1.6,2.0,0),-PI/2,5.5,Color("eeddb9"))
	title.remove_from_group("race_sign_text")

func _reflections() -> void:
	if RenderingServer.get_current_rendering_method()!="forward_plus":return
	# One continuous capture volume avoids rectangular highlight seams on asphalt.
	var probe:=ReflectionProbe.new()
	probe.position=Vector3(0,10,-20)
	probe.size=Vector3(600,75,650)
	probe.max_distance=500
	probe.intensity=.32
	probe.update_mode=ReflectionProbe.UPDATE_ONCE
	probe.enable_shadows=false
	add_child(probe)
