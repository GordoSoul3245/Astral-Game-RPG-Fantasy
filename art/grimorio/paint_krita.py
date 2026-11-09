import json, os, uuid, urllib.request, pathlib, shutil, math

# Tapa del grimorio: 1024x1024, panel único UV 0-1. Misma paleta que el hechicero (índigo + oro + llama).
OUT = pathlib.Path(__file__).parent
WORK = pathlib.Path.home() / 'Documents/Krita-MCP/grimorio'
WORK.mkdir(parents=True, exist_ok=True)
cfg = json.loads((pathlib.Path(os.environ['LOCALAPPDATA'])/'krita-codex-mcp/config.json').read_text())
def call(op, **args):
    body=json.dumps(dict(protocol_version='1',request_id=str(uuid.uuid4()),operation=op,arguments=args)).encode()
    req=urllib.request.Request(f"http://127.0.0.1:{cfg['port']}/v1/execute",body,{'Authorization':'Bearer '+cfg['token'],'Content-Type':'application/json'})
    result=json.load(urllib.request.urlopen(req, timeout=180))
    if not result.get('ok'): raise RuntimeError(result)
    return result['result']
doc=call('document',action='create',width=1024,height=1024,name='Grimorio — tapa',color_model='RGBA',color_depth='U8',profile='',resolution=72)['affected_document_id']
def layer(name):
    return call('layers',document_id=doc,action='create',name=name,kind='paintlayer')['affected_layer_id']
def draw(shape,color,**kwargs):
    return call('draw',document_id=doc,layer_id=lid,shape=shape,foreground=color,brush_size=2,stroke_style='None',fill_style='ForegroundColor',**kwargs)
def rect(x,y,w,h,color): draw('rectangle',color,rect=dict(x=x,y=y,width=w,height=h))
def poly(points,color): draw('polygon',color,points=[dict(x=x,y=y) for x,y in points])
def line(p,q,color,width):
    call('draw',document_id=doc,layer_id=lid,shape='line',foreground=color,brush_size=width,stroke_style='ForegroundColor',fill_style='None',points=[dict(x=p[0],y=p[1]),dict(x=q[0],y=q[1])])

lid=layer('01 — Cuero índigo')
rect(0,0,1024,1024,'#1b2a4a')
lid=layer('02 — Planos cel')
poly([(0,0),(420,0),(300,1024),(0,1024)],'#233559')
poly([(700,0),(1024,0),(1024,1024),(800,1024)],'#121c36')
lid=layer('03 — Ribete de oro')
for x in (26,974):
    rect(x-12,0,24,1024,'#b47b32'); rect(x-7,0,6,1024,'#f4cf77')
for y in (26,998):
    rect(0,y-12,1024,24,'#b47b32'); rect(0,y-7,1024,6,'#f4cf77')
lid=layer('04 — Esquineros')
for cx,cy in [(96,96),(928,96),(96,928),(928,928)]:
    poly([(cx,cy-52),(cx+52,cy),(cx,cy+52),(cx-52,cy)],'#d8a94f')
    poly([(cx,cy-30),(cx+30,cy),(cx,cy+30),(cx-30,cy)],'#7a1f2b')
lid=layer('05 — Sello de la llama')
cx,cy=512,512
for radius,width,color in [(250,8,'#a77b3c'),(220,4,'#e6bd66'),(150,3,'#a77b3c')]:
    for i in range(48):
        a=math.tau*i/48; b=math.tau*(i+1)/48
        line((cx+radius*math.cos(a),cy+radius*math.sin(a)),(cx+radius*math.cos(b),cy+radius*math.sin(b)),color,width)
poly([(512,330),(572,455),(548,500),(610,478),(572,600),(512,680),(452,605),(420,505),(478,520),(452,455)],'#c7913c')
poly([(512,420),(545,505),(528,545),(558,532),(512,625),(478,550)],'#ffe0a0')
for k in range(8):
    a=math.tau*k/8
    x,y=cx+235*math.cos(a),cy+235*math.sin(a)
    poly([(x,y-20),(x+11,y),(x,y+20),(x-11,y)],'#e8bd68')
result=call('save_export',document_id=doc,kra_path=str(WORK/'grimorio_tapa.kra'),png_path=str(WORK/'grimorio_tapa.png'))
for name in ('grimorio_tapa.kra','grimorio_tapa.png'): shutil.copy2(WORK/name,OUT/name)
assert (OUT/'grimorio_tapa.kra').stat().st_size>1000 and (OUT/'grimorio_tapa.png').stat().st_size>1000
print(json.dumps(dict(document_id=doc,outputs=result['outputs'],destination=str(OUT))))
