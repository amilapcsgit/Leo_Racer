class_name LeoLoadingBackdrops
extends RefCounted
const DAY="res://assets/art/menu.png"
const NIGHT="res://assets/ui/art/home.png"
const TRACKS=["astra_coast","colombo_city","kandy_lake"]
const REGISTRY="res://assets/config/loading-gallery-v279.json"
static var operation: String=""
static var operation_track: String=""
static var selected: String=""
static var sequence:=0
static var bags: Dictionary={}
static var previous: Dictionary={}
static var entries: Array=[]
static func inventory() -> Array:
 if entries.is_empty() and FileAccess.file_exists(REGISTRY):
  var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
  if data is Dictionary and data.get("artworks") is Array:entries=data.artworks
 return entries
static func caption(path: String) -> String:
 for row in inventory():
  if row.path==path:return String(row.get("caption","Sri Lanka · Leo Racer artwork"))
 return "Sri Lanka · Leo Racer artwork"
static func paths(_track_id: String="",preview: String="") -> Array[String]:
 var result: Array[String]=[]
 for row in inventory():
  var path:=String(row.get("path",""))
  if not path.is_empty() and ResourceLoader.exists(path) and not path in result:result.append(path)
 if result.is_empty() and not preview.is_empty() and FileAccess.file_exists(preview):result.append(preview)
 if result.is_empty():
  for path in [DAY,NIGHT]:
   if ResourceLoader.exists(path):result.append(path)
 return result
static func begin_load(operation_id: String,track_id: String="",preview: String="") -> String:
 if operation_id==operation and not selected.is_empty():return selected
 var choices:=paths(track_id,preview)
 if choices.is_empty():return ""
 var remaining: Array=bags.get("gallery",[])
 if remaining.is_empty() or not remaining.all(func(path):return path in choices):
  remaining=choices.duplicate();remaining.shuffle()
  if remaining.size()>1 and remaining[-1]==previous.get("gallery",""):
   var first: Variant=remaining[0];remaining[0]=remaining[-1];remaining[-1]=first
 selected=remaining.pop_back();bags["gallery"]=remaining;previous["gallery"]=selected
 operation=operation_id;operation_track=track_id;return selected
static func new_operation(kind: String) -> String:
 sequence+=1;return kind+"-"+str(sequence)
