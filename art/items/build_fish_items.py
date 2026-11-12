# Iconos 128 px de la pesca: peces, alga, cañas, platos de pescado y elixires (data/crafting.json, data/fishing.json).
# Requiere sprite_common.py, build_items.py y build_craft_items.py ya ejecutados en el mismo ns. Uso: render_all_fish()  (o render_fish('sardina'))
OUT = r'C:/Users/Mateo/Documents/astral/art/items/'


def fish_palette():
    m = palette()
    for n, c in {
        'sardina': (0.35, 0.55, 0.78), 'silver': (0.85, 0.9, 0.95), 'gold': (0.97, 0.72, 0.15), 'goldl': (1.0, 0.9, 0.5),
        'orange': (1.0, 0.5, 0.1), 'trout': (0.5, 0.68, 0.55), 'pink': (0.95, 0.5, 0.55), 'puffer': (0.92, 0.82, 0.38),
        'eelb': (0.1, 0.35, 0.7), 'glow': (0.3, 0.95, 1.0), 'yellow': (1.0, 0.9, 0.3), 'cryst': (0.64, 0.42, 1.0),
        'cryl': (0.85, 0.75, 1.0), 'sword': (0.2, 0.36, 0.72), 'swordl': (0.7, 0.85, 0.95), 'ash': (0.2, 0.2, 0.25),
        'emberf': (1.0, 0.35, 0.08), 'abyss': (0.1, 0.22, 0.32), 'abyssl': (0.2, 0.4, 0.5), 'kelp': (0.1, 0.5, 0.45),
        'kelpl': (0.3, 0.8, 0.6), 'liq_teal': (0.15, 0.8, 0.7), 'liq_ash': (0.9, 0.3, 0.1), 'fillet': (0.95, 0.6, 0.5),
        'plate': (0.85, 0.85, 0.9), 'roastf': (0.6, 0.35, 0.15), 'rodiron': (0.4, 0.42, 0.5), 'rodcry': (0.62, 0.4, 1.0),
        'line': (0.9, 0.9, 0.85),
    }.items():
        m[n] = cmat(n, c)
    return m


def fish_body(kit, p, m, body, belly, fin, L=0.5, H=0.2):
    kit.ell((0, 0, 0), (L, 0.12, H), body, p)
    kit.ell((0.04, -0.07, -H * 0.4), (L * 0.8, 0.07, H * 0.55), belly, p)
    kit.ell((-L - 0.12, 0, H * 0.55), (0.14, 0.03, H * 0.75), fin, p)
    kit.ell((-L - 0.12, 0, -H * 0.55), (0.14, 0.03, H * 0.75), fin, p)
    kit.ell((-0.02, 0, H + 0.01), (L * 0.35, 0.03, 0.09), fin, p)
    kit.ell((0.0, -0.1, -H * 0.2), (0.1, 0.03, 0.06), fin, p)
    kit.ell((L * 0.62, -0.11, H * 0.25), (0.05, 0.035, 0.05), m['eyew'], p)
    kit.ell((L * 0.64, -0.14, H * 0.25), (0.025, 0.02, 0.025), m['obs'], p)


def build_fish(i):
    m = fish_palette()
    kit = Kit('ITEM', 'it_root')
    p = kit.pivot('it_p', (0, 0, 0.05))
    if i == 'sardina':
        fish_body(kit, p, m, m['sardina'], m['silver'], m['sardina'], 0.46, 0.15)
    elif i == 'carpa_dorada':
        fish_body(kit, p, m, m['gold'], m['goldl'], m['orange'], 0.48, 0.26)
        for x, z in [(-0.15, 0.1), (0.05, 0.14), (-0.05, -0.02), (0.18, 0.04)]:
            kit.ell((x, -0.11, z), (0.06, 0.02, 0.05), m['goldl'], p)
    elif i == 'trucha_plateada':
        fish_body(kit, p, m, m['trout'], m['silver'], m['trout'], 0.5, 0.17)
        kit.ell((0, -0.115, 0.0), (0.4, 0.02, 0.03), m['pink'], p)
        for x in (-0.2, -0.05, 0.1, 0.25):
            kit.ell((x, -0.115, 0.1), (0.025, 0.015, 0.025), m['obs'], p)
    elif i == 'pez_globo':
        kit.ell((0, 0, 0), (0.32, 0.3, 0.3), m['puffer'], p)
        kit.ell((0, -0.12, -0.12), (0.26, 0.2, 0.18), m['silver'], p)
        for a in range(10):
            ang = a * 0.63
            kit.beam((math.cos(ang) * 0.3, -0.05, math.sin(ang) * 0.3), (math.cos(ang) * 0.43, -0.05, math.sin(ang) * 0.43), 0.025, 0.003, m['bone'], p, 4)
        kit.ell((-0.38, 0, 0.0), (0.1, 0.03, 0.12), m['puffer'], p)
        kit.ell((0.2, -0.28, 0.08), (0.07, 0.04, 0.07), m['eyew'], p)
        kit.ell((0.22, -0.31, 0.08), (0.035, 0.02, 0.035), m['obs'], p)
        kit.ell((0.3, -0.25, -0.08), (0.06, 0.04, 0.03), m['liq_red'], p)
    elif i == 'anguila_luminosa':
        for k in range(7):
            x = -0.55 + k * 0.18
            z = math.sin(k * 0.95) * 0.16
            kit.ell((x, 0, z), (0.14, 0.09, 0.09), m['eelb'], p)
            kit.ell((x, -0.08, z), (0.04, 0.02, 0.04), m['glow'], p)
        kit.ell((0.62, 0, math.sin(6 * 0.95) * 0.16 + 0.02), (0.14, 0.1, 0.1), m['eelb'], p)
        kit.ell((0.7, -0.08, math.sin(6 * 0.95) * 0.16 + 0.06), (0.04, 0.03, 0.04), m['yellow'], p)
    elif i == 'pez_cristal':
        fish_body(kit, p, m, m['cryst'], m['cryl'], m['cryl'], 0.46, 0.2)
        for x, h in [(-0.2, 0.34), (0.0, 0.42), (0.2, 0.3)]:
            kit.beam((x, 0, 0.14), (x, 0, 0.14 + h * 0.55), 0.06, 0.005, m['cryl'], p, 5)
    elif i == 'pez_lanza':
        fish_body(kit, p, m, m['sword'], m['swordl'], m['sword'], 0.46, 0.17)
        kit.beam((0.46, 0, 0.0), (0.98, 0, 0.0), 0.05, 0.004, m['swordl'], p, 6)
        kit.ell((-0.05, 0, 0.3), (0.22, 0.03, 0.2), m['sword'], p)
    elif i == 'pez_ceniza':
        fish_body(kit, p, m, m['ash'], m['emberf'], m['emberf'], 0.48, 0.21)
        for x, z in [(-0.2, 0.0), (0.0, 0.1), (0.2, -0.02), (-0.05, -0.1)]:
            kit.ell((x, -0.115, z), (0.04, 0.02, 0.04), m['ember'], p)
    elif i == 'pez_abisal':
        kit.ell((0, 0, 0), (0.5, 0.18, 0.34), m['abyss'], p)
        kit.ell((0.06, -0.1, -0.16), (0.4, 0.1, 0.16), m['abyssl'], p)
        kit.ell((-0.6, 0, 0.0), (0.16, 0.03, 0.3), m['abyss'], p)
        for x in (0.28, 0.38, 0.48):
            kit.beam((x, -0.14, -0.02), (x + 0.02, -0.15, -0.14), 0.025, 0.003, m['bone'], p, 4)
        kit.beam((0.2, 0, 0.3), (0.4, 0, 0.55), 0.02, 0.01, m['abyssl'], p, 4)
        kit.ell((0.42, 0, 0.58), (0.07, 0.07, 0.07), m['yellow'], p)
        kit.ell((0.3, -0.17, 0.1), (0.06, 0.04, 0.06), m['eyew'], p)
        kit.ell((0.32, -0.2, 0.1), (0.03, 0.02, 0.03), m['obs'], p)
    elif i == 'alga_marina':
        for k, a in enumerate([-0.55, -0.3, -0.05, 0.2, 0.45]):
            kit.beam((a * 0.2, 0, -0.4), (a * 0.9, 0, 0.15 + (0.3 - abs(a) * 0.3)), 0.07, 0.015, m['kelp' if k % 2 == 0 else 'kelpl'], p, 5)
        kit.ell((0, 0, -0.4), (0.25, 0.1, 0.06), m['kelp'], p)
    elif i.startswith('cana_'):
        head = {'madera': m['woodl'], 'hierro': m['rodiron'], 'cristal': m['rodcry']}[i.split('_')[1]]
        kit.beam((-0.42, 0, -0.45), (0.5, 0, 0.5), 0.045, 0.012, head, p, 8)
        kit.beam((-0.42, 0, -0.45), (-0.25, 0, -0.28), 0.06, 0.06, m['leather'], p, 8)
        kit.torus((-0.18, -0.06, -0.12), 0.08, 0.02, m['gold'], p, rot=(math.pi / 2, 0, 0))
        kit.beam((0.5, 0, 0.5), (0.58, 0, -0.1), 0.01, 0.01, m['line'], p, 4)
        kit.ell((0.58, 0, -0.14), (0.04, 0.03, 0.04), m['berry'], p)
    elif i == 'pescado_asado':
        kit.ell((0, 0, -0.18), (0.5, 0.35, 0.07), m['plate'], p)
        fish_body(kit, p, m, m['roastf'], m['copper'], m['roast'], 0.4, 0.14)
    elif i == 'sopa_pescado':
        bowl(kit, p, m['copper'], m)
        kit.ell((-0.1, -0.1, 0.04), (0.16, 0.05, 0.07), m['fillet'], p)
        kit.ell((0.14, -0.1, 0.04), (0.07, 0.05, 0.06), m['kelpl'], p)
    elif i == 'brocheta_anguila':
        kit.beam((-0.5, 0, -0.3), (0.5, 0, 0.3), 0.025, 0.025, m['wood'], p, 6)
        for t in (-0.3, -0.05, 0.2):
            kit.ell((t, 0, t * 0.6), (0.14, 0.12, 0.12), m['roastf'], p)
            kit.ell((t, -0.1, t * 0.6), (0.05, 0.02, 0.05), m['glow'], p)
    elif i == 'sashimi_lanza':
        kit.ell((0, 0, -0.18), (0.5, 0.35, 0.07), m['plate'], p)
        for x in (-0.28, -0.1, 0.08, 0.26):
            kit.ell((x, -0.05, -0.06), (0.1, 0.07, 0.07), m['fillet'], p)
        kit.ell((0.0, -0.05, 0.1), (0.14, 0.07, 0.06), m['kelpl'], p)
    elif i == 'elixir_marea':
        flask(kit, p, m['liq_teal'], m)
        kit.ell((0, -0.3, -0.1), (0.07, 0.02, 0.05), m['glow'], p)
    elif i == 'elixir_ceniza':
        flask(kit, p, m['liq_ash'], m)
        kit.beam((0, -0.3, -0.18), (0, -0.3, 0.0), 0.06, 0.0, m['ember'], p, 4)
    kit.upd()


def render_fish(item_id, res=128):
    build_fish(item_id)
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


FISH_IDS = [
    'sardina', 'carpa_dorada', 'trucha_plateada', 'pez_globo', 'anguila_luminosa', 'pez_cristal', 'pez_lanza', 'pez_ceniza', 'pez_abisal',
    'alga_marina', 'cana_madera', 'cana_hierro', 'cana_cristal', 'pescado_asado', 'sopa_pescado', 'brocheta_anguila', 'sashimi_lanza',
    'elixir_marea', 'elixir_ceniza',
]


def render_all_fish(only=None):
    for i in FISH_IDS:
        if only is None or i in only:
            render_fish(i)
