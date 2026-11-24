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

El protagonista actual es el viajero de Ignis. Su diseño toma la silueta del viajero joven de la referencia, con cabello castaño corto y revuelto, expresión reservada, túnica de lino oliva con lazada y remiendo, capucha caída, capa marrón de borde irregular, cinturón con bolsa y botas envueltas en lino.

Los píxeles visibles se pintan en Krita. El atlas editable de piezas y accesorios está en `blender/viajero_pixel.kra` (160 × 128). Exportar a `blender/viajero_pixel.png` al guardar cambios. El retrato tiene su propio original en `blender/retrato_pixel_ignis.kra` y se exporta directamente a `art/dialogue/heroe.png` (90 × 96).

Para regenerar los sprites en PowerShell desde la raíz del proyecto:

```powershell
$env:ASTRAL_POSES = Join-Path $env:TEMP 'astral_pixel_poses.json'
blender -b blender/viajero_ignis.blend --python-exit-code 1 -P art/hechicero/export_pose_guide.py
uv run --no-project --python 3.13 --with "pillow>=12.1" python art/hechicero/compose_painted.py $env:ASTRAL_POSES
godot --headless --editor --import
```

La guía guarda posiciones y profundidad de las articulaciones, el filo y las herramientas. El montaje ordena las piezas pintadas por profundidad, usa vecino más cercano y conserva los colores de pincel. El modelo 3D queda como fuente de poses. Para reconstruirlo desde el rig original se usa `art/hechicero/build_traveler.py` sobre `blender/hechicero_floor.blend`.

El horneado conserva la escala del mundo. Las acciones con un arco amplio usan un lienzo de 192 px, el lanzamiento de la caña usa 224 px y el resto, 128 px. La cámara ortográfica y el centro del fotograma mantienen la misma posición de los pies. Las puntas de caña de `data/rod_tips.json` se calculan al renderizar desde la geometría de la vara.

## Verificación reproducible

- `tests/test_gait.gd`: distancia, continuidad direccional, parada y sprint.
- `tests/test_animation_integration.gd`: carga en ocho direcciones, tiempos de impacto/duración, reacción, reaparición, muerte sin duplicar recompensa y reinicio del dragón sin desvanecimiento residual.
- `tests/capture_polish.gd`: secuencias de poses y capturas renderizadas de exterior, dungeon y magia en `docs/previews/`.

El mapa y sus texturas no se regeneraron. Esta entrega centra el pulido en los personajes, su presentación y su integración. Las capturas y las pruebas automatizadas no sustituyen una sesión prolongada de juego ni un perfil de rendimiento.
