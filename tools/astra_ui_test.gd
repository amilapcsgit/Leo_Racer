extends SceneTree
## Reproducible headless garage, navigation, scaling and map contract.
## Run: Godot --headless --path . --script tools/astra_ui_test.gd
class GarageGame:
	extends Node3D
	var ROSTER := [
		{"name":"Sonic","tagline":"Blue blur. Big grin. Born for the coast."},
		{"name":"Leo","tagline":"Roaring heart."},
		{"name":"Ellie","tagline":"Island energy."},
		{"name":"Rio","tagline":"Tropical colour."},
		{"name":"Shaven Leo","tagline":"Fresh cut. Full throttle."}]
	var KARTS: Array = []
	var selected_driver := 4
	var selected_kart := 8
	var reduced_motion := false
	var paused := false
	func _init() -> void:
		for n in ["Blue Bolt","Sunset GT","Palm Dash","Lotus Pop","Formula Blue","Formula Red","Lion GT","Racing Tuk-Tuk","Party Bus"]:
			KARTS.append({"name":n,"speed":4.2,"grip":4.0,"accel":3.8})
	func enter_garage() -> void: pass
	func select_driver(i: int) -> void: selected_driver=i
	func select_kart(i: int) -> void: selected_kart=i
	func start_race() -> void: pass
	func return_menu() -> void: pass

var failures: Array[String] = []
var checks := 0
var layouts: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		print("FAIL ",description)
func test_layout(resolution: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size=resolution
	root.add_child(viewport)
	var game := GarageGame.new()
	viewport.add_child(game)
	var hud := LeoHUD.new()
	hud.game=game
	game.add_child(hud)
	await process_frame
	hud.show_garage()
	await process_frame
	var prefix := "%dx%d / " % [resolution.x,resolution.y]
	var start_checks := checks
	check(hud.garage_buttons.size()==16,prefix+"Five driver and nine vehicle buttons plus race/back exist")
	var design_rect := Rect2(hud.position,hud.size*hud.scale)
	check(design_rect.position.x>=-.01 and design_rect.position.y>=-.01 and design_rect.end.x<=resolution.x+.01 and design_rect.end.y<=resolution.y+.01,prefix+"Whole design canvas fits viewport")
	check(is_equal_approx(hud.scale.x,hud.scale.y),prefix+"Scaling preserves aspect ratio")
	check((design_rect.get_center()-Vector2(resolution)*.5).length()<.01,prefix+"Canvas stays centered")
	var cards: Array[Rect2] = []
	for b in hud.garage_buttons:
		var description := b.text.replace("\n"," ")
		check(b.position.x>=0 and b.position.y>=0 and b.position.x+b.size.x<=668 and b.position.y+b.size.y<=900,prefix+"Card inside design canvas: "+description)
		cards.append(Rect2(b.position,b.size))
		for neighbor in ["left","right","top","bottom"]:
			check(not b.get("focus_neighbor_"+neighbor).is_empty() and b.get_node_or_null(b.get("focus_neighbor_"+neighbor))!=null,prefix+"Focus neighbor resolves: "+description+" / "+neighbor)
	for i in cards.size():
		for j in range(i+1,cards.size()):
			check(not cards[i].intersects(cards[j]),prefix+"Cards remain disjoint %d/%d" % [i,j])
	check(viewport.gui_get_focus_owner()==hud.garage_buttons[13],prefix+"Selected Party Bus retains focus")
	var previous_time := hud.time
	game.paused=true
	hud._process(.5)
	check(hud.time==previous_time,prefix+"UI animation freezes during pause")
	game.paused=false
	for driver in range(5):
		hud.choose_driver(driver)
		await process_frame
		check(viewport.gui_get_focus_owner()==hud.garage_buttons[driver],prefix+"Driver focus survives rebuild %d" % driver)
		for vehicle in range(9):
			hud.choose_vehicle(vehicle)
			await process_frame
			check(game.selected_driver==driver and game.selected_kart==vehicle and viewport.gui_get_focus_owner()==hud.garage_buttons[5+vehicle],prefix+"Combination %d/%d selects and retains focus" % [driver,vehicle])
	game.reduced_motion=true
	hud._process(.5)
	var all_static := true
	for b in hud.garage_buttons:
		all_static=all_static and b.scale.distance_to(Vector2.ONE)<.001
	check(all_static,prefix+"Reduced Motion suppresses card scale animation")
	hud.photo_mode=true
	hud.announcement="STALE RECOVERY"
	hud.announcement_time=8.0
	hud.display_speed=211.0
	hud.display_nitro=.12
	hud.show_race()
	check(not hud.photo_mode,prefix+"Restart clears F8 photo mode")
	check(hud.announcement.is_empty() and hud.announcement_time==0.0,prefix+"Restart clears prior race callout")
	check(hud.display_speed==0.0 and hud.display_nitro==1.0,prefix+"Restart initializes smoothed instruments")
	check(hud.hud_root.visible and not hud.menu_root.visible and hud.modal_root.get_child_count()==0,prefix+"Restart restores race HUD and dismisses modal")
	# This narrow UI fixture has no live racer. Stop telemetry before the next frame.
	hud.scene_mode="garage"
	layouts.append({"resolution":[resolution.x,resolution.y],"scale":hud.scale.x,"canvas_position":[hud.position.x,hud.position.y],"checks":checks-start_checks,"combinations":45})
	viewport.queue_free()
	await process_frame
func test_minimap(points: PackedVector3Array, description: String) -> void:
	var bounds := Rect2(62,521,203,269)
	var projection := LeoTelemetry.map_transform(points,bounds)
	var inside := true
	for p in points:
		var mapped := projection*Vector2(p.x,p.z)
		inside=inside and mapped.x>=bounds.position.x-.01 and mapped.x<=bounds.end.x+.01 and mapped.y>=bounds.position.y-.01 and mapped.y<=bounds.end.y+.01
	check(inside,description+" minimap fits every circuit point")
func run() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		await test_layout(resolution)
	var circuit := LeoCircuit.new()
	test_minimap(circuit.points,"Actual Astra route")
	test_minimap(PackedVector3Array([Vector3(-300,0,-700),Vector3(500,0,-700),Vector3(500,0,800),Vector3(-300,0,800)]),"Oversize 1.5km extent")
	check(LeoHUD.speed_line_strength(150.0/3.6,false,true,false)==0.0,"Measured-speed lines begin above 150 km/h")
	check(is_equal_approx(LeoHUD.speed_line_strength(180.0/3.6,false,true,false),.65),"Measured-speed lines reach full at 180 km/h")
	check(LeoHUD.speed_line_strength(50,true,true,true)==0.0,"Reduced Motion suppresses speed lines")
	check(LeoHUD.speed_line_strength(50,true,false,false)==0.0,"Inactive racer suppresses speed lines")
	check(LeoHUD.speed_line_strength(50,true,true,false)==1.0,"Boost uses stronger intensity rather than adding values")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"layouts":layouts,"track_points":circuit.points.size(),"scope":"UI layout, focus, combinations, pause, Reduced Motion, minimap and measured-speed effect contract; full driving and performance are separate tests."}
	var output := FileAccess.open("res://docs/qa-astra/ui-layout.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  "))
	output.close()
	print("ASTRA_UI_REPORT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
