# Futuro: creación de personaje (razas, clases, cuerpo base y equipo)

Estado: **aplazado a propósito**. No se empieza hasta que animaciones y mecánicas estén perfeccionadas.
Motivo: los sprites del cuerpo y de cada pieza de equipo se renderizan a partir de las animaciones; si estas cambian después, hay que rehacerlos todos.

## Decisiones tomadas
- La **katana y el grimorio actuales son de prueba**: sirven para pulir animación y mecánica. No son el equipo final ni definen las clases finales.
- El personaje se crea eligiendo **solo la parte física**: raza, clase, color de piel/ojos/pelo, tamaño.
- El cuerpo base va **semidesnudo**. La ropa, armaduras, capas y armas son **equipo** que se obtiene y se equipa (estilo Dark Souls / Ark), no una elección al crear.
- Las clases son **datos** (equipo inicial + estadísticas) y no necesitan sprites propios salvo que traigan un arma con animaciones nuevas.
- Las razas comparten **esqueleto y silueta** (cambian color, orejas, cuernos, cola y una escala de ±10 %), para que cada pieza de equipo sirva a todas sin renderizarla otra vez.

## Antes de empezar (requisitos)
1. Animaciones y mecánicas cerradas: caminar, correr, dash, tajos, cast, golpe recibido, muerte.
2. Mover a un archivo de datos por personaje: `ANIMS` (fotogramas por animación), `FEET`, tiempos por fotograma, `strike_frame`, y los puntos de salida del tajo y del proyectil (hoy fijos: pecho a 40 px, mano a 40 px de altura).

## Fases
| Fase | Contenido |
|---|---|
| 1 | Datos por personaje + clases como datos (equipo inicial, estadísticas) + pantalla de creación + guardado. |
| 2 | Cuerpo semidesnudo con 2-3 razas; color de piel, ojos y pelo por shader. |
| 3 | Sistema de ranuras (cabeza, torso, piernas, manos, capa, arma): orden de dibujo por dirección y ocultar lo que tapa la pieza. |
| 4 | Primeras piezas de equipo (≈500-1000 PNG cada una: 8 direcciones × todas las animaciones). |
| 5 | Armas con animaciones nuevas (lanza, arco, escudo...), una por una. |

## Riesgos conocidos
- Cada pieza de equipo es un juego completo de sprites: limitar razas y piezas del primer lanzamiento.
- Razas con proporciones muy distintas obligan a renderizar cada pieza otra vez.
- Cambiar animaciones después de renderizar las capas obliga a rehacerlas.
- Opcional y delicado: peso del equipo que afecte a dash/estamina (tocaría mecánicas ya cerradas).
