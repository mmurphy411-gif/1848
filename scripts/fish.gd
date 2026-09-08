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
var fade := 0.0
var material: ShaderMaterial
var walker: CharacterBody3D
func configure(data: Dictionary,source: Mesh,w: CharacterBody3D) -> void:
	species=data.species;spot=data.spot;weight_lb=data.weight_lb;mesh=source;walker=w
	var offset := Vector2(sin(data.index*2.4)*1.1,cos(data.index*2.4)*.65)
	home=Vector3(spot.position.x+offset.x,-.4,spot.position.y+offset.y)
	if species in ["sucker","salmon"]: home.y=Layout.height_at(home.x,home.z)+.22
	elif species=="pikeminnow" or species=="hardhead": home.y=Layout.height_at(home.x,home.z)*.5
	position=home
	scale=Vector3.ONE*pow(weight_lb/(15.0 if species=="salmon" else 1.0),1.0/3.0)
	material=ShaderMaterial.new();material.shader=preload("res://shaders/fish.gdshader")
	material.set_shader_parameter("scales",preload("res://assets/fish/fish_atlas.png"))
	material.set_shader_parameter("length_m",.85 if species=="salmon" else .40)
	material.set_shader_parameter("phase",data.index*2.3+home.x)
	material_override=material
	age=Weather.noise(data.index,12,int(home.x))*10
func flee() -> void:
	if flee_time>=0: return
	flee_time=0
	approach=false
func _process(delta: float) -> void:
	age+=delta
	fade=move_toward(fade,0 if retired else 1,delta*.5)
	material.set_shader_parameter("visibility",fade)
	if retired and fade<=0: queue_free();return
	var distance := global_position.distance_to(walker.global_position)
	if not approach and flee_time<0 and (distance<(4.0 if walker.water_depth>0 else 2.5) or (walker.panner.state!=0 and distance<6)): flee()
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
	position.z=minf(position.z,Layout.shore_z(position.x)-4.5)
	var half_height := mesh.get_aabb().size.y*.5*scale.y+.03
	position.y=clampf(position.y,Layout.height_at(position.x,position.z)+half_height,-half_height)
	material.set_shader_parameter("pace",3.0 if flee_time>=0 else 1.8 if approach else .7)
