extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var report: Dictionary=await load("res://scripts/content/content_refresh_check.gd").run(self)
 FileAccess.open("res://build/modularity/refresh.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CONTENT_REFRESH_TEST ",JSON.stringify(report));quit(0 if report.status=="PASS" else 1)
