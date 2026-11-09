# Ecos de la Ruina: investigación y propuesta de evolución

Fecha: 9 de noviembre de 2026. Este informe propone opciones; no modifica las decisiones de DESIGN_NOTES.md ni autoriza implementar todas las mecánicas.

## Dirección recomendada

Un RPG de acción isométrico para un jugador, con combate preciso de espada y magia, exploración de ruinas y progresión persistente. Conservar el bucle pueblo → bosque → dungeon → jefe → recompensa. La propuesta es priorizar el dominio del combate y el descubrimiento sobre el volumen de botín.

Referencias: Heart Machine describe Hyper Light Drifter en términos de combate rápido, contundente y habilidoso [1]. Supergiant presenta Hades como acción con combinaciones de poderes, progresión y narrativa entre intentos [2]. Motion Twin destaca en Dead Cells enemigos con patrones, armas diferenciadas y rutas secretas [3]. Son referencias de principios, no instrucciones para convertir este proyecto en un roguelite o un plataformas.

## Lo comprobado en el proyecto

- main.gd carga ocho imágenes por ciclo de caminar/correr, a 8 y 14 imágenes por segundo respectivamente. El reposo reutiliza una imagen de caminar.
- enemy.gd carga una imagen de reposo y ocho para marcha/ataque. Los golpes de varios enemigos se sincronizan con su preparación.
- La cámara ya usa seguimiento exponencial dependiente del tiempo. Movimiento y colocación del héroe se ejecutan en física; hay que evaluar su presentación entre ticks.
- Los bonos de velocidad aumentan desplazamiento sin ajustar el ciclo de marcha. Riesgo inferido: deslizamiento de pies.
- No aparecieron PointLight2D, DirectionalLight2D, CanvasModulate o mapas normales en la búsqueda de scripts. Esto no constituye una auditoría visual completa de todos los recursos.
- project.godot usa Compatibility y filtrado nearest. El arte conserva sombreado cel de Blender; no es geometría 3D iluminable en tiempo real dentro de Godot.
- Ya existen recursos, dash, ataques físicos y mágicos, ultimate, varios enemigos, dungeon de tres pisos, botín, estadísticas y equipo. No se deben presentar como funcionalidades nuevas.

No se ejecutó el juego ni se midieron tiempos de cuadro. Los problemas visuales descritos son hipótesis fundamentadas en código, pendientes de comparar en movimiento.

## Animación: trabajo que más cambia la percepción

1. Crear reposo real: respiración, balance contenido, tela y manos con desfase. Evitar mover todo el cuerpo como una pieza rígida.
2. Mejorar poses antes de multiplicar imágenes: apoyo firme del pie, transferencia del peso, giro del torso, anticipación del arma y recuperación.
3. Probar ciclos de 12–16 imágenes en locomoción y mayor densidad donde el ataque cambia más deprisa. Son presupuestos iniciales, no estándares obligatorios. Mantener pausas y acentos: fluidez no equivale a velocidad uniforme.
4. Conservar la fase del ciclo al cambiar entre direcciones y ajustar reproducción a la velocidad efectiva. Al chocar con una pared no debe seguir una marcha completa si el personaje no avanza.
5. Añadir entradas/salidas de movimiento cortas, sin retrasar la respuesta del control. Antes de exportar nuevas transiciones, probar si bastan poses y tiempos mejores.
6. Añadir reacción al golpe, muerte y aparición para cada enemigo; el dragón necesita una muerte diseñada que sustituya el aplastado provisional.
7. Separar preparación, impacto y recuperación; mantener hitboxes y efectos sincronizados si cambia el número de imágenes. Los strike_frame actuales deben actualizarse con cada render nuevo.
8. Probar interpolación de presentación. Godot dispone de interpolación física 2D [5], pero esto no inventa poses entre PNG. Revisar cámara y teletransportes para no introducir retraso o estelas.
9. Mantener ocho direcciones durante esta fase. Pasar a dieciséis multiplica el arte direccional; solo hacerlo si una prueba demuestra una mejora necesaria.

No recomendar interpolación automática de imágenes como solución principal: puede deformar manos y armas y desalinear el impacto.

## Iluminación y profundidad

Propuesta inicial: conservar el sombreado cel existente, usar un ambiente contenido por zona, sombras de contacto legibles y unas pocas luces de antorchas o magia. La guía oficial documenta CanvasModulate, luces 2D, oclusores y mapas normales [4].

Prueba mínima: una sala, una antorcha, el héroe y un proyectil. Comparar versión actual, luz añadida sobre sprite existente y una variante de material preparada para recibir luz. El sombreado ya incluido en PNG puede producir doble iluminación o sombras contradictorias.

Etapas:

- Sombra de contacto bajo personajes; variar tamaño/opacidad con el salto. Separar sombra de suelo y cuerpo cuando sea necesario.
- Antorchas cálidas con fluctuación continua suave; evitar valores aleatorios independientes por cuadro.
- Iluminación breve de fuego y rayos sobre el entorno, sin lavar las siluetas ni los avisos enemigos.
- Máscaras para impedir que HUD y elementos concretos reciban luces del mundo.
- Oclusores simplificados en muros y objetos grandes. Las sombras 2D de un sprite no reconstruyen automáticamente una escena isométrica tridimensional.
- Mapas normales exportados desde Blender por pose y dirección solo si la prueba justifica su coste. Deben compartir encuadre, transparencia y orientación compatible con Godot; no basta con conectar un pase de normales arbitrario.
- Partículas ambientales, agua, polvo y vegetación con movimiento contenido. Reducir partículas antes que perder legibilidad o estabilidad de cuadros.
- Glow moderado. La documentación consultada indica que Compatibility tiene implementación propia y propiedades limitadas [6]; verificar comportamiento de la versión instalada y del lienzo 2D antes de diseñar alrededor de HDR.

No se propone migrar a 3D ni cambiar renderer de entrada. Las diferencias de renderer están documentadas por Godot [7].

## Catálogo de mecánicas posibles

P0 = base y calidad; P1 = siguiente ampliación coherente; P2 = opcional posterior; X = fuera del MVP actual. Todas las entradas son propuestas salvo donde se indique existente.

| Área | Mecánicas | Prioridad y condición |
|---|---|---|
| Control | Movimiento, sprint y dash existentes; remapeo; mando; apuntado asistido opcional; buffer corto de acciones; tolerancia al cambio de dirección | P0. Probar buffer de 80–150 ms como punto de partida, sin encadenar órdenes antiguas |
| Ataques | Ligero, pesado, magia y ultimate existentes; combo corto; ataques cargados; golpe tras dash; pequeño avance durante el tajo | P1. Cada ataque debe tener una utilidad distinta |
| Defensa | Esquiva existente; ventanas de cancelación; bloqueo; parry; contraataque; esquiva perfecta | P1 para ventanas, P2 para elegir una defensa adicional. No añadir todas a la vez |
| Impacto | Reacción, empuje, interrupción, resistencia al tambaleo, ruptura de postura, pausa breve de impacto | P0/P1. Impedir bloqueo infinito y permitir reducir destellos/temblores |
| Recursos | Vida/maná/estamina/ultimate existentes; regeneración tras combate; golpes que recuperan maná; cargas de curación | P1. Crear un motivo para alternar espada y magia |
| Magia | Ignis existente; hielo, tormenta o ruina; proyectil, cono, zona, trampa, escudo, canalización, teletransporte corto | P1 una segunda escuela; P2 el resto |
| Estados | Quemadura, lentitud, congelación, descarga, vulnerabilidad, veneno y sangrado | P1 comenzar con dos. Definir duración, acumulación, inmunidad y señal visual |
| Combinaciones | Enemigo marcado por magia recibe un efecto de espada; enemigo mojado conduce descarga; quemadura puede detonar | P1 una interacción; P2 superficies complejas. Evitar una tabla combinatoria enorme |
| Enemigos | Perseguidor, arquero, bruto y mago existentes; escudero, apoyo, invocador, emboscador, explosivo | P1. Variar decisiones exigidas antes de añadir más HP |
| Coordinación | Cupo de atacantes simultáneos; flanqueo; mantener distancia; retirada; ayudas entre enemigos; zonas de persecución | P1. No permitir ataques inevitables fuera de cámara |
| Élites | Un modificador legible: blindado, eléctrico, regenerador o invocador | P2. No acumular efectos ilegibles |
| Jefes | Fases, patrones por distancia, recuperación castigable, partes rompibles, invocaciones, arena que cambia | P1 para fases/patrones; P2 para partes y arena compleja |
| Encuentros | Mezclas de roles, obstáculos, entradas escalonadas, emboscadas anunciadas, objetivos de supervivencia o interrupción | P1. Enseñar cada amenaza antes de combinarla |
| Exploración | Atajos, secretos, cofres opcionales, puertas con llaves, zonas de riesgo, puntos de descanso, mapa descubierto | P1. Conservar una región diseñada a mano |
| Puzles | Runas, interruptores, braseros, secuencias, rayos reflejados, puertas abiertas con magia | P2. Empezar con uno que reutilice el combate |
| Dungeon | Tres pisos existentes; habitaciones con propósito, llave opcional, santuario, desafío, miniboss, decisión riesgo/recompensa | P1. Diferenciar pisos mediante situaciones |
| Pueblo | Gremio, aceptación/cobro de misión, curación, herrero sencillo, mercader y entrenamiento | P0 para gremio y misión; P1 para servicios mínimos |
| Misiones | Principal, encargos opcionales, rescate, recuperar reliquia, eliminar élite, encontrar secreto | P0 una principal completa; P2 variedad |
| Narrativa | Diálogo breve, ruinas que cuentan historias, notas, bestiario, ecos del pasado | P1. Mantener historia opcional durante combate |
| Equipo | Ranuras y rarezas existentes; atributos únicos, runas, mejora acotada, comparación, vender/desmontar, favoritos | P1. Un objeto debe cambiar decisiones, no solo números |
| Apariencia | Armas visibles, tintes, armaduras visibles, accesorios | P2. Cada combinación exige una estrategia de render/capas y oclusión |
| Progresión | Nivel y atributos existentes; devolver puntos; pequeñas ramas de talentos; dominio de espada/magia | P1. Evitar multiplicadores de velocidad sin límites de legibilidad |
| Botín | Pools existentes; recompensas elegidas, objetos únicos, protección frente a duplicados, materiales con uso concreto | P1. Resolver qué ocurre si la mochila está llena |
| Muerte | Reaparición en pueblo y misión activa según brief; señal de causa de muerte; checkpoints | P0. Recuperar moneda perdida o cadáver sería P2 y requiere decidirlo expresamente |
| Persistencia | Guardar/cargar progreso, equipo, misión y estado de dungeon; autoguardado; versión de formato; respaldo | P0. No se verificó aquí si ya existe algún guardado |
| Interfaz | Inventario existente; mensajes claros de bloqueo, tutorial contextual, opciones de tamaño, navegación por mando | P0/P1 |
| Accesibilidad | Remapeo, mantener/alternar sprint, reducir shake y flashes, señales por forma además de color, ayudas configurables | P0. Integrarlo en los efectos nuevos |
| Audio | Pasos según superficie, preparación enemiga reconocible, capas de impacto, ambiente y música por intensidad | P0/P1. Priorizar señales útiles sobre ruido constante |
| Rejugabilidad | Desafíos de jefe, arena, modificadores opcionales, nueva partida+ | P2 tras completar el bucle |
| Sistemas grandes | Cooperativo, economía compleja, oficios, facciones, mundo abierto, múltiples clases, dungeon procedural recurrente | X. El brief los excluye o exceden su alcance |

No existe una lista finita de todas las mecánicas imaginables. Este catálogo cubre las familias principales que encajan con el diseño y distingue las que requieren cambiar su alcance.

## Identidad propuesta: resonancia entre espada y grimorio

Propuesta nueva, todavía no aprobada: la magia deja una marca breve; el pesado o un ataque de espada tras dash la consume para producir un efecto. Empezar con Ignis: marca → golpe físico → pequeña explosión. Mostrar la marca y su consumo de forma inequívoca. Alternativa más pequeña: la espada recupera una cantidad limitada de maná.

Elegir una de las dos para la primera prueba. Ambas conectan los sistemas ya existentes; añadir las dos inmediatamente haría más difícil evaluar cuál mejora el combate.

## Orden de producción y criterios de salida

1. Sala de calidad: héroe, slime, arquero, antorcha y obstáculo. Comparar movimiento, lectura y luz antes/después mediante capturas y vídeo real.
2. Fluidez: reposo, apoyos, fase de locomoción, sincronía de efectos y velocidad; comprobar todas las direcciones y máximos de estadísticas.
3. Sensación: buffer, reacción, sonido e impacto; medir si la entrada es aceptada y cuándo llega el golpe. Probar ventanas con jugadores, no solo cifras.
4. Identidad: una interacción espada/magia, un enemigo que la invite y un jefe que permita usarla sin obligarla.
5. Bucle completo: pueblo, misión, exterior, dungeon, jefe, vuelta, recompensa, guardado y muerte.
6. Contenido: secretos, equipo singular y variedad de encuentros después de validar lo anterior.

Objetivo inicial de rendimiento propuesto: 60 FPS estables en un equipo de referencia aún por elegir; 16,7 ms por cuadro es el presupuesto correspondiente, no una medición del proyecto. Revisar también picos al cargar sprites y activar efectos. Probar 30/60/120 FPS, resoluciones y zooms habituales. Una captura headless no valida respuesta, sonido ni fluidez.

## Fuentes y alcance

Investigación documental con búsqueda web, lectura de documentación oficial y revisión parcial de código local. No hubo pruebas de usuario, perfilado, ejecución visual ni auditoría completa de recursos. Confianza alta en hallazgos de código citados; las prioridades y presupuestos son recomendaciones de diseño que requieren pruebas.

1. Heart Machine, texto del desarrollador sobre Hyper Light Drifter: https://blog.playstation.com/2014/03/14/creating-the-world-of-hyper-light-drifter-on-ps4-and-ps-vita/
2. Supergiant, Hades FAQ: https://www.supergiantgames.com/blog/hades-faq/
3. Motion Twin, presentación de Dead Cells: https://deadcells.com/
4. Godot, 2D lights and shadows: https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
5. Godot, interpolación 2D y 3D: https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html
6. Godot, environment and post-processing (documentación latest; contrastar versión instalada): https://docs.godotengine.org/en/latest/tutorials/3d/environment_and_post_processing.html
7. Godot, comparación de renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
