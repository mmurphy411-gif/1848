extends SkeletonModifier3D
## A man's build on the shared rig: trunk girth and belly, shoulder breadth and limb
## thickness, written after the animation every frame. Each bone's scale is set so its
## net scale is the one wanted, counter-scaling the parent, so heads, hands and feet keep
## their size. Height is the figure's own scale.
const TRUNK:=["Hips","Spine","Chest"]
var net: Dictionary={}
var _local: Array=[]

## build: {"hips":Vector2(width, depth), "spine":..., "chest":..., "shoulders":float, "arms":float, "legs":float, "head":Vector3}
func configure(skeleton: Skeleton3D, build: Dictionary) -> void:
	net.clear()
	for bone in TRUNK:
		var s: Vector2=build.get(bone.to_lower(),Vector2.ONE)
		net[bone]=Vector3(s.x,1,s.y)
	var arms: float=build.get("arms",1.0);var legs: float=build.get("legs",1.0)
	for side in ["Left","Right"]:
		net[side+"Shoulder"]=Vector3(1,build.get("shoulders",1.0),1)
		net[side+"UpperArm"]=Vector3(arms,1,arms)
		net[side+"LowerArm"]=Vector3(arms,1,arms)
		net[side+"UpperLeg"]=Vector3(legs,1,legs)
		net[side+"LowerLeg"]=Vector3(legs,1,legs)
	for bone in ["Neck","LeftHand","RightHand","LeftFoot","RightFoot"]: net[bone]=Vector3.ONE
	# Head shape: width, length and depth of the skull (hat, hair and beard follow it).
	net["Head"]=build.get("head",Vector3.ONE)
	_local.clear()
	for bone in net:
		var index:=skeleton.find_bone(bone)
		if index<0: continue
		var parent:=skeleton.get_bone_parent(index)
		var inherited: Vector3=_parent_net(skeleton,parent)
		var local: Vector3=net[bone]/_in_frame(skeleton,index,inherited)
		if not local.is_equal_approx(Vector3.ONE): _local.append([index,local])

func _parent_net(skeleton: Skeleton3D, index: int) -> Vector3:
	if index<0: return Vector3.ONE
	return net.get(skeleton.get_bone_name(index),Vector3.ONE)

## The parent's net scale seen along this bone's own rest axes (the rig's joints are
## near axis-aligned, so the diagonal is enough).
func _in_frame(skeleton: Skeleton3D, index: int, inherited: Vector3) -> Vector3:
	var r:=skeleton.get_bone_rest(index).basis.orthonormalized()
	var m:=r.transposed()*Basis.from_scale(inherited)*r
	return Vector3(absf(m.x.x),absf(m.y.y),absf(m.z.z))

func _process_modification() -> void:
	var skeleton:=get_skeleton()
	if skeleton==null: return
	# On top of the clip's own scale keys; the skeleton restores the unmodified pose
	# before the next frame, so this never accumulates.
	for item in _local: skeleton.set_bone_pose_scale(item[0],skeleton.get_bone_pose_scale(item[0])*item[1])
