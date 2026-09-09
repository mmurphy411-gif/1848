extends SceneTree
const River = preload("res://scripts/river_model.gd")
const Mining = preload("res://scripts/mining_model.gd")
const Layout = preload("res://scripts/claim_layout.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures+=1
func _initialize() -> void:
	check(River.level(0,1848,"clear")==0,"June water datum preserved")
	check(River.level(75,1848,"clear")<River.level(20,1848,"clear"),"River falls through summer")
	check(River.level(120,1848,"clear")>River.level(75,1848,"clear"),"October water rises")
	check(is_equal_approx(River.level(75,7,"rain")-River.level(75,7,"clear"),.1),"Rain raises water")
	for i in Layout.BEDROCK.size():
		check(not Mining.exposed(i,0) and Mining.exposed(i,River.level(50,7,"clear")) and not Mining.exposed(i,River.level(120,7,"rain")),"Slab %d opens in August and floods in October" % i)
		var taken := 0.0
		for action in 300: taken+=Mining.crevice(i,7,taken,action)
		check(is_equal_approx(taken,Mining.reserve(i,7)) and Mining.crevice(i,7,taken,300)==0,"Slab %d has a finite season reserve" % i)
	check(Mining.load_seconds({"pick":true})<Mining.load_seconds({}),"Pick speeds loading")
	check(River.wade_limit({"boots":true})==.7 and River.wade_limit({})==.45,"Boots extend working depth")
	for day in [0,20,50,75,97,115,132]:
		var level := River.level(day,1848)
		var z := River.shore_z(0,level)
		check(absf(Layout.height_at(0,z)-level)<.00001,"Day %d shoreline matches terrain" % day)
		check(River.level(day,1848)==level,"Day %d water is deterministic" % day)
	var p := Vector3(-4,0,-5)
	check(Mining.rocker_yield(p,7,2)==Mining.rocker_yield(p,7,2),"Rocker rolls replay exactly")
	check(Mining.rocker_site(Vector3(0,0,River.shore_z(0,-.68)+.6),-.68),"Low-water rocker site has dry footing and wet intake")
	check(not Mining.rocker_site(Vector3(0,0,10),-.68),"Dry inland sites cannot run a rocker")
	quit(0 if failures==0 else 1)
