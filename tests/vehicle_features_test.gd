extends SceneTree
var errors: Array[String] = []
var checks := 0
var output := OS.get_environment("VEHICLE_QA_ROOT") if OS.has_environment("VEHICLE_QA_ROOT") else "res://build/vehicle232"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func run() -> void:
	LeoAssets.configure(OS.get_environment("LEO_ASSET_ROOT") if OS.has_environment("LEO_ASSET_ROOT") else ProjectSettings.globalize_path("res://build/Release-2.3.1/GameAssets"));LeoAssets.mount_packs()
	LeoVehicleLibrary.discover(ProjectSettings.globalize_path(output+"/vehicles"))
	var definition := GarageCatalog.shared().vehicle(&"bigster")
	check(definition!=null,"Bigster feature package discovers")
	if not definition:quit(2);return
	check(LeoVehicleLibrary.problems(definition.content_data,definition.content_folder).is_empty(),"Feature manifest validates")
	await LeoAssets.scene_async(definition.model_path,self)
	var kart := LeoKart.new();root.add_child(kart);kart.setup(LeoCircuit.new(),0,true,"human","bigster")
	kart.set_process(false);kart.set_physics_process(false);kart.bump_cooldown=999.;kart.active=true;kart.control_input=LeoPlayerInput.new()
	var feature: LeoVehicleFeatures=kart.vehicle_lighting
	check(feature!=null and feature.diagnostics.is_empty(),"All authored targets resolve")
	check(feature.headlights.size()==2 and feature.brake_materials.size()==3,"Two beams, two Y signatures and high-level brake bind")
	var reverse_groups := definition.lighting.filter(func(group):return group.role=="reverse")
	check(reverse_groups.size()==1,"One separate bumper reverse optical unit")
	check(reverse_groups[0].targets[0].node.contains("bumper") and not reverse_groups[0].targets[0].node.contains("taillight"),"Reverse cannot bind the upper Y cluster")
	check(float(reverse_groups[0].anchor[1])<.6,"Reverse illumination originates below rear bumper")
	for suffix in ["L","R"]:
		var optic := kart.chassis.get_node("Bigster_024/Front_Assembly/dust25_headlight_"+suffix+"_001") as MeshInstance3D
		var illuminated := 0
		for i in optic.mesh.get_surface_count():
			var material := optic.get_active_material(i) as StandardMaterial3D
			if material.emission_enabled and material.emission_energy_multiplier>0.:illuminated+=1
		check(illuminated==2,"Both main optical cells and signature illuminate: "+suffix)
		var cluster := kart.chassis.get_node("Bigster_024/Rear_Assembly/dust25_taillight_"+suffix) as MeshInstance3D
		var lit_surfaces := 0
		for i in cluster.mesh.get_surface_count():
			var material := cluster.get_active_material(i) as StandardMaterial3D
			if material.emission_enabled and material.emission_energy_multiplier>0.:
				lit_surfaces+=1
				check(material.resource_name=="Lamp_Tail_Y_LED_232","Only inset Y rails emit; broad lens and indicator stay passive")
		check(lit_surfaces==1,"One continuous red Y signature per rear cluster: "+suffix)
	var states: Array=[]
	for sample in [["accelerate",15.,1.,0.,false,false],["coast",15.,0.,0.,false,false],["brake forward",15.,0.,1.,true,false],["brake at rest",0.,0.,1.,true,false],["reverse",-5.,0.,1.,false,true],["brake reverse",-5.,1.,0.,true,true]]:
		kart.speed=float(sample[1]);kart.control_input.inject_test("accelerate",float(sample[2]));kart.control_input.inject_test("brake",float(sample[3]));kart._physics_process(.016)
		check(feature.braking==sample[4] and feature.reversing==sample[5],"Driving lamps: "+sample[0])
		states.append({"case":sample[0],"brake":feature.braking,"reverse":feature.reversing})
	feature.update_state(true,true);feature.toggle_headlights()
	check(not feature.headlights_on and feature.headlights.all(func(light):return not light.visible),"Headlight toggle controls projected beams")
	check(feature.brake_materials[0].emission_energy_multiplier>3. and feature.reversing,"Brake/reverse independent of headlight toggle")
	for group in feature.groups:
		if group.role=="reverse":check(group.materials[0].emission_energy_multiplier>3. and group.materials[0].emission.b>.9,"White reverse surfaces illuminate")
	var other := VehicleAssembler.assemble(definition,GarageCatalog.shared().driver(&"human"));root.add_child(other)
	var second: LeoVehicleFeatures=other.get_node("Chassis/VehicleLighting")
	check(second.headlights_on and not second.braking and not second.reversing,"Second car has independent lamp state")
	check(second.brake_materials[0]!=feature.brake_materials[0],"Per-car material instances")
	var panel := kart.chassis.get_node("Bigster_024/Glass_and_Seals/Bigster_Sunroof_Opening_Glass") as Node3D
	var fixed := kart.chassis.get_node("Bigster_024/Glass_and_Seals/Bigster_Panoramic_Fixed_Glass") as Node3D
	var closed := panel.transform;var fixed_pose := fixed.transform
	check(feature.trigger(1) and not feature.trigger(2),"Only authored sunroof action is assigned")
	feature._process(.8);var halfway := panel.position.distance_to(closed.origin)
	feature.trigger(1);feature._process(.4)
	check(panel.position.distance_to(closed.origin)<halfway,"Sunroof reverses from current pose")
	feature.trigger(1);feature._process(2.)
	var opened := panel.transform
	check(opened.origin.distance_to(closed.origin)>.6 and fixed.transform==fixed_pose,"Moving panel slides without moving fixed glass")
	kart.recover();check(panel.transform==opened,"Recovery retains roof pose")
	var second_panel := other.get_node("Chassis/Bigster_024/Glass_and_Seals/Bigster_Sunroof_Opening_Glass") as Node3D
	check(second_panel.transform==closed,"Second car roof stays closed")
	# Actual shared material inside the cabin must not be a brake target.
	var dashboard := kart.chassis.get_node("Bigster_024/Cabin/dust25_dash") as MeshInstance3D
	for i in dashboard.mesh.get_surface_count():
		var mat: Material=dashboard.get_active_material(i)
		if mat.resource_name.begins_with("Lamp_TailBrake_"):check(mat not in feature.brake_materials,"Dashboard excluded from brake rig")
	var malformed := definition.content_data.duplicate(true);malformed.lighting[0].targets[0].node="../outside"
	check(not LeoVehicleLibrary.problems(malformed,"",false).is_empty(),"Escaping lamp path rejected")
	malformed=definition.content_data.duplicate(true);malformed.actions[0].duration=NAN
	check(not LeoVehicleLibrary.problems(malformed,"",false).is_empty(),"Nonfinite action timing rejected")
	malformed=definition.content_data.duplicate(true);malformed.actions.append(malformed.actions[0].duplicate(true))
	check(not LeoVehicleLibrary.problems(malformed,"",false).is_empty(),"Duplicate action slot rejected")
	var legacy := LeoVehicleCodec.deserialize(definition.content_data,definition.content_folder)
	legacy.lighting=[];legacy.actions=[];legacy.model=definition.model
	var older := VehicleAssembler.assemble(legacy,GarageCatalog.shared().driver(&"human"));root.add_child(older)
	check(older.get_node_or_null("Chassis/VehicleLighting")!=null,"Legacy Bigster compatibility adapter")
	var roundtrip := LeoVehicleCodec.serialize(definition)
	check(roundtrip.lighting==definition.lighting and roundtrip.actions==definition.actions,"Feature metadata survives codec round-trip")
	# Profile upgrade keeps old bindings and leaves conflicting defaults unbound.
	var p := LeoPlayerInput.new();var saved := p.serialize();saved.version=2
	for action in LeoPlayerInput.FEATURE_ACTIONS:saved.bindings.erase(action)
	saved.bindings.horn=[{"type":"key","index":KEY_L}];p.restore(saved)
	check(p.bindings.horn==saved.bindings.horn and p.bindings.headlights.is_empty(),"Legacy key conflict preserves old assignment")
	var router := LeoInputRouter.new();router.active_slots=2
	router.players[0].reset_defaults("keyboard");router.players[1].reset_defaults("keyboard");router.configure_keyboards(2)
	check(router.ready_problem(0).is_empty() and router.ready_problem(1).is_empty(),"Shared keyboard feature defaults do not overlap")
	var rig := preload("res://scripts/local/race_camera.gd").new();p=LeoPlayerInput.new("gamepad")
	rig.advance(-2.,p,.1);check(not rig.reverse_view,"Reverse camera delay")
	rig.advance(-2.,p,.06);check(rig.reverse_view and rig.mode=="reverse","Automatic reverse camera enters")
	p.inject_test("look_back",1.);rig.advance(5.,p,.1);check(rig.mode=="look_back","Held look-back overrides chase")
	p.inject_test("camera_right",1.);rig.advance(5.,p,.1);check(rig.mode=="orbit","Orbit overrides held look-back")
	p.clear();rig.advance(5.,p,1.1);check(rig.mode=="chase" and not rig.reverse_view,"Orbit recenters and forward exits reverse")
	var independent := preload("res://scripts/local/race_camera.gd").new()
	check(independent.angle==0. and independent.orbit_idle==2.,"Independent player camera state")
	router.players[0].reset_defaults("gamepad");router.players[1].reset_defaults("keyboard")
	var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true;router.feed(click)
	var motion := InputEventMouseMotion.new();motion.relative=Vector2(15,0);router.feed(motion)
	check(router.players[1].mouse_orbit.x==15 and router.players[0].mouse_orbit==Vector2.ZERO,"Mouse follows keyboard player")
	router.clear_all();check(not router.players[1].orbit_dragging and router.players[1].mouse_orbit==Vector2.ZERO,"Clearing inputs releases mouse orbit")
	var converter=preload("res://scripts/content/workshop_converter.gd")
	var converted: Dictionary=converter.convert(definition.model_path,{"id":"bigster_feature_roundtrip"})
	check(converted.get("ok",false) and converted.definition.actions==definition.actions and converted.definition.lighting==definition.lighting,"Conversion preserves authored feature metadata")
	if converted.get("ok",false):
		var destination:=ProjectSettings.globalize_path(output+"/converted-"+str(Time.get_ticks_usec()))
		var exported: Dictionary=converter.export_folder(converted,destination)
		check(exported.get("ok",false),"Authored car exports with existing wheel rig: "+String(exported.get("error","")))
		if exported.get("ok",false):
			var imported: Dictionary=LeoVehicleImporter.import_scene(destination.path_join("model.glb"))
			var restored:=LeoVehicleCodec.deserialize(converted.definition,destination);restored.model=imported.scene
			var actor:=VehicleAssembler.assemble(restored,GarageCatalog.shared().driver(&"human"));root.add_child(actor)
			var feature_roundtrip=actor.get_node_or_null("Chassis/VehicleLighting")
			check(feature_roundtrip!=null and feature_roundtrip.diagnostics.is_empty(),"Exported/imported feature targets still resolve")
			actor.free()
		converted.scene.free()
	# Embedded clip support is exercised independently of Bigster's transform rig.
	var fixture:=Node3D.new();fixture.name="Fixture"
	var hatch:=Node3D.new();hatch.name="Hatch";fixture.add_child(hatch);hatch.owner=fixture
	var animator:=AnimationPlayer.new();animator.name="AnimationPlayer";fixture.add_child(animator);animator.owner=fixture
	var clip:=Animation.new();clip.length=1.;var track:=clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(track,NodePath("Hatch:position"));clip.track_insert_key(track,0.,Vector3.ZERO);clip.track_insert_key(track,1.,Vector3.UP)
	var library:=AnimationLibrary.new();library.add_animation("open",clip);animator.add_animation_library("",library)
	var packed:=PackedScene.new();packed.pack(fixture);fixture.free()
	var animated:=VehicleDefinition.new();animated.model=packed;animated.driver_policy=VehicleDefinition.DriverPolicy.IDENTITY_ONLY;animated.actions=[{"slot":2,"name":"Hatch","type":"animation","player":"AnimationPlayer","clip":"open","duration":1.}]
	var animated_actor:=VehicleAssembler.assemble(animated,DriverDefinition.new());root.add_child(animated_actor)
	var animation_feature=animated_actor.get_node("Chassis/VehicleLighting")
	check(animation_feature.trigger(2),"Second slot accepts an embedded animation")
	animation_feature._process(.5)
	check(animated_actor.get_node("Chassis/Hatch").position.y>.4,"Embedded animation samples the authored clip")
	animation_feature.trigger(2);animation_feature._process(.5)
	check(animated_actor.get_node("Chassis/Hatch").position.is_equal_approx(Vector3.ZERO),"Embedded clip reverses to closed pose")
	animated_actor.free()
	var editor := LeoVehicleSetup.new();editor.game=Node.new();editor.configure(definition);root.add_child(editor)
	await process_frame;await process_frame
	check(editor.data.lighting==definition.lighting and editor.data.actions==definition.actions,"Workshop preserves authored features")
	check(editor.fields.find_children("*","OptionButton",true,false).size()>4,"Workshop exposes lamp/action editors")
	editor.game.free();editor.queue_free();router.free();older.free();other.free();kart.stop_audio();kart.free()
	await process_frame
	var report := {"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"driving_states":states}
	FileAccess.open(output+"/features-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VEHICLE_FEATURE_TEST ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
