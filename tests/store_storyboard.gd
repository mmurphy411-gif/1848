extends SceneTree
## Gate-only staging. Poses, smoke and page text are review fixtures, not gameplay.
const Layout=preload("res://scripts/claim_layout.gd")
const Guard=preload("res://tests/composition_guard.gd")
const Prices=preload("res://scripts/prices.gd")
const Calendar=preload("res://scripts/calendar.gd")
var camera: Camera3D
var claim: Node3D
var store: Node3D
var caption: Label
var detail: Label
var miner: Node3D
var lambert: Node3D
var arms: Node3D
var pour: Node3D
var pile: Node3D
var fish: Node3D
var selected: Node3D
var coil: Node3D
var slate: Label3D
var report: Dictionary={}
var store_view:=false
var camp: Node3D
var smoke_fixture: Node3D
var day_hour:=7.0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()

func material(color: Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=.88
	return m

func mesh(parent: Node3D, at: Vector3, shape: Mesh, color: Color, collision:=true) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); node.mesh=shape; node.material_override=material(color)
	parent.add_child(node); node.position=at
	if collision:
		var body:=StaticBody3D.new(); node.add_child(body)
		var bounds:=CollisionShape3D.new(); bounds.shape=shape.create_convex_shape(); body.add_child(bounds)
	return node

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, collision:=true) -> MeshInstance3D:
	var shape:=BoxMesh.new(); shape.size=size
	return mesh(parent,at,shape,color,collision)

func capsule(parent: Node3D, at: Vector3, height: float, radius: float, color: Color) -> MeshInstance3D:
	var shape:=CapsuleMesh.new(); shape.height=height; shape.radius=radius
	return mesh(parent,at,shape,color,false)

func bar(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> MeshInstance3D:
	var result:=box(parent,(a+b)/2,Vector3(width,width,a.distance_to(b)),color,false)
	result.look_at(parent.to_global(b),Vector3.UP if absf((b-a).normalized().y)<.99 else Vector3.RIGHT)
	return result

func text3(parent: Node3D, words: String, at: Vector3, px:=.002) -> Label3D:
	var label:=Label3D.new(); label.text=words; label.font_size=48; label.pixel_size=px
	label.outline_size=0; label.modulate=Color("f3e6c6")
	parent.add_child(label); label.position=at
	return label

func route(parent: Node3D, points: Array, claim_ground:=false) -> void:
	for i in range(points.size()-1):
		var a: Vector3=points[i]; var b: Vector3=points[i+1]
		for step in 12:
			var p:=a.lerp(b,float(step)/12)
			if claim_ground: p.y=Layout.height_at(p.x,p.z)+.045
			var segment:=box(parent,p,Vector3(1.2,.035,a.distance_to(b)/12+.12),Color("b4a78b"),false)
			segment.rotation.y=atan2(b.x-a.x,b.z-a.z)

func limb(parent: Node3D, shoulder: Vector3, elbow: Vector3, hand: Vector3, color: Color) -> void:
	bar(parent,shoulder,elbow,.10,color); bar(parent,elbow,hand,.075,color)
	box(parent,hand,Vector3(.13,.055,.11),Color("c19773"),false)

func keeper_at(x: float, weighing:=false) -> void:
	lambert.position=Vector3(x,0,-.84) # Front .15 m behind rear counter edge (-.425).
	for child in arms.get_children(): child.free()
	if weighing:
		limb(arms,Vector3(x-.21,1.4,-.77),Vector3(-1.6,1.15,-.5),Vector3(-1.39,1.17,-.10),Color("985e50"))
		bar(arms,Vector3(-1.39,1.18,-.1),Vector3(-1.31,1.18,.015),.045,Color("d3a57c"))
		limb(arms,Vector3(x+.21,1.4,-.77),Vector3(-.43,1.1,-.4),Vector3(-.43,1.19,.02),Color("985e50"))
	else:
		for side in [-1,1]: limb(arms,Vector3(x+side*.22,1.4,-.8),Vector3(x+side*.34,1.1,-.52),Vector3(x+side*.25,1.06,-.22),Color("985e50"))

func make_store() -> void:
	store=Node3D.new(); root.add_child(store); store.position.x=1000
	box(store,Vector3(0,-.15,0),Vector3(42,.3,42),Color("777c70"))
	route(store,[Vector3(8,0,18),Vector3(7,0,13),Vector3(4.1,0,7.2),Vector3(1,0,3),Vector3(0,0,1)])
	var masses: Array=[Vector3(-8,1,8),Vector3(-10,1.5,2),Vector3(-7,.8,-8),Vector3(8,1.2,-5),Vector3(11,.7,3),Vector3(14,1.8,10),Vector3(-12,2,14)]
	for i in masses.size():
		var p: Vector3=masses[i]
		var m:=box(store,p,Vector3(2.8+i%3,2*p.y,1.8+i%2),Color("59685c")); m.rotation.y=i*.63
		bar(store,p+Vector3(.6,0,.4),p+Vector3(.8,4.5+i%3,.2),.22,Color("4f554d"))
	box(store,Vector3(0,.95,0),Vector3(3.2,.14,.85),Color("645c4d"))
	for x in [-1.4,1.4]: box(store,Vector3(x,.44,0),Vector3(.15,.88,.55),Color("5e5648"))
	box(store,Vector3(0,1.35,-2.05),Vector3(5,2.7,.16),Color("727668"))
	# Open side for the greybox pour review; final wall clearance remains a gate.
	for x in [-2.4,2.4]: box(store,Vector3(x,1.45,.55),Vector3(.13,2.9,.13),Color("615b49"))
	for side in [-1,1]:
		var roof:=box(store,Vector3(side*1.24,3.05,-.7),Vector3(2.56,.08,3.1),Color("b3ad97")); roof.rotation.z=-side*.2
	text3(store,"LAMBERT",Vector3(0,2.78,.88),.0035)
	text3(store,"FRENCH CAMP",Vector3(0,2.55,.88),.0013)
	for height in [.4,1.15,1.9]: box(store,Vector3(0,height,-1.73),Vector3(4.2,.08,.52),Color("525c50"))
	for i in 5:
		var sack:=capsule(store,Vector3(-1.72+i*.38,.68,-1.57),.5,.15,Color("b8ab84")); sack.rotation.z=(i-2)*.06
	for i in 3: capsule(store,Vector3(.5+i*.47,.65,-1.57),.44,.2,Color("7d7560"))
	for i in 4: box(store,Vector3(-1.72+i*.27,1.4,-1.53),Vector3(.20,.36,.08),Color("d0c8ad"))
	for i in 3:
		var torus:=TorusMesh.new(); torus.inner_radius=.09; torus.outer_radius=.14
		var c:=mesh(store,Vector3(.4+i*.5,1.42,-1.47),torus,Color("a99872"),false); c.rotation.x=PI/2
		if i==1: coil=c
		bar(store,Vector3(.4+i*.5,1.49,-1.68),Vector3(.4+i*.5,1.49,-1.36),.045,Color("4e4e40"))
	for i in 3:
		bar(store,Vector3(-1.3+i*.8,1.97,-1.6),Vector3(-1.4+i*.8,2.52,-1.6),.07,Color("5a5141"))
		bar(store,Vector3(-1.6+i*.8,2.43,-1.6),Vector3(-1.1+i*.8,2.48,-1.6),.09,Color("7d827b"))
	bar(store,Vector3(2.03,.2,-1.6),Vector3(1.8,2.6,-1.6),.04,Color("b8a783"))
	box(store,Vector3(-2.9,1.74,.6),Vector3(.99,1.65,.07),Color("263734"))
	bar(store,Vector3(-2.4,2.47,.55),Vector3(-2.9,2.47,.6),.045,Color("615b49"))
	var board:="LAMBERT\n%s\nGOLD  $%.2f / oz\n\n" % [Calendar.date_string(30),Prices.gold_price(30,1848)]
	for item in ["flour","beans","pork","coffee","salt","hook","line","rod"]:
		var unit: String="/ lb" if item in ["flour","beans","pork","coffee","salt"] else "/ coil" if item=="line" else "each"
		board+="%s  $%.2f %s\n" % [item.capitalize(),Prices.price(item,30,1848),unit]
	text3(store,board.strip_edges(),Vector3(-2.9,1.74,.645),.0014)
	bar(store,Vector3(-.9,1,0),Vector3(-.9,1.6,0),.055,Color("b8a66e"))
	bar(store,Vector3(-1.43,1.59,0),Vector3(-.38,1.63,0),.045,Color("c7b578"))
	for x in [-1.35,-.43]:
		bar(store,Vector3(x,1.6,0),Vector3(x,1.15,0),.014,Color("a69566"))
		box(store,Vector3(x,1.145,0),Vector3(.32,.035,.3),Color("beac72"))
	box(store,Vector3(-.43,1.21,0),Vector3(.11,.11,.1),Color("cfb967"))
	box(store,Vector3(1.2,1.36,.22),Vector3(.97,.69,.06),Color("263734"))
	slate=text3(store,"",Vector3(1.2,1.36,.255),.0016)
	box(store,Vector3(2.12,.47,1.05),Vector3(.8,.94,.82),Color("6f7160"))
	text3(store,"SMOKED FISH",Vector3(2.12,1.17,1.15),.0014)
	lambert=Node3D.new(); store.add_child(lambert)
	capsule(lambert,Vector3(0,.85,0),1.5,.26,Color("935d51"))
	capsule(lambert,Vector3(0,1.67,0),.31,.135,Color("bc9476"))
	box(lambert,Vector3(0,.93,.22),Vector3(.38,.79,.04),Color("b9ac8d"),false)
	arms=Node3D.new(); store.add_child(arms); keeper_at(-1.1)
	miner=load("res://assets/miner/miner.glb").instantiate(); store.add_child(miner); miner.rotation.y=PI
	for m in miner.find_children("*","MeshInstance3D",true,false): m.material_override=material(Color("87918f"))
	var animation: AnimationPlayer=miner.find_children("*","AnimationPlayer",true,false)[0]
	animation.play("idle"); animation.advance(.5); animation.pause()
	pour=Node3D.new(); store.add_child(pour)
	# Posed greybox miner judges hands/sack without creating production clips.
	capsule(pour,Vector3(-1.1,.83,.95),1.5,.24,Color("7f9292"))
	capsule(pour,Vector3(-1.1,1.68,.93),.30,.13,Color("bbc4bd"))
	limb(pour,Vector3(-1.34,1.41,.9),Vector3(-1.65,1.55,.65),Vector3(-1.58,1.58,.26),Color("90a5a3"))
	limb(pour,Vector3(-.87,1.41,.9),Vector3(-.92,1.62,.54),Vector3(-1.25,1.72,.2),Color("90a5a3"))
	var sack:=box(pour,Vector3(-1.44,1.62,.18),Vector3(.28,.36,.2),Color("baa57c"),false); sack.rotation.z=-.6
	bar(pour,Vector3(-1.35,1.47,.10),Vector3(-1.35,1.17,.05),.023,Color("e4bf59"))
	pour.visible=false
	pile=Node3D.new(); store.add_child(pile)
	capsule(pile,Vector3(-.05,1.2,.12),.35,.15,Color("c2b48b"))
	box(pile,Vector3(.28,1.055,.25),Vector3(.21,.04,.17),Color("d4cdb5"),false)
	var ring:=TorusMesh.new(); ring.inner_radius=.075; ring.outer_radius=.12
	mesh(pile,Vector3(.57,1.075,.28),ring,Color("a18f63"),false)
	fish=Node3D.new(); store.add_child(fish)
	for i in 3: box(fish,Vector3(1.89+i*.18,.98,1.05),Vector3(.13,.06,.45),Color("a08d6d"),false)
	selected=Node3D.new(); store.add_child(selected)
	capsule(selected,Vector3(-.6,1.55,-.5),.38,.14,Color("ded3a3"))
	text3(selected,"FLOUR · 1 lb",Vector3(-.6,1.92,-.45),.0011)
	limb(selected,Vector3(-1.7,1.35,.5),Vector3(-1.0,1.45,-.1),Vector3(-.60,1.4,-.5),Color("8fa3a1"))
	for node in [pile,fish,selected]: node.visible=false
	var sun:=DirectionalLight3D.new(); store.add_child(sun); sun.rotation_degrees=Vector3(-50,-35,0); sun.light_energy=1.1; sun.shadow_enabled=true

func pose(hour: float) -> void:
	day_hour=hour
	var clock: Node=claim.get_node("Daylight/Clock")
	clock.start(hour); clock.running=false; claim.get_node("Daylight").apply(hour)
	assert(is_equal_approx(claim.get_node("Daylight").current_hour,hour))
	assert(is_equal_approx(clock.hour_at(clock.elapsed),hour))

func shot(number: int, title: String, action: String, state: String, input: String, from: Vector3, target: Vector3, fov: float, camera_name: String) -> void:
	camera.position=from; camera.look_at(target); camera.fov=fov; camera.current=true
	if store_view: camera.position.x+=1000
	caption.text="%02d  %s  ·  %s" % [number,title,camera_name]
	var time:="%02d:%02d" % [floori(day_hour),roundi(fposmod(day_hour,1)*60)]
	detail.text="%s  |  Input: %s\nState: %s  |  Time: %s%s" % [action,input,state,time," · paused" if store_view else ""]
	for i in 75: await process_frame
	await physics_frame; await RenderingServer.frame_post_draw
	var label:="storyboard-%02d" % number
	var ok:=Guard.check(self,label)
	report[label]={"guard":ok,"camera":str(from),"target":str(target),"fov":fov,"camera_name":camera_name,"hour":day_hour,"state":state}
	if number in [4,9,12]:
		var centre:=Vector3(997.1,1.74,.645) if number==4 else Vector3(1001.2,1.36,.255)
		var size:=Vector2(.99,1.65) if number==4 else Vector2(.97,.69)
		var safe:=Rect2(20,155,1880,905)
		for x in [-.5,.5]:
			for y in [-.5,.5]:
				if not safe.has_point(camera.unproject_position(centre+Vector3(x*size.x,y*size.y,0))): failures.append(label+" reading surface clipped")
		var glyph_height:=camera.unproject_position(centre).distance_to(camera.unproject_position(centre+Vector3(0,48*(.0014 if number==4 else .0016),0)))
		report[label].nominal_glyph_px=glyph_height
		if glyph_height<22: failures.append(label+" text below 22 px")
	root.get_texture().get_image().save_png("res://artifacts/storyboard/"+label+".png")
	print("SAVED ",label)

func make_smoke() -> void:
	# Greybox column: live short particles disappear at rim distance; no art claim.
	smoke_fixture=Node3D.new(); claim.add_child(smoke_fixture); smoke_fixture.position=camp.position
	for i in 30:
		var cloud:=capsule(smoke_fixture,Vector3(.2*sin(i*.8)+i*.05,.7+i*.48,.1*cos(i)),.8+i*.025,.30+i*.018,Color(.75,.75,.72,.65))
		var m:=cloud.material_override as StandardMaterial3D
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func run() -> void:
	root.content_scale_size=Vector2i(1920,1080); root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://artifacts/storyboard")
	root.get_node("GameState").apply_scenario({"day":"30","hour":"7","weather":"clear"})
	claim=load("res://scenes/claim.tscn").instantiate(); root.add_child(claim)
	claim.get_node("HUD").hide(); claim.get_node("Rain").set_process(false)
	claim.get_node("Walker").set_physics_process(false)
	claim.get_node("CameraRig").set_process(false); claim.get_node("CameraRig").set_physics_process(false)
	var mount:=Node3D.new(); root.add_child(mount); camera=Camera3D.new(); mount.add_child(camera); camera.far=600
	camera.attributes=claim.get_node("Daylight").camera_attributes
	var overlay:=CanvasLayer.new(); root.add_child(overlay)
	var plate:=ColorRect.new(); overlay.add_child(plate); plate.position=Vector2(24,20); plate.size=Vector2(1790,130); plate.color=Color(.035,.06,.055,.93)
	caption=Label.new(); overlay.add_child(caption); caption.position=Vector2(42,27); caption.add_theme_font_size_override("font_size",29)
	detail=Label.new(); overlay.add_child(detail); detail.position=Vector2(42,70); detail.add_theme_font_size_override("font_size",25)
	camp=claim.get_node("Camp")
	var trail:=camp.position+Vector3(0,0,6); trail.y=Layout.height_at(trail.x,trail.z)
	var path:=Node3D.new(); claim.add_child(path)
	route(path,[trail-Vector3(0,0,1),trail+Vector3(2,0,2),trail+Vector3(5,0,5),trail+Vector3(7,0,9)],true)
	for side in [-1,1]:
		for i in (3 if side<0 else 4):
			var p:=trail+Vector3(2+side*(1.25+.22*sin(i*2.4)),0,2+i*.8+side*.25); p.y=Layout.height_at(p.x,p.z)+.35
			capsule(path,p,.57+.22*sin(i*2.1+1),.24+.055*cos(i),Color("63705a"))
	claim.get_node("Walker").position=trail-Vector3(1,0,.5)
	claim.get_node("Walker/Visual").set_process(false); claim.get_node("Walker/Visual").rotation.y=PI
	pose(7); camp.fire_hours=2; make_smoke()
	await shot(1,"SET OUT","Follow the worn path through the brush","claim → departing","G before 09:00",trail+Vector3(-3.4,2.4,-.4),trail+Vector3(4,1,4),54,"departure review")
	var rim:=Vector3(12,Layout.height_at(12,40)+2,40)
	var rim_target:=Vector3(0,5,2)
	await shot(2,"THE RIM","Camp smoke rises below; hold 4 s","departing → store arrival (+6 h)","none",rim,rim_target,50,"rim held shot · smoke blockout")
	path.visible=false; claim.visible=false
	var world: WorldEnvironment=claim.get_node("Daylight/WorldEnvironment"); var previous:=world.environment
	world.environment=Environment.new(); world.environment.background_mode=Environment.BG_COLOR; world.environment.background_color=Color("99a8a9")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; world.environment.ambient_light_color=Color("c4cebf"); world.environment.ambient_light_energy=.65
	make_store(); store_view=true; day_hour=13
	miner.position=Vector3(4.1,0,7.2); miner.rotation.y=PI+.5
	await shot(3,"ARRIVAL","Curve into the clearing; counter resolves at 8 m","store · free walk","walk",Vector3(6.4,2.15,10.8),Vector3(0,1.35,-.1),48,"approach player")
	miner.position=Vector3(-.6,0,1.1)
	await shot(4,"THE BOARD","Read gold and goods prices","store · board focus","face board; Esc releases",Vector3(-2.9,1.91,4.3),Vector3(-2.9,1.91,.6),32,"board focus")
	miner.visible=false; pour.visible=true; keeper_at(-1.1,true)
	slate.text="0.46 oz\n$%.2f" % Prices.credit(.5,30,1848).dollars
	await shot(5,"THE POUR","Sack pours into pan; Lambert's thumb rests on the rim","pouring → dollars credited on release","hold G; release stops",Vector3(-3.0,2.35,-1.25),Vector3(-1.12,1.32,.13),38,"pour review · keeper side cutaway")
	pour.visible=false; miner.visible=false; selected.visible=true; keeper_at(1.1)
	await shot(6,"SHELVES","A single flour sack is held clear of three distinct tiers","pile +1 flour; shelf reservation +1","G on flour",Vector3(-.65,2.8,2.5),Vector3(0,1.45,-1.3),49,"shelf review · high offset")
	selected.visible=false; pile.visible=true; keeper_at(.15)
	var total:=Prices.price("flour",30,1848)+Prices.price("hook",30,1848)+Prices.price("line",30,1848)
	slate.text="Flour  $%.2f\nHook  $%.2f\nLine  $%.2f\nTOTAL $%.2f\nPACK 3 lb" % [Prices.price("flour",30,1848),Prices.price("hook",30,1848),Prices.price("line",30,1848),total]
	await shot(7,"COUNTER PILE","Flour, hook paper and coil lie beside the total","G on pile → last item returned","G to return last item",Vector3(.15,2.65,2.7),Vector3(.5,1.12,.1),36,"counter review · raised")
	fish.visible=true; miner.visible=true; miner.position=Vector3(.6,0,1.5)
	await shot(8,"FISH BARREL","Offer three smoked fish beside the counter","fish offer → pending credit (reversible)","G to offer; G to undo",Vector3(3.1,2,3.8),Vector3(1.9,1.1,.55),46,"barrel player")
	fish.visible=false; miner.visible=false; keeper_at(1.2)
	slate.text="TOTAL $%.2f\nPAID\nPACK 3 lb" % total
	await shot(9,"SETTLE","Lambert writes and hands over the pile","coin then dust → goods; stock deducted","G at slate",Vector3(1.2,1.48,3.1),Vector3(1.2,1.35,.22),20,"slate focus")
	slate.text="TOTAL $%.2f\nSHORT $1.20\nLast item returned" % total; slate.modulate=Color("f3b7a0")
	await shot(12,"SHORT","Cannot cover the total","last item → shelf; no goods awarded","G at slate",Vector3(1.2,1.48,3.1),Vector3(1.2,1.35,.22),20,"failure review · slate")
	coil.visible=false; pile.visible=false; keeper_at(-1.1)
	text3(store,"LINE\nSOLD OUT",Vector3(.9,1.18,-1.28),.0011)
	await shot(13,"EMPTY PEG","The last coil is gone; bare peg stays visible","stock = 0; pile unchanged","G → Sold out",Vector3(.9,2.75,1.3),Vector3(.9,1.42,-1.48),28,"failure review · shelf")
	store.queue_free(); await process_frame; store_view=false
	world.environment=previous; claim.visible=true; camp.fire_hours=0; camp.ember_hours=0; camp.flame.visible=false; camp.smoke.visible=false; smoke_fixture.visible=false
	pose(19)
	await shot(10,"THE RIM AT DUSK","Same view, low western light; fire out","returning → claim (+6 h)","none; hold 4 s",rim,rim_target,50,"rim held shot")
	var ledger: Node=claim.get_node("Ledger"); ledger.open_book()
	ledger.left.text="July 26, 1848\n\nWalked to Lambert's.\n\nSold 0.50 oz at $%.2f.\nHe called it 0.46.\n\nBought flour, a hook, a coil.\n\nHome at dusk." % Prices.gold_price(30,1848)
	ledger.right.text="Prices at Lambert's\nJuly 26\n\nGold  $%.2f / oz\nFlour  $%.2f / lb\nHooks  $%.2f each\n\nSpent today: $%.2f" % [Prices.gold_price(30,1848),Prices.price("flour",30,1848),Prices.price("hook",30,1848),total]
	await shot(11,"HOME · THE LEDGER","Open the page at the camp crate","visit → recorded in ledger","G at crate",trail+Vector3(3,2,4),camp.position+Vector3(0,1,0),55,"ledger player")
	FileAccess.open("res://artifacts/storyboard/cameras.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STORYBOARD REVISION ","FAIL "+str(failures) if Guard.failed or not failures.is_empty() else "PASS")
	quit(1 if Guard.failed or not failures.is_empty() else 0)
