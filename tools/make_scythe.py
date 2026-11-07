"""Draws art/fx/scythe.png, the blade of the Scythe spell: a shaft with a curved blade hooking down at its end. Run from the project folder."""
from PIL import Image, ImageDraw
import math
W,H=88,64
def bez(p0,p1,p2,p3,n=40):
    out=[]
    for i in range(n+1):
        t=i/n
        a=(1-t)**3; b=3*(1-t)**2*t; c=3*(1-t)*t*t; d=t**3
        out.append((a*p0[0]+b*p1[0]+c*p2[0]+d*p3[0], a*p0[1]+b*p1[1]+c*p2[1]+d*p3[1]))
    return out
im=Image.new("RGBA",(W,H),(0,0,0,0))
d=ImageDraw.Draw(im)
# shaft along y=30, from the hand at the left to the blade
d.rectangle([0,29,66,31],fill=(200,200,210,255))
d.rectangle([0,29,66,29],fill=(235,235,245,255))
for x in (6,7,8,9):  # a wrapped grip
    d.line([x,28,x,32],fill=(150,150,165,255))
# the blade: out from the end of the shaft, down and round, curling back to a point
outer=bez((64,27),(92,22),(94,52),(58,62))
inner=bez((58,62),(78,52),(78,36),(66,34))
poly=outer+inner
d.polygon(poly,fill=(255,255,255,255))
# the edge along the inside of the curve, a little brighter at the point
d.line(inner,fill=(255,255,255,255),width=1)
# a socket where the blade meets the shaft
d.rectangle([62,26,67,34],fill=(170,170,185,255))
im.save("art/fx/scythe.png")
