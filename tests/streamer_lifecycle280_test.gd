extends SceneTree
const STRESS := preload("res://tests/teardown280_test.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var report: Dictionary=STRESS.verify_detached_anchors(root)
	print("STREAMER_LIFECYCLE280_TEST ",JSON.stringify(report))
	quit(0 if report.errors.is_empty() else 1)
