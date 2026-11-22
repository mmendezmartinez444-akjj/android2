import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/regla_negocio.dart';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/modelos.dart';
import 'ordenes_viewmodel.dart';
import 'providers.dart';

final tecnicosProvider = StreamProvider<List<Tecnico>>(
  (ref) => ref.watch(tecnicosRepositoryProvider).watchTecnicos(),
);

final tecnicoActivoIdProvider = StreamProvider<int?>(
  (ref) => ref.watch(tecnicosRepositoryProvider).watchTecnicoActivoId(),
);

/// Técnico que está usando el teléfono en este momento (o nulo si todavía
/// no se ha elegido ninguno).
final tecnicoActivoProvider = Provider<Tecnico?>((ref) {
  final id = ref.watch(tecnicoActivoIdProvider).valueOrNull;
  final tecnicos = ref.watch(tecnicosProvider).valueOrNull ?? const [];
  for (final tecnico in tecnicos) {
    if (tecnico.id == id) return tecnico;
  }
  return null;
});

/// Cuánto trabajo tiene asignado cada técnico.
final cargaTrabajoProvider = Provider<AsyncValue<List<CargaTecnico>>>((ref) {
  final tecnicos = ref.watch(tecnicosProvider);
  final ordenes = ref.watch(ordenesProvider);
  return tecnicos.whenData((lista) {
    final todas = ordenes.valueOrNull ?? const <OrdenResumen>[];
    int contar(Tecnico t, EstadoOrden estado) => todas
        .where((o) => o.orden.tecnicoId == t.id && o.orden.estado == estado)
        .length;
    return [
      for (final tecnico in lista)
        CargaTecnico(
          tecnico: tecnico,
          enReparacion: contar(tecnico, EstadoOrden.enReparacion),
          listas: contar(tecnico, EstadoOrden.lista),
          cerradas: contar(tecnico, EstadoOrden.entregada),
        ),
    ];
  });
});

/// Órdenes abiertas a cargo de un técnico.
final ordenesDeTecnicoProvider =
    Provider.family<List<OrdenResumen>, int>((ref, tecnicoId) {
  final todas = ref.watch(ordenesProvider).valueOrNull ?? const [];
  return todas
      .where((o) => o.orden.tecnicoId == tecnicoId && o.orden.estado.abierta)
      .toList();
});

final tecnicosViewModelProvider = Provider<TecnicosViewModel>(
  (ref) => TecnicosViewModel(ref),
);

class TecnicosViewModel {
  TecnicosViewModel(this._ref);

  final Ref _ref;

  Future<String?> seleccionarActivo(int tecnicoId) => ejecutarAccion(
        () => _ref
            .read(tecnicosRepositoryProvider)
            .seleccionarTecnicoActivo(tecnicoId),
      );

  Future<String?> renombrar(int tecnicoId, String nombre) => ejecutarAccion(
        () =>
            _ref.read(tecnicosRepositoryProvider).renombrar(tecnicoId, nombre),
      );
}

/// Id del técnico activo o error controlado si aún no se ha elegido.
int tecnicoActivoObligatorio(Ref ref) {
  final activo = ref.read(tecnicoActivoProvider);
  if (activo == null) {
    throw const ReglaNegocio(
      'Selecciona primero qué técnico está usando la app.',
    );
  }
  return activo.id;
}
