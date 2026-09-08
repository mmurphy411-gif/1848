extends SceneTree
## Terrain and lighting acceptance checks against the actual physics scene.

const Layout = preload("res://scripts/claim_layout.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	for i in 40:
		await physics_frame
	var daylight: Node3D = claim.get_node("Daylight")
	var sun: DirectionalLight3D = daylight.sun
	var environment: Environment = daylight.environment
	_check(daylight.hour >= 18.5 and daylight.hour <= 20.0, "Default hour is golden hour")
	_check(not sun.rotation_degrees.is_equal_approx(Vector3(-48, -32, 0)), "Daylight.apply has configured the sun")
	_check(daylight.sun_elevation >= 7 and daylight.sun_elevation <= 11, "Golden sun elevation is 7–11 degrees (%.2f)" % daylight.sun_elevation)
	_check(absf(daylight.sun_azimuth) <= 25, "Sun is within 25 degrees of downstream (%.2f)" % daylight.sun_azimuth)
	var clear := 0
	var space := claim.get_world_3d().direct_space_state
	for x in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		var z := Layout.shore_z(x) + 1.0
		var start := Vector3(x, Layout.height_at(x, z) + 1.2, z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(start, start + sun.global_basis.z * 500, 1))
		if hit.is_empty():
			clear += 1
		else:
			print("Shadow at x=%s: %s, position=%s" % [x, hit.collider.get_parent().name, hit.position])
	_check(clear >= 4, "At least four of five waterline points have clear 500 m sun rays (%d/5)" % clear)
	var open_saddle := false
	var center := Vector3(0, Layout.height_at(0, 4) + 1.2, 4)
	for angle in range(-10, 11, 2):
		var direction := sun.global_basis.z.rotated(Vector3.UP, deg_to_rad(angle))
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(center, center + direction * 500, 1)).is_empty():
			open_saddle = true
	_check(open_saddle, "A ray through the downstream saddle/opening admits low sunlight")
	for x in [-40.0, 0.0, 40.0]:
		var edge := Layout.back_z(x)
		var base := Layout.height_at(x, edge)
		_check(Layout.height_at(x, edge + 12) - base >= 8, "Talus/cliff rises at least 8 m by 12 m at x=%s" % x)
		_check(Layout.height_at(x, edge + 80) >= 40, "Near rim exceeds 40 m at x=%s" % x)
		var continuous_rise := true
		for d in range(0, 71):
			if Layout.height_at(x, edge + d + 10) - Layout.height_at(x, edge + d) < 2.0:
				continuous_rise = false
		_check(continuous_rise, "No 10 m plateau along near wall at x=%s" % x)
		var apron_slope := (Layout.height_at(x, edge + 4) - Layout.height_at(x, edge + 1)) / 3
		_check(apron_slope >= 0.85 and apron_slope <= 1.1, "Apron stays above the walking floor angle at x=%s" % x)
	var tallest := 0.0
	var lowest_rim := INF
	var highest_rim := -INF
	for x in range(-40, 41, 2):
		tallest = maxf(tallest, Layout.height_at(x, Layout.shore_z(x) - 25 - 60))
		var height := Layout.height_at(x, Layout.back_z(x) + 80)
		lowest_rim = minf(lowest_rim, height)
		highest_rim = maxf(highest_rim, height)
	_check(tallest >= 60, "Far bank reaches at least 60 m (%.1f)" % tallest)
	_check(highest_rim - lowest_rim >= 12, "Near ridgeline varies by at least 12 m (%.1f)" % (highest_rim - lowest_rim))
	_check(environment.sdfgi_enabled and environment.ssao_enabled and environment.volumetric_fog_enabled and environment.glow_enabled, "GI, SSAO, volumetric fog and glow enabled")
	_check(not environment.ssr_enabled, "SSR remains off until milestone 4")
	_check(environment.sky.sky_material is PhysicalSkyMaterial, "Physical sky material is in use")
	_check(environment.tonemap_mode in [Environment.TONE_MAPPER_AGX, Environment.TONE_MAPPER_ACES], "AgX or ACES tonemapping")
	_check(not daylight.camera_attributes.auto_exposure_enabled, "Exposure is fixed for repeatable renders")
	var elevations: Array[float] = []
	var azimuths: Array[float] = []
	var rotations: Array[Basis] = []
	for h in [6.0, 12.0, 19.25]:
		daylight.apply(h)
		elevations.append(daylight.sun_elevation)
		azimuths.append(daylight.sun_azimuth)
		rotations.append(sun.basis)
	_check(not rotations[0].is_equal_approx(rotations[1]) and not rotations[1].is_equal_approx(rotations[2]) and not rotations[0].is_equal_approx(rotations[2]), "Dawn, noon and golden hour rotate the actual sun differently")
	_check(azimuths[0] < azimuths[1] and azimuths[1] < azimuths[2], "Azimuth changes monotonically from dawn to dusk")
	_check(elevations[1] > elevations[0] and elevations[1] > elevations[2] and elevations[1] > 70, "Sun rises to high noon then descends")
	daylight.apply(19.25)
	_check(claim.get_node("Walker").is_on_floor(), "Walker still spawns on the floor")
	_check(claim.get_node("CameraRig/SpringArm3D/Camera3D").far == 600, "Camera reaches the distant canyon")
	print("MILESTONE 3: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures.append(description)
