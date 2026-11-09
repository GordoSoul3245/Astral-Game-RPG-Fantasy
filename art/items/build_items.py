# Objetos equipables de los cofres (data/equipment.json): iconos 128 px de armaduras, anillos, collares, espadas y grimorios.
# Requiere art/sprite_common.py ya ejecutado en el mismo ns. Uso: render_all()  (o render_one('anillo_vigor'))
OUT = r'C:/Users/Mateo/Documents/astral/art/items/'
M = bpy.data.materials


def gem(name, rgb):
    r, g, b = rgb
    return ramp('Item • gem ' + name, 'Cel • cobalt silk', [(r * .35, g * .35, b * .35), (r * .65, g * .65, b * .65), (r, g, b), (min(1, r * 1.5), min(1, g * 1.5), min(1, b * 1.5))])


def mats():
    d = {}
    d['leather'] = ramp('Item • leather', 'Cel • dark wood', [(0.06, 0.03, 0.012), (0.14, 0.07, 0.025), (0.26, 0.13, 0.05), (0.4, 0.2, 0.08)])
    d['steel'] = ramp('Item • steel', 'Cel • midnight indigo', [(0.05, 0.055, 0.07), (0.12, 0.13, 0.17), (0.24, 0.26, 0.32), (0.42, 0.45, 0.52)])
    d['bone'] = ramp('Item • bone', 'Cel • amber cloak', [(0.22, 0.19, 0.13), (0.42, 0.37, 0.26), (0.68, 0.62, 0.46), (0.9, 0.84, 0.66)])
    d['blade_obs'] = ramp('Item • blade obsidian', 'Cel • midnight indigo', [(0.03, 0.025, 0.05), (0.08, 0.06, 0.12), (0.17, 0.12, 0.26), (0.34, 0.26, 0.5)])
    d['blade_storm'] = ramp('Item • blade storm', 'Cel • midnight indigo', [(0.1, 0.15, 0.22), (0.25, 0.35, 0.5), (0.5, 0.65, 0.8), (0.85, 0.95, 1.0)])
    d['book_ember'] = ramp('Item • book ember', 'Cel • crimson', [(0.12, 0.03, 0.015), (0.28, 0.07, 0.03), (0.5, 0.12, 0.04), (0.7, 0.2, 0.06)])
    d['book_inferno'] = ramp('Item • book inferno', 'Cel • crimson', [(0.05, 0.008, 0.012), (0.12, 0.015, 0.02), (0.25, 0.03, 0.035), (0.4, 0.05, 0.05)])
    d['pages'] = ramp('Item • pages', 'Cel • amber cloak', [(0.3, 0.26, 0.18), (0.5, 0.45, 0.32), (0.75, 0.7, 0.55), (0.95, 0.9, 0.75)])
    d['gold'], d['obs'] = M['Cel • antique gold'], M['Cel • obsidian']
    for n, c in (('red', (0.8, 0.08, 0.1)), ('orange', (1.0, 0.4, 0.05)), ('blue', (0.25, 0.4, 1.0)), ('green', (0.2, 0.9, 0.5)),
                 ('cyan', (0.3, 0.9, 1.0)), ('purple', (0.6, 0.2, 0.9))):
        d['gem_' + n] = gem(n, c)
    return d


def armor(kit, body, trim, accent, kind):
    p = kit.pivot('it_p', (0, 0, 0.05))
    kit.ell((0, 0, 0.0), (0.4, 0.2, 0.44), body, p)                                    # torso
    kit.ell((0, -0.12, 0.08), (0.32, 0.1, 0.3), trim if kind == 'gold' else body, p)   # peto
    for sx in (-1, 1):
        kit.ell((sx * 0.42, 0, 0.3), (0.19, 0.17, 0.14), trim, p)                       # hombreras
        if kind == 'gold':
            kit.beam((sx * 0.5, -0.02, 0.36), (sx * 0.58, -0.02, 0.56), 0.06, 0.0, trim, p, 6)   # púas
        kit.ell((sx * 0.5, 0, 0.0), (0.12, 0.12, 0.3), body, p)                          # manguitos
    kit.ell((0, -0.04, 0.46), (0.14, 0.1, 0.06), M['Cel • obsidian'], p)                # cuello
    kit.box((0, -0.14, -0.22), (0.78, 0.08, 0.1), trim, p)                              # cinturón
    kit.ell((0, -0.19, -0.22), (0.07, 0.03, 0.07), accent, p)                           # hebilla
    for x in (-0.24, -0.08, 0.08, 0.24):
        kit.box((x, -0.12, -0.38), (0.13, 0.05, 0.22), body, p)                         # faldón
    if kind == 'leather':
        kit.beam((-0.3, -0.2, 0.32), (0.28, -0.2, -0.16), 0.03, 0.03, M['Cel • obsidian'], p, 6)   # correas
        kit.beam((0.3, -0.2, 0.32), (-0.28, -0.2, -0.16), 0.03, 0.03, M['Cel • obsidian'], p, 6)
    if kind == 'mail':
        for i in range(4):
            for j in range(4):
                kit.ell((-0.24 + i * 0.16, -0.2, 0.3 - j * 0.14), (0.06, 0.02, 0.05), trim, p)   # anillas
    if kind == 'gold':
        kit.ell((0, -0.2, 0.12), (0.09, 0.03, 0.11), accent, p)                         # gema central


def ring(kit, band, stone, big=False):
    p = kit.pivot('it_p', (0, 0, 0.05))
    kit.torus((0, 0, 0), 0.3, 0.075, band, p, rot=(math.pi / 2, 0, 0))
    kit.ell((0, 0, 0.32), (0.15, 0.12, 0.07), band, p)                                  # engaste
    kit.ell((0, -0.03, 0.4), (0.13, 0.1, 0.15), stone, p)                               # gema
    if big:
        for sx in (-1, 1):
            kit.ell((sx * 0.2, 0, 0.27), (0.06, 0.05, 0.06), stone, p)
    p.rotation_euler = (math.radians(-18), 0, 0)


def amulet(kit, kind, m):
    p = kit.pivot('it_p', (0, 0, 0.05))
    cord = m['obs'] if kind == 'bone' else m['gold']
    kit.torus((0, 0, 0.12), 0.38, 0.018, cord, p, rot=(math.pi / 2, 0, 0))
    if kind == 'bone':
        for a in range(-60, 61, 20):                                                    # cuentas de hueso
            t = math.radians(a)
            kit.ell((math.sin(t) * 0.38, -0.02, 0.12 - math.cos(t) * 0.38), (0.05, 0.05, 0.07), m['bone'], p)
        kit.ell((0, -0.03, -0.42), (0.14, 0.1, 0.15), m['bone'], p)                      # colgante: calavera
        for sx in (-1, 1):
            kit.ell((sx * 0.05, -0.12, -0.4), (0.03, 0.02, 0.04), m['obs'], p)
    elif kind == 'wind':
        kit.beam((0, -0.03, -0.3), (0, -0.03, -0.58), 0.1, 0.0, m['gem_green'], p, 6)    # cristal
        kit.beam((0, -0.03, -0.3), (0, -0.03, -0.12), 0.1, 0.0, m['gem_green'], p, 6)
        kit.torus((0, -0.03, -0.3), 0.14, 0.015, m['gold'], p, rot=(math.pi / 2, 0, 0))
    else:  # tormenta
        kit.torus((0, -0.03, -0.36), 0.17, 0.03, m['gold'], p, rot=(math.pi / 2, 0, 0))
        kit.ell((0, -0.04, -0.36), (0.11, 0.06, 0.11), m['gem_cyan'], p)
        for a in range(0, 360, 90):
            t = math.radians(a + 45)
            kit.beam((math.sin(t) * 0.17, -0.03, -0.36 + math.cos(t) * 0.17), (math.sin(t) * 0.27, -0.03, -0.36 + math.cos(t) * 0.27), 0.04, 0.0, m['gem_cyan'], p, 4)


def sword(kit, blade, glow, m):
    p = kit.pivot('it_p', (0, 0, 0.05))
    kit.box((0, 0, 0.2), (0.11, 0.025, 0.78), blade, p)                                 # hoja
    kit.beam((0, 0, 0.59), (0, 0, 0.74), 0.055, 0.0, blade, p, 4)                       # punta
    if glow is None:
        kit.box((0, -0.014, 0.2), (0.012, 0.01, 0.72), m['gold'], p)                    # filo dorado
    else:
        kit.box((0, -0.014, 0.2), (0.016, 0.01, 0.72), glow, p)                         # vena luminosa
    kit.box((0, 0, -0.2), (0.3, 0.05, 0.05), m['gold'], p)                              # guarda
    kit.box((0, 0, -0.42), (0.06, 0.05, 0.3), m['obs'], p)                               # empuñadura
    for z in (-0.32, -0.42, -0.52):
        kit.box((0, -0.026, z), (0.065, 0.01, 0.03), m['gold'], p)
    kit.ell((0, 0, -0.6), (0.045, 0.04, 0.04), m['gold'], p)                             # pomo
    p.rotation_euler = (0, math.radians(-40), 0)


def grimoire(kit, cover, emblem, flame, m):
    p = kit.pivot('it_p', (0, 0, 0.05))
    kit.box((0.04, 0.0, 0), (0.58, 0.12, 0.8), m['pages'], p)                           # hojas
    kit.box((0, -0.03, 0), (0.6, 0.07, 0.82), cover, p)                                  # tapa
    kit.box((-0.31, 0.0, 0), (0.08, 0.15, 0.84), cover, p)                               # lomo
    for sx, sz in ((-1, -1), (-1, 1), (1, -1), (1, 1)):
        kit.box((sx * 0.29, -0.065, sz * 0.4), (0.13, 0.03, 0.13), m['gold'], p)         # esquineros
    kit.torus((0.0, -0.08, 0.02), 0.17, 0.018, m['gold'], p, rot=(math.pi / 2, 0, 0))   # medallón
    if flame:
        for x, h in ((-0.07, 0.14), (0.0, 0.22), (0.07, 0.14)):
            kit.beam((x, -0.09, -0.07), (x, -0.09, -0.07 + h), 0.05, 0.0, emblem, p, 6)  # llama
    else:
        kit.ell((0, -0.09, 0.02), (0.1, 0.03, 0.1), emblem, p)
    p.rotation_euler = (math.radians(8), math.radians(-22), math.radians(-6))


def build_item(item_id):
    m = mats()
    kit = Kit('ITEM', 'it_root')
    if item_id == 'armadura_cuero':
        armor(kit, m['leather'], m['obs'], m['gold'], 'leather')
    elif item_id == 'armadura_malla':
        armor(kit, m['steel'], m['steel'], m['gold'], 'mail')
    elif item_id == 'armadura_dorada':
        armor(kit, m['gold'], m['gold'], m['gem_red'], 'gold')
    elif item_id == 'anillo_vigor':
        ring(kit, m['gold'], m['gem_red'])
    elif item_id == 'anillo_furia':
        ring(kit, m['gold'], m['gem_orange'], True)
    elif item_id == 'anillo_arcano':
        ring(kit, m['steel'], m['gem_purple'])
    elif item_id == 'collar_hueso':
        amulet(kit, 'bone', m)
    elif item_id == 'collar_viento':
        amulet(kit, 'wind', m)
    elif item_id == 'amuleto_tormenta':
        amulet(kit, 'storm', m)
    elif item_id == 'katana_obsidiana':
        sword(kit, m['blade_obs'], None, m)
    elif item_id == 'katana_tormenta':
        sword(kit, m['blade_storm'], m['gem_cyan'], m)
    elif item_id == 'grimorio_brasas':
        grimoire(kit, m['book_ember'], m['gem_orange'], False, m)
    elif item_id == 'grimorio_inferno':
        grimoire(kit, m['book_inferno'], m['gem_orange'], True, m)
    kit.upd()


def render_one(item_id, res=128):
    build_item(item_id)
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


IDS = ['armadura_cuero', 'armadura_malla', 'armadura_dorada', 'anillo_vigor', 'anillo_furia', 'anillo_arcano', 'collar_hueso',
       'collar_viento', 'amuleto_tormenta', 'katana_obsidiana', 'katana_tormenta', 'grimorio_brasas', 'grimorio_inferno']


def render_all():
    for i in IDS:
        render_one(i)
