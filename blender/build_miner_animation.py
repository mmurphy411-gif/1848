"""Eight baked clips using analytic two-bone hand/foot IK.
Reference watched before keyframing: BLM Alaska, How to pan for gold,
https://www.youtube.com/watch?v=AeaHDcDZylE (shake, drain and final wash).
The solver keeps heel and grip targets fixed while the torso changes posture.
"""
import math
from common import *
from mathutils import Matrix, Quaternion
CLIPS={'idle':4.0,'walk':1.0,'wade':1.2,'pan_enter':2.0,'pan_swirl':2.0,'pan_wash':1.5,'pan_lift':1.5,'pan_exit':1.0}
def smooth(t):return max(0,min(1,t))**2*(3-2*max(0,min(1,t)))
def ik(root,target,l1,l2,pole):
    delta=target-root;d=max(.0001,min(delta.length,l1+l2-.0001));axis=delta.normalized()
    bend=Vector(pole)-root;bend=(bend-axis*bend.dot(axis)).normalized()
    along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along))
    return root+axis*along+bend*height,root+axis*d
def animate(rig,body,joints):
    scene=bpy.context.scene;scene.render.fps=30
    rig.animation_data_create()
    rest={n:rig.data.bones[n].matrix_local.copy() for n in joints}
    def pose(clip,t):
        phase=t*math.tau/(1.2 if clip=='wade' else 1.0)
        crouch=0.;lift=0.;pan_t=0.
        if clip=='pan_enter':crouch=smooth(t/1.75);pan_t=crouch
        if clip in ['pan_swirl','pan_wash','pan_lift']:crouch=1.;pan_t=1.
        if clip=='pan_lift':lift=smooth(t/1.5)
        if clip=='pan_exit':crouch=1-smooth(t);pan_t=crouch;lift=crouch
        lean=math.radians(72)*crouch-math.radians(37)*lift
        hip=Vector((.006*math.sin(t*math.pi*.5),.11*crouch,.94-.54*crouch+.10*lift))
        moving=clip in ['walk','wade']
        if moving:hip.z+=.018*math.cos(phase*2);hip.x=.022*math.sin(phase)
        rotation=Matrix.Rotation(lean,4,'X')
        direction=rotation.to_3x3()@Vector((0,0,1))
        matrices={}
        def bone(name,a,b):
            old=Vector(joints[name][1])-Vector(joints[name][0]);new=Vector(b)-Vector(a)
            q=old.rotation_difference(new);mat=q.to_matrix().to_4x4()@rest[name];mat.translation=a;matrices[name]=mat
        spine=hip+direction*.12;chest=spine+direction*.18;neck=chest+direction*.19;head=neck+direction*.08
        for n,a,b in [('Hips',hip,spine),('Spine',spine,chest),('Chest',chest,neck),('Neck',neck,head),('Head',head,head+direction*.18)]:bone(n,a,b)
        carried=Vector((.32,-.015,.73+.025*math.sin(t*math.pi*.5)))
        pan=carried.lerp(Vector((0,-.66,-.065)),pan_t)
        tilt=math.radians(78)*(1-pan_t)
        if clip=='pan_swirl':
            a=t*math.tau/2
            pan+=Vector((.060*math.cos(a)-.060+.009*math.sin(a*7),.052*math.sin(a),.027*math.sin(a)+.008*math.sin(a*5)))
            tilt=math.radians(8+9*math.sin(a-.4))
        if clip=='pan_wash':
            u=smooth(t/1.5);pan.z+=.13*u;tilt=math.radians(42)*math.sin(u*math.pi*.5)
        if clip=='pan_lift':
            pan=Vector((0,-.66,.065)).lerp(Vector((0,-.57,.72)),lift);tilt=math.radians(42-27*lift)
        if clip=='pan_exit':pan=carried.lerp(Vector((0,-.57,.72)),crouch);tilt=math.radians(78-63*crouch)
        pan_matrix=Matrix.Rotation(tilt,4,'X');pan_matrix.translation=pan
        for side,sign in [('Left',1),('Right',-1)]:
            # Foot stance: forward travel equals 2.4m per walk cycle. Only
            # the planted half is linear; the recovery arc raises the toe.
            ankle=Vector((sign*(.11+.045*crouch),.02,.11));foot_tilt=0.
            if moving:
                u=(t/(1.2 if clip=='wade' else 1.0)+(0 if sign<0 else .5))%1
                stride=.56 if clip=='walk' else .31
                if u<.5:ankle.y=-stride+u*stride*4
                else:
                    v=(u-.5)*2;ankle.y=stride-2*stride*smooth(v);ankle.z+=(.13 if clip=='walk' else .24)*math.sin(v*math.pi);foot_tilt=-.2*math.sin(v*math.pi)
            hip_joint=hip+Vector((sign*.105,0,0))
            knee,ankle=ik(hip_joint,ankle,.411,.423,(sign*.24,-1,.5))
            bone(side+'UpperLeg',hip_joint,knee);bone(side+'LowerLeg',knee,ankle)
            bone(side+'Foot',ankle,ankle+Vector((0,-.17,-.04+foot_tilt*.1)))
            shoulder=chest+direction*.16+Vector((sign*.21,0,0))
            bone(side+'Shoulder',chest+direction*.16,shoulder)
            carried_hand=Vector((sign*.32,-.015,.855))
            if moving:
                carried_hand.y+=sign*.16*math.sin(phase);carried_hand.x+=sign*(.065 if clip=='wade' else .015)
            target=carried_hand.lerp(pan_matrix@Vector((sign*.215,0,.115)),pan_t)
            # Keep elbows close to the ribs, with a slight outward pole so the
            # forearms do not intersect during circular shaking.
            elbow,wrist=ik(shoulder,target,.309,.258,(sign*.38,.06,.7-.20*crouch))
            bone(side+'UpperArm',shoulder,elbow);bone(side+'LowerArm',elbow,wrist)
            hand_dir=Vector((sign*.025,0,-.085)).lerp(Vector((-sign*.018,0,-.08)),pan_t)
            bone(side+'Hand',wrist,wrist+hand_dir)
            for f in ['Thumb','Index','Middle','Ring','Little']:
                name=side+f+'Proximal'
                matrices[name]=matrices[side+'Hand']@rest[side+'Hand'].inverted()@rest[name]
            if side=='Left' and pan_t<.999:
                pan_matrix.translation=pan_matrix.translation.lerp(wrist+Vector((0,0,-.125)),1-pan_t)
        # pan_socket stays parented to RightHand. Its keyed local transform
        # transfers the carried pan to LeftHand without changing attachments.
        matrices['pan_socket']=pan_matrix@rest['pan_socket'].to_quaternion().to_matrix().to_4x4()
        matrices['pan_socket'].translation=pan_matrix.translation
        for name in joints:
            rig.pose.bones[name].matrix=matrices[name]
            bpy.context.view_layer.update()
        return pan_matrix
    for clip,duration in CLIPS.items():
        action=bpy.data.actions.new(clip);rig.animation_data.action=action
        frames=round(duration*30);scene.frame_start=1;scene.frame_end=frames+1
        for frame in range(frames+1):
            scene.frame_set(frame+1);pose(clip,frame/30)
            for pb in rig.pose.bones:
                pb.rotation_mode='QUATERNION'
                pb.keyframe_insert('location',frame=frame+1,group=pb.name)
                pb.keyframe_insert('rotation_quaternion',frame=frame+1,group=pb.name)
                pb.keyframe_insert('scale',frame=frame+1,group=pb.name)
        rig.animation_data.action=None
        track=rig.animation_data.nla_tracks.new();track.name=clip
        strip=track.strips.new(clip,1,action);strip.name=clip;track.mute=True
    scene.frame_start=1;scene.frame_end=121
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    save('build_miner')
    for track in rig.animation_data.nla_tracks:track.mute=False
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/'miner/miner.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_normals=True,export_tangents=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_materials='PLACEHOLDER',export_all_influences=False,export_cameras=False,export_lights=False)
    print('MINER_CLIPS',CLIPS)
