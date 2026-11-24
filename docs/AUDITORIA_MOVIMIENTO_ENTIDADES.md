# Movimiento de personajes, monstruos y entidades · auditoría del 24 de noviembre

Revisión de código (sin jugar) de `scripts/main.gd` (héroe), `enemy.gd` (monstruos, semijefes y jefes), `zone.gd`, `projectile.gd`, `critter.gd` (conejos), `predator.gd` (zorro), `villager.gd`, `pet.gd`, `dragon.gd` y `world_map.gd` (colisión y caminos). Complementa `AUDITORIA_MOVIMIENTO_COMBATE.md` e `INVESTIGACION_Y_AUDITORIA_2026-11-21.md`.

## Qué dice el género (resumen)

- **Ataque en tres fases:** aviso, golpe y recuperación castigable; la dirección se fija al final del aviso. Astral ya lo hace (`aim` fijado en `windup`, `recover` quieto). [Anatomía de un ataque en Dark Souls 3](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3), [Enemy attacks and telegraphing](https://gamedeveloper.com/design/enemy-attacks-and-telegraphing)
- **Turnos de ataque (tokens):** DOOM 2016 limita cuántos enemigos atacan a la vez con un fondo común de fichas; más fichas = más agresivo. Astral tiene una versión (`can_prepare`, `MAX_WINDUPS = 2`). Las fuentes son de segunda mano. [Game Developer: Cyber demons, la IA de DOOM 2016](https://www.gamedeveloper.com/design/cyber-demons-the-ai-of-doom-2016-), [Strayspark: attack tokens](https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair)
- **Movimiento tranquilo creíble:** los comportamientos de Reynolds (buscar, huir, llegar frenando, deambular con continuidad, rodear obstáculos, seguir un camino) siguen siendo la base para fauna y aldeanos. [Reynolds 1999, Steering behaviors](https://www.cs.princeton.edu/courses/archive/spr01/cs598b/papers/reynolds00.pdf)

## Ya corregido desde la auditoría anterior

Validación del pincho de hielo antes de cobrar maná, `_push_out` del héroe por pasos con `move_collide` y dirección de respaldo, y la cola de acciones que guarda blanco y arma.

## Hallazgos ordenados

| # | Prioridad | Problema (evidencia) | Qué pasa en el juego | Corrección propuesta |
|---|---|---|---|---|
| 1 | Alta | Monstruos, conejos, zorro y aldeanos van en línea recta al destino (`enemy._move(to.normalized())`, `_search`, `critter._step`, `predator._step`, `villager._step`). Solo el dragón, la mascota y el bot de pruebas usan `world.next_waypoint`. | En la mazmorra y junto a casas o árboles se quedan caminando contra la pared; el héroe los puede atacar a distancia sin respuesta. | Un paso común que, si la línea está bloqueada, pide `next_waypoint` cada 0,25 s, como hace `dragon.gd`. |
| 2 | Alta | `_separate()` y el empuje contra el héroe en `enemy._move` cambian `pos` directamente, sin `move_collide`. | Un monstruo apretado por otros o por el héroe puede quedar dentro de un muro y después no puede salir. | Pasar ambos empujes por `world.move_collide`. |
| 3 | Alta | Zonas superpuestas: cada `zone.gd` llama a `damage_hero` por separado, y si el héroe está atacando no hay `reaction_time`, así que no hay invulnerabilidad tras el golpe. | La onda expansiva, la cruz o la lluvia de meteoros de un jefe (con daño ×2,5) pueden pegar 2 o 3 veces en el mismo instante. | Invulnerabilidad corta tras recibir daño (~0,25 s) aunque se esté atacando, separada de la animación de herida. |
| 4 | Alta | `can_prepare` cuenta solo enemigos en `windup`. Los que están en `charge` o en un salto de ataque (`air`) no ocupan turno. | Más de dos ataques peligrosos a la vez: rompe el límite de `MAX_WINDUPS`. | Contar también `charge` y `air` con golpe al aterrizar. |
| 5 | Alta | Conejos y aldeanos en huida corren en línea recta a su madriguera o casa y solo paran a menos de 3 px; no hay límite de tiempo. | Si algo bloquea el camino, corren en el sitio para siempre. También pueden huir hacia el héroe si está entre ellos y la casa. | Camino con `next_waypoint` y un tiempo máximo de huida que los esconda igual. |
| 6 | Media | La ralentización de hielo (`slow_t`) solo se descuenta dentro de `enemy._move`. | Si el monstruo está avisando, recuperándose o en el aire, el efecto no baja y dura más de lo previsto. | Descontar `slow_t` en `_physics_process`. |
| 7 | Media | Jefes y monstruos con repertorio usan sus ataques en orden fijo (`atk_i`) y esperan llegar al alcance del siguiente. | Previsibles, y a veces rodean sin atacar hasta acercarse (el gólem necesita 55 px para su anillo). | Elegir al azar con peso entre los ataques que ya están en alcance, sin repetir el último. |
| 8 | Media | Los monstruos cuerpo a cuerpo van todos al mismo punto (el héroe) y `_separate` los aparta después. | Se amontonan y tiemblan uno contra otro. | Repartir posiciones alrededor del héroe (un hueco por monstruo) mientras esperan turno. |
| 9 | Media | Perspectiva: caminar aplasta el eje Y ×0,6, pero no lo hacen `zone_line`, el golpe del cíclope (`pos + to.normalized() * 32`), la dispersión de `zone_hero`, la distancia de `zone_ring`, los proyectiles ni la mascota. | Hacia arriba y abajo, los golpes caen más lejos de lo que el monstruo camina y los proyectiles parecen más rápidos. | Aplicar `Vector2(1, 0.6)` a esos desplazamientos. |
| 10 | Media | Arqueros, magos, hongo y murciélago retroceden en línea recta. | Se pegan a una pared o esquina y quedan fáciles. | Retroceso con componente lateral; si choca, rodear. |
| 11 | Baja | `next_waypoint` es una búsqueda sin límite sobre todo el mapa; la mascota la llama en cada cuadro cuando está bloqueada. Además permite diagonales que cortan esquinas. | Picos de tiempo en el mapa unificado, y caminos que `move_collide` no puede seguir. | Límite de casillas exploradas, recalcular cada 0,25 s y no cortar esquinas. |
| 12 | Baja | La cola de acciones del héroe caduca con reloj real (`Time.get_ticks_msec`). | Pausar justo después de pulsar puede perder la acción. | Contar el tiempo en `_physics_process`. |
| 13 | Baja | El comentario de `enemy.knock()` dice que los ligeros interrumpen el aviso; el código interrumpe con los pesados. | Confusión al ajustar. | Decidir el diseño y alinear comentario y código. |
| 14 | Pulido | Fauna y aldeanos arrancan y frenan de golpe, giran al instante y eligen puntos al azar sin continuidad. | Movimiento tranquilo algo mecánico. | Llegada frenando y deambular con continuidad (Reynolds). |
| 15 | Diseño | El dash es invulnerable durante todo el recorrido, incluido el frenado final. | Muy permisivo con los jefes más rápidos. | Valorar invulnerabilidad solo en la primera parte del dash. |

## Recomendación

Primero los puntos 1 a 4: son errores visibles o injustos, comparten poco código y se pueden probar con los tests actuales (`test_combat`, `test_combat_ext`, `test_dungeon`, `test_playthrough`). Después el 5 y el 6. Los puntos 7 a 10 mejoran la sensación de combate y conviene hacerlos juntos. El resto puede esperar.

## Estado

Los 15 puntos quedaron corregidos el mismo día. `tests/test_pathing.gd` cubre el camino alrededor de un muro, la invulnerabilidad tras un golpe, el turno de embestidas y saltos, la invulnerabilidad parcial del dash y el hielo que se gasta sin caminar. La batería completa (35 pruebas) pasa.

Nada de esto se probó jugando a mano: falta comprobar la sensación de los huecos alrededor del héroe, el retroceso lateral, la elección de ataques de los jefes y los proyectiles más lentos en vertical.
