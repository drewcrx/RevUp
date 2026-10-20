# Mejoras de la demo · RevUp 1.1.0

Se implementó el alcance solicitado en la auditoría y su ampliación: inventario
con existencias, recordatorios y visor 3D. La agenda y la aprobación de
presupuestos quedaron excluidas por indicación del usuario.

## Cambios disponibles

| Mejora | Dónde se utiliza |
| --- | --- |
| Importes con coma o punto | Servicios, repuestos y pagos validan dos decimales y no convierten entradas inválidas en cero. |
| Cobros protegidos | Guardar queda bloqueado durante la solicitud; cada intento de pago tiene un identificador. La API reproduce un reintento sin duplicarlo y rechaza importes que superen el saldo. |
| Conservación del historial | Retirar un vehículo con órdenes o movimientos lo archiva. Vehículos → icono de archivo permite consultar y restaurar esos registros. |
| Formularios estables | Los diálogos esperan a que termine su salida antes de liberar controladores. Los formularios de registro y las pantallas nuevas advierten al salir con cambios sin guardar. |
| Kilometraje por visita | Nueva orden precarga el registro anterior y permite actualizarlo. Advierte si el valor ingresado es menor y conserva el kilometraje propio de la orden. |
| Entrega confirmada | Se revisan placa, total, abonado y saldo antes de entregar. El servidor bloquea cambios financieros y modificaciones de documentos cerrados. |
| Correcciones posteriores | Las anotaciones conservan autor y fecha. Se muestran en el seguimiento QR y en el PDF; el formulario informa de su visibilidad para el cliente. |
| Listas de recepción y entrega | Detalle OT → Recepción y seguimiento. Combustible, accesorios, observaciones, revisión de daños y confirmación de inspección. «Pendiente» se distingue de «Sin daños». |
| Etapas independientes del cobro | El menú de etapa permite Recibido, En proceso y Listo para retirar. Entregado sigue correspondiendo al cierre de la orden. Se reflejan también en el seguimiento QR. |
| Búsqueda de órdenes | Busca por placa, número o cliente; filtra por etapa y saldo. Los grupos se construyen explícitamente, sin repetir encabezados de estados intercalados. |
| Saldo visible | El detalle presenta total, abonado y saldo, con «Cobrar saldo» precargado. |
| PDF completo | Detalle OT → PDF de la OT. Cliente, vehículo, diagnóstico, partidas, cobros, saldo, inspecciones, daños, anotaciones y QR. |
| Compartir seguimiento | Android abre la hoja del sistema; la web utiliza compartir si está disponible. Como alternativa se copia el enlace. |
| Comparar fotografías | Detalle OT → Ingreso / entrega. Desliza entre fotos y toca para ampliarlas con zoom. |
| Conexión y actualización | El menú comprueba la salud de la API; Órdenes muestra la hora de actualización de sus datos. |
| Reportes | Selector de mes, validación del rango, importes a dos decimales y barras de ingresos, gastos y saldo actual de las órdenes del mes. |
| Inventario real | Menú → Inventario. Alta y edición de repuestos, código, costos, precios, existencias, mínimo, movimientos e historial. |
| Uso de existencias en una orden | Agregar repuesto → Usar inventario. El cargo y el descuento de existencias se confirman en la misma transacción. La API rechaza salidas que dejen cantidades negativas y conserva el costo de cada uso. |
| Recordatorios | Menú → Recordatorios. Próximo servicio por fecha o kilometraje; filtros de vencidos y completados, reactivación y texto para compartir con el cliente. Inicio muestra los servicios pendientes y las existencias bajas. |
| Visor 3D giratorio | Inspección → icono 3D. Gira arrastrando, acerca con dos dedos, elige carrocería y toca una pieza para inspeccionarla. |

## Modelos de vehículo

El visor 3D usa geometría local con paneles identificados, iluminación y cámara
interactiva. Incluye sedán, SUV y pickup de referencia, y elige inicialmente la
carrocería según el tipo de vehículo registrado. No necesita descargar modelos.
Las vistas realistas del sedán de la inspección anterior siguen disponibles.
Los modelos son referencias genéricas, no reproducciones de marcas concretas.

## Inventario y recordatorios

El inventario se asigna por mecánico; el superuser puede consultar y operar
todos los registros. Para descontar existencias, la pieza debe seleccionarse
mediante «Usar inventario». Se conserva la opción de agregar repuestos manuales.
Cambiar un costo en el inventario no altera el costo histórico de piezas usadas.

Los recordatorios generan avisos dentro de la app cuando vence la fecha o se
alcanza el kilometraje objetivo registrado en el vehículo. Compartir prepara el
texto y permite elegir su envío en el teléfono. El usuario marca el servicio
como completado cuando se realiza.

## Datos existentes

El arranque incorpora `api/revup-api/db/workshop_schema.sql`. La ampliación es
aditiva e idempotente: añade columnas, tablas e índices y asigna la etapa inicial
de las órdenes heredadas a partir de su estado. No borra registros ni fotos.
Los identificadores de pago anteriores pueden permanecer vacíos; los nuevos
intentos de la app utilizan identificadores independientes.

La documentación de la auditoría original permanece como registro de los
hallazgos de partida. Las correcciones se comprueban ahora mediante regresiones
en `test/mejoras_taller_test.dart` y `api/revup-api/test/app.test.js`.

## Verificación y uso de la demo

- Flutter: 31 pruebas aprobadas.
- Backend: 22 pruebas aprobadas, incluidas concurrencia de pagos e inventario,
  permisos, archivo y restauración, documentos cerrados y recordatorios.
- Se revisaron capturas en tamaño móvil del detalle de orden y las tres
  carrocerías 3D.
- PostgreSQL 16 real: 19 pruebas HTTP aprobadas en una base aislada, incluidas
  operaciones concurrentes con varias conexiones.
- Compilación web de release completada en `build/web`.
- APK local compilada: `1.1.0-local`, código de versión 2, 82.4 MB.
- Análisis de `lib`: sin errores ni advertencias; permanecen avisos informativos
  de APIs obsoletas y estilo.
- No había un Android USB conectado; queda pendiente instalar y comprobar esta
  versión en el teléfono físico.

La APK local se genera en
`build/app/outputs/flutter-apk/app-local-release.apk`.
El entorno se inicia con `tool/local.ps1 -Action Start`; teléfono y PC deben
compartir la red usada al compilar. La comprobación de interfaz en el Android
físico requiere conectar el teléfono.

Para compilar Android después de ejecutar pruebas, utiliza el comando estándar
del lanzador (`tool/local.ps1 -Action Build`). En el SDK instalado, omitir la
regeneración con `--no-pub` puede dejar el registro del plugin `integration_test`
en una compilación de release; la compilación estándar lo regenera correctamente.
