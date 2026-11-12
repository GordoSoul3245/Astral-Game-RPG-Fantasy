# Iconos 128 px de la creación: materiales, comida, pociones, planos, herramientas y espadas/armadura nuevas (data/crafting.json).
# Requiere sprite_common.py y build_items.py ya ejecutados en el mismo ns. Uso: render_all_craft()  (o render_craft('madera'))
OUT = r'C:/Users/Mateo/Documents/astral/art/items/'


def cmat(name, rgb):  # material cel de un color
    return gem('c_' + name, rgb)


def palette():
    m = mats()
    for n, c in {
        'wood': (0.42, 0.25, 0.1), 'woodl': (0.62, 0.4, 0.18), 'stone': (0.36, 0.38, 0.44), 'ore': (0.3, 0.27, 0.3),
        'copper': (0.85, 0.5, 0.25), 'coal': (0.05, 0.05, 0.07), 'ember': (1.0, 0.3, 0.08), 'crystal': (0.62, 0.4, 1.0),
        'mush': (0.3, 1.0, 0.8), 'mushs': (0.9, 0.9, 0.8), 'leafg': (0.22, 0.75, 0.3), 'berry': (0.85, 0.08, 0.18),
        'meat': (0.72, 0.18, 0.15), 'roast': (0.55, 0.28, 0.1), 'rabbit': (0.5, 0.46, 0.42), 'fox': (0.9, 0.45, 0.15),
        'leatherb': (0.5, 0.28, 0.12), 'iron': (0.3, 0.32, 0.38), 'steelb': (0.34, 0.5, 0.72), 'glass': (0.7, 0.88, 0.95),
        'slime': (0.45, 0.9, 0.3), 'scale': (0.8, 0.15, 0.12), 'eyew': (0.95, 0.93, 0.88), 'iris': (0.3, 0.9, 1.0),
        'cork': (0.55, 0.38, 0.2), 'liq_red': (0.9, 0.1, 0.12), 'liq_orange': (1.0, 0.45, 0.05), 'liq_blue': (0.2, 0.4, 1.0),
        'liq_green': (0.2, 0.9, 0.35), 'liq_cyan': (0.35, 0.9, 1.0), 'liq_dark': (0.4, 0.05, 0.05), 'bread': (0.82, 0.62, 0.3),
        'paper': (0.88, 0.8, 0.58), 'ink': (0.15, 0.3, 0.55), 'headstone': (0.3, 0.32, 0.38), 'headiron': (0.36, 0.38, 0.45),
        'headsteel': (0.4, 0.58, 0.82), 'bladeiron': (0.34, 0.37, 0.44), 'bladesteel': (0.45, 0.62, 0.9), 'bladecry': (0.55, 0.35, 0.95),
    }.items():
        m[n] = cmat(n, c)
    return m


def ingot(kit, p, mat, loc, rot=0.0):
    x, y, z = loc
    kit.box((x, y, z), (0.7, 0.3, 0.22), mat, p)
    kit.box((x, y, z + 0.14), (0.56, 0.22, 0.08), mat, p)


def flask(kit, p, liquid, m, bomb=False):
    body = liquid if liquid is not None else m['glass']
    if bomb:
        kit.ell((0, 0, -0.08), (0.3, 0.3, 0.3), body, p)
        kit.ell((-0.1, -0.26, 0.0), (0.07, 0.03, 0.1), m['glass'], p)
        kit.beam((0, 0, 0.18), (0, 0, 0.32), 0.07, 0.07, m['glass'], p, 8)
        kit.beam((0, 0, 0.32), (0, 0, 0.4), 0.075, 0.075, m['cork'], p, 8)
        kit.beam((0.01, 0, 0.4), (0.16, 0, 0.5), 0.015, 0.012, m['obs'], p, 5)
        kit.ell((0.17, 0, 0.51), (0.05, 0.05, 0.05), m['ember'], p)
        return
    kit.ell((0, 0, -0.1), (0.28, 0.27, 0.28), body, p)                                  # cuerpo (líquido o vidrio)
    kit.ell((-0.11, -0.25, -0.02), (0.06, 0.03, 0.11), m['glass'], p)                   # brillo del vidrio
    kit.beam((0, 0, 0.12), (0, 0, 0.34), 0.085, 0.07, m['glass'], p, 8)                 # cuello
    kit.torus((0, 0, 0.34), 0.075, 0.018, m['glass'], p)                                # borde
    kit.beam((0, 0, 0.35), (0, 0, 0.44), 0.07, 0.07, m['cork'], p, 8)                   # corcho


def bowl(kit, p, content, m):
    kit.ell((0, 0, -0.1), (0.42, 0.32, 0.22), m['wood'], p)
    kit.ell((0, -0.02, -0.0), (0.36, 0.26, 0.07), content, p)


def pickaxe(kit, p, head, m):
    kit.beam((-0.3, 0, -0.45), (0.3, 0, 0.42), 0.04, 0.04, m['wood'], p, 8)             # mango
    kit.beam((0.1, 0, 0.3), (0.55, 0, 0.1), 0.1, 0.025, head, p, 6)                     # pico derecho
    kit.beam((0.1, 0, 0.3), (-0.3, 0, 0.52), 0.1, 0.025, head, p, 6)                      # pico izquierdo
    kit.ell((0.12, 0, 0.3), (0.09, 0.07, 0.09), head, p)                                 # cabeza


def axe(kit, p, head, m):
    kit.beam((-0.25, 0, -0.48), (0.2, 0, 0.35), 0.045, 0.04, m['wood'], p, 8)
    kit.poly([(0.0, -0.03, 0.4), (0.5, -0.03, 0.5), (0.52, -0.03, 0.1), (0.1, -0.03, 0.2)], head, p)   # filo
    kit.poly([(0.0, 0.03, 0.4), (0.1, 0.03, 0.2), (0.52, 0.03, 0.1), (0.5, 0.03, 0.5)], head, p)
    kit.box((0.1, 0, 0.3), (0.12, 0.1, 0.22), head, p)


def build_craft(i):
    m = palette()
    kit = Kit('ITEM', 'it_root')
    p = kit.pivot('it_p', (0, 0, 0.05))
    if i == 'madera':
        for k, (z, x) in enumerate([(-0.18, -0.2), (-0.18, 0.2), (0.12, 0.0)]):
            kit.beam((x - 0.4, 0, z), (x + 0.4, 0, z), 0.17, 0.17, m['wood'], p, 10)
            kit.ell((x + 0.4, -0.01, z), (0.02, 0.17, 0.17), m['woodl'], p, 10, 6)
    elif i == 'piedra':
        kit.ell((-0.15, 0, -0.12), (0.3, 0.25, 0.22), m['stone'], p)
        kit.ell((0.22, 0.02, -0.15), (0.24, 0.2, 0.18), m['stone'], p)
        kit.ell((0.0, 0.03, 0.12), (0.22, 0.2, 0.2), m['stone'], p)
    elif i == 'mena_hierro':
        kit.ell((0, 0, -0.05), (0.4, 0.3, 0.32), m['ore'], p)
        for x, z, s in [(-0.15, 0.1, 0.1), (0.12, 0.0, 0.09), (0.0, -0.18, 0.08), (0.2, 0.18, 0.07)]:
            kit.ell((x, -0.28, z), (s, 0.04, s), m['copper'], p)
    elif i == 'carbon':
        kit.ell((-0.15, 0, -0.1), (0.28, 0.24, 0.24), m['coal'], p)
        kit.ell((0.2, 0, -0.12), (0.24, 0.2, 0.2), m['coal'], p)
        kit.ell((0.02, 0.02, 0.14), (0.22, 0.2, 0.2), m['coal'], p)
        for x, z in [(-0.2, -0.05), (0.2, -0.1), (0.05, 0.18)]:
            kit.ell((x, -0.22, z), (0.04, 0.02, 0.04), m['ember'], p)
    elif i == 'cristal_arcano':
        for x, z, h, s in [(0, 0, 0.8, 0.14), (-0.22, -0.08, 0.55, 0.1), (0.22, -0.1, 0.6, 0.11), (0.1, 0.0, 0.4, 0.08)]:
            kit.beam((x, 0, -0.35), (x, 0, -0.35 + h), s, s * 0.05, m['crystal'], p, 6)
        kit.ell((0, 0, -0.38), (0.4, 0.2, 0.08), m['ore'], p)
    elif i == 'hongo_luminoso':
        for x, h, s in [(-0.2, 0.35, 0.2), (0.15, 0.5, 0.25), (0.35, 0.25, 0.14)]:
            kit.beam((x, 0, -0.4), (x, 0, -0.4 + h), 0.045, 0.05, m['mushs'], p, 6)
            kit.ell((x, -0.01, -0.4 + h), (s, s * 0.9, s * 0.55), m['mush'], p)
    elif i == 'hierba_vital':
        for k, a in enumerate([-0.5, -0.25, 0.0, 0.25, 0.5]):
            kit.beam((0, 0, -0.4), (a * 0.7, 0, 0.1 + (0.3 - abs(a) * 0.3)), 0.07, 0.01, m['leafg'], p, 5)
    elif i == 'baya_roja':
        for x, z in [(-0.18, -0.12), (0.18, -0.12), (0.0, 0.14)]:
            kit.ell((x, 0, z), (0.18, 0.18, 0.18), m['berry'], p)
            kit.ell((x, -0.17, z + 0.06), (0.04, 0.02, 0.04), m['glass'], p)
        kit.ell((0, 0, 0.3), (0.12, 0.04, 0.06), m['leafg'], p)
    elif i in ('carne_conejo', 'carne_zorro'):
        big = 1.25 if i == 'carne_zorro' else 1.0
        kit.ell((0, 0, 0.0), (0.34 * big, 0.2, 0.28 * big), m['meat'], p)
        kit.ell((0.05, -0.12, 0.08), (0.2 * big, 0.08, 0.14 * big), m['liq_red'], p)
        kit.beam((0.25 * big, 0, -0.1), (0.5, 0, -0.32), 0.05, 0.05, m['bone'], p, 6)
        kit.ell((0.52, 0, -0.34), (0.07, 0.06, 0.07), m['bone'], p)
    elif i in ('piel_conejo', 'piel_zorro'):
        col = m['rabbit'] if i == 'piel_conejo' else m['fox']
        kit.ell((0, 0, 0), (0.45, 0.06, 0.34), col, p)
        kit.ell((-0.2, -0.05, 0.28), (0.1, 0.04, 0.12), col, p)
        kit.ell((0.2, -0.05, 0.28), (0.1, 0.04, 0.12), col, p)
        kit.ell((0, -0.05, -0.3), (0.12, 0.04, 0.1), col, p)
    elif i == 'cuero':
        kit.ell((0, 0, 0.0), (0.42, 0.06, 0.3), m['leatherb'], p)
        kit.beam((-0.35, -0.08, 0.05), (0.35, -0.08, 0.05), 0.1, 0.1, m['leather'], p, 10)
        kit.box((0, -0.16, 0.05), (0.06, 0.03, 0.22), m['gold'], p)
    elif i == 'lingote_hierro' or i == 'lingote_acero':
        mat = m['iron'] if i == 'lingote_hierro' else m['steelb']
        ingot(kit, p, mat, (-0.2, 0, -0.22))
        ingot(kit, p, mat, (0.2, -0.01, -0.22))
        ingot(kit, p, mat, (0.0, -0.02, 0.14))
    elif i == 'frasco_vacio':
        flask(kit, p, None, m)
    elif i == 'pocion_vida':
        flask(kit, p, m['liq_red'], m)
    elif i == 'pocion_vida_mayor':
        flask(kit, p, m['liq_orange'], m)
        kit.torus((0, -0.02, 0.28), 0.1, 0.014, m['gold'], p)
    elif i == 'pocion_mana':
        flask(kit, p, m['liq_blue'], m)
    elif i == 'pocion_vigor':
        flask(kit, p, m['liq_green'], m)
    elif i == 'elixir_furia':
        flask(kit, p, m['liq_orange'], m)
        kit.beam((0, -0.3, -0.18), (0, -0.3, 0.02), 0.07, 0.0, m['ember'], p, 4)
    elif i == 'elixir_celeridad':
        flask(kit, p, m['liq_cyan'], m)
        kit.beam((-0.04, -0.3, 0.02), (0.06, -0.3, -0.12), 0.05, 0.01, m['glass'], p, 4)
    elif i == 'frasco_ignis':
        flask(kit, p, m['liq_dark'], m, bomb=True)
    elif i in ('carne_asada', 'asado_zorro'):
        big = 1.3 if i == 'asado_zorro' else 1.0
        kit.ell((0, 0, 0.0), (0.34 * big, 0.2, 0.26 * big), m['roast'], p)
        kit.ell((-0.05, -0.12, 0.08), (0.2 * big, 0.08, 0.12 * big), m['copper'], p)
        kit.beam((0.25 * big, 0, -0.1), (0.5, 0, -0.32), 0.05, 0.05, m['bone'], p, 6)
        kit.ell((0.52, 0, -0.34), (0.07, 0.06, 0.07), m['bone'], p)
    elif i == 'estofado_zorro':
        bowl(kit, p, m['copper'], m)
        kit.ell((-0.1, -0.1, 0.02), (0.1, 0.06, 0.07), m['roast'], p)
        kit.ell((0.12, -0.1, 0.03), (0.08, 0.06, 0.06), m['leafg'], p)
    elif i == 'tostada_hongo':
        kit.box((0, 0, -0.05), (0.7, 0.1, 0.5), m['bread'], p)
        for x, z in [(-0.15, 0.02), (0.15, 0.05), (0.0, -0.12)]:
            kit.ell((x, -0.08, z), (0.14, 0.05, 0.09), m['mush'], p)
    elif i == 'pastel_baya':
        kit.ell((0, 0, -0.1), (0.42, 0.34, 0.16), m['bread'], p)
        kit.ell((0, 0, 0.05), (0.38, 0.3, 0.1), m['berry'], p)
        for x, z in [(-0.15, 0.12), (0.12, 0.14), (0.0, 0.2)]:
            kit.ell((x, -0.1, z), (0.07, 0.07, 0.07), m['liq_red'], p)
    elif i == 'sopa_hueso':
        bowl(kit, p, m['bread'], m)
        kit.beam((0.0, -0.05, 0.0), (0.28, -0.05, 0.28), 0.04, 0.04, m['bone'], p, 6)
        kit.ell((0.3, -0.05, 0.3), (0.07, 0.05, 0.07), m['bone'], p)
    elif i == 'plano':
        kit.box((0, 0, 0), (0.7, 0.02, 0.9), m['paper'], p)
        kit.beam((-0.38, -0.03, 0.46), (0.38, -0.03, 0.46), 0.06, 0.06, m['paper'], p, 8)
        kit.beam((-0.38, -0.03, -0.46), (0.38, -0.03, -0.46), 0.06, 0.06, m['paper'], p, 8)
        kit.torus((0, -0.02, 0.05), 0.2, 0.012, m['ink'], p, rot=(math.pi / 2, 0, 0))
        kit.box((0, -0.02, 0.05), (0.025, 0.01, 0.4), m['ink'], p)
        for dz in (-0.3, -0.22):
            kit.box((0, -0.02, dz), (0.46, 0.01, 0.02), m['ink'], p)
    elif i.startswith('pico_') or i.startswith('hacha_'):
        tier = i.split('_')[1]
        head = {'piedra': m['headstone'], 'hierro': m['headiron'], 'acero': m['headsteel']}[tier]
        (pickaxe if i.startswith('pico') else axe)(kit, p, head, m)
    elif i == 'espada_hierro':
        sword(kit, m['bladeiron'], None, m)
    elif i == 'espada_acero':
        sword(kit, m['bladesteel'], m['gem_cyan'], m)
    elif i == 'espada_cristal':
        sword(kit, m['bladecry'], m['gem_purple'], m)
    elif i == 'armadura_hierro':
        armor(kit, m['iron'], m['iron'], m['leather'], 'leather')
        kit.ell((0, -0.2, 0.12), (0.1, 0.03, 0.12), m['steelb'], p)
    elif i == 'gel_slime':
        kit.ell((0, 0, -0.1), (0.38, 0.32, 0.26), m['slime'], p)
        kit.ell((-0.1, -0.18, 0.0), (0.1, 0.04, 0.07), m['glass'], p)
        kit.ell((0.05, 0, 0.16), (0.2, 0.18, 0.18), m['slime'], p)
    elif i == 'hueso_antiguo':
        kit.beam((-0.38, 0, -0.3), (0.38, 0, 0.3), 0.07, 0.07, m['bone'], p, 8)
        for sx in (-1, 1):
            e = (sx * 0.38, 0, sx * 0.3)
            kit.ell((e[0] - 0.05, 0, e[2] + sx * 0.05), (0.1, 0.09, 0.1), m['bone'], p)
            kit.ell((e[0] + 0.07, 0, e[2] - 0.05 * sx), (0.1, 0.09, 0.1), m['bone'], p)
    elif i == 'ojo_ciclope':
        kit.ell((0, 0, 0), (0.4, 0.4, 0.4), m['eyew'], p)
        kit.ell((0, -0.32, 0), (0.2, 0.1, 0.2), m['iris'], p)
        kit.ell((0, -0.4, 0), (0.09, 0.05, 0.09), m['obs'], p)
        for a in (0.9, 2.3, 4.0):
            kit.beam((math.cos(a) * 0.2, -0.3, math.sin(a) * 0.2), (math.cos(a) * 0.36, -0.2, math.sin(a) * 0.34), 0.012, 0.005, m['liq_red'], p, 4)
    elif i == 'nucleo_tormenta':
        kit.ell((0, 0, 0), (0.28, 0.28, 0.28), m['steelb'], p)
        kit.torus((0, 0, 0), 0.4, 0.025, m['gem_cyan'], p, rot=(math.radians(70), 0, math.radians(20)))
        kit.beam((0, -0.2, 0.2), (0.1, -0.2, 0.0), 0.05, 0.02, m['gem_cyan'], p, 4)
        kit.beam((0.1, -0.2, 0.0), (-0.05, -0.2, -0.2), 0.05, 0.01, m['gem_cyan'], p, 4)
    elif i == 'escama_dragon':
        kit.ell((0, 0, 0), (0.42, 0.06, 0.5), m['scale'], p)
        kit.ell((0, -0.06, 0), (0.28, 0.03, 0.36), m['liq_orange'], p)
        for x, z in [(-0.12, 0.18), (0.12, 0.18), (0.0, 0.02), (-0.14, -0.14), (0.14, -0.14)]:
            kit.ell((x, -0.1, z), (0.1, 0.03, 0.08), m['scale'], p)
    kit.upd()


def render_craft(item_id, res=128):
    build_craft(item_id)
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


CRAFT_IDS = [
    'madera', 'piedra', 'mena_hierro', 'carbon', 'cristal_arcano', 'hongo_luminoso', 'hierba_vital', 'baya_roja', 'carne_conejo',
    'piel_conejo', 'carne_zorro', 'piel_zorro', 'cuero', 'lingote_hierro', 'lingote_acero', 'frasco_vacio',
    'pocion_vida', 'pocion_vida_mayor', 'pocion_mana', 'pocion_vigor', 'elixir_furia', 'elixir_celeridad', 'frasco_ignis',
    'carne_asada', 'asado_zorro', 'estofado_zorro', 'tostada_hongo', 'pastel_baya', 'sopa_hueso', 'plano',
    'pico_piedra', 'pico_hierro', 'pico_acero', 'hacha_piedra', 'hacha_hierro', 'hacha_acero',
    'espada_hierro', 'espada_acero', 'espada_cristal', 'armadura_hierro',
    'gel_slime', 'hueso_antiguo', 'ojo_ciclope', 'nucleo_tormenta', 'escama_dragon',
]


def render_all_craft(only=None):
    for i in CRAFT_IDS:
        if only is None or i in only:
            render_craft(i)
