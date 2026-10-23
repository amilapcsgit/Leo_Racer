class_name LeoLoadingBackdrops
extends RefCounted
const DAY="res://assets/art/menu.png"
const NIGHT="res://assets/ui/art/home.png"
static var operation: String=""
static var selected: String=""
static var next_day: int=-1
static var sequence:=0
static func begin_load(operation_id: String) -> String:
 if operation_id==operation and not selected.is_empty():return selected
 if next_day<0:next_day=randi()%2
 selected=DAY if next_day==1 else NIGHT;next_day=1-next_day;operation=operation_id
 return selected
static func new_operation(kind: String) -> String:
 sequence+=1;return kind+"-"+str(sequence)
