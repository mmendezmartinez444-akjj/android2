import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/models/modelos.dart';
import 'providers.dart';

/// Clientes con sus equipos.
final clientesProvider = StreamProvider<List<ClienteConEquipos>>(
  (ref) => ref.watch(clientesRepositoryProvider).watchClientes(),
);

/// Equipos registrados con su dueño actual.
final equiposProvider = StreamProvider<List<EquipoConCliente>>(
  (ref) => ref.watch(clientesRepositoryProvider).watchEquipos(),
);

final equipoProvider =
    FutureProvider.autoDispose.family<EquipoConCliente?, int>(
  (ref, equipoId) =>
      ref.watch(clientesRepositoryProvider).obtenerEquipo(equipoId),
);

final clienteProvider = FutureProvider.autoDispose.family<Cliente?, int>(
  (ref, clienteId) =>
      ref.watch(clientesRepositoryProvider).obtenerCliente(clienteId),
);

/// Historial de reparaciones de un equipo.
final historialEquipoProvider =
    StreamProvider.autoDispose.family<List<OrdenDetalle>, int>(
  (ref, equipoId) =>
      ref.watch(ordenesRepositoryProvider).watchHistorialEquipo(equipoId),
);

/// Historial de reparaciones de un cliente.
final historialClienteProvider =
    StreamProvider.autoDispose.family<List<OrdenDetalle>, int>(
  (ref, clienteId) =>
      ref.watch(ordenesRepositoryProvider).watchHistorialCliente(clienteId),
);
