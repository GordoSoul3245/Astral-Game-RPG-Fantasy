# Game Brief: Ecos de la Ruina

**Pitch:** Un RPG de acción isométrico de fantasía donde cada golpe pesa, y donde explorás un mundo luminoso y peligroso construido sobre las ruinas de una civilización perdida.

## Core loop
- Aceptar una misión en el pueblo.
- Explorar la zona y leer, esquivar y vencer a los enemigos usando ataques físicos y magia.
- Entrar a la dungeon y derrotar al jefe.
- Volver con botín y pistas del pasado, y mejorar el equipo.

## Objetivo y fallo
- **Objetivo:** completar la misión del gremio venciendo al jefe de la dungeon.
- **Fallo:** si la vida llega a 0, el jugador reaparece en el pueblo y la misión sigue activa.
- **Sesión completa:** misión aceptada, dungeon superada, jefe derrotado y recompensa cobrada.

## MVP
1. Movimiento y esquiva en 8 direcciones que respondan bien, sobre el suelo y los sprites actuales del proyecto.
2. Combate con peso para un protagonista hechicero: ataques físicos ligeros y pesados, más hechizos con coste de maná; todos con preparación, impacto y recuperación legibles.
3. Dos enemigos con comportamiento propio y ataques que se puedan leer.
4. Un jefe de dungeon con patrones.
5. Un pueblo con un NPC del gremio que da una misión y la cobra.
6. Una zona exterior (el bosque junto a la ruina) conectada con una dungeon.
7. Datos externos para armas, criaturas y misiones, de modo que agregar más no duplique lógica.

## Fuera de alcance
- Cooperativo de 2 a 4 jugadores.
- Más de una región; islas flotantes, bosques que se mueven, zonas submarinas.
- Facciones, reputación y memoria de los NPC.
- Economía con comercio, mercado negro y gremios múltiples.
- Oficios: pesca, minería, alquimia, cultivo, cocina y fabricación.
- Árboles extensos de magia, múltiples clases de hechicero y sistemas avanzados de grimorios. El protagonista sí usa magia en el combate base mediante su grimorio equipado.
- Dungeons que rotan o reaparecen; megajefes.

## Orden de construcción
1. Movimiento y esquiva en 8 direcciones (lo que hoy no convence).
2. Ataque ligero y magia normal contra un enemigo, para ajustar la sensación del golpe y del hechizo.
3. Ataque pesado, magia pesada y segundo enemigo; después, magia ultimate y sus condiciones de carga.
4. Jefe de dungeon.
5. Pueblo, NPC y misión.
6. Conexión entre la zona exterior y la dungeon.
7. Pasar armas, criaturas y misiones a datos externos.

## Dirección de arte y audio
Se mantiene la historia y el contexto de Ecos de la Ruina. El apartado gráfico es el del proyecto actual: personajes y escenarios renderizados desde Blender con sombreado cel y texturas pintadas en Krita, con la cámara y paleta de `art/`. La música acompaña el contraste entre zonas luminosas y sombrías.

**Quién lo juega:** jugadores de soulslike y ARPG que disfrutan aprender a un enemigo y sentir que cada golpe cuenta.

**Referencia:** *Hyper Light Drifter*: combate legible en ocho direcciones y una zona con dungeon; sin el mundo abierto completo.
