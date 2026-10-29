class_name LeoLoadingBackdrops
extends RefCounted
const DAY="res://assets/art/menu.png"
const NIGHT="res://assets/ui/art/home.png"
const TRACKS=["astra_coast","colombo_city","kandy_lake"]
static var operation: String=""
static var operation_track: String=""
static var selected: String=""
static var sequence:=0
static var bags: Dictionary={}
static var previous: Dictionary={}
static func paths(track_id: String,preview: String="") -> Array[String]:
 var result: Array[String]=[]
 if track_id in TRACKS:
  for number in ["01","02","03"]:
   var path: String="res://assets/ui/boot/tracks/"+track_id+"/"+number+".png"
   if ResourceLoader.exists(path):result.append(path)
 if result.is_empty() and not preview.is_empty() and FileAccess.file_exists(preview):result.append(preview)
 if result.is_empty():result.assign([DAY,NIGHT])
 return result
static func begin_load(operation_id: String,track_id: String="",preview: String="") -> String:
 if operation_id==operation and operation_track==track_id and not selected.is_empty():return selected
 var choices:=paths(track_id,preview)
 var remaining: Array=bags.get(track_id,[])
 if remaining.is_empty() or not remaining.all(func(path):return path in choices):
  remaining=choices.duplicate();remaining.shuffle()
  if remaining.size()>1 and remaining[-1]==previous.get(track_id,""):
   var first: Variant=remaining[0];remaining[0]=remaining[-1];remaining[-1]=first
 selected=remaining.pop_back();bags[track_id]=remaining;previous[track_id]=selected
 operation=operation_id;operation_track=track_id;return selected
static func new_operation(kind: String) -> String:
 sequence+=1;return kind+"-"+str(sequence)
