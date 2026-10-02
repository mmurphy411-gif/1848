"""Experimental paper segmentation; NOT a calibrated gauntlet gate.

Preserves large leg gaps that flood filling can swallow. Ground shadows still
need explicit exclusion and visual validation before these masks can be used.
"""
from PIL import Image


def components(bits, width, height, value):
    seen=bytearray(width*height)
    for start in range(width*height):
        if seen[start] or bits[start]!=value:
            continue
        seen[start]=1; region=[start]; cursor=0; boundary=False
        while cursor<len(region):
            i=region[cursor];cursor+=1;x,y=i%width,i//width
            boundary |= x in (0,width-1) or y in (0,height-1)
            for a,b in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                j=b*width+a
                if 0<=a<width and 0<=b<height and not seen[j] and bits[j]==value:
                    seen[j]=1;region.append(j)
        yield region,boundary


def mask(image, tolerance=25, ground_fraction=.08, ground_tolerance=55):
    image=image.convert("RGB");w,h=image.size;pixels=list(image.getdata())
    border=[pixels[y*w+x] for y in range(h) for x in (0,w-1)]
    paper=tuple(sorted(p[c] for p in border)[len(border)//2] for c in range(3))
    bits=bytearray(w*h)
    for i,p in enumerate(pixels):
        t=ground_tolerance if i//w>=h*(1-ground_fraction) else tolerance
        bits[i]=int(max(abs(p[c]-paper[c]) for c in range(3))>t)
    # Only enclosed small white markings are filled; a large leg gap is not fur.
    for region,boundary in components(bits,w,h,0):
        if not boundary and len(region)<w*h*.025:
            for i in region:bits[i]=1
    regions=list(components(bits,w,h,1))
    if not regions:raise ValueError("Empty land-animal mask")
    region=max(regions,key=lambda item:len(item[0]))[0]
    result=bytearray(w*h)
    for i in region:result[i]=255
    return Image.frombytes("L",(w,h),bytes(result))
