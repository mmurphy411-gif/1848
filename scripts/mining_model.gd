extends RefCounted
## Action rolls are replayable; reserve and action counters belong to GameState.
const Layout = preload("res://scripts/claim_layout.gd")
const Gold = preload("res://scripts/gold_map.gd")
const Pan = preload("res://scripts/pan_result.gd")
const Weather = preload("res://scripts/weather.gd")
const TOOLS := ["crowbar","pick","shovel","boots","rocker"]
const CREVICE_SECONDS := 18.0
const ROCK_SECONDS := 40.0
const ROCKER_PANS := 10

static func slab_point(index: int) -> Vector3:
	var slab: Vector4 = Layout.BEDROCK[index]
	return Vector3(slab.x+slab.z*.35,Layout.height_at(slab.x+slab.z*.35,slab.y)+.035,slab.y)

static func exposed(index: int, water: float) -> bool:
	return index>=0 and index<Layout.BEDROCK.size() and water<slab_point(index).y-.04

static func reserve(index: int, seed: int) -> float:
	return 4.0+2.0*Weather.noise(seed,index,1101)

static func crevice(index: int, seed: int, taken: float, action: int) -> float:
	var remaining := maxf(0,reserve(index,seed)-taken)
	var richness := lerpf(.25,1,remaining/reserve(index,seed))
	return minf(remaining,lerpf(.16,.42,Weather.noise(seed,index*10000+action,1102))*richness)

static func load_seconds(inventory: Dictionary) -> float:
	return 8.0 if inventory.get("pick",false) else 14.0

static func rocker_yield(point: Vector3, seed: int, action: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ hash(Vector3i(roundi(point.x*10),action,roundi(point.z*10)))
	var result := 0.0
	for i in ROCKER_PANS: result += Pan.roll(Gold.density_at(point.x,point.z),rng).ounces
	return result

static func rocker_site(point: Vector3, river: float) -> bool:
	# A cradle can be carried down to newly exposed gravel; feed water is riverward.
	if absf(point.x)>32 or point.z>Layout.back_z(point.x): return false
	var feet := Layout.height_at(point.x,point.z)
	var intake := point-Layout.inland_normal(point.x)*1.5
	var depth := river-Layout.height_at(intake.x,intake.z)
	if feet<river+.015 or feet>river+.24 or depth<.06 or depth>.65: return false
	for b in Layout.BOULDERS:
		if Vector2(point.x-b.x,point.z-b.y).length()<b.z+1.5: return false
	for b in Layout.BEDROCK:
		if Vector2(point.x-b.x,point.z-b.y).length()<2.5: return false
	return true
