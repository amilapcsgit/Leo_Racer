extends SceneTree
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func verify(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message)
	print(("PASS " if ok else "FAIL ")+message)
func run() -> void:
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var sri: LeoSriLankaWorld=game.world.find_child("SriLanka2026",true,false)
	verify(sri!=null,"Supplied Sri Lanka scenery replaces the presentation world")
	verify(is_equal_approx(game.environment.tonemap_exposure,1.1),"ACES exposure stays at 1.1")
	verify(game.environment.tonemap_mode==Environment.TONE_MAPPER_ACES,"ACES tonemapping is active")
	verify(game.world.find_child("AuthenticLotusTower",true,false)!=null,"Authentic supplied tower is active")
	verify(game.art_profile.world_model.ends_with("srilanka/world.glb"),"Filtered world preserves original road geometry")
	verify(get_nodes_in_group("sri_boundary").size()==4,"Both boundaries and painted curbs are installed")
	verify(sri.national_flags>=28,"National flags occupy real lamp anchors on both sides")
	verify(sri.advertising_faces>=60,"Advertising panels have populated front and back faces")
	var art: Dictionary={}
	for face in get_nodes_in_group("sri_advertising"):
		var texture: Texture2D=face.material_override.albedo_texture
		art[texture.resource_path]=true
	verify(art.size()==8,"All eight generated festival designs appear in the scene")
	verify(sri.transport_count==5,"Exactly four tuk-tuks and one bus are placed")
	for p in sri.transport_placements:verify(absf(game.circuit.project(p).offset)>=17.4,"Transport stays outside the racing boundary: "+str(p))
	verify(LeoHUD.speed_line_strength(149.9/3.6,false,true,false)==0,"Cruising speed lines stay off below 150 km/h")
	verify(LeoHUD.speed_line_strength(165.0/3.6,false,true,false)>0,"Cruising speed lines ramp above 150 km/h")
	verify(is_equal_approx(LeoHUD.speed_line_strength(180.0/3.6,false,true,false),.65),"Speed-line cruise envelope reaches its bounded maximum")
	verify(LeoHUD.speed_line_strength(55,true,true,false)==1,"Boost takes the stronger envelope without stacking")
	verify(LeoHUD.speed_line_strength(55,true,true,true)==0,"Reduced Motion suppresses screen speed lines")
	game.start_race()
	game.state="race"
	for kart in game.karts:kart.set_physics_process(false)
	game.player.boost_fuel=.5
	game.hud._process(.1)
	verify(is_instance_valid(game.hud.nitro_liquid),"Liquid nitro instrument is installed")
	verify(game.hud.nitro_liquid.material.get_shader_parameter("fuel")<1,"Liquid meter reads gameplay fuel")
	game.paused=true
	var frozen: float=game.hud.time
	game.hud._process(.2)
	verify(game.hud.time==frozen,"HUD shader animation clock freezes during pause")
	game.paused=false
	game.set_reduced_motion(true)
	game.hud._process(.1)
	verify(game.hud.nitro_liquid.material.get_shader_parameter("motion")==0,"Reduced Motion freezes energy flow")
	var report:={"checks":checks,"errors":errors,"status":"PASS" if errors.is_empty() else "FAIL"}
	FileAccess.open("res://docs/qa-srilanka/srilanka-test.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SRI_REPORT ",JSON.stringify(report))
	game.stop_all_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)
