import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/modelos.dart';

/// Clientes (dueños) y equipos registrados en el taller.
class ClientesRepository {
  ClientesRepository(this._db);

  final AppDatabase _db;

  Stream<void> _cambios() => _db.customSelect(
        'SELECT 1',
        readsFrom: {_db.clientes, _db.equipos},
      ).watch();

  /// Clientes con los equipos que han traído.
  Stream<List<ClienteConEquipos>> watchClientes() =>
      _cambios().asyncMap((_) async {
        final clientes = await (_db.select(_db.clientes)
              ..orderBy([(c) => OrderingTerm.asc(c.nombre)]))
            .get();
        final equipos = await _db.select(_db.equipos).get();
        return [
          for (final cliente in clientes)
            ClienteConEquipos(
              cliente: cliente,
              equipos: equipos.where((e) => e.clienteId == cliente.id).toList(),
            ),
        ];
      });

  /// Todos los equipos con su dueño actual.
  Stream<List<EquipoConCliente>> watchEquipos() =>
      _cambios().asyncMap((_) => _equipos());

  Future<Cliente?> obtenerCliente(int clienteId) =>
      (_db.select(_db.clientes)..where((c) => c.id.equals(clienteId)))
          .getSingleOrNull();

  Future<EquipoConCliente?> obtenerEquipo(int equipoId) async {
    final lista = await _equipos(equipoId: equipoId);
    return lista.isEmpty ? null : lista.first;
  }

  /// Busca un equipo ya registrado por su número de serie. Se usa en la
  /// recepción para reconocer un equipo que vuelve al taller.
  Future<EquipoConCliente?> buscarEquipoPorSerie(String numeroSerie) async {
    final serie = numeroSerie.trim().toUpperCase();
    if (serie.isEmpty) return null;
    final lista = await _equipos(numeroSerie: serie);
    return lista.isEmpty ? null : lista.first;
  }

  /// Busca un cliente ya registrado por su teléfono.
  Future<Cliente?> buscarClientePorTelefono(String telefono) {
    return (_db.select(_db.clientes)
          ..where((c) => c.telefono.equals(telefono.trim())))
        .getSingleOrNull();
  }

  Future<List<EquipoConCliente>> _equipos({
    int? equipoId,
    String? numeroSerie,
  }) async {
    final consulta = _db.select(_db.equipos).join([
      innerJoin(
        _db.clientes,
        _db.clientes.id.equalsExp(_db.equipos.clienteId),
      ),
    ]);
    if (equipoId != null) consulta.where(_db.equipos.id.equals(equipoId));
    if (numeroSerie != null) {
      consulta.where(_db.equipos.numeroSerie.equals(numeroSerie));
    }
    consulta.orderBy([
      OrderingTerm.asc(_db.equipos.marca),
      OrderingTerm.asc(_db.equipos.modelo),
    ]);
    final filas = await consulta.get();
    return [
      for (final fila in filas)
        EquipoConCliente(
          equipo: fila.readTable(_db.equipos),
          cliente: fila.readTable(_db.clientes),
        ),
    ];
  }
}
