import 'package:drift/drift.dart';

import '../../core/regla_negocio.dart';
import '../database/app_database.dart';

/// Inventario de repuestos del almacén.
class InventarioRepository {
  InventarioRepository(this._db);

  final AppDatabase _db;

  Stream<List<Repuesto>> watchRepuestos() =>
      (_db.select(_db.repuestos)..orderBy([(r) => OrderingTerm.asc(r.nombre)]))
          .watch();

  /// Crea un repuesto ([id] nulo) o actualiza su ficha. Las existencias de
  /// un repuesto existente solo cambian con [ajustarExistencias] o al
  /// usarlo en una orden.
  Future<void> guardarRepuesto({
    int? id,
    required String nombre,
    required String codigo,
    required double precio,
    required int existencias,
    required int stockMinimo,
  }) {
    final nombreLimpio = nombre.trim();
    final codigoLimpio = codigo.trim().toUpperCase();
    if (nombreLimpio.isEmpty || codigoLimpio.isEmpty) {
      throw const ReglaNegocio('El nombre y el código son obligatorios.');
    }
    if (precio < 0 || existencias < 0 || stockMinimo < 0) {
      throw const ReglaNegocio('Los valores no pueden ser negativos.');
    }
    return _db.transaction(() async {
      final repetido = await (_db.select(_db.repuestos)
            ..where((r) => r.codigo.equals(codigoLimpio)))
          .getSingleOrNull();
      if (repetido != null && repetido.id != id) {
        throw ReglaNegocio(
          'Ya existe un repuesto con el código $codigoLimpio.',
        );
      }
      if (id == null) {
        await _db.into(_db.repuestos).insert(
              RepuestosCompanion.insert(
                nombre: nombreLimpio,
                codigo: codigoLimpio,
                precio: precio,
                existencias: existencias,
                stockMinimo: Value(stockMinimo),
              ),
            );
      } else {
        await (_db.update(_db.repuestos)..where((r) => r.id.equals(id))).write(
          RepuestosCompanion(
            nombre: Value(nombreLimpio),
            codigo: Value(codigoLimpio),
            precio: Value(precio),
            stockMinimo: Value(stockMinimo),
          ),
        );
      }
    });
  }

  /// Entrada (+) o corrección (−) de existencias en el almacén.
  Future<void> ajustarExistencias(int repuestoId, int diferencia) {
    return _db.transaction(() async {
      final repuesto = await (_db.select(_db.repuestos)
            ..where((r) => r.id.equals(repuestoId)))
          .getSingleOrNull();
      if (repuesto == null) {
        throw const ReglaNegocio('El repuesto no existe.');
      }
      final nuevas = repuesto.existencias + diferencia;
      if (nuevas < 0) {
        throw const ReglaNegocio('Las existencias no pueden quedar negativas.');
      }
      await (_db.update(_db.repuestos)..where((r) => r.id.equals(repuestoId)))
          .write(RepuestosCompanion(existencias: Value(nuevas)));
    });
  }

  /// Solo se puede eliminar un repuesto que nunca se haya usado, para no
  /// perder el historial de las órdenes.
  Future<void> eliminarRepuesto(int repuestoId) {
    return _db.transaction(() async {
      final usos = await (_db.select(_db.repuestosUsados)
            ..where((u) => u.repuestoId.equals(repuestoId))
            ..limit(1))
          .get();
      if (usos.isNotEmpty) {
        throw const ReglaNegocio(
          'No se puede eliminar: el repuesto aparece en órdenes de '
          'reparación.',
        );
      }
      await (_db.delete(_db.repuestos)..where((r) => r.id.equals(repuestoId)))
          .go();
    });
  }
}
