# Tu Solution

Aplicación Android para gestionar las reparaciones de un taller de celulares, tablets y laptops.
Segundo Examen Parcial de Programación para Dispositivos Móviles (Ingeniería Informática, 3er año).

- **Tecnología:** Flutter para Android
- **Persistencia:** Drift sobre SQLite (funciona sin conexión y conserva los datos al cerrar la app)
- **Gestión de estado:** Riverpod
- **Arquitectura:** MVVM

## Cómo abrir y ejecutar la aplicación

Requisitos: Flutter SDK estable (3.24 o superior), Android Studio con el plugin de Flutter y un emulador o teléfono Android.

1. Clonar el repositorio y abrir la carpeta en Android Studio (**File > Open**).
2. En la terminal de Android Studio, descargar las dependencias:
   ```
   flutter pub get
   ```
3. Generar el código de Drift:
   ```
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Iniciar un emulador o conectar un teléfono y ejecutar:
   ```
   flutter run
   ```

Al abrir la app por primera vez se crean los tres técnicos del taller y un inventario inicial de repuestos. Lo primero es elegir qué técnico está usando el teléfono; a partir de ahí ya se pueden recibir equipos.

Pruebas automáticas de las reglas del taller (opcional): `flutter test`.

## Qué resuelve

| Necesidad del taller | Cómo se resuelve |
| --- | --- |
| Usarse sin internet y conservar la información | Toda la información se guarda en una base de datos SQLite local con Drift. |
| Sin autenticación ni interacción con clientes | No hay inicio de sesión. Solo se indica qué técnico tiene el teléfono, para saber quién recibe y quién toma cada orden. |
| Registrar el equipo que llega | Recepción con tipo, marca, modelo, número de serie, nombre y teléfono del dueño y falla reportada. |
| Un equipo puede volver y un dueño puede traer varios | El número de serie identifica al equipo y el teléfono al cliente; si ya existen se reutilizan y se conserva su historial. |
| Cada visita es una orden con estados | Recibida → En reparación → Lista → Entregada. Cualquier orden abierta puede quedar Cancelada, con su motivo. |
| Que dos técnicos no reparen el mismo equipo | Un técnico **toma** la orden y queda como responsable. La base de datos impide que otro la tome, y solo el responsable puede modificarla. El responsable se ve en todos los listados. |
| Anotar trabajos y repuestos | En la orden se anotan los trabajos con su costo de mano de obra y los repuestos con su cantidad. |
| Inventario que coincida con la realidad | Repuestos con nombre, código, precio y existencias. Usar un repuesto en una orden descuenta las existencias en la misma transacción; quitarlo las devuelve. |
| Enterarse a tiempo de lo que se agota | Cada repuesto tiene un mínimo. Al llegar a ese mínimo aparece como «por agotarse» en el inicio y en el inventario. |
| Costo total de la orden | Mano de obra + repuestos, calculado en la propia orden. |
| Qué órdenes están abiertas, en qué estado y quién las tiene | Listado de órdenes abiertas con estado y responsable, con búsqueda y filtros. |
| Cuánto trabajo tiene cada técnico | Pantalla de técnicos con las órdenes en reparación y listas de cada uno. |
| Historial de un equipo y de un cliente | Pantallas de historial con cada visita: falla, trabajos, piezas cambiadas, técnico y total. |
| Qué repuestos están por agotarse | Alerta en el inicio y apartado propio en el inventario. |

## Diseño de la interfaz (versión panel)

- **Navegación:** panel de inicio con módulos grandes; cada sección se abre en su propia pantalla.
- **Estilo:** Material 3 claro en tonos verde azulado, tarjetas redondeadas sin sombra y botones anchos.
- **Órdenes:** una sola lista agrupada por estado, con búsqueda y filtro «Solo las mías».
- **Detalle de la orden:** barra de avance (recibida → en reparación → lista → entregada), tarjeta del responsable y botón principal fijo abajo; los trabajos y repuestos se añaden en pantallas completas.
- **Recepción:** asistente de tres pasos (equipo, dueño, falla).
- **Inventario:** separado en «Reponer pronto» y «Con existencias», con botones − / + en cada fila.

## Arquitectura (MVVM)

```
lib/
  main.dart                 Punto de entrada (ProviderScope)
  app.dart                  MaterialApp y tema
  core/                     Formato y errores de reglas del taller
  data/
    database/               Modelo: tablas y base de datos Drift
    models/                 Modelo: enumeraciones y modelos compuestos
    repositories/           Modelo: consultas y reglas del taller (transacciones)
  viewmodels/               ViewModel: providers y notifiers de Riverpod
  views/                    Vista: pantallas y widgets
    panel_view.dart      Panel de inicio con accesos, técnico activo y alerta de stock
    ordenes_view.dart    Órdenes agrupadas por estado
    orden_view.dart      Orden con barra de avance; formularios de trabajo y repuesto
    recepcion_view.dart  Asistente de recepción en tres pasos
    inventario_view.dart Inventario y formulario de repuesto
    clientes_view.dart   Buscador de clientes y equipos
    historial_view.dart  Historial con resumen de visitas
    tecnicos_view.dart   Técnicos y reparto del trabajo
    estilo.dart          Widgets y utilidades de interfaz compartidos
test/                       Pruebas de las reglas del taller
screenshots/                Capturas de la aplicación
```

- **Modelo:** las tablas de Drift (`tables.dart`) y los repositorios. Las reglas del taller (tomar una orden, descontar existencias, cambiar de estado) viven en los repositorios y se ejecutan dentro de transacciones.
- **ViewModel:** providers de Riverpod que exponen los datos como flujos reactivos (`StreamProvider`), el filtro de órdenes (`Notifier`) y las acciones de cada pantalla. Devuelven a la vista un mensaje cuando una regla no se cumple.
- **Vista:** widgets que solo observan los ViewModels y muestran el resultado; no acceden a la base de datos.

## Decisiones tomadas donde el enunciado deja el punto abierto

- **Técnico activo:** como no hay autenticación, se elige de una lista qué técnico usa el teléfono y se recuerda entre sesiones.
- **Tomar una orden** la pasa a «En reparación» y fija al responsable. El responsable puede **liberarla** para que otro la tome.
- **Un equipo no puede tener dos órdenes abiertas** a la vez.
- **Para marcar una orden como lista** debe tener al menos un trabajo anotado. Una orden lista puede volver a reparación.
- **Cualquier técnico puede entregar** un equipo listo; solo el responsable puede cancelar una orden ya tomada.
- **Precio del repuesto:** la orden guarda el precio del momento en que se usó, así el historial no cambia si luego cambia el precio.
- **Al cancelar,** los repuestos que sigan anotados se consideran consumidos; para devolverlos al almacén se quitan antes de cancelar.
- **Un repuesto usado en alguna orden no se puede eliminar,** para no perder el historial.
- Los nombres de los tres técnicos se pueden cambiar desde la pantalla de técnicos.

## Capturas de pantalla

| Archivo | Pantalla |
| --- | --- |
| `screenshots/01_panel.png` | Panel de inicio con alerta de repuestos por agotarse |
| `screenshots/02_ordenes.png` | Órdenes abiertas agrupadas por estado, con su responsable |
| `screenshots/03_recepcion.png` | Asistente de recepción |
| `screenshots/04_orden.png` | Orden con barra de avance, trabajos, repuestos y costo total |
| `screenshots/05_inventario.png` | Inventario con repuestos por reponer |
| `screenshots/06_historial.png` | Historial de un equipo o cliente |
| `screenshots/07_tecnicos.png` | Técnicos y trabajo asignado |
