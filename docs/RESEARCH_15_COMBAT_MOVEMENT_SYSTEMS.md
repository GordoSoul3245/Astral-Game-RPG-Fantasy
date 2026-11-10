# Quince referencias de combate, movimiento y vida para Ecos de la Ruina

Investigación: 10 de noviembre de 2026. Documento para el usuario y Claude Code. Complementa DESIGN_NOTES.md, GAME_BRIEF.md y COMBAT_LIGHTING_REPORT.md. No constituye autorización para implementar todas las propuestas.

## Cómo leer este estudio

No hay quince sistemas objetivamente mejores para todos los jugadores. Seleccioné quince referencias por su utilidad: respuesta, peso, dominio, expresión, enemigos y mundo vivo. El orden es temático, no una clasificación de calidad. Celeste enseña movimiento; Rain World y Red Dead enseñan comportamiento; no todos son modelos de combate isométrico.

Distingo tres capas: **evidencia** (mecánica documentada o valoración de una fuente), **interpretación** (por qué puede producir una sensación) y **propuesta** (cómo trasladarla). Las motivaciones de disfrute son hipótesis de diseño apoyadas en recepción crítica, no una encuesta representativa. No se midieron ventas, retención ni porcentajes de preferencias. Las críticas de una reseña son de su autor, no de toda la comunidad. Cuando falta corroboración, se indica como riesgo de adaptación.

Fuentes consultadas: documentación y textos de desarrolladores, charla/postmortem, manuales, entrevistas y reseñas identificadas. Se prefieren fuentes originales para explicar implementación. Las reseñas se usan para experiencia y críticas, no para atribuir algoritmos internos que no conocemos. La antigüedad es apropiada para estudiar sistemas históricos; no se pretende describir el balance de sus últimos parches.

## Estado del proyecto comprobado antes de recomendar

El código local y COMBAT_LIGHTING_REPORT.md ya contienen combat.gd como entrada de daño, empujes, chispas, sonidos sintetizados, marcas de Ignis, recuperación del arquero/mago y ambiente/luces dinámicas. El informe dice que sus pruebas pasaron; esta investigación no las reejecutó. No deben reconstruirse esos sistemas desde cero.

El héroe ya tiene locomoción de 16 poses y fase por distancia, animaciones de reposo y reacciones; el dragón tiene muerte articulada. Revisar ANIMATION_POLISH.md. Todavía falta demostrar satisfacción en una partida prolongada con personas.

Hay cambios sin commit en main.gd y archivos de controles táctiles/exportación. No se modificaron ni descartaron en este estudio. Los documentos de diseño conservan algunos pendientes viejos que contradicen actualizaciones posteriores: verificar código y reportes antes de actuar.

## 1. Hades: movilidad y combinaciones sobre pocos verbos

**Evidencia.** Ataque, especial, lanzamiento y dash se combinan con armas y bendiciones; las combinaciones alteran la forma de jugar. La reseña de GameSpot destaca encadenamiento y variedad; Tom’s Guide señala repetición de jefes. [Guía PlayStation](https://www.playstation.com/en-us/games/hades/tips-and-tricks-to-survive-your-first-hades-encounters/), [GameSpot](https://www.gamespot.com/reviews/hades-review-the-long-hard-road-out-of-hell/1900-6417568/), [Tom’s Guide](https://www.tomsguide.com/reviews/hades).

**Interpretación.** Pocos controles con resultados combinables permiten sentirse hábil pronto y seguir descubriendo decisiones. Movimiento y ataque forman una frase continua.

**Para Astral.** Aprovechar la marca de Ignis existente: mostrar claramente aplicar → reconocer → consumir. Probar un ataque tras dash antes de crear más botones. Variar encuentros, no solo estadísticas. **Riesgo inferido:** cancelar cualquier ataque en cualquier instante elimina el compromiso del pesado; demasiadas partículas ocultan el peligro. **Coste:** bajo/medio sobre sistemas existentes. **Prueba:** que una persona nueva explique cuándo detonó la marca y repita voluntariamente la secuencia.

## 2. Hyper Light Drifter: precisión espacial con repertorio pequeño

**Evidencia.** Heart Machine presenta combate rápido y justo, narrativa visual y exploración. GameSpot elogia los enfrentamientos pero describe objetos y bordes que no siempre se leen con claridad. [Desarrollador](https://blog.playstation.com/2014/03/14/creating-the-world-of-hyper-light-drifter-on-ps4-and-ps-vita/), [reseña](https://www.gamespot.com/reviews/hyper-light-drifter-review/1900-6416400/).

**Interpretación.** Elegir dónde terminar una esquiva importa tanto como ejecutarla. La satisfacción viene de anticipar la posición siguiente, no de tener muchos ataques.

**Para Astral.** Revisar destino del dash, anchura de pasillos, pies y obstáculos ocultos por árboles. Avisar ataques desde fuera de cámara antes de permitir daño. El arquero debe exigir reposicionarse, el cíclope salir de su zona y el slime gestionar cercanía. **Riesgo:** una perspectiva bonita puede dificultar leer las colisiones. **Coste:** bajo para reglas, medio para escenario. **Prueba:** al morir, el jugador debe identificar obstáculo o ataque responsable sin una explicación externa.

## 3. Dead Cells: controles que entienden intención

**Evidencia.** El postmortem de Sébastien Bénard describe ayudas de control, giro libre y asistencia de apuntado, y defiende cuidar detalles ajenos al desafío. La reseña de GameSpot explica cómo muerte y desbloqueos estructuran el progreso. [Postmortem GDC](https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf), [reseña](https://www.gamespot.com/reviews/dead-cells-review-rise-from-your-grave/1900-6416953/).

**Interpretación.** Si el control acepta la intención, el fracaso puede atribuirse a la decisión. La dificultad deja de depender de luchar contra el mando.

**Para Astral.** Un buffer corto para la siguiente acción, giro permitido en una parte definida de la preparación y ayuda angular discreta opcional con mando/táctil. Mantener apuntado preciso con ratón. **Riesgo de adaptación:** almacenar demasiadas acciones hace que el héroe ataque cuando el jugador ya quiere huir; asistir a través de paredes se siente tramposo. No atribuir valores exactos al juego sin medirlos. **Coste:** bajo/medio. **Prueba:** pulsar un poco antes de terminar la recuperación ejecuta una sola acción; el menú y la muerte vacían la cola.

## 4. Dark Souls: compromiso y economía de acciones

**Evidencia.** El manual identifica la estamina como recurso central. Un análisis de diseño advierte que copiar la barra sin diseñar enemigos y acciones conjuntamente no reproduce el sistema. [Manual oficial](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/211420/manuals/DarkSouls_PC_Manual_Online_GB.pdf), [análisis](https://www.gamedeveloper.com/design/the-design-lessons-designers-fail-to-learn-from-dark-souls).

**Interpretación.** Un golpe pesa cuando aceptar su preparación y recuperación expone a una consecuencia. Leer al rival produce dominio y alivio al vencer.

**Para Astral.** Mantener un pesado con compromiso reconocible; comparar su riesgo/beneficio con varios ligeros. Reservar suficiente control para que retirarse siga siendo una decisión. **Riesgo de adaptación:** espera pasiva, agotamiento que bloquea todas las respuestas o enemigos que giran durante el impacto para corregir artificialmente su puntería. Estas son advertencias de diseño, no resultados de una encuesta de Dark Souls. **Coste:** bajo en balance, medio en animaciones/encuentros. **Prueba:** el pesado se elige por una apertura concreta, no porque supera al ligero en todas las situaciones.

## 5. Bloodborne: agresión como recuperación

**Evidencia.** El sistema Regain permite recuperar vida reciente atacando dentro de una ventana. TIME lo describe como una invitación arriesgada a responder y critica que algunos jefes pueden sentirse como patrones ya resueltos. [Presentación oficial](https://blog.playstation.com/2014/08/13/bloodborne-on-ps4-new-combat-details/), [crítica](https://time.com/3754106/bloodborne-playstation/).

**Interpretación.** Recibir daño genera una decisión inmediata: recuperar iniciativa o aceptar la pérdida y retirarse. Cambia el significado del error.

**Para Astral.** Preferir inicialmente una recuperación pequeña de maná al golpear con espada, con límite por acción. Conecta espada/magia sin introducir otra barra de salud. **Riesgo:** premiar recibir golpes o permitir curación infinita con enemigos débiles. Si se prueba recuperar vida, conservar solo daño reciente, limitarlo y mostrarlo en HUD. **Coste:** medio. **Prueba:** comparar agresión voluntaria y daño recibido con/sin recuperación; no aprobarla solo porque reduce la dificultad.

## 6. Sekiro: defensa activa y presión sobre postura

**Evidencia.** Activision explica que atacar y desviar rompe postura para abrir un golpe decisivo. PC Gamer describe la descarga emocional de alcanzar el deathblow tras un duelo exigente. [Mecánicas oficiales](https://support.activision.com/content/atvi/support/web/en/sekiro/articles/sekiro-shadows-die-twice-game-mechanics.html), [reseña](https://www.pcgamer.com/sekiro-review/).

**Interpretación.** Defender en el instante adecuado hace avanzar el combate; no es solo demorar el daño. El intercambio adquiere ritmo y una meta visible.

**Para Astral.** Probar primero interrupción o ruptura de guardia en un élite específico usando el pesado. No añadir postura universal y parry obligatorio simultáneamente. **Riesgo inferido:** estrechar todas las soluciones a un examen rítmico perjudica a quienes prefieren magia, movilidad o tienen dificultades de timing. **Coste:** medio/alto por animaciones, UI y balance de todas las criaturas. **Prueba:** el élite debe seguir siendo vencible con magia y esquiva; indicar exactamente qué ataques admiten interrupción.

## 7. Monster Hunter: World: la criatura como adversario físico

**Evidencia.** PC Gamer destaca armas con compromiso, bestias convincentes y recompensa de acertar una secuencia; también critica fricción de gestión y describe control lento/castigos. Capcom publica manuales de la serie con agotamiento de monstruos; no se asumen iguales todos sus valores entre entregas. [Reseña de World](https://www.pcgamer.com/monster-hunter-world-review/), [manual de Generations](https://game.capcom.com/manual/MH_Gen/en-UK/page-46.html).

**Interpretación.** Aprender el cuerpo, la orientación y los momentos del animal transforma al enemigo en alguien que se observa, no en una barra que se vacía.

**Para Astral.** Dar al dragón pausa para respirar tras una ráfaga, giro limitado antes del disparo y retirada a una posición válida. Su cansancio debe cambiar postura, respiración o sonido. **Riesgo:** escalar la vida sin nuevas decisiones alarga el combate; perseguir constantemente al monstruo produce tedio. **Coste:** medio. **Prueba:** el jugador identifica la ventana de castigo por la criatura, incluso sin icono flotante.

## 8. Devil May Cry 5: expresión y variedad voluntaria

**Evidencia.** La guía de PlayStation describe herramientas y estilos combinables; GameSpot destaca cómo personajes y nuevas mecánicas renuevan el combate. [Guía](https://blog.playstation.com/2019/03/14/devil-may-cry-5-tips-for-demon-slaying-success/), [reseña](https://www.gamespot.com/reviews/devil-may-cry-5-review---from-zero-to-nero/1900-6417099/).

**Interpretación.** Un encuentro puede preguntar cómo quieres resolverlo, además de si puedes sobrevivir. El dominio produce expresión personal.

**Para Astral.** Ofrecer rutas cortas distintas: ligero → esquiva; marca → pesado; distancia → hechizo. Una recompensa moderada por variar puede cargar ultimate, sin exigir un marcador de estilo. **Riesgo inferido:** demasiadas combinaciones y cambios de arma generan sobrecarga; premiar variedad puede castigar una preferencia legítima. **Coste:** medio/alto si se añaden ataques; bajo si solo se aclaran usos existentes. **Prueba:** dos jugadores resuelven la misma sala de formas distintas sin una estrategia claramente inferior por estadísticas.

## 9. DOOM Eternal: movilidad y circuito de recursos

**Evidencia.** Bethesda explica que ciertas acciones restauran salud, munición o armadura. PC Gamer aprecia la tensión del intercambio, pero relata rechazo inicial al Marauder por exigir una pausa y contraataque muy distintos del ritmo habitual. [Soporte oficial](https://help.bethesda.net/app/answers/detail/a_id/49879/~/why-do-i-keep-running-out-of-health-and-ammo-in-doom-eternal%3F), [reseña](https://www.pcgamer.com/doom-eternal-review/).

**Interpretación.** Los enemigos pueden ser oportunidades para recuperar iniciativa y recursos. Moverse conecta supervivencia y ofensiva.

**Para Astral.** Un vínculo espada → maná puede sostener la magia; evitar que todo dependa de regeneración esperando fuera de alcance. Diseñar rutas de salida y espacio para esquivar. **Riesgo:** un orden obligatorio de botones convierte el combate en mantenimiento; enemigos con una única respuesta rompen la libertad prometida. **Coste:** medio. **Prueba:** al quedarse sin maná hay una acción segura pero no trivial para recuperarlo, y no un bloqueo irreversible.

## 10. Batman: Arkham Asylum: flujo y coordinación de grupos

**Evidencia.** El análisis de Game Developer estudia Freeflow y la combinación de acciones del juego. Es un análisis de un autor, no documentación del código de Rocksteady. [Análisis](https://www.gamedeveloper.com/design/game-design-review-batman-arkham-asylum).

**Interpretación.** Cambiar de amenaza sin perder continuidad crea sensación de control sobre un grupo. La legibilidad del ataque entrante sostiene ese ritmo.

**Para Astral.** Tomar como propuesta un coordinador pequeño: limitar preparaciones de ataques simultáneos según sus áreas, reservar espacio para aproximarse y alternar atacantes. No afirmamos que ese sea el algoritmo interno de Batman. **Riesgo inferido:** enemigos que esperan quietos su turno parecen extras; autoacercamiento excesivo hace perder precisión. Quien espera debe rodear, proteger o buscar posición, respetando distancia. **Coste:** medio. **Prueba:** con seis enemigos hay presión legible, pero no seis impactos inevitables al mismo tiempo ni una fila inmóvil.

## 11. Zelda: Breath of the Wild: reglas que permiten experimentar

**Evidencia.** La presentación de Nintendo en GDC documenta el replanteamiento del mundo; la reseña de GameSpot destaca descubrimiento y nuevas maneras de abordar situaciones. No se inspeccionó código propietario. [Presentación](https://www.gdcvault.com/play/1024562/Change-and-Constant-Breaking-Conventions), [reseña](https://www.gamespot.com/reviews/the-legend-of-zelda-breath-of-the-wild-review/1900-6416626/).

**Interpretación.** Una regla consistente permite formular una hipótesis y comprobarla. La curiosidad se convierte en acción.

**Para Astral.** Un primer sistema acotado: Ignis enciende un brasero que abre una puerta, o prende un obstáculo combustible. La regla debe repetirse visualmente en combate y exploración. **Riesgo inferido:** superficies, clima, fuego, agua y electricidad juntos multiplican casos; no añadir durabilidad de armas solo por copiar la referencia. Esta investigación no cuantifica la crítica comunitaria a la durabilidad. **Coste:** medio para una regla, alto para una simulación completa. **Prueba:** el jugador deduce una segunda interacción sin tutorial textual.

## 12. Celeste: tolerancia sin quitar precisión

**Evidencia.** Maddy Thorson documenta coyote time, buffer de salto, correcciones de esquinas y ayudas de movimiento. PCWorld destaca el uso de pocas acciones en muchas situaciones. [Texto original](https://www.maddymakesgames.com/articles/celeste_and_forgiveness/index.html), [reseña](https://www.pcworld.com/article/407904/celeste-review.html).

**Interpretación.** El juego acepta una intención razonable cerca del límite, conservando el desafío de decidir y dirigir.

**Para Astral.** Buffer de dash/ataque, deslizamiento coherente al rozar obstáculos y cierta tolerancia en interacción con puertas/cofres. No añadir coyote time literalmente: actualmente no hay plataformas ni salto libre. **Riesgo inferido:** una corrección demasiado grande puede cruzar muros, cambiar el destino o activar otra puerta. **Coste:** bajo. **Prueba:** entradas limítrofes aceptadas, entradas vencidas descartadas y cero atravesamientos de esquinas en todas las direcciones.

## 13. Rain World: criaturas con intereses propios

**Evidencia.** La entrevista a Joar Jakobsson explica animación procedural y criaturas que sobreviven, cazan y compiten más allá del jugador. PC Gamer critica aprendizaje opaco y situaciones emergentes injustas. [Entrevista](https://www.gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-), [reseña](https://www.pcgamer.com/rain-world-review/).

**Interpretación.** Un animal resulta vivo cuando no está siempre esperando al protagonista. Los encuentros cuentan pequeñas historias sin guion completo.

**Para Astral.** Primer ecosistema de tres roles: presa que pasta/huye, depredador que busca/completa una persecución y criatura territorial que advierte antes de atacar. Dar refugios y rutas de escape. **Riesgo:** una simulación puede bloquear accesos o matar al jugador al entrar en pantalla; exigir zonas seguras y límites de presión. La animación procedural de Rain World no se traslada directamente a PNG horneados. **Coste:** medio para comportamiento acotado, alto para ecosistema persistente. **Prueba:** observar 60 segundos sin intervenir y reconocer al menos una conducta con propósito.

## 14. Red Dead Redemption 2: presencia corporal y observación

**Evidencia.** La crítica de PCWorld describe fricción concreta del control de caballo relativo a cámara. Rockstar ofrece configuraciones alternativas de control. La página oficial de fauna no devolvió texto legible en esta consulta; no se toman de ella cifras de especies ni algoritmos. [Rockstar, controles](https://www.rockstargames.com/newswire/article/25o2411817k8k7/Red-Dead-Redemption-2-Quick-Tips), [PCWorld](https://www.pcworld.com/article/398324/red-dead-redemption-2-pc-impressions.html).

**Interpretación.** Miradas, pausas y transiciones pueden comunicar peso y atención. Ese realismo puede entrar en conflicto con respuesta inmediata.

**Para Astral.** Para NPC/animales, preparar giro, mirar un estímulo y luego desplazarse; alternar reposos con duración variable. Para el héroe conservar respuesta rápida y relegar el arrastre a tela/cuerpo. **Riesgo inferido:** prolongar todas las animaciones parece lentitud; reacciones azarosas constantes parecen tics. **Coste:** medio, principalmente arte. **Prueba:** un NPC se orienta hacia quien habla y vuelve a su actividad sin bloquear el paso.

## 15. The Last of Us Part II: percepción, búsqueda y comunicación

**Evidencia.** Naughty Dog/PlayStation describe enemigos con nombres y reacciones a compañeros; su documentación de accesibilidad separa ayudas de navegación, apuntado y señales. Ars Technica señala el papel de perros en la búsqueda. [Presentación](https://blog.playstation.com/archive/2019/10/09/neil-druckmann-discusses-new-the-last-of-us-part-ii-details/), [accesibilidad](https://www.naughtydog.com/blog/the_last_of_us_part_ii_accessibility_features_detailed), [crítica](https://arstechnica.com/gaming/2020/06/the-last-of-us-part-2-isnt-a-fully-satisfying-return-to-the-apocalypse/).

**Interpretación.** Oír o ver una intención permite construir un modelo del adversario. El grupo parece una comunidad, no una colección de sensores independientes.

**Para Astral.** Diferenciar sospecha, alerta, búsqueda de última posición conocida y regreso. Avisos breves mediante sonido, postura o icono; un enemigo alerta a los cercanos con alcance limitado. **Riesgo inferido:** información telepática, detección a través de árboles sólidos y búsqueda infinita. La violencia o complejidad narrativa de la referencia no son requisitos. **Coste:** medio. **Prueba:** al perder visión, el enemigo busca donde vio al héroe, no donde está escondido ahora.

## Qué se repite y qué no debe mezclarse sin decidir

Los patrones siguientes aparecen en varias referencias. Es una codificación cualitativa de esta selección, no una estadística del mercado ni una afirmación sobre implementaciones internas compartidas.

| Patrón | Referencias ilustrativas | Utilidad para Astral |
|---|---|---|
| Decisión → preparación → consecuencia → recuperación | Souls, Sekiro, Monster Hunter, HLD | El peso surge del riesgo comprensible |
| Movilidad ofensiva/defensiva | Hades, HLD, Bloodborne, DOOM | Reposicionarse cambia oportunidades |
| Pocos verbos con combinaciones | Hades, Celeste, Zelda | Profundidad con controles manejables |
| Feedback de éxito inequívoco | Sekiro, DMC, Dead Cells | Confirmar que la acción funcionó |
| Recursos que inducen conducta | Souls, Bloodborne, DOOM, Hades | Elegir qué se quiere incentivar |
| Intención perceptible del adversario | Monster Hunter, Sekiro, TLOU II | Poder anticipar sin leer tablas |
| Variación mediante encuentros/contexto | Hades, Dead Cells, Zelda | Reutilizar habilidades sin repetir decisiones |
| Habitantes con objetivos propios | Rain World, RDR2, TLOU II | Vida fuera del combate |

Conflictos: cancelación libre y compromiso fuerte no pueden gobernar el mismo momento del mismo ataque; agresión permanente y sigilo contemplativo requieren contextos diferentes; simulación indiferente al jugador y combates siempre justos necesitan un límite de seguridad; inercia realista y respuesta instantánea no son equivalentes. Elegir por estado y por criatura.

Mi combinación recomendada: respuesta y claridad de HLD/Dead Cells, relaciones espada-magia de Hades, compromiso selectivo de Souls/Monster Hunter y vida ambiental acotada de Rain World/RDR2. Sekiro, DMC, DOOM y Zelda aportan pruebas pequeñas, no sistemas enteros obligatorios.

## Diseño propuesto para el héroe

1. Un buffer de una sola acción con marca temporal; comenzar probando 100 ms, comparando 70/130 ms. Son valores propuestos, no tiempos medidos de los juegos estudiados. Una acción vencida o invalidada por muerte, menú o transición se elimina. No cobrar recursos hasta comenzar.
2. Tabla explícita de cancelaciones: ligero puede ceder a dash en recuperación; pesado conserva preparación/impacto y solo permite salir al final; comprobar antes si el dash actual ya cancela ataques. No introducir una tabla genérica si bastan las ramas existentes.
3. Ventana de giro antes de fijar dirección; después la trayectoria es legible. Añadir ayuda angular solo opcional para mando/táctil y con visión libre, nunca cambiar el objetivo del ratón sin consentimiento.
4. Mantener hitboxes calculadas desde el suelo y ancla de pies. Separar daño, empuje e intensidad visual; una criatura resistente no debe desplazarse como un slime.
5. Evaluar audio por capas: inicio del golpe, contacto según material, cuerpo/voz y cola breve. Limitar voces simultáneas y volumen acumulado. Los sonidos sintetizados existentes son un punto de partida, no prueba de calidad sonora.
6. Experimentar con pausa de impacto solo tras verificar claridad básica: empezar con 25–40 ms en pesado, sin acumular pausas por cada objetivo. Preferir pausa local/presentación; ralentizar todo el árbol puede alterar cooldowns, proyectiles y UI. Requiere temporización y accesibilidad explícitas.
7. Velocidad de ataque tiene que conservar un mínimo legible de preparación enemiga y un presupuesto de efectos. No compensar rendimiento dibujando menos avisos peligrosos.

## Monstruos: una gramática común, decisiones distintas

Estados conceptuales: tranquilo → sospecha → alerta → aproximar/posicionarse → preparar → ejecutar → recuperar → reevaluar. Huida y muerte son salidas; no todos los tipos necesitan todos los estados. Aprovechar idle/chase/windup/recover actuales en lugar de reescribir toda la IA.

| Actor | Intención y comportamiento propuesto | Señal perceptible | Respuesta disponible |
|---|---|---|---|
| Slime | Aproximación por saltos y pausa real al aterrizar | Compresión antes del salto | Apartarse y castigar aterrizaje |
| Arquero | Buscar línea libre y fijar tiro antes de soltar | Arco/sonido/línea discreta | Cubrirse o acercarse durante recuperación |
| Cíclope | Girar lentamente y comprometerse con el golpe | Hombro, arma y elipse de suelo | Salir del área y atacar después |
| Mago | Alternar presión de proyectiles y zona anunciada | Gestos/colores/formas distintos | Reposicionarse según patrón |
| Dragón | Detectar, advertir, ráfaga, respirar y recolocarse | Cuello/pecho/respiración | Aprovechar flanco y pausa |
| Depredador futuro | Rodear y perseguir con límite territorial | Mirada, gruñido, postura baja | Mantener distancia o retirarse |

Propuesta de coordinación: empezar con dos preparaciones peligrosas simultáneas por encuentro, no como cifra universal. Si sus áreas cierran todas las salidas, reducir presión o escalonar. Los demás enemigos siguen buscando posición. Excluir amenazas que aún no son visibles o anticipadas. No impedir todos los ataques fuera de pantalla silenciosamente: usar aviso o reglas de alcance claras.

La percepción guarda última posición vista, intensidad de sospecha y tiempo desde contacto. Una alerta compartida comunica posición aproximada de un evento, no acceso permanente al jugador. Oír y ver usan reglas diferentes. Abortar o resolver zonas pendientes de forma consistente si muere su dueño.

## NPC y animales: vida con pocas reglas

**NPC civil:** una actividad base (trabajar/descansar), puntos alcanzables, mirar al interlocutor, ceder paso, huir/refugiarse ante peligro y volver después. Variar pausas, pero no cambiar de objetivo cada fotograma. Interactuar detiene la actividad sin destruir su destino pendiente. Este sistema todavía requiere NPC reales en el proyecto.

**Presa:** pastar → observar al detectar ruido/visión → huir hacia un refugio navegable → esperar seguridad → volver. Un conejo no necesita estadísticas de combate ni árbol de talentos.

**Depredador:** descansar → buscar una presa válida → aproximarse → perseguir con energía/distancia limitada → abandonar/comer/volver. Ataque al héroe solo si lo identifica como amenaza/presa bajo reglas de especie.

**Territorial:** reposo → advertir dentro de un radio → atacar si se insiste → abandonar persecución fuera del territorio. Dos umbrales distintos para entrar/salir de alerta evitan oscilaciones constantes.

**Grupo:** separación personal, atracción moderada a compañeros y dirección compartida pueden producir una bandada/manada pequeña. Son reglas de steering propuestas; no se atribuyen a un juego concreto. No simular cada individuo lejano a frecuencia completa. Mantener estados resumidos y evitar aparecer junto al jugador al reactivar.

Para sprites horneados, animar intención con orientación, elección de clip y tiempos; tela/colas se pueden mejorar al renderizar en Blender. No prometer movimiento procedural 3D libre a partir de PNG. El arte mínimo por nueva especie debería decidirse según su conducta: reposo, mirar, caminar/correr y una reacción pueden bastar antes de ataques y muerte.

## Integración concreta en Godot

1. Leer los callers de combat.hit, take_damage, _dash, _attack y _begin antes de tocar contratos. Conservar que botín y ultimate se entregan una sola vez. La detonación de Ignis no debe volver a marcar ni detonar en cadena.
2. Guardar percepción y decisión en coordenadas lógicas de suelo/casilla; proyectar una sola vez para dibujar. La elipse visual y el daño deben compartir el mismo cálculo, incluido Y/0,6 cuando corresponda. Nunca mezclar píxeles escalados con datos de suelo.
3. Reutilizar world_map.move_collide y next_waypoint inicialmente. Navegación, evasión y colisión son problemas distintos. NavigationAgent2D es opcional y no mueve automáticamente al personaje; su evasión tampoco conoce por sí sola la colisión física. No migrar solo por disponibilidad del nodo. [Godot: NavigationAgents](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html).
4. Para animales/NPC, actualizar decisiones lentamente y movimiento en física. Valores iniciales de experimento: decisiones a 5–10 Hz para actores cercanos; navegación cada 0,2–0,4 s o al invalidarse el camino. No son límites del motor. Escalonar actualizaciones y medir.
5. Datos por criatura: alcance de visión, ángulo de visión, alcance de oído, tiempo de sospecha, duración de búsqueda, territorio, recuperación y resistencia al empuje. Añadir solo campos usados; usar defaults compatibles para dragón y enemigos existentes.
6. Para combate, especificar preparación/activo/recuperación e identificador de acción. Validar costes y cooldowns al iniciar, objetivos al golpear, cancelación al morir. Los índices de fotograma actuales requieren actualizar sus datos si se cambia el render.
7. Añadir depuración reversible: estado, destino, visión, última posición conocida, número de atacantes y geometría peligrosa. No poner ese detalle técnico en la interfaz normal.

## Secuencia de producción propuesta

**Fase A — comprobar base ya hecha.** Jugar y registrar sala con slime/arquero/cíclope. Identificar problemas reales antes de nuevos sistemas. Confirmar controles de ratón y táctiles locales sin sobrescribirlos.

**Fase B — respuesta y justicia.** Buffer único, cancelaciones explícitas y límites de amenaza; corregir áreas/recuperación. Comparar contra versión anterior en la misma sala.

**Fase C — identidad existente.** Refinar marca de Ignis y su feedback, ofrecer enemigos que inviten a usarla, conservar otras rutas válidas. Decidir después si hace falta recuperación de maná.

**Fase D — vida ambiental mínima.** Un civil y una presa con mirar/actividad/huida/refugio. Sin persistencia de ecosistema ni cientos de criaturas.

**Fase E — ampliación.** Depredador, alerta compartida y territorialidad. Solo después considerar postura, bloqueo/parry, sistemas de materiales o combos adicionales.

Las fases no son una estimación de horas. Cada una necesita validación y puede descartarse si perjudica la identidad o el alcance del brief.

## Experimentos y criterios de aceptación

| Experimento | Qué registrar | Condición para aceptar |
|---|---|---|
| Buffer vs actual | Entrada, estado, tiempo de inicio y expiración | Una pulsación produce como máximo una acción; cero acciones antiguas al cerrar menú |
| Pesado vs ligero | Uso, daño por oportunidad, exposición | Ambos tienen una razón situacional para usarse |
| Ataques mezclados | Preparaciones, áreas y posición de héroe | Toda combinación prevista deja una respuesta ejecutable |
| Interrupción | Dueño de zona, estado y momento del golpe | No queda daño invisible después de una cancelación |
| Percepción | Última posición vista y objetivo real | No seguir información del jugador que no se percibió |
| Huida | Camino válido, refugio y amenazas | No huir hacia agua/muro ni alternar de rumbo sin motivo |
| Vida ambiental | Observación sin intervención | Conductas con inicio, consecuencia y retorno reconocibles |
| Animación | Pies, velocidades y cambios de dirección | Cero saltos de fase; apoyo coherente; golpe coincide con contacto |
| Rendimiento | Tiempo de cuadro y picos con varios actores/luces | Objetivo inicial 60 FPS en equipo de referencia por definir; no una medición actual |
| Accesibilidad | Shake, destellos, sonido, colores y ayudas | Señales importantes comprensibles sin depender de un solo canal |

Para una primera prueba formativa, invitar 5–8 personas con experiencias distintas y observar sin instruir constantemente. Esa muestra descubre problemas, no representa al mercado. Preguntar qué creían que ocurriría, por qué recibieron daño y qué intentaron. Comparar dos versiones cambiando una variable; no vender una mejora porque el desarrollador ya aprendió el patrón.

## Límites de la investigación

No se jugó personalmente a las quince referencias durante esta tarea, no se midieron sus ventanas de input ni se accedió a código propietario. No se obtuvo un sondeo representativo de jugadores; por ello no hay ranking universal, porcentajes de gusto ni afirmaciones de causalidad. Algunas páginas oficiales, especialmente fauna de RDR2 y el manual de World, devolvieron contenido vacío o restringido; no se trataron como evidencia legible. GDC se consultó en sus materiales disponibles, no se afirma haber visto una charla completa detrás de acceso restringido.

Las recomendaciones técnicas son propuestas específicas para este proyecto y deben probarse. Esta entrega añade documentación, no cambia jugabilidad ni autoriza implementar todas las fases. Para Claude: leer también CLAUDE_RESEARCH_BRIEF.md antes de convertir propuestas en trabajo.
