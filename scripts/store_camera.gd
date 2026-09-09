extends Node3D
var target: Node3D
var yaw := .5
var pitch := -.18
var focused := false
var camera:=Camera3D.new()
var destination:=Transform3D.IDENTITY
var focus_fov := 40.0
func _ready() -> void:
	add_child(camera);camera.far=250;camera.make_current()
	if DisplayServer.get_name()!="headless": Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not focused:
		yaw-=event.relative.x*.0022;pitch=clampf(pitch-event.relative.y*.0022,-.8,.25)
func focus(point: Vector3,look: Vector3,fov: float) -> void:
	focused=true;destination=Transform3D(Basis.IDENTITY,point).looking_at(look);focus_fov=fov
func release_focus() -> void: focused=false
func _process(delta: float) -> void:
	rotation.y=yaw
	var desired:=destination
	if not focused:
		var aim:=target.position+Vector3(0,1.4,0)
		var offset:=Basis.from_euler(Vector3(pitch,yaw,0))*Vector3(.4,0,4.1)
		var query:=PhysicsRayQueryParameters3D.create(aim,aim+offset,1,[target.get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): offset=(hit.position-aim).normalized()*maxf(.2,aim.distance_to(hit.position)-.18)
		desired=Transform3D(Basis.IDENTITY,aim+offset).looking_at(aim)
	camera.global_transform=camera.global_transform.interpolate_with(desired,1-exp(-9*delta))
	camera.fov=lerpf(camera.fov,focus_fov if focused else 65.0,1-exp(-9*delta))
