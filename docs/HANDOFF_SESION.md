# Handoff: Ecos de la Ruina (proyecto `astral`)

Pégame este archivo al empezar otra sesión. Contiene lo hecho, el estado real del repo y lo pendiente.

## 1. Proyecto y entorno
- Juego: **Ecos de la Ruina**, RPG isométrico de acción en **Godot 4.7.2** (renderer GL Compatibility, GDScript).
- Carpeta: `C:\Users\Mateo\Documents\astral`. Repo: `github.com/GordoSoul3245/Astral-Game-RPG-Fantasy`, rama `main`.
- Godot consola (tests y capturas): `C:/Users/Mateo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  - Tests: `--headless --path . --script res://tests/<nombre>.gd` (con `--fixed-fps 60` para `test_playthrough`).
  - Capturas: el mismo comando **sin** `--headless`.
  - Tras crear recursos nuevos: `--headless --path . --import`.
- Blender 5.2.3 conectado por MCP (`blender/hechicero_floor.blend`, rig `HECHICERO_RIG`). Krita: la conexión con krita-codex no quedó validada.
- Git: no hay identidad global. Commits con `git -c user.name=GordoSoul3245 -c user.email=<correo del último commit>`. No escribir el correo en textos ni peticiones externas.
- Carpeta **distinta** `C:\Users\Mateo\Documents\dungeon`: plantilla de estudio de juegos (Claude Code Game Studios), no es este juego.

## 2. Preferencias del usuario
- Responder en **español**, con enlaces a archivos.
- Si la petición es clara, **hacer sin preguntar**. Preguntar solo cuando la decisión sea suya.
- **Subir a GitHub al terminar cada bloque**, sin force push.
- Al final: qué se hizo, qué **no se probó jugando** y qué riesgos quedan.
- Si el contexto se acerca al límite, pasar el trabajo a Codex.

## 3. Estado del repo
- Último commit subido: `0d66541` (lista de prueba). Antes: `b846823` (sistema de creación).
- Todos los tests `tests/test_*.gd` pasaban en la última ejecución (incluye `test_crafting`, `test_crafting_world` y `test_playthrough`).
- Los archivos de creación (`tests/capture_craft.gd`, `tests/test_crafting_world.gd`, `data/crafting.json`, `art/items/build_craft_items.py`) ya están commiteados en `b846823`; no hay cambios sin commit en ellos.
- Modificado sin commit: `blender/hechicero_floor.blend`.
- Sin rastrear: `.claude/`, `export/` y varios `*.import` de previews. No son del juego.

## 4. Lo trabajado en esta sesión (en orden)
1. **Revisión inicial:** los 15 tests pasaban. Se confirmó el estado del repo.
2. **Estela del dash:** primero una raya en el suelo (`df422b1`); luego se sustituyó por **siluetas residuales** del fotograma real (cuerpo, capa y arma) con shader de silueta plana (`83bc40a`).
3. **Impacto:** los enemigos se aplastan al recibir golpe (`_squash` en `scripts/combat.gd`). Golpes pesados y explosiones dejan una onda con grietas (`scripts/ground_impact.gd`). El tajo pesado muerde el suelo aunque falle (`57bef51`).
4. **Animación de golpe recibido:** pose `hurt` de 4 fotogramas en Blender para esqueleto, slime y cíclope (`art/skeleton`, `art/slime`, `art/cyclops`). `enemy.gd` carga `hurt_<dir>` si existe (`89f1887`, `b3905b0`).
5. **Dash rehecho:** pose erguida (torso máx. 10°, antes 45°) en `art/katana/build_katana.py` (`DASH`). Salpicadura de sangre con color por criatura (`scripts/splatter.gd`, `"blood"` en `data/creatures.json`). Bola de energía por capas (`scripts/projectile.gd`, `_draw_energy`) (`83bc40a`).
6. **Plan aplazado del personaje** (`docs/FUTURE_CHARACTER_SYSTEM.md`, `9358a64`): ver §6.
7. **Investigación y diseño de crafteo** (`docs/CRAFTING_DESIGN.md`, `6703f79`): ver §5.
8. **Sistema de creación implementado** (`b846823`): ver §5.
9. **Lista de prueba** (`docs/PLAYTEST_CREACION.md`, `0d66541`).

## 5. Sistema de creación (implementado)
**Datos:** `data/crafting.json` (materiales, consumibles, 7 planos, recetas por estación, tiempos de estación, recolección, props del mundo, mina y `world_sprites`).
**Lógica pura:** `scripts/crafting.gd` (inventario unificado, recetas, alquimia, consumibles, tiradas de recolección).
**Progreso:** `scripts/progress.gd` añade `blueprints`, `buffs` (con `add_buff`/`tick_buffs`) y `quick` (tecla G).
**Paneles:**
- `scripts/station_ui.gd`: ventana que pausa el juego (Esc cierra; no cierra a mitad de animación).
- `scripts/craft_panel.gd` + `scripts/craft_fx.gd`: forja y cocina y crafteo a mano.
- `scripts/alchemy_panel.gd` + `scripts/alchemy_fx.gd` + `scripts/plano_view.gd`: mesa de alquimia (plano sobre la mesa, ingredientes colocados, catalizador opcional, animación).
- Pestaña **Crafteo** en `scripts/menu.gd` (`_build_craft`, `_build_side`).

**Mundo:**
- `scripts/station_prop.gd`: mesa de alquimia y fogata (fogata animada con luz). Mesa en tile [12.7, 34.8]; fogata en [15.3, 35.0], ambas junto al mercader.
- Yunque de Bram: estación `forge` dentro de la casa `forge` (interior).
- `scripts/world_map.gd`: nodos recolectables (`res_nodes`, `add_resource`, `node_near`, `hit_node`, reaparición). Árboles y rocas del mapa son recolectables; 18 arbustos de hierba y bayas en `overworld_nodes`.
- `scripts/mine.gd`: cueva con semilla fija, 9 vetas de hierro, 7 de carbón, 3 de cristal, 6 hongos, 5 guardianes. Entrada en tile [15.5, 20.5]; puerta en [15.5, 22.3].
- `main.gd`: `_build_world_props`, `_gather`/`_gather_tick`/`_gather_hit`, `_use_quick`, `_enter_mine`/`_exit_mine`, `_near_station`, `_near_node`, guardado de planos y herramientas.

**Recolección:** E sobre un recurso. El golpe cae a mitad de la animación de tajo ligero. `tool_power` y `can_gather` controlan la herramienta necesaria (hierro y carbón con pico de piedra; cristal con pico de hierro).

**Objetos nuevos:** herramientas (picos y hachas de piedra, hierro y acero), espadas (hierro, acero, hoja de cristal con `trail` propio) y armadura de hierro en `data/equipment.json`. Iconos en `art/items/build_craft_items.py` (45). Sprites del mundo en `art/map/build_craft_world.py` (12; necesita `build_map.py` en el mismo `ns`).

**Otros datos:** planos en botín de esqueleto, cíclope, mago de tormenta y dragón; carne y piel de conejo y zorro; Tomás vende dos planos (50 y 60 monedas); Bram compra más materiales (`data/shop.json`).

**Tests:**
- `tests/test_crafting.gd`: lógica.
- `tests/test_crafting_world.gd`: integración con el juego real.
- `tests/capture_craft.gd`: capturas en `production/qa/evidence/creacion/` (14 PNG, revisadas).

## 6. Plan aplazado: personaje, razas y equipo
Archivo: `docs/FUTURE_CHARACTER_SYSTEM.md`. Decisiones:
- La **katana y el grimorio actuales son de prueba** para pulir animación y mecánica.
- Al crear personaje solo se elige la parte física (raza, clase, piel, ojos, pelo, tamaño).
- Cuerpo base semidesnudo; la ropa y armas son equipo que se consigue (estilo Dark Souls / Ark).
- Razas comparten esqueleto y silueta.
- **Requisito previo:** mover a datos por personaje `ANIMS`, `FEET`, tiempos, `strike_frame` y puntos de salida del tajo y proyectil (hoy fijos en el código).
- **Regla del usuario:** no empezar hasta que animaciones y mecánicas estén perfeccionadas.
- Hay un registro de pendiente: `astral-sistema-personaje`.

## 7. Lo que queremos a futuro
- **Ajustar valores jugando:** velocidad, daño, postura, duración de la búsqueda; y el sistema de creación (costes, tiempos, drops).
- **Equipo visible completo:** capas de sprite por pieza (requiere render en Blender).
- **Música compuesta de verdad** (la sintetizada es funcional).
- **Mercader que recompre equipo;** casas con más de un interior.
- **Segunda región del mapa.**
- **Runas, invocación y matriz de elementos** del diseño de crafteo (no implementados).
- **Ataques del héroe:** anticipar el golpe, alargar el fotograma de impacto y estela del filo que siga la espada.
- **Animación de golpe recibido** para dragón y mago de tormenta.
- **Personaje creable** (fases en `FUTURE_CHARACTER_SYSTEM.md`).

## 8. Riesgos y no verificado
- **Nada jugado a mano** en las mecánicas nuevas: dash, impacto, sangre, bola de energía, creación, mina, equilibrio.
- Equilibrio de costes, tiempos, drops y precios: iniciales, sin probar.
- Mina: entrada a unas 15 casillas del pueblo (se movió porque bloqueaba la ruta de un aldeano; un test lo detectó). Muros de la mina se dibujan por detrás del héroe. Vetas de hierro y carbón se parecen.
- Commit `2ea25c5` mezcla trabajo ajeno (menú de título, `dash_dust.gd`, `project.godot`, estelas). **Sin resolver** de quién es.
- Krita no se usó en esta sesión: todos los sprites salen de render directo de Blender.

## 9. Próximo paso sugerido
1. Jugar la lista de `docs/PLAYTEST_CREACION.md` y anotar fallos y sensaciones.
3. Pasarme las notas para ajustar `data/crafting.json` y corregir lo que falle.
