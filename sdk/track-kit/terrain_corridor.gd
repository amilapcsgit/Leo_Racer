extends RefCounted
## Offline mesh cutting: decorative terrain may never span the race corridor.
var route:=PackedVector2Array()
var bins: Dictionary={}
var report: Dictionary={}
const CELL:=128.
func _init(points: PackedVector3Array) -> void:
 for p in points:route.append(Vector2(p.x,p.z))
 for i in route.size():
  var a:=route[i];var b:=route[(i+1)%route.size()]
  var lo:=(a.min(b)-Vector2.ONE*320.)/CELL;var hi:=(a.max(b)+Vector2.ONE*320.)/CELL
  for x in range(floori(lo.x),floori(hi.x)+1):
   for z in range(floori(lo.y),floori(hi.y)+1):
    var key:=Vector2i(x,z)
    if not bins.has(key):bins[key]=[]
    bins[key].append(i)
func distance(p: Vector2) -> float:
 var result:=INF;var key:=Vector2i(floori(p.x/CELL),floori(p.y/CELL))
 for i in bins.get(key,[]):result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[(i+1)%route.size()])))
 return result
func y_on_triangle(p: Vector2,a: Vector3,b: Vector3,c: Vector3) -> float:
 var det:=(b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
 if absf(det)<.000001:return a.y
 var u:=((p.x-a.x)*(c.z-a.z)-(p.y-a.z)*(c.x-a.x))/det
 var v:=((b.x-a.x)*(p.y-a.z)-(b.z-a.z)*(p.x-a.x))/det
 return a.y+u*(b.y-a.y)+v*(c.y-a.y)
func cut(mesh: Mesh,margin: float,label: String) -> ArrayMesh:
 var outer:=Geometry2D.offset_polygon(route,margin);var inner:=Geometry2D.offset_polygon(route,-margin)
 var faces:=mesh.get_faces();var output:=SurfaceTool.new();output.begin(Mesh.PRIMITIVE_TRIANGLES)
 var kept:=0;var cut_count:=0;var removed:=0
 for i in range(0,faces.size(),3):
  var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
  var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
  var center: Vector2=(triangle[0]+triangle[1]+triangle[2])/3.
  var radius:=maxf(center.distance_to(triangle[0]),maxf(center.distance_to(triangle[1]),center.distance_to(triangle[2])))
  var nearest:=distance(center)
  if nearest>margin+radius+.1:
   for vertex in [a,b,c]:output.set_normal(Vector3.UP);output.add_vertex(vertex)
   kept+=1;continue
  if nearest+radius<margin-.1:removed+=1;continue
  var pieces: Array[PackedVector2Array]=[triangle]
  for boundary in outer:
   var next: Array[PackedVector2Array]=[]
   for piece in pieces:
    for part in Geometry2D.clip_polygons(piece,boundary):next.append(part)
   pieces=next
  for boundary in inner:
   for part in Geometry2D.intersect_polygons(triangle,boundary):pieces.append(part)
  for piece in pieces:
   var indices:=Geometry2D.triangulate_polygon(piece)
   for index in indices:
    var p:=piece[index];output.set_normal(Vector3.UP);output.add_vertex(Vector3(p.x,y_on_triangle(p,a,b,c),p.y))
  cut_count+=1
 report[label]={"source_triangles":faces.size()/3,"untouched":kept,"clipped":cut_count,"removed":removed,"protected_half_width_m":margin}
 return output.commit()
