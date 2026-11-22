import 'package:drift/drift.dart';

import '../models/enums.dart';

/// Técnicos del taller.
@DataClassName('Tecnico')
class Tecnicos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 60)();
}

/// Dueños de los equipos. El teléfono identifica al cliente.
@DataClassName('Cliente')
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 80)();
  TextColumn get telefono => text().unique()();
}

/// Equipos que han pasado por el taller. El número de serie es único,
/// por eso un mismo equipo puede volver muchas veces.
@DataClassName('Equipo')
class Equipos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  TextColumn get tipo => textEnum<TipoEquipo>()();
  TextColumn get marca => text().withLength(min: 1, max: 40)();
  TextColumn get modelo => text().withLength(min: 1, max: 60)();
  TextColumn get numeroSerie => text().unique()();
}

/// Cada visita de un equipo al taller es una orden de reparación.
@DataClassName('Orden')
class Ordenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get equipoId => integer().references(Equipos, #id)();

  /// Dueño del equipo en el momento de la visita.
  IntColumn get clienteId => integer().references(Clientes, #id)();
  TextColumn get fallaReportada => text()();
  TextColumn get estado => textEnum<EstadoOrden>()();

  /// Técnico que recibió el equipo.
  IntColumn get recibidoPorId => integer().references(Tecnicos, #id)();

  /// Técnico responsable (quien tomó la orden). Nulo = nadie la ha tomado.
  IntColumn get tecnicoId => integer().nullable().references(Tecnicos, #id)();
  DateTimeColumn get fechaRecepcion => dateTime()();
  DateTimeColumn get fechaToma => dateTime().nullable()();
  DateTimeColumn get fechaLista => dateTime().nullable()();

  /// Fecha de entrega o de cancelación.
  DateTimeColumn get fechaCierre => dateTime().nullable()();
  TextColumn get notaCierre => text().nullable()();
}

/// Trabajos realizados en una orden, con su costo de mano de obra.
@DataClassName('Trabajo')
class Trabajos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId => integer().references(Ordenes, #id)();
  IntColumn get tecnicoId => integer().references(Tecnicos, #id)();
  TextColumn get descripcion => text()();
  RealColumn get costo => real()();
  DateTimeColumn get fecha => dateTime()();
}

/// Inventario de repuestos del almacén.
@DataClassName('Repuesto')
class Repuestos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 80)();
  TextColumn get codigo => text().unique()();
  RealColumn get precio => real()();
  IntColumn get existencias => integer()();

  /// Cuando las existencias llegan a este valor el repuesto se marca
  /// como "por agotarse".
  IntColumn get stockMinimo => integer().withDefault(const Constant(3))();
}

/// Repuestos utilizados en una orden. Guarda el precio del momento.
@DataClassName('RepuestoUsado')
class RepuestosUsados extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId => integer().references(Ordenes, #id)();
  IntColumn get repuestoId => integer().references(Repuestos, #id)();
  IntColumn get cantidad => integer()();
  RealColumn get precioUnitario => real()();
  DateTimeColumn get fecha => dateTime()();
}

/// Ajustes simples clave/valor (por ejemplo, el técnico activo).
@DataClassName('Ajuste')
class Ajustes extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {clave};
}
