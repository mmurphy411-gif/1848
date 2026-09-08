@tool
extends RefCounted
## Sparse, filtered stars. The built-in panorama is additive even during day,
## so update its brightness in small steps only during astronomical twilight.
var image := Image.create(4096,2048,false,Image.FORMAT_RGBH)
var texture: ImageTexture
var stars: Array[Vector3] = []
var visibility := -1.0
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 184807
	for i in 1800:
		var x := rng.randi_range(0,4095)
		# Uniform solid angle, rather than crowding both panorama poles.
		var y := clampi(int(acos(rng.randf_range(-1,1))/PI*2048),0,2047)
		stars.append(Vector3(x,y,rng.randf_range(.8,3.0) if i%14 else 7.0))
	image.fill(Color.BLACK)
	texture = ImageTexture.create_from_image(image)

func fade(amount: float) -> void:
	var value := snappedf(amount,.02)
	if value==visibility: return
	visibility = value
	image.fill(Color.BLACK)
	for star in stars:
		image.set_pixel(int(star.x),int(star.y),Color(.83,.89,1)*star.z*value)
	texture.update(image)
