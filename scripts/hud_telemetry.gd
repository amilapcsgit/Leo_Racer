class_name LeoTelemetry
extends RefCounted
## Vector instruments stay crisp at every resolution; no baked text textures.
static func glass(h: Control, r: Rect2, cyan: Color) -> void:
	var p := r.position
	var e := r.end
	var cut := minf(12.0,minf(r.size.x,r.size.y)*.25)
	var pts := PackedVector2Array([p+Vector2(cut,0),Vector2(e.x,p.y),e-Vector2(0,cut),e-Vector2(cut,0),Vector2(p.x,e.y),p+Vector2(0,cut)])
	h.draw_colored_polygon(pts,Color(.018,.031,.043,.86))
	pts.append(pts[0])
	h.draw_polyline(pts,Color(.24,.45,.49,.6),1.2,true)
	h.draw_line(p+Vector2(17,3),Vector2(e.x-5,p.y+3),Color(cyan,.32),2,true)
	for i in range(int(r.size.y/7)):
		var y := p.y+6+i*7
		h.draw_line(Vector2(p.x+8,y),Vector2(e.x-8,y),Color(.6,.8,.8,.018),1)

static func draw(h: LeoHUD) -> void:
	var cyan := Color("00f2fe")
	var amber := Color("ff9000")
	glass(h,Rect2(42,36,230,142),cyan)
	glass(h,Rect2(306,36,244,139),cyan)
	glass(h,Rect2(1193,30,365,96),cyan)
	h.draw_polyline(PackedVector2Array([Vector2(574,36),Vector2(585,75),Vector2(1145,75),Vector2(1174,36)]),Color(cyan,.5),1.2,true)
	h.draw_line(Vector2(638,81),Vector2(735,81),Color(amber,.8),2,true)
	glass(h,Rect2(42,836,735,45),cyan)
	# Position badge metallic edge.
	h.draw_line(Vector2(46,52),Vector2(46,151),Color(amber,.8),3,true)
	h.draw_line(Vector2(50,55),Vector2(50,146),Color("ffd796"),1,true)
	var c := Vector2(1400,720)
	h.draw_circle(c,155,Color(.008,.02,.033,.86),true,-1,true)
	for i in range(5):
		h.draw_arc(c,146+i*2,deg_to_rad(135),deg_to_rad(405),100,Color(0,.8,.95,.09-float(i)*.014),3,true)
	h.draw_arc(c,149,deg_to_rad(135),deg_to_rad(405),100,Color(.16,.35,.4,.85),2,true)
	h.draw_arc(c,138,deg_to_rad(135),deg_to_rad(405),100,Color(.08,.21,.28),8,true)
	var value := clampf(h.display_speed/240.0,0,1)
	for i in range(64):
		var t := float(i)/64
		var a := deg_to_rad(135+t*270)
		var b := deg_to_rad(135+(t+1.0/64)*270)
		var col := cyan.lerp(amber,smoothstep(.55,.9,t))
		h.draw_arc(c,138,a,b,3,Color(col,.9 if t<=value else .18),4,true)
	for i in range(49):
		var a := deg_to_rad(135+float(i)/48*270)
		var v := Vector2(cos(a),sin(a))
		var large := i%6==0
		h.draw_line(c+v*127,c+v*(116 if large else 122),Color(cyan,.85 if large else .4),2 if large else 1,true)
		if large:
			var label_pos := c+v*103-Vector2(9,-5)
			h.draw_string(h.heading_font,label_pos,str(i*5),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d6e8ea"))
	var angle := deg_to_rad(135+value*270)
	var needle := Vector2(cos(angle),sin(angle))
	h.draw_line(c+needle*77,c+needle*130,Color(amber,.18),9,true)
	h.draw_line(c+needle*77,c+needle*130,amber,3,true)
	h.draw_circle(c+needle*77,3,Color("fff6df"),true,-1,true)
	h.draw_arc(c,82,0,TAU,64,Color(cyan,.18),1,true)
	# Curved nitro tube; energy follows the real fuel value.
	h.draw_arc(c,164,deg_to_rad(42),deg_to_rad(138),64,Color(.27,.45,.48),23,true)
	h.draw_arc(c,164,deg_to_rad(42),deg_to_rad(138),64,Color(.018,.05,.06),18,true)
	# The shader-backed child draws liquid energy inside this fixed tube.
	# Holographic map.
	glass(h,Rect2(42,498,242,311),cyan)
	for i in range(8):
		h.draw_line(Vector2(49+i*32,507),Vector2(49+i*32,800),Color(cyan,.045),1)
	for i in range(10):
		h.draw_line(Vector2(48,508+i*32),Vector2(278,508+i*32),Color(cyan,.045),1)
	var center := Vector2(156,665)
	var line := PackedVector2Array()
	for i in range(0,h.game.circuit.points.size(),3):
		var p: Vector3 = h.game.circuit.points[i]
		line.append(center+Vector2(p.x,p.z)*.86)
	line.append(line[0])
	h.draw_polyline(line,Color(0,.65,.8,.10),15,true)
	h.draw_polyline(line,Color(.12,.32,.37),8,true)
	h.draw_polyline(line,Color("65dae0"),2,true)
	for kart in h.game.karts:
		var dot := center+Vector2(kart.position.x,kart.position.z)*.86
		if kart.is_player:
			h.draw_circle(dot,15+sin(h.time*4)*2,Color(cyan,.08),true,-1,true)
			lotus(h,dot,cyan)
		else:
			h.draw_circle(dot,4,amber,true,-1,true)
	if h.game.player.drifting:
		glass(h,Rect2(600,805,400,10),cyan)
		h.draw_rect(Rect2(602,807,396*minf(1,h.game.player.drift_charge/2.5),6),amber)

static func lotus(h: Control,c: Vector2,color: Color) -> void:
	for i in range(5):
		var a := deg_to_rad(-155+i*32)
		var v := Vector2(cos(a),sin(a))
		var side := Vector2(-v.y,v.x)
		var points := PackedVector2Array([c,c+v*5+side*3,c+v*12,c+v*5-side*3])
		h.draw_colored_polygon(points,Color(color,.92))
	h.draw_arc(c+Vector2(0,-3),7,0,PI,14,Color("d3fbff"),1.4,true)
