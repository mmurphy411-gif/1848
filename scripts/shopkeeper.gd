extends Node3D
## Lambert, the storekeeper at French Camp: a French-Canadian, once a Hudson's Bay
## voyageur, who never speaks. He is built from the crew kit like the hired hands
## (crew_look.gd LAMBERT: red toque, ceinture flechee, grey walrus moustache) and plays
## his five store clips, which assets/store/shopkeeper.glb carries on the miner's rig.
const Figure=preload("res://scripts/crew_figure.gd")
const Look=preload("res://scripts/crew_look.gd")
var state := "keep_idle"
var history: Array[String]=[]
var player: AnimationPlayer
var busy := false
var figure: Node3D
func _ready() -> void:
	var clips: Node=load("res://assets/store/shopkeeper.glb").instantiate()
	var library: AnimationLibrary=clips.find_children("*","AnimationPlayer",true,false)[0].get_animation_library("")
	clips.free()
	figure=Figure.new();figure.name="Figure";add_child(figure)
	figure.dress(Look.LAMBERT,library)
	player=figure.player
	player.get_animation("keep_idle").loop_mode=Animation.LOOP_LINEAR
	player.animation_finished.connect(func(clip: StringName):
		if clip=="shelve": play("keep_idle"))
	play("keep_idle")
func play(clip: String) -> void:
	state=clip;history.append(clip);player.play(clip,.15)
func settle() -> void:
	busy=true;play("write")
	var motion:=create_tween();motion.tween_interval(1.5)
	motion.tween_callback(func():play("hand_over"));motion.tween_interval(1.5)
	motion.tween_callback(func():busy=false;play("keep_idle"))
