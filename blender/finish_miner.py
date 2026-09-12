"""Complete the retained anatomical miner and save an editable production master.

Blender --background --python blender/finish_miner.py
Inputs stay intact; generated surfaces have FINISH names.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[1]
STUDY=ROOT/'experiments/miner_anatomy_study'
OUT=ROOT/'artifacts/miner-finished';OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(STUDY/'refinement'));import run_refine as r
b=r.b

def clone(o,name):
    n=o.copy();n.data=o.data.copy();o.users_collection[0].objects.link(n);n.name=name
    if 'source_component' in n:del n['source_component']
    r.previous.hide(o);return n


def anatomical_surface():
    """Fit the CC0 hand/forearm surface to the established joint locations."""
    import numpy as np
    a,uv,groups=r.previous.source_mesh();rig=bpy.data.objects['MinerRig']
    def unit(v):return v/np.linalg.norm(v)
    def joint(n):return a[sorted({v for f in groups['joint-l-'+n] for v,t in f})].mean(0)
    def bone(n):
        p=rig.data.bones['Left'+n];return np.array(p.head_local),np.array(p.tail_local)
    wrist=joint('hand');elbow=joint('elbow');axis=unit(wrist-elbow)
    normal=unit(np.cross(unit(joint('finger-3-1')-wrist),unit(joint('finger-2-1')-joint('finger-5-1'))))
    dw,dt=bone('Hand');de,_=bone('LowerArm')
    dn=unit(np.cross(unit(dt-dw),unit(bone('IndexProximal')[0]-bone('LittleProximal')[0])))
    source_faces=[f for f in groups['body'] if all(a[v,0]>2.7 and np.dot(a[v]-elbow,axis)>-.6 for v,t in f)]
    ids=sorted({v for f in source_faces for v,t in f});lookup={v:i for i,v in enumerate(ids)}
    segments=[('LowerArm',elbow,wrist),('Hand',wrist,joint('finger-3-1'))]
    for digit,label in enumerate(['Thumb','Index','Middle','Ring','Little'],1):
        js=[joint(f'finger-{digit}-{k}') for k in range(1,5)]
        segments.extend((label+part,js[j],js[j+1]) for j,part in enumerate(['Proximal','Intermediate','Distal']))
    fitted=[]
    for p in a[ids]:
        distances=[]
        for name,start,end in segments:
            t=np.clip(np.dot(p-start,end-start)/np.dot(end-start,end-start),0,1)
            distances.append(np.linalg.norm(p-(start+t*(end-start))))
        ix=np.argsort(distances)[:4];weights=1/(np.array(distances)[ix]+.025)**6;weights/=weights.sum()
        point=np.zeros(3)
        for index,weight in zip(ix,weights):
            name,start,end=segments[index];ta,tb=bone(name);sa=unit(end-start);da=unit(tb-ta)
            sn=unit(normal-sa*np.dot(normal,sa));tn=unit(dn-da*np.dot(dn,da))
            sb=unit(np.cross(sa,sn));tbasis=unit(np.cross(da,tn));offset=p-start
            radius=.115 if name=='LowerArm' else .09
            point+=weight*(ta+da*np.dot(offset,sa)*np.linalg.norm(tb-ta)/np.linalg.norm(end-start)+tn*np.dot(offset,sn)*radius+tbasis*np.dot(offset,sb)*radius)
        if point[2]>1.04:
            direction=unit(dw-de);center=de+direction*np.dot(point-de,direction);radial=point-center
            if np.linalg.norm(radial)>.042:point=center+unit(radial)*.042
            point[2]=min(1.135,point[2])
        fitted.append(point.tolist())
    return fitted,[[lookup[v] for v,t in f] for f in source_faces]

def hands():
    """Continuous anatomy, established grip weights and an explicit wrist blend."""
    from mathutils.kdtree import KDTree
    rig=bpy.data.objects['MinerRig'];mat=skin_material();vertices,faces=anatomical_surface()
    for sign,side in [(1,'Left'),(-1,'Right')]:
        sources=[o for o in bpy.context.scene.objects if o.type=='MESH' and 10<=o.get('source_component',-1)<=33 and any(c.name=='BODY | hands and forearms' for c in o.users_collection) and sum(v.co.x for v in o.data.vertices)*sign>0]
        samples=[];sample_weights=[]
        for source in sources:
            if 'Fingernail' in source.name:continue
            for v in source.data.vertices:
                samples.append(v.co.copy());sample_weights.append({source.vertex_groups[g.group].name:g.weight for g in v.groups if g.weight>0 and source.vertex_groups[g.group].name in rig.data.bones})
        vs=[(p[0]*sign,p[1],p[2]) for p in vertices];fs=faces if sign>0 else [list(reversed(f)) for f in faces]
        o=b.mesh('FINISH | continuous forearm and hand '+side,vs,fs,mat,'BODY | finished anatomy')
        tree=KDTree(len(samples))
        for i,p in enumerate(samples):tree.insert(p,i)
        tree.balance()
        for v in o.data.vertices:
            weights={}
            for p,index,d in tree.find_n(v.co,6):
                influence=1/(d+.002)**4
                for name,w in sample_weights[index].items():weights[name]=weights.get(name,0)+influence*w
            pairs=sorted(weights.items(),key=lambda p:-p[1])[:4];total=sum(w for n,w in pairs)
            for name,w in pairs:
                vg=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);vg.add([v.index],w/total,'REPLACE')
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
        bpy.ops.object.vertex_group_smooth(group_select_mode='ALL',factor=.55,repeat=3)
        bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL',limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL',lock_active=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        wrist=rig.data.bones[side+'Hand'].head_local;axis=(wrist-rig.data.bones[side+'LowerArm'].head_local).normalized()
        forearm=o.vertex_groups.get(side+'LowerArm');hand=o.vertex_groups.get(side+'Hand')
        for v in o.data.vertices:
            t=(v.co-wrist).dot(axis)
            if -.065<t<.018:
                for group in list(v.groups):o.vertex_groups[group.group].remove([v.index])
                h=r.smooth((t+.055)/.073);forearm.add([v.index],1-h,'REPLACE');hand.add([v.index],h,'REPLACE')
        r.smooth_object(o,1);o.parent=rig;arm=o.modifiers.new('MinerRig','ARMATURE');arm.object=rig
        coords=o.data.attributes.new(name='FINISH skin position',type='FLOAT_VECTOR',domain='POINT')
        for v in o.data.vertices:coords.data[v.index].vector=v.co
        o['source_license']='MakeHuman graphical asset CC0 1.0';o['source_commit']='a8bc2d54ff0ac92e78ff71431b1023eda42bf482'
        o['construction']='Continuous anatomical hand/forearm; established grip weights with a broad wrist blend; corrected panning elbow bend'
    for o in list(bpy.context.scene.objects):
        if any(c.name=='BODY | hands and forearms' for c in o.users_collection):r.previous.hide(o)
    (OUT/'hand_fit.json').write_text(json.dumps({'method':'Local anatomical bone-frame fit, original grip weight transfer, topology smoothing and explicit wrist transition','continuous_wrist':True},indent=2))

def skin_material():
    mat=b.material('FINISH | sun-weathered working hands',(.30,.143,.075),.69)
    n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF');p.inputs['Specular IOR Level'].default_value=.22
    coord=n.new('ShaderNodeAttribute');coord.attribute_name='FINISH skin position'
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=160;noise.inputs['Detail'].default_value=3;l.new(coord.outputs['Vector'],noise.inputs[0])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.27,.130,.066,1);ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[1].color=(.34,.187,.103,1);ramp.color_ramp.elements[1].position=.82;l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
    fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=1400;l.new(coord.outputs['Vector'],fine.inputs[0])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.15;bump.inputs['Distance'].default_value=.00012;l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
    return mat

def fabric_variant(role,base,tint,roughness,repeat):
    mat=bpy.data.materials['REFINE | '+base].copy();mat.name='FINISH | '+role
    for n in mat.node_tree.nodes:
        if n.type=='MIX_RGB' and n.blend_type=='MULTIPLY':n.inputs[2].default_value=(*tint,1)
        if n.type=='VECT_MATH' and n.operation=='SCALE' and n.inputs['Scale'].default_value>1:n.inputs['Scale'].default_value=repeat
        if n.type=='BSDF_PRINCIPLED':n.inputs['Roughness'].default_value=roughness
    return mat

def costume():
    mats={
        'trousers':fabric_variant('heavy umber cotton drill','linen',(.28,.19,.115),.92,7),
        'canvas':fabric_variant('weathered flax pack canvas','linen',(.36,.305,.20),.94,8),
        'blanket':fabric_variant('moss wool blanket','vest',(.44,.48,.28),.96,10),
        'boot':fabric_variant('oiled and scuffed boot leather','leather',(.25,.20,.155),.72,4),
    }
    for source in list(bpy.context.scene.objects):
        if source.type!='MESH' or source.hide_render:continue
        role=None;name=source.name
        if name.startswith('Trousers |') and 'fray' not in name:role='trousers'
        elif name.startswith('Backpack |') and 'seam' not in name:role='canvas'
        elif name.startswith('Bedroll |') and 'binding' not in name:role='blanket'
        elif name.startswith('Boot |') and not any(x in name for x in ['buckle','stitched']):role='boot'
        if role:
            o=clone(source,'FINISH | '+name);b.assign(o,mats[role]);r.material_uv(o,'leather' if role=='boot' else 'linen')
            wear=o.data.color_attributes['REFINE wear']
            for v in o.data.vertices:
                z=v.co.z;w=.06
                if role=='trousers':w+=.18*math.exp(-((z-.41)/.08)**2)+.10*math.exp(-((z-.58)/.09)**2)
                elif role=='boot':w+=.16*r.smooth((.12-z)/.10)
                elif role=='canvas':w+=.14*r.smooth((1.12-z)/.12)
                wear.data[v.index].color=(w,w,w,1)
            if role=='canvas' and len(o.data.vertices)>60:
                # Tailored pockets puff between their sewn boundaries.
                zmin=min(v.co.z for v in o.data.vertices);zmax=max(v.co.z for v in o.data.vertices)
                xmin=min(v.co.x for v in o.data.vertices);xmax=max(v.co.x for v in o.data.vertices)
                for v in o.data.vertices:
                    u=(v.co.x-xmin)/max(.001,xmax-xmin);t=(v.co.z-zmin)/max(.001,zmax-zmin)
                    v.co.y+=.0045*math.sin(u*math.pi)*math.sin(t*math.pi)*math.sin(u*13+t*9)
                r.smooth_object(o,1)
        if any(c.name in ['GEAR | backpack','GEAR | bedroll'] for c in source.users_collection) and any(x in name for x in ['harness','binding','closure']):
            if not any(x in name for x in ['adjust','rivet','seam']):
                o=clone(source,'FINISH | '+name);b.assign(o,bpy.data.materials['REFINE | leather']);r.material_uv(o,'leather')
    # Soften the turn of the instep straps and limit corner thickness.
    for side in ['Left','Right']:
        name='FINISH | Boot | diagonal instep strap '+side;o=bpy.data.objects[name]
        for m in o.modifiers:
            if m.type=='SOLIDIFY':m.use_even_offset=False;m.thickness_clamp=1.0
        r.smooth_object(o,2)
    # Apply the calf transition to all boot construction, including collars and seams.
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render or 'Boot |' not in o.name:continue
        for side in ['Left','Right']:
            foot=o.vertex_groups.get(side+'Foot')
            if not foot:continue
            calf=o.vertex_groups.get(side+'LowerLeg') or o.vertex_groups.new(name=side+'LowerLeg')
            for v in o.data.vertices:
                w=sum(g.weight for g in v.groups if g.group==foot.index);t=r.smooth((v.co.z-.11)/.10)
                if w:foot.add([v.index],w*(1-t),'REPLACE');calf.add([v.index],w*t,'REPLACE')
    # Prevent alpha input from switching to the export bake UV map.
    mat=bpy.data.materials['REFINE | fine hair cards'];n=mat.node_tree.nodes;l=mat.node_tree.links
    uv=n.new('ShaderNodeUVMap');uv.uv_map='Hair atlas'
    for tex in n:
        if tex.type=='TEX_IMAGE':l.new(uv.outputs[0],tex.inputs['Vector'])

def panning_arms():
    """Repair panning arm twist and fit attached fingers around the fixed pan.

    The earlier panning solution folded the hand almost back along the forearm.
    A two-bone IK solution reaches the adjusted wrist with a usable bend.
    Forearm roll follows the palm; attached fingers curl beneath the pan wall.
    """
    rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
    review={p.name:p.matrix_basis.copy() for p in rig.pose.bones}
    for p in rig.pose.bones:p.rotation_mode='QUATERNION'
    current=rig.animation_data.action;current_frame=scene.frame_current
    mutes=[t.mute for t in rig.animation_data.nla_tracks]
    modifiers=[(m,m.show_viewport) for o in scene.objects for m in o.modifiers]
    for m,_ in modifiers:m.show_viewport=False
    for track in rig.animation_data.nla_tracks:track.mute=True
    report={}
    for action in [a for a in bpy.data.actions if a.name.startswith('pan_')]:
        rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        frames=range(round(action.frame_range[0]),round(action.frame_range[1])+1)
        # Sample the original first; inserted keys must not influence later samples.
        samples=[]
        for frame in frames:
            scene.frame_set(frame);bpy.context.view_layer.update()
            sample={side:{part:rig.pose.bones[side+part].matrix.copy() for part in ['UpperArm','LowerArm','Hand']} for side in ['Left','Right']}
            sample['pan']=rig.pose.bones['pan_socket'].matrix.copy();samples.append(sample)
        error=0;wrist_offset=0;prior_rotation={}
        for frame,sample in zip(frames,samples):
            scene.frame_set(frame)
            socket=rig.pose.bones['pan_socket']
            pan=sample['pan']@socket.bone.matrix_local.to_quaternion().to_matrix().to_4x4().inverted()
            grip=r.smooth((frame-1)/52.5) if action.name=='pan_enter' else 1-r.smooth((frame-1)/30) if action.name=='pan_exit' else 1
            for sign,side in [(1,'Left'),(-1,'Right')]:
                upper=rig.pose.bones[side+'UpperArm'];lower=rig.pose.bones[side+'LowerArm'];hand=rig.pose.bones[side+'Hand']
                old=sample[side];target_hand=old['Hand'].copy();target_hand.translation+=pan.to_3x3()@Vector((0,0,-.040*grip))
                wrist_offset=max(wrist_offset,(target_hand.translation-old['Hand'].translation).length)
                start=old['UpperArm'].translation;wrist=target_hand.translation;direction=wrist-start;distance=direction.length;axis=direction.normalized()
                a=rig.data.bones[side+'UpperArm'].length;b_len=rig.data.bones[side+'LowerArm'].length
                along=(a*a-b_len*b_len+distance*distance)/(2*distance);height=math.sqrt(max(0,a*a-along*along))
                pole=Vector((sign,.10,.05));pole=(pole-axis*pole.dot(axis)).normalized();elbow=start+axis*along+pole*height
                for pb,key,origin,end in [(upper,'UpperArm',start,elbow),(lower,'LowerArm',elbow,wrist)]:
                    # Match the hand's skin rotation before aiming each arm bone.
                    # Independent shortest-arc poses otherwise leave a near half-turn
                    # of axial twist at the wrist and collapse linear skinning.
                    reference=old['Hand']@hand.bone.matrix_local.inverted()@pb.bone.matrix_local
                    old_direction=reference.to_3x3()@Vector((0,1,0));turn=old_direction.rotation_difference((end-origin).normalized())
                    matrix=turn.to_matrix().to_4x4()@reference;matrix.translation=origin;pb.matrix=matrix;bpy.context.view_layer.update()
                hand.matrix=target_hand;bpy.context.view_layer.update()
                for pb in [upper,lower,hand]:
                    if pb.name in prior_rotation and pb.rotation_quaternion.dot(prior_rotation[pb.name])<0:pb.rotation_quaternion.negate()
                    prior_rotation[pb.name]=pb.rotation_quaternion.copy()
                    for channel in ['location','rotation_quaternion','scale']:pb.keyframe_insert(channel,frame=frame,group=pb.name)
                # Original primitive fingers were translated independently onto
                # the pan rim, separating their roots by up to nine centimetres.
                # A continuous anatomical surface needs fixed joint attachments.
                for digit in ['Thumb','Index','Middle','Ring','Little']:
                    chain=[rig.pose.bones[side+digit+segment] for segment in ['Proximal','Intermediate','Distal']]
                    # Fixed roots and bone lengths; solve a smooth three-segment
                    # arc to the outer lip, with the first joint below the palm.
                    deform=hand.matrix@hand.bone.matrix_local.inverted()
                    root=deform@chain[0].bone.head_local;local=pan.inverted()@root
                    radial=Vector((local.x,local.y,0)).normalized()
                    target=pan@(radial*.208+Vector((0,0,.095 if digit=='Thumb' else .075)))
                    delta=target-root;u=delta.normalized();up=pan.to_3x3()@Vector((0,0,1));v=(up-u*up.dot(u)).normalized()
                    lengths=[p.bone.length for p in chain];distance=min(delta.length,sum(lengths)-.0001)
                    lo=0.;hi=2.0
                    for _ in range(24):
                        q=(lo+hi)/2;x=sum(l*math.cos(j*q) for j,l in enumerate(lengths));y=sum(l*math.sin(j*q) for j,l in enumerate(lengths))
                        if math.hypot(x,y)>distance:lo=q
                        else:hi=q
                    curl=(lo+hi)/2;start_angle=-math.atan2(sum(l*math.sin(j*curl) for j,l in enumerate(lengths)),sum(l*math.cos(j*curl) for j,l in enumerate(lengths)))
                    origin=root
                    for j,pb in enumerate(chain):
                        direction=u*math.cos(start_angle+j*curl)+v*math.sin(start_angle+j*curl)
                        reference=deform@pb.bone.matrix_local
                        turn=(reference.to_3x3()@Vector((0,1,0))).rotation_difference(direction)
                        matrix=turn.to_matrix().to_4x4()@reference;matrix.translation=origin
                        pb.matrix=matrix;bpy.context.view_layer.update();pb.location=(0,0,0)
                        pb.rotation_quaternion=Quaternion().slerp(pb.rotation_quaternion,grip)
                        if pb.name in prior_rotation and pb.rotation_quaternion.dot(prior_rotation[pb.name])<0:pb.rotation_quaternion.negate()
                        prior_rotation[pb.name]=pb.rotation_quaternion.copy()
                        for channel in ['location','rotation_quaternion']:pb.keyframe_insert(channel,frame=frame,group=pb.name)
                        origin+=direction*lengths[j]
            socket.matrix=sample['pan'];bpy.context.view_layer.update()
            if socket.name in prior_rotation and socket.rotation_quaternion.dot(prior_rotation[socket.name])<0:socket.rotation_quaternion.negate()
            prior_rotation[socket.name]=socket.rotation_quaternion.copy()
            error=max(error,max(abs(socket.matrix[i][j]-sample['pan'][i][j]) for i in range(4) for j in range(4)))
            for channel in ['location','rotation_quaternion','scale']:socket.keyframe_insert(channel,frame=frame,group=socket.name)
            bpy.context.view_layer.update()
        report[action.name]={'frames':len(samples),'pan_matrix_max_error':error,'wrist_reach_offset':wrist_offset}
        print('PANNING_ARM_FIT',action.name,error,flush=True)
    rig.animation_data.action=current;scene.frame_set(current_frame)
    for track,mute in zip(rig.animation_data.nla_tracks,mutes):track.mute=mute
    for name,matrix in review.items():rig.pose.bones[name].matrix_basis=matrix
    for m,enabled in modifiers:m.show_viewport=enabled
    bpy.context.view_layer.update()
    (OUT/'panning_arm_fit.json').write_text(json.dumps(report,indent=2))
    assert all(row['pan_matrix_max_error']<1e-5 and row['wrist_reach_offset']<.04001 for row in report.values())

def main():
    bpy.ops.wm.open_mainfile(filepath=str(STUDY/'refinement/miner_refined.blend'))
    hands();costume();panning_arms()
    scene=bpy.context.scene;scene.cycles.samples=40
    scene.camera=bpy.data.objects['Study full']
    note=bpy.data.texts.get('MINER FINISHED — READ ME') or bpy.data.texts.new('MINER FINISHED — READ ME')
    note.clear();note.write('Editable source for the integrated miner.\nContinuous CC0 anatomical hands/forearms; original rig/rest transforms; reference-textured face and hair; finished canvas, wool, cotton and boot materials.\nRebuild with blender/finish_miner.py, then blender/export_intrepid_miner.py prepare, bake, export.\nSee MINER_GAME_INTEGRATION.md for runtime validation and provenance.\n')
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/miner_finished.blend'))
    if '--no-render' in sys.argv:return
    r.previous.OUT=OUT;r.previous.render('finished',['full','back','torso'])
    # Detail view establishes wrist continuity in the retained review grip pose.
    cam=bpy.data.objects['Study torso'];target=bpy.data.objects['MinerRig'].pose.bones['LeftHand'].head
    cam.location=target+Vector((1.8,-3,.8));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.46
    r.previous.render('hands',['torso'])
    rig=bpy.data.objects['MinerRig']
    for track in rig.animation_data.nla_tracks:track.mute=True
    rig.animation_data.action=bpy.data.actions['pan_lift'];rig.animation_data.action_slot=bpy.data.actions['pan_lift'].slots[0]
    scene.frame_set(round(bpy.data.actions['pan_lift'].frame_range[1]));bpy.context.view_layer.update()
    center=(rig.pose.bones['LeftHand'].head+rig.pose.bones['RightHand'].head)*.5
    cam.location=center+Vector((.35,-2,1));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.05
    r.previous.render('hands_pan_lift',['torso'])
    print('FINISHED_MASTER_SAVED',flush=True)

if __name__=='__main__':main()
