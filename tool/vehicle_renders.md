# Recursos visuales de la inspección

La app incorpora además un visor 3D giratorio en `lib/src/vehiculo_3d.dart`, con
geometría local para sedán, SUV y pickup. Ese visor es independiente de los PNG
de referencia descritos aquí y permite seleccionar piezas al girar el modelo.

Los cuatro PNG de `assets/images/inspeccion/` se generaron con la herramienta
integrada `image_gen`, sin CLI ni dependencias nuevas. Miden 1536 × 1024 y se
incluyen en el paquete Flutter para funcionar sin descargar imágenes.

| Archivo | Vista |
| --- | --- |
| `sedan_frontal.png` | Frontal |
| `sedan_posterior.png` | Posterior |
| `sedan_lateral.png` | Lateral izquierdo; Flutter refleja la imagen para el derecho |
| `sedan_superior.png` | Superior; se recorta el fondo lateral para aprovechar la pantalla |

Es un sedán genérico de referencia: son proyecciones prerenderizadas, no un
modelo 3D con rotación libre ni una reproducción de la marca y modelo de la
orden. La posición de las piezas se define en `lib/src/inspeccion_vehiculo.dart`.
La imagen y los marcadores reciben el mismo recorte y zoom. Los nombres de
vistas y zonas siguen siendo compatibles con los daños existentes. Izquierda
y derecha corresponden a los lados del vehículo desde la posición del conductor.

## Prompts de generación

Se envió una solicitud por imagen. Cada solicitud combina el siguiente prompt
común con la especificación de su vista.

```text
Use case: product-mockup. Asset type: production vehicle inspection illustration for a Flutter auto workshop app. Create ONE high quality photorealistic physically based 3D studio render of a modern generic midsize four-door sedan, metallic pearl silver paint, black glass panoramic roof, slim angular LED headlamps, restrained hexagonal dark grille, body-colored mirrors, five spoke machined alloy wheels, realistic panel gaps. Entire vehicle undamaged, no logos or branding, no license plate text. Smooth flat very dark navy background exactly #080E1A with subtle contact shadow only, no environment, no floor horizon, no decorative graphics, no UI, no annotations, no borders, no text, no watermark. Soft large studio lights show panel contours and metallic reflections clearly. The car must look like a real manufactured car, not a diagram. Sharp clean edges. Landscape 1536x1024 composition.
```

### Frontal

```text
Camera: EXACT symmetrical straight FRONT elevation, looking at headlights, hood and windshield, camera elevated slightly enough to see the hood surface clearly but NOT a three quarter view. Both sides perfectly symmetric. Whole car centered; outermost mirrors between x=12% and x=88%, top roof y=18%, bottom tires y=85%. Hood between y=40% and y=59%, windshield y=25%-40%, lamps around y=59%, grille y=69%, blank plate y=76%. Vehicle front faces the viewer.
```

### Posterior

```text
Camera: EXACT symmetrical straight REAR elevation, looking at tail lights, trunk and rear windshield, camera elevated slightly to see trunk surface clearly but NOT a three quarter view. Both sides perfectly symmetric. Whole car centered; outermost mirrors between x=12% and x=88%, top roof y=18%, bottom tires y=85%. Rear windshield y=25%-40%, trunk y=44%-58%, tail lamps around y=59%, blank rear plate at y=70%, rear bumper y=78%. Vehicle rear faces the viewer.
```

### Lateral

```text
Camera: EXACT full LEFT SIDE orthographic elevation, the FRONT of car points LEFT and the rear points RIGHT. No front or rear face visible. Entire sedan occupies x=6%-94%, roof y=28%, tire bottoms y=80%. Front wheel center (25%,67%), rear wheel center (76%,67%). Clear two left doors and panel seams, front left fender around (17%,53%), front door (42%,52%), rear door (61%,52%), rear fender (83%,52%), left mirror (35%,43%). Wide low realistic sedan proportions.
```

### Superior

```text
Camera: EXACT overhead TOP DOWN orthographic view, front hood points UP, trunk points DOWN. No side elevation visible. Whole sedan centered and vertical, front bumper y=5%, rear bumper y=95%. Main body occupies x=31%-69%, mirrors extend to x=26% and x=74%. Hood centered around (50%,22%), windshield (50%,37%), panoramic black glass roof (50%,52%), rear glass (50%,68%), trunk (50%,81%). Detailed genuine car with side mirrors, visible body seams and realistic reflections.
```

Las coordenadas finales se ajustaron después de inspeccionar las imágenes
generadas; no se asume que reproduzcan exactamente las posiciones del prompt.
