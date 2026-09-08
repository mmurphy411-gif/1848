extends RefCounted
## Placeholder yields in ounces; random variation belongs here, never in the map.

const SPECKS := Vector2(0.002, 0.006)
const COLOR := Vector2(0.010, 0.030)
const GOOD := Vector2(0.050, 0.150)
const NUGGET := Vector2(0.25, 1.00)
const NOISE := 0.08
const NUGGET_CHANCE := 0.08

static func roll(density: float, rng: RandomNumberGenerator) -> Dictionary:
	var v := clampf(density + rng.randfn(0.0, NOISE), 0.0, 1.0)
	if v < 0.12:
		return {"tier": 0, "ounces": 0.0}
	if v < 0.30:
		return {"tier": 1, "ounces": rng.randf_range(SPECKS.x, SPECKS.y)}
	if v < 0.55:
		return {"tier": 2, "ounces": rng.randf_range(COLOR.x, COLOR.y)}
	var ounces := rng.randf_range(GOOD.x, GOOD.y)
	if density > 0.75 and rng.randf() < NUGGET_CHANCE:
		return {"tier": 4, "ounces": ounces + rng.randf_range(NUGGET.x, NUGGET.y)}
	return {"tier": 3, "ounces": ounces}
