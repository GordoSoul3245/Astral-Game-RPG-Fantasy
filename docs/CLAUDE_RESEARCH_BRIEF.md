# Guía de lectura y aplicación para Claude Code

## Encargo recibido

El usuario pidió investigar quince de los mejores sistemas de combate y movimiento para héroe, NPC, monstruos y animales; explicar por qué funcionan, qué gusta, críticas, patrones repetidos y cómo adaptarlos a su juego. Esta entrega es investigación y transferencia de conocimiento. No interpretar cada propuesta como una orden de implementación ni como evidencia de gustos de toda la comunidad.

## Prompt listo para copiar

> Trabajamos en Ecos de la Ruina, Godot 4.7.2, en C:/Users/Mateo/Documents/astral. Lee docs/RESEARCH_15_COMBAT_MOVEMENT_SYSTEMS.md completo y usa docs/DESIGN_NOTES.md, docs/GAME_BRIEF.md, docs/ANIMATION_POLISH.md y docs/COMBAT_LIGHTING_REPORT.md para contrastarlo con la implementación. Asimila las decisiones como contexto de esta sesión; no afirmes que entrenaste tu modelo ni que recordarás automáticamente el documento en otros chats. Antes de implementar, identifica qué ya existe y qué pedido concreto está autorizado en el mensaje actual. Respeta cambios locales y no reescribas controles táctiles/exportación ajenos al trabajo. Para cada propuesta elegida, explica la sensación buscada, su coste, su conflicto con otras reglas y una prueba observable. Conserva estilo/cámara/escala. No edites data/map.json a mano. No copies los quince sistemas completos. No hagas push solo por leer este informe: la publicación depende del encargo activo.

## Quince referencias y lección principal

| Referencia | Aprender | Evitar importar por defecto |
|---|---|---|
| Hades | Pocos verbos, movilidad y combinaciones expresivas | Roguelite completo y multiplicación de efectos |
| Hyper Light Drifter | Posicionamiento preciso y ataques legibles | Obstáculos/collisiones ambiguos |
| Dead Cells | Interpretar intención con ayudas discretas | Colas largas de acciones involuntarias |
| Dark Souls | Compromiso y oportunidades | Estamina que solo ralentiza o bloquea todo |
| Bloodborne | Recuperación que incentiva iniciativa | Curación infinita o premiar recibir daño |
| Sekiro | Defensa que hace avanzar el combate | Parry obligatorio para todas las builds |
| Monster Hunter: World | Criaturas observables y peso | Vida enorme y persecución sin decisiones |
| Devil May Cry 5 | Varias soluciones y dominio expresivo | Docenas de inputs y animaciones prematuros |
| DOOM Eternal | Acciones que reabastecen recursos | Rotación de mantenimiento obligatoria |
| Batman: Arkham Asylum | Flujo al cambiar amenazas | Autoacercamiento que sustituye apuntado |
| Zelda: Breath of the Wild | Reglas consistentes y experimentación | Simulación combinatoria de materiales |
| Celeste | Tolerancia temporal y espacial | Correcciones que atraviesan paredes |
| Rain World | Intereses propios de criaturas | Encuentros emergentes inevitables |
| Red Dead Redemption 2 | Miradas, pausas y presencia corporal | Inercia lenta en el héroe de acción |
| The Last of Us Part II | Percepción, búsqueda y señales sociales | IA omnisciente disfrazada de búsqueda |

Cada fila resume una interpretación de diseño. Las mecánicas verificadas, críticas y enlaces están en el informe largo. No usar la tabla como prueba de algoritmos internos de los juegos.

## Estado que no debe duplicarse

- `scripts/main.gd`: héroe, ataques, dash, recursos, animación y cambio de mapas. Hay modificaciones locales y controles táctiles; leer estado de Git antes de editar.
- `scripts/combat.gd`: daño del héroe centralizado en `hit`, chispas, audio sintetizado, luces, empujes, marcas de Ignis y detonación.
- `scripts/enemy.gd`: roles, dirección de tiro fijada durante preparación, recuperación, resistencia a empuje/interrupción.
- `scripts/dragon.gd`: comportamiento propio, no idéntico al enemigo genérico; muerte articulada y reset.
- `scripts/projectile.gd`, `meteor.gd`, `zone.gd`: rutas de daño y geometría peligrosa; revisar todos los callers antes de modificar contratos.
- `scripts/world_map.gd`: movimiento con colisión y búsqueda de camino; no sustituirlo sin una necesidad demostrada.
- `data/items.json`, `creatures.json`: valores de ataques/criaturas; marca de Ignis tiene duración, radio y daño configurados.
- `art/render_polish.py`: sprites del héroe con piernas resueltas, reposo, locomoción y ataques. El juego usa PNG renderizados, no un esqueleto 3D animable en runtime.
- `tests/test_combat.gd`, `test_gait.gd`, `test_animation_integration.gd`: conservar contratos y extender cuando una nueva regla lo requiera. El reporte previo indica PASS; la investigación no volvió a ejecutarlos.

## Prioridad recomendada si el usuario autoriza implementación

1. Diagnosticar con la sala actual y una prueba formativa: respuesta, salida de dash, colisiones, legibilidad, marca y recuperación. Resolver fallos observados primero.
2. Prototipar una sola acción en buffer y cancelaciones explícitas; comparar contra la versión actual sin cambiar simultáneamente daño/velocidad.
3. Controlar presión de encuentros y construir percepción con última posición conocida. Reutilizar estados existentes antes de introducir una arquitectura nueva.
4. Crear una presa y un civil con actividades, observar, huir y volver. Los NPC y animales aún necesitan datos/arte y navegación válida.
5. Agregar territorialidad/depredador si el paso anterior aporta vida con coste aceptable.
6. Postergar postura universal, parry, combos largos, ecosistema persistente y materiales complejos hasta tener evidencia.

Números como buffer 100 ms, pausa de impacto 25–40 ms, decisiones 5–10 Hz y dos preparaciones simultáneas son puntos de partida experimentales. No son mediciones de Hades/Dead Cells ni valores ya aprobados para Astral.

## Reglas de implementación que protegen lo existente

- Cada pulsación se consume como máximo una vez; muerte, menú y transiciones invalidan acciones pendientes.
- Conservar instante del impacto al cambiar duración de poses. Si cambian índices, actualizar datos, efectos y tests conjuntamente.
- Un enemigo muerto no dispara y una zona cancelada no daña. Una detonación no duplica experiencia, botín ni carga de ultimate.
- Definir si preparación puede corregir puntería y en qué momento queda fijada. No ocultar esa regla tras una animación incongruente.
- Preparar, ejecutar y recuperar usan el mismo reloj lógico; no hacer que un hitstop deje avanzando daño invisible.
- Las coordenadas de suelo/casilla son la fuente de movimiento, alcance y caminos; SCALE y proyección corresponden a presentación.
- Navegación no sustituye colisión ni evasión. Primero aprovechar `move_collide` y `next_waypoint`.
- Sospecha/alerta se basan en eventos percibidos. Buscar última posición vista sin consultar continuamente al héroe escondido.
- Una presa necesita refugio alcanzable y tiempo mínimo de estado para no oscilar; territorio usa umbrales diferentes de entrada/salida.
- Ruido y variación se usan para personalidad; no para ataques impredecibles sin aviso.
- Mantener opciones de reducir destellos/temblor y no depender solo del color para marcar amenazas.

## Qué entregar al terminar una futura implementación

Diff acotado, pruebas de las nuevas reglas, capturas/vídeo o escena reproducible, informe honesto sobre lo que no se pudo observar, y actualización del diseño. Validar subjetivamente con personas; tests headless no escuchan audio ni demuestran que el combate sea divertido. El alcance actual sigue siendo una región con dungeon y progresión persistente.

Este paquete es contexto legible para Claude; debe adjuntarse o indicarse su ruta en una sesión futura. No se envió a otra sesión ni se inició una implementación durante esta investigación.
