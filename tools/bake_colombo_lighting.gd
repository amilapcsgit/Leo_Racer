extends SceneTree
## Authored radiance, not a PNG renamed or expanded into a floating-point file.
func _initialize() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/art/colombo")
	var image:=Image.create_empty(1024,512,false,Image.FORMAT_RGBF)
	var sun:Vector3=(Basis.from_euler(Vector3(deg_to_rad(-65.),deg_to_rad(-145.),0.))*Vector3.BACK).normalized()
	var maximum:=0.
	for y in 512:
		var theta:float=(y+.5)*PI/512.
		for x in 1024:
			var azimuth:float=((x+.5)/1024.-.5)*TAU
			var direction:=Vector3(sin(azimuth)*sin(theta),cos(theta),cos(azimuth)*sin(theta))
			var color:Color
			if direction.y>=0.:
				color=Color(.82,1.10,1.48).lerp(Color(.17,.48,1.10),pow(direction.y,.4))*1.4
				var angle:=acos(clampf(direction.dot(sun),-1.,1.))
				var disk:=1.-smoothstep(.0035,.006,angle)
				var halo:=pow(maxf(direction.dot(sun),0.),160.)*.8
				color+=Color(1.,.97,.90)*(disk*1800.+halo)
			else:color=Color(.19,.21,.17)*lerpf(.7,1.,1.+direction.y)
			maximum=maxf(maximum,color.r);image.set_pixel(x,y,color)
	assert(maximum>100.)
	assert(image.save_exr("res://assets/art/colombo/midday_lighting.exr")==OK)
	FileAccess.open("res://assets/art/colombo/lighting.json",FileAccess.WRITE).store_string(JSON.stringify({"format":1,"authoring":"linear procedural atmosphere plus explicit radiance sun","dimensions":[1024,512],"peak_linear_radiance":maximum,"sun_angles_degrees":[-65,-145,0],"source":"tools/bake_colombo_lighting.gd","generated_visual_is_hdr":false},"  "))
	print("COLOMBO_HDR_BAKED peak_linear_radiance=",maximum);quit()
