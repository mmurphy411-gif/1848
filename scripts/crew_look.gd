extends RefCounted
## Who each man looks like: a fixed casting per roster entry, so the same fourteen men
## (and Lambert) appear in every season and every save. Read by crew_figure.gd.
##
## Every look is built from the miner's kit (assets/crew/crew_kit.glb): hat and hair
## shape keys, garment dyes and patterns, beard regions, skin tone and a build. Colours
## are sRGB hex here and converted to linear for the shader.
##
## Keys
##   hat: "none" or a style in HATS; hat_colour, band; knit (wool cap)
##   hair, beard: colours; cut: hair shape keys; beard_style: BEARDS; beard_shape: keys
##   skin: a tone in SKINS; shaven (0-1, lifts the painted stubble); bald
##   shirt, shirt_b, pattern ("plain","check","stripe","plaid"), check (repeat, m), sleeves
##   vest (colour or ""), trousers, scarf (colour or ""), braces (colour or ""), sash
##   knee: the miner's torn knee "torn", "patched" or "whole"
##   build: in BUILDS; head: skull width, length, depth; height; pack, satchel, canteen
const HATS:={
	"slouch":{"brim_droop":.55},
	"wide_awake":{"crown_low":1.0,"brim_wide":.55,"brim_flat":.6},
	"vaquero":{"crown_low":1.0,"brim_wide":1.0,"brim_flat":1.0},
	"sombrero":{"crown_cone":1.0,"brim_wide":1.0,"brim_flat":.55},
	"plug":{"crown_tall":1.0,"brim_narrow":.8,"brim_flat":.75},
	"farmer":{"crown_low":.6,"brim_wide":.35,"brim_droop":.6},
	"chilean":{"crown_low":.8,"brim_wide":.45,"brim_flat":1.0},
	"watch_cap":{"cap":1.0},
	"tuque":{"cap":1.0,"tuque":1.0},
}
## Skin: a multiplier on the miner's sun-browned albedo (linear).
const SKINS:={"pale":Vector3(1.22,1.30,1.32),"fair":Vector3(1.12,1.16,1.16),"ruddy":Vector3(1.14,1.03,.99),
	"weathered":Vector3.ONE,"olive":Vector3(.80,.78,.70),"tan":Vector3(.62,.55,.48),"brown":Vector3(.47,.39,.33),"dark":Vector3(.27,.21,.18)}
## Beard regions shown: moustache 1, chin 2, jaw 4, cheek 8.
const BEARDS:={"full":15,"chin_curtain":14,"mutton_chops":13,"moustache":1,"goatee":3,"clean":0}
const BUILDS:={
	"average":{},
	"lean":{"hips":Vector2(.93,.93),"spine":Vector2(.88,.88),"chest":Vector2(.93,.92),"shoulders":.96,"arms":.9,"legs":.92},
	"stocky":{"hips":Vector2(1.08,1.08),"spine":Vector2(1.12,1.15),"chest":Vector2(1.1,1.1),"shoulders":1.06,"arms":1.11,"legs":1.1},
	"heavy":{"hips":Vector2(1.12,1.14),"spine":Vector2(1.2,1.32),"chest":Vector2(1.12,1.18),"shoulders":1.05,"arms":1.13,"legs":1.12},
	"broad":{"hips":Vector2(1.03,1.03),"spine":Vector2(1.04,1.04),"chest":Vector2(1.13,1.07),"shoulders":1.12,"arms":1.09,"legs":1.04},
}
const MEN:={
	# A sailor off a ship abandoned in the Bay: navy watch cap, striped frock, duck trousers.
	"pike":{"head":Vector3(0.97,1.02,0.98),"hat":"watch_cap","hat_colour":"2a3550","knit":true,"hair":"4a3524","cut":{"hair_short":.6},
		"beard_style":"goatee","beard_shape":{},"skin":"ruddy","shaven":.6,
		"shirt":"d9d4c4","shirt_b":"2c3a5e","pattern":"stripe","check":.035,"sleeves":"rolled",
		"vest":"","trousers":"cfc6ad","scarf":"1d2433","build":"lean","height":.98,"canteen":true},
	# Mormon Battalion veteran: chin-curtain beard, butternut shirt on braces, grey slouch.
	"boyle":{"head":Vector3(1,1.01,1),"knee":"patched","hat":"slouch","hat_colour":"5f5a52","band":"2a2622","hair":"6a5236","beard_style":"chin_curtain",
		"beard_shape":{"beard_long":.45},"skin":"fair","shaven":.8,
		"shirt":"8c6c3c","pattern":"plain","sleeves":"",
		"vest":"","trousers":"4f4a40","scarf":"","braces":"3b2a1d","build":"average","height":1.01,"satchel":true},
	# A Californio vaquero: flat wide hat, crimson faja, dark short vest, moustache.
	"soto":{"head":Vector3(0.96,1.03,0.97),"knee":"whole","hat":"vaquero","hat_colour":"1e1a17","band":"6b5a3a","hair":"161210","beard_style":"moustache",
		"beard_shape":{"moustache_walrus":.35},"skin":"tan","shaven":1.0,
		"shirt":"e2dccb","pattern":"plain","sleeves":"down",
		"vest":"2b1d17","trousers":"3a2f28","scarf":"8a2a1c","sash":"8f1d1d","sash_kind":1,"build":"lean","height":1.0},
	# From Honolulu on the brig Euphemia: low straw hat, long black hair, red check.
	"kalama":{"head":Vector3(1.05,1,1.03),"hat":"wide_awake","hat_colour":"b89d62","band":"2f2a26","hair":"0f0d0c","cut":{"hair_long":.8},
		"beard_style":"clean","skin":"brown","shaven":1.0,
		"shirt":"7a2a22","shirt_b":"d2c8b4","pattern":"check","check":.045,"sleeves":"rolled",
		"vest":"","trousers":"5d5648","scarf":"","build":"broad","height":1.03},
	# A voyageur, Lambert's cousin: blue wool cap, arrow sash in blue, dark full beard.
	"roux":{"head":Vector3(1.04,0.97,1.02),"knee":"patched","hat":"watch_cap","hat_colour":"2d4566","knit":true,"hair":"231812","beard_style":"full",
		"beard_shape":{"beard_bushy":.6},"skin":"olive",
		"shirt":"5b6d7c","pattern":"plain","sleeves":"rolled",
		"vest":"","trousers":"3f3a33","scarf":"b3872c","sash":"23406e","sash_kind":2,"build":"stocky","height":.95,"canteen":true},
	# An Oregon farmer come south with the first wagons: long greying beard, drooping slouch.
	"whitcomb":{"head":Vector3(0.98,1.03,1),"knee":"patched","hat":"slouch","hat_colour":"6b5136","band":"3a2a1c","hair":"7d746a","beard":"8f8a82",
		"beard_style":"full","beard_shape":{"beard_long":1.0},"cut":{"hair_long":.4},"skin":"weathered",
		"shirt":"8a8370","shirt_b":"4c4436","pattern":"check","check":.06,"sleeves":"",
		"vest":"3a3026","trousers":"5a4a35","scarf":"","build":"average","height":1.05,"satchel":true,"canteen":true},
	# Of Stevenson's New York Volunteers, discharged: army sky-blue trousers, ginger chops.
	"doyle":{"head":Vector3(1.04,0.98,1.03),"hat":"slouch","hat_colour":"2e2b28","band":"171514","hair":"8a3e1c","beard_style":"mutton_chops",
		"beard_shape":{"beard_bushy":.3},"skin":"ruddy","cut":{"hair_short":.5},
		"shirt":"4e4f55","pattern":"plain","sleeves":"rolled",
		"vest":"","trousers":"7f97b0","scarf":"","braces":"2a2522","build":"stocky","height":.97},
	# A cooper from Bremen, the camp cook: heavy, fair, bushy blond beard, blue check.
	"brandt":{"head":Vector3(1.06,1,1.04),"knee":"patched","hat":"wide_awake","hat_colour":"5d564b","band":"25221f","hair":"b8964f","beard_style":"full",
		"beard_shape":{"beard_bushy":1.0,"beard_long":.35},"skin":"fair",
		"shirt":"d7d2c3","shirt_b":"3a4f73","pattern":"check","check":.028,"sleeves":"rolled",
		"vest":"4a3a2c","trousers":"4a4136","scarf":"d8d3c6","build":"heavy","height":1.0},
	# A gambusino from the placers of Sonora: tall straw sombrero, white manta, moustache.
	"ruiz":{"head":Vector3(1.02,0.98,1),"hat":"sombrero","hat_colour":"c4ab6e","band":"3c2b1e","hair":"141110","beard_style":"moustache",
		"beard_shape":{},"skin":"tan","shaven":1.0,
		"shirt":"ece6d6","pattern":"plain","sleeves":"",
		"vest":"","trousers":"d7cfbb","scarf":"6d1f1a","sash":"5a1a14","sash_kind":1,"build":"stocky","height":.94},
	# A ship's cook from New Bedford: black low hat, grey-flecked short beard, red neckerchief.
	"freeman":{"head":Vector3(1,1.02,1.02),"knee":"whole","hat":"wide_awake","hat_colour":"151413","band":"5c2a20","hair":"1a1614","beard":"3a3633",
		"beard_style":"full","beard_shape":{},"skin":"dark","cut":{"hair_short":1.0},
		"shirt":"cfcabb","pattern":"plain","sleeves":"rolled",
		"vest":"1f1d1c","trousers":"3b3934","scarf":"a1241b","build":"average","height":1.02},
	# A Missouri hog farmer, late for Oregon: straw farmer's hat, red flannel, braces, lanky.
	"lacy":{"head":Vector3(0.95,1.04,0.97),"knee":"patched","hat":"farmer","hat_colour":"cdb47c","band":"5e4b32","hair":"9c7646","beard_style":"clean",
		"skin":"fair","shaven":.3,"cut":{"hair_short":.3},
		"shirt":"9b2f24","pattern":"plain","sleeves":"",
		"vest":"","trousers":"6b5a3e","scarf":"","braces":"7b6a55","build":"lean","height":1.06},
	# From the silver country above Copiapo: flat-brimmed dark felt, full black beard, broad.
	"ortuzar":{"head":Vector3(1.04,1,1.03),"hat":"chilean","hat_colour":"2f2620","band":"7a1f1f","hair":"120f0e","beard_style":"full",
		"beard_shape":{"beard_long":.6},"skin":"olive",
		"shirt":"6f5d4a","shirt_b":"2c241c","pattern":"plaid","check":.07,"sleeves":"rolled",
		"vest":"","trousers":"2f2a26","scarf":"c9b48a","build":"broad","height":.99},
	# A careful Yankee clerk from Hartford: black plug hat, clean-shaven, white shirt, black vest.
	"fisk":{"head":Vector3(0.95,1.03,0.98),"knee":"whole","hat":"plug","hat_colour":"141312","band":"0c0b0b","hair":"5e4632","beard_style":"clean","skin":"pale","shaven":1.0,
		"cut":{"hair_short":.8},"shirt":"ece9e0","pattern":"plain","sleeves":"down",
		"vest":"191818","trousers":"34332f","scarf":"141414","build":"lean","height":1.04,"satchel":true},
	# A Methodist exhorter who signs the pledge: bare bald head, white chin-curtain beard.
	"price":{"head":Vector3(0.98,1.01,1),"knee":"whole","hat":"none","hair":"b9b3a9","beard_style":"chin_curtain","beard_shape":{"beard_long":.7},
		"skin":"fair","shaven":1.0,"bald":true,
		"shirt":"e6e1d4","pattern":"plain","sleeves":"down",
		"vest":"1d1c1b","trousers":"2a2927","scarf":"","build":"average","height":.96},
}
## Lambert: a French-Canadian ex-Hudson's Bay voyageur at French Camp. Red tuque, red
## ceinture flechee, grey walrus moustache and side-whiskers, checked shirt, no vest.
const LAMBERT:={"head":Vector3(1.05,.98,1.04),"knee":"whole","hat":"tuque","hat_colour":"9b2a22","knit":true,"hair":"9a948b","beard":"b5afa6",
	"beard_style":"mutton_chops","beard_shape":{"moustache_walrus":1.0,"beard_bushy":.5},"skin":"weathered","shaven":.45,
	"cut":{"hair_short":.3},"shirt":"cfc8b3","shirt_b":"3b4f6e","pattern":"check","check":.03,"sleeves":"rolled",
	"vest":"","trousers":"39332c","scarf":"2c3e5c","sash":"8c1d18","sash_kind":2,"build":"heavy","height":1.0}

static func look(id: String) -> Dictionary:
	if id=="lambert": return LAMBERT
	if MEN.has(id): return MEN[id]
	# A man not in the casting (old saves, tests): a plain hand from a seeded draw.
	var rng:=RandomNumberGenerator.new();rng.seed=hash(id+"look")
	var hats: Array=["slouch","wide_awake","farmer"];var shirts: Array=["8a8370","5b6d7c","9b2f24","d9d4c4"]
	return {"hat":hats[rng.randi()%hats.size()],"hat_colour":"4a4842","hair":["2a1f18","5e4632","8a3e1c"][rng.randi()%3],
		"beard_style":["full","moustache","clean"][rng.randi()%3],"shirt":shirts[rng.randi()%shirts.size()],
		"build":"average","height":rng.randf_range(.96,1.04)}

static func linear(hex: String) -> Color:
	return Color.html(hex).srgb_to_linear() if hex!="" else Color(0,0,0,0)

## Instance uniforms for crew.gdshader, shared by every surface of one man.
static func uniforms(man: Dictionary) -> Dictionary:
	var patterns:={"plain":0.0,"check":1.0,"stripe":2.0,"plaid":3.0}
	var out:={}
	var shirt:=linear(man.get("shirt",""));var shirt_b:=linear(man.get("shirt_b",""))
	out.shirt=Vector4(shirt.r,shirt.g,shirt.b,patterns.get(man.get("pattern","plain"),0.0))
	out.shirt_b=Vector4(shirt_b.r,shirt_b.g,shirt_b.b,float(man.get("check",.05)))
	var vest:=String(man.get("vest",""))
	var v:=linear(vest);out.vest=Vector4(v.r,v.g,v.b,0.0 if vest=="" else 1.0)
	var t:=linear(man.get("trousers",""));out.trousers=Vector4(t.r,t.g,t.b,{"torn":0.0,"patched":1.0,"whole":2.0}.get(man.get("knee","torn"),0.0))
	var scarf:=String(man.get("scarf",""))
	var s:=linear(scarf);out.scarf=Vector4(s.r,s.g,s.b,0.0 if scarf=="" else 1.0)
	var braces:=String(man.get("braces",""))
	# The kit's harness straps are the braces: shown only on men who wear them.
	var b:=linear(braces);out.braces=Vector4(b.r,b.g,b.b,0.0 if braces=="" else 1.0)
	var sash:=String(man.get("sash",""))
	var w:=linear(sash);out.sash=Vector4(w.r,w.g,w.b,0.0 if sash=="" else float(man.get("sash_kind",1)))
	var h:=linear(man.get("hat_colour",""));out.hat=Vector4(h.r,h.g,h.b,1.0 if man.get("knit",false) else 0.0)
	var band:=linear(man.get("band",""));out.band=Vector4(band.r,band.g,band.b,0)
	var tone: Vector3=SKINS.get(man.get("skin","weathered"),Vector3.ONE)
	out.skin=Vector4(tone.x,tone.y,tone.z,float(man.get("shaven",0.0)))
	out.scalp=Vector4(0,0,0,1.0 if man.get("bald",false) else 0.0)
	var hair:=linear(man.get("hair",""));out.hair=Vector4(hair.r,hair.g,hair.b,0)
	var beard:=linear(man.get("beard",""))
	out.beard=Vector4(beard.r,beard.g,beard.b,float(BEARDS.get(man.get("beard_style","full"),15)))
	return out

## Blend-shape weights per kit mesh.
static func shapes(man: Dictionary) -> Dictionary:
	var hat: Dictionary=HATS.get(man.get("hat","slouch"),{}).duplicate()
	var hair: Dictionary=man.get("cut",{}).duplicate()
	hair.merge(man.get("beard_shape",{}))
	if man.get("hat","slouch") in ["watch_cap","tuque"]: hair["hair_capped"]=1.0
	# The beard shell on the face takes the same beard keys as the strands.
	var skin: Dictionary=man.get("beard_shape",{}).duplicate()
	var body:={}
	match man.get("sleeves",""):
		"rolled": body["sleeves_rolled"]=1.0
		"down": body["sleeves_down"]=1.0
	return {"Hat":hat,"Hair":hair,"Skin":skin,"Body":body}
