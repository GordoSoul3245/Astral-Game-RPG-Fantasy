# Revisión visual del prototipo

9 de noviembre de 2026. Inspección mediante control de escritorio; sin cambios de código.

## Ejecución

Se inspeccionó la instancia previamente abierta y se inició otra con Godot 4.7.2, Compatibility, ventana solicitada de 1280×720. La consola identificó Radeon 7 y no mostró errores en el arranque revisado. Se cerró únicamente la instancia nueva al terminar.

Los clics de ataque produjeron cambio de pose y consumo de estamina; en la instancia nueva se comprobó el pesado. Las teclas enviadas por la herramienta no produjeron respuesta visible, incluso tras activar la ventana y probar Tab, I, flecha y espacio. No se ha determinado si se debe a la automatización o al manejo de eventos. No se considera un defecto confirmado del control del juego.

## Observaciones visuales

- Paleta y silueta del héroe coherentes; el personaje destaca sobre el terreno verde.
- El apoyo de los pies necesita una sombra de contacto más legible. La separación del suelo es una percepción visual, no una conclusión sobre la colisión.
- Árboles y terreno presentan repetición muy visible. Los detalles pequeños del suelo compiten por atención; reducir contraste y agrupar variaciones ayudaría a jerarquizar la escena.
- La composición del exterior presenta mucha luminosidad similar entre zonas. Se recomienda comparar iluminación ambiental y focos locales conservando las bandas cel.
- En la ventana de 1280×720, los controles y la información del HUD aparecen pequeños. Revisar tamaño mínimo y escala de interfaz.
- El borde oscuro de la isla ocupa una parte amplia de la vista inicial. Revisar posición de aparición, composición y límites de cámara cuando se diseñe el mapa definitivo. El mapa actual sigue siendo una prueba.

## Prioridades propuestas

1. Sala representativa para comparar sombra de contacto, reposo animado e iluminación local.
2. Verificación real de locomoción, fase de zancada y cambios de dirección, con entrada física o automatización compatible.
3. Escalado de HUD y controles en 720p y 1080p.
4. Revisión completa de encuentros y dungeon cuando pueda controlarse el desplazamiento y la interacción.

## Límites

No se recorrió la dungeon, no se abrió el inventario y no se completó un combate contra enemigos. Las capturas aisladas no permiten medir fluidez, latencia, audio ni rendimiento. No se confirmó deslizamiento de pies en ejecución; sigue siendo un riesgo inferido del código descrito en RESEARCH_DESIGN_2026-11-09.md. No se modificaron escenas, datos ni arte.
