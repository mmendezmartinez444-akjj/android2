import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../core/regla_negocio.dart';
import '../data/models/modelos.dart';
import '../data/repositories/ordenes_repository.dart';
import 'providers.dart';
import 'tecnicos_viewmodel.dart';

/// Detalle en vivo de una orden (trabajos, repuestos y costos).
final ordenDetalleProvider =
    StreamProvider.autoDispose.family<OrdenDetalle?, int>(
  (ref, ordenId) => ref.watch(ordenesRepositoryProvider).watchDetalle(ordenId),
);

/// Qué puede hacer el técnico activo con la orden.
final permisosOrdenProvider =
    Provider.autoDispose.family<PermisosOrden, int>((ref, ordenId) {
  final detalle = ref.watch(ordenDetalleProvider(ordenId)).valueOrNull;
  if (detalle == null) return const PermisosOrden();
  return PermisosOrden.calcular(detalle, ref.watch(tecnicoActivoProvider));
});

final ordenDetalleViewModelProvider =
    Provider.family<OrdenDetalleViewModel, int>(
  (ref, ordenId) => OrdenDetalleViewModel(ref, ordenId),
);

/// Acciones del técnico sobre una orden. Cada método devuelve `null` si la
/// acción se completó o el mensaje que debe mostrarse si no fue posible.
class OrdenDetalleViewModel {
  OrdenDetalleViewModel(this._ref, this.ordenId);

  final Ref _ref;
  final int ordenId;

  OrdenesRepository get _repo => _ref.read(ordenesRepositoryProvider);

  int get _tecnico => tecnicoActivoObligatorio(_ref);

  Future<String?> tomar() =>
      ejecutarAccion(() => _repo.tomarOrden(ordenId, _tecnico));

  Future<String?> liberar() =>
      ejecutarAccion(() => _repo.liberarOrden(ordenId, _tecnico));

  Future<String?> marcarLista() =>
      ejecutarAccion(() => _repo.marcarLista(ordenId, _tecnico));

  Future<String?> reabrir() =>
      ejecutarAccion(() => _repo.reabrirOrden(ordenId, _tecnico));

  Future<String?> entregar() => ejecutarAccion(() {
        tecnicoActivoObligatorio(_ref); // exige un técnico identificado
        return _repo.entregarOrden(ordenId);
      });

  Future<String?> cancelar(String motivo) =>
      ejecutarAccion(() => _repo.cancelarOrden(ordenId, _tecnico, motivo));

  Future<String?> agregarTrabajo(String descripcion, String costo) =>
      ejecutarAccion(() {
        final valor = leerDecimal(costo);
        if (valor == null) {
          throw const ReglaNegocio('Escribe un costo de mano de obra válido.');
        }
        return _repo.agregarTrabajo(
          ordenId: ordenId,
          tecnicoId: _tecnico,
          descripcion: descripcion,
          costo: valor,
        );
      });

  Future<String?> eliminarTrabajo(int trabajoId) =>
      ejecutarAccion(() => _repo.eliminarTrabajo(trabajoId, _tecnico));

  Future<String?> usarRepuesto(int repuestoId, int cantidad) => ejecutarAccion(
        () => _repo.usarRepuesto(
          ordenId: ordenId,
          tecnicoId: _tecnico,
          repuestoId: repuestoId,
          cantidad: cantidad,
        ),
      );

  Future<String?> quitarRepuesto(int usoId) =>
      ejecutarAccion(() => _repo.quitarRepuesto(usoId, _tecnico));
}
