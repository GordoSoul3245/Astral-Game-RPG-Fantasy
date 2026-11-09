# Traspaso a Claude Code: Ecos de la Ruina

## Pedido activo y autorización

El usuario pidió: «okey haz el 2, 3 y 4, tambien quiero un sistema de iluminacion mas realista, luego sube el juego al repositorio de recien, si llegas al 94% de uso de tokens, pasale el trabajo a claude code, pasale todo junto en un resumen tanto el contexto y la investigacion que hiciste y lo que venimos trabajando mas lo que estamos haciendo ahora.»

2 = impactos con sonidos, reacción enemiga, empuje donde corresponda y efectos distinguibles entre ligero/pesado/magia.
3 = preparación clara de ataques enemigos, áreas precisas, recuperaciones castigables.
4 = Ignis deja marca temporal; pesado de katana consume marca y provoca pequeña explosión. Implementar una interacción concreta, equilibrada y visible.
También iluminación más realista/dinámica compatible con sprites cel y GL Compatibility. Terminar, probar, documentar, commit y push a origin/main. La publicación está explícitamente autorizada.

## Estado actual

Proyecto Windows: C:/Users/Mateo/Documents/astral. Godot 4.7.2; ejecutable C:/Users/Mateo/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe.
Git limpio al inicio de esta tarea, HEAD af1fe7b. origin https://github.com/GordoSoul3245/Astral-Game-RPG-Fantasy.git. Cuenta Git Credential Manager GordoSoul3245, selección local credential.https://github.com.username ya configurada. Push anterior comprobado; no pedir autorización otra vez. No force-push.
En esta tarea solamente se leyeron enemy.gd, projectile.gd y zone.gd; todavía no se modificó la jugabilidad. Este documento es el primer archivo nuevo.

## Fuentes de verdad y contexto completo

Leer docs/DESIGN_NOTES.md y docs/GAME_BRIEF.md. Investigación de este chat en docs/RESEARCH_DESIGN_2026-11-09.md (fuentes oficiales Godot, Heart Machine, Supergiant y Motion Twin; catálogo de mecánicas y prioridades). Revisión visual previa en docs/VISUAL_REVIEW_2026-11-09.md. Trabajo de animación final en docs/ANIMATION_POLISH.md y capturas docs/previews/.
Juego: RPG de acción isométrico, un jugador, pueblo → explorar → dungeon/jefe → mejorar equipo. Hoy exterior de prueba, dungeon de 3 pisos, combate, progresión e inventario. No implementar pueblo/quest en este pedido.
Español, tono directo. Cámara y paleta existentes, SCALE=3, sombreado cel 4 bandas índigo/oro/rojo. No editar data/map.json a mano: generado por art/map/build_map.py. No convertir a 3D ni añadir dependencias innecesarias.

## Trabajo terminado en este chat

Se investigó y luego se implementó reposo real, locomoción de 16 poses en 8 direcciones, apoyos con solución de dos huesos y desplazamiento de cadera; fase de marcha por distancia preservada al girar. Nuevo arte en art/hechicero/polished. Render reproducible art/render_polish.py usando Blender en segundo plano. Mantiene originales y no guarda sobre blend fuente.
Ataques con tela/torso y duración desigual por fotograma conservando instante del impacto y duración total. Reacción del héroe 0,2s fuera de ataque y muerte de 12 poses antes de reaparecer. Muerte hero192px offset(-32,-32), dragón160px offset(-16,-16), misma escala física. Dragón ya tiene muerte articulada y reset cancela tweens.
Sombra de contacto del héroe, HUD más grande, spell_light PointLight2D cálida que entra/sale al castear o arder katana. Esta luz es solo un inicio; ampliar coherentemente iluminación.
752 imágenes héroe, 96 muerte dragón. Tests pasaron: tests/test_gait.gd, tests/test_animation_integration.gd; tests/capture_polish.gd genera capturas reales. Hubo corrección visual de pies fuera del alcance y recorte de muerte, ya resuelta.

## Puntos de implementación relevantes

scripts/main.gd concentra entrada, ataques, daño, cámara, UI, cambio de mapa. _strike recorre main.enemies y llama take_damage; current_mode distingue pesado. _begin y _on_hero_frame sincronizan strike_frame/trail_frame. damage_hero gestiona reacción/respawn. Proyectiles en scripts/projectile.gd llaman e.take_damage tanto impacto directo como AoE. Meteoro tiene otra ruta: revisar todos los callers con rg antes de centralizar feedback o marcas.
Enemigos dungeon en scripts/enemy.gd, dragón en scripts/dragon.gd: ambos exponen alive,pos,radius,hp,take_damage. No asumir que dragón tiene las mismas propiedades que enemy. Botín y ultimate no deben duplicarse al detonar marca.
enemy.gd: archer prepara en windup, al disparar vuelve inmediatamente chase, dirige flecha hacia posición actual del héroe; mage similar. brute tiene recover 0,7s y crea zone al comenzar windup. Sincronización de fotogramas: archer4, brute5, mage5. Revisar recuperación y dirección fijada al telegráfico para evitar ataques injustos; si se añade interrupción, cancelar zonas pendientes apropiadamente.
zone.gd dibuja elipse y daño calcula Vector2(d.x,d.y/0.6). Mantener igualdad entre aviso y colisión. Actualmente shake global incluso lejos: mejorar si corresponde.
enemy.take_damage ya tiene flash y fade al morir; agregar reacción/knockback sin romper límites del mundo ni interrumpir indefinidamente jefes. Estados actuales idle/chase/windup/recover.
projectile.gd: source hero/dragon/enemy, speed/radius/damage/aoe. Impacto directo y AoE separados; marca debe asignarse a enemigos sobrevivientes una vez. Especificación de ataques en data/items.json, criaturas en data/creatures.json; priorizar valores externos.
Iluminación: PNG incluyen luz horneada, no sobreiluminar ni prometer normales inexistentes. Emplear ambiente por zona, luces locales de fuego/proyectiles/rayos, sombras/oclusores donde correspondan a geometría real. UI debe seguir legible. Conservar Compatibility. Probar visualmente al menos exterior/dungeon/magia.

## Validación y entrega

Hacer tests significativos: marca aplica/refresca/caduca, pesado consume una vez, explosión no encadena infinitamente ni duplica botín, enemigos muertos no actúan, recover se cumple, telegráfico y daño coinciden, luces se limpian entre mapas. Reejecutar tests de animación/gait si afectados. Capturas con viewport renderizado, no headless para validar visuales. El teclado de herramienta de escritorio no funcionó antes; scripts de prueba Godot son alternativa válida para escenas/capturas.
Ejemplo: Godot --headless --path . --quit-after 600 -s tests/test_animation_integration.gd. Importar nuevos assets con --headless --editor --quit.
Guardar reporte final breve en docs con cambios/pruebas/limitaciones. Actualizar DESIGN_NOTES. Revisar git diff, git diff --check, commit y push origin main, verificar SHA remoto. No incluir logs/caché (.gitignore ya los excluye).
No se requiere repetir investigación web salvo incertidumbres nuevas. Evitar inflar alcance. No afirmar que se hicieron pruebas manuales prolongadas si solo hubo tests/capturas.

## Continuidad

Lista claude-mem combat-lighting: tarea «Impactos, lectura enemiga, sinergia Ignis, iluminación y push» en doing. Mantener estado si herramientas disponibles. Responder al usuario en español. Completar todo el pedido, no quedarse en plan. Si algún bloqueo real impide seguir, dejar estado exacto y evidencia.
