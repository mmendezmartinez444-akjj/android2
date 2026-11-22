import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../core/regla_negocio.dart';
import '../data/database/app_database.dart';
import '../data/models/modelos.dart';
import 'providers.dart';

/// Inventario completo, ordenado por nombre.
final repuestosProvider = StreamProvider<List<Repuesto>>(
  (ref) => ref.watch(inventarioRepositoryProvider).watchRepuestos(),
);

/// Repuestos cuyas existencias llegaron a su mínimo (o se agotaron).
final repuestosPorAgotarseProvider = Provider<List<Repuesto>>((ref) {
  final todos = ref.watch(repuestosProvider).valueOrNull ?? const [];
  return todos.where((r) => r.porAgotarse).toList()
    ..sort((a, b) => a.existencias.compareTo(b.existencias));
});

final inventarioViewModelProvider = Provider<InventarioViewModel>(
  (ref) => InventarioViewModel(ref),
);

class InventarioViewModel {
  InventarioViewModel(this._ref);

  final Ref _ref;

  /// Crea ([id] nulo) o edita un repuesto a partir del texto del formulario.
  Future<String?> guardar({
    int? id,
    required String nombre,
    required String codigo,
    required String precio,
    required String existencias,
    required String stockMinimo,
  }) =>
      ejecutarAccion(() {
        final precioValor = leerDecimal(precio);
        final existenciasValor = int.tryParse(existencias.trim());
        final minimoValor = int.tryParse(stockMinimo.trim());
        if (precioValor == null ||
            existenciasValor == null ||
            minimoValor == null) {
          throw const ReglaNegocio(
            'Revisa el precio, las existencias y el mínimo: deben ser '
            'números.',
          );
        }
        return _ref.read(inventarioRepositoryProvider).guardarRepuesto(
              id: id,
              nombre: nombre,
              codigo: codigo,
              precio: precioValor,
              existencias: existenciasValor,
              stockMinimo: minimoValor,
            );
      });

  /// Entrada (+) o corrección (−) de existencias.
  Future<String?> ajustarExistencias(int repuestoId, int diferencia) =>
      ejecutarAccion(
        () => _ref
            .read(inventarioRepositoryProvider)
            .ajustarExistencias(repuestoId, diferencia),
      );

  Future<String?> eliminar(int repuestoId) => ejecutarAccion(
        () => _ref
            .read(inventarioRepositoryProvider)
            .eliminarRepuesto(repuestoId),
      );
}
