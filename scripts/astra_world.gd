class_name LeoAstraWorld
extends LeoSriLankaWorld
## A flat, raceable 1.9km ribbon surrounded by sculpted coast, lagoon and gardens.
## This node contains decoration only. LeoCircuit remains the collision authority.
var static_batches: Dictionary = {}
var _ground_samples := PackedVector2Array()
var _art_cache: Dictionary = {}
var _advert_border: StandardMaterial3D

func setup(track: LeoCircuit,p: LeoArtProfile) -> void:
	name = "AstraLotusCoast"
	profile = p
	circuit = track
	for i in range(0,circuit.points.size(),4):
		_ground_samples.append(Vector2(circuit.points[i].x,circuit.points[i].z))
	_terrain()
	_road()
	_foliage()
	_boundaries()
	_prom_details()
	_causeway()
	_flush()
	_flush_static()
	_reflections()
	print("ASTRA_WORLD_READY | lap=%.1fm | foliage=%d | adverts=%d | flags=%d | ground=coastal-dunes+lagoon+garden-hills"%[circuit.length,count,advertising_faces,national_flags])

func _mesh_node(mesh: Mesh,material: Material,label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	return node

func _ribbon(a: float,b: float,height: float,material: Material,label: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(circuit.points.size()):
		var s := float(i)*circuit.step
		var e := float(i+1)*circuit.step
		_surface(surface,[circuit.sample(s,a)+Vector3.UP*height,circuit.sample(s,b)+Vector3.UP*height,circuit.sample(e,b)+Vector3.UP*height,circuit.sample(e,a)+Vector3.UP*height],[Vector2(s,a),Vector2(s,b),Vector2(e,b),Vector2(e,a)])
	surface.generate_normals()
	surface.generate_tangents()
	var node := _mesh_node(surface.commit(),material,label)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _road() -> void:
	var asphalt := pbr_material("res://shaders/road_surface.gdshader","Asphalt023S")
	asphalt.set_shader_parameter("base_roughness",profile.road_roughness)
	_ribbon(-9.25,9.25,.045,asphalt,"AstraContinuousAsphalt")
	var paint := LeoRaceVisuals.flat_material(Color("eee6d0"),.03)
	paint.roughness = .39
	for side in [-1.0,1.0]:
		_ribbon(side*8.86,side*9.02,.055,paint,"WhiteEdge")
	# Discrete lane dashes are batched and follow the actual driving tangent.
	for i in range(int(circuit.length/12)):
		var s := float(i)*12
		_batch_box(circuit.sample(s)+Vector3.UP*.056,Vector3(.16,.012,3.8),atan2(circuit.direction(s).x,circuit.direction(s).z),paint)
	var checker := ShaderMaterial.new()
	checker.shader = load("res://shaders/astra_checkers.gdshader")
	var finish := SurfaceTool.new()
	finish.begin(Mesh.PRIMITIVE_TRIANGLES)
	_surface(finish,[Vector3(-99.15,.062,75),Vector3(-80.85,.062,75),Vector3(-80.85,.062,81),Vector3(-99.15,.062,81)],[Vector2(0,0),Vector2(9,0),Vector2(9,3),Vector2(0,3)])
	finish.generate_normals()
	_mesh_node(finish.commit(),checker,"AstraWornFinishCheckers")
	var navy := LeoRaceVisuals.flat_material(Color("14232b"),.45)
	var warm := _emissive(Color("ffbd5a"),1.4)
	for x in [-100.6,-79.4]:
		_batch_box(Vector3(x,4.5,72),Vector3(.85,9,1.05),0,navy)
		_batch_box(Vector3(x,5.2,72),Vector3(.91,.22,1.11),0,warm)
	_batch_box(Vector3(-90,8.12,72),Vector3(22,1.55,1.1),0,navy)
	_batch_box(Vector3(-90,8.96,72),Vector3(22,.11,1.18),0,_emissive(Color("07dfef"),2.5))

func _ground_height(p: Vector2) -> float:
	var coast := smoothstep(-165.0,-132.0,p.x)
	var lagoon := pow((p.x-215.0)/85.0,2)+pow((p.y+80.0)/125.0,2)
	if p.x < -150:return -3.0
	if lagoon<1.0:return -3.0+smoothstep(.74,1.0,lagoon)*2.65
	var nearest := INF
	for sample in _ground_samples:nearest=minf(nearest,p.distance_squared_to(sample))
	var clearance := sqrt(nearest)
	var road_mask := smoothstep(24.0,60.0,clearance)
	var hills := 13.0*exp(-p.distance_squared_to(Vector2(30,-100))/6000.0)+8.0*exp(-p.distance_squared_to(Vector2(80,100))/4000.0)
	var dune := (sin(p.y*.041)+sin(p.y*.077+p.x*.035)*.5+1.5)*1.15
	var dune_mask := (1.0-smoothstep(-124.0,-109.0,p.x))*smoothstep(-152.0,-139.0,p.x)
	return -3.0*(1.0-coast)+(-.09+hills*road_mask+dune*dune_mask)*coast

func _terrain() -> void:
	var ground := SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 65
	var rows := 96
	var start := Vector2(-200,-520)
	var grid := 10.0
	var vertices := PackedVector3Array()
	for z in range(rows+1):
		for x in range(cols+1):
			var p := start+Vector2(x,z)*grid
			vertices.append(Vector3(p.x,_ground_height(p),p.y))
	for z in range(rows):
		for x in range(cols):
			var i := z*(cols+1)+x
			for j in [i,i+1,i+cols+1,i+1,i+cols+2,i+cols+1]:
				ground.set_uv(Vector2(vertices[j].x,vertices[j].z)*.1)
				ground.add_vertex(vertices[j])
	ground.generate_normals()
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/astra_terrain.gdshader")
	ground_mat.set_shader_parameter("sand_map",load("res://assets/materials/shore_AlbedoHeight.png"))
	_mesh_node(ground.commit(),ground_mat,"SculptedAstraCoastAndGardenHills")
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/astra_water.gdshader")
	var ocean := PlaneMesh.new()
	ocean.size = Vector2(2000,2200)
	ocean.subdivide_width = 24
	ocean.subdivide_depth = 24
	var sea := _mesh_node(ocean,water,"IndianOcean")
	sea.position = Vector3(-1145,-.66,-40)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lagoon_mesh := SurfaceTool.new()
	lagoon_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a := float(i)*TAU/96
		var b := float(i+1)*TAU/96
		for v in [Vector3(215,-.64,-80),Vector3(215+cos(a)*85,-.64,-80+sin(a)*125),Vector3(215+cos(b)*85,-.64,-80+sin(b)*125)]:
			lagoon_mesh.set_normal(Vector3.UP)
			lagoon_mesh.add_vertex(v)
	var lagoon_node := _mesh_node(lagoon_mesh.commit(),water,"LotusLagoon")
	lagoon_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = 38296
	for i in range(70):
		var a := float(i)*TAU/70
		var p := Vector3(215+cos(a)*87,-.1,-80+sin(a)*127)
		if absf(circuit.project(p).offset)>15:
			_instance("rock_medium_%d"%(1+i%2),p,.28+rng.randf()*.35,a)
	for i in range(70):
		_instance("rock_medium_%d"%(1+i%2),Vector3(-139,-.12,-350+i*9),.35+rng.randf()*.55,rng.randf()*TAU)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		for location in [Vector3(-230,8,-190),Vector3(215,4,-110)]:
			var haze := FogVolume.new()
			haze.position = location
			haze.size = Vector3(130,22,190) if location.x<0 else Vector3(120,12,150)
			var fog_mat := FogMaterial.new()
			fog_mat.density = profile.bay_fog_density*(1.0 if location.x<0 else .28)
			fog_mat.albedo = profile.haze_color
			haze.material = fog_mat
			add_child(haze)

func _foliage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8102026
	for i in range(int(circuit.length/24.0)):
		var s := float(i)*24+7
		for side in [-1.0,1.0]:
			var p := circuit.sample(s,side*18.3)
			var lagoon := pow((p.x-215.0)/85.0,2)+pow((p.z+80.0)/125.0,2)
			if p.x < -125 or lagoon<1.06:continue
			if p.distance_to(circuit.project(p).center)<16:continue
			var yaw := rng.randf()*TAU
			var size0 := .85+rng.randf()*.25
			_instance("phoenix_%d"%(i%3),p,size0,yaw)
			_instance("phoenix_%d_lod"%(i%3),p,size0,yaw,true)
			for j in range(2):
				var q := circuit.sample(s+j*6.0,side*15.4)
				if q.distance_to(circuit.project(q).center)<14.8:continue
				var kind := "banana_detailed" if (i+j)%3 else "banana_simple"
				_instance(kind,q,.85+rng.randf()*.23,yaw+j)
				_instance("banana_detailed_lod" if kind=="banana_detailed" else kind,q,.97,yaw+j,true)
				_instance("bush_common_flowers",q+Vector3(side,0,0),.7,yaw)
	for i in range(28):
		var a := float(i)*TAU/28
		var p := Vector3(35+cos(a)*58,0,-80+sin(a)*80)
		if p.distance_to(circuit.project(p).center)>55:
			p.y = _ground_height(Vector2(p.x,p.z))
			_instance("shade_tree_%d"%(i%3),p,.75,a)
			_instance("shade_tree_%d"%(i%3),p,.75,a,true)

func _art_material(key: String) -> StandardMaterial3D:
	if _art_cache.has(key):return _art_cache[key]
	var material := super._art_material(key)
	material.albedo_color = Color(.92,.92,.92,1)
	material.emission_energy_multiplier = 1.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = .24
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_art_cache[key] = material
	return material

func _poster(parent: Node3D,key: String,size0: Vector2,offset: Vector3,yaw: float) -> void:
	super._poster(parent,key,size0,offset,yaw)
	var face := parent.get_child(parent.get_child_count()-1) as MeshInstance3D
	face.visibility_range_end = 230
	if not _advert_border:_advert_border = _emissive(Color("30e4dd"),2.4)
	var tr := parent.transform*Transform3D(Basis(Vector3.UP,yaw),offset)
	for y in [-1.0,1.0]:
		_batch_box(tr.origin+tr.basis.y*(size0.y*.5+.04)*y,Vector3(size0.x+.08,.045,.04),parent.rotation.y+yaw,_advert_border)
func _emissive(color: Color,power: float) -> StandardMaterial3D:
	var material := LeoRaceVisuals.flat_material(color,.2)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = power
	return material

func _prom_details() -> void:
	var iron := LeoRaceVisuals.flat_material(Color("27312e"),.6)
	var lamp := _emissive(Color("ffdc98"),2.0)
	for side in [-1.0,1.0]:
		for i in range(int(circuit.length/36.0)):
			var s := float(i)*36+6
			var t := circuit.direction(s)
			var p := circuit.sample(s,side*12.8)
			var yaw := atan2(-t.x,-t.z)
			var basis0 := Basis(Vector3.UP,yaw)
			_batch_box(p+Vector3.UP*3.5,Vector3(.18,7,.18),yaw,iron)
			_batch_box(p+Vector3.UP*6.8+basis0.x*.8,Vector3(1.8,.13,.18),yaw,iron)
			_batch_box(p+Vector3.UP*6.7+basis0.x*1.55,Vector3(.9,.09,.5),yaw,lamp)
			var pole := Node3D.new()
			pole.position = p
			pole.rotation.y = yaw
			add_child(pole)
			if i%3==0:
				_national_flag(pole)
			else:
				_batch_box(p+basis0*Vector3(.85,4.2,0),Vector3(1.35,2.6,.1),yaw,iron)
				_poster(pole,PORTRAITS[i%4],Vector2(1.25,2.5),Vector3(.85,4.2,.06),0)
				_poster(pole,PORTRAITS[i%4],Vector2(1.25,2.5),Vector3(.85,4.2,-.06),PI)
	# The six race boards are backed by LeoRaceVisuals.build_signs().
	for i in range(6):
		var s := circuit.length*(.12+i*.14)
		var t := circuit.direction(s)
		var normal := Vector3(-t.z,0,t.x)
		var board := Node3D.new()
		board.position = circuit.sample(s,-14.4)
		board.rotation.y = atan2(normal.x,normal.z)
		add_child(board)
		_poster(board,WIDE[i%4],Vector2(7.8,2.6),Vector3(0,2.6,.19),0)
		_poster(board,WIDE[i%4],Vector2(7.8,2.6),Vector3(0,2.6,-.19),PI)
	# Anticipation: readable corner boards announce the fast-to-slow transitions.
	for pair in [[.31,"NORTH ESSES"],[.365,"HARBOR HAIRPIN"],[.50,"LAGOON CAUSEWAY"],[.72,"GARDEN DRIFT"]]:
		var s := float(pair[0])*circuit.length
		var t := circuit.direction(s)
		var gate := Node3D.new()
		gate.position = circuit.sample(s,11.6)+Vector3.UP*2.4
		gate.rotation.y = atan2(-t.x,-t.z)
		add_child(gate)
		LeoRaceVisuals.mesh_box(gate,Vector3(5.4,1.2,.15),Vector3.ZERO,iron)
		LeoRaceVisuals.label(gate,pair[1],Vector3(0,0,.10),0,4.9,Color("ffcc66"))

func _causeway() -> void:
	var concrete := pbr_material("res://shaders/paving_pbr.gdshader","Concrete034")
	var steel := LeoRaceVisuals.flat_material(Color("535d60"),.7)
	var amber := _emissive(Color("ffab36"),2.0)
	for i in range(int(circuit.length/4)):
		var s := float(i)*4
		var p := circuit.sample(s)
		if pow((p.x-215.0)/85.0,2)+pow((p.z+80.0)/125.0,2)>1.0:continue
		var t := circuit.direction(s)
		var yaw := atan2(t.x,t.z)
		_batch_box(p+Vector3.DOWN*.3,Vector3(23,.65,4.2),yaw,concrete)
		for side in [-1.0,1.0]:
			_batch_box(circuit.sample(s,side*11.7)+Vector3.UP*.8,Vector3(.15,1.6,.15),yaw,steel)
			_batch_box(circuit.sample(s,side*11.7)+Vector3.UP*1.45,Vector3(.17,.12,4.05),yaw,steel)
			if i%3==0:_batch_box(circuit.sample(s,side*11.7)+Vector3.UP*1.57,Vector3(.3,.1,.6),yaw,amber)
		if i%5==0:
			for side in [-1.0,1.0]:
				_batch_box(circuit.sample(s,side*7.5)+Vector3.DOWN*1.5,Vector3(1.4,3,1.4),yaw,concrete)

func _batch_box(pos: Vector3,size0: Vector3,yaw: float,material: Material) -> void:
	var tile := Vector2i(floori(pos.x/64),floori(pos.z/64))
	var key := "%s_%s_%s"%[material.get_instance_id(),str(size0),str(tile)]
	if not static_batches.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size0
		mesh.material = material
		static_batches[key] = {"mesh":mesh,"items":[],"origin":Vector3(tile.x*64+32,0,tile.y*64+32)}
	static_batches[key].items.append(Transform3D(Basis(Vector3.UP,yaw),pos-Vector3(static_batches[key].origin)))

func _flush_static() -> void:
	for data in static_batches.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = data.mesh
		mm.instance_count = data.items.size()
		for i in range(data.items.size()):mm.set_instance_transform(i,data.items[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.position = data.origin
		node.visibility_range_end = 230
		add_child(node)

func _reflections() -> void:
	if RenderingServer.get_current_rendering_method()!="forward_plus":return
	var probe := ReflectionProbe.new()
	probe.position = Vector3(100,12,-50)
	probe.size = Vector3(700,85,850)
	probe.max_distance = 800
	probe.intensity = .38
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.enable_shadows = false
	add_child(probe)
