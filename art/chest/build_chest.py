# Cofre de recompensa: madera con herrajes dorados; la tapa se abre hacia atrás (6 fotogramas) y enseña monedas.
# Requiere art/sprite_common.py ya ejecutado en el mismo ns. Uso: build(); render()
OUT = r'C:/Users/Mateo/Documents/astral/art/chest/'
RES = 128                    # FEET = (68, 113.7): centro del cofre a ras de suelo
PIVOTS = ['ch_lid']


def build():
    kit = Kit('CHEST', 'ch_root')
    WOOD = ramp('Chest • wood', 'Cel • dark wood', [(0.05, 0.022, 0.008), (0.11, 0.05, 0.016), (0.2, 0.09, 0.03), (0.3, 0.14, 0.05)])
    GOLD, OBS = bpy.data.materials['Cel • antique gold'], bpy.data.materials['Cel • obsidian']
    GLOW = ramp('Chest • glow', 'Cel • antique gold', [(0.6, 0.4, 0.08), (0.9, 0.65, 0.15), (1.0, 0.85, 0.35), (1.0, 0.97, 0.7)])
    root = kit.root
    kit.box((0, 0, 0.3), (1.3, 0.8, 0.6), WOOD, root)                           # cuerpo
    for x in (-0.4, 0.0, 0.4):
        kit.box((x, -0.405, 0.3), (0.02, 0.02, 0.56), OBS, root)                # juntas de tablones
    for sx in (-1, 1):
        kit.box((sx * 0.56, 0, 0.3), (0.14, 0.84, 0.62), GOLD, root)            # herrajes laterales
    kit.box((0, 0, 0.05), (1.34, 0.84, 0.1), GOLD, root)                        # zócalo
    kit.box((0, -0.43, 0.5), (1.3, 0.04, 0.08), GOLD, root)                     # banda del frente
    kit.box((0, 0, 0.6), (1.1, 0.62, 0.05), OBS, root)                          # interior oscuro
    gold = [(-0.3, 0.1, 0.65), (0.0, -0.05, 0.7), (0.3, 0.12, 0.66), (-0.1, 0.2, 0.68), (0.15, -0.15, 0.66), (-0.35, -0.12, 0.65), (0.4, -0.05, 0.64)]
    for i, p in enumerate(gold):
        c = kit.ell(p, (0.16, 0.14, 0.08), GOLD, root)                          # monedas
        c.name = f'ch_coin{i}'
    g = kit.ell((0, 0, 0.78), (0.5, 0.35, 0.12), GLOW, root)                    # brillo del botín
    g.name = 'ch_glow'
    lid = kit.pivot('ch_lid', (0, 0.4, 0.6), root)                              # bisagra en el borde trasero
    kit.ell((0, 0, 0.62), (0.66, 0.42, 0.3), WOOD, lid)                         # tapa abombada
    kit.box((0, 0, 0.6), (1.3, 0.8, 0.02), WOOD, lid)
    for sx in (-1, 1):
        kit.ell((sx * 0.5, 0, 0.63), (0.08, 0.3, 0.2), GOLD, lid)               # bandas de la tapa (siguen su curva)
    kit.box((0, -0.4, 0.62), (0.2, 0.04, 0.22), GOLD, lid)                      # cerradura
    kit.ell((0, -0.43, 0.6), (0.03, 0.02, 0.05), OBS, lid)
    pose('idle', 0)
    kit.upd()
    print('cofre listo', 'yaw', round(tile_yaw(), 3))


def pose(kind, k):
    reset(PIVOTS)
    t = k / 5.0 if kind == 'open' else 0.0
    bpy.data.objects['ch_lid'].rotation_euler = (-math.radians(115) * t, 0, 0)
    bpy.data.objects['ch_glow'].hide_render = t < 0.3


def render(kinds=(('open', 6),)):
    render_fixed('CHEST', 'ch_root', pose, OUT, 'chest_', tile_yaw(), RES, kinds)
