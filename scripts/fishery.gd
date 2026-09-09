extends RefCounted
const Layout = preload("res://scripts/claim_layout.gd")
const Calendar = preload("res://scripts/calendar.gd")
const Weather = preload("res://scripts/weather.gd")
const SPECIES := ["trout","sucker","pikeminnow","hardhead","salmon"]
const BAITS := ["grasshopper","hellgrammite","worm","pork"]
const PREFERENCES := {"trout":[1.0,.9,.6,.2],"sucker":[.2,.2,1.0,.8],"pikeminnow":[.5,.7,0.0,1.0],"hardhead":[0.0,.8,.6,0.0],"salmon":[0.0,0.0,0.0,0.0]}
# X increases downstream; +Z points inland. All spots use the original terrain.
# Four shoreline boulders shelter pools in their downstream wakes. Their centers
# are 1.5 boulder radii downstream, so the largest stones make the longest lees.
# Pool distance from shore grows with stone radius, between five and seven metres.
# Within that band we choose the closest 0.8–1.6 m depth to the preferred distance:
# gravel shields a holding trout, while enough water remains over its back.
# Two slab seams sit at the downstream ends of the bedrock ledges. Insects collect
# at these edges; the fish stand off the shallow slab on the 0.7 m depth contour.
# The head riffle is at X=-36: cold, coarse upstream gravel holds migrating salmon.
# Deep runs at X=-10 and X=12 put suckers, hardhead and pikeminnow farther offshore.
# The downstream flat at X=30 is a slower bottom-feeding tail-out.
# Indices follow that order and remain stable, making catches local to their water.
# Nothing here changes the rocks, river level, bank, gold map, or walking boundary.
static func _spot(x: float,z: float,kind: String) -> Dictionary:
	return {"position":Vector2(x,z),"type":kind,"depth":-Layout.height_at(x,z)}
static func spots() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for b in Layout.BOULDERS:
		if absf(b.y-Layout.shore_z(b.x))<=6:
			var x: float=b.x+1.5*b.z
			var preferred: float=clampf(5+(b.z-2)*1.25,5,7)
			var distance := preferred
			var error := INF
			for i in 21:
				var candidate := 5+i*.1
				var depth: float=-Layout.height_at(x,Layout.shore_z(x)-candidate)
				if depth>=.8 and depth<=1.6 and absf(candidate-preferred)<error:
					distance=candidate;error=absf(candidate-preferred)
			result.append(_spot(x,Layout.shore_z(x)-distance,"pool"))
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
	for i in result.size(): result[i]["spot_index"]=i
	return result
static func pressure(species: String,spot_index: int,day: int,catch_log: Array=[]) -> float:
	var taken := 0.0
	for catch in catch_log:
		var age: int=day-int(catch.day)
		if catch.species==species and catch.spot_index==spot_index and age>=0 and age<6:
			taken+=.30*(1.0-age/6.0)
	return maxf(.15,1.0-taken)
static func season_factor(species: String,day: int) -> float:
	if species=="trout":
		if day<=95: return 1.0
		if day<=120: return lerpf(1,.45,(day-95)/25.0)
		return lerpf(.45,.35,clampf((day-120)/12.0,0,1))
	if species in ["pikeminnow","hardhead"]:
		if day<=100: return 1.0
		if day<=115: return lerpf(1,.5,(day-100)/15.0)
		return .4
	return 1.0
static func spot_at(x: float,z: float,radius := 2.5) -> Dictionary:
	var best: Dictionary={}
	for s in spots():
		var d: float=s.position.distance_to(Vector2(x,z))
		if d<radius: radius=d;best=s
	return best
static func presence(species: String,spot: Dictionary,day: int,hour: float,seed: int,override := "auto",catch_log: Array=[]) -> float:
	if spot.is_empty(): return 0.0
	var kind: String=spot.type
	var weather := Weather.state(day,seed) if override=="auto" else override
	var n := Weather.noise(seed,day,int(spot.position.x*13)+SPECIES.find(species)*19)
	var base := 0.0
	var feeding := 1.0 # Dawn/dusk trout; midday warm-water residents.
	var summer := 1.0 # Late-July trout dip as snowmelt warmth arrives.
	var heat := 1.0 # Hot midday further suppresses trout.
	if species=="salmon":
		return (6+8*Calendar.salmon_intensity(day)) if kind=="riffle" and Calendar.salmon_run(day) else 0.0
	if species=="trout" and kind in ["pool","seam","riffle"]:
		base=1.6 if kind=="pool" else .65
		feeding=1.0 if (hour>=5 and hour<=8) or (hour>=17 and hour<=21) else .30
		summer=1.0-.18*exp(-pow((day-35.0)/20,2))
		if weather=="hot" and hour>=11 and hour<16: heat=.6
	elif species=="sucker" and kind in ["run","flat","pool"]: base=.40 if kind=="pool" else 1.2
	elif species=="pikeminnow" and kind=="run": base=.46;feeding=1.0 if hour>=10 and hour<=16 else .35
	elif species=="hardhead" and kind=="run": base=.7;feeding=1.0 if hour>=10 and hour<=16 else .35
	var weather_factor := 1.5 if weather=="rain" else .7 if weather=="frost" else 1.0 # Flow feeds; frost slows.
	var season := season_factor(species,day) # Autumn thins residents.
	var local_pressure := pressure(species,spot.get("spot_index",-1),day,catch_log) # Caught fish take days to replace.
	var variation := lerpf(.85,1.15,n) # Seeded local differences, without mutable RNG.
	return base*feeding*summer*heat*weather_factor*season*local_pressure*variation
static func bite_rate(species: String,spot: Dictionary,day: int,hour: float,bait: String,seed: int,override := "auto",catch_log: Array=[]) -> float:
	var i := BAITS.find(bait)
	if i<0 or not PREFERENCES.has(species): return 0.0
	if spot.get("type","")=="riffle" and Calendar.salmon_run(day): return 0.0
	return presence(species,spot,day,hour,seed,override,catch_log)*PREFERENCES[species][i]*.04
static func roll_weight(species: String,rng: RandomNumberGenerator) -> float:
	if species=="trout": return rng.randf_range(1.8,3) if rng.randf()<.03 else rng.randf_range(.3,1.8)
	if species=="salmon": return rng.randf_range(10,20)
	return rng.randf_range(1,4 if species=="pikeminnow" else 3)
static func expected_population(day: int,hour: float,seed: int,override := "auto",catch_log: Array=[]) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	# Reserve space for the seasonal run before filling resident fish habitats.
	for species in ["salmon","trout","sucker","pikeminnow","hardhead"]:
		for s in spots():
			for i in roundi(presence(species,s,day,hour,seed,override,catch_log)):
				if result.size()>=24: return result
				result.append({"species":species,"spot":s,"index":i,"weight_lb":lerpf(.5,1.8,Weather.noise(seed,day,i+int(s.position.x))) if species=="trout" else 15.0 if species=="salmon" else 2.0})
	return result
