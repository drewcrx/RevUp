# Auditoría previa a la demo de RevUp

Fecha: 20 de octubre de 2026.

Estado posterior: las correcciones y ampliaciones solicitadas se documentan en
[Mejoras de la demo](mejoras_demo.md). Este informe conserva los resultados y
hallazgos de la revisión inicial.

## Evaluación general y alcance

La app permite demostrar un recorrido completo de taller: clientes y vehículos,
órdenes, diagnóstico, inspección de daños de ingreso y entrega, fotos,
actualizaciones de trabajo, servicios, repuestos, pagos, entrega, seguimiento
público mediante QR e informes por mes y por mecánico. También tiene
autenticación, recuperación de cuenta, sesión persistida y permisos por rol.

La prioridad recomendada es afinar la fiabilidad de ese recorrido y facilitar
su presentación. Añadir muchos módulos antes de la demo ampliaría las partes
que necesitan validación.

Esta revisión abarca el código Flutter, las rutas Express, el esquema de datos
y pruebas automatizadas. Las comprobaciones nuevas usaron datos sintéticos,
peticiones simuladas y PostgreSQL en memoria. No se modificó la lógica de la
app ni la base real del taller. La revisión no sustituye una nueva prueba de
la última APK en el teléfono.

## Hallazgos que conviene atender

### 1. Un precio con coma puede guardarse como cero — prioridad alta

En el formulario de servicios, escribir `12,50` envía `precio: 0.0`.
Se reprodujo con una prueba de interfaz y un cliente HTTP simulado.
La conversión usa `double.tryParse(...) ?? 0`, por lo que una entrada que no
se interpreta como número se convierte silenciosamente en un servicio gratis.
Los costos y precios de repuestos siguen el mismo patrón; en pagos la entrada
con coma se rechaza como monto inválido.

Recomendación: aceptar una entrada decimal consistente, validar antes de enviar
y mostrar el error en el campo. Un cero debe ser una decisión explícita del
usuario, no la consecuencia de una conversión fallida. Rechazar valores
ambiguos o no finitos y normalizar la presentación a dos decimales.

Referencia: [detalle_orden.dart](../lib/src/detalle_orden.dart), líneas 286,
415–416 y 475.

### 2. Las solicitudes de pago repetidas se contabilizan por separado — prioridad alta

En una orden con total de $50, dos solicitudes de pago de $50 devolvieron
HTTP 201 y dejaron dos pagos que suman $100. Se reprodujo contra la API
aislada. El bloqueo transaccional existente protege el cierre y los cargos
concurrentes, pero no identifica la repetición de una misma operación.
El botón Guardar de los diálogos tampoco se desactiva mientras espera.

Recomendación: bloquear pulsaciones durante el guardado e identificar cada
intento de cobro para que un reintento no lo duplique. Mostrar total, abonado y
saldo antes de confirmar. Rechazar o gestionar explícitamente cualquier exceso;
si se desea aceptar anticipos o registrar cambio, debe existir una regla clara.
Conservar la posibilidad de hacer dos abonos legítimos de igual importe.

Referencias: [detalle_orden.dart](../lib/src/detalle_orden.dart), líneas 434 y
1356; [ordenes.js](../api/revup-api/routes/ordenes.js), línea 1017.

### 3. Eliminar un vehículo también elimina sus órdenes y pagos — prioridad alta

La eliminación física del vehículo se propaga mediante relaciones
`ON DELETE CASCADE`. En la comprobación aislada se eliminó un vehículo con
una orden entregada y pagos: la API devolvió HTTP 200 y quedaron cero órdenes
y cero pagos asociados. La interfaz sí pide confirmar la eliminación, pero
el mensaje no explica que se pierde ese historial.

Recomendación: archivar vehículos con historial y reservar la eliminación
definitiva para registros sin movimientos. Mostrar con claridad la consecuencia
de cada acción. Esto protege también la consistencia de los informes históricos.

Referencias: [vehiculos.dart](../lib/src/vehiculos.dart), línea 549;
[vehiculos.js](../api/revup-api/routes/vehiculos.js), línea 377;
[base_schema.sql](../api/revup-api/db/base_schema.sql), líneas 54 y 90.

### 4. El cierre del formulario de servicios provoca un error de controlador — prioridad alta

La prueba adicional de interfaz detectó
`A TextEditingController was used after being disposed` al guardar un servicio
con una respuesta HTTP simulada inmediata. Los controladores se liberan al
retornar `showDialog`, mientras el diálogo puede seguir presente durante su
animación de salida. Hay un patrón similar en otros formularios del detalle.

Recomendación: dar al propio diálogo la responsabilidad sobre el ciclo de vida
de sus controladores y verificar guardar, cancelar y volver atrás con el teclado
abierto. Reproducido en pruebas de widgets; su efecto en la APK física requiere
comprobación específica y no se afirma que cierre la app en producción.

Referencia: [detalle_orden.dart](../lib/src/detalle_orden.dart), líneas 298,
430 y 488.

### 5. El kilometraje de una nueva visita puede reutilizar el dato anterior — prioridad media

Al crear una orden desde un vehículo seleccionado, si existe un kilometraje
mayor que cero se muestra como dato informativo y se vuelve a enviar ese mismo
valor. El usuario puede actualizar el vehículo previamente, pero no confirmar
o corregir el kilometraje dentro de ese flujo de creación.
La API ya admite guardar un kilometraje propio de cada orden.

Recomendación: precargar el último valor y permitir confirmarlo o actualizarlo
al recibir el auto. Advertir ante una disminución y conservar el valor de cada
visita. Es una mejora del flujo actual, sin necesitar otro módulo.

Referencias: [nueva_orden.dart](../lib/src/nueva_orden.dart), líneas 74, 110 y
343; [ordenes.js](../api/revup-api/routes/ordenes.js), línea 341.

### 6. La entrega necesita una confirmación y una política de cambios posteriores — prioridad media

El botón de entregar llama directamente al cierre. La API bloquea correctamente
la entrega con deuda y los cambios financieros posteriores. Sin embargo, una
orden entregada sigue aceptando cambios de diagnóstico: se comprobó un PUT
que devolvió HTTP 200 después de cerrarla.

Recomendación: mostrar un resumen de confirmación con placa, trabajo y cobros.
Definir qué documentos quedan cerrados y registrar las correcciones posteriores
como anotaciones con autor y fecha. Permitir documentar fotos de entrega sin
alterar silenciosamente la evidencia original de ingreso.

Referencias: [detalle_orden.dart](../lib/src/detalle_orden.dart), línea 492;
[ordenes.js](../api/revup-api/routes/ordenes.js), líneas 574 y 1046.

### 7. Un mes inexistente produce un error de servidor — prioridad baja

La validación admite el formato `2026-13`. La API respondió HTTP 500 en la
comprobación aislada: la expresión de formato no valida el rango del mes.
Reportes pide escribir el mes, mientras Inicio ya tiene selector de fecha.

Recomendación: usar un selector de mes consistente y validar el rango tanto
en la interfaz como en la API. Una entrada inválida debe recibir HTTP 400
y una explicación clara.

Referencias: [reportes_page.dart](../lib/src/reportes_page.dart), líneas 57 y
496; [reportes.js](../api/revup-api/routes/reportes.js), línea 11.

## Añadidos que aportan valor al producto actual

| Mejora | Qué aporta | Alcance orientativo |
| --- | --- | --- |
| Búsqueda y filtros de órdenes | Encontrar por placa o número; filtrar recibidas, en proceso, entregadas y con saldo. Vehículos ya tiene búsqueda, pero Órdenes todavía muestra la lista completa. | Pequeño a medio |
| Resumen financiero visible | Mostrar Total, Abonado y Saldo juntos, con un botón «Cobrar saldo». Ya hay abonos; se mejora su visibilidad y seguridad. | Pequeño |
| PDF de la orden | Resumen imprimible con cliente, vehículo, diagnóstico, servicios, repuestos, total, abonos y saldo. El PDF actual genera etiquetas QR, no el documento completo de la OT. | Medio |
| Lista de recepción y entrega | Confirmar kilometraje, nivel de combustible, accesorios recibidos, fotos y revisión de daños. Distinguir «sin daños» de «todavía sin inspeccionar». | Medio |
| Estado «Listo para retirar» | Distinguir reparación terminada de entrega realizada. El estado actual «en proceso» se activa con cargos, por lo que la etapa del trabajo no es independiente del cobro. | Medio |
| Compartir seguimiento | Botón para compartir el enlace QR mediante las opciones del teléfono. Aprovecha la página pública que ya funciona. | Pequeño |
| Comparación de ingreso y entrega | Visor que ponga las fotos de ambas etapas juntas y permita ampliarlas. Aprovecha las fotos y daños ya separados por etapa. | Pequeño a medio |
| Estado del servidor y última actualización | Informar si la PC/API está disponible y ofrecer reintento. El punto verde del avatar actual es decorativo, no mide conectividad. | Pequeño a medio |
| Mejor presentación de reportes | Selector de mes, importes uniformes y una gráfica sencilla de ingresos, gastos y saldo. Reutiliza los informes existentes. | Pequeño a medio |
| Protección del formulario | Advertir al salir con datos sin guardar o recuperar un borrador de recepción. Útil ante volver atrás por accidente. | Medio |

Al mejorar Órdenes conviene corregir además su agrupación: la API devuelve
órdenes por fecha y la interfaz agrega una cabecera cada vez que cambia el
estado entre filas. Con estados intercalados pueden repetirse las mismas
cabeceras. Los filtros o grupos explícitos resolverían esa confusión.

Referencias de estas oportunidades: [ordenes.dart](../lib/src/ordenes.dart),
línea 193; [detalle_orden.dart](../lib/src/detalle_orden.dart), línea 1011;
[detalle_vehiculo.dart](../lib/src/detalle_vehiculo.dart), línea 715;
[navbar.dart](../lib/src/navbar.dart), indicador verde del avatar.

## Alcance recomendado para esta demo

1. Resolver importes, cobros repetidos, eliminación de historial y cierre de
   formularios. Añadir pruebas de regresión para esos casos.
2. Confirmar la entrega y validar correctamente el mes. Revisar la captura del
   kilometraje de ingreso dentro del flujo existente.
3. Añadir búsqueda de órdenes y resumen de saldo. Si queda margen de validación,
   sumar el PDF de la orden como mejora visible principal.
4. Compilar la última APK y recorrer el flujo completo en el teléfono con la
   PC/API y el QR que se usarán en la presentación.

Para una siguiente etapa quedarían agenda de citas, inventario con existencias
reales —distinto del catálogo de repuestos actual—, aprobación de presupuestos,
recordatorios y nuevas carrocerías para la inspección. Un visor 3D de giro libre
también puede explorarse después: implica modelos, selección de piezas,
compatibilidad y rendimiento que requieren su propia validación.

## Recorrido sugerido para la presentación

1. Crear cliente y vehículo, o abrir uno de demostración.
2. Crear una orden, confirmar el kilometraje y documentar daños de ingreso.
3. Añadir diagnóstico y una actualización con foto; mostrarla mediante el QR.
4. Registrar un servicio de $12.50 y dos repuestos de $10: total $32.50.
5. Registrar un abono de $10: saldo $22.50. Mostrar que no se entrega con deuda.
6. Registrar el saldo, revisar las fotos de entrega y confirmar la entrega.
7. Mostrar historial e informe del mes. Presentar el PDF de la OT si se incorpora.

Preparar datos sintéticos de una orden recién recibida, otra en proceso y otra
entregada facilitará explicar la app sin depender de crear todos los casos en vivo.

## Resultado de la validación

- `flutter test --no-pub`: **25 pruebas existentes aprobadas**.
- `npm test --prefix api/revup-api`: **16 pruebas existentes aprobadas**.
- Comprobaciones adicionales de API en memoria: pagos repetidos y exceso de
  cobro, modificación de diagnóstico después de entregar, mes inexistente y
  eliminación de un vehículo con órdenes y pagos. Reprodujeron los
  comportamientos descritos arriba.
- Comprobación adicional Flutter: confirmó el envío de cero para `12,50` y
  detectó el error de controlador al cerrar el diálogo de servicios. Esta
  prueba adicional falla; no está incluida entre las 25 pruebas existentes.

Los reproductores locales están en `.local/audit_demo.mjs` y
`.local/audit_demo_test.dart`, con registros de interfaz en `.local/`.
Esa carpeta está ignorada por Git y no se incorpora a la app.
