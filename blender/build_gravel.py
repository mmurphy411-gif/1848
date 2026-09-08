"""Seeded periodic depositional gravel: three populations, buried rims and sand."""
import numpy as np
from png_helpers import png
def build_gravel(outdir):
    n=2048; tile=1.5; rng=np.random.default_rng(184806)
    y,x=np.mgrid[:n,:n]; grain=rng.random((n,n))
    height=(grain-.5)*.0007
    # The fine damp matrix stays darker than the pale stone faces, retaining
    # local relief contrast without reintroducing near-black stones.
    color=np.stack([.51+grain*.09,.455+grain*.08,.35+grain*.09],axis=2)
    # Place coarse first and reject overlap for the medium population. Pea
    # grains occupy the remaining matrix, rather than tessellating the plane.
    occupied=np.zeros((n,n),dtype=bool)
    for lo,hi,target in [(.08,.15,.20),(.03,.08,.40),(.003,.025,.24)]:
        added=0; attempts=0
        while added<target*n*n and attempts<150000:
            attempts+=1; cx,cy=rng.integers(0,n,2)
            if occupied[cy,cx]: continue
            radius=rng.uniform(lo,hi)*.5*n/tile; r=int(radius*1.4)+2
            xx,yy=np.meshgrid(np.arange(-r,r+1),np.arange(-r,r+1))
            ix=(cx+xx)%n; iy=(cy+yy)%n
            angle=rng.uniform(0,6.283); aspect=rng.uniform(.62,1.0)
            u=(xx*np.cos(angle)+yy*np.sin(angle))/radius
            v=(-xx*np.sin(angle)+yy*np.cos(angle))/(radius*aspect)
            theta=np.arctan2(v,u)
            d=np.sqrt(u*u+v*v)*(1+.09*np.sin(theta*3+angle)+.06*np.cos(theta*5-angle))
            mask=(d<1)&~occupied[iy,ix]
            if mask.sum()<radius*radius*aspect*2.3: continue
            buried=rng.uniform(.10,.38)
            dome=np.maximum(0,1-d*d)**.65
            raised=np.maximum(0,dome-buried)*radius*tile/n*.32
            edge=np.clip((1-d)*12,0,1)*mask
            # Low-saturation Sierra stones in linear reflectance: warm grey,
            # buff/tan, quartz, and occasional dark green-grey. Encode sRGB
            # only after clamping neutral-light luminance to the ruled range.
            palette=np.array([[.76,.74,.71],[.78,.74,.66],[.81,.78,.71],[.83,.825,.805],[.67,.69,.665]])
            base=palette[rng.choice(5,p=[.40,.25,.18,.12,.05])]
            linear=base[None,None,:]*(rng.uniform(.98,1.07)+(grain[iy,ix]-.5)[:,:,None]*.045)*1.12
            luminance=linear@np.array([.2126,.7152,.0722])
            linear*=np.clip(luminance,.26,.83)[:,:,None]/luminance[:,:,None]
            stone=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
            color[iy,ix]=color[iy,ix]*(1-edge[:,:,None])+stone*edge[:,:,None]
            height[iy,ix]=np.maximum(height[iy,ix],raised*mask)
            occupied[iy,ix]|=mask; added+=mask.sum()
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*tile/n)
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*tile/n)
    normal=np.stack([-dx,dy,np.ones_like(dx)],axis=2); normal/=np.linalg.norm(normal,axis=2)[:,:,None]
    png(outdir/'gravel_albedo.png',np.clip(color*255,0,255))
    png(outdir/'gravel_normal.png',(normal*.5+.5)*255)
    png(outdir/'gravel_orm.png',np.full((n,n),232,dtype=np.uint8))
    png(outdir/'gravel_stones.png',occupied.astype(np.uint8)*255)
