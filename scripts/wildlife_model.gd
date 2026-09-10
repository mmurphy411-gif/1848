extends RefCounted
## Deterministic seasonal population and movement rules. No inventory side effects.
const Calendar = preload("res://scripts/calendar.gd")
const Layout = preload("res://scripts/claim_layout.gd")
const River = preload("res://scripts/river_model.gd")
const SPECIES := ["bear","deer","squirrel","quail","jay"]
const SPEED := {"bear":3.3,"deer":5.5,"squirrel":2.7,"quail":2.2,"jay":4.8}
const ALERT := {"bear":8.0,"deer":12.0,"squirrel":6.0,"quail":6.0,"jay":7.0}
const FLEE := {"bear":3.8,"deer":7.0,"squirrel":3.2,"quail":3.4,"jay":4.0}

static func active(species: String, day: int, hour: float) -> bool:
	if species=="bear": return Calendar.salmon_run(day) and hour>=4.75 and hour<8.0
	if species=="deer": return (hour>=4.75 and hour<8.0) or (hour>=17.5 and hour<20.5)
	return hour>=5.0 and hour<20.0

static func population(seed_value: int, day: int, hour: float, water: float) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new();rng.seed=seed_value+day*7919
	var result: Array[Dictionary]=[]
	for species in SPECIES:
		var count: int={"bear":1,"deer":2,"squirrel":2,"quail":4,"jay":1}[species]
		for i in count:
			var x: float={"bear":-33.0,"deer":-21.0,"squirrel":12.0,"quail":6.0,"jay":-10.0}[species]+i*1.8+rng.randf_range(-.6,.6)
			var z: float=River.shore_z(x,water)+1.15+i*.65 if species in ["bear","deer"] else Layout.shore_z(x)+({"squirrel":21.0,"quail":16.0,"jay":18.0}[species])+rng.randf_range(-1.0,1.0)
			var scale_value := rng.randf_range(.88,1.06)
			var phase := rng.randf_range(0,TAU)
			if active(species,day,hour): result.append({"species":species,"position":Vector3(x,Layout.height_at(x,z),z),"scale":scale_value,"phase":phase})
	return result

static func dry_clear(p: Vector3, water: float, radius: float) -> bool:
	if absf(p.x)>37 or p.z>Layout.back_z(p.x)-1.0 or p.z<River.shore_z(p.x,water)+radius: return false
	for b in Layout.BOULDERS:
		if Vector2(p.x-b.x,p.z-b.y).length()<b.z+radius+.35: return false
	return true

static func away(position: Vector3, threat: Vector3) -> Vector3:
	var direction := position-threat;direction.y=0
	return direction.normalized() if direction.length_squared()>.001 else Vector3.BACK
