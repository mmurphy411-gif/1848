extends SceneTree
const River = preload("res://scripts/river_model.gd")
const Mining = preload("res://scripts/mining_model.gd")
const Layout = preload("res://scripts/claim_layout.gd")
var failures: Array[String]=[]
var claim: Node3D
func _initialize() -> void:
	run.call_deferred()
	create_timer(150).timeout.connect(func(): push_error("M11 timeout");quit(2))
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await physics_frame
func interact() -> void:
	var event := InputEventAction.new();event.action="interact";event.pressed=true
	claim.get_node("Activities")._unhandled_input(event)
func run() -> void:
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"0","weather":"clear","hour":"12","river":"auto"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var walker: CharacterBody3D=claim.get_node("Walker")
	var river: Area3D=claim.get_node("Greybox/River")
	var mining: Node3D=claim.get_node("Mining")
	var activities: Node=claim.get_node("Activities")
	var water: MeshInstance3D=river.get_node("WaterSurface")
	var material=water.material_override
	var high_shore: float=river.shore_z(0)
	game.apply_scenario({"day":"75","crowbar":"1","shovel":"1","pick":"1","boots":"1","rocker":"1"})
	await frames(20)
	check(is_equal_approx(water.global_position.y,game.water_level()) and river.shore_z(0)<high_shore-3,"Live water and shoreline fall together")
	check(water.material_override==material,"River updates retain foam material and leg contacts")
	var vertices: PackedVector3Array=water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var correct := true
	for v in vertices:
		if absf(v.x)<40 and v.z>river.shore_z(v.x)+.0001: correct=false
	check(correct,"Water mesh ends at the seasonal bank")
	var fish_in_water := true
	for fish in claim.get_node("FishSchool").get_children():
		if not fish.retired and fish.visible:
			if fish.global_position.y>game.water_level() or fish.global_position.y<Layout.height_at(fish.position.x,fish.position.z): fish_in_water=false
	check(fish_in_water,"Fish remain between bed and seasonal surface")
	mining.focus_site("crevice");await frames(20)
	check(mining.target()=="crevice","Exposed slab is reachable and selectable")
	interact();check(activities.action=="crevice","G starts crevicing")
	await frames(650)
	check(walker.get_node("Visual").activity_clip=="spoon","Crowbar changes to horn spoon")
	await frames(450)
	check(not activities.busy and game.mining.taken[0]>0 and root.get_node("Sack").ounces>0,"Crevicing awards gold and depletes slab")
	var taken: float=game.mining.taken[0]
	interact();await frames(30);mining.cancel()
	check(game.mining.taken[0]==taken,"Cancelled work cannot award or deplete gold")
	interact();await frames(30)
	game.apply_scenario({"day":"120","weather":"rain"})
	await frames(3)
	check(not activities.busy and game.mining.taken[0]==taken,"Flooding cancels an unfinished crevice without gold")
	check(mining.target()!="crevice","October rain closes the slab")
	check(game.mining.taken[0]==taken,"Changing days retains slab depletion")
	game.apply_scenario({"day":"75","weather":"clear"})
	mining.focus_site("rocker");await frames(20)
	check(mining.target()=="build","Dry bank with running intake permits a build")
	interact();await frames(380)
	check(game.mining.rocker_built and mining.rocker.visible,"Rocker kit builds a persistent cradle")
	mining.focus_site("rocker");await frames(20)
	interact();check(activities.action=="rocker","Shovel enables rocker work")
	await frames(510)
	check(walker.get_node("Visual").activity_clip=="rock" and absf(mining.cradle.rotation.z)>.001,"Loaded cradle rocks with its own animation")
	await frames(2400)
	check(game.mining.rocker_actions==1 and not activities.busy,"One completed load processes ten pans once")
	var record: Dictionary=game.mining.duplicate(true)
	game.apply_scenario({"day":"0"})
	check(mining.prompt().begins_with("Move rocker"),"Changed river requires repositioning the cradle")
	check(game.mining.rocker_position==record.rocker_position,"River change does not teleport the built cradle")
	interact();check(not game.mining.rocker_built and game.inventory.rocker,"Cradle can be packed for a new shoreline")
	game.apply_scenario({"river":"0","boots":"0"})
	walker.position=Vector3(0,0,River.shore_z(0,0)-.60/.18)
	walker.position.y=Layout.height_at(walker.position.x,walker.position.z)+.02
	check(not walker.panner.can_pan(),"Ordinary boots cannot work at 60cm depth")
	game.apply_scenario({"boots":"1"})
	check(walker.panner.can_pan(),"Tall boots unlock the same deeper ground")
	var counter: Node=load("res://scripts/counter.gd").new();claim.add_child(counter)
	game.dollars=1000
	for item in Mining.TOOLS: game.inventory[item]=false
	for item in Mining.TOOLS: check(counter.select(item)=="","Store sells "+item)
	check(counter.settle(),"Tool purchase settles as one exchange")
	check(game.inventory.crowbar and game.inventory.shovel and game.inventory.boots and game.inventory.rocker,"Purchased equipment reaches owned inventory")
	check(counter.select("crowbar")=="Already owned","Duplicate tools are refused")
	var trip: Node=root.get_node("Trip")
	var progress: Dictionary=game.mining.duplicate(true)
	await trip.depart(true)
	await trip.home(true)
	check(game.inventory.crowbar and game.inventory.boots and game.mining==progress,"Equipment and mining records survive a real store round trip")
	var sandbox: Node=claim.get_node("Sandbox");sandbox.refresh_fields()
	check(sandbox.fields.has("boots") and sandbox.fields.has("river"),"Sandbox exposes tools and river override")
	print("MILESTONE 11: ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
