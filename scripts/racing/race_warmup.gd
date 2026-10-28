class_name LeoRaceWarmup
extends RefCounted
static var last_report: Dictionary={}
static func prepare(game: Node3D) -> void:
	var began:=Time.get_ticks_usec()
	var particles: Array[Dictionary]=[];var audio: Array[Dictionary]=[];var callbacks: Array[Dictionary]=[]
	var warm_meshes: Array[MeshInstance3D]=[]
	var skid_nodes: Array[Dictionary]=[]
	for kart in game.karts:
		# Render the actual selected skid backend, including its receiving surface.
		if kart.effects and not kart.effects.marks.is_empty():
			var mark: Node3D=kart.effects.marks[0]
			skid_nodes.append({"node":mark,"transform":mark.global_transform,"visible":mark.visible})
			mark.visible=true
			var camera: Camera3D=game.local_players[mini(maxi(0,kart.local_slot),game.human_count-1)].camera
			mark.global_position=camera.global_position-camera.global_basis.z*4.-Vector3.UP
			var receiver:=MeshInstance3D.new();var ground:=PlaneMesh.new();ground.size=Vector2(2.,2.);receiver.mesh=ground
			game.world.add_child(receiver);receiver.global_position=mark.global_position-Vector3.UP*.01;warm_meshes.append(receiver)
		for node in [kart]+kart.find_children("*","Node",true,false):
			if node is GPUParticles3D:
				particles.append({"node":node,"transform":node.global_transform,"emitting":node.emitting})
				var camera: Camera3D=game.local_players[mini(maxi(0,kart.local_slot),game.human_count-1)].camera
				node.global_position=camera.global_position-camera.global_basis.z*4.;node.restart();node.emitting=true
			elif node is AudioStreamPlayer or node is AudioStreamPlayer3D:
				if node.stream and not node.playing:audio.append({"node":node,"volume":node.volume_db});node.volume_db=-80.;node.play()
			if node.has_method("_process") or node.has_method("_physics_process"):
				callbacks.append({"node":node,"process":node.is_processing(),"physics":node.is_physics_processing()});node.set_process(false);node.set_physics_process(false)
			if node is LeoCosmeticDamage and not node.available.is_empty():
				# Match the real patch vertex format: no UV, explicit normals/tangents.
				var representative:=MeshInstance3D.new();var mesh:=ArrayMesh.new();var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.15,-.15,0),Vector3(.15,-.15,0),Vector3(0,.15,0),Vector3(0,.15,0),Vector3(.15,-.15,0),Vector3(-.15,-.15,0)])
				arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK,Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD]);arrays[Mesh.ARRAY_TANGENT]=PackedFloat32Array([1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				representative.mesh=mesh;representative.material_override=node.available[0].material_override
				var active_camera: Camera3D=game.local_players[mini(maxi(0,kart.local_slot),game.human_count-1)].camera
				game.world.add_child(representative);representative.global_basis=active_camera.global_basis;representative.global_position=active_camera.global_position-active_camera.global_basis.z*3.;warm_meshes.append(representative)
	for frame in 4:
		await game.get_tree().process_frame
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	for entry in particles:
		entry.node.emitting=false;entry.node.restart();entry.node.global_transform=entry.transform;entry.node.emitting=entry.emitting
	for entry in audio:entry.node.stop();entry.node.volume_db=entry.volume
	for entry in callbacks:entry.node.set_process(entry.process);entry.node.set_physics_process(entry.physics)
	for entry in skid_nodes:entry.node.global_transform=entry.transform;entry.node.visible=entry.visible
	for mesh in warm_meshes:mesh.free()
	last_report={"particles":particles.size(),"audio_streams":audio.size(),"damage_materials":warm_meshes.size()-skid_nodes.size(),"skid_backends":skid_nodes.size(),"milliseconds":(Time.get_ticks_usec()-began)/1000.,"post_draw":DisplayServer.get_name()!="headless"}
