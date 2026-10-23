extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var profile:LeoArtProfile=load("res://assets/config/colombo-city.tres")
	assert(profile.sun_angles==Vector3(-65,-145,0))
	var matte:=Image.load_from_file(profile.sky_visual_path)
	assert(matte.get_width()==matte.get_height()*2)
	var hdr:=Image.load_from_file(profile.sky_lighting_path)
	assert(hdr.get_format() in [Image.FORMAT_RGBF,Image.FORMAT_RGBAF,Image.FORMAT_RGBH,Image.FORMAT_RGBAH])
	var peak:=0.
	for y in hdr.get_height():
		for x in hdr.get_width():peak=maxf(peak,hdr.get_pixel(x,y).r)
	assert(peak>100.,"Lighting must contain authored HDR radiance")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await game.initialization_finished
	await game.select_track("colombo_city")
	assert(game.environment.sky.sky_material is ShaderMaterial)
	assert(not game.environment.ssr_enabled and not game.environment.volumetric_fog_enabled)
	assert(not game.track_definition.modified and game.track_definition.revision==1)
	print("COLOMBO_LIGHTING_PASS ratio=2:1 peak=",peak," rules_revision=1")
	await game.quit_game()
