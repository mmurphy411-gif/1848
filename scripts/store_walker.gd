extends CharacterBody3D
const Layout=preload("res://scripts/store_layout.gd")
var camera_rig: Node3D
var river: Node
var panner: Node
var water_depth := 0.0
func depth_at(_point: Vector3) -> float: return 0.0
func _physics_process(delta: float) -> void:
	var store:=get_parent()
	var axes:=Input.get_vector("move_left","move_right","move_forward","move_back")
	if store.busy or store.get_node("Sandbox").opened or store.get_node("Ledger").opened or get_node("/root/Trip").travelling: axes=Vector2.ZERO
	var direction:=Basis(Vector3.UP,camera_rig.rotation.y)*Vector3(axes.x,0,axes.y)
	var motion:=Layout.guide_motion(position,direction*2.4)
	velocity.x=move_toward(velocity.x,motion.x,7*delta);velocity.z=move_toward(velocity.z,motion.z,7*delta)
	velocity.y=0 if is_on_floor() else velocity.y-18*delta
	move_and_slide()
	if direction.length_squared()>.01: $Visual.rotation.y=lerp_angle($Visual.rotation.y,atan2(-direction.x,-direction.z),1-exp(-8*delta))
