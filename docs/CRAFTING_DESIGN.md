# Diseño: sistema de creación conectado (forja, alquimia, runas, cocina, invocación)

Estado: **implementado en parte** (crafteo a mano, forja, cocina, alquimia con planos, recolección y mina; ver `docs/DESIGN_NOTES.md` §5c). Sin implementar: la matriz de elementos, runas e invocación. Investigación y propuesta para Ecos de la Ruina.
Lo marcado como *(fuente)* viene de las páginas citadas al final; el resto es análisis propio y conocimiento general de diseño de juegos.

## 1. Qué hacen otros juegos y por qué funciona

| Modelo | Ejemplos | Cómo funciona | Por qué engancha |
|---|---|---|---|
| **Árbol de mejoras con materiales de monstruo** | Monster Hunter | Matas, cortas partes y forjas arma o armadura; cada arma tiene su árbol y se desbloquea con un material clave; se puede deshacer y recuperar materiales *(fuente)* | Cada pelea tiene una recompensa concreta y un motivo para repetirla; la progresión se ve en el árbol |
| **Descubrimiento por experimentación** | Potion Craft, Skyrim | Potion Craft sustituye la lista de recetas por un mapa donde se dirige el efecto con ingredientes; Skyrim da 4 efectos ocultos por ingrediente que se descubren comiéndolo o mezclando, y la habilidad solo da potencia *(fuente)* | El jugador siente que entiende el sistema, no que memoriza una lista |
| **Sistema que multiplica** | Breath of the Wild, Tears of the Kingdom | Los objetos afectan a otros objetos; en lugar de crear algo divertido, se crea un sistema que produce cosas divertidas; Fuse combina dos objetos cualesquiera sin código por caso *(fuente)* | Soluciones inesperadas y anécdotas propias |
| **Constructor de reglas ordenadas** | Noita | Los modificadores actúan sobre el hechizo que está a su derecha y suman coste de maná *(fuente)* | El orden es el diseño: mucha profundidad con pocas piezas |
| **Crafteo con riesgo** | Path of Exile | Orbes que añaden o quitan propiedades; en PoE 2 no existe el orbe que borra todo para reintentar, así que cada decisión pesa *(fuente)* | Elegir con riesgo da tensión y control |
| **Runas en ranuras** | Diablo 2, PoE Runesmithing *(fuente)* | Piezas pequeñas que se encajan y combinan | Personalización sin llenar de menús |
| **Cocina** | Breath of the Wild | Olla de hasta 5 ingredientes; sus desarrolladores simplificaron un sistema que era más complejo *(fuente)* | Recompensa inmediata y cotidiana |

### Qué es lo complejo de verdad
1. **Datos, no recetas.** Se definen *propiedades* de los materiales y reglas de combinación; las recetas salen solas. Los desarrolladores de Ember vieron que escribir combinaciones a mano no escalaba y pasaron a categorías con potencia ligada a la rareza *(fuente)*.
2. **Que las partes se hablen entre sí.** El mismo elemento (fuego, tormenta) tiene el mismo efecto en una poción, una runa, una comida y un arma.
3. **Riesgo de la pura adivinanza.** Si las combinaciones parecen arbitrarias, el descubrimiento se vuelve un juego de azar *(fuente)*. Hacen falta pistas legibles (nombres, colores, familias).
4. **Decisiones con coste.** Hay que poder equivocarse y perder algo, pero sin castigo cruel.

### Por qué lo quieren los jugadores (análisis propio)
Autoría ("lo hice yo"), dominio (aprender un sistema), propósito para el botín (cada drop sirve para algo), identidad de build y una economía propia (lo fabricado vale más que lo vendido).

## 2. Lo que ya tiene el juego
- Materiales reales que sueltan los monstruos: `gel_slime`, `hueso_antiguo`, `ojo_ciclope`, `nucleo_tormenta` y `escama_dragon` (`data/equipment.json`, `data/creatures.json`).
- Bram (herrero) solo **compra** materiales: hoy es un sumidero de monedas, no de creación.
- Equipo con `slot`, `tier` y `mods` (7 estadísticas), tienda de Tomás e inventario con equipo.
- Fuego de Ignis que **marca** y detona, caza de fauna (conejo, zorro), maná, estamina y postura de élites.
- Misiones en cadena con Elda.

## 3. Propuesta: una capa común de esencias
Todo se conecta con dos archivos de datos nuevos.

**`data/materials.json`**, cada material (monstruo, planta o mineral):

    "nucleo_tormenta": {"tags": ["arcano", "mineral"], "essence": {"tormenta": 3, "vital": 0, "sombra": 1},
                        "quality": 3, "rarity": 4, "source": "storm_mage"}

**`data/elements.json`**, la matriz de reacciones que usan TODOS los sistemas:

    fuego + tormenta -> explosión
    fuego + vital    -> cura que arde
    tormenta + sombra -> cadena

Cualquier oficio recibe un conjunto de esencias y devuelve un resultado con esa misma matriz. Nada se programa receta por receta.

### Los cinco oficios, conectados por las esencias
| Oficio | Dónde | Qué consume | Qué produce | Conexión |
|---|---|---|---|---|
| **Forja** | Bram | Mineral, hueso, escamas | Mejora de armas y armadura (+1…+5) y cambio del tipo de daño (infusión) | El tipo de daño es un elemento de la matriz |
| **Alquimia** | NPC nueva o mesa en el pueblo | Gel, plantas, ojos | Pociones y bombas lanzables | Efectos ocultos que se descubren usando el ingrediente |
| **Runas** | Altar | Núcleos y runas | Hechizos y armas con ranuras ordenadas | Forma + elemento + modificador definen la bola de energía |
| **Cocina** | Hoguera, casa | Carne de caza y plantas | Comidas con bonus temporales a las 7 estadísticas | Conecta con la caza de fauna y el descanso |
| **Invocación** | Círculo ritual | Núcleos y maná | Un "eco" aliado que reutiliza los sprites de un monstruo derrotado | Conecta con el bestiario y la lore (Ecos de la Ruina) |

### Cómo se une con el combate (para que no sea un menú aparte)
- **Partes al romper la postura:** el material raro cae al romperle la postura a un élite, no solo al matarlo (como en Monster Hunter, pero con tu sistema de postura).
- **Calidad según cómo luchas:** una muerte limpia (esquiva perfecta, sin recibir daño) da material de más calidad.
- **Infusiones visibles:** cambian el color del tajo y de las siluetas del dash según el elemento.
- **Runas del grimorio:** definen la bola de energía (haz, orbe, abanico), el elemento y el modificador, sobre lo que ya dibuja `projectile.gd`.

### Qué lo hace complejo pero legible
- Descubrimiento con **pistas** (familias de color y nombre) y un **diario** que registra lo aprendido. Como en Skyrim, la habilidad da potencia, no el conocimiento.
- **Calidad** variable según materiales y pericia, sin azar puro.
- **Especialización:** subir un oficio abre opciones nuevas, no solo números.
- **Sumideros de economía:** lo fabricado vale más que lo vendido; las monedas que hoy van a Bram pasan a pagar creación.
- **Deshacer mejoras** recuperando parte de los materiales, para que probar no duela.

## 4. Cómo implementarlo
1. **Lógica pura y testeable** en `scripts/crafting.gd`: `combine(oficio, ingredientes) -> resultado`, sin nodos ni interfaz. Se prueba con tests headless como el resto.
2. **Objetos como instancias, no solo ids.** Hoy un objeto es un id fijo. Para mejoras (+3), infusiones y calidad hay que guardar `{id, nivel, infusión, ranuras, calidad}`. **Es el cambio técnico más grande:** toca inventario, tienda, guardado y migración de partidas.
3. **Interfaz:** reutilizar la pantalla de inventario con una pestaña por oficio.
4. **Datos antes que código:** materiales, elementos, recetas base y tablas de mejora en JSON, ajustables sin tocar scripts.
5. **Guardado:** versionar el formato y migrar las partidas antiguas.

### Fases
| Fase | Contenido | Riesgo |
|---|---|---|
| 1 | `materials.json`, `elements.json`, objetos como instancias, guardado y migración | Medio: toca inventario y guardado |
| 2 | Forja de Bram: mejoras +1…+5 e infusión elemental | Bajo |
| 3 | Cocina (la caza ya existe) y alquimia con descubrimiento y diario | Medio: diseño de pistas |
| 4 | Runas y constructor de hechizos ordenado (une con `projectile.gd`) | Alto: equilibrio |
| 5 | Invocación (reutiliza sprites de monstruos) | Alto: IA aliada y equilibrio |

### Riesgos
- **Equilibrio explosivo:** una matriz de combinaciones es difícil de balancear; empezar con 4 elementos.
- **Volumen de contenido:** muchas combinaciones sin diseño intencional se sienten vacías.
- **Interfaz:** más oficios significan más menús; conviene un solo punto de entrada.
- **Alcance:** cada oficio es casi un juego pequeño; mejor terminar la fase 2 antes de empezar la 3.

## Fuentes
- [Potion Craft (PC Gamer)](https://www.pcgamer.com/potion-craft-has-finally-given-me-a-crafting-system-i-dont-hate)
- [5 approaches to crafting systems (Tuts+)](https://code.tutsplus.com/5-approaches-to-crafting-systems-in-games-and-where-to-use-them--cms-22628a)
- [Crafting the crafting in Ember (Game Developer)](https://gamedeveloper.com/design/crafting-the-crafting-in-ember)
- [Camelot Unchained alchemy (MassivelyOP)](https://massivelyop.com/2021/03/05/interview-camelot-unchained-lays-out-its-innovative-alchemy-system/)
- [Monster Hunter weapon trees (Shacknews)](https://shacknews.com/article/106719/dual-blades-upgrade-tree-and-crafting-materials-monster-hunter-world)
- [Why people love Monster Hunter (PC Gamer)](https://www.pcgamer.com/why-people-love-monster-hunter-so-damn-much)
- [Nintendo explains Zelda physics at GDC (TechSpot)](https://www.techspot.com/news/102483-nintendo-explains-philosophy-behind-zelda-physics-gdc.html)
- [Zelda BotW cooking explained (Zelda Dungeon)](https://www.zeldadungeon.net/breath-of-the-wilds-developers-explain-the-cooking-system-in-depth/)
- [Noita wand mechanics](https://noita.wiki.gg/wiki/Guide:_Wand_Mechanics)
- [Path of Exile 2 crafting overview (Maxroll)](https://maxroll.gg/poe2/resources/path-of-exile-2-crafting-overview)
- [Skyrim alchemy (UESP)](https://en.uesp.net/wiki/Skyrim:Alchemy)
