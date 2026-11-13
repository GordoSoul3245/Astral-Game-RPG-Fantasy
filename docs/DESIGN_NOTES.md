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

## 5c. Creación: crafteo, forja, cocina y alquimia
- **Datos:** `data/crafting.json` (materiales, consumibles, planos, recetas, estaciones, recolección, props del mundo y mina). Lógica pura en `scripts/crafting.gd` (probada en `tests/test_crafting.gd`); integración con el juego real en `tests/test_crafting_world.gd`.
- **Inventario unificado:** materiales, comida y pociones viven en `prog.materials`; la poción de vida sigue en `prog.potions` (tecla H). Planos en `prog.blueprints` (guardados). Bonus temporales en `prog.buffs`; tecla **G** usa el consumible elegido en la pestaña Crafteo.
- **Crafteo a mano** (pestaña *Crafteo* del menú): herramientas de piedra, cuero, frascos y armadura de cuero. **Forja** (yunque de Bram, dentro de su casa): lingotes, picos, hachas, espadas y armadura de hierro. **Cocina** (fogata junto al mercader): comida con curación y bonus. **Alquimia** (mesa junto al mercader): planos + ingredientes colocados uno a uno + animación; los planos no se gastan y un catalizador duplica el resultado.
- **Planos:** el inicial es de la poción de vida; Tomás vende dos; los otros caen de esqueleto, cíclope, mago de tormenta y dragón (`drops` en `data/creatures.json`).
- **Recolección:** E sobre árboles, rocas, vetas, plantas y hongos; el golpe cae a mitad de la animación del tajo ligero. Herramienta por nivel (`tool_power`): hierro y carbón exigen pico de piedra; el cristal arcano, de hierro. Los recursos se agotan, dejan de bloquear y vuelven a crecer.
- **Mina:** entrada al norte del pueblo; cueva generada con semilla fija (`scripts/mine.gd`), 9 vetas de hierro, 7 de carbón, 3 de cristal, 6 hongos y 5 monstruos.
- **Arte:** iconos con `art/items/build_craft_items.py`; objetos del mundo con `art/map/build_craft_world.py` (necesita `build_map.py` en el mismo `ns`).
- **Capturas de revisión:** `production/qa/evidence/creacion/` (`tests/capture_craft.gd`, sin `--headless`).
- **Pendiente de jugar:** equilibrio de costes y tiempos, y que la mesa y la mina se sientan bien de recorrer.

## 6. Preferencias del usuario
- Español, tono directo.
- Cambios de diseño consistentes con lo ya hecho (misma cámara, escala y estilo).
- El mapa actual es de **prueba para mecánicas**, no de producción.


## Pesca (estilo Stardew Valley)
- Caña en la barra de objetos (`cana_madera`, `cana_hierro`, `cana_cristal`; ranura `rod`). Tomás vende la de madera; las otras se forjan (la de cristal pide un pez cristal).
- Mantener el clic carga la fuerza; soltar lanza hacia el cursor. Debe caer en agua (cualquier casilla fuera de la isla, `world_map.is_water`). Más lejos = peces más raros (`min_tiles`), y la caña limita cuáles (`min_rod`).
- Espera el pique (2.5–7 s menos 0.3 s por nivel de caña) con tirones falsos; al picar aparece «!» y hay unos 0.8 s para hacer clic. Clic antes de tiempo recoge el sedal. Dash, Esc, cambiar de objeto o recibir daño también cancelan.
- Minijuego (`fish_game.gd`): mantener el clic sube la barra, soltar la deja caer; el pez se mueve según su patrón (`mixed`, `dart`, `smooth`, `sinker`, `floater`) y la dificultad. Progreso +0.22/s dentro y −(0.12 + dif·0.1)/s fuera. Pesca perfecta (nunca lo pierdes) = un pez extra. La caña da barra más larga (+0.05 por nivel).
- Datos: `data/fishing.json`. 9 peces + alga marina (basura, 12 %). Se cocinan (pescado asado, sopa, brocheta de anguila, sashimi de pez lanza), se destilan (elixires de marea y de ceniza con planos de Tomás) y Bram los compra.
- Pesca perfecta ya no da un pez extra: da **calidad** (ver abajo).
- Test: `tests/test_fishing.gd`. Capturas: `tests/capture_fishing.gd` → `production/qa/evidence/pesca/`.

## Pesca ampliada (reloj, cebos, calidad, cofres, libro, acuario, nasas y encargos)
- **Reloj** (`scripts/clock.gd`): un día = 8 min reales, arranca a las 9:00. Tinta el ambiente exterior (`combat.gd`), llueve el 25 % de los días (gotas en pantalla) y se muestra en la HUD. Se guarda (`clock`). Dentro de casas, mina y dungeon no oscurece ni llueve (`clock.outdoors`).
- **Peces por hora y clima** (`when` en `data/fishing.json`): anguila luminosa y pez abisal solo de noche (20:00–6:00); pez lanza y pez cristal solo con lluvia. Con lluvia el pique llega un 25 % antes.
- **Cebos** (tecla **B** con la caña en la barra): gusano (−40 % de espera), baya (peces raros ×1.7), carne (raros ×2.3 y −20 % de espera). Se gastan al lanzar. Se fabrican a mano con hierba vital, bayas y carne de conejo.
- **Calidad** (`prog.stars`, subconjunto de `materials`): pesca perfecta = ★; perfecta y de las grandes (80 % del rango de tamaño) = ★★. Se vende +25 % / +50 % (`shop.sell_value`) y un plato cocinado con pescado de calidad sale de calidad y cura +25 % / +50 %. Al cocinar y comer se gasta primero lo mejor; al gastar sin más, lo normal.
- **Cofre del fondo:** en el minijuego aparece a veces (14 % + 4 % por nivel de caña) un cofre en la pista; mantener la barra sobre él llena su medidor dorado. Botín por peso en `treasure.loot` (monedas, cristales, lingote de acero, pociones, un plano que no conozcas, un anillo).
- **Libro de capturas** (`scripts/angler.gd`, pestaña *Pesca* del menú): especies, veces y récord de tamaño/calidad; hitos a 3, 6 y 9 especies con recompensa.
- **Acuario** (misma pestaña; no es un mueble de la casa): hasta 6 peces vivos; cada día producen materiales (`aquarium.yield`) que se recogen en la pestaña.
- **Encargos diarios:** Bram y Tomás piden cada día un pescado distinto (`orders`); botón en su panel de tienda, uno por día y comerciante.
- **Nasas y trampas** (`scripts/traps.gd`, objetos de la barra): la nasa va en la orilla (pesca sola 4 h de juego), la trampa en tierra (carne y piel de conejo, 3 h); máximo 3; se recogen solas al pasar cerca. Se guardan con la partida.
- **Comida duradera:** los platos de pescado dan además regeneración de vida (`regen`). Cada día hay un **plato favorito** (`crafting.favorite_dish`): sus efectos ×1.5 y los bonus duran el doble.
- Tests: `tests/test_angling.gd`. Capturas: `tests/capture_angling.gd` → `production/qa/evidence/pesca_plus/`.
- Ideas medianas y grandes pendientes: `docs/IDEAS_FUTURAS.md`.
- **No hecho / por probar:** nada de esto se jugó a mano; el equilibrio (tiempos, precios, probabilidades) es inicial. La nasa y la trampa se dibujan con formas simples (sin sprite propio) y los iconos de cebos son sencillos. Las trampas de caza no cazan otra cosa que conejo.

## Mundo vivo y barra editable (tercera tanda)
- **Barra de objetos editable** (`prog.slots`, 6 casillas, `main.hotbar_drop/hotbar_clear/hotbar_add`): al abrir el inventario (**I**) la barra aparece bajo el panel. Se arrastra cualquier objeto utilizable (armas base, herramientas que tengas, consumibles) desde la mochila a una casilla; si estaba ocupada se intercambian (o el desplazado vuelve a la mochila). Arrastrar de una casilla a la mochila la vacía. Una herramienta soltada en la barra pasa a ser la equipada; las herramientas nuevas entran solas en el sitio de la anterior o en la primera libre. Casilla vacía = «Manos libres». Las armas base quitadas de la barra aparecen en la mochila. Guardado en `slots`; las partidas antiguas (`hand`) se migran. Botones «A la barra» del menú y del crafteo siguen funcionando.
- **Sombras y farolas:** `clock.dark()` y `clock.shadow()`; la sombra del héroe se alarga e inclina con el sol y se aclara con la luna (solo la del héroe). Farolas (`scripts/lamps.gd`) en las puertas de las casas y junto a los comerciantes: se encienden al anochecer o con lluvia.
- **Dormir y acuario en la casa de Teo:** cama (E: salta hasta las 7:00, cura todo y guarda; solo de noche) y pecera con los peces del acuario nadando (E abre la pestaña Pesca).
- **Tienda de Tomás:** cebos (paquetes de 5), nasa, trampa y los planos de los elixires nuevos (`qty` en `data/shop.json`).
- **Mejoras de caña:** carrete (forja: barra más larga y medidor ×1.25) y sedal trenzado (a mano con alga: +1 casilla de lanzamiento y +0.3 s para clavar); se instalan desde la pestaña Pesca y valen para cualquier caña.
- **Cocina y alquimia con pescado:** estofado marino, parrillada dorada, pastel de cristal y caldo abisal; elixir de visión nocturna (la noche se ve clara) y elixir de sirena (peces raros y pique más rápido).
- **Sonidos de pesca** sintetizados (`combat.CUES`: lanzar, chapuzón, pique, clavar, captura, cofre, dormir).
- Tests: `tests/test_hotbar.gd`, `tests/test_world_life.gd`. Capturas: `production/qa/evidence/mundo_vivo/` (`tests/capture_world_life.gd`).
- **No hecho / por probar:** el arrastre real con el ratón no se probó a mano (el test llama a las funciones de arrastre). Las sombras solo afectan al héroe. Los iconos de nasa/trampa se usan también como sprites del mundo. Los sonidos son sintéticos y simples.
