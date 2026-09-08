"""Eight baked clips using analytic two-bone hand/foot IK.
Reference watched before keyframing: BLM Alaska, How to pan for gold,
https://www.youtube.com/watch?v=AeaHDcDZylE (shake, drain and final wash).
The solver keeps heel and grip targets fixed while the torso changes posture.
"""
import math
from common import *
from mathutils import Matrix
CLIPS={'idle':4.0,'walk':1.0,'wade':1.2,'pan_enter':2.0,'pan_swirl':2.0,'pan_wash':1.5,'pan_lift':1.5,'pan_exit':1.0}
CLIPS.update({'pan_swirl_2':2.0,'pan_swirl_3':2.0})
CLIPS.update({'fish_idle':3.,'cast':1.2,'fish_wait':4.,'strike':.4,'fight':1.,'land':2.,'gather':2.,'tend_fire':2.,'eat':3.,'lie_down':2.})
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
        swirl=clip.startswith('pan_swirl')
        cycle={'pan_swirl':0,'pan_swirl_2':1,'pan_swirl_3':2}.get(clip,0)
        phase=t*math.tau/(1.2 if clip=='wade' else 1.0)
        crouch=0.;lift=0.;pan_t=0.
        if clip=='pan_enter':crouch=smooth(t/1.75);pan_t=crouch
        if swirl or clip in ['pan_wash','pan_lift']:crouch=1.;pan_t=1.
        if clip=='pan_lift':lift=smooth(t/1.5)
        if clip=='pan_exit':crouch=1-smooth(t);pan_t=crouch;lift=crouch
        if clip in ['gather','tend_fire']:crouch=math.sin(math.pi*t/2)**2
        if clip=='eat':crouch=.9
        if clip=='lie_down':crouch=smooth(t/2)
        lean=math.radians(43)*crouch-math.radians(33)*lift
        hip=Vector((.006*math.sin(t*math.pi*.5)*(1-crouch),.10*crouch,.94-.42*crouch))
        if clip=='eat':lean=.08;hip=Vector((0,.25,.32))
        if clip=='lie_down':lean=-math.pi*.48*smooth(t/2);hip=Vector((0,.7*smooth(t/2),.94-.72*smooth(t/2)))
        moving=clip in ['walk','wade']
        if moving:hip.z+=.018*math.cos(phase*2);hip.x=.022*math.sin(phase)
        rotation=Matrix.Rotation(lean,4,'X')
        direction=rotation.to_3x3()@Vector((0,0,1))
        matrices={}
        def bone(name,a,b):
            old=Vector(joints[name][1])-Vector(joints[name][0]);new=Vector(b)-Vector(a)
            q=old.rotation_difference(new);mat=q.to_matrix().to_4x4()@rest[name]
            mat.translation=a;matrices[name]=mat
        a=t*math.tau/2+[0,.22,.47][cycle]
        shoulder_orbit=Vector((.037*math.cos(a),.037*math.sin(a),0)) if swirl else Vector((0,0,0))
        spine=hip+direction*.12;chest=spine+direction*.18;neck=chest+direction*.19;head=neck+direction*.08
        head_direction=Matrix.Rotation(lean+math.radians(20)*crouch+math.radians(7)*lift,3,'X')@Vector((0,0,1))
        for n,start,end in [('Hips',hip,spine),('Spine',spine,chest),('Chest',chest,neck),('Neck',neck,head),('Head',head,head+head_direction*.18)]:bone(n,start,end)
        carried=Vector((.37,-.015,.46+.009*math.sin(t*math.pi*.5)))
        pan=carried.lerp(Vector((.102,-.35,-.065)),pan_t)
        tilt=math.radians(14)*pan_t
        if swirl:
            radius=[.102,.110,.118][cycle]
            # Three brief impulses separated by pauses, superimposed on the
            # slower circular wash. Each pass has its own phase and radius.
            shake=0.
            for center in [.22,.93,1.48]:
                u=(t-center)/.085
                if abs(u)<1:shake+=.007*math.sin(u*math.tau)*(1-u*u)**2
            pan=Vector((radius*math.cos(a)+shake,-.35+radius*math.sin(a),-.065))
            tilt=math.radians(14+2*math.sin(a-.4))
        if clip=='pan_wash':
            u=smooth(t/1.5)
            pan=Vector((.118*math.cos(.47),-.35+.118*math.sin(.47),-.065)).lerp(Vector((0,-.35,.10)),u)
            tilt=math.radians(14+31*u)
        if clip=='pan_lift':
            pan=Vector((0,-.35,.10)).lerp(Vector((0,-.30,.80)),lift);tilt=math.radians(45-20*lift)
        if clip=='pan_exit':pan=carried.lerp(Vector((0,-.30,.80)),crouch);tilt=math.radians(25)*crouch
        carried_rotation=Matrix.Rotation(-math.pi/2,4,'Y').to_quaternion()
        pan_rotation=carried_rotation.slerp(Matrix.Rotation(tilt,4,'X').to_quaternion(),pan_t)
        pan_matrix=pan_rotation.to_matrix().to_4x4();pan_matrix.translation=pan
        for side,sign in [('Left',1),('Right',-1)]:
            # Foot stance: forward travel equals 2.4m per walk cycle. Only
            # the planted half is linear; the recovery arc raises the toe.
            ankle=Vector((sign*.11,.02,.11));foot_tilt=0.
            if clip=='eat':ankle.y=-.30
            if moving:
                u=(t/(1.2 if clip=='wade' else 1.0)+(0 if sign<0 else .5))%1
                stride=.56 if clip=='walk' else .31
                if u<.5:ankle.y=-stride+u*stride*4
                else:
                    v=(u-.5)*2;ankle.y=stride-2*stride*smooth(v);ankle.z+=(.13 if clip=='walk' else .24)*math.sin(v*math.pi);foot_tilt=-.2*math.sin(v*math.pi)
            hip_joint=hip+Vector((sign*.105,0,0))
            knee,ankle=ik(hip_joint,ankle,.411,.423,(sign*(.24+.55*crouch),-1,.5))
            bone(side+'UpperLeg',hip_joint,knee);bone(side+'LowerLeg',knee,ankle)
            bone(side+'Foot',ankle,ankle+Vector((0,-.17,-.04+foot_tilt*.1)))
            shoulder=chest+direction*(.16-.06*crouch)+Vector((sign*.21,0,0))+shoulder_orbit
            bone(side+'Shoulder',chest+direction*(.16-.06*crouch),shoulder)
            carried_hand=Vector((sign*.37,-.015,.765))
            if moving:
                carried_hand.y+=sign*.16*math.sin(phase);carried_hand.x+=sign*(.065 if clip=='wade' else .015)
            target=carried_hand.lerp(pan_matrix@Vector((sign*.242,0,.185)),pan_t)
            if side=='Left':target=target.lerp(pan_matrix@Vector((.275,0,.08)),1-pan_t)
            if clip in ['fish_idle','fish_wait','cast','strike','fight','land']:
                target=Vector((sign*.22,-.26,1.0+.008*math.sin(t*2)))
                if clip=='cast' and side=='Right':target+=Vector((0,-.24*math.sin(t/1.2*math.pi),-.25*math.cos(t/1.2*math.pi)))
                if clip=='strike' and side=='Right':target.z+=.32*smooth(t/.3)
                if clip=='fight':target+=Vector((0,.06*math.cos(t*math.tau+sign),.10*math.sin(t*math.tau+sign)))
                if clip=='land' and side=='Right':target=target.lerp(Vector((-.20,-.35,1.35)),smooth(t/2))
            if clip in ['gather','tend_fire']:target=Vector((sign*.22,-.36,.8-.65*crouch))
            if clip=='eat':target=Vector((sign*.20,-.30,.62+(.47*max(0,math.sin(t*math.tau/1.5)) if side=='Right' else 0)))
            if clip=='lie_down':target=Vector((sign*.3,0,.75-.5*crouch))
            # Keep elbows close to the ribs, with a slight outward pole so the
            # forearms do not intersect during circular shaking.
            l1=(Vector(joints[side+'UpperArm'][1])-Vector(joints[side+'UpperArm'][0])).length
            l2=(Vector(joints[side+'LowerArm'][1])-Vector(joints[side+'LowerArm'][0])).length
            elbow,wrist=ik(shoulder,target,l1,l2,(sign*.06,.02,.60))
            bone(side+'UpperArm',shoulder,elbow);bone(side+'LowerArm',elbow,wrist)
            hand_dir=Vector((sign*.025,0,-.085)).lerp(pan_matrix.to_3x3()@Vector((0,0,-.08)),pan_t)
            if side=='Left':hand_dir=(pan_matrix.to_3x3()@Vector((-.065,0,.035))).lerp(pan_matrix.to_3x3()@Vector((0,0,-.08)),pan_t)
            bone(side+'Hand',wrist,wrist+hand_dir)
            for f,label in enumerate(['Thumb','Index','Middle','Ring','Little']):
                angle=[-.42,-.20,-.065,.07,.205][f]
                radial=Vector((sign*math.cos(angle),math.sin(angle),0))
                points=[radial*r+Vector((0,0,z)) for r,z in [(.241,.105),(.230,.127),(.205,.108),(.190,.073)]]
                for j,segment in enumerate(['Proximal','Intermediate','Distal']):
                    name=side+label+segment
                    relaxed=matrices[side+'Hand']@rest[side+'Hand'].inverted()@rest[name]
                    grip=pan_t
                    # Left hand hooks over the upper lip in the side carry.
                    if side=='Left' and clip not in ['fish_idle','fish_wait','cast','strike','fight','land','gather','tend_fire','eat','lie_down']:
                        carry_points=[Vector((.225-.011*k,(-.045+f*.021),.105-.01*k)) for k in range(4)]
                        start=pan_matrix@carry_points[j];end=pan_matrix@carry_points[j+1]
                        start=start.lerp(pan_matrix@points[j],pan_t);end=end.lerp(pan_matrix@points[j+1],pan_t)
                        bone(name,start,end)
                    else:
                        start=relaxed.translation.lerp(pan_matrix@points[j],grip)
                        end=(relaxed@Vector((0,(Vector(joints[name][1])-Vector(joints[name][0])).length,0))).lerp(pan_matrix@points[j+1],grip)
                        bone(name,start,end)
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
