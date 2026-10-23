extends SceneTree
var errors: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:errors.append(message);push_error(message)
func write(path: String,data: Dictionary) -> void:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data))
func run() -> void:
	var folder:="res://build/asset-contract-test"
	DirAccess.make_dir_recursive_absolute(folder)
	check(LeoAssets.configure(folder)==ERR_FILE_NOT_FOUND,"Missing catalog is readable failure")
	write(folder+"/catalog.json",{"format":99})
	check(LeoAssets.configure(folder)==ERR_FILE_CORRUPT,"Unsupported catalog rejected")
	write(folder+"/catalog.json",{"format":1,"packs":[{"file":"missing.pck"}]})
	check(LeoAssets.configure(folder)==ERR_FILE_NOT_FOUND,"Missing pack fails before racing")
	var pack:=PCKPacker.new();pack.pck_start(folder+"/sample.pck");pack.flush()
	write(folder+"/catalog.json",{"format":1,"packs":[{"file":"sample.pck","sha256":"wrong"}]})
	check(LeoAssets.configure(folder)==ERR_FILE_CORRUPT,"Corrupt pack hash rejected")
	FileAccess.open(folder+"/sign.svg",FileAccess.WRITE).store_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="16"><rect width="32" height="16" fill="#178080"/></svg>')
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8);image.fill(Color.CORAL);image.save_png(folder+"/sign.png")
	var doc:={"format":1,"packs":[{"file":"sample.pck","sha256":FileAccess.get_sha256(folder+"/sample.pck")}],"overrides":[{"id":"test-sign","file":"sign.svg","affects_rules":false}]}
	write(folder+"/catalog.json",doc)
	check(LeoAssets.configure(folder)==OK and LeoAssets.mount_packs()==OK,"Valid catalog and category pack mount")
	check(LeoAssets.texture("test-sign") is Texture2D and not LeoAssets.modified_rules,"SVG cosmetic override loads with no record penalty")
	check(LeoAssets.safe_file("../outside.glb").is_empty() and LeoAssets.safe_file("C:/outside").is_empty(),"Override remains inside assets folder")
	doc.overrides=[{"id":"test-sign","file":"sign.png","affects_rules":true}];write(folder+"/catalog.json",doc);LeoAssets.configure(folder)
	check(LeoAssets.texture("test-sign").get_width()==8 and LeoAssets.modified_rules,"PNG override and rules eligibility")
	doc.overrides=[];write(folder+"/catalog.json",doc);LeoAssets.configure(folder)
	var catalog:=GarageCatalog.shared()
	check(catalog.vehicles.size()==16 and catalog.drivers.size()==6,"Complete roster remains metadata")
	check(catalog.vehicles.all(func(v):return not v.model_path.is_empty()),"Vehicle metadata stores paths rather than eager scenes")
	var car:=catalog.vehicle(&"bigster")
	var scene:=await LeoAssets.scene_async(car.model_path,self)
	check(scene is PackedScene and car.model==scene,"Threaded load resolves protected Bigster")
	var glb:="res://assets/models/city/building-a.glb"
	var bytes:=FileAccess.get_file_as_bytes(glb);FileAccess.open(folder+"/building.glb",FileAccess.WRITE).store_buffer(bytes)
	doc.overrides=[{"id":"test-building","file":"building.glb"}];write(folder+"/catalog.json",doc);LeoAssets.configure(folder)
	var replacement:=LeoAssets.scene("test-building")
	check(replacement is PackedScene,"Loose GLB override creates a scene")
	LeoAssets.directory="";LeoAssets.manifest={};LeoAssets.cache.clear();LeoAssets.modified_rules=false
	var report:={"status":"PASS" if errors.is_empty() else "FAIL","checks":checks,"errors":errors}
	FileAccess.open("res://docs/qa-colombo-city/assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CITY_ASSETS_TEST ",report)
	quit(0 if errors.is_empty() else 1)
