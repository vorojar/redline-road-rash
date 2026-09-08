#!/usr/bin/env python3
"""Author original REDLINE UV paint, leather normal and roughness maps (Pillow)."""
from pathlib import Path
import random
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/textures/vehicles'
OUT.mkdir(parents=True,exist_ok=True)
FONT=str(ROOT/'assets/fonts/NotoSansSC.ttf')

def label(draw,xy,text,size,fill):
    draw.text(xy,text,font=ImageFont.truetype(FONT,size),fill=fill,anchor='mm',stroke_width=max(1,size//60),stroke_fill=fill)

def maps(name,kind):
    w,h=(1024,1024) if kind=='suit' else (512,1024) if kind=='limb' else (1024,512)
    # Alpha encodes the team-color mask; surfaces remain opaque in the material.
    base=Image.new('RGBA',(w,h),(190,192,188,0));d=ImageDraw.Draw(base)
    height=Image.new('L',(w,h),128);hd=ImageDraw.Draw(height)
    rough=Image.new('L',(w,h),145 if kind in ['suit','limb'] else 54 if kind=='helmet' else 65);rd=ImageDraw.Draw(rough)
    dark=(28,31,35,0);team=(225,230,235,255);white=(192,193,186,0);red=(173,36,31,0)
    if kind=='suit':
        for c in [256,768]:
            d.polygon([(c-205,0),(c+205,0),(c+220,1024),(c-220,1024)],fill=dark)
            d.polygon([(c-125,190),(c+125,190),(c+147,370),(c+110,860),(c-110,860),(c-147,370)],fill=team)
            d.polygon([(c-190,140),(c-120,205),(c-100,370),(c-157,390),(c-205,240)],fill=white)
            d.polygon([(c+190,140),(c+120,205),(c+100,370),(c+157,390),(c+205,240)],fill=white)
            d.rounded_rectangle((c-87,428,c+87,635),radius=20,fill=(147,154,156,0))
            label(d,(c,535),'07',153,dark)
            label(d,(c,315),'REDLINE',37,white)
            label(d,(c,719),'ROAD DIVISION',18,white)
            d.rectangle((c-118,790,c+118,811),fill=red)
            for side in [-1,1]:
                pts=[(c+side*136,366),(c+side*100,853)]
                d.line(pts,fill=(178,178,170,0),width=3);hd.line(pts,fill=146,width=3)
                for y in range(384,852,13):
                    x=c+side*int(136-(y-366)*36/487)
                    d.line((x,y,x,y+5),fill=(218,218,210,0),width=2)
            rd.rounded_rectangle((c-87,428,c+87,635),radius=20,fill=110)
            # Accordion leather at the shoulder blades and lower back.
            for y in list(range(212,285,9))+list(range(828,883,9)):
                d.line((c-95,y,c+95,y),fill=(57,63,68,0),width=4)
                hd.line((c-95,y,c+95,y),fill=150,width=4)
                rd.line((c-95,y,c+95,y),fill=185,width=4)
        # Collar and waist elastic are intentionally dark, with fine stitched ribs.
        d.rectangle((0,0,w,104),fill=dark);d.rectangle((0,900,w,h),fill=dark)
        for y in range(917,1005,9): d.line((0,y,w,y),fill=(52,55,58,0),width=2);hd.line((0,y,w,y),fill=134,width=2)
    elif kind=='limb':
        d.rectangle((0,0,w,h),fill=dark)
        d.polygon([(96,45),(390,45),(369,810),(135,810)],fill=team)
        d.polygon([(100,150),(404,55),(398,150),(105,247)],fill=white)
        d.polygon([(106,254),(398,158),(394,189),(110,286)],fill=red)
        # Sleeve markings use bars so left/right limb rotations cannot invert lettering.
        for y in [389,405,421]:d.line((193,y,317,y),fill=white,width=4)
        d.rounded_rectangle((166,548,346,717),radius=45,fill=(49,53,57,0))
        for y in range(567,700,17):
            d.line((187,y,325,y),fill=(68,72,76,0),width=5);hd.line((187,y,325,y),fill=144,width=5)
        for y in range(845,965,12):d.line((124,y,387,y),fill=(58,61,63,0),width=3);hd.line((124,y,387,y),fill=140,width=3)
    elif kind=='helmet':
        d.rectangle((0,0,w,h),fill=(33,39,47,0))
        for c in [256,768]:
            d.polygon([(c-140,0),(c-48,0),(c+127,512),(c-47,512)],fill=(219,222,218,0))
            d.polygon([(c+20,0),(c+85,0),(c+200,512),(c+145,512)],fill=team)
            d.polygon([(c-44,0),(c-22,0),(c+150,512),(c+133,512)],fill=red)
            label(d,(c,167),'R',66,white)
            label(d,(c,295),'REDLINE',23,white)
            d.rectangle((c-78,374,c+78,402),fill=dark)
    elif kind=='paint':
        d.rectangle((0,0,w,h),fill=team)
        for c in [256,768]:
            d.polygon([(c-210,70),(c+205,192),(c+185,330),(c-218,191)],fill=white)
            d.polygon([(c-215,207),(c+185,343),(c+178,369),(c-218,237)],fill=dark)
            label(d,(c,184),'R',54,dark)
            label(d,(c,410),'07',94,white)
            label(d,(c,476),'ROAD DIVISION',18,white)
    if kind in ['suit','limb']:
        # Resolved perforations and weave are maps, not high-frequency runtime noise.
        for y in range(8,h,12):
            for x in range(8+(6 if y//12%2 else 0),w,12):
                hd.ellipse((x-1,y-1,x+1,y+1),fill=123)
        # Broad creases read in the chase camera; fine grain only modulates leather.
        rng=random.Random(404 if kind=='suit' else 405)
        for _ in range(42 if kind=='suit' else 28):
            x=rng.randrange(20,w-120);y=rng.randrange(120,h-80)
            length=rng.randrange(45,110)
            points=[(x+j,y+int(5*math.sin(j/length*math.pi))) for j in range(length)]
            hd.line(points,fill=139,width=3)
            rd.line(points,fill=162,width=3)
        noise=Image.frombytes('L',(w,h),random.Random(812).randbytes(w*h)).point(lambda v:244+v//24)
        rgb=ImageChops.multiply(base.convert('RGB'),noise.convert('RGB'))
        rgb.putalpha(base.getchannel('A'));base=rgb
    gx=ImageChops.subtract(ImageChops.offset(height,-1,0),ImageChops.offset(height,1,0),offset=128).point(lambda x:max(0,min(255,128+(x-128)*2)))
    gy=ImageChops.subtract(ImageChops.offset(height,0,-1),ImageChops.offset(height,0,1),offset=128).point(lambda x:max(0,min(255,128+(x-128)*2)))
    normal=Image.merge('RGB',(gx,gy,Image.new('L',(w,h),255)))
    base.save(OUT/(name+'_albedo.png'));normal.save(OUT/(name+'_normal.png'));rough.save(OUT/(name+'_roughness.png'))
    print(name,w,h)

for name,kind in [('rider_suit','suit'),('rider_limb','limb'),('rider_helmet','helmet'),('bike_livery','paint')]:maps(name,kind)
