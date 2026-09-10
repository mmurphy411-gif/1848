extends Node3D
const Fishery=preload("res://scripts/fishery.gd")
const Fish=preload("res://scripts/fish.gd")
var sources: Dictionary={}
var hour_key := -1
var river_level := INF
@onready var state: Node=get_node("/root/GameState")
@onready var clock: Node=get_parent().get_node("Daylight/Clock")
func _ready() -> void:
	var asset := preload("res://assets/fish/fish.glb").instantiate()
	for child in asset.find_children("*","MeshInstance3D",true,false): sources[str(child.name)]=child.mesh
	asset.free()
	state.new_day.connect(refresh)
	refresh()
func refresh() -> void:
	if sources.is_empty(): return
	for fish in get_children(): fish.retired=true
	var hour: float=clock.hour_at(clock.elapsed) if clock.running else get_parent().get_node("Daylight").current_hour
	hour_key=int(hour)
	var skipped := 0
	for data in Fishery.expected_population(state.day,hour,state.seed,state.weather()):
		if data.species=="salmon" and skipped<int(state.expedition.salmon_taken.get(state.day,0)):
			skipped+=1;continue
		var fish := Fish.new()
		fish.configure(data,sources[data.species],get_parent().get_node("Walker"))
		add_child(fish)
func _process(_delta: float) -> void:
	if not is_equal_approx(river_level,state.water_level()):
		river_level=state.water_level();refresh()
	elif clock.running and int(clock.hour_at(clock.elapsed))!=hour_key: refresh()
func nearest(species: String,point: Vector3) -> Node3D:
	var best: Node3D=null
	var distance := 4.0
	for fish in get_children():
		if fish.species!=species or fish.retired or not fish.visible or fish.flee_time>=0: continue
		var d: float=fish.global_position.distance_to(point)
		if d<distance: distance=d;best=fish
	return best
