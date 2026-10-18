class_name LeoRaceVisuals
extends RefCounted

# Race-direction geometry has an explicit local -Z convention. Text has a
# front face only; paired labels are used where a sign can be approached twice.
static func mesh_box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	parent.add_child(node)
	return node

static func flat_material(color: Color, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .46
	m.metallic = metal
	return m

static func polish_chassis(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for i in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(i) as StandardMaterial3D
			if not source: continue
			var m := source.duplicate() as StandardMaterial3D
			if source.resource_name in ["blue","coral","aqua","pink"]:
				m.roughness = .19
				m.metallic = .18
				m.clearcoat_enabled = true
				m.clearcoat = .75
				m.clearcoat_roughness = .15
			elif source.resource_name == "gold":
				m.metallic = .7
				m.roughness = .23
			elif source.resource_name == "cyan":
				m.emission_enabled = true
				m.emission = Color("83e7ff")
				m.emission_energy_multiplier = 1.35
			else: continue
			instance.set_surface_override_material(i,m)
	for child in node.get_children(): polish_chassis(child)

static func label(parent: Node3D, words: String, p: Vector3, yaw: float, width: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = words
	l.name = "SignText"
	l.position = p
	l.rotation.y = yaw
	l.font = load("res://assets/fonts/heading.ttf")
	l.font_size = 80
	l.pixel_size = width / maxf(1.0, l.font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,80).x)
	l.modulate = color
	l.outline_modulate = Color("0a1830")
	l.outline_size = 3
	l.double_sided = false
	l.shaded = false
	l.no_depth_test = false
	l.fixed_size = false
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.visibility_range_end = 140
	l.visibility_range_end_margin = 12
	l.add_to_group("race_sign_text")
	parent.add_child(l)
	return l

static func build_signs(world: Node3D, circuit: LeoCircuit) -> Node3D:
	var root := Node3D.new()
	root.name = "RaceSigns"
	world.add_child(root)
	# The beam is centred at z=72, so each label sits outside its own face.
	label(root,"LEO RACER",Vector3(-90,8.12,72.67),0,10.5,Color("ffdc66"))
	label(root,"LEO RACER",Vector3(-90,8.12,71.33),PI,10.5,Color("ffdc66"))
	var navy := flat_material(Color("10243f"),.12)
	var gold := flat_material(Color("ffbd35"),.32)
	var words := ["LOTUS COAST", "FORT QUARTER", "COLOMBO GRAND PRIX", "ISLAND ENERGY", "CHASE THE COAST", "LOTUS PLAZA"]
	for i in words.size():
		var s := circuit.length*(.12+i*.14)
		var t := circuit.direction(s)
		var normal := Vector3(-t.z,0,t.x)
		var board := Node3D.new()
		board.name = "TrackBoard_%d" % i
		board.position = circuit.sample(s,-14.4)
		board.rotation.y = atan2(normal.x,normal.z)
		root.add_child(board)
		mesh_box(board,Vector3(7.8,1.65,.28),Vector3(0,2.35,0),navy)
		mesh_box(board,Vector3(7.9,.10,.32),Vector3(0,3.24,0),gold)
		for x in [-2.8,2.8]: mesh_box(board,Vector3(.17,2.0,.17),Vector3(x,1,0),navy)
		label(board,words[i],Vector3(0,2.38,.17),0,6.9,Color("fff3c7"))
	return root

static func chevron_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-4,0,1.0),Vector3(0,0,-.8),Vector3(0,0,0),Vector3(-4,0,1.8),
		Vector3(0,0,-.8),Vector3(4,0,1.0),Vector3(4,0,1.8),Vector3(0,0,0)])
	var normals := PackedVector3Array()
	for i in vertices.size(): normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2,4,6,5,4,7,6])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func build_boosts(world: Node3D, circuit: LeoCircuit) -> Node3D:
	var root := Node3D.new()
	root.name = "BoostPads"
	world.add_child(root)
	var dark := flat_material(Color("122d43"),.3)
	var edge := flat_material(Color("ffc750"),.2)
	var arrow := chevron_mesh()
	for fraction in circuit.boosts:
		var s := float(fraction)*circuit.length
		var pad := Node3D.new()
		pad.name = "Boost_%03d" % int(s)
		pad.position = circuit.sample(s)+Vector3.UP*.075
		var t := circuit.direction(s)
		pad.rotation.y = atan2(-t.x,-t.z)
		pad.set_meta("race_direction",t)
		pad.add_to_group("race_boost_pad")
		root.add_child(pad)
		mesh_box(pad,Vector3(10,.025,7.5),Vector3(0,0,.5),dark)
		for side in [-1,1]:
			mesh_box(pad,Vector3(.10,.035,7.5),Vector3(side*4.8,.02,.5),edge)
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/boost_pad.gdshader")
		for j in range(3):
			var item := MeshInstance3D.new()
			item.mesh = arrow
			item.position = Vector3(0,.04,-2.0+j*2.1)
			var material := m.duplicate() as ShaderMaterial
			material.set_shader_parameter("phase",float(j)*-.7)
			item.material_override = material
			pad.add_child(item)
	return root
