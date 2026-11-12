# Lista de prueba: creación (crafteo, forja, cocina, alquimia, recolección y mina)

Objetivo: jugar una partida nueva de ~30 minutos y anotar qué se siente lento, caro o confuso. Todos los números se ajustan en `data/crafting.json` sin tocar código.

## Antes de empezar
- Borra el guardado para partir de cero (o juega con el actual y salta los pasos ya hechos).
- Teclas: **E** interactuar (mantener E repite golpes), **I** menú (pestaña *Crafteo*), **G** consumible elegido, **H** poción de vida.

## Ruta recomendada y qué mirar

| # | Qué hacer | Esperado | Anotar |
|---|---|---|---|
| 1 | Ir a un árbol y pulsar E con las manos | 6 golpes (~3 s), cae madera ×2-3 | ¿Se hace pesado talar sin hacha? |
| 2 | Picar 2-3 rocas a mano | Piedra ×2-3 por roca | ¿Cuánta piedra necesitas en total? |
| 3 | Pestaña *Crafteo*: hacha y pico de piedra | Se equipan solos; hacha: árbol en 3 golpes | ¿Los costes (3 madera + 3-4 piedra) son justos? |
| 4 | Recoger hierba vital y bayas del valle | 2-3 por arbusto, vuelven a los ~3 min | ¿Hay suficientes arbustos cerca? |
| 5 | Cazar conejos y zorros | Carne y piel (70-90 %) | ¿Salen suficientes pieles para cuero? |
| 6 | Fogata (junto a Tomás): carne asada | Animación ~1,4 s, aparece en consumibles | ¿La animación se hace larga al repetirla? |
| 7 | Mesa de alquimia: plano de poción de vida | Piedra+carbón → frascos (en *Crafteo*); luego hierba×2 + gel + frasco → 2 pociones | ¿Se entiende el plano sin explicación? |
| 8 | Comprar planos a Tomás (50 y 60 monedas) | Se aprenden, aparecen en la mesa | ¿El precio es acorde a las monedas que llevas? |
| 9 | Entrar a la mina (norte del pueblo, `[E] Entrar a la mina`) | Cueva con vetas; 5 guardianes | ¿Se encuentra la entrada? ¿Se pierde uno dentro? |
| 10 | Picar hierro (4 golpes) y carbón; el cristal debe negarse | Aviso "Necesitas un pico mejor" | ¿Está claro por qué no se rompe? |
| 11 | Forja de Bram (dentro de su casa): lingotes → pico de hierro | Cristal ya se parte | ¿Cuántas idas y venidas a la mina hacen falta? |
| 12 | Forjar espada de hierro / hoja de cristal | Se equipa y cambia el color del tajo | ¿Las espadas nuevas compensan frente a las de los cofres? |
| 13 | Morir en la mina | Despiertas en el pueblo | ¿Pierdes algo que no esperabas? |
| 14 | Guardar, cerrar y cargar | Planos, herramientas y materiales intactos | Cualquier pérdida |

## Cosas que pueden fallar (míralas con atención)
- **Muros de la mina:** si pasas por detrás de un bloque de roca, el héroe se dibuja encima. ¿Molesta?
- **Vetas de hierro y carbón:** se parecen mucho en la mina. ¿Se distinguen?
- **Pausa del panel:** al abrir mesa o forja el juego se pausa; cerrar con Esc a mitad de una animación no debe cerrar.
- **Mantener E:** talar seguido no debe atascarse ni disparar el diálogo de un NPC cercano.
- **Hitbox de la mesa y la fogata:** no debe quedar atrapado el héroe al caminar pegado.
- **Rendimiento:** FPS en la mina y en el pueblo con todos los arbustos.

## Valores para ajustar (en `data/crafting.json`)
- Golpes por recurso: `gather.<tipo>.hp` y `tool_power`.
- Cantidad que cae: `gather.<tipo>.drops`; reaparición: `gather.<tipo>.respawn` (segundos).
- Costes: `recipes.<receta>.inputs`; resultado: `qty`.
- Duración de las animaciones: `stations.<oficio>.time`.
- Tamaño y enemigos de la mina: `mine.tiles`, `mine.nodes`, `mine.enemies`.
- Efectos de comida y pociones: `consumables.<id>`.
- Precio de planos y de venta de materiales: `data/shop.json`.

## Al terminar
Pásame lo anotado (aunque sea en frases sueltas) y ajusto los valores y los fallos.
