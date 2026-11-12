# Objetos del mundo de la creación: mesa de alquimia, fogata (4 fotogramas), entrada de la mina, vetas (hierro, carbón, cristal),
# hongos luminosos y arbustos de hierba y bayas. Requiere build_map.py ya ejecutado en el mismo ns (usa sus ayudantes y la cámara).
# Uso: ns={}; exec(open(build_map.py).read(), ns); exec(open(este).read(), ns); build_craft_objects(); info = render_craft_world()
# Convención de build_map.py: +X mira hacia el frente (abajo-derecha en pantalla); 1 unidad = 1 m.

CRAFT_SPRITES = {
    'alchemy_table': 192, 'campfire_0': 128, 'campfire_1': 128, 'campfire_2': 128, 'campfire_3': 128, 'mine_entrance': 320,
    'node_iron': 96, 'node_coal': 96, 'node_crystal': 96, 'node_mushroom': 96, 'herb_bush': 96, 'berry_bush': 96,
}


def craft_materials():
    M = materials()
    R = mat_ramp
    M['glass'] = R('Craft • vidrio', [(0.15, 0.22, 0.26), (0.3, 0.45, 0.5), (0.5, 0.7, 0.75), (0.75, 0.92, 0.95)])
    M['liq_red'] = R('Craft • liq rojo', [(0.25, 0.01, 0.02), (0.55, 0.03, 0.05), (0.85, 0.08, 0.1), (1.0, 0.25, 0.25)])
    M['liq_blue'] = R('Craft • liq azul', [(0.02, 0.06, 0.25), (0.05, 0.15, 0.55), (0.15, 0.35, 0.9), (0.4, 0.6, 1.0)])
    M['liq_green'] = R('Craft • liq verde', [(0.02, 0.18, 0.05), (0.05, 0.4, 0.12), (0.15, 0.75, 0.25), (0.45, 1.0, 0.5)])
    M['book_a'] = R('Craft • libro A', [(0.08, 0.02, 0.02), (0.25, 0.05, 0.05), (0.5, 0.1, 0.08), (0.7, 0.2, 0.12)])
    M['book_b'] = R('Craft • libro B', [(0.02, 0.05, 0.12), (0.05, 0.12, 0.3), (0.1, 0.22, 0.5), (0.2, 0.35, 0.7)])
    M['paper'] = R('Craft • papel', [(0.35, 0.3, 0.2), (0.55, 0.5, 0.35), (0.78, 0.72, 0.55), (0.95, 0.9, 0.75)])
    M['ember'] = R('Craft • brasa', [(0.5, 0.1, 0.0), (0.9, 0.25, 0.02), (1.0, 0.5, 0.08), (1.0, 0.8, 0.3)])
    M['flame_y'] = R('Craft • llama amarilla', [(0.9, 0.6, 0.1), (1.0, 0.75, 0.2), (1.0, 0.9, 0.4), (1.0, 1.0, 0.7)])
    M['ore_iron'] = R('Craft • hierro', [(0.2, 0.1, 0.05), (0.45, 0.22, 0.1), (0.75, 0.4, 0.18), (0.95, 0.6, 0.3)])
    M['coal'] = R('Craft • carbón', [(0.004, 0.004, 0.006), (0.012, 0.012, 0.018), (0.03, 0.03, 0.04), (0.07, 0.07, 0.09)])
    M['crystal'] = R('Craft • cristal', [(0.15, 0.06, 0.4), (0.35, 0.18, 0.75), (0.6, 0.4, 1.0), (0.85, 0.75, 1.0)])
    M['mush_cap'] = R('Craft • sombrero', [(0.02, 0.25, 0.2), (0.08, 0.55, 0.45), (0.25, 0.9, 0.75), (0.7, 1.0, 0.95)])
    M['mush_stem'] = R('Craft • pie', [(0.3, 0.28, 0.22), (0.55, 0.52, 0.42), (0.8, 0.78, 0.65), (0.95, 0.93, 0.85)])
    M['leaf'] = R('Craft • hoja', [(0.02, 0.15, 0.03), (0.06, 0.32, 0.07), (0.15, 0.6, 0.15), (0.4, 0.9, 0.3)])
    M['berry'] = R('Craft • baya', [(0.2, 0.0, 0.02), (0.5, 0.02, 0.06), (0.85, 0.06, 0.12), (1.0, 0.25, 0.3)])
    M['petal'] = R('Craft • pétalo', [(0.5, 0.4, 0.05), (0.8, 0.65, 0.1), (1.0, 0.85, 0.2), (1.0, 1.0, 0.6)])
    return M


def build_craft_objects():
    M = craft_materials()
    for name in CRAFT_SPRITES:
        col = new_col('MAPOBJ_' + name)
        B = {}

        def bm(key):
            if key not in B:
                B[key] = bmesh.new()
            return B[key]

        if name == 'alchemy_table':   # 1.0 (x) por 1.7 (y); el frente de la mesa mira a +X
            box(bm('wood'), (0, 0, 0.8), 1.0, 1.7, 0.1)                                  # tablero
            for sx in (-1, 1):
                for sy in (-1, 1):
                    box(bm('wood'), (sx * 0.42, sy * 0.72, 0.4), 0.1, 0.1, 0.8)           # patas
            box(bm('wood'), (0, 0, 0.3), 0.9, 1.5, 0.06)                                  # estante inferior
            for k, y in enumerate((-0.45, -0.15, 0.15)):                                  # libros en el estante
                box(bm('book_a' if k % 2 == 0 else 'book_b'), (0.05, y, 0.4), 0.55, 0.2, 0.14)
            cone(bm('stone'), (0.05, 0.0, 0.85), 0.28, 0.28, 0.08, 10)                    # quemador
            sphere(bm('ember'), (0.05, 0.0, 0.97), 0.12, 0.12, 0.05)
            sphere(bm('glass'), (0.05, 0.0, 1.17), 0.2, 0.2, 0.2, 10, 6)                   # matraz central
            sphere(bm('liq_red'), (0.05, 0.0, 1.12), 0.17, 0.17, 0.13, 10, 6)
            cone(bm('glass'), (0.05, 0.0, 1.3), 0.07, 0.06, 0.28, 8)
            cone(bm('wood'), (0.05, 0.0, 1.55), 0.07, 0.07, 0.06, 8)
            for k, (y, mkey, h) in enumerate(((-0.6, 'liq_blue', 0.3), (-0.42, 'liq_green', 0.24), (0.45, 'liq_blue', 0.26), (0.62, 'liq_green', 0.3))):
                cone(bm(mkey), (-0.15, y, 0.85), 0.08, 0.07, h * 0.7, 8)                    # frascos de colores
                cone(bm('glass'), (-0.15, y, 0.85 + h * 0.7), 0.04, 0.03, h * 0.4, 8)
                cone(bm('wood'), (-0.15, y, 0.85 + h * 1.1), 0.04, 0.04, 0.04, 6)
            sphere(bm('dark'), (0.3, -0.5, 0.9), 0.13, 0.13, 0.08, 8, 5)                   # mortero
            sphere(bm('paper'), (0.32, 0.5, 0.88), 0.08, 0.2, 0.06, 6, 4)                  # plano enrollado
        elif name.startswith('campfire'):
            k = int(name[-1])
            for a in range(8):                                                          # círculo de piedras
                ang = a * math.pi / 4
                sphere(bm('rock'), (math.cos(ang) * 0.55, math.sin(ang) * 0.55, 0.1), 0.17, 0.17, 0.13, 6, 4)
            box(bm('wood'), (0, 0, 0.12), 0.9, 0.14, 0.14)
            box(bm('wood'), (0, 0, 0.26), 0.14, 0.9, 0.14)
            box(bm('wood'), (0, 0, 0.12), 0.14, 0.7, 0.12)
            sphere(bm('ember'), (0, 0, 0.18), 0.28, 0.28, 0.1, 8, 4)
            flames = [(0.0, 0.0, 0.62), (0.13, 0.08, 0.42), (-0.1, -0.1, 0.46), (0.0, 0.14, 0.34)]
            for i, (fx, fy, fh) in enumerate(flames):
                h = fh * (0.8 + 0.25 * math.sin(k * 1.6 + i * 2.1))
                cone(bm('ember'), (fx + 0.04 * math.sin(k + i), fy, 0.24), 0.16 - i * 0.015, 0.0, h, 7)
            cone(bm('flame_y'), (0.0, 0.0, 0.26), 0.09, 0.0, 0.3 * (0.8 + 0.3 * math.sin(k * 1.9)), 6)
        elif name == 'mine_entrance':   # montículo de roca con marco de madera y boca oscura a +X; ~3.2 (y) x 2.2 (x)
            sphere(bm('rock'), (-0.4, 0.0, 0.9), 1.8, 1.7, 1.15, 10, 6)
            sphere(bm('rock'), (-0.2, -1.0, 0.45), 0.8, 0.7, 0.5, 8, 5)
            sphere(bm('rock'), (-0.2, 1.0, 0.45), 0.8, 0.7, 0.5, 8, 5)
            sphere(bm('moss'), (-0.5, 0.2, 1.8), 0.9, 0.8, 0.18, 8, 4)
            box(bm('dark'), (0.78, 0, 0.7), 0.3, 1.2, 1.4)                                  # boca de la cueva
            for sy in (-1, 1):
                box(bm('wood'), (1.0, sy * 0.68, 0.75), 0.18, 0.18, 1.6)                    # postes
            box(bm('wood'), (1.0, 0, 1.58), 0.2, 1.7, 0.18)                                 # dintel
            box(bm('wood'), (1.0, 0, 1.4), 0.12, 1.3, 0.08)
            cone(bm('gold'), (1.12, -0.5, 1.2), 0.05, 0.05, 0.14, 6)                        # farol
            sphere(bm('ember'), (1.12, -0.5, 1.2), 0.07, 0.07, 0.07, 6, 4)
            sphere(bm('ore_iron'), (1.2, 0.95, 0.12), 0.18, 0.15, 0.12, 6, 4)               # montón de mena
            sphere(bm('coal'), (1.3, 1.15, 0.1), 0.14, 0.12, 0.1, 6, 4)
            box(bm('wood'), (1.35, -1.0, 0.18), 0.5, 0.35, 0.3)                              # caja
        elif name == 'node_iron':
            sphere(bm('rock'), (0, 0, 0.35), 0.62, 0.55, 0.45, 8, 5)
            sphere(bm('rock'), (0.4, 0.25, 0.2), 0.3, 0.26, 0.2, 6, 4)
            for x, y, z, s in ((0.3, 0.0, 0.5, 0.22), (0.38, -0.25, 0.3, 0.17), (0.3, 0.3, 0.28, 0.16), (0.1, -0.1, 0.74, 0.16), (0.5, 0.05, 0.2, 0.14)):
                sphere(bm('ore_iron'), (x, y, z), s, s * 1.1, s * 0.9, 6, 4)
        elif name == 'node_coal':
            sphere(bm('coal'), (0, 0, 0.32), 0.6, 0.52, 0.42, 8, 5)
            sphere(bm('coal'), (0.35, 0.28, 0.17), 0.3, 0.26, 0.2, 6, 4)
            sphere(bm('rock'), (-0.35, -0.3, 0.12), 0.2, 0.18, 0.12, 5, 4)
            for x, y, z in ((0.36, 0.0, 0.48), (0.3, -0.22, 0.3)):
                sphere(bm('ember'), (x, y, z), 0.05, 0.05, 0.05, 5, 3)
        elif name == 'node_crystal':
            sphere(bm('rock'), (0, 0, 0.1), 0.6, 0.55, 0.16, 8, 4)
            for x, y, h, s in ((0, 0, 1.0, 0.2), (0.28, 0.1, 0.65, 0.14), (-0.25, 0.15, 0.55, 0.13), (0.1, -0.28, 0.45, 0.11)):
                cone(bm('crystal'), (x, y, 0.1), s, 0.02, h, 6)
        elif name == 'node_mushroom':
            sphere(bm('moss'), (0, 0, 0.05), 0.5, 0.45, 0.07, 7, 3)
            for x, y, h, s in ((0, 0, 0.55, 0.28), (0.3, 0.2, 0.35, 0.2), (-0.25, 0.22, 0.28, 0.17)):
                cone(bm('mush_stem'), (x, y, 0.05), 0.06, 0.05, h, 6)
                sphere(bm('mush_cap'), (x, y, 0.05 + h), s, s, s * 0.6, 8, 4)
        elif name == 'herb_bush':
            for i in range(9):
                a = i * 2 * math.pi / 9
                cone(bm('leaf'), (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.0), 0.08, 0.0, 0.55 + 0.1 * (i % 3), 5)
            sphere(bm('petal'), (0.0, 0.0, 0.52), 0.07, 0.07, 0.07, 6, 4)
            sphere(bm('petal'), (0.16, 0.06, 0.4), 0.06, 0.06, 0.06, 6, 4)
        elif name == 'berry_bush':
            sphere(bm('leaf'), (0, 0, 0.32), 0.45, 0.4, 0.3, 8, 5)
            sphere(bm('leaf'), (0.28, 0.2, 0.2), 0.28, 0.25, 0.2, 7, 4)
            for x, y, z in ((0.34, 0.05, 0.42), (0.3, -0.2, 0.3), (0.15, 0.3, 0.38), (0.4, 0.28, 0.26), (0.2, -0.05, 0.55)):
                sphere(bm('berry'), (x, y, z), 0.07, 0.07, 0.07, 6, 4)
        for key, b in B.items():
            commit(col, f'{name}_{key}', M[key], b)


def render_craft_world(names=None):
    ns_globals = globals()
    saved_sprites = dict(ns_globals['SPRITES'])
    ns_globals['SPRITES'].clear()
    ns_globals['SPRITES'].update(CRAFT_SPRITES)
    try:
        info = render_sprites(names)
    finally:
        ns_globals['SPRITES'].clear()
        ns_globals['SPRITES'].update(saved_sprites)
    return info
