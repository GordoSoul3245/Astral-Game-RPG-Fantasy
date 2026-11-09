# Animación del héroe y del dragón — 9 de noviembre de 2026

## Cambios

- Reposo del héroe: 16 poses por dirección; movimiento de torso, cabeza, manos, capa y ocho faldones con desfases.
- Caminar/correr: 16 poses por dirección. Apoyos resueltos con dos huesos y cadera que desplaza el peso; trayectoria de pie con fase plantada y fase de vuelo. El render comprueba que el pie esté al alcance de la pierna.
- Godot conserva la fase al girar y avanza el ciclo por distancia recorrida. La longitud del ciclo se corresponde con la longitud de paso y la fracción de apoyo usadas en Blender. Una pared detiene la marcha.
- Tajos normales y en llamas: torso, cabeza y tela acompañan el gesto, con pies apoyados. Se mantienen seis/ocho poses y los mismos índices de impacto. Duraciones distintas por pose conservan el tiempo acumulado hasta el impacto y el tiempo total. También se ajusta el ritmo del lanzamiento de magia.
- Reacción del héroe: seis poses y 0,2 s de recuperación protegida cuando recibe daño fuera de un ataque. Los ataques en curso conservan su compromiso. La muerte usa doce poses durante un segundo antes de aplicar la reaparición existente.
- Dragón: doce poses de muerte por dirección, con retroceso, caída, cuello, alas y cola; el cuerpo conserva su escala. Se desvanece después de caer. Reiniciarlo cancela los tweens anteriores.
- Sombra de contacto del héroe, texto del HUD más grande y luz cálida con transición suave al lanzar magia o usar la espada en llamas.

## Archivos y regeneración

`art/render_polish.py` se ejecuta en una instancia de Blender en segundo plano sobre `blender/hechicero_floor.blend`. Exporta a `art/hechicero/polished/` y usa la cámara y materiales existentes. No guarda cambios sobre el blend original. Las imágenes originales del héroe siguen disponibles.

Comando completo: Blender con `--background blender/hechicero_floor.blend --python art/render_polish.py -- all`. Modos de revisión: `preview`, `locomotion`, `hero_death`.

La muerte del héroe usa un lienzo de 192 px y la del dragón uno de 160 px con la misma densidad de píxeles; Godot compensa el margen añadido (32 y 16 px por borde). Las demás imágenes siguen en 128 px.

Importar después con Godot `--headless --editor --quit --path .`.

## Verificación reproducible

- `tests/test_gait.gd`: distancia, continuidad direccional, parada y sprint.
- `tests/test_animation_integration.gd`: carga en ocho direcciones, tiempos de impacto/duración, reacción, reaparición, muerte sin duplicar recompensa y reinicio del dragón sin desvanecimiento residual.
- `tests/capture_polish.gd`: secuencias de poses y capturas renderizadas de exterior, dungeon y magia en `docs/previews/`.

El mapa y sus texturas no se regeneraron. Esta entrega centra el pulido en los personajes, su presentación y su integración. Las capturas y las pruebas automatizadas no sustituyen una sesión prolongada de juego ni un perfil de rendimiento.
