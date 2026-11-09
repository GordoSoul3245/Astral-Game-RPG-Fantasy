# Puerta de la dungeon: marco de piedra con hoja de madera y herrajes; la hoja sube al abrirse (6 fotogramas).
# Requiere art/sprite_common.py ya ejecutado en el mismo ns. Uso: build(); render()
OUT = r'C:/Users/Mateo/Documents/astral/art/door/'
K = 1.75
RES = int(128 * K)                                         # 224 px
FEET = (68 + (RES - 128) / 2, 113.7 + (RES - 128) / 2)     # centro del marco a ras de suelo
PIVOTS = ['dr_panel']


def build():
    kit = Kit('DOOR', 'dr_root')
    STONE = ramp('Door • stone', 'Cel • midnight indigo', [(0.04, 0.045, 0.08), (0.09, 0.1, 0.18), (0.17, 0.19, 0.3), (0.28, 0.31, 0.45)])
    STONE2 = ramp('Door • stone light', 'Cel • midnight indigo', [(0.07, 0.08, 0.13), (0.14, 0.16, 0.26), (0.24, 0.27, 0.4), (0.38, 0.42, 0.58)])
    WOOD, OBS, GOLD = bpy.data.materials['Cel • dark wood'], bpy.data.materials['Cel • obsidian'], bpy.data.materials['Cel • antique gold']
    root = kit.root
    # marco: dos pilares, dintel y piedra clave (ancho total 2.7 m, alto 3.2 m, fondo 0.5 m); el frente mira a -Y
    for sx in (-1, 1):
        kit.box((sx * 1.15, 0, 1.5), (0.4, 0.5, 3.0), STONE, root)
        kit.box((sx * 1.15, -0.02, 0.1), (0.5, 0.56, 0.2), STONE2, root)       # basa
        kit.box((sx * 1.15, -0.02, 2.95), (0.5, 0.56, 0.12), STONE2, root)     # capitel
    kit.box((0, 0, 3.0), (2.7, 0.5, 0.4), STONE, root)
    kit.box((0, -0.02, 3.25), (2.9, 0.56, 0.12), STONE2, root)                  # cornisa
    kit.box((0, -0.27, 3.0), (0.45, 0.08, 0.5), STONE2, root)                   # clave
    kit.box((0, 0.2, 1.4), (1.9, 0.1, 2.8), OBS, root)                          # interior oscuro
    # hoja de madera con tablones, bandas de hierro y aldaba; vive detrás del dintel para poder subir
    panel = kit.pivot('dr_panel', (0, 0, 2.7))                                  # pivote arriba: al abrir la hoja se recoge hacia el dintel
    kit.box((0, 0.0, 1.35), (1.9, 0.16, 2.7), WOOD, panel)
    for x in (-0.6, -0.2, 0.2, 0.6):
        kit.box((x, -0.085, 1.35), (0.03, 0.02, 2.7), OBS, panel)               # juntas de tablones
    for z in (0.6, 1.35, 2.1):
        kit.box((0, -0.09, z), (1.9, 0.04, 0.16), OBS, panel)                   # bandas de hierro
    kit.ell((0.55, -0.12, 1.3), (0.1, 0.05, 0.1), GOLD, panel)                  # aldaba
    pose('idle', 0)
    kit.upd()
    print('puerta lista', 'RES', RES, 'FEET', FEET, 'yaw', round(tile_yaw(), 3))


def pose(kind, k):
    reset(PIVOTS)
    p = bpy.data.objects['dr_panel']
    open_t = k / 5.0 if kind == 'open' else 0.0
    p.scale = (1, 1, max(1.0 - open_t, 0.001))
    p.hide_render = open_t >= 1.0


def render(kinds=(('open', 6),)):
    render_fixed('DOOR', 'dr_root', pose, OUT, 'door_', tile_yaw(), RES, kinds)
