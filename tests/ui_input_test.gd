extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,words: String) -> void:
 checks+=1
 if not ok:failures.append(words);push_error(words)
func key(code: Key,location: KeyLocation=KEY_LOCATION_UNSPECIFIED,pressed: bool=true) -> InputEventKey:
 var e:=InputEventKey.new();e.physical_keycode=code;e.location=location;e.pressed=pressed;return e
func run() -> void:
 var router:=LeoInputRouter.new();router.settings_path="user://ui-input-test.cfg"
 if FileAccess.file_exists(router.settings_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(router.settings_path))
 root.add_child(router)
 for p in router.players:p.preference="auto"
 router.resolve_automatic(2,[],{},true)
 check(router.players.all(func(p):return p.kind=="keyboard"),"Zero controllers gives two keyboard players")
 check(router.ready_problem(0).is_empty() and router.ready_problem(1).is_empty(),"Shared defaults are immediately valid")
 router.feed(key(KEY_W));router.feed(key(KEY_RIGHT))
 check(router.players[0].throttle()==1. and router.players[1].throttle()==0. and router.players[1].steering()==1. and router.players[0].steering()==0.,"Simultaneous independent steering and acceleration")
 router.feed(key(KEY_SHIFT,KEY_LOCATION_LEFT))
 check(router.players[0].value("boost")==1. and router.players[1].value("boost")==0.,"Left Shift only boosts P1")
 router.feed(key(KEY_SHIFT,KEY_LOCATION_RIGHT))
 check(router.players[0].value("boost")==1. and router.players[1].value("boost")==1.,"Both shifts can be held")
 router.feed(key(KEY_SHIFT,KEY_LOCATION_LEFT,false))
 check(router.players[0].value("boost")==0. and router.players[1].value("boost")==1.,"Releasing left shift preserves right shift")
 router.feed(key(KEY_SPACE));router.feed(key(KEY_CTRL,KEY_LOCATION_RIGHT))
 check(router.players[0].value("drift")==1. and router.players[1].value("drift")==1.,"Simultaneous independent drift")
 router.clear_all();check(router.players.all(func(p):return p.throttle()==0. and p.value("boost")==0.),"Focus loss clears both players")
 router.resolve_automatic(1,[],{},true)
 check(router.players[0].keyboard_preset=="solo","Solo preset restored")
 router.resolve_automatic(2,[9],{},true)
 check(router.players[0].device==9 and router.players[1].kind=="keyboard","One controller plus keyboard")
 router.resolve_automatic(2,[9,7],{},true)
 check(router.players[0].device==9 and router.players[1].device==7,"Existing Auto device stays assigned; next free fills P2")
 for p in router.players:p.device=-1;p.preference="auto"
 router.resolve_automatic(2,[9,7],{},true)
 check(router.players[0].device==7 and router.players[1].device==9,"Fresh assignment uses sorted runtime IDs")
 router.assignment_locked=true;router.resolve_automatic(2,[5,6],{},true)
 check(router.players[0].device==7 and router.players[1].device==9,"No automatic reassignment during race")
 router.assignment_locked=false
 check(not router.assign(1,"gamepad",7,false),"Controller cannot belong to both players")
 for p in router.players:p.preference="auto"
 router.resolve_automatic(2,[],{},true)
 router.start_capture(1,"horn");router._capture(key(KEY_H))
 check(not router.pending_binding.is_empty(),"Cross-player key conflict is detected")
 router.resolve_conflict("swap")
 check(router.players[0].bindings.horn[0].index==KEY_ENTER and router.players[1].bindings.horn[0].index==KEY_H,"Safe binding swap")
 check(router.save_profiles()==OK,"New profiles save")
 var snapshot:=router.players[1].serialize();router.load_profiles()
 check(router.players[1].serialize()==snapshot,"Versioned profiles round trip")
 var legacy:=LeoPlayerInput.new("keyboard");var old:={"kind":"keyboard","bindings":legacy.bindings.duplicate(true),"identity":{}}
 legacy.restore(old)
 check(legacy.preference=="manual" and not legacy.custom_bindings,"Legacy default profile migration")
 old.bindings.horn=[{"type":"key","index":KEY_J}];legacy.restore(old)
 check(legacy.custom_bindings and legacy.bindings.horn[0].index==KEY_J,"Legacy custom remap preserved")
 legacy.use_keyboard_preset("shared1")
 check(legacy.bindings.horn[0].index==KEY_J and legacy.bindings.accelerate.size()==1 and legacy.bindings.accelerate[0].index==KEY_W,"Shared preset preserves custom actions while separating default movement")
 legacy.use_keyboard_preset("solo")
 check(legacy.bindings.horn[0].index==KEY_J and legacy.bindings.accelerate.size()==2,"Leaving shared mode restores the complete solo bindings")
 legacy.use_keyboard_preset("shared1");legacy.bindings.horn=[{"type":"key","index":KEY_K}];legacy.custom_bindings=true
 legacy.use_keyboard_preset("solo");legacy.use_keyboard_preset("shared1")
 check(legacy.bindings.horn[0].index==KEY_K,"Shared-mode remaps survive leaving and returning to shared mode")
 var restored:=LeoPlayerInput.new();restored.restore(legacy.serialize());restored.use_keyboard_preset("solo")
 check(restored.bindings.horn[0].index==KEY_J,"Solo and shared remaps survive a profile reload independently")
 var report:={"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"errors":failures}
 DirAccess.make_dir_recursive_absolute("res://build/qa-ui")
 FileAccess.open("res://build/qa-ui/ui-input.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("UI_INPUT_TEST ",JSON.stringify(report))
 router.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
