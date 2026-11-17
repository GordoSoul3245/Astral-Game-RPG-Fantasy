# Arte natural y con vida (guía del proyecto)

Fuente: "Stylized Grass & Trees for Pixel Art 3D in Godot 4" (Eduardo Schildt) y el video de pasto de Dylearn.
Ecos de la Ruina es 2D con sprites pre-renderizados desde Blender, así que cada idea va traducida a nuestro pipeline.

## Las ideas de fondo (no recetas sueltas)
1. **Todo comparte una sola luz y una sola paleta.** El pasto usa la misma luz y el mismo color que el suelo de debajo:
   así no se ve "pegado". Regla: cualquier vegetación o decorado se tiñe y se sombrea con la misma función que el suelo.
2. **Forma simple, detalle en la silueta.** Copas = esfera deformada con ruido (Displace "clouds") + remesh; troncos = cilindro
   con raíces. Texturas casi planas: a baja resolución el detalle fino parpadea. El carácter va en el contorno, no en la textura.
3. **Pocas bandas de luz (cel shading).** Cuantizar la luz en 2-4 escalones; un borde de luz (rim) solo en el lado iluminado
   da volumen sin ruido. Especular a cero.
4. **Sombra por objeto, no por píxel.** Una mata o un árbol recibe la sombra entero (la luz se calcula en su pivote/forma
   original), lo que da manchas limpias, legibles en pixel art.
5. **La vida viene de UN viento global.** Un ruido que se desplaza por el mundo (coordenadas de mundo, no del objeto) con
   dirección, escala, velocidad y fuerza globales: todo lo que se mueve (pasto, hojas, telas) lee los mismos valores, así
   sopla una misma ráfaga por la escena. Cada tipo solo decide cuánto se dobla ("bend").
6. **Solo se mueve lo que estaría libre.** Máscara por altura: la base del pasto quieta, la punta se mueve.
   En hojas sin pivote propio: mover las esquinas opuestas en sentidos contrarios imita una rotación.
7. **Movimiento estilizado, no físico.** Doblar de lado respecto a la cámara (no hacia ella) para que nada "desaparezca";
   pocos fotogramas con fase distinta por objeto da encanto de animación dibujada sin que todo cambie a la vez.
8. **Separar lo que se ve de lo que proyecta sombra.** Si algo animado hace parpadear sombras, la sombra la proyecta una
   copia quieta. En 2D: la sombra de un árbol es un sprite fijo; solo la copa se mece.
9. **Variedad controlada.** Manchas de color por ruido del mundo, unas pocas piezas de acento, rejilla con azar fijo por
   casilla: natural pero estable (lo mismo cada vez que se carga).

10. **El pixelado es renderizar pequeño y ampliar sin suavizar.** Toda la escena se dibuja a baja resolución y se escala
    con filtro "nearest". No hace falta pintar píxel a píxel: la resolución baja es la que crea el estilo y unifica todo.
    (Nosotros ya lo hacemos: sprites de Blender a 128 px y escala x3.)
11. **Contornos que explican la forma: oscuro afuera, claro adentro.** Se comparan la profundidad y la normal de cada píxel
    con sus 4 vecinos. Un salto de profundidad = borde exterior, se oscurece; un cambio de normal sin salto de profundidad
    = arista interior (pliegue, esquina de techo, tablón), se aclara. Un solo píxel de grosor, con umbral, y una máscara
    para que no salgan líneas dobles. Ese "brillo en las aristas" es lo que hace que una casa o una roca se lean como
    objeto sólido y cuidado. La vegetación (pasto, hojas) va sin contorno: queda suave y viva frente a lo construido.
12. **Escena final = pocas cosas que se refuerzan:** pixelado + paleta cálida + cel shading + contornos + luz que se cuela
    (rayos, sombras de nubes) + objetos pequeños de vida (banderines, puestos, flores). La vida no es un efecto: es
    densidad de detalle pequeño y movimiento coordinado.

13. **Píxeles estables al moverse (Red Giraffe, "Pixel Perfect").** Si los píxeles de arte se mueven en posiciones decimales,
    cruzan la rejilla de forma desigual: el sprite "tiembla" (shimmer, se estira y encoge un píxel). Dos familias:
    - *Pixel perfect:* todo se dibuja en la rejilla baja y solo salta de celda en celda (estable, pero la cámara va a saltos).
    - *Sub-texel:* el arte es pixel art pero se mueve libremente (suave, con algo de temblor).
    La solución buena junta las dos: la cámara que "fotografía" la escena se redondea a la rejilla (sin temblor) y lo que
    se perdió al redondear se devuelve desplazando la imagen final en alta resolución (movimiento suave). La rotación de
    cámara no tiene arreglo limpio (se acepta el temblor, o se disimula con un poco de desenfoque, tramado o más pixelado).
    En lo nuestro (2D, sprites x3): mantener los sprites en múltiplos de 3 px de pantalla (rejilla del arte) y mover la cámara
    suave; nada de rotar la cámara; los efectos dibujados por código se ajustan a la misma rejilla de 3 px (como ya hace la estela).

14. **Agua viva por capas (Red Giraffe, "Pixel Art Oceans").** Plana, no simulada. Se apilan capas, cada una con su control:
    color por profundidad (claro en la orilla -> oscuro en lo hondo) -> refracción falsa (ruido animado que desplaza lo que
    se ve debajo, más fuerte cuanto más hondo) -> olas grandes y lentas (dos senos perpendiculares multiplicados: va y viene)
    -> espuma de orilla (1 px, irregular a propósito) -> espuma suelta (ruido con umbral que se desplaza) -> reflejo.
    Cambiando pesos y texturas, el mismo sistema da mar tormentoso o laguna tropical. Ojo: lo continuo (degradados) también
    se cuantiza a la paleta para no romper el pixel art. Movimiento y riqueza de color son lo que dice "líquido".
    En lo nuestro: el agua del valle y las charcas (`region.gd`) pueden ganar con un shader 2D por capas: degradado orilla ->
    centro por distancia a tierra (casillas), ondas lentas, espuma de 1 px en el borde de casillas de agua, destellos por ruido
    con umbral, y todo cuantizado a 3-4 tonos de la paleta. Debe moverse con el mismo viento que el pasto.

15. **Árboles con anatomía, aunque sean estilizados (Dylearn, "stylized trees").** Tronco grueso que sostiene; ramas que salen
    afinándose (gruesas abajo, finas en los bordes); raíces visibles que se abren (nebari) y anclan; copa con la forma de la
    especie. Las ramas siguen un flujo (espiral, alternadas). Estilizar = quitar ramitas y quedarse con las formas grandes que
    marcan el flujo. Recto y alto (pino, compite por luz) vs ancho y abierto (arce, sombra). Ni muy rígido ni muy caído.
    Copa: formas simples apiladas que se achican hacia arriba, y sobre ellas muchas hojitas-sprite del mismo shader que el pasto
    (se mecen; tamaño justo: grandes se cruzan, pequeñas dejan ver huecos). Variedad: otras hojas, flores, piñas en el mismo
    shader. Profundidad: hojas que caen girando con el centro de giro desplazado (turbulencia natural).
    Composición: para bosques, árboles de forma simple y parecida (masa cohesiva); los árboles raros y llamativos, pocos y
    donde cuenten algo (narrativa del entorno). El mismo sistema de "hojas sobre una forma" sirve para enredaderas en muros.
    En lo nuestro: rehacer `tree_a/b/c` en Blender con esta anatomía (raíces visibles, copa por capas), copa con brillo de
    borde; en el juego, la copa se mece con el viento global y caen unas pocas hojas como partículas; enredaderas en casas.

## Cómo lo aplicamos aquí
- Pasto: `scripts/grass_tile.gd` + `shaders/grass*.gdshader` ya siguen 1, 4, 5, 6, 7 y 9.
- Siguiente paso natural: árboles del valle con copa que se mece con el mismo viento (parámetros en un único lugar,
  `GrassTile.material()`/shader globals) y sombra fija aparte; renderizar copas en Blender con la receta de la idea 2.
- Al crear cualquier sprite nuevo en Blender: paleta del juego, 2-4 tonos, silueta con carácter, textura casi plana.
- Contornos (idea 11) en nuestro pipeline: se hacen al renderizar en Blender, no en Godot (somos 2D). En el compositor,
  pases de profundidad (Z) y normal: borde exterior oscuro y aristas interiores claras, de 1 px a 128 px, solo en edificios,
  rocas, cofres y personajes; nunca en pasto ni copas.
