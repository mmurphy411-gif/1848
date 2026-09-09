extends Node3D
var state := "keep_idle"
var history: Array[String]=[]
var player: AnimationPlayer
var busy := false
func _ready() -> void:
	var model: Node3D=load("res://assets/store/shopkeeper.glb").instantiate();add_child(model)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material=mesh.mesh.surface_get_material(surface)
			if original.resource_name=="Lambert 3":
				var skin: StandardMaterial3D=original.duplicate()
				skin.albedo_color=Color.WHITE
				skin.albedo_texture=preload("res://assets/miner/body_albedo.png")
				skin.normal_enabled=true;skin.normal_texture=preload("res://assets/miner/body_normal.png");skin.normal_scale=.12
				mesh.set_surface_override_material(surface,skin)
	player=model.find_children("*","AnimationPlayer",true,false)[0]
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
