# Iconos 128 px del huerto: tres bolsas de semillas y la regadera (data/crafting.json "consumables").
# Requiere sprite_common.py, build_items.py, build_craft_items.py y build_fish_items.py ya ejecutados en el mismo ns
# (fish_palette, Kit, OUT, bpy, math). Uso: render_all_farm()  (o render_farm('regadera'))


def build_farm(i):
    m = fish_palette()
    kit = Kit('ITEM', 'it_root')
    p = kit.pivot('it_p', (0, 0, 0.05))
    if i.startswith('semilla_'):
        seed = {'semilla_baya': m['berry'], 'semilla_hierba': m['kelpl'], 'semilla_hongo': m['glow']}[i]
        sack = m['bone']
        kit.ell((0, 0, -0.1), (0.36, 0.3, 0.36), sack, p)            # bolsa de tela
        kit.ell((0, 0, -0.32), (0.3, 0.26, 0.12), m['leather'], p)   # base cosida
        kit.beam((0, 0, 0.2), (0, 0, 0.36), 0.16, 0.1, sack, p, 12)  # cuello fruncido
        kit.torus((0, 0, 0.3), 0.14, 0.022, m['leather'], p)          # cordel
        kit.beam((0.06, 0, 0.3), (0.2, 0, 0.12), 0.012, 0.012, m['leather'], p, 5)
        for x, y, z in [(-0.12, -0.3, -0.18), (0.06, -0.31, -0.22), (0.2, -0.26, -0.28), (-0.22, -0.2, -0.28), (0.02, -0.36, -0.05)]:
            kit.ell((x, y, z), (0.07, 0.05, 0.05), seed, p)           # semillas que asoman
        if i == 'semilla_hierba':
            kit.beam((-0.05, 0, 0.36), (-0.14, 0, 0.55), 0.03, 0.005, m['kelp'], p, 5)
            kit.beam((0.05, 0, 0.36), (0.14, 0, 0.52), 0.03, 0.005, m['kelp'], p, 5)
        if i == 'semilla_hongo':
            kit.ell((0, 0, 0.5), (0.1, 0.1, 0.06), m['glow'], p)
            kit.beam((0, 0, 0.36), (0, 0, 0.48), 0.025, 0.025, m['bone'], p, 5)
        if i == 'semilla_baya':
            kit.ell((0, 0, 0.5), (0.07, 0.07, 0.07), m['berry'], p)
            kit.beam((0, 0, 0.36), (0, 0, 0.46), 0.012, 0.012, m['kelp'], p, 4)
    elif i == 'regadera':
        kit.beam((0, 0, -0.3), (0, 0, 0.2), 0.3, 0.3, m['rodiron'], p, 28)       # cuerpo
        kit.torus((0, 0, -0.3), 0.3, 0.025, m['wood'], p)
        kit.torus((0, 0, 0.2), 0.3, 0.025, m['wood'], p)
        kit.beam((0.25, 0, -0.12), (0.7, 0, 0.3), 0.06, 0.04, m['rodiron'], p, 10)  # pitorro
        kit.beam((0.66, 0, 0.27), (0.76, 0, 0.36), 0.12, 0.12, m['gold'], p, 12)    # alcachofa
        kit.torus((-0.22, 0, 0.0), 0.24, 0.035, m['wood'], p, rot=(math.pi / 2, 0, 0))  # asa
        kit.ell((0, -0.3, -0.05), (0.2, 0.02, 0.1), m['liq_teal'], p)             # etiqueta azul
    kit.upd()


def render_farm(item_id, res=128):
    build_farm(item_id)
    s = bpy.context.scene
    r = s.render
    col, cam = bpy.data.collections['ITEM'], bpy.data.objects['IconCam']
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    keep = {o.name for o in col.all_objects}
    hidden = {}
    for o in s.objects:
        if o.type in ('MESH', 'CURVE') and o.name not in keep:
            hidden[o] = o.hide_render
            o.hide_render = True
    s.camera = cam
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    r.filepath = OUT + item_id + '.png'
    bpy.ops.render.render(write_still=True)
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


CROPS = ['baya', 'hierba', 'hongo']


def build_crop(crop, stage):  # sprites del huerto: fase 0 (semillas), 1 (brote), 2 (planta), 3 (madura)
    m = fish_palette()
    kit = Kit('ITEM', 'it_root')
    p = kit.pivot('it_p', (0, 0, 0.05))
    kit.ell((0, 0, -0.4), (0.55, 0.5, 0.12), m['leather'], p)  # montículo de tierra
    if stage == 0:
        for x, y in [(-0.2, 0.0), (0.05, 0.12), (0.22, -0.08)]:
            kit.ell((x, y, -0.3), (0.06, 0.05, 0.04), m['wood'], p)
    elif stage == 1:
        for x in (-0.18, 0.12):
            kit.beam((x, 0, -0.32), (x, 0, 0.0), 0.03, 0.015, m['kelp'], p, 5)
            kit.ell((x + 0.08, 0, 0.0), (0.09, 0.03, 0.05), m['kelpl'], p)
            kit.ell((x - 0.08, 0, -0.04), (0.09, 0.03, 0.05), m['kelpl'], p)
    elif stage == 2:
        for x, h in [(-0.22, 0.35), (0.0, 0.5), (0.22, 0.3)]:
            kit.beam((x, 0, -0.32), (x, 0, -0.32 + h), 0.04, 0.02, m['kelp'], p, 6)
            kit.ell((x + 0.12, 0, -0.32 + h * 0.8), (0.14, 0.03, 0.07), m['kelpl'], p)
            kit.ell((x - 0.12, 0, -0.32 + h * 0.6), (0.14, 0.03, 0.07), m['kelpl'], p)
    else:
        if crop == 'baya':
            kit.ell((0, 0, -0.05), (0.42, 0.36, 0.34), m['kelp'], p)
            for x, y, z in [(-0.25, -0.3, 0.0), (0.1, -0.34, 0.1), (0.3, -0.2, -0.08), (-0.05, -0.36, -0.2), (0.0, -0.1, 0.3), (-0.3, -0.1, 0.2)]:
                kit.ell((x, y, z), (0.07, 0.07, 0.07), m['berry'], p)
        elif crop == 'hierba':
            for i, x in enumerate([-0.3, -0.18, -0.06, 0.06, 0.18, 0.3, 0.0]):
                kit.beam((x, 0, -0.32), (x * 1.6, 0.04 * (i % 3 - 1), 0.45 + 0.1 * (i % 2)), 0.05, 0.005, m['kelpl'] if i % 2 else m['kelp'], p, 5)
        else:
            for x, h in [(-0.25, 0.3), (0.05, 0.5), (0.28, 0.25)]:
                kit.beam((x, 0, -0.32), (x, 0, -0.32 + h), 0.04, 0.035, m['bone'], p, 6)
                kit.ell((x, 0, -0.32 + h + 0.04), (0.15, 0.15, 0.08), m['glow'], p)
    kit.upd()


def render_crop(crop, stage, res=128):
    build_crop(crop, stage)
    s = bpy.context.scene
    r = s.render
    col, cam = bpy.data.collections['ITEM'], bpy.data.objects['IconCam']
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    keep = {o.name for o in col.all_objects}
    hidden = {}
    for o in s.objects:
        if o.type in ('MESH', 'CURVE') and o.name not in keep:
            hidden[o] = o.hide_render
            o.hide_render = True
    s.camera = cam
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    r.filepath = OUT + 'cultivo_%s_%d.png' % (crop, stage)
    bpy.ops.render.render(write_still=True)
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


def render_all_crops():
    for c in CROPS:
        for st in range(4):
            render_crop(c, st)


FARM_IDS = ['semilla_baya', 'semilla_hierba', 'semilla_hongo', 'regadera']


def render_all_farm():
    for i in FARM_IDS:
        render_farm(i)
