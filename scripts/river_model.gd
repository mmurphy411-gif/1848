extends RefCounted
## Seasonal water elevation; the geological height field remains fixed.
const Layout = preload("res://scripts/claim_layout.gd")
const Weather = preload("res://scripts/weather.gd")
const LEVELS := [[0,0.0],[20,-.12],[50,-.55],[75,-.68],[96,-.68],[115,-.15],[132,.04]]

static func level(day: int, seed: int, weather := "auto") -> float:
	var d := clampi(day, 0, 132)
	var result := 0.0
	for i in range(1, LEVELS.size()):
		var a: Array = LEVELS[i-1]
		var b: Array = LEVELS[i]
		result = lerpf(a[1], b[1], clampf(float(d-a[0])/float(b[0]-a[0]),0,1))
		if d <= b[0]: break
	var state := Weather.state(d,seed) if weather == "auto" else weather
	return result + (.10 if state == "rain" else 0.0)

static func shore_z(x: float, elevation: float) -> float:
	# Invert the two near-bank terrain slopes, including high-water inundation.
	return Layout.canyon_shore_z(x) + (elevation-.12)/(.035 if elevation>=.12 else .18)

static func far_z(x: float, elevation: float) -> float:
	return Layout.canyon_shore_z(x)-27.27619-Layout.canyon_far_offset(x)+(-elevation/2.1 if elevation<=0 else -elevation/.97)

static func depth_at(point: Vector3, elevation: float) -> float:
	if absf(point.x)>110 or point.z>shore_z(point.x,elevation) or point.z<far_z(point.x,elevation): return 0.0
	return maxf(0,elevation-Layout.height_at(point.x,point.z))

static func wade_limit(inventory: Dictionary) -> float:
	return .70 if inventory.get("boots",false) else .45

static func work_edge(point: Vector3, elevation: float, limit: float) -> bool:
	var depth := depth_at(point,elevation)
	var inland := point.z-shore_z(point.x,elevation)
	# Preserve the original June dry-edge allowance (shore datum + 1.5m).
	return absf(point.x)<40 and point.z<=Layout.back_z(point.x) and ((depth>0 and depth<=limit) or (depth==0 and inland>=0 and inland<=2.166667))
