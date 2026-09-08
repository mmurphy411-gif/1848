extends RefCounted
const Layout = preload("res://scripts/claim_layout.gd")
const Calendar = preload("res://scripts/calendar.gd")
const Weather = preload("res://scripts/weather.gd")
const SPECIES := ["trout","sucker","pikeminnow","hardhead","salmon"]
const BAITS := ["grasshopper","hellgrammite","worm","pork"]
const PREFERENCES := {"trout":[1.0,.9,.6,.2],"sucker":[.2,.2,1.0,.8],"pikeminnow":[.5,.7,0.0,1.0],"hardhead":[0.0,.8,.6,0.0],"salmon":[0.0,0.0,0.0,0.0]}
static func _spot(x: float,z: float,kind: String) -> Dictionary:
	return {"position":Vector2(x,z),"type":kind,"depth":-Layout.height_at(x,z)}
static func spots() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	# Boulder wakes slow the current below the same obstacles that trap gold.
	for b in Layout.BOULDERS:
		if absf(b.y-Layout.shore_z(b.x))<=6:
			var x: float=b.x+1.5*b.z
			result.append(_spot(x,Layout.shore_z(x)-5.8,"pool"))
	# Exposed slab edges shelter larvae; shift only the fish to the .7 m contour.
	# The specified slab-relative offset alone is shallower than the required band.
	for b in Layout.BEDROCK:
		var x: float=b.x+b.z*.5
		result.append(_spot(x,minf(b.y-2.5,Layout.shore_z(x)-4.65),"seam"))
	# The upstream end concentrates coarse gravel and migrating salmon.
	var head: float=-Layout.HALF_LENGTH+6
	result.append(_spot(head,Layout.shore_z(head)-7,"riffle"))
	for x in [-10.0,12.0]: result.append(_spot(x,Layout.shore_z(x)-12,"run"))
	result.append(_spot(Layout.HALF_LENGTH-12,Layout.shore_z(Layout.HALF_LENGTH-12)-5,"flat"))
	return result
static func spot_at(x: float,z: float,radius := 2.5) -> Dictionary:
	var best: Dictionary={}
	for s in spots():
		var d: float=s.position.distance_to(Vector2(x,z))
		if d<radius: radius=d;best=s
	return best
static func presence(species: String,spot: Dictionary,day: int,hour: float,seed: int,override := "auto") -> float:
	if spot.is_empty(): return 0.0
	var kind: String=spot.type
	var weather := Weather.state(day,seed) if override=="auto" else override
	var n := Weather.noise(seed,day,int(spot.position.x*13)+SPECIES.find(species)*19)
	var base := 0.0
	if species=="salmon":
		return (6+8*Calendar.salmon_intensity(day)) if kind=="riffle" and Calendar.salmon_run(day) else 0.0
	if species=="trout" and kind in ["pool","seam","riffle"]:
		base=1.6 if kind=="pool" else .65
		base*=1.0 if (hour>=5 and hour<=8) or (hour>=17 and hour<=21) else .30
		base*=1.0-.18*exp(-pow((day-35.0)/20,2))
		if weather=="hot" and hour>=11 and hour<16: base*=.6
	elif species=="sucker" and kind in ["run","flat","pool"]: base=.40 if kind=="pool" else 1.2
	elif species=="pikeminnow" and kind=="run": base=.46*(1.0 if hour>=10 and hour<=16 else .35)
	elif species=="hardhead" and kind=="run": base=.7*(1.0 if hour>=10 and hour<=16 else .35)
	if weather=="rain": base*=1.5
	if weather=="frost": base*=.7
	return base*lerpf(.85,1.15,n)
static func bite_rate(species: String,spot: Dictionary,day: int,hour: float,bait: String,seed: int,override := "auto") -> float:
	var i := BAITS.find(bait)
	if i<0 or not PREFERENCES.has(species): return 0.0
	if spot.get("type","")=="riffle" and Calendar.salmon_run(day): return 0.0
	return presence(species,spot,day,hour,seed,override)*PREFERENCES[species][i]*.04
static func roll_weight(species: String,rng: RandomNumberGenerator) -> float:
	if species=="trout": return rng.randf_range(1.8,3) if rng.randf()<.03 else rng.randf_range(.3,1.8)
	if species=="salmon": return rng.randf_range(10,20)
	return rng.randf_range(1,4 if species=="pikeminnow" else 3)
static func expected_population(day: int,hour: float,seed: int,override := "auto") -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	# Reserve space for the seasonal run before filling resident fish habitats.
	for species in ["salmon","trout","sucker","pikeminnow","hardhead"]:
		for s in spots():
			for i in roundi(presence(species,s,day,hour,seed,override)):
				if result.size()>=24: return result
				result.append({"species":species,"spot":s,"index":i,"weight_lb":lerpf(.5,1.8,Weather.noise(seed,day,i+int(s.position.x))) if species=="trout" else 15.0 if species=="salmon" else 2.0})
	return result
