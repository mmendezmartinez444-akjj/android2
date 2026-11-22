import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/regla_negocio.dart';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/modelos.dart';
import 'providers.dart';
import 'tecnicos_viewmodel.dart';

/// Resultado de registrar una recepción: el id de la orden creada o el
/// mensaje de error.
class ResultadoRecepcion {
  const ResultadoRecepcion.ok(int this.ordenId) : error = null;
  const ResultadoRecepcion.fallo(String this.error) : ordenId = null;

  final int? ordenId;
  final String? error;
}

final recepcionViewModelProvider = Provider<RecepcionViewModel>(
  (ref) => RecepcionViewModel(ref),
);

class RecepcionViewModel {
  RecepcionViewModel(this._ref);

  final Ref _ref;

  /// Reconoce un equipo que ya estuvo en el taller.
  Future<EquipoConCliente?> buscarEquipo(String numeroSerie) =>
      _ref.read(clientesRepositoryProvider).buscarEquipoPorSerie(numeroSerie);

  /// Reconoce a un cliente que ya estuvo en el taller.
  Future<Cliente?> buscarCliente(String telefono) =>
      _ref.read(clientesRepositoryProvider).buscarClientePorTelefono(telefono);

  Future<ResultadoRecepcion> registrar({
    required TipoEquipo tipo,
    required String marca,
    required String modelo,
    required String numeroSerie,
    required String nombreCliente,
    required String telefono,
    required String falla,
  }) async {
    try {
      final ordenId =
          await _ref.read(ordenesRepositoryProvider).registrarRecepcion(
                tecnicoId: tecnicoActivoObligatorio(_ref),
                tipo: tipo,
                marca: marca,
                modelo: modelo,
                numeroSerie: numeroSerie,
                nombreCliente: nombreCliente,
                telefono: telefono,
                falla: falla,
              );
      return ResultadoRecepcion.ok(ordenId);
    } on ReglaNegocio catch (e) {
      return ResultadoRecepcion.fallo(e.mensaje);
    } catch (e) {
      return ResultadoRecepcion.fallo('Ocurrió un error inesperado: $e');
    }
  }
}
