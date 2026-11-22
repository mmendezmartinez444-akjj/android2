import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../data/models/modelos.dart';
import 'inventario_viewmodel.dart';
import 'providers.dart';
import 'tecnicos_viewmodel.dart';

/// Todas las órdenes del taller, de la más reciente a la más antigua.
final ordenesProvider = StreamProvider<List<OrdenResumen>>(
  (ref) => ref.watch(ordenesRepositoryProvider).watchResumenes(),
);

/// Filtro del listado de órdenes.
class FiltroOrdenes {
  const FiltroOrdenes({
    this.estado,
    this.texto = '',
    this.soloMias = false,
  });

  /// Nulo = todas las órdenes abiertas.
  final EstadoOrden? estado;
  final String texto;

  /// Solo las órdenes a cargo del técnico activo.
  final bool soloMias;
}

final ordenesViewModelProvider =
    NotifierProvider<OrdenesViewModel, FiltroOrdenes>(OrdenesViewModel.new);

class OrdenesViewModel extends Notifier<FiltroOrdenes> {
  @override
  FiltroOrdenes build() => const FiltroOrdenes();

  void filtrarPorEstado(EstadoOrden? estado) {
    state = FiltroOrdenes(
      estado: estado,
      texto: state.texto,
      soloMias: state.soloMias,
    );
  }

  void buscar(String texto) {
    state = FiltroOrdenes(
      estado: state.estado,
      texto: texto,
      soloMias: state.soloMias,
    );
  }

  void mostrarSoloMias(bool valor) {
    state = FiltroOrdenes(
      estado: state.estado,
      texto: state.texto,
      soloMias: valor,
    );
  }
}

bool _coincide(OrdenResumen o, String texto) {
  final t = texto.trim().toLowerCase();
  if (t.isEmpty) return true;
  return '#${o.orden.id}'.contains(t) ||
      o.nombreEquipo.toLowerCase().contains(t) ||
      o.equipo.numeroSerie.toLowerCase().contains(t) ||
      o.cliente.nombre.toLowerCase().contains(t) ||
      o.cliente.telefono.contains(t) ||
      o.responsable.toLowerCase().contains(t);
}

/// Órdenes que cumplen el filtro actual.
final ordenesFiltradasProvider =
    Provider<AsyncValue<List<OrdenResumen>>>((ref) {
  final filtro = ref.watch(ordenesViewModelProvider);
  final activo = ref.watch(tecnicoActivoProvider);
  return ref.watch(ordenesProvider).whenData((todas) {
    return todas.where((o) {
      final estado = o.orden.estado;
      final pasaEstado =
          filtro.estado == null ? estado.abierta : estado == filtro.estado;
      final pasaMias = !filtro.soloMias ||
          (activo != null && o.orden.tecnicoId == activo.id);
      return pasaEstado && pasaMias && _coincide(o, filtro.texto);
    }).toList();
  });
});

/// Órdenes de un estado concreto (respeta la búsqueda y "solo mías").
final ordenesPorEstadoProvider =
    Provider.family<List<OrdenResumen>, EstadoOrden>((ref, estado) {
  final filtro = ref.watch(ordenesViewModelProvider);
  final activo = ref.watch(tecnicoActivoProvider);
  final todas = ref.watch(ordenesProvider).valueOrNull ?? const [];
  return todas.where((o) {
    final pasaMias =
        !filtro.soloMias || (activo != null && o.orden.tecnicoId == activo.id);
    return o.orden.estado == estado && pasaMias && _coincide(o, filtro.texto);
  }).toList();
});

/// Números generales del taller.
final resumenTallerProvider = Provider<AsyncValue<ResumenTaller>>((ref) {
  final porAgotarse = ref.watch(repuestosPorAgotarseProvider).length;
  return ref.watch(ordenesProvider).whenData((todas) {
    int contar(EstadoOrden estado) =>
        todas.where((o) => o.orden.estado == estado).length;
    return ResumenTaller(
      recibidas: contar(EstadoOrden.recibida),
      enReparacion: contar(EstadoOrden.enReparacion),
      listas: contar(EstadoOrden.lista),
      repuestosPorAgotarse: porAgotarse,
    );
  });
});
