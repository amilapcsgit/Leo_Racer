extends SceneTree

# Run with the real renderer, not --headless:
# Godot --path LeoRacer --script res://tests/render_profile.gd -- --drive-test
# --drive-test prevents loading/writing personal settings in main.gd.
const WARMUP_SECONDS := 5.0
const SAMPLE_SECONDS := 300.0
const REPORT_PATH := "res://docs/qa-astra/render-profile.json"

var game: Node3D
var sampling := false
var completed := false
var sample_started_usec := 0
var frame_ms: Array[float] = []
var wall_frame_ms: Array[float] = []
var last_process_usec := 0
var draw_calls: Array[float] = []
var primitives: Array[float] = []
var rendered_objects: Array[float] = []
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var peak_video_bytes := 0.0
var peak_static_bytes := 0.0
var starting_progress := 0.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if "--drive-test" not in OS.get_cmdline_user_args():
		push_error("Render profiling requires -- --drive-test to avoid personal settings changes.")
		quit(2)
		return
	Engine.time_scale = 1.0
	Engine.max_fps = 120
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.diagnostics_mode = true
	game.start_race()
	game.player.auto_drive = true
	# Profile moving race rendering throughout; countdown/UI loading is warmed up.
	game.state = "race"
	for kart in game.karts:
		kart.active = true
	print("RENDER_PROFILE_WARMUP | %.1f seconds | renderer=%s | device=%s" % [WARMUP_SECONDS, RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	await create_timer(WARMUP_SECONDS, true, false, true).timeout
	await RenderingServer.frame_post_draw
	game.diagnostics_mode = true
	game.start_race()
	game.player.auto_drive = true
	game.state = "race"
	for kart in game.karts: kart.active = true
	await process_frame
	starting_progress = game.player.progress
	sample_started_usec = Time.get_ticks_usec()
	last_process_usec = sample_started_usec
	sampling = true
	print("RENDER_PROFILE_SAMPLING | %.1f seconds of wall time" % SAMPLE_SECONDS)

func _process(delta: float) -> bool:
	if not sampling:
		return false
	var now := Time.get_ticks_usec()
	frame_ms.append(delta * 1000.0)
	wall_frame_ms.append(float(now - last_process_usec) / 1000.0)
	last_process_usec = now
	draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	rendered_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	peak_video_bytes = maxf(peak_video_bytes, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	peak_static_bytes = maxf(peak_static_bytes, Performance.get_monitor(Performance.MEMORY_STATIC))
	if (game.karts.all(func(kart): return kart.finished) or float(now - sample_started_usec)/1000000.0 >= SAMPLE_SECONDS) and not completed:
		sampling = false
		completed = true
		finish.call_deferred()
	return false

func average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(1.0, float(values.size()))

func percentile(values: Array[float], fraction: float) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	if ordered.is_empty():
		return 0.0
	var index := fraction * (ordered.size() - 1)
	var lo := int(floor(index))
	var hi := mini(ordered.size() - 1, lo + 1)
	return lerpf(ordered[lo], ordered[hi], index - lo)

func minimum_one_second_fps(values: Array[float]) -> float:
	# Sliding windows include the complete frame that crosses 1,000 ms.
	var end := 0
	var elapsed := 0.0
	var minimum := INF
	for start in values.size():
		while end < values.size() and elapsed < 1000.0:
			elapsed += values[end]
			end += 1
		if elapsed >= 1000.0:
			minimum = minf(minimum, float(end - start) * 1000.0 / elapsed)
		elapsed -= values[start]
	return 0.0 if is_inf(minimum) else minimum

func finish() -> void:
	var wall_seconds := float(last_process_usec - sample_started_usec) / 1000000.0
	var report := {
		"status": "COMPLETE",
		"godot_version": Engine.get_version_info().string,
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(),
		"device_vendor": RenderingServer.get_video_adapter_vendor(),
		"cpu": OS.get_processor_name(),
		"viewport_pixels": [root.size.x, root.size.y],
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"physics_interpolation_enabled": ProjectSettings.get_setting("physics/common/physics_interpolation", false),
		"max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"warmup_seconds": WARMUP_SECONDS,
		"sample_wall_seconds": wall_seconds,
		"sample_frames": frame_ms.size(),
		"mean_fps": float(frame_ms.size()) / maxf(.001, wall_seconds),
		"mean_process_frame_ms": average(frame_ms),
		"p50_frame_ms": percentile(frame_ms, .50),
		"p95_frame_ms": percentile(frame_ms, .95),
		"p99_frame_ms": percentile(frame_ms, .99),
		"minimum_one_second_fps": minimum_one_second_fps(wall_frame_ms),
		"average_draw_calls": average(draw_calls),
		"average_render_primitives": average(primitives),
		"average_rendered_objects": average(rendered_objects),
		"average_cpu_process_ms": average(process_ms),
		"average_cpu_physics_ms": average(physics_ms),
		"peak_video_memory_bytes": peak_video_bytes,
		"peak_static_memory_bytes": peak_static_bytes,
		"player_start_progress_m": starting_progress,
		"player_end_progress_m": game.player.progress,
		"racer_count": game.karts.size(),
		"full_race_completed": game.karts.all(func(kart): return kart.finished),
		"frame_times_ms": frame_ms,
		"wall_frame_times_ms": wall_frame_ms,
		"notes": "Real GPU/windowed render; no headless mode. Frame deltas include rendering, presentation, CPU work and the explicit 120 FPS cap. Primitive counts are Godot render-monitor primitives, including renderer passes; they are not unique scene triangles."
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write render profile: %s" % error_string(FileAccess.get_open_error()))
	else:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("RENDER_PROFILE_REPORT | fps=%.2f | p50=%.2f ms | p95=%.2f ms | p99=%.2f ms | min1sec=%.2f fps | drawcalls=%.1f | primitives=%.0f | device=%s" % [report.mean_fps, report.p50_frame_ms, report.p95_frame_ms, report.p99_frame_ms, report.minimum_one_second_fps, report.average_draw_calls, report.average_render_primitives, report.device])
	game.set_process(false)
	game.hud.set_process(false)
	game.state = "profile_complete"
	game.stop_all_audio()
	game.remove_racers()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if file != null else 1)
