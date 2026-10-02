extends CanvasLayer
## Daguerreotype photo mode: a free camera on a short tether to the miner, a
## period plate effect over the frame, and a three-second exposure that saves
## the plate to user://daguerreotypes. Everything it touches is restored on exit.

const Layout = preload("res://scripts/claim_layout.gd")
const Calendar = preload("res://scripts/calendar.gd")
const PLATE_SHADER = preload("res://shaders/daguerreotype.gdshader")
const TONES := ["Daguerreotype", "Salt print", "Cyanotype"]
const RADIUS := 14.0
const CLEARANCE := 0.3
const TETHER_HEIGHT := 1.2
const SPEED := 2.0
const FAST_SPEED := 5.0
const MIN_FOV := 25.0
const MAX_FOV := 75.0
const FOV_STEP := 2.5
const MOUSE_SENSITIVITY := 0.0022
const STICK_SPEED := 1.5
const PITCH_LIMIT := 1.4
const CAMERA_RADIUS := 0.2
const DEFAULT_DIR := "user://daguerreotypes"

enum State {OFF, COMPOSING, EXPOSING, CAPTURING}

var state := State.OFF
var active: bool:
	get: return state != State.OFF
var tone := 0
var mat_visible := true
var exposure_seconds := 3.0
var plate_dir := DEFAULT_DIR
var plate_seed := 0
var last_plate := ""
var camera: Camera3D
var yaw := 0.0
var pitch := 0.0
var target_fov := 65.0

var overlay := ColorRect.new()
var caption := Label.new()
var plate_label := Label.new()
var toast := Label.new()
var dial := ExposureDial.new()
var _material := ShaderMaterial.new()
var _saved := {}
var _exposed := 0.0
var _frames_left := 0
var _capture_wait := 0.0
var _flash := 0.0
var _toast_time := 0.0
var _probe := SphereShape3D.new()


class ExposureDial extends Control:
	## A brass arc that fills over the exposure, with the operator's instruction.
	var progress := 0.0
	var font: Font

	func _draw() -> void:
		var centre := Vector2(30, size.y * 0.5)
		draw_circle(centre, 12, Color(0.12, 0.08, 0.03, 0.35))
		draw_arc(centre, 10.5, 0, TAU, 40, Color(0.3, 0.21, 0.08, 0.7), 2.5, true)
		if progress > 0.0:
			draw_arc(centre, 10.5, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, Color(0.96, 0.78, 0.4), 3.5, true)
		draw_string(font, Vector2(50, size.y * 0.5 + 8), "Hold still…", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.2, 0.13, 0.05, 0.9))


func _ready() -> void:
	layer = 30
	visible = false
	_probe.radius = CAMERA_RADIUS
	_material.shader = PLATE_SHADER
	overlay.material = _material
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hand: Font = preload("res://assets/fonts/PatrickHand-Regular.ttf")
	var cursive: Font = preload("res://assets/fonts/Cedarville-Cursive.ttf")
	# The plate label is part of the picture: it stays visible through the exposure.
	_bottom_label(plate_label, cursive, 34, -112, -62)
	_bottom_label(caption, hand, 19, -58, -32)
	toast.add_theme_font_override("font", hand)
	toast.add_theme_font_size_override("font_size", 24)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	# The toast takes the caption's place on the bottom of the mount.
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -300; toast.offset_right = 300; toast.offset_top = -62; toast.offset_bottom = -28
	toast.hide()
	dial.font = hand
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dial)
	dial.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dial.offset_left = -95; dial.offset_right = 105; dial.offset_top = -66; dial.offset_bottom = -22
	dial.hide()
	_apply_look()


func _bottom_label(label: Label, font: Font, font_size: int, top: float, bottom: float) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -700; label.offset_right = 700
	label.offset_top = top; label.offset_bottom = bottom


# --- Entering and leaving -------------------------------------------------

func can_enter() -> bool:
	if state != State.OFF or not is_inside_tree(): return false
	var claim := get_parent()
	if claim.get("quitting") == true: return false
	for path in ["Activities", "Walker", "HUD", "Daylight/Clock"]:
		if claim.get_node_or_null(path) == null: return false
	if not claim.get_node("Activities").idle(): return false
	var trip := get_node_or_null("/root/Trip")
	if trip and trip.get("travelling") == true: return false
	return get_viewport().get_camera_3d() != null


func enter() -> bool:
	if not can_enter(): return false
	var claim := get_parent()
	var walker: CharacterBody3D = claim.get_node("Walker")
	var clock: Node = claim.get_node("Daylight/Clock")
	var hud: CanvasLayer = claim.get_node("HUD")
	var rig: Node = claim.get_node_or_null("CameraRig")
	var original := get_viewport().get_camera_3d()
	_saved = {
		"clock": clock, "clock_running": clock.running,
		"walker": walker, "walker_physics": walker.is_physics_processing(), "walker_velocity": walker.velocity,
		"hud": hud, "hud_visible": hud.visible,
		"rig": rig, "rig_process": rig.is_processing() if rig else false,
		"camera": original, "mouse_mode": Input.mouse_mode,
	}
	clock.running = false
	walker.set_physics_process(false)
	walker.velocity = Vector3.ZERO
	hud.visible = false
	if rig: rig.set_process(false) # the right stick would otherwise keep turning the orbit
	camera = Camera3D.new()
	camera.name = "PlateCamera"
	add_child(camera)
	camera.global_transform = original.global_transform
	camera.fov = original.fov
	camera.near = original.near
	camera.far = original.far
	camera.cull_mask = original.cull_mask
	camera.attributes = original.attributes
	camera.environment = original.environment
	camera.make_current()
	var forward := -original.global_basis.z.normalized()
	yaw = atan2(-forward.x, -forward.z)
	pitch = clampf(asin(clampf(forward.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)
	target_fov = clampf(original.fov, MIN_FOV, MAX_FOV)
	state = State.COMPOSING
	plate_seed = _plate_number_seed()
	_exposed = 0.0
	_flash = 0.0
	_toast_time = 0.0
	toast.hide()
	visible = true
	_take_input_priority()
	_capture_mouse()
	_apply_look()
	return true


func leave() -> void:
	if state == State.OFF: return
	state = State.OFF
	_stop_capture()
	visible = false
	dial.hide()
	toast.hide()
	_restore()


func toggle() -> void:
	if active: leave()
	else: enter()


func _restore() -> void:
	var s := _saved
	_saved = {}
	if s.is_empty(): return
	var original: Camera3D = s.camera if is_instance_valid(s.camera) else null
	var rig: Node = s.rig if is_instance_valid(s.rig) else null
	if original == null and rig: original = rig.get_node_or_null("SpringArm3D/Camera3D")
	if original and original.is_inside_tree(): original.make_current()
	if is_instance_valid(camera):
		camera.current = false
		camera.queue_free()
	camera = null
	if is_instance_valid(s.clock): s.clock.running = s.clock_running
	if is_instance_valid(s.walker):
		s.walker.set_physics_process(s.walker_physics)
		s.walker.velocity = s.walker_velocity
	if is_instance_valid(s.hud): s.hud.visible = s.hud_visible
	if rig: rig.set_process(s.rig_process)
	if DisplayServer.get_name() != "headless": Input.mouse_mode = s.mouse_mode


func _exit_tree() -> void:
	# The claim can be freed or swapped while composing; never strand its state.
	if active: leave()


## _input runs last child first: stay the claim's last child while composing so
## sibling UIs (crew book, ledger, sandbox) never see keys meant for the camera.
func _take_input_priority() -> void:
	var claim := get_parent()
	if claim and get_index() != claim.get_child_count() - 1: claim.move_child(self, -1)


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if state == State.OFF:
		if event.is_action_pressed("photo") and not event.is_echo() and enter():
			get_viewport().set_input_as_handled()
		return
	# Photo mode owns every event so nothing reaches the miner or the orbit rig.
	get_viewport().set_input_as_handled()
	if event.is_echo(): return
	if event.is_action_pressed("photo") or event.is_action_pressed("ui_cancel"):
		leave()
		return
	if state != State.COMPOSING: return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: look(event.relative * MOUSE_SENSITIVITY)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
					_capture_mouse() # the first click after focus loss only recaptures
				else:
					expose()
			MOUSE_BUTTON_WHEEL_UP: zoom(-FOV_STEP)
			MOUSE_BUTTON_WHEEL_DOWN: zoom(FOV_STEP)
	elif event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_E: expose()
			KEY_T: cycle_tone()
			KEY_M: toggle_mat()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: expose()
			JOY_BUTTON_Y: cycle_tone()
			JOY_BUTTON_X: toggle_mat()
			JOY_BUTTON_LEFT_SHOULDER: zoom(FOV_STEP)
			JOY_BUTTON_RIGHT_SHOULDER: zoom(-FOV_STEP)


func look(turn: Vector2) -> void:
	if not is_instance_valid(camera): return
	yaw = wrapf(yaw - turn.x, -PI, PI)
	pitch = clampf(pitch - turn.y, -PITCH_LIMIT, PITCH_LIMIT)
	camera.global_basis = Basis.from_euler(Vector3(pitch, yaw, 0))


func zoom(step: float) -> void:
	target_fov = clampf(target_fov + step, MIN_FOV, MAX_FOV)


func cycle_tone() -> void:
	tone = posmod(tone + 1, TONES.size())
	_apply_look()


func toggle_mat() -> void:
	mat_visible = not mat_visible
	_apply_look()


## Move along the view: x right, y world up, z back. Magnitude 1 is full speed.
func fly(input: Vector3, delta: float, fast := false) -> void:
	if not is_instance_valid(camera): return
	var basis := camera.global_basis
	var motion := basis.x * input.x + Vector3.UP * input.y + basis.z * input.z
	move_camera(motion * (FAST_SPEED if fast else SPEED) * delta)


func move_camera(motion: Vector3) -> void:
	if not is_instance_valid(camera): return
	var from := camera.global_position
	if motion.length_squared() > 0.0 and camera.is_inside_tree():
		# Sweep a small sphere so the lens stops at rocks rather than entering them.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _probe
		query.transform = Transform3D(Basis.IDENTITY, from)
		query.motion = motion
		query.collision_mask = 1
		var walker := get_parent().get_node_or_null("Walker") as CollisionObject3D
		if walker: query.exclude = [walker.get_rid()]
		var fractions := camera.get_world_3d().direct_space_state.cast_motion(query)
		# [0, 0] means the sphere already overlaps something: let it move free.
		if fractions.size() == 2 and fractions[1] > 0.0:
			motion *= maxf(0.0, fractions[0] - 0.01)
	camera.global_position = constrain(from + motion)


## Keep the lens within RADIUS of the miner and CLEARANCE above ground and water.
func constrain(point: Vector3) -> Vector3:
	var walker := get_parent().get_node_or_null("Walker") as Node3D
	if walker == null: return point
	var centre := walker.global_position + Vector3.UP * TETHER_HEIGHT
	for i in 4:
		var offset := point - centre
		if offset.length() > RADIUS: point = centre + offset.limit_length(RADIUS)
		point.y = maxf(point.y, floor_at(point.x, point.z) + CLEARANCE)
	return point


func floor_at(x: float, z: float) -> float:
	var ground := Layout.height_at(x, z)
	var walker := get_parent().get_node_or_null("Walker")
	var river: Node = walker.get("river") if walker else null
	var water: float = river.water_level() if is_instance_valid(river) and river.has_method("water_level") else Layout.WATER_LEVEL
	return maxf(ground, water)


# --- Exposure --------------------------------------------------------------

func expose() -> bool:
	if state != State.COMPOSING: return false
	state = State.EXPOSING
	_exposed = 0.0
	caption.hide()
	toast.hide()
	dial.progress = 0.0
	dial.show()
	return true


func _begin_capture() -> void:
	state = State.CAPTURING
	caption.hide()
	dial.hide()
	toast.hide()
	_set_param("develop", 1.0)
	_frames_left = 2
	_capture_wait = 0.0
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


func _on_frame_post_draw() -> void:
	if state != State.CAPTURING:
		_stop_capture()
		return
	_frames_left -= 1
	if _frames_left <= 0: _finish_capture()


func _stop_capture() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)


func _finish_capture() -> void:
	_stop_capture()
	if state != State.CAPTURING: return
	var image: Image = null
	var texture := get_viewport().get_texture()
	# The headless dummy renderer has no pixels to read back.
	if texture and DisplayServer.get_name() != "headless": image = texture.get_image()
	var message := "No plate taken"
	if image and not image.is_empty():
		var day: int = _day()
		DirAccess.make_dir_recursive_absolute(plate_dir)
		var path := next_plate_path(plate_dir, day)
		if image.save_png(path) == OK:
			last_plate = path
			message = "Plate saved"
		else:
			message = "The plate was spoiled"
	state = State.COMPOSING
	_flash = 1.0
	_toast_time = 2.0
	plate_seed = _plate_number_seed()
	_apply_look()
	toast.text = message
	toast.modulate.a = 1.0
	toast.show()


## The next free plate_<day>_<NNN>.png; NNN runs on past every plate in the folder.
static func next_plate_path(dir: String, day: int) -> String:
	var highest := 0
	var folder := DirAccess.open(dir)
	if folder:
		for file in folder.get_files():
			if not (file.begins_with("plate_") and file.ends_with(".png")): continue
			var parts := file.get_basename().split("_")
			if parts.size() == 3 and parts[2].is_valid_int():
				highest = maxi(highest, parts[2].to_int())
	return "%s/plate_%d_%03d.png" % [dir.trim_suffix("/"), day, highest + 1]


func _day() -> int:
	var game := get_node_or_null("/root/GameState")
	return int(game.day) if game else 0


func _plate_number_seed() -> int:
	var path := next_plate_path(plate_dir, _day())
	return hash(path) % 100000


# --- Per frame -------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.OFF: return
	var claim := get_parent()
	if not is_instance_valid(camera) or claim.get_node_or_null("Walker") == null:
		leave()
		return
	if is_instance_valid(_saved.get("clock")): _saved.clock.running = false # hold the light still
	_take_input_priority()
	_set_param("aspect", overlay.size.x / maxf(overlay.size.y, 1.0))
	if state == State.COMPOSING:
		var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var lift := 0.0
		if Input.is_physical_key_pressed(KEY_SPACE): lift += 1.0
		if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_CTRL): lift -= 1.0
		lift += Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
		var fast := Input.is_physical_key_pressed(KEY_SHIFT)
		fly(Vector3(axes.x, clampf(lift, -1.0, 1.0), axes.y), delta, fast)
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if stick != Vector2.ZERO: look(stick * stick.length() * STICK_SPEED * delta)
	elif state == State.EXPOSING:
		_exposed += delta
		var progress := clampf(_exposed / maxf(exposure_seconds, 0.001), 0.0, 1.0)
		dial.progress = progress
		dial.queue_redraw()
		_set_param("develop", lerpf(0.35, 1.0, smoothstep(0.0, 1.0, progress)))
		if _exposed >= exposure_seconds: _begin_capture()
	elif state == State.CAPTURING:
		_capture_wait += delta
		if _capture_wait > 1.0: _finish_capture() # no frames drawn (headless): give up quietly
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-10.0 * delta))
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.8)
		_set_param("flash", _flash * _flash)
	if _toast_time > 0.0:
		_toast_time -= delta
		toast.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		if _toast_time <= 0.0:
			toast.hide()
			if state == State.COMPOSING: caption.show()


# --- Look ------------------------------------------------------------------

func _set_param(param: String, value: Variant) -> void:
	_material.set_shader_parameter(param, value)


func _apply_look() -> void:
	_set_param("tone", tone)
	_set_param("mat_visible", 1.0 if mat_visible else 0.0)
	_set_param("plate_seed", float(plate_seed))
	_set_param("flash", 0.0 if _flash <= 0.0 else _flash * _flash)
	_set_param("develop", 1.0)
	plate_label.text = "North Yuba · " + Calendar.date_string(_day())
	plate_label.visible = mat_visible
	caption.text = "%s  ·  E / click expose  ·  T tone  ·  M mat  ·  wheel lens  ·  P / Esc leave" % TONES[tone]
	caption.visible = state == State.COMPOSING and _toast_time <= 0.0
	# Engraved into brass, inked onto the card, pencilled beside the sun print.
	var ink: Color = [Color(0.22, 0.14, 0.05, 0.92), Color(0.27, 0.15, 0.08, 0.9), Color(0.3, 0.31, 0.34, 0.85)][tone]
	var lift: Color = [Color(1.0, 0.86, 0.55, 0.55), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)][tone]
	plate_label.add_theme_color_override("font_color", ink)
	plate_label.add_theme_color_override("font_shadow_color", lift)
	plate_label.add_theme_color_override("font_outline_color", ink)
	plate_label.add_theme_constant_override("outline_size", 1) # the cursive is hairline-thin otherwise
	plate_label.add_theme_constant_override("shadow_offset_x", 0)
	plate_label.add_theme_constant_override("shadow_offset_y", 1)
	var on_mount := mat_visible
	caption.add_theme_color_override("font_color", Color(0.18, 0.12, 0.05, 0.85) if on_mount else Color(0.93, 0.9, 0.82, 0.8))
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0 if on_mount else 0.6))
	caption.add_theme_constant_override("outline_size", 0 if on_mount else 4)
	toast.add_theme_color_override("font_color", Color(0.2, 0.14, 0.07, 0.9) if on_mount else Color(0.95, 0.92, 0.85))
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.0 if on_mount else 0.6))
	toast.add_theme_constant_override("outline_size", 0 if on_mount else 4)
