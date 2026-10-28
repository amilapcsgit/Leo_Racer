extends RefCounted
## A bounded last-launch diagnostic; records no account, controller or personal data.
static var marks: Array=[]
static func mark(stage: String) -> void:
	var entry:={"stage":stage,"milliseconds":Time.get_ticks_msec()}
	marks.append(entry)
	if marks.size()>32:marks.pop_front()
	var file:=FileAccess.open("user://startup-last.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":"2.6.0","stages":marks},"  "))
	print("BOOT_STAGE ",JSON.stringify(entry))
