extends SceneTree
const Logic=preload("res://scripts/local/game_logic279.gd")
const Main=preload("res://scripts/main.gd")
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func fixture(ids: Array[String]) -> GarageCatalog:
	var catalog:=GarageCatalog.new()
	for id in ids:
		var vehicle:=VehicleDefinition.new();vehicle.id=StringName(id);vehicle.display_name=id;catalog.vehicles.append(vehicle)
	return catalog
func run() -> void:
	var output:=ProjectSettings.globalize_path("res://build/qa279/game-logic")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(output)
	var config:=ConfigFile.new()
	check(not Logic.read_preference(config),"Missing preference defaults to OFF")
	config.set_value("audio","volume",.72)
	check(not Logic.read_preference(config),"Existing settings without the new key default to OFF")
	Logic.write_preference(config,true)
	var file:=output.path_join("settings-roundtrip.cfg")
	check(config.save(file)==OK,"Opt-in preference saves to a real configuration file")
	var restored:=ConfigFile.new();check(restored.load(file)==OK and Logic.read_preference(restored),"Opt-in survives configuration reload")
	Logic.write_preference(restored,false);restored.save(file)
	var disabled:=ConfigFile.new();disabled.load(file)
	check(not Logic.read_preference(disabled),"OFF survives configuration reload")
	config.set_value("game","allow_ai_bigster","false")
	check(not Logic.read_preference(config),"Malformed non-boolean preference fails closed")
	var catalog:=fixture(["bigster","duster","duster_2024","qa_addon"])
	check(LeoDefaultRoster.fallback(catalog)==&"bigster","Human default Bigster selection remains unchanged")
	var pool:=LeoDefaultRoster.ai_vehicles(catalog)
	check(pool.size()==2 and not pool.any(func(v):return v.id==&"bigster"),"Default AI roster excludes Bigster")
	check(not pool.any(func(v):return v.id==&"qa_addon"),"Automatic grids retain the reviewed default roster")
	check(LeoDefaultRoster.ai_vehicles(catalog,true).any(func(v):return v.id==&"bigster"),"Explicit opt-in permits Bigster in the AI pool")
	var game:=Main.new();game.diagnostics_mode=true;game.catalog=catalog;game.human_count=1;game.selected_kart=0
	check(not game.allow_ai_bigster,"New game preference defaults to OFF")
	check(game.prepare_ai_roster().is_empty(),"Default grid prepares successfully")
	var before: Array[StringName]=[]
	for slot in range(1,6):
		var vehicle: VehicleDefinition=game.default_ai_vehicle(slot)
		check(vehicle!=null and vehicle.id!=&"bigster","Default warmup/grid/spawn lookup excludes Bigster / "+str(slot))
		before.append(vehicle.id)
	check(game.default_ai_vehicle(0)==null and game.catalog.vehicles[game.selected_kart].id==&"bigster","Human Bigster slot is not changed by AI filtering")
	game.set_allow_ai_bigster(true)
	for slot in range(1,6):check(game.default_ai_vehicle(slot).id==before[slot-1],"Changing preference preserves the active grid / "+str(slot))
	check(not game.race_game_logic.active_allow_ai_bigster,"Active policy remains OFF until a new start/restart")
	check(game.prepare_ai_roster().is_empty() and game.race_game_logic.active_allow_ai_bigster,"Restart takes a new opt-in policy snapshot")
	# A two-car fixture makes the permission observable in the deterministic grid.
	game.catalog=fixture(["bigster","duster"]);game.prepare_ai_roster()
	var includes_bigster:=false
	for slot in range(1,6):includes_bigster=includes_bigster or game.default_ai_vehicle(slot).id==&"bigster"
	check(includes_bigster,"Opt-in can actually spawn Bigster as an AI opponent")
	game.set_allow_ai_bigster(false);game.prepare_ai_roster()
	for slot in range(1,6):check(game.default_ai_vehicle(slot).id==&"duster","Next restart applies OFF to every AI slot / "+str(slot))
	game.human_count=2;game.prepare_ai_roster()
	check(game.default_ai_vehicle(0)==null and game.default_ai_vehicle(1)==null,"Both human slots are excluded from AI policy")
	for slot in range(2,6):check(game.default_ai_vehicle(slot).id==&"duster","Split-screen AI slots obey OFF / "+str(slot))
	var frozen: VehicleDefinition=game.default_ai_vehicle(2)
	game.catalog=fixture(["bigster"])
	var failure:=game.prepare_ai_roster()
	check(not failure.is_empty() and "Game Logic" in failure and "Content" in failure,"No eligible AI returns actionable pre-start failure")
	check(game.default_ai_vehicle(2)==frozen,"Failed restart leaves its previous active grid intact")
	var fresh:=Logic.new()
	check(not fresh.prepare(game.catalog,1,0,false).is_empty() and fresh.vehicle(1)==null,"Empty eligible pool has no hidden Bigster fallback")
	check(fresh.prepare(game.catalog,1,0,true).is_empty() and fresh.vehicle(1).id==&"bigster","Bigster-only installation can race after explicit opt-in")
	check(not fresh.prepare(fixture([]),1,0,true).is_empty(),"Completely empty pool fails safely even with opt-in")
	game.free()
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors,"gpu_required":false}
	FileAccess.open(output.path_join("game-logic279.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("GAME_LOGIC279_RESULT ",JSON.stringify(report));quit(0 if errors.is_empty() else 1)
