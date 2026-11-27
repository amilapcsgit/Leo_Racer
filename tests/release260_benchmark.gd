extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	LeoAssets.configure(ProjectSettings.globalize_path("res://build/preview260/GameAssets"));LeoAssets.mount_packs()
	LeoVehicleLibrary.discover()
	var game: Node3D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await game.initialization_finished
	var probe: Node=load("res://tests/release260_benchmark_probe.gd").new()
	probe.game=game;root.add_child(probe);await probe.run()
