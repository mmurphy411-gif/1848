extends SceneTree
var failures: Array[String] = []
var metrics: Dictionary = {}
func _initialize() -> void:run.call_deferred()
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures.append(label)
func run() -> void:
	root.get_node("GameState").apply_scenario({"day":"75","pick":"1","shovel":"1"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var visual: Node3D=claim.get_node("Walker/Visual")
	await frames(5)
	var meshes: Array[Node]=[]
	for node: MeshInstance3D in visual.miner.find_children("*","MeshInstance3D",true,false):
		if node.mesh.surface_get_material(0).resource_name.begins_with("Intrepid_"):meshes.append(node)
	var triangles:=0;var surfaces:=0;var valid_weights:=true;var textures_valid:=true;var skins_valid:=true;var lod_count:=0
	var hair_cutout_valid:=false
	for mesh: MeshInstance3D in meshes:
		skins_valid = skins_valid and mesh.skin!=null and mesh.get_node(mesh.skeleton)==visual.skeleton
		for surface in mesh.mesh.get_surface_count():
			surfaces+=1
			var render_surface: Dictionary=RenderingServer.mesh_get_surface(mesh.mesh.get_rid(),surface)
			lod_count+=render_surface.get("lods",[]).size()
			var arrays: Array=mesh.mesh.surface_get_arrays(surface)
			triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			valid_weights=valid_weights and weights.size()==arrays[Mesh.ARRAY_VERTEX].size()*4
			for i in range(0,weights.size(),4):
				valid_weights=valid_weights and absf(weights[i]+weights[i+1]+weights[i+2]+weights[i+3]-1)<.001
			var material: ShaderMaterial=mesh.get_surface_override_material(surface)
			for parameter in ["albedo_atlas","normal_atlas","surface_atlas"]:
				textures_valid=textures_valid and material.get_shader_parameter(parameter) is Texture2D
			if mesh.mesh.surface_get_material(surface).resource_name=="Intrepid_Hair":
				var atlas: Texture2D=material.get_shader_parameter("albedo_atlas")
				var pixels:=atlas.get_image()
				if pixels.is_compressed():pixels.decompress()
				var clear_pixels:=0;var opaque_pixels:=0
				for y in range(0,pixels.get_height(),8):
					for x in range(0,pixels.get_width(),8):
						var alpha:=pixels.get_pixel(x,y).a
						if alpha<.25:clear_pixels+=1
						if alpha>.75:opaque_pixels+=1
				hair_cutout_valid=material.get_shader_parameter("hair_cutout")==true and clear_pixels>100 and opaque_pixels>100
	check(meshes.size()==8 and surfaces==8,"Eight modular meshes / eight atlas surfaces")
	check(triangles<120000,"Full source LOD under 120k triangles: %d" % triangles)
	check(valid_weights and skins_valid,"All mesh skins target the live skeleton with four normalized influences")
	check(textures_valid,"Every runtime material has baked color, normal and roughness/metallic textures")
	check(hair_cutout_valid,"Hair preserves both transparent strand gaps and opaque coverage after GLB import")
	check(lod_count>0,"Imported meshes contain generated distance LODs: %d levels" % lod_count)
	visual.set_physics_process(false);claim.get_node("Walker").set_physics_process(false)
	var keys: Array=visual.equipment.keys();var visibility_ok:=true
	for mask in 32:
		for i in keys.size():visual.set_equipment(keys[i],bool(mask & (1<<i)))
		for i in keys.size():visibility_ok=visibility_ok and visual.equipment[keys[i]].visible==bool(mask & (1<<i))
		for mesh: MeshInstance3D in meshes:
			if String(mesh.name) in ["Body","Skin","Hair"]:visibility_ok=visibility_ok and mesh.is_visible_in_tree()
	check(visibility_ok,"All 32 equipment combinations preserve the complete core character")
	for key in keys:visual.clear_equipment_override(key)
	visual.play_activity("cast")
	check(not visual.equipment.carry_pan.visible and not visual.equipment.carry_pickaxe.visible and not visual.physical_pan.visible,"Fishing frees both hands of travel tools")
	visual.stop_activity();visual.play_pan("pan_enter")
	check(visual.physical_pan.visible and not visual.equipment.carry_pan.visible and not visual.equipment.carry_pickaxe.visible,"Panning uses only the functional pan, without duplicate travel tools")
	visual.stop_activity()
	check(visual.equipment.carry_pan.visible and visual.equipment.carry_pickaxe.visible and not visual.physical_pan.visible,"Returning to locomotion restores owned travel tools")
	visual.play_activity("lie_down")
	check(not visual.pack_visual.visible and not visual.equipment.wear_satchel.visible and not visual.equipment.wear_canteen.visible,"Sleeping stows the pack and hip equipment")
	visual.stop_activity()
	visual.tree.active=false
	var animation_ok:=true;var moved:=false;var previous:=Transform3D.IDENTITY
	var panning_wrist_angle:=0.0
	var panning_skin_rotation:=0.0
	var panning_joint_separation:=0.0
	for clip in visual.player.get_animation_list():
		if clip=="RESET":continue
		visual.player.play(clip)
		for t in [.0,.5,.95]:
			visual.player.seek(visual.player.get_animation(clip).length*t,true)
			for bone in visual.skeleton.get_bone_count():
				var transform: Transform3D=visual.skeleton.get_bone_global_pose(bone)
				animation_ok=animation_ok and transform.is_finite() and transform.origin.length()<4
			var hand: Transform3D=visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("RightHand"))
			moved=moved or not hand.is_equal_approx(previous);previous=hand
			if String(clip).begins_with("pan_"):
				for side in ["Left","Right"]:
					var wrist: Transform3D=visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone(side+"Hand"))
					var elbow: Transform3D=visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone(side+"LowerArm"))
					var angle:=rad_to_deg((wrist.origin-elbow.origin).angle_to(wrist.basis.y))
					panning_wrist_angle=maxf(panning_wrist_angle,angle)
					var hand_rest: Transform3D=visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone(side+"Hand"))
					var arm_rest: Transform3D=visual.skeleton.get_bone_global_rest(visual.skeleton.find_bone(side+"LowerArm"))
					var hand_rotation: Quaternion=(wrist.basis*hand_rest.basis.inverse()).get_rotation_quaternion()
					var arm_rotation: Quaternion=(elbow.basis*arm_rest.basis.inverse()).get_rotation_quaternion()
					panning_skin_rotation=maxf(panning_skin_rotation,rad_to_deg(hand_rotation.angle_to(arm_rotation)))
					for digit in ["Thumb","Index","Middle","Ring","Little"]:
						for segment in ["Proximal","Intermediate","Distal"]:
							var joint: int=visual.skeleton.find_bone(side+digit+segment)
							panning_joint_separation=maxf(panning_joint_separation,visual.skeleton.get_bone_pose_position(joint).distance_to(visual.skeleton.get_bone_rest(joint).origin))
	check(animation_ok and moved,"All imported locomotion, panning, fishing, camp, store and mining clips evaluate finite moving skeletons")
	check(panning_wrist_angle<130.0,"Panning avoids folding the hand back along the forearm: maximum %.1f degrees" % panning_wrist_angle)
	check(panning_skin_rotation<130.0,"Panning avoids wrist skin collapse from axial twist: maximum %.1f degrees" % panning_skin_rotation)
	check(panning_joint_separation<.001,"Panning finger joints remain anatomically attached: maximum offset %.6f m" % panning_joint_separation)
	metrics={"mesh_objects":meshes.size(),"surfaces":surfaces,"triangles":triangles,"generated_lod_levels":lod_count,"animations":visual.player.get_animation_list(),"equipment_cases":32,"hair_cutout_valid":hair_cutout_valid,"panning_wrist_angle_max_degrees":panning_wrist_angle,"failures":failures}
	metrics["panning_skin_rotation_max_degrees"]=panning_skin_rotation
	metrics["panning_joint_separation_max_meters"]=panning_joint_separation
	var file:=FileAccess.open("res://artifacts/miner-game/runtime_audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
	claim.get_node("Soundscape").stop();claim.queue_free();await frames(8)
	print("MINER GAME: ","PASS" if failures.is_empty() else "FAIL");quit(0 if failures.is_empty() else 1)
