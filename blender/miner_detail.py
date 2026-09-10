"""Authored anatomical and tailoring detail, in the miner's rest coordinates.

Uses the existing skin weights and material slots so every baked action shares
the same body. Dimensions are meters; -Y faces the camera, Z is up.
"""
import math
from mathutils import Vector


def detail(loft, verts, faces, uvs, slots, weights, shirt_weight):
    def ellipsoid(name, center, scale, slot, bone='Head', sides=16, rings=9):
        points=[]; radii=[]; depths=[]
        for j in range(rings):
            a=math.pi*(.015+.97*j/(rings-1))
            points.append((center[0],center[1],center[2]-scale[2]*math.cos(a)))
            radii.append(scale[0]*math.sin(a));depths.append(scale[1]*math.sin(a))
        loft(name,points,radii,depths,slot,bone,sides)

    # Continuous head surface: jaw, cheek, temple and cranium profiles. Facial
    # planes displace this surface rather than stacking a nose on a sphere.
    profile=[(1.475,.033,.033),(1.49,.054,.048),(1.51,.070,.059),
             (1.53,.079,.066),(1.55,.087,.072),(1.575,.092,.080),
             (1.60,.089,.080),(1.625,.087,.079),(1.65,.086,.081),
             (1.675,.072,.071),(1.693,.045,.050),(1.703,.009,.016)]
    profile=[tuple(a[k]+(b[k]-a[k])*t/3 for k in range(3))
             for a,b in zip(profile,profile[1:]) for t in range(3)]+[profile[-1]]
    first=len(verts)
    loft('Sculpted head',[(0,.002,z) for z,_,_ in profile],
         [r for _,r,_ in profile],[d for _,_,d in profile],3,'Head',44)
    def gaussian(x,z,cx,cz,sx,sz):
        return math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
    for i in range(first,len(verts)):
        p=verts[i]
        if p.y>=0:continue
        front=max(0,-p.y/.08)**2
        bridge=.029*gaussian(p.x,p.z,0,1.602,.020,.035)
        tip=.019*gaussian(p.x,p.z,0,1.581,.025,.018)
        tip+=sum(.012*gaussian(p.x,p.z,s*.017,1.581,.012,.009) for s in [-1,1])
        brow=sum(.008*gaussian(p.x,p.z,s*.039,1.630,.032,.010) for s in [-1,1])
        sockets=sum(.011*gaussian(p.x,p.z,s*.035,1.616,.024,.011) for s in [-1,1])
        muzzle=.009*gaussian(p.x,p.z,0,1.55,.038,.018)
        p.y-=(bridge+tip+brow+muzzle-sockets)*front
    # Soft nasal wings, ears with inset conchae, inset eyes and eyelid margins.
    for s in [-1,1]:
        ellipsoid('Ear',(s*.091,.002,1.592),(.017,.012,.030),3)
        ellipsoid('Ear concha',(s*.103,-.008,1.591),(.006,.003,.014),2,sides=12,rings=6)
        ellipsoid('Inset eye',(s*.036,-.0735,1.616),(.015,.006,.0055),8,sides=16,rings=7)
        ellipsoid('Iris',(s*.035,-.079,1.616),(.004,.0015,.004),5,sides=12,rings=7)
        for upper in [True,False]:
            points=[(s*.036+.015*math.cos(a),-.077,1.616+(.006 if upper else -.0045)*math.sin(a)) for a in [i*math.pi/8 for i in range(9)]]
            loft('Eyelid',points,[.0025]*9,[.002]*9,3,'Head',8)
        points=[(s*(.017+i*.009),-.078+i*.002,1.632+.003*math.sin(i*.8)) for i in range(5)]
        loft('Brow',points,[.002,.0038,.004,.003,.001],[.0025]*5,5,'Head',8)
    # A narrow mouth between the moustache and chin; no solid beard mask across
    # the cheeks or eyes. Individual overlapping locks establish the silhouette.
    ellipsoid('Lower lip',(0,-.079,1.549),(.023,.006,.004),3,sides=20,rings=7)
    loft('Mouth seam',[(-.024,-.080,1.553),(0,-.084,1.552),(.023,-.080,1.553)],
         [.0015]*3,[.001]*3,5,'Head',8)
    base=len(verts);columns=49;rows=10
    for j in range(rows):
        t=j/(rows-1)
        for i in range(columns):
            a=-1.5+i*3/(columns-1)
            top=1.539+.065*abs(math.sin(a))**1.8
            bottom=1.452+.042*abs(math.sin(a))+.003*math.sin(i*2.4)
            relief=.0017*math.sin(a*47+t*2)+.001*math.sin(a*81-t*3)
            x=(.096-.053*t*t)*math.sin(a)
            y=-(.082+.014*math.sin(t*math.pi)-.017*t+relief)*math.cos(a)
            verts.append(Vector((x,y,top*(1-t)+bottom*t)))
            uvs.append((i/(columns-1),1-t));weights.append({'Head':1})
    for j in range(rows-1):
        for i in range(columns-1):
            a=base+j*columns+i;faces.append((a,a+columns,a+1+columns,a+1));slots.append(5)
    for s in [-1,1]:
        loft('Moustache',[(s*.003,-.093,1.568),(s*.017,-.091,1.563),(s*.032,-.082,1.557)],
             [.004,.006,.002],[.004,.005,.001],5,'Head',10)

    # Placket, collar and small dark buttons provide cloth construction cues.
    loft('Shirt placket',[(0,-.145,1.01),(0,-.151,1.15),(0,-.154,1.29),(0,-.129,1.38)],
         [.011]*4,[.003]*4,0,shirt_weight,8)
    for s in [-1,1]:
        base=len(verts)
        pts=[(s*.018,-.066,1.451),(s*.070,-.073,1.43),
             (s*.088,-.128,1.388),(s*.037,-.134,1.373)]
        verts.extend(Vector(p) for p in pts);uvs.extend([(.05,.46),(.08,.46),(.08,.40),(.05,.4)])
        weights.extend([{'Chest':1}]*4)
        faces.append(tuple(base+j for j in ([3,2,1,0] if s>0 else [0,1,2,3])));slots.append(0)
    for z,y in [(1.08,-.144),(1.18,-.154),(1.28,-.155),(1.35,-.140)]:
        ellipsoid('Horn button',(0,y-.004,z),(.004,.003,.004),7,shirt_weight,10,6)
    # Built leather soles and heel layers, with a welt separate from the upper.
    for s in [-1,1]:
        for z,r,d in [(.019,.078,.137),(.034,.079,.140)]:
            loft('Boot welt',[(s*.11,-.075,z-.004),(s*.11,-.075,z+.004)],
                 [r,r],[d,d],7,('Left' if s>0 else 'Right')+'Foot',32)
        side='Left' if s>0 else 'Right'
        # Nails sit on the back of each fingertip and inherit distal motion.
        for f,label in enumerate(['Index','Middle','Ring','Little'],1):
            x=s*(.45+.018+f*.01+.008)
            y=-.015-.035+f*.017
            ellipsoid('Fingernail',(x+s*.006,y,.765-.07-.0246-.0314-.023),
                      (.0035,.0055,.008),8,side+label+'Distal',8,6)
