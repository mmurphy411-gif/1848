extends RefCounted
## The outfit: hired hands as a deterministic function of seed, day and hour.
## Records live in GameState.crew; this file owns the rules, rates and rolls.
## Work is simulated in game hours, so a crew keeps the same pace whether the
## miner watches, fast-forwards, sleeps through the afternoon or walks to Lambert's.
const Layout=preload("res://scripts/claim_layout.gd")
const Gold=preload("res://scripts/gold_map.gd")
const Pan=preload("res://scripts/pan_result.gd")
const Mining=preload("res://scripts/mining_model.gd")
const Fishery=preload("res://scripts/fishery.gd")
const RiverModel=preload("res://scripts/river_model.gd")
const Prices=preload("res://scripts/prices.gd")
const Stock=preload("res://scripts/store_stock.gd")
const Weather=preload("res://scripts/weather.gd")
const Calendar=preload("res://scripts/calendar.gd")

const JOBS:=["pan","rocker","crevice","fish","cook","haul","dam","channel","rest"]
const JOB_NAMES:={"pan":"Panning","rocker":"On the cradle","crevice":"Crevicing","fish":"Fishing","cook":"Camp cook","haul":"Hauling","dam":"Building the dam","channel":"In the channel","rest":"Resting"}
## The wing dam: a log crib that turns the river off the inside of the channel
## at low water, laying bare the bedrock pay streak until the autumn rise.
const DAM_X:=Vector2(-14.0,6.0)
const DAM_REACH:=9.0
const DAM_HOURS:=200.0
const DAM_WATER:=-.42
const WASHOUT_WATER:=-.33
## Seepage inside the crib walls; the water shader uses the same margin.
const DAM_MARGIN:=.25
const CHANNEL_PANS_PER_HOUR:=10.0
const CHANNEL_PANS_PER_CELL:=300.0
const SHIFTS:=[[6.0,12.0],[13.0,19.0]]
const PANS_PER_HOUR:=5.0
const LOADS_PER_HOUR:=2.0
const ROCKER_TEAM:=[0.0,1.0,2.0,2.8]
const CREVICE_PER_HOUR:=3.0
const RATION_LB:=2.0
const SHARE:=.4
const WAIT_DAYS:=5
const HAUL_LB:=60.0
const CELL:=2.0
## A 2 m cell dug to bedrock holds about six hundred pans of gravel.
const PANS_PER_CELL:=600.0
static var _yield_table: Array[float]=[]
## Men who came up the Yuba in 1848, and when word reached them. Skills multiply
## the base job rate; loyalty governs how long a grievance is borne.
const ROSTER:=[
	{"id":"pike","name":"Jem Pike","origin":"a sailor off a ship abandoned in the Bay","arrives":6,"wage":4.5,"loyalty":.2,"skills":{"fish":1.2,"pan":.9}},
	{"id":"boyle","name":"Henry Boyle","origin":"Mormon Battalion, dug Sutter's millrace","arrives":10,"wage":5.0,"loyalty":.8,"skills":{"crevice":1.25,"rocker":1.15}},
	{"id":"soto","name":"Joaquín Soto","origin":"a Californio vaquero from San José","arrives":16,"wage":5.0,"loyalty":.7,"skills":{"haul":1.4,"fish":1.1}},
	{"id":"kalama","name":"Keoni Kalama","origin":"from Honolulu on the brig Euphemia","arrives":22,"wage":5.0,"loyalty":.75,"skills":{"fish":1.45,"pan":1.05}},
	{"id":"roux","name":"Jean-Baptiste Roux","origin":"a voyageur, Lambert's cousin","arrives":28,"wage":5.5,"loyalty":.65,"skills":{"haul":1.35,"cook":1.1}},
	{"id":"whitcomb","name":"Ezra Whitcomb","origin":"an Oregon farmer, come south with the first wagons","arrives":35,"wage":6.0,"loyalty":.85,"skills":{"rocker":1.25,"pan":1.0}},
	{"id":"doyle","name":"Patrick Doyle","origin":"of Stevenson's New York Volunteers, discharged","arrives":42,"wage":6.0,"loyalty":.5,"skills":{"rocker":1.15,"pan":1.0}},
	{"id":"brandt","name":"Wilhelm Brandt","origin":"a cooper from Bremen","arrives":49,"wage":5.5,"loyalty":.7,"skills":{"cook":1.45,"rocker":1.05}},
	{"id":"ruiz","name":"Tomás Ruiz","origin":"a gambusino from the placers of Sonora","arrives":56,"wage":7.0,"loyalty":.7,"skills":{"pan":1.4,"crevice":1.2}},
	{"id":"freeman","name":"Moses Freeman","origin":"a ship's cook from New Bedford","arrives":63,"wage":6.0,"loyalty":.8,"skills":{"cook":1.3,"pan":1.1}},
	{"id":"lacy","name":"Tobias Lacy","origin":"a Missouri hog farmer, late for Oregon","arrives":71,"wage":6.5,"loyalty":.4,"skills":{"rocker":1.1}},
	{"id":"ortuzar","name":"Rafael Ortúzar","origin":"a miner from the silver country above Copiapó","arrives":79,"wage":7.5,"loyalty":.7,"skills":{"crevice":1.4,"rocker":1.15}},
	{"id":"fisk","name":"Abel Fisk","origin":"a careful Yankee clerk from Hartford","arrives":88,"wage":6.5,"loyalty":.9,"skills":{"pan":1.15}},
	{"id":"price","name":"Samuel Price","origin":"a Methodist exhorter, signs the pledge","arrives":97,"wage":6.5,"loyalty":.95,"skills":{"pan":1.0,"cook":1.1},"teetotal":true},
]

static func initial() -> Dictionary:
	return {"hands":[],"departed":[],"sundays":false,
		"spots":[],"worked":{},"channel_worked":{},"dam":{"progress":0.0,"built":false,"day":-1,"lost":0},"mark":-1.0,"take_today":0.0,"take_total":0.0,"wages_paid":0.0,
		"rations_eaten":0.0,"runs":[],"hauls":0,"bar_name":"","music_nights":0,"owed":0.0}

static func roster_entry(id: String) -> Dictionary:
	for man in ROSTER:
		if man.id==id: return man
	return {}

## Men waiting at the trailhead today: arrived, not yet moved on, never hired.
static func applicants(state: Dictionary, day: int) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for man in ROSTER:
		if day<int(man.arrives) or day>=int(man.arrives)+WAIT_DAYS: continue
		if has_hand(state,man.id) or man.id in state.departed: continue
		result.append(man)
	return result

static func has_hand(state: Dictionary, id: String) -> bool:
	for hand in state.hands:
		if hand.id==id: return true
	return false

static func hand(state: Dictionary, id: String) -> Dictionary:
	for h in state.hands:
		if h.id==id: return h
	return {}

## Wages rise with the rush, but more slowly than flour.
static func wage(id: String, day: int, seed: int) -> float:
	var man:=roster_entry(id)
	if man.is_empty(): return 0.0
	return snappedf(float(man.wage)*pow(Prices.index(day,seed,"wage"),.4),.05)

static func hire(state: Dictionary, id: String, day: int) -> bool:
	var man:=roster_entry(id)
	if man.is_empty() or has_hand(state,id) or id in state.departed: return false
	state.hands.append({"id":id,"name":man.name,"job":"pan","terms":"wages","morale":70.0,"foreman":false,
		"hired":day,"unpaid":0,"hungry":0,"take_today":0.0,"take_total":0.0,"earned":0.0,"actions":0,"progress":0.0,"spot":-1})
	if state.bar_name=="": state.bar_name=bar_name(state)
	return true

static func dismiss(state: Dictionary, id: String) -> void:
	for i in state.hands.size():
		if state.hands[i].id==id:
			state.hands.remove_at(i);state.departed.append(id);return

static func set_foreman(state: Dictionary, id: String) -> void:
	for h in state.hands: h.foreman=h.id==id and not h.foreman

static func foreman(state: Dictionary) -> Dictionary:
	for h in state.hands:
		if h.foreman: return h
	return {}

static func skill(h: Dictionary, job: String) -> float:
	return float(roster_entry(h.id).get("skills",{}).get(job,1.0))

static func morale_factor(h: Dictionary) -> float:
	var factor:=lerpf(.6,1.15,clampf(h.morale/100.0,0,1))
	return factor*(.5 if h.hungry>0 else 1.0)

static func mood(morale: float) -> String:
	if morale>=80: return "In good heart"
	if morale>=60: return "Content"
	if morale>=40: return "Grumbling"
	if morale>=20: return "Sullen"
	return "Ready to quit"

static func rest_day(state: Dictionary, day: int) -> bool:
	return Calendar.weekday(day)=="Sunday" and not state.sundays

# ---------------------------------------------------------------- the ground

static func cell(x: float, z: float) -> Vector2i: return Vector2i(floori(x/CELL),floori(z/CELL))

static func cell_reserve(c: Vector2i) -> float:
	var center:=Vector2((c.x+.5)*CELL,(c.y+.5)*CELL)
	return expected_pan(Gold.density_at(center.x,center.y))*PANS_PER_CELL+.05

## Mean ounces per pan at a density, tabulated once from the real roll.
static func expected_pan(density: float) -> float:
	if _yield_table.is_empty():
		var rng:=RandomNumberGenerator.new();rng.seed=184848
		for i in 21:
			var total:=0.0
			for n in 2000: total+=Pan.roll(i/20.0,rng).ounces
			_yield_table.append(total/2000)
	var f:=clampf(density,0,1)*20
	return lerpf(_yield_table[floori(f)],_yield_table[mini(20,floori(f)+1)],f-floori(f))

## Fraction of a 2 m cell's gold still in the gravel; pans, cradles and crews share it.
static func remaining(worked: Dictionary, x: float, z: float) -> float:
	var c:=cell(x,z)
	return clampf(1.0-float(worked.get(c,0.0))/cell_reserve(c),0,1)

static func worked_density(worked: Dictionary, x: float, z: float) -> float:
	return Gold.density_at(x,z)*remaining(worked,x,z)

static func take(worked: Dictionary, x: float, z: float, ounces: float) -> void:
	var c:=cell(x,z)
	worked[c]=float(worked.get(c,0.0))+maxf(0,ounces)

## The miner's own pans teach the crew where to work. Nearby samples merge.
static func record_prospect(state: Dictionary, point: Vector3, ounces: float, day: int) -> void:
	for s in state.spots:
		if Vector2(s.x-point.x,s.z-point.z).length()<1.6:
			s.samples+=1;s.ounces+=ounces;s.day=day;return
	state.spots.append({"x":point.x,"z":point.z,"samples":1,"ounces":ounces,"day":day})
	if state.spots.size()>48:
		var held: Dictionary={}
		for h in state.hands:
			if h.spot>=0 and h.spot<state.spots.size(): held[h.id]=state.spots[h.spot]
		state.spots.sort_custom(func(a,b): return estimate(a)>estimate(b))
		state.spots.resize(48)
		for h in state.hands:
			h.spot=state.spots.find(held[h.id]) if held.has(h.id) else -1

static func estimate(spot: Dictionary) -> float: return float(spot.ounces)/maxi(1,int(spot.samples))

static func workable(point: Vector2, water: float) -> bool:
	return RiverModel.work_edge(Vector3(point.x,Layout.height_at(point.x,point.y),point.y),water,.45)

## Best known ground for each panner, spaced so two men never share a pan's elbow room.
static func assign_spots(state: Dictionary, water: float) -> void:
	var ranked: Array=[]
	for i in state.spots.size():
		var s: Dictionary=state.spots[i]
		if not workable(Vector2(s.x,s.z),water): continue
		ranked.append({"index":i,"value":estimate(s)*remaining(state.worked,s.x,s.z)})
	ranked.sort_custom(func(a,b): return a.value>b.value)
	var used: Array[Vector2]=[]
	for h in state.hands:
		h.spot=-1
		if h.job!="pan": continue
		for r in ranked:
			var s: Dictionary=state.spots[r.index]
			if used.any(func(u): return u.distance_to(Vector2(s.x,s.z))<2.4): continue
			h.spot=r.index;used.append(Vector2(s.x,s.z));break
		if h.spot<0:
			# No known ground left: work the shore below camp and hope.
			var x: float=-6.0+used.size()*2.6
			state.spots.append({"x":x,"z":RiverModel.shore_z(x,water)+.4,"samples":0,"ounces":0.0,"day":-1})
			h.spot=state.spots.size()-1;used.append(Vector2(x,state.spots[h.spot].z))

## The point a man works from, for the visual crew and for yields.
static func job_point(state: Dictionary, h: Dictionary, mining: Dictionary, water: float, seed: int, day := 0, hour := 6.0, log: Array=[]) -> Vector3:
	match h.job:
		"pan":
			if h.spot>=0 and h.spot<state.spots.size():
				var s: Dictionary=state.spots[h.spot]
				return Vector3(s.x,Layout.height_at(s.x,s.z),s.z)
		"rocker":
			if mining.rocker_built: return mining.rocker_position
		"crevice":
			var slab:=crevice_slab(state,h,mining,water,seed)
			if slab>=0: return Mining.slab_point(slab)
		"fish":
			var spot:=best_fish_spot(day,hour,seed,log,state)
			if not spot.is_empty():
				var x: float=spot.position.x
				return Vector3(x,Layout.height_at(x,RiverModel.shore_z(x,water)+.3),RiverModel.shore_z(x,water)+.3)
	return Vector3.INF

## Crevicers take one exposed, unexhausted slab each, in roll order.
static func crevice_slab(state: Dictionary, h: Dictionary, mining: Dictionary, water: float, seed: int) -> int:
	var open: Array[int]=[]
	for i in Layout.BEDROCK.size():
		if Mining.exposed(i,water) and mining.taken[i]<Mining.reserve(i,seed)-.00001: open.append(i)
	if open.is_empty(): return -1
	var n:=0
	for other in state.hands:
		if other.id==h.id: break
		if other.job=="crevice": n+=1
	return open[n%open.size()]

static func best_fish_spot(day: int, hour: float, seed: int, log: Array, state: Dictionary={}) -> Dictionary:
	var best: Dictionary={};var value:=0.0
	for s in Fishery.spots():
		if s.type=="riffle" or in_channel(state,s.position.x,s.position.y): continue
		var total:=0.0
		for species in ["trout","sucker","pikeminnow","hardhead"]: total+=Fishery.presence(species,s,day,hour,seed,"auto",log)
		if total>value: value=total;best=s
	return best

# ------------------------------------------------------------- assignments

static func job_ready(state: Dictionary, h: Dictionary, inventory: Dictionary, mining: Dictionary, water: float) -> String:
	## Empty string when the man can work; otherwise why he is standing about.
	match h.job:
		"pan":
			var panners:=0
			for other in state.hands:
				if other.job=="pan":
					panners+=1
					if other.id==h.id: break
			if panners>int(inventory.get("pans",0)): return "needs a pan"
		"rocker":
			if not mining.rocker_built: return "no cradle built"
			if not inventory.get("shovel",false): return "needs a shovel"
			if not RiverModel.work_edge(mining.rocker_position,water,.65): return "cradle out of water"
			var team:=0
			for other in state.hands:
				if other.job=="rocker":
					team+=1
					if other.id==h.id: break
			if team>3: return "cradle crowded"
		"crevice":
			if not inventory.get("crowbar",false): return "needs a crowbar"
			if not range(Layout.BEDROCK.size()).any(func(i): return Mining.exposed(i,water)): return "bedrock under water"
		"fish":
			if int(inventory.get("hooks",0))<=0: return "out of hooks"
		"dam":
			if state.dam.built: return "the dam is built"
			return dam_blocker(state,inventory,water)
		"channel":
			if not state.dam.built: return "no dam yet"
			if not inventory.get("shovel",false): return "needs a shovel"
	return ""

## The foreman's dawn arrangement: cook, haul, cradle, cracks, then pans.
static func auto_assign(state: Dictionary, inventory: Dictionary, mining: Dictionary, water: float, day: int, seed: int) -> void:
	var men: Array=state.hands.duplicate()
	men.sort_custom(func(a,b): return a.id<b.id)
	for h in men: h.job="rest"
	var pick:=func(job: String, count: int) -> void:
		for n in count:
			var best: Dictionary={};var score:=-1.0
			for h in men:
				if h.job!="rest": continue
				if skill(h,job)>score: score=skill(h,job);best=h
			if best.is_empty(): return
			best.job=job
	if men.size()>=4: pick.call("cook",1)
	if provision_days(state,inventory)<4 and not state.runs.any(func(r): return int(r.day)>=day-1): pick.call("haul",1)
	if state.dam.built and inventory.get("shovel",false): pick.call("channel",8)
	elif men.size()>=5 and dam_blocker(state,inventory,water)=="": pick.call("dam",men.size())
	if mining.rocker_built and inventory.get("shovel",false) and RiverModel.work_edge(mining.rocker_position,water,.65): pick.call("rocker",3)
	if inventory.get("crowbar",false):
		var open:=0
		for i in Layout.BEDROCK.size():
			if Mining.exposed(i,water) and mining.taken[i]<Mining.reserve(i,seed)-.05: open+=1
		pick.call("crevice",open)
	pick.call("pan",int(inventory.get("pans",0)))
	if men.size()>=5 and int(inventory.get("hooks",0))>0: pick.call("fish",1)

# --------------------------------------------------------------- the work

static func abs_hour(day: int, hour: float) -> float:
	return day*24.0+(hour if hour>=4.75 else hour+24.0)

static func work_hours(from_abs: float, to_abs: float) -> Array:
	## Overlaps of [from,to) with the day's two shifts, as [day, start, end] pieces.
	var pieces: Array=[]
	if to_abs<=from_abs: return pieces
	for d in range(floori(from_abs/24.0),floori(to_abs/24.0)+1):
		for shift in SHIFTS:
			var a:=maxf(from_abs,d*24.0+shift[0]);var b:=minf(to_abs,d*24.0+shift[1])
			if b>a: pieces.append([d,a-d*24.0,b-d*24.0])
	return pieces

static func _rng(seed: int, h: Dictionary, salt: int) -> RandomNumberGenerator:
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash([seed,h.id,int(h.actions),salt])
	return rng

## Simulate hours of work. Mutates crew state, the worked ground, mining reserves,
## inventory hooks and fish. Returns ounces for the claim (after shares) and notes.
static func work(state: Dictionary, inventory: Dictionary, mining: Dictionary, day: int, from_hour: float, to_hour: float, seed: int, water: float, catch_log: Array) -> Dictionary:
	var result:={"ounces":0.0,"fish":[],"notes":[]}
	if state.hands.is_empty(): return result
	for piece in work_hours(abs_hour(day,from_hour),abs_hour(day,to_hour)):
		if rest_day(state,piece[0]): continue
		var hours: float=piece[2]-piece[1]
		var team: Array=state.hands.filter(func(h): return h.job=="rocker" and job_ready(state,h,inventory,mining,water)=="")
		for h in state.hands:
			if job_ready(state,h,inventory,mining,water)!="": continue
			var rate:=morale_factor(h)*skill(h,h.job)
			var gold:=0.0
			match h.job:
				"pan":
					if h.spot<0 or h.spot>=state.spots.size(): assign_spots(state,water)
					if h.spot<0: continue
					var s: Dictionary=state.spots[h.spot]
					h.progress+=PANS_PER_HOUR*rate*hours
					while h.progress>=1.0:
						h.progress-=1.0;h.actions+=1
						var rolled:=Pan.roll(worked_density(state.worked,s.x,s.z),_rng(seed,h,1))
						take(state.worked,s.x,s.z,rolled.ounces);gold+=rolled.ounces
				"rocker":
					# A team shares the cradle; each man adds his part of the loads.
					var share: float=ROCKER_TEAM[mini(3,team.size())]/maxf(1,team.size())
					h.progress+=LOADS_PER_HOUR*share*rate*hours
					var source:=rocker_source(state,mining,water)
					while h.progress>=1.0:
						h.progress-=1.0;h.actions+=1
						var rng:=_rng(seed,h,2)
						for i in Mining.ROCKER_PANS:
							var rolled:=Pan.roll(worked_density(state.worked,source.x,source.y),rng)
							take(state.worked,source.x,source.y,rolled.ounces);gold+=rolled.ounces
				"crevice":
					var slab:=crevice_slab(state,h,mining,water,seed)
					if slab<0: continue
					h.progress+=CREVICE_PER_HOUR*rate*hours
					while h.progress>=1.0 and mining.taken[slab]<Mining.reserve(slab,seed)-.00001:
						h.progress-=1.0;h.actions+=1
						var ounces:=Mining.crevice(slab,seed,mining.taken[slab],mining.crevice_actions[slab])
						mining.taken[slab]+=ounces;mining.crevice_actions[slab]+=1;gold+=ounces
				"dam":
					state.dam.progress=minf(DAM_HOURS,float(state.dam.progress)+hours*rate)
					h.actions+=1
					if state.dam.progress>=DAM_HOURS and not state.dam.built:
						state.dam.built=true;state.dam.day=piece[0]
						inventory.timber=maxi(0,int(inventory.get("timber",0))-1)
						result.notes.append("The wing dam holds. The river is turned and the channel lies open to bedrock.")
				"channel":
					var spot:=channel_spot(state,h)
					h.progress+=CHANNEL_PANS_PER_HOUR*rate*hours
					while h.progress>=1.0:
						h.progress-=1.0;h.actions+=1
						var rolled:=Pan.roll(channel_worked_density(state,spot.x,spot.y),_rng(seed,h,4))
						take_channel(state,spot.x,spot.y,rolled.ounces);gold+=rolled.ounces
				"fish":
					var spot:=best_fish_spot(piece[0],(piece[1]+piece[2])*.5,seed,catch_log,state)
					if spot.is_empty(): continue
					var presence:=0.0
					for species in ["trout","sucker","pikeminnow","hardhead"]: presence+=Fishery.presence(species,spot,piece[0],(piece[1]+piece[2])*.5,seed,"auto",catch_log)
					h.progress+=minf(1.6,.35*presence)*rate*hours
					while h.progress>=1.0 and int(inventory.hooks)>0:
						h.progress-=1.0;h.actions+=1
						var rng:=_rng(seed,h,3)
						var roll:=rng.randf()*presence;var species:="trout"
						for kind in ["trout","sucker","pikeminnow","hardhead"]:
							roll-=Fishery.presence(kind,spot,piece[0],(piece[1]+piece[2])*.5,seed,"auto",catch_log)
							if roll<=0: species=kind;break
						var fish:={"species":species,"weight_lb":snappedf(Fishery.roll_weight(species,rng),.01),"day":piece[0],"state":"fresh","by":h.id}
						result.fish.append(fish)
						catch_log.append({"species":species,"spot_index":spot.spot_index,"day":piece[0]})
						if rng.randf()<.05: inventory.hooks=int(inventory.hooks)-1;inventory.line_m=maxf(0,float(inventory.line_m)-2)
			if gold>0:
				var kept: float=gold*(SHARE if h.terms=="shares" else 0.0)
				h.earned+=kept;h.take_today+=gold;h.take_total+=gold
				result.ounces+=gold-kept
				state.take_today+=gold;state.take_total+=gold
	return result

static func rocker_source(state: Dictionary, mining: Dictionary, water: float) -> Vector2:
	## Gravel is shovelled from the richest known ground within carrying distance.
	var p: Vector3=mining.rocker_position
	var best:=Vector2(p.x,p.z);var value:=worked_density(state.worked,p.x,p.z)
	for s in state.spots:
		if Vector2(s.x-p.x,s.z-p.z).length()>25 or not workable(Vector2(s.x,s.z),water): continue
		var d:=worked_density(state.worked,s.x,s.z)
		if d>value: value=d;best=Vector2(s.x,s.z)
	return best

## The foreman has the cradle carried beside the best known gravel. Returns true
## when it moved. The site must pass the same rule as a cradle the miner builds.
static func site_cradle(state: Dictionary, mining: Dictionary, water: float) -> bool:
	if not mining.rocker_built and not mining.get("owned",false): return false
	var current:=Vector2.ZERO
	if mining.rocker_built and Mining.rocker_site(mining.rocker_position,water):
		var src:=rocker_source(state,mining,water)
		current=Vector2(worked_density(state.worked,src.x,src.y),0)
	var best: Vector3=Vector3.INF;var value:=current.x*1.25+.02
	for s in state.spots:
		var d:=worked_density(state.worked,s.x,s.z)
		if d<=value: continue
		for dx in [0.0,3.0,-3.0,6.0,-6.0,9.0,-9.0]:
			var x: float=s.x+dx
			var z: float=RiverModel.shore_z(x,water)+.25
			var p:=Vector3(x,Layout.height_at(x,z)+.02,z)
			if Mining.rocker_site(p,water): best=p;value=d;break
	if best==Vector3.INF: return false
	mining.rocker_position=best;mining.rocker_built=true
	return true

# ------------------------------------------------------------ the wing dam

## The autumn rise takes the dam, built or half built, crew or no crew.
static func washout(state: Dictionary, water: float) -> String:
	if not (state.dam.built or float(state.dam.progress)>0) or water<=WASHOUT_WATER: return ""
	var note:="The river rose in the night and took the wing dam." if state.dam.built else "High water carried off the half-built dam."
	state.dam={"progress":0.0,"built":false,"day":-1,"lost":int(state.dam.get("lost",0))+1}
	return note

static func dam_blocker(state: Dictionary, inventory: Dictionary, water: float) -> String:
	if int(inventory.get("timber",0))<=0 and float(state.dam.progress)<=0: return "needs dam timber"
	if water>DAM_WATER: return "river too high"
	if not (inventory.get("pick",false) and inventory.get("shovel",false)): return "needs pick and shovel"
	return ""

## True for the bared channel bed inside a standing dam.
static func in_channel(state: Dictionary, x: float, z: float) -> bool:
	if not state.get("dam",{}).get("built",false): return false
	var inland:=z-Layout.shore_z(x)
	return x>DAM_X.x+DAM_MARGIN and x<DAM_X.y-DAM_MARGIN and inland>-DAM_REACH+DAM_MARGIN and inland<.4

## The pay streak lies on bedrock along the old thalweg, a little inside the crib.
static func channel_density(x: float, z: float) -> float:
	var inland:=z-Layout.shore_z(x)
	var streak:=exp(-pow((inland+6.4)/2.1,2))
	var along:=.82+.18*sin(x*.73+1.3)*cos(x*.21)
	return clampf(.18+.62*streak*along,0,1)

static func channel_cell_reserve(c: Vector2i) -> float:
	return expected_pan(channel_density((c.x+.5)*CELL,(c.y+.5)*CELL))*CHANNEL_PANS_PER_CELL+.05

static func channel_worked_density(state: Dictionary, x: float, z: float) -> float:
	var c:=cell(x,z)
	return channel_density(x,z)*clampf(1.0-float(state.channel_worked.get(c,0.0))/channel_cell_reserve(c),0,1)

static func take_channel(state: Dictionary, x: float, z: float, ounces: float) -> void:
	var c:=cell(x,z)
	state.channel_worked[c]=float(state.channel_worked.get(c,0.0))+maxf(0,ounces)

## Each man in the channel takes the richest unworked cell along his stretch.
static func channel_spot(state: Dictionary, h: Dictionary) -> Vector2:
	var n:=0;var count:=0
	for other in state.hands:
		if other.job=="channel":
			if other.id==h.id: n=count
			count+=1
	var width:=(DAM_X.y-DAM_X.x-2.0)/maxi(1,count)
	var best:=Vector2.ZERO;var value:=-1.0
	for step in 6:
		var x:=DAM_X.x+1.0+width*(n+(step+.5)/6.0)
		for inland in [-7.6,-6.4,-5.2,-4.0]:
			var z: float=Layout.shore_z(x)+inland
			var d:=channel_worked_density(state,x,z)
			if d>value: value=d;best=Vector2(x,z)
	return best

# ---------------------------------------------------------------- the night

const TALK:=[
	"%s showed %s how a Sonoran works a batea, a wrist and a half-turn.",
	"%s and %s argued half the night about whether the gold grows in the rock.",
	"%s read aloud from a month-old Californian. %s did not believe a word.",
	"%s cut %s's hair with a skinning knife. Neither man was satisfied.",
	"%s swore he saw a nugget the size of a hen's egg. %s asked to see it.",
	"%s wrote a letter home for %s, who cannot write. It was mostly about the food.",
	"%s and %s pitched horseshoes with two worn-out shoes from Lambert's mule.",
	"%s sang in a language nobody else knew. %s hummed along anyway.",
	"%s mended %s's boots with rawhide and a promise.",
	"%s bet %s an ounce the river would rise by Tuesday.",
]

static func provisions(inventory: Dictionary) -> float:
	var goods: Dictionary=inventory.get("goods",{})
	return float(goods.get("flour",0))+float(goods.get("beans",0))+float(goods.get("pork",0))

static func provision_days(state: Dictionary, inventory: Dictionary) -> float:
	var mouths: int=state.hands.size()
	if mouths==0: return INF
	return provisions(inventory)/(mouths*RATION_LB*(.8 if cooked(state) else 1.0))

static func cooked(state: Dictionary) -> bool:
	return state.hands.any(func(h): return h.job=="cook" and h.hungry==0)

static func bunks_needed(state: Dictionary) -> int: return ceili(state.hands.size()/4.0)

static func eat_rations(inventory: Dictionary, pounds: float) -> float:
	## Fresh fish first (it would spoil), then flour, beans and pork. Returns pounds short.
	var need:=pounds
	var kept: Array=[]
	for f in inventory.fish:
		if need>0 and f.state=="fresh" and not f.get("cooked",false) and f.species in ["trout","sucker","pikeminnow","hardhead","salmon","venison","bear meat"]:
			var eaten:=minf(need,float(f.weight_lb))
			need-=eaten
			if float(f.weight_lb)-eaten>.05:
				var rest: Dictionary=f.duplicate();rest.weight_lb=float(f.weight_lb)-eaten;kept.append(rest)
		else: kept.append(f)
	inventory.fish=kept
	for item in ["flour","beans","pork"]:
		var have: float=inventory.goods.get(item,0.0)
		var eaten:=minf(need,have)
		inventory.goods[item]=have-eaten;need-=eaten
	return maxf(0,need)

## Resolve one night: rations, wages, shelter, Sunday, whiskey, music, desertion.
## `funds` is {"dollars", "ounces", "gold_price"}; returns the spent amounts and notes.
static func night(state: Dictionary, inventory: Dictionary, funds: Dictionary, day: int, seed: int, weather: String, fire: bool) -> Dictionary:
	var out:={"dollars":0.0,"ounces":0.0,"notes":[],"stolen":0.0,"left":[]}
	if state.hands.is_empty():
		state.take_today=0.0;return out
	var cook:=cooked(state)
	var short:=eat_rations(inventory,state.hands.size()*RATION_LB*(.8 if cook else 1.0))
	state.rations_eaten+=state.hands.size()*RATION_LB*(.8 if cook else 1.0)-short
	var hungry_count:=ceili(short/RATION_LB)
	var dollars: float=funds.dollars;var ounces: float=funds.ounces
	var price: float=funds.gold_price
	var sheltered:=int(inventory.get("bunks",0))*4
	var drinks: bool=Calendar.weekday(day)=="Saturday" and int(inventory.get("whiskey",0))>=1
	if drinks:
		inventory.whiskey=maxi(0,int(inventory.whiskey)-ceili(state.hands.size()/4.0))
		out.notes.append("Saturday night. The men passed the whiskey around the fire.")
	var music: bool=fire and state.hands.size()>=2
	if music: state.music_nights+=1
	var order: Array=state.hands.duplicate()
	order.sort_custom(func(a,b): return a.hired<b.hired or (a.hired==b.hired and a.id<b.id))
	for i in order.size():
		var h: Dictionary=order[i]
		var man:=roster_entry(h.id)
		var change:=-2.0 # Homesickness: every night a little more of it.
		# Rations: the most recently hired go short first.
		h.hungry=1 if i>=order.size()-hungry_count else 0
		change+=-20.0 if h.hungry else (4.0 if cook else 0.0)
		# Wages are paid in coin, or in dust at the day's price.
		if h.terms=="wages":
			var owed: float=wage(h.id,day,seed)*(1.5 if h.foreman else 1.0)+float(h.get("arrears",0.0))
			if dollars>=owed: dollars-=owed;out.dollars+=owed;h.unpaid=0;change+=2
			elif dollars+ounces*price>=owed:
				var dust: float=(owed-dollars)/price
				out.dollars+=dollars;dollars=0;ounces-=dust;out.ounces+=dust;h.unpaid=0;change+=2
			else: h.unpaid+=1;change-=25;h.arrears=owed
			if h.unpaid==0: h.arrears=0.0
			state.wages_paid+=owed if h.unpaid==0 else 0.0
		else: change+=1 if h.take_today>0 else -3
		# Canvas over every four men; rain and frost find the rest.
		if i>=sheltered: change+=-12.0 if weather=="rain" else -10.0 if weather=="frost" else -3.0
		else: change+=1
		if rest_day(state,day): change+=6
		elif Calendar.weekday(day)=="Sunday": change-=5
		if drinks and not man.get("teetotal",false): change+=15
		if music: change+=2
		h.morale=clampf(h.morale+change,0,100)
		h.take_today=0.0
	# Now and then the journal keeps something of the men themselves.
	var talk:=RandomNumberGenerator.new();talk.seed=hash([seed,day,"talk"])
	if order.size()>=2 and talk.randf()<.35:
		var a: Dictionary=order[talk.randi()%order.size()];var b: Dictionary=order[talk.randi()%order.size()]
		if a.id!=b.id: out.notes.append(TALK[talk.randi()%TALK.size()] % [a.name.get_slice(" ",0),b.name.get_slice(" ",0)])
	var lost:=washout(state,funds.get("water",-1.0))
	if lost!="": out.notes.append(lost)
	# Desertion and theft, decided once a night in hiring order.
	for h in order:
		var man:=roster_entry(h.id)
		var leave: bool=h.morale<15 or h.unpaid>=2 or h.hungry and h.morale<30
		if not leave: continue
		var rng:=RandomNumberGenerator.new();rng.seed=hash([seed,day,h.id,"night"])
		if not inventory.get("strongbox",false) and rng.randf()>float(man.loyalty) and ounces>.05:
			var taken:=minf(ounces*.15,3.0)
			ounces-=taken;out.stolen+=taken
			out.notes.append("%s lit out in the night with %.2f oz from the camp." % [h.name,taken])
		else: out.notes.append("%s rolled his blankets and went on down the river." % h.name)
		out.left.append(h.id)
	for id in out.left: dismiss(state,id)
	state.take_today=0.0
	return out

## The standing order a hauler fills at Lambert's: a week of rations for the outfit,
## hooks for a fishing hand, salt for the rack, and coffee when there is room.
static func haul(state: Dictionary, inventory: Dictionary, purchases: Array, funds: Dictionary, day: int, seed: int, hauler: Dictionary) -> Dictionary:
	var out:={"dollars":0.0,"ounces":0.0,"bought":[],"pounds":0.0}
	var mouths: int=state.hands.size()+1
	var wanted:={"flour":mouths*RATION_LB*7*.5,"beans":mouths*RATION_LB*7*.3,"pork":mouths*RATION_LB*7*.2}
	var lines: Array=[]
	for item in wanted: lines.append([item,maxi(0,ceili(wanted[item]-float(inventory.goods.get(item,0))))])
	if state.hands.any(func(h): return h.job=="fish") and int(inventory.hooks)<6: lines.append(["hook",6-int(inventory.hooks)])
	if float(inventory.goods.get("salt",0))<2: lines.append(["salt",2])
	if float(inventory.goods.get("coffee",0))<1: lines.append(["coffee",1])
	var capacity:=HAUL_LB*skill(hauler,"haul")
	var dollars: float=funds.dollars;var ounces: float=funds.ounces
	var rate: float=Prices.gold_price(day,seed)*.92
	for line in lines:
		var item: String=line[0]
		var entry:=Stock.entry(item)
		var count:=mini(int(line[1]),Stock.stock(item,day,seed,purchases))
		if entry.is_empty() or count<=0: continue
		var per_lb: float=entry.pounds_per_unit
		if per_lb>0: count=mini(count,floori((capacity-out.pounds)/per_lb))
		var unit:=Prices.price(item,day,seed)
		while count>0 and dollars+ounces*rate<unit*count: count-=1
		if count<=0: continue
		var cost: float=unit*count
		var from_coin:=minf(dollars,cost);dollars-=from_coin;out.dollars+=from_coin
		var dust:=(cost-from_coin)/rate;ounces-=dust;out.ounces+=dust
		out.pounds+=per_lb*count
		purchases.append({"day":day,"item":item,"count":count})
		out.bought.append({"item":item,"count":count,"price":unit})
		if item=="hook": inventory.hooks=int(inventory.hooks)+count
		else: inventory.goods[item]=float(inventory.goods.get(item,0))+count
	state.hauls+=1
	state.runs.append({"day":day,"by":hauler.id,"dollars":out.dollars,"ounces":out.ounces,"bought":out.bought})
	return out

# ------------------------------------------------------------- reputation

const BAR_NAMES:=[[0.0,"Greenhorn Bar"],[20.0,"Shirt-Tail Bar"],[60.0,"Good Hope Bar"],[150.0,"Rich Bar"],[400.0,"Nabob's Bar"]]
static func bar_name(state: Dictionary) -> String:
	var name: String=BAR_NAMES[0][1]
	for row in BAR_NAMES:
		if float(state.take_total)>=row[0]: name=row[1]
	return name

## The season's verdict, from coin plus dust at a fair sixteen dollars an ounce.
static func title(worth: float, hands: int) -> String:
	if worth>=6000 and hands>=6: return "Nabob of the North Yuba"
	if worth>=3000 and hands>=3: return "Captain of the Bar"
	if worth>=1500: return "A Man of Means"
	if worth>=600: return "An Honest Miner"
	if worth>=150: return "A Hard-Working Pilgrim"
	return "A Greenhorn, Going Home"
