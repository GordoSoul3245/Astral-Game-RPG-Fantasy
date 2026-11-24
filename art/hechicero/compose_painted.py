"""Assemble the painted Krita atlas at native pixel resolution using projected Blender joints."""
import argparse
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/hechicero'
PARTS = {
    'shirt': (0,32,32,68), 'cape': (36,32,71,73), 'hood': (74,32,103,49),
    'pouch': (106,32,120,47), 'sleeve': (0,76,15,97), 'arm': (17,76,28,93),
    'hand': (30,76,41,89), 'thigh': (44,76,59,100), 'shin': (62,76,75,96),
    'toe': (128,36,142,51), 'heel': (144,36,157,50),
    'boot': (77,76,97,92), 'sword': (0,105,49,117), 'rod': (51,106,98,114),
    'eyelet': (149,80,152,82),
    'grip': (0,110,12,115),
    'axe': (102,104,134,121), 'pick': (134,103,160,125), 'food': (104,76,119,89),
    'drink': (124,76,137,92), 'flame': (82,52,103,66),
}
for i in range(5):
    PARTS['head'+str(i)] = (32*i,0,32*i+32,30)

# Brush swatches from the Krita master. Discard edge blends left by the native brush.
SWATCHES = """8f886a a59a79 5c5849 96896b 968366 57433b 8b7056 a88865 746153 99866a 997956 aa6246 784538 39272d 633731 934c35 b96d43 dd9761 784c46 ac6e50 dd9f70 f5c593 ffe0aa
382e30 736747 44403a 66634c 898369 aba47d d2c399 48383a 634e43 80634e a48260
423539 604b45 826650 aa8561 d5a85f 8196a0 d4d4bb f0973e ffda87 b95243 76a7b5"""

def pixel_sheet(image):
    colors=[tuple(bytes.fromhex(h)) for h in SWATCHES.split()]
    mapping={}
    for _,rgba in image.getcolors(image.width*image.height):
        closest=min(colors,key=lambda c:sum((a-b)**2 for a,b in zip(c,rgba)))
        mapping[rgba]=(*closest,255) if rgba[3]>=128 else (0,0,0,0)
    image.putdata([mapping[p] for p in image.get_flattened_data()])
    return image

def mix(a,b,t):
    return tuple(x+(y-x)*t for x,y in zip(a,b))

def compose(sheet, filename, frame):
    size,j = frame
    kind,direction,index = Path(filename).stem.rsplit('_',2)
    flip = 'W' in direction
    back = 'N' in direction
    profile = direction in ('W','E')
    stack=[]
    def piece(name, start, end, a, b, width=1.0, mirror=False, depth=None):
        stamp=sheet[name]
        if mirror:
            stamp=stamp.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            a=(stamp.width-a[0],a[1]); b=(stamp.width-b[0],b[1])
        dx,dy=end[0]-start[0],end[1]-start[1]
        sx,sy=b[0]-a[0],b[1]-a[1]
        span=math.hypot(sx,sy)
        length=max(.01,math.hypot(dx,dy))
        u,v=dx/length,dy/length
        # Inverse affine: original brush pixels map into the posed bone with nearest sampling.
        stretch=span/max(length,span*.22)
        sx,sy=sx/span,sy/span
        aa=sx*u*stretch+sy*v/width
        ab=sx*v*stretch-sy*u/width
        ba=sy*u*stretch-sx*v/width
        bb=sy*v*stretch+sx*u/width
        x,y=start[:2]
        params=(aa,ab,a[0]-aa*x-ab*y,ba,bb,a[1]-ba*x-bb*y)
        shape=stamp.transform((size,size),Image.Transform.AFFINE,params,Image.Resampling.NEAREST)
        # Retain one-bit silhouettes and tool sockets. Soften only interior brush transitions.
        if name not in ('sword','grip','rod','eyelet','axe','pick','flame'):
            tones=stamp.transform((size,size),Image.Transform.AFFINE,params,Image.Resampling.BILINEAR)
            mixed=Image.blend(shape,tones,.55)
            mixed.putalpha(shape.getchannel('A'))
            shape=mixed
        stack.append((depth if depth is not None else (start[2]+end[2])/2,shape))
    neck=j['head']; hip=j['root']; center=mix(neck,hip,.5)
    coat_end=mix(neck,j['hem'],1.18)
    piece('cape',neck,coat_end,(17,3),(17,37),.98 if not profile else .7,flip,
          center[2]+(-.20 if back else .20))
    for side in ('L','R'):
        knee=j['shin.'+side]; ankle=j['foot.'+side]; toe=j['toe.'+side]; thigh=j['thigh.'+side]
        piece('thigh',thigh,knee,(7,2),(7,21),.91)
        piece('shin',knee,ankle,(6,2),(6,18),.86)
        if back or direction=='S':
            front=direction=='S'
            base=(mix(ankle,toe,.45)[0],max(ankle[1]+4,toe[1]),ankle[2])
            top=(ankle[0],base[1]-10,ankle[2])
            piece('toe' if front else 'heel',top,base,(7,2),(7,13),.79,flip,ankle[2]-.02)
        else:
            piece('boot',ankle,toe,(6,3),(14,12),.85,flip,ankle[2]-.02)
    piece('shirt',neck,mix(neck,hip,1.30),(16,2),(16,33),1.00 if not profile else .69,flip,center[2])
    piece('hood',mix(neck,hip,-.05),mix(neck,hip,.27),(14,2),(14,14),.86 if not profile else .63,flip,neck[2]-.035)
    bag=j['pouch']
    piece('pouch',bag,(bag[0],bag[1]+9,bag[2]),(7,1),(7,13),.70,flip,bag[2]-.1)
    for side in ('L','R'):
        shoulder=j['upper_arm.'+side]; elbow=j['forearm.'+side]; wrist=j['hand.'+side]
        piece('sleeve',mix(shoulder,neck,.14),mix(shoulder,elbow,1.07),(7,2),(7,18),.92)
        piece('arm',elbow,wrist,(5,2),(5,14),.83)
        piece('hand',wrist,j['fingers.'+side],(5,2),(5,10),.82,flip,wrist[2]-.025)
    head_index={'S':0,'SE':1,'SW':1,'E':2,'W':2,'NW':3,'NE':3,'N':4}[direction]
    top=mix(neck,j['crown'],1.17)
    piece('head'+str(head_index),top,mix(neck,j['crown'],.07),(15,1),(15,26),
          .85,flip,neck[2]-.19)
    wrist=j['hand.R']
    if 'slash' in kind or kind=='megadash':
        a,b=j['hilt'],j['blade']
        piece('grip',j['fingers.R'],a,(2,2),(11,2),.85,depth=a[2]-.03)
        piece('sword',a,b,(12,6),(47,2),.93,depth=a[2]-.04)
        if kind.startswith('fslash') or kind=='megadash':
            t=.42+.08*math.sin(int(index)*2)
            piece('flame',mix(a,b,t),b,(2,11),(18,2),.85,depth=a[2]-.045)
    elif kind.startswith('fish'):
        tip=j['rod']
        piece('rod',wrist,tip,(2,4),(45,2),1.15,depth=wrist[2]-.01)
        piece('eyelet',tip,(tip[0]+1,tip[1],tip[2]),(1,1),(2,1),1,depth=wrist[2]-.02)
    elif kind.startswith('chop'):
        tool=kind.split('_')[1]
        piece(tool,wrist,j[tool],(2,9 if tool=='axe' else 12),
              (29,10) if tool=='axe' else (24,18),.85,depth=wrist[2]-.01)
    elif kind in ('eat','drink'):
        piece('food' if kind=='eat' else 'drink',(wrist[0],wrist[1]-8,wrist[2]),wrist,
              (6,1),(6,11),.7,flip,wrist[2]-.04)
    image=Image.new('RGBA',(size,size))
    for _,stamp in sorted(stack,key=lambda s:-s[0]):
        image.alpha_composite(stamp)
    return image

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('guide',type=Path)
    parser.add_argument('--sample',type=Path)
    args=parser.parse_args()
    sheet=Image.open(ROOT/'blender/viajero_pixel.png').convert('RGBA')
    assert sheet.size==(160,128), sheet.size
    sheet=pixel_sheet(sheet)
    parts={name:sheet.crop(rect) for name,rect in PARTS.items()}
    base=[tuple(bytes.fromhex(h)) for h in SWATCHES.split()]
    colors=list(base)
    for color in base:
        neighbors=sorted((c for c in base if c!=color),key=lambda c:sum((v-w)**2 for v,w in zip(c,color)))
        for other in neighbors[:3]:
            mid=tuple(round((v+w)/2) for v,w in zip(color,other))
            if mid not in colors: colors.append(mid)
    palette=Image.new('P',(1,1))
    palette.putpalette(bytes(v for c in (colors+[colors[0]]*(256-len(colors))) for v in c))
    poses=json.loads(args.guide.read_text())
    assert len(poses)==1328
    if args.sample:
        poses={k:v for k,v in poses.items() if k.startswith('idle_') and k.endswith('_00.png')}
        args.sample.mkdir(parents=True,exist_ok=True)
    for name,frame in poses.items():
        kind=name.rsplit('_',2)[0]
        folder=args.sample or (ART/'polished' if kind in ('idle','walk','run','death','hurt') or 'slash' in kind else ART)
        pic=compose(parts,name,frame)
        assert pic.getbbox(),name
        # Fixed tonal steps keep the same material color across every clip and direction.
        alpha=pic.getchannel('A')
        pic=pic.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA')
        pic.putalpha(alpha)
        pic.save(folder/name)
if __name__=='__main__':
    main()
