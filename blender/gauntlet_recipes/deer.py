"""From-scratch black-tailed buck, authored in metres, +Y forward, Z up.

No previous deer mesh is loaded or sampled. Parameters reconstruct the same
semantic parts, making changes reproducible instead of vertex-index dependent.
"""
import math
import bpy
from mathutils import Vector


def mesh(name, vertices, faces):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    for face in data.polygons:
        face.use_smooth = True
    return obj


def ellipsoid(name, center, radii, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def tube(name, points, radii, sides=12, subdivisions=5):
    controls = [Vector(p) for p in points]
    smooth, widths = [], []
    for i in range(len(controls)-1):
        a,b,c,d = [controls[max(0,min(len(controls)-1,j))] for j in (i-1,i,i+1,i+2)]
        for k in range(subdivisions):
            t = k/subdivisions
            smooth.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
            widths.append(radii[i]*(1-t)+radii[i+1]*t)
    smooth.append(controls[-1]); widths.append(radii[-1])
    vertices, faces = [], []
    for i,point in enumerate(smooth):
        tangent = (smooth[min(i+1,len(smooth)-1)]-smooth[max(0,i-1)]).normalized()
        u = Vector((1,0,0)) if abs(tangent.x)<.85 else Vector((0,1,0))
        u = (u-tangent*u.dot(tangent)).normalized()
        v = tangent.cross(u)
        for k in range(sides):
            vertices.append(point + widths[i]*(u*math.cos(k*math.tau/sides)+v*math.sin(k*math.tau/sides)))
    for i in range(len(smooth)-1):
        for k in range(sides):
            a=i*sides+k; b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces += [tuple(reversed(range(sides))), tuple((len(smooth)-1)*sides+k for k in range(sides))]
    return mesh(name, vertices, faces)


def merge_sculpt(parts, name, voxel, triangles, protect_anatomy=False):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = parts[0]; obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.remesh_voxel_size = voxel
    bpy.ops.object.voxel_remesh()
    mod = obj.modifiers.new("Relax merged anatomy", "SMOOTH")
    mod.factor=.65; mod.iterations=12
    bpy.ops.object.modifier_apply(modifier=mod.name)
    count = sum(len(p.vertices)-2 for p in obj.data.polygons)
    if count > triangles:
        mod=obj.modifiers.new("Source topology budget", "DECIMATE");mod.ratio=triangles/count
        if protect_anatomy:
            group=obj.vertex_groups.new(name="Anatomical density")
            for v in obj.data.vertices:
                group.add([v.index],.30 if v.co.z>1.43 else .5 if v.co.z<.80 else 1.0,"REPLACE")
            mod.vertex_group=group.name;mod.vertex_group_factor=.5
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons: face.use_smooth=True
    obj["gauntlet_id"] = name
    return obj


def material(name, roughness):
    mat = bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes; links=mat.node_tree.links
    shader=nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value=roughness
    color=nodes.new("ShaderNodeVertexColor");color.layer_name="Coat"
    links.new(color.outputs["Color"],shader.inputs["Base Color"])
    return mat


def colors(obj, mat, color):
    obj.data.materials.clear();obj.data.materials.append(mat)
    attr=obj.data.color_attributes.get("Coat") or obj.data.color_attributes.new(name="Coat",type="FLOAT_COLOR",domain="CORNER")
    for loop in obj.data.loops:
        point=obj.matrix_world@obj.data.vertices[loop.vertex_index].co
        rgb=color(point) if callable(color) else color
        attr.data[loop.index].color=(*rgb,1)


def ear(name, sign, p, inset=False):
    base=Vector((sign*.085,.66,1.735)); tip=Vector((sign*p["ear_spread"],.575,1.935))
    axis=tip-base; horizontal=Vector((sign*.30,0,-.34)).normalized()
    if p["anatomy_version"]>=9:
        tip=Vector((sign*.30,.525,1.96));axis=tip-base
        horizontal=Vector((sign*.22,.27,-.07))
        horizontal=(horizontal-axis.normalized()*horizontal.dot(axis.normalized())).normalized()
    if p["anatomy_version"]>=11:
        tip=Vector((sign*.33,.55,1.935));axis=tip-base
        horizontal=Vector((sign*.30,.12,-.28))
        horizontal=(horizontal-axis.normalized()*horizontal.dot(axis.normalized())).normalized()
    rings=12; sides=12; vertices=[];faces=[]
    for i in range(rings+1):
        t=i/rings
        width=(math.sin(math.pi*t)**.85)*(.075 if not inset else .057)
        center=base+axis*t
        for k in range(sides):
            a=k*math.tau/sides
            # Front-facing hollow leaf, not a solid oval glued to the skull.
            depth=(.012 if not inset else .005)*math.sin(a)
            cup=(.035*math.cos(a)**2-.012) if p.get("anatomy_version",1)>=4 else .026
            point=center+horizontal*width*math.cos(a)+Vector((0,depth+cup*math.sin(math.pi*t),0))
            if inset: point.y+=.010
            vertices.append(point)
    for i in range(rings):
        for k in range(sides):
            a=i*sides+k;b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    return mesh(name, vertices, faces)


def hoof(name, x, y, mat):
    vertices=[]
    for z,w,back,front in [(0,.023,-.045,.085),(.074,.018,-.03,.033)]:
        vertices.extend([(x-w,y+back,z),(x+w,y+back,z),(x+w,y+front,z),(x-w,y+front,z)])
    obj=mesh(name,vertices,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    colors(obj,mat,(.025,.022,.018))
    bpy.ops.object.select_all(action="DESELECT");obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bevel=obj.modifiers.new("Rounded hoof wall", "BEVEL");bevel.width=.004;bevel.segments=2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def loft(name, sections, axis="Y", sides=32, subdivisions=5):
    """Section tuples: axial coordinate, other center, half-width, half-height."""
    controls=[Vector(s) for s in sections]; rings=[]
    for i in range(len(controls)-1):
        a,b,c,d=[controls[max(0,min(len(controls)-1,j))] for j in (i-1,i,i+1,i+2)]
        for k in range(subdivisions):
            t=k/subdivisions
            rings.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    rings.append(controls[-1]);vertices=[];faces=[]
    for axial,center,width,height in rings:
        for k in range(sides):
            a=k*math.tau/sides
            x=max(.001,width)*math.cos(a); offset=max(.001,height)*math.sin(a)
            vertices.append((x,axial,center+offset) if axis=="Y" else (x,center+offset,axial))
    for i in range(len(rings)-1):
        for k in range(sides):
            a=i*sides+k;b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.extend([tuple(reversed(range(sides))),tuple((len(rings)-1)*sides+k for k in range(sides))])
    return mesh(name,vertices,faces)


def seated_eye(sign, coat, dark, version=5):
    graph=bpy.context.evaluated_depsgraph_get()
    vertices=[];faces=[];sides=20
    if version>=12:
        hit,eye_center,_,_,_,_=bpy.context.scene.ray_cast(graph,Vector((sign*.5,.787,1.641)),Vector((-sign,0,0)),distance=1)
        if not hit:raise ValueError("Eye center missed skull")
        eye_normal=Vector((sign*.9,.4,.07)).normalized()
        eye_u=Vector((0,1,0));eye_u=(eye_u-eye_normal*eye_u.dot(eye_normal)).normalized()
        eye_v=eye_normal.cross(eye_u)*sign
    for ring in (0,.45,1.0,1.24):
        for k in range(sides):
            a=k*math.tau/sides
            y=.787+.024*ring*math.cos(a)
            z=1.641+(.019 if version>=11 else .0135)*ring*math.sin(a)*(.55+.45*abs(math.sin(a)))
            hit,point,normal,index,obj,matrix=bpy.context.scene.ray_cast(graph,Vector((sign*.5,y,z)),Vector((-sign,0,0)),distance=1)
            if not hit:raise ValueError("Eye surface sample missed skull")
            bulge=.001+(.012 if version>=9 else .004)*max(0,1-ring*ring)
            if ring>1:bulge=.003 if version>=9 else .001
            if version>=12 and ring<=1:
                vertices.append(eye_center+eye_u*(.024*ring*math.cos(a))+
                                eye_v*(.018*ring*math.sin(a))+
                                eye_normal*(.001+.012*math.sqrt(max(0,1-ring*ring))))
            else:
                vertices.append(point+normal*bulge)
    for i in range(3):
        for k in range(sides):
            a=i*sides+k;b=i*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides))
    eye=mesh(f"Eye {sign}",vertices,faces)
    eye.data.materials.append(dark);eye.data.materials.append(coat)
    attr=eye.data.color_attributes.new(name="Coat",type="FLOAT_COLOR",domain="CORNER")
    for face in eye.data.polygons:
        face.material_index=1 if face.index>=2*sides else 0
        for loop_index in face.loop_indices:
            index=eye.data.loops[loop_index].vertex_index
            color=(.18,.092,.043) if index>=3*sides else (.028,.015,.006) if index>=sides else (.005,.003,.002)
            if version>=12 and index>=3*sides:color=(.34,.25,.15)
            attr.data[loop_index].color=(*color,1)
    return eye


def build(settings):
    p={"body_depth":1.0,"body_width":1.0,"body_length":1.0,"neck_width":1.0,
       "head_scale":1.0,"muzzle_length":1.0,"ear_spread":.34,"leg_width":1.0,
       "antler_spread":1.0,"antler_height":1.0,"body_triangles":7400,"antler_triangles":900,
       "coat_detail":False,"anatomy_version":1,"head_raise":0,"antler_sweep":0,
       "muzzle_shorten":0,"foreleg_spacing":1,"thigh_fullness":0,**settings}
    # Only geometry is cleared. The gauntlet owns the fixed review cameras/lights.
    for obj in list(bpy.context.scene.objects):
        if obj.type not in {"CAMERA","LIGHT"}: bpy.data.objects.remove(obj,do_unlink=True)
    coat=material("Buck coat",.83);dark=material("Buck eyes nose and hooves",.65 if p["anatomy_version"]>=6 else .35)
    if p["anatomy_version"]>=6:
        dark.node_tree.nodes.get("Principled BSDF").inputs["Specular IOR Level"].default_value=.10
    if p["anatomy_version"]>=9:
        shader=dark.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Roughness"].default_value=.36
        shader.inputs["Specular IOR Level"].default_value=.25
    anatomy=[]
    def ell(name, c, r):
        obj=ellipsoid(name,c,r);anatomy.append(obj);return obj
    ell("Rib barrel",(0,-.04,1.04),(.235*p["body_width"],.57*p["body_length"],.275*p["body_depth"]))
    ell("Shoulder blades",(0,.405,1.095),(.22,.25,.31))
    ell("Rump",(0,-.445,1.055),(.245,.25,.28))
    ell("Brisket",(0,.45,.955),(.17,.24,.235))
    # Elliptical neck sections overlap generously before voxel union.
    for i,(y,z,rx,ry,rz) in enumerate([(.46,1.24,.18,.23,.27),(.555,1.41,.14,.18,.26),(.645,1.555,.106,.139,.19)]):
        ell(f"Neck {i}",(0,y,z),(rx*p["neck_width"],ry*p["neck_width"],rz))
    hs=p["head_scale"]
    ell("Cranium",(0,.705,1.652),(.113*hs,.137*hs,.148*hs))
    ell("Cheeks",(0,.766,1.56),(.113*hs,.12*hs,.092*hs))
    ell("Nasal bridge",(0,.891,1.555),(.073*hs,.176*p["muzzle_length"],.072*hs))
    ell("Mandible",(0,.866,1.497),(.077*hs,.145*p["muzzle_length"],.047*hs))
    if p["anatomy_version"]>=2:
        for obj in anatomy: bpy.data.objects.remove(obj,do_unlink=True)
        anatomy=[]
        anatomy.append(loft("Continuous trunk",[
            (-.715,1.04,.018,.085),(-.62,1.035,.17,.22),(-.45,1.045,.23,.27),
            (-.15,1.035,.232,.26),(.18,1.045,.22,.255),(.39,1.035,.208,.28),
            (.53,1.05,.155,.23),(.625,1.02,.065,.13),(.65,1.02,.01,.045)]))
        anatomy.append(loft("Continuous neck",[
            (1.03,.425,.135,.17),(1.18,.465,.16,.205),(1.36,.535,.141,.185),
            (1.52,.625,.108,.13),(1.635,.675,.082,.095),(1.715,.665,.05,.055)],axis="Z"))
        anatomy.append(loft("Tapered skull and muzzle",[
            (.585,1.65,.025,.055),(.65,1.65,.096,.112),(.735,1.623,.11,.105),
            (.80,1.588,.084,.080),(.875,1.55,.063,.060),(.955,1.511,.056,.048),
            (1.035,1.498,.052,.033),(1.06,1.5,.024,.022)]))
    if p["anatomy_version"]>=3:
        bpy.data.objects.remove(anatomy[0],do_unlink=True)
        anatomy[0]=loft("Continuous trunk",[
            (-.70,1.10,.018,.07),(-.62,1.105,.155,.21),(-.45,1.12,.224,.225),
            (-.15,1.105,.224,.245),(.18,1.12,.21,.23),(.38,1.10,.196,.255),
            (.52,1.11,.143,.21),(.61,1.075,.063,.10),(.64,1.06,.01,.035)])
    if p["anatomy_version"]>=5 and p.get("shaped_torso",True):
        for obj in anatomy[:2]:bpy.data.objects.remove(obj,do_unlink=True)
        anatomy[0]=loft("Shaped chest barrel and croup",[
            (-.70,1.13,.015,.06),(-.61,1.18,.15,.16),(-.43,1.165,.225,.195),
            (-.15,1.10,.218,.21),(.14,1.105,.21,.225),(.35,1.115,.198,.255),
            (.51,1.105,.145,.22),(.60,1.09,.06,.12),(.63,1.10,.01,.04)])
        anatomy[1]=loft("Withers blending into neck",[
            (1.08,.36,.125,.23),(1.24,.42,.165,.27),(1.39,.54,.137,.185),
            (1.54,.635,.105,.13),(1.645,.675,.083,.095),(1.715,.665,.05,.055)],axis="Z")
    if p["anatomy_version"]>=6:
        bpy.data.objects.remove(anatomy[2],do_unlink=True)
        anatomy[2]=loft("Adult deer skull",[
            (.585,1.65,.025,.055),(.65,1.645,.105,.13),(.735,1.61,.127,.11),
            (.80,1.575,.096,.09),(.85,1.55,.071,.073),(.925,1.52,.055,.054),
            (1.03,1.506,.05,.038),(1.06,1.50,.023,.021)])
    if p["anatomy_version"]>=8:
        for obj in anatomy[:2]:bpy.data.objects.remove(obj,do_unlink=True)
        anatomy[0]=loft("Chest abdomen and muscular croup",[
            (-.70,1.16,.018,.065),(-.62,1.17,.16,.155),(-.45,1.17,.235,.185),
            (-.25,1.135,.225,.20),(-.04,1.09,.224,.23),(.18,1.075,.218,.26),
            (.37,1.085,.20,.265),(.52,1.105,.143,.21),(.61,1.10,.055,.12),(.64,1.10,.01,.035)])
        anatomy[1]=loft("Flowing withers and neck",[
            (1.05,.365,.125,.225),(1.20,.375,.164,.28),(1.30,.405,.158,.285),
            (1.40,.535,.138,.18),(1.53,.63,.108,.13),(1.645,.675,.083,.095),
            (1.715,.665,.05,.055)],axis="Z")
    feet=[]
    for sign in [-1,1]:
        if p["anatomy_version"]>=10:
            ell(f"Scapula and upper forelimb {sign}",(sign*.155,.32,1.045),(.09,.175,.22))
        shift=.04*sign
        for kind,pts,radii in [
            ("Fore",[(sign*.145,.415+shift,1.14),(sign*.158,.39+shift,.78),(sign*.173,.442+shift,.455),(sign*.179,.474+shift,.18),(sign*.18,.487+shift,.064)],[.078,.053,.036,.025,.029]),
            ("Hind",[(sign*.15,-.45,1.11),(sign*.185,-.285+shift,.735),(sign*.20,-.51+shift,.43),(sign*.205,-.555+shift,.17),(sign*.208,-.60+shift,.064)],[.10,.077,.035,.025,.029])]:
            if p["anatomy_version"]>=5:
                pts[0]=(sign*.10,pts[0][1],1.165)
                if kind=="Hind":radii[0]=.115
            if p["anatomy_version"]>=7:
                if kind=="Fore":
                    shift=.065*sign
                    pts=[(sign*.10,.415+shift,1.165),(sign*.158,.39+shift,.78),
                         (sign*.172,.435+shift,.53),(sign*.174,.445+shift,.44),
                         (sign*.177,.455+shift,.35),(sign*.18,.48+shift,.14),(sign*.18,.49+shift,.064)]
                    radii=[.078,.053,.034,.041,.028,.024,.029]
                elif sign==-1:
                    pts=[(sign*.10,-.45,1.165),(sign*.18,-.27,.69),(sign*.20,-.535,.35),
                         (sign*.208,-.59,.15),(sign*.208,-.64,.064)]
                    radii=[.115,.083,.04,.025,.029]
                else:
                    pts=[(sign*.10,-.45,1.165),(sign*.175,-.22,.69),(sign*.198,-.335,.35),
                         (sign*.205,-.27,.15),(sign*.208,-.225,.064)]
                    radii=[.115,.079,.037,.025,.029]
            if p["anatomy_version"]>=8 and kind=="Hind":
                hock_y=-.57 if sign==-1 else -.40
                foot_y=-.64 if sign==-1 else -.225
                pts=[(sign*.10,-.46,1.165),(sign*.18,-.325,.88),
                     (sign*.195,hock_y+.065,.60),(sign*.202,hock_y,.49),
                     (sign*.205,hock_y+(foot_y-hock_y)*.45,.30),
                     (sign*.208,foot_y,.064)]
                radii=[.13,.094,.052,.036,.025,.029]
            if p["anatomy_version"]>=10 and kind=="Fore":
                pts.insert(-1,(sign*.18,.482+shift,.108))
                radii.insert(-1,.032)
            anatomy.append(tube(f"{kind} limb {sign}",pts,[r*p["leg_width"] for r in radii]))
            feet.append((kind,sign,pts[-1][0],pts[-1][1]))
        anatomy.append(ear(f"Ear outer {sign}",sign,p))
        if p["anatomy_version"]>=4:
            ell(f"Antler pedicle {sign}",(sign*.073,.665,1.759),(.032,.036,.027))
    body=merge_sculpt(anatomy,"Buck anatomy",.010,p["body_triangles"],p["anatomy_version"]>=5)
    if p["anatomy_version"]>=5:
        for vertex in body.data.vertices:
            q=vertex.co
            if p["anatomy_version"]>=10:
                q.z+=.035*math.exp(-(q.x/.10)**2-((q.y-.30)/.28)**2-((q.z-.82)/.07)**2)
            r2=((q.y-.787)/.028)**2+((q.z-1.641)/.025)**2
            q.x+=(-1 if q.x<0 else 1)*(-.006*math.exp(-r2*1.4)+.004*math.exp(-((math.sqrt(r2)-1.4)/.4)**2))
        body.data.update()
    def body_color(q):
        x,y,z=q
        color=(.255,.139,.062)
        if z>1.18: color=(.205,.111,.054)
        if z<.82 and -.5<y<.40: color=(.37,.285,.18)
        if z<.38: color=(.25,.19,.115)
        # Cream throat, chin and ventral rump markings live on surface geometry.
        neck_front=.49+(z-1.20)*.65
        if 1.16<z<1.515 and y>neck_front+.105 and abs(x)<.105: color=(.57,.49,.36)
        if y>.835 and z<1.495 and z>1.43: color=(.60,.53,.41)
        if y<-.63 and .91<z<1.23 and abs(x)<.14: color=(.65,.59,.47)
        if p["anatomy_version"]>=2:
            def smooth(a,b,v):
                t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
            color=Vector((.24,.135,.068)).lerp(Vector((.165,.09,.043)),smooth(1.10,1.36,z))
            cream=Vector((.57,.48,.35))
            throat=(1-smooth(.065,.13,abs(x)))*smooth(1.13,1.28,z)*(1-smooth(1.52,1.56,z))*smooth(.01,.07,y-(.46+(z-1.18)*.66))
            chin=smooth(.78,.90,y)*(1-smooth(1.46,1.50,z))*smooth(1.40,1.45,z)
            if p["anatomy_version"]>=6:
                chin=smooth(.78,.90,y)*(1-smooth(1.77-.315*y,1.785-.315*y,z))*smooth(1.40,1.45,z)
                throat*=1-smooth(.02,.10,abs(x))
            belly=(1-smooth(.80,.88,z))*smooth(-.61,-.4,y)*(1-smooth(.33,.5,y))*smooth(.66,.77,z)
            if p["anatomy_version"]>=10:
                belly*=1-smooth(.075,.14,abs(x))
            rump=(1-smooth(-.70,-.625,y))*(1-smooth(.08,.145,abs(x)))*smooth(.86,.96,z)*(1-smooth(1.17,1.23,z))
            color=color.lerp(cream,max(throat,chin,belly,rump))
            return tuple(color)
        return color
    colors(body,coat,body_color)
    for kind,sign,x,y in feet:
        for toe in [-1,1]: hoof(f"{kind} hoof {sign} {toe}",x+toe*.026,y,dark)
    for sign in [-1,1]:
        inside=ear(f"Ear inner {sign}",sign,p,True); colors(inside,coat,(.37,.285,.20))
        # Sample the actual merged head surface for eye seating.
        graph=bpy.context.evaluated_depsgraph_get()
        hit,point,normal,index,obj,matrix=bpy.context.scene.ray_cast(graph,Vector((sign*.5,.787,1.641)),Vector((-sign,0,0)),distance=1)
        if not hit: raise ValueError("No cheek surface for the eye")
        if p["anatomy_version"]>=5:
            seated_eye(sign,coat,dark,p["anatomy_version"])
        else:
            eye=ellipsoid(f"Eye {sign}",point+normal*.001,(.006,.022,.014) if p["anatomy_version"]>=3 else (.006,.018,.010),20,12)
            colors(eye,dark,(.013,.009,.005))
        if 3<=p["anatomy_version"]<5:
            # A narrow arched lid, sampled on the cheek, replaces a floating bead.
            lid_points=[]
            for dy,dz in [(-.025,0),(-.015,.012),(0,.017),(.014,.012),(.025,-.003)]:
                hit,lp,ln,idx,found,m=bpy.context.scene.ray_cast(graph,Vector((sign*.5,.787+dy,1.641+dz)),Vector((-sign,0,0)),distance=1)
                if hit: lid_points.append(lp+ln*.002)
            if len(lid_points)==5:
                lid=tube(f"Upper eyelid {sign}",lid_points,[.0015,.0025,.003,.0025,.0015],6,3)
                colors(lid,coat,(.15,.085,.039))
        # Continuous antler beam plus true branches, tapered to distinct tips.
        def signed(pts):
            return [(sign*x*p["antler_spread"],y-p["antler_sweep"]*(z-1.75)/.45,1.75+(z-1.75)*p["antler_height"]) for x,y,z in pts]
        branches=[tube("Beam",signed([(.073,.665,1.755),(.09,.635,1.85),(.155,.59,1.93),(.225,.555,2.04),(.252,.57,2.16)]),[.026,.026,.022,.013,.0018],10),
                  tube("Brow",signed([(.10,.62,1.865),(.115,.73,1.93),(.13,.765,1.995)]),[.017,.011,.0015],9),
                  tube("Fork",signed([(.16,.59,1.945),(.175,.62,2.07),(.175,.665,2.185)]),[.016,.010,.0015],9),
                  tube("Outer tine",signed([(.211,.56,2.015),(.30,.585,2.08),(.355,.635,2.135)]),[.012,.008,.0015],9)]
        antler=merge_sculpt(branches,f"Buck antler {sign}",.0055,p["antler_triangles"])
        colors(antler,coat,lambda q:(.26+.12*max(0,q.z-1.8),.17+.12*max(0,q.z-1.8),.09+.1*max(0,q.z-1.8)))
    nose_center=(0,1.052,1.504) if p["anatomy_version"]>=2 else (0,1.045,1.52)
    nose=ellipsoid("Nose",nose_center,(.048,.022,.025),20,12);colors(nose,dark,(.026,.022,.018))
    if p["anatomy_version"]>=11:
        for vertex in nose.data.vertices:
            # Narrow the lower nose into the cleft above the upper lip.
            vertex.co.x*=.78+.22*max(0,min(1,(vertex.co.z+.012)/.022))
        for sign in [-1,1]:
            cutter=ellipsoid("Temporary nostril cutter",(sign*.034,1.07,1.513),(.014,.012,.009),16,12)
            bpy.context.view_layer.objects.active=nose
            modifier=nose.modifiers.new("Recessed nostril", "BOOLEAN")
            modifier.operation="DIFFERENCE";modifier.solver="EXACT";modifier.object=cutter
            bpy.ops.object.modifier_apply(modifier=modifier.name)
            bpy.data.objects.remove(cutter,do_unlink=True)
        colors(nose,dark,(.026,.022,.018))
    if p["anatomy_version"]<6:
        for sign in [-1,1]:
            nostril=ellipsoid(f"Nostril {sign}",(sign*.027,1.071,1.511),(.009,.002,.006),12,8);colors(nostril,dark,(.003,.002,.001))
        mouth=tube("Mouth crease",[(-.066,1.005,1.475),(-.04,1.057,1.48),(0,1.067,1.48),(.04,1.057,1.48),(.066,1.005,1.475)],[.0025]*5,6)
        colors(mouth,dark,(.036,.025,.015))
    else:
        for sign in [-1,1]:
            points=[]
            for y in [.87,.89,.915,.94,.965,.99,1.025]:
                z=1.49-.065*(y-.86)
                hit,q,n,index,obj,matrix=bpy.context.scene.ray_cast(bpy.context.evaluated_depsgraph_get(),Vector((sign*.5,y,z)),Vector((-sign,0,0)),distance=1)
                if hit:points.append(q+n*.0005)
            if len(points)>2:
                mouth=tube(f"Seated mouth crease {sign}",points,[.001]*len(points),5,3)
                colors(mouth,dark,(.035,.020,.01))
    tail=tube("Black tail",[(0,-.636,1.205),(0,-.708,1.05),(0,-.735,.90),(0,-.722,.865)],[.06,.064,.037,.003],14)
    colors(tail,coat,lambda q:(.028,.023,.017) if q.y<-.70 else (.57,.50,.38))
    if p["head_raise"] or p["muzzle_shorten"] or p["foreleg_spacing"]!=1 or p["thigh_fullness"]:
        # Apply the same continuous neck/head offset to every anatomical feature.
        for obj in [o for o in bpy.context.scene.objects if o.type=="MESH"]:
            transform=obj.matrix_world.copy();inverse=transform.inverted()
            for vertex in obj.data.vertices:
                q=transform@vertex.co
                def smooth(a,b,v):
                    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
                q.y-=p["muzzle_shorten"]*max(0,q.y-.78)*smooth(1.40,1.48,q.z)
                q.x*=1-(1-p["foreleg_spacing"])*smooth(.1,.3,q.y)*(1-smooth(.75,1.0,q.z))
                thigh=math.exp(-((abs(q.x)-.17)/.12)**2-((q.y+.32)/.19)**2-((q.z-.82)/.20)**2)
                q.x+=(-1 if q.x<0 else 1)*p["thigh_fullness"]*.012*thigh
                t=max(0,min(1,(q.z-1.30)/.34));q.z+=p["head_raise"]*t*t*(3-2*t)
                vertex.co=inverse@q
            obj.data.update()
    if p["coat_detail"]:
        nodes=coat.node_tree.nodes;links=coat.node_tree.links
        noise=nodes.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=190
        bump=nodes.new("ShaderNodeBump");bump.inputs["Strength"].default_value=.20;bump.inputs["Distance"].default_value=.002
        links.new(noise.outputs["Fac"],bump.inputs["Height"])
        links.new(bump.outputs["Normal"],nodes.get("Principled BSDF").inputs["Normal"])
    bpy.context.scene["construction"]="from scratch: parametric deer, no prior geometry"
    bpy.context.scene["construction_parameters"]=str(p)
