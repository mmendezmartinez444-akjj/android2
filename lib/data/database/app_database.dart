import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Base de datos local (SQLite) de Tu Solution.
///
/// Toda la información vive en el teléfono: la app funciona sin conexión
/// y los datos se conservan aunque la aplicación se cierre.
@DriftDatabase(
  tables: [
    Tecnicos,
    Clientes,
    Equipos,
    Ordenes,
    Trabajos,
    Repuestos,
    RepuestosUsados,
    Ajustes,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// En producción abre el archivo `tu_solution.sqlite`. En las pruebas se
  /// puede pasar un ejecutor en memoria.
  AppDatabase([QueryExecutor? ejecutor])
      : super(ejecutor ?? driftDatabase(name: 'tu_solution'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _sembrarDatosIniciales();
        },
        beforeOpen: (detalles) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// El taller cuenta con tres técnicos y un pequeño almacén de repuestos.
  Future<void> _sembrarDatosIniciales() async {
    await batch((b) {
      b.insertAll(tecnicos, [
        TecnicosCompanion.insert(nombre: 'Técnico 1'),
        TecnicosCompanion.insert(nombre: 'Técnico 2'),
        TecnicosCompanion.insert(nombre: 'Técnico 3'),
      ]);
      b.insertAll(repuestos, [
        RepuestosCompanion.insert(
          nombre: 'Pantalla Samsung Galaxy A14',
          codigo: 'PAN-SAM-A14',
          precio: 4500,
          existencias: 5,
        ),
        RepuestosCompanion.insert(
          nombre: 'Pantalla iPhone 11',
          codigo: 'PAN-IPH-11',
          precio: 9800,
          existencias: 2,
        ),
        RepuestosCompanion.insert(
          nombre: 'Batería Xiaomi Redmi Note 12',
          codigo: 'BAT-XIA-N12',
          precio: 2500,
          existencias: 8,
        ),
        RepuestosCompanion.insert(
          nombre: 'Batería laptop HP 15',
          codigo: 'BAT-HP-15',
          precio: 7200,
          existencias: 3,
        ),
        RepuestosCompanion.insert(
          nombre: 'Conector de carga USB-C',
          codigo: 'CON-USBC',
          precio: 600,
          existencias: 20,
          stockMinimo: const Value(5),
        ),
        RepuestosCompanion.insert(
          nombre: 'Módulo de cámara trasera Galaxy A14',
          codigo: 'CAM-SAM-A14',
          precio: 3200,
          existencias: 1,
          stockMinimo: const Value(2),
        ),
      ]);
    });
  }
}
