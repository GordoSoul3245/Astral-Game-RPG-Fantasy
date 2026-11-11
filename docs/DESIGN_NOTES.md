# Ecos de la Ruina: notas de diseño (para continuar en un chat nuevo)

## Actualización de animación — 9 de noviembre de 2026

Implementado el pulido descrito en `docs/ANIMATION_POLISH.md`: reposo, caminar y correr del héroe con 16 poses en ocho direcciones (`art/hechicero/polished`), apoyos de piernas y fase de marcha por distancia; tajos con tela/torso y ritmo por fotograma conservando tiempos de impacto; reacción y caída del héroe antes de reaparecer; muerte del dragón renderizada desde Blender (sustituye el aplastado provisional mencionado más abajo). Sombra de contacto, texto del HUD más grande y luz cálida suave durante magia/espada ardiente. Generador reproducible: `art/render_polish.py`; pruebas en `tests/test_gait.gd` y `tests/test_animation_integration.gd`.

Lee este archivo y sigue desde "Pendiente". Lo que está escrito aquí es la fuente de verdad; el historial del chat anterior no existe.

## 1. Estado
**Terminado (prototipo jugable):**
- Héroe (hechicero) con caminata/sprint en 8 direcciones, dash con Espacio (invulnerable, atraviesa entidades, no estructuras).
- Katana Ceniza: tajo ligero (clic izq), tajo pesado (clic der), ultimate "Estocada ígnea" (mega dash en llamas, 8 s de espada ardiente).
- Grimorio de Ignis: bola de fuego (básico), esfera ígnea (pesado, área), meteoro (ultimate, marcador 3×3, rango 10 casillas).
- Recursos: vida, maná, estamina (correr/dash/ataques), carga de ultimate (se gana golpeando entidades). Barras arriba a la izquierda.
- Barra de objetos abajo al centro (teclas 1/2 o Q; R = ultimate).
- Dragón: detecta, persigue manteniendo distancia por camino (BFS sobre casillas, recalculado cada 0.25 s en `world_map.gd:next_waypoint`), escupe fuego; 60 HP.
- Mapa de prueba 50×50 casillas: isla, lago, castillo y casa, caminos, árboles y rocas, claro central sin árboles. Colisiones por casillas.

**Dungeon (en curso; pedido del usuario, 3 pisos):**
- HECHO: sistema de puertas (`scripts/door.gd`, tecla E, `locked`/`lock_text`, aviso en pantalla), puerta del castillo → dungeon, piso de 25×25 casillas (`scripts/dungeon.gd`, suelo dibujado por código: arte provisional), puerta de salida, fundido entre mapas. Lógica en `main.gd` (`enter_dungeon`/`exit_dungeon`).
- HECHO (probado en headless, no visto en pantalla): lista `main.enemies` (dragón + monstruos; todo ataque del héroe la recorre), `scripts/enemy.gd` (slime, arquero, cíclope, jefe de rayos según `kind` en `data/creatures.json`), `scripts/zone.gd` (onda del cíclope y rayos), 3 pisos en `data/dungeon.json` (`scripts/floors.gd`: puerta al siguiente piso bloqueada hasta matar todo, cofre al completar, cofre final mejor), botín al morir (XP, monedas, materiales, pociones; también el dragón), `scripts/progress.gd` (nivel, XP, 5 puntos por nivel, 7 estadísticas, equipo), `scripts/menu.gd` (tecla I/Tab: Inventario y Estadísticas), `data/equipment.json` (armaduras, anillos, collares, espadas y grimorios con `mods`). Teclas: E interactuar, H poción.
- Arte de Blender HECHO: cíclope (448 px), slime (128 px, solo idle y salto), esqueleto arquero (128 px) y mago de la tormenta (256 px), todos con 8 direcciones. Scripts en `art/<criatura>/build_*.py` + `art/sprite_common.py` (ayudantes: `exec` el común y luego el de la criatura en el mismo `ns`; abre `blender/hechicero_floor.blend`; `ns['build']()`, `ns['render']([...])`). Se conectan con `"sprites"` (prefijo, `feet`, `kinds`) en `data/creatures.json`; `enemy.gd` sincroniza el fotograma de golpe del ataque con el fin del aviso (cíclope 5, arquero 4, mago 5). Los sprites grandes usan encuadre ×K con los mismos px por metro. Tras añadir PNG nuevos, importa con `Godot --headless --editor --quit --path <proyecto>`.
- Cuello del cíclope (visto de espalda): corregido con cuello/joroba/nuca (el usuario lo pidió).
- Puerta (`art/door`, 224 px, 6 fotogramas: la hoja se recoge) y cofre (`art/chest`, 128 px, 6 fotogramas: la tapa se abre) también en Blender. Se renderizan con giro fijo `tile_yaw()` (en `sprite_common.py`): el suelo del juego tiene su propia proyección y las aristas de casilla no coinciden con los ejes de Blender, así que se gira ~94.4° para que el borde inferior quede paralelo al borde del suelo. Las puertas se colocan a 0.25 casillas del borde (su fondo es 0.5 m) para que su cara trasera toque el borde. `door.gd` y `chest.gd` dibujan esas imágenes (el piloto rojo de "bloqueada" sigue siendo código).
- Objetos de los cofres: 13 iconos de Blender de 128 px en `art/items/<id>.png` (mismo id que `data/equipment.json`; script `art/items/build_items.py`, usa `IconCam`; `render_one(id)` / `render_all()`). El inventario los muestra en el equipo y en la lista; al abrir un cofre aparecen sus iconos sobre el aviso (`main.show_loot`). Para un objeto nuevo: añade su entrada en `equipment.json`, un caso en `build_item` y renderiza su icono.
- Menú rediseñado (`scripts/menu.gd`, tecla I/Tab): Inventario = equipo como muñeco de ranuras + mochila en cuadrícula (16 casillas, marcos por rareza: Común gris-verde, Raro azul, Épico dorado; "E" = equipado; clic ve el detalle, doble clic equipa) + panel de detalle con comparación contra lo equipado (▲/▼) y botón Equipar/Quitar; Estadísticas = tarjeta de nivel con barra de XP + tabla de puntos. Capturas de prueba: se puede automatizar con un script `-s` que guarda `get_viewport().get_texture().get_image()`.
- No hay arte del equipo puesto sobre el héroe (los objetos solo dan estadísticas). Pendiente de arte: nada obligatorio.
- Notas de diseño: pisos 1 y 2 usan los mismos monstruos (piso 2 con uno más de slime y de arquero); piso 3 solo 2 cíclopes y el jefe; salir de la dungeon conserva el piso alcanzado; completar el cofre final reinicia en el piso 1. Las espadas/grimorios del cofre dan bonos de estadísticas (no cambian los ataques). "Resistencia" = estamina máxima; vida máxima sube +10 por nivel.
  - El usuario pidió: si el uso de tokens llega al 98 %, pasar a Codex todo el contexto, el pedido y las imágenes, manteniendo el estilo y la forma de trabajo.

**Pendiente / conocido:**
- **Hecho (2026-11-10):** pueblo junto al inicio (2 casas y puesto del mercader, generados con `art/map/build_map.py`; `VILLAGE`), reaparición en el pueblo al morir, cadena de 5 misiones con Elda (`data/quests.json`, `scripts/quests.gd`; `[E]` para hablar), mercader de pociones, guardado/carga en `user://save.json` (nivel, estadísticas, equipo, monedas, piso y misión; autoguardado cada 20 s y en hitos), fauna golpeable (conejos y zorro, `main.targets()`) y estructuras translúcidas cuando tapan al héroe (`world_map.gd: covers_hero`). Tests: `test_town.gd`, `test_fauna.gd`, `test_perception.gd`, `test_pressure.gd`, `test_buffer.gd`.
- **Hitboxes (2026-11-11):** `scripts/hitbox.gd` mide la silueta real de cada sprite (elipse por dirección centrada en la masa de píxeles) para héroe, dragón, monstruos, fauna y NPC. Tajos (desde el pecho), proyectiles (a la altura de la bola), mega dash, meteoro y explosiones se miden contra ella; el daño en el suelo usa la huella (elipse aplastada ×0.6). Estructuras: rectángulos de casa/castillo/puesto del tamaño del zócalo y follaje de árboles que frena proyectiles (`pcircle`). **F2** dibuja las hitbox. `art/map/build_map.py` genera todo (`FOOTPRINT_MARGIN`).
- **Tienda (2026-11-11):** `scripts/shop.gd` + `data/shop.json`. Tomás (puesto) vende pociones y equipo de tier 1-2; Bram (junto a la casa) compra materiales de monstruos. Panel con el juego en pausa.
- **Misiones:** 10 en cadena (`data/quests.json`); eventos `kill`, `floor` y `loot`. **Piso 4 opcional** (`data/dungeon.json`): cofre final con +3 puntos de estadística; el piso 3 ya no reinicia la dungeon.
- **Test de humo con bot** (`tests/test_playthrough.gd`, ejecutar con `--fixed-fps 60`): recorre los 4 pisos en ~137 s de juego sin morir. El bot apunta perfecto y no esquiva; úsalo para detectar atascos, no para balance fino. Con él se ve que XP y monedas llegan muy rápido (nivel 12 y ~1500 monedas al final).
- **Balance (2026-11-11):** `data/dungeon.json` `scale` (vida/daño por piso: 1.0/1.0, 1.3/1.15, 1.6/1.3, 1.9/1.4); `main.gd` `REWARD_XP = 0.8`, `REWARD_COINS = 0.7`. El bot (con esquiva básica, gasto de puntos y compras) recorre los 4 pisos en ~130-190 s con 0-1 muertes; los límites del test son 15 muertes y 900 s.
- **Opciones y sonido:** pestaña Opciones del menú (`settings.gd`, `user://settings.json`): temblor, destellos, pausa de impacto y volúmenes (buses SFX/Music). `music.gd` sintetiza por código un tema por zona, un ambiente y una capa de combate sincronizada (no hay archivos de audio; el generador externo pide suscripción de nivel 2).
- **Combate nuevo:** *esquiva perfecta* (un golpe durante el dash da +12 ultimate, +15 maná, +25 estamina; cooldown 0.6 s; el mega dash no cuenta), *maná por golpe de espada* (+4 ligero, +10 pesado, tope 14 por tajo), *bonus tras dash* (+30 % al siguiente tajo en 0.5 s) y *postura* de élites (cíclope 70, mago 90; ligero 8, pesado 30, magia 12, explosión 24; al llenarse quedan 2.2 s abiertos, no actúan, cancelan su zona y reciben x1.5; la barra amarilla se regenera tras 2 s sin golpes). Test: `test_combat_ext.gd`.
- **Movimiento (2026-11-11):** caminar 100 px/s y correr 200 (antes 90/190); inercia (`ACCEL` 900, `BRAKE` 1500 px/s²); se puede caminar mientras atacas (x0.5 ligero, x0.2 pesado, x0.35 hechizo; sin girar ni cortar); caminar corta la recuperación de un tajo ligero ya conectado (0.08 s tras el impacto; el pesado no se corta); el dash frena al final (misma distancia, curva 1.75→0.25); sprint más barato (`sprint_drain` 16). Test: `test_movement.gd`. Todos los valores son constantes en `main.gd` o `creatures.json`, para ajustarlos jugando.
- **Ataques y jefe (2026-11-11):** dragón con ráfaga de 3 (la 2.ª en abanico) y 3 s sin aliento (x1.5 de daño); arquero con abanico cada 3.er tiro (3 líneas de aviso, más recuperación); mago con corona de 6-8 orbes cada 5.º hechizo; cíclope que embiste desde lejos (pasillo rojo, carrera recta, daño una vez, recuperación larga). Test: `test_attacks.gd`.
- **Interiores y diálogo:** las dos casas del pueblo se visitan (`data/interiors.json`, `scripts/interior.gd`: sala dibujada por código, muebles con colisión y profundidad). Mara (casa de Bram) y Teo (antiguo aventurero, da consejos de combate) hablan según el estado del mundo (`data/dialogue.json`, condiciones `dragon_alive`/`dragon_dead`/`fox_alive`/`deep`). Cuadro de diálogo con pausa y texto progresivo (`scripts/dialogue.gd`); Elda también lo usa. Test: `test_interior.gd`.
- **Equipo visible (versión ligera):** la armadura tiñe la ropa del héroe (`self_modulate`), la espada cambia el color del tajo y collar/anillo dan un brillo tenue (`_equip_look`). Las capas de sprite reales del equipo quedan pendientes: requieren renderizar en Blender todas las animaciones del héroe por pieza.
- Pendiente: sin probar jugando por una persona; no hay interior de casas; el mercader no recompra equipo; sin música compuesta (la sintetizada es funcional, no sustituye a una pista real).
- Animaciones nuevas (procedurales, no de Blender): la bola de fuego usa la anim `cast` y el dragón se aplasta y se desvanece al morir.

## 2. Brief del juego (resumen)
"Ecos de la Ruina": RPG de acción isométrico de fantasía. Bucle: aceptar misión en el pueblo → explorar y pelear → dungeon y jefe → volver con botín y mejorar equipo. Fallo: vida a 0 → reaparece en el pueblo y la misión sigue. MVP completo en `docs/GAME_BRIEF.md`.

## 3. Decisiones de diseño (valores fijos)
- **Cámara:** ortográfica de los sprites, 2.75 m de encuadre a 128 px; pitch ~65°, yaw ~31° (no es 2:1 clásica). Todos los sprites de personajes y objetos usan esta cámara; hay que renderizarlos con ella.
- **Escala en juego:** `SCALE = 3.0` (un sprite de 128 px se muestra a 384 px).
- **Tamaños:** héroe ~2.05 m de alto; dragón 1.0 m (la mitad).
- **Movimiento:** caminar 90 px/s, sprint 190 px/s, aplastado en Y por 0.6 (vista isométrica).
- **Mapa:** casillas de 1 m; rombo de 50×50 casillas definido por `c1/e1/e2` en `data/map.json`.
- **Estilo:** sombreado cel (4 bandas), paleta índigo/oro/rojo; materiales copiados de la base "Cel •" en Blender.
- **Costes y valores:** en `data/items.json` y `data/creatures.json`, no en el código.

## 4. Dónde vive cada cosa
- **Escenario principal:** `scenes/main.tscn` → `scripts/main.gd` (héroe, input, ataques, recursos, barras, dash, ultimates, cámara).
- **Entidades y proyectiles:** `scripts/dragon.gd`, `scripts/projectile.gd`, `scripts/meteor.gd`, `scripts/slash_trail.gd`, `scripts/tile_marker.gd`.
- **Mapa y colisiones:** `scripts/world_map.gd` (lee `data/map.json`).
- **Datos:** `data/items.json`, `data/creatures.json`, `data/inventory_test.json`, `data/map.json` (generado).
- **Arte (Blender/Krita, scripts reproducibles):**
  - `art/dragon/build_dragon.py`: modelo, poses y render del dragón.
  - `art/katana/build_katana.py`: katana, tajos, dash, mega dash y render del hechicero.
  - `art/map/build_map.py`: terreno, objetos, sprites del mapa y `data/map.json`.
  - `art/grimorio/paint_krita.py`: tapa del grimorio (Krita).
- **Archivo de Blender:** `blender/hechicero_floor.blend` (escena con el hechicero y el rig `HECHICERO_RIG`).

## 5. Cómo regenerar y probar
- **Mapa:** en Blender, `ns={}; exec(open('art/map/build_map.py').read(), ns)`, luego `layout()`, `build_ground()`, `render_ground()`, `build_objects()`, `render_sprites()` y `export_map()`.
- **Dragón:** `build_dragon.py` → `build()` y `render(...)`.
- **Katana/hechicero:** `build_katana.py` → `render_slash`, `render_cast`, `render_dash`, `render_megadash`, `render_icon`.
- **Probar en Godot 4.7:** `Godot_v4.7.2-stable_win64_console.exe --path <proyecto>`; para probar sin ratón, usa un gancho temporal y quítalo después.
- **Regla:** no edites `data/map.json` a mano; se regenera desde `build_map.py`.
- **Combate:** `tests/test_combat.gd` (headless) y `tests/capture_combat.gd` (sin `--headless`, capturas en `docs/previews/`).

## 5b. Combate e iluminación
- Todo daño del héroe pasa por `combat.hit()` (scripts/combat.gd): sonido, chispa, luz y empuje por tipo (ligero/pesado/magia/explosión).
- Enemigos: dirección fijada al avisar, `recover` castigable, `knock_resist`/`staggerable` en `data/creatures.json`; jefes no se interrumpen.
- Marca de Ignis: el fuego del grimorio marca 4 s; el tajo pesado de la katana la consume y explota (sin cadenas). `data/items.json` → `grimorio_ignis.mark`.
- Luz: CanvasModulate por zona + PointLight2D locales; sin sombras (sprites con luz horneada). Detalle en `docs/COMBAT_LIGHTING_REPORT.md`.

## 6. Preferencias del usuario
- Español, tono directo.
- Cambios de diseño consistentes con lo ya hecho (misma cámara, escala y estilo).
- El mapa actual es de **prueba para mecánicas**, no de producción.
