class_name LeoSpeedDigits
extends RefCounted
static var font: FontFile
static func configure(label: Label) -> void:
	if not font:
		font=load("res://assets/fonts/heading.ttf").duplicate() as FontFile
		font.multichannel_signed_distance_field=false
		font.fixed_size=0
		# Populate the exact glyph range before the first race frame.
		font.get_string_size("0123456789",HORIZONTAL_ALIGNMENT_LEFT,-1,91)
	label.add_theme_font_override("font",font)
	label.add_theme_constant_override("outline_size",2)
	label.add_theme_constant_override("shadow_outline_size",0)
	label.clip_text=false
	label.z_index=10
	label.set_meta("digit_rendering","bundled_raster_font")

static func diagnostic(label: Label,reason: String,slot: int) -> Dictionary:
	var report:={"time":Time.get_datetime_string_from_system(true),"reason":reason,"player":slot+1,"version":"2.7.8",
		"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"window":str(DisplayServer.window_get_size()),"screen":str(DisplayServer.screen_get_size()),"mode":DisplayServer.window_get_mode(),
		"text":label.text,"visible":label.is_visible_in_tree(),"rect":str(label.get_global_rect()),"font_size":label.get_theme_font_size("font_size"),
		"raster_font":label.get_theme_font("font")==font,"glyphs":font.has_char(48) and font.has_char(57)}
	var path:="user://speedometer-diagnostics.jsonl"
	if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size()>262144:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".previous"))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".previous"))
	var file:=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file:file.seek_end();file.store_line(JSON.stringify(report))
	return report
