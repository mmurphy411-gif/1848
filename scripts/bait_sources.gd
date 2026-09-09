extends Node
const Layout=preload("res://scripts/claim_layout.gd")
const LIMITS := {"grasshopper":6,"hellgrammite":4,"worm":4,"firewood":10}
var used: Dictionary={}
var rng := RandomNumberGenerator.new()
@onready var game: Node=get_node("/root/GameState")
func _ready() -> void:
	game.new_day.connect(reset)
	reset()
func reset() -> void:
	used={"grasshopper":0,"hellgrammite":0,"worm":0,"firewood":0}
	rng.seed=game.seed^game.day^184809
func eligible(point: Vector3,hour: float) -> String:
	var inland := point.z-Layout.shore_z(point.x)
	var wet_edge: float=point.z-get_parent().get_node("Greybox/River").shore_z(point.x)
	if absf(point.x)>=40 or wet_edge< -.35 or point.z>Layout.back_z(point.x): return ""
	if inland>=3 and inland<=6 and used.firewood<10: return "firewood"
	if absf(wet_edge)<1 and used.hellgrammite<4:
		for b in Layout.BOULDERS:
			if Vector2(point.x-b.x,point.z-b.y).length()<b.z+3: return "hellgrammite"
		for b in Layout.BEDROCK:
			if Vector2(point.x-b.x,point.z-b.y).length()<3: return "hellgrammite"
	if (hour<9 or hour>=18) and used.worm<4:
		for oak in get_parent().get_node("Vegetation").placements.black_oak:
			if Vector2(point.x-oak.origin.x,point.z-oak.origin.z).length()<4: return "worm"
	if hour>=9 and hour<18 and game.weather()!="rain" and used.grasshopper<6:
		for grass in get_parent().get_node("Vegetation").placements.grass:
			if Vector2(point.x-grass.origin.x,point.z-grass.origin.z).length()<2: return "grasshopper"
	return ""
func gather(kind: String) -> bool:
	if not LIMITS.has(kind) or used[kind]>=LIMITS[kind]: return false
	used[kind]+=1
	var success := kind=="firewood" or rng.randf()<.7
	if success:
		if kind=="firewood": game.inventory.firewood+=1
		else: game.inventory.bait[kind]+=1
		game.changed.emit()
	return success
