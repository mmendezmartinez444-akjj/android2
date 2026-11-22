import 'package:drift/drift.dart';

import '../../core/regla_negocio.dart';
import '../database/app_database.dart';

/// Técnicos del taller y técnico que está usando el teléfono.
class TecnicosRepository {
  TecnicosRepository(this._db);

  final AppDatabase _db;

  static const _claveActivo = 'tecnico_activo';

  Stream<List<Tecnico>> watchTecnicos() =>
      (_db.select(_db.tecnicos)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  Future<void> renombrar(int tecnicoId, String nombre) async {
    if (nombre.trim().isEmpty) {
      throw const ReglaNegocio('El nombre no puede quedar vacío.');
    }
    await (_db.update(_db.tecnicos)..where((t) => t.id.equals(tecnicoId)))
        .write(TecnicosCompanion(nombre: Value(nombre.trim())));
  }

  /// La app no lleva autenticación: solo se recuerda qué técnico tiene el
  /// teléfono en la mano para saber quién recibe y quién toma las órdenes.
  Stream<int?> watchTecnicoActivoId() =>
      (_db.select(_db.ajustes)..where((a) => a.clave.equals(_claveActivo)))
          .watchSingleOrNull()
          .map((ajuste) => ajuste == null ? null : int.tryParse(ajuste.valor));

  Future<void> seleccionarTecnicoActivo(int tecnicoId) {
    return _db.into(_db.ajustes).insertOnConflictUpdate(
          AjustesCompanion.insert(
            clave: _claveActivo,
            valor: tecnicoId.toString(),
          ),
        );
  }
}
