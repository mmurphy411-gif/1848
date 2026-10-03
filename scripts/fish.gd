extends MeshInstance3D
const Layout=preload("res://scripts/claim_layout.gd")
const Weather=preload("res://scripts/weather.gd")
var species := "trout"
var spot: Dictionary={}
var weight_lb := 1.0
var home := Vector3.ZERO
var age := 0.0
var flee_time := -1.0
var approach := false
var approach_target := Vector3.ZERO
var retired := false
var fade := 0.0:
	set(value):
		fade=value
		if shadow: shadow.modulate.a=.8*shadow_light*fade
var material: ShaderMaterial
var eye_material: ShaderMaterial
var walker: CharacterBody3D
## Species looks for shaders/fish.gdshader (VISUAL_UPGRADE_NOTES.md, Stage 5): dorsal and
## belly tints (sRGB), spot density and flank silvering. Rainbow trout: olive back, black
## spots; Chinook in the run: dark olive-grey, spotted back and tail; Sacramento sucker:
## brown back, cream-yellow belly; pikeminnow: olive over bright silver; hardhead: bronze.
## Wave C: the backs are darker (a fish is seen from above as a dark spindle over the
## paler bed) and the shader adds a pale lateral line with a soft flank sheen.
const LOOKS := {
	"trout": [Color(.085,.11,.07),Color(.84,.82,.78),.55,.35],
	"salmon": [Color(.09,.10,.085),Color(.72,.70,.66),.45,.25],
	"sucker": [Color(.12,.10,.065),Color(.80,.75,.60),0.0,.15],
	"pikeminnow": [Color(.10,.12,.075),Color(.86,.86,.82),0.0,.45],
	"hardhead": [Color(.12,.10,.07),Color(.82,.80,.73),0.0,.40],
}
## A soft shadow on the bed under each school fish, cast along the sun: a decal, so it is
## drawn in the opaque pass the water refracts. One shared fall-off texture.
static var shadow_texture: GradientTexture2D
## Occlusion 0, roughness 1, metal 0 under the shadow (masked by its fall-off): black albedo
## alone left the wet stones' sky glints shining through.
static var shadow_orm: ImageTexture
var shadow: Decal
var shadow_light := 0.0
var sun: DirectionalLight3D
## A fish material for one species and mesh (school fish and the landed trophy).
static func look(kind: String, source: Mesh) -> ShaderMaterial:
	var mat := ShaderMaterial.new();mat.shader=preload("res://shaders/fish.gdshader")
	mat.set_shader_parameter("scales",preload("res://assets/fish/fish_atlas.png"))
	mat.set_shader_parameter("length_m",.85 if kind=="salmon" else .40)
	mat.set_shader_parameter("half_depth",source.get_aabb().size.y*.5)
	var row: Array=LOOKS.get(kind,LOOKS.trout)
	mat.set_shader_parameter("back_color",row[0]);mat.set_shader_parameter("belly_color",row[1])
	mat.set_shader_parameter("spot_density",row[2]);mat.set_shader_parameter("silver",row[3])
	return mat
## Body material on the first surface, a glossy-black copy on the eye surfaces; both
## share fade and swim parameters. Returns [body, eye].
static func dress(target: MeshInstance3D, kind: String) -> Array[ShaderMaterial]:
	var body := look(kind,target.mesh)
	var eye: ShaderMaterial=body.duplicate();eye.set_shader_parameter("eye",true)
	for surface in target.mesh.get_surface_count(): target.set_surface_override_material(surface,body if surface==0 else eye)
	return [body,eye]
func set_look(parameter: String, value: Variant) -> void:
	material.set_shader_parameter(parameter,value);eye_material.set_shader_parameter(parameter,value)
func configure(data: Dictionary,source: Mesh,w: CharacterBody3D) -> void:
	species=data.species;spot=data.spot;weight_lb=data.weight_lb;mesh=source;walker=w
	var offset := Vector2(sin(data.index*2.4)*1.1,cos(data.index*2.4)*.65)
	home=Vector3(spot.position.x+offset.x,-.4,spot.position.y+offset.y)
	var water: float=walker.get_node("/root/GameState").water_level()
	if species=="salmon": home.z=preload("res://scripts/river_model.gd").shore_z(home.x,water)-2.15
	home.z=minf(home.z,preload("res://scripts/river_model.gd").shore_z(home.x,water)-(2.15 if species=="salmon" else 3.5))
	home.y=water-.4
	if species in ["sucker","salmon"]: home.y=Layout.height_at(home.x,home.z)+.22
	elif species=="pikeminnow" or species=="hardhead": home.y=lerpf(water,Layout.height_at(home.x,home.z),.5)
	position=home
	scale=Vector3.ONE*pow(weight_lb/(15.0 if species=="salmon" else 1.0),1.0/3.0)
	var looks := dress(self,species);material=looks[0];eye_material=looks[1]
	set_look("phase",data.index*2.3+home.x)
	age=Weather.noise(data.index,12,int(home.x))*10
	sun=walker.get_parent().get_node_or_null("Daylight/Sun")
	if shadow_texture==null:
		var ramp:=Gradient.new();ramp.set_color(0,Color(1,1,1,1));ramp.set_color(1,Color(1,1,1,0))
		ramp.add_point(.45,Color(1,1,1,.8))
		shadow_texture=GradientTexture2D.new();shadow_texture.gradient=ramp
		shadow_texture.fill=GradientTexture2D.FILL_RADIAL;shadow_texture.fill_from=Vector2(.5,.5);shadow_texture.fill_to=Vector2(1,.5)
		shadow_texture.width=64;shadow_texture.height=64
		var orm:=Image.create(4,4,false,Image.FORMAT_RGBA8);orm.fill(Color(0,1,0,1))
		shadow_orm=ImageTexture.create_from_image(orm)
	shadow=Decal.new();shadow.name="Shadow";shadow.texture_albedo=shadow_texture;shadow.texture_orm=shadow_orm
	shadow.albedo_mix=1.0;shadow.upper_fade=.15;shadow.lower_fade=.3;shadow.normal_fade=.3
	shadow.distance_fade_enabled=true;shadow.distance_fade_begin=30.0;shadow.distance_fade_length=10.0
	var size: Vector3=source.get_aabb().size
	shadow.set_meta("footprint",Vector2(size.x*1.1,maxf(size.z*2.6,size.y*.9)))
	add_child(shadow)

func _ready() -> void:
	_place_shadow()

## Where the sun would throw the fish's shadow on the bed, softened and faded with the
## fish; none at night or under heavy overcast.
func _place_shadow() -> void:
	if shadow==null or not is_inside_tree(): return
	var toward: Vector3=sun.global_basis.z if sun else Vector3.UP
	shadow_light=smoothstep(.1,.35,toward.y)*(clampf(sun.light_energy/1.4,0,1) if sun and sun.visible else 0.0)
	shadow.visible=shadow_light>.01
	if not shadow.visible: return
	var p: Vector3=global_position
	var bed: float=Layout.height_at(p.x,p.z)
	var reach: Vector3=-toward/maxf(toward.y,.2)*maxf(p.y-bed,0.0)
	reach.y=0;reach=reach.limit_length(1.2)
	var q: Vector3=p+reach;q.y=Layout.height_at(q.x,q.z)
	var footprint: Vector2=shadow.get_meta("footprint")*scale.x
	# The box runs from under the fish's belly down past the bed, turned with the fish.
	var top: float=maxf(p.y-mesh.get_aabb().size.y*.5*scale.y-.02,q.y+.06)
	var bottom: float=q.y-.1
	shadow.global_transform=Transform3D(Basis(Vector3.UP,global_rotation.y),Vector3(q.x,(top+bottom)*.5,q.z))
	shadow.size=Vector3(footprint.x,top-bottom,footprint.y)
	shadow.modulate=Color(0,0,0,.8*shadow_light*fade)

func flee() -> void:
	if flee_time>=0: return
	flee_time=0
	approach=false
func _process(delta: float) -> void:
	age+=delta
	fade=move_toward(fade,0 if retired else 1,delta*.5)
	set_look("visibility",fade)
	if retired and fade<=0: queue_free();return
	var distance := global_position.distance_to(walker.global_position)
	if not approach and flee_time<0 and (distance<(1.8 if species=="salmon" else 4.0 if walker.water_depth>0 else 2.5) or (walker.panner.state!=0 and distance<6)): flee()
	var desired := home+Vector3(sin(age*.38)*.8,0,cos(age*.43)*.35)
	var dart := pow(maxf(0,sin(age*.65)),12)
	desired.x-=dart*(2.3 if species=="salmon" else 1.2)
	if approach: desired=approach_target
	if flee_time>=0:
		flee_time+=delta
		desired=home+Vector3(2,-.1,-2.5)
		visible=flee_time<1.5
		if flee_time>20+fposmod(home.x*3,20): flee_time=-1;visible=true
	var motion := desired-position
	var heading := atan2(motion.z,-motion.x) if approach or flee_time>=0 or dart>.4 else 0.0
	rotation.y=lerp_angle(rotation.y,heading,delta*4)
	position=position.move_toward(desired,delta*(3.0 if flee_time>=0 else 1.0 if approach else .6))
	var water: float=get_node("/root/GameState").water_level()
	position.z=minf(position.z,preload("res://scripts/river_model.gd").shore_z(position.x,water)-(2.15 if species=="salmon" else 3.5))
	var half_height := mesh.get_aabb().size.y*.5*scale.y+.03
	position.y=clampf(position.y,Layout.height_at(position.x,position.z)+half_height,water-half_height)
	set_look("pace",3.0 if flee_time>=0 else 1.8 if approach else .7)
	_place_shadow()
