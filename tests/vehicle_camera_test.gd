extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var assets:=OS.get_environment("LEO_ASSET_ROOT")
 if assets.is_empty():assets=ProjectSettings.globalize_path("res://build/Release-2.3.2/GameAssets")
 assert(LeoAssets.configure(assets)==OK and LeoAssets.mount_packs()==OK)
 LeoVehicleLibrary.discover(assets.path_join("vehicles"))
 var game:=load("res://scenes/main.tscn").instantiate()
 root.add_child(game);await game.initialization_finished
 var probe:=preload("res://scripts/content/vehicle_check.gd").new();probe.game=game;root.add_child(probe);await probe.run()
