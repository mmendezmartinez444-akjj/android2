import 'package:drift/drift.dart';

import '../../core/regla_negocio.dart';
import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/modelos.dart';

/// Acceso a datos y reglas del taller sobre las órdenes de reparación.
class OrdenesRepository {
  OrdenesRepository(this._db);

  final AppDatabase _db;

  /// Emite cada vez que cambia cualquier tabla relacionada con las órdenes.
  Stream<void> _cambios() => _db.customSelect(
        'SELECT 1',
        readsFrom: {
          _db.ordenes,
          _db.equipos,
          _db.clientes,
          _db.tecnicos,
          _db.trabajos,
          _db.repuestosUsados,
          _db.repuestos,
        },
      ).watch();

  // ---------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------

  Stream<List<OrdenResumen>> watchResumenes() =>
      _cambios().asyncMap((_) => obtenerResumenes());

  Stream<OrdenDetalle?> watchDetalle(int ordenId) =>
      _cambios().asyncMap((_) => obtenerDetalle(ordenId));

  /// Historial de reparaciones de un equipo (más reciente primero).
  Stream<List<OrdenDetalle>> watchHistorialEquipo(int equipoId) =>
      _cambios().asyncMap((_) => _obtenerDetalles(equipoId: equipoId));

  /// Historial de reparaciones de un cliente (más reciente primero).
  Stream<List<OrdenDetalle>> watchHistorialCliente(int clienteId) =>
      _cambios().asyncMap((_) => _obtenerDetalles(clienteId: clienteId));

  Future<List<OrdenResumen>> obtenerResumenes({
    int? ordenId,
    int? equipoId,
    int? clienteId,
  }) async {
    final consulta = _db.select(_db.ordenes).join([
      innerJoin(_db.equipos, _db.equipos.id.equalsExp(_db.ordenes.equipoId)),
      innerJoin(
        _db.clientes,
        _db.clientes.id.equalsExp(_db.ordenes.clienteId),
      ),
      leftOuterJoin(
        _db.tecnicos,
        _db.tecnicos.id.equalsExp(_db.ordenes.tecnicoId),
      ),
    ]);
    if (ordenId != null) consulta.where(_db.ordenes.id.equals(ordenId));
    if (equipoId != null) {
      consulta.where(_db.ordenes.equipoId.equals(equipoId));
    }
    if (clienteId != null) {
      consulta.where(_db.ordenes.clienteId.equals(clienteId));
    }
    consulta.orderBy([
      OrderingTerm.desc(_db.ordenes.fechaRecepcion),
      OrderingTerm.desc(_db.ordenes.id),
    ]);
    final filas = await consulta.get();
    return [
      for (final fila in filas)
        OrdenResumen(
          orden: fila.readTable(_db.ordenes),
          equipo: fila.readTable(_db.equipos),
          cliente: fila.readTable(_db.clientes),
          tecnico: fila.readTableOrNull(_db.tecnicos),
        ),
    ];
  }

  Future<OrdenDetalle?> obtenerDetalle(int ordenId) async {
    final resumenes = await obtenerResumenes(ordenId: ordenId);
    if (resumenes.isEmpty) return null;
    return _completar(resumenes.first);
  }

  Future<List<OrdenDetalle>> _obtenerDetalles({
    int? equipoId,
    int? clienteId,
  }) async {
    final resumenes = await obtenerResumenes(
      equipoId: equipoId,
      clienteId: clienteId,
    );
    return [for (final r in resumenes) await _completar(r)];
  }

  Future<OrdenDetalle> _completar(OrdenResumen resumen) async {
    final ordenId = resumen.orden.id;
    final recibidoPor = await (_db.select(_db.tecnicos)
          ..where((t) => t.id.equals(resumen.orden.recibidoPorId)))
        .getSingle();
    final trabajos = await (_db.select(_db.trabajos)
          ..where((t) => t.ordenId.equals(ordenId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final filasUsos = await (_db.select(_db.repuestosUsados).join([
      innerJoin(
        _db.repuestos,
        _db.repuestos.id.equalsExp(_db.repuestosUsados.repuestoId),
      ),
    ])
          ..where(_db.repuestosUsados.ordenId.equals(ordenId))
          ..orderBy([OrderingTerm.asc(_db.repuestosUsados.id)]))
        .get();
    return OrdenDetalle(
      resumen: resumen,
      recibidoPor: recibidoPor,
      trabajos: trabajos,
      repuestos: [
        for (final fila in filasUsos)
          RepuestoUsadoDetalle(
            uso: fila.readTable(_db.repuestosUsados),
            repuesto: fila.readTable(_db.repuestos),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Recepción
  // ---------------------------------------------------------------------

  /// Registra la llegada de un equipo y crea su orden en estado "recibida".
  ///
  /// Si el número de serie ya existe se reutiliza el equipo (así se conserva
  /// su historial) y si el teléfono ya existe se reutiliza el cliente.
  /// Devuelve el id de la nueva orden.
  Future<int> registrarRecepcion({
    required int tecnicoId,
    required TipoEquipo tipo,
    required String marca,
    required String modelo,
    required String numeroSerie,
    required String nombreCliente,
    required String telefono,
    required String falla,
  }) {
    final serie = numeroSerie.trim().toUpperCase();
    final tel = telefono.trim();
    final nombre = nombreCliente.trim();
    if (marca.trim().isEmpty ||
        modelo.trim().isEmpty ||
        serie.isEmpty ||
        nombre.isEmpty ||
        tel.isEmpty ||
        falla.trim().isEmpty) {
      throw const ReglaNegocio('Completa todos los datos de la recepción.');
    }

    return _db.transaction(() async {
      // Cliente: el teléfono lo identifica.
      final cliente = await (_db.select(_db.clientes)
            ..where((c) => c.telefono.equals(tel)))
          .getSingleOrNull();
      final clienteId = cliente?.id ??
          await _db.into(_db.clientes).insert(
                ClientesCompanion.insert(nombre: nombre, telefono: tel),
              );

      // Equipo: el número de serie lo identifica.
      final equipo = await (_db.select(_db.equipos)
            ..where((e) => e.numeroSerie.equals(serie)))
          .getSingleOrNull();
      final int equipoId;
      if (equipo == null) {
        equipoId = await _db.into(_db.equipos).insert(
              EquiposCompanion.insert(
                clienteId: clienteId,
                tipo: tipo,
                marca: marca.trim(),
                modelo: modelo.trim(),
                numeroSerie: serie,
              ),
            );
      } else {
        final abiertas = await (_db.select(_db.ordenes)
              ..where(
                (o) =>
                    o.equipoId.equals(equipo.id) &
                    o.estado.isIn(EstadoOrden.abiertas.map((e) => e.name)),
              ))
            .get();
        if (abiertas.isNotEmpty) {
          throw ReglaNegocio(
            'Este equipo ya está en el taller con la orden '
            '#${abiertas.first.id} abierta.',
          );
        }
        equipoId = equipo.id;
        if (equipo.clienteId != clienteId) {
          // El equipo cambió de dueño: se actualiza el dueño actual.
          await (_db.update(_db.equipos)..where((e) => e.id.equals(equipo.id)))
              .write(EquiposCompanion(clienteId: Value(clienteId)));
        }
      }

      return _db.into(_db.ordenes).insert(
            OrdenesCompanion.insert(
              equipoId: equipoId,
              clienteId: clienteId,
              fallaReportada: falla.trim(),
              estado: EstadoOrden.recibida,
              recibidoPorId: tecnicoId,
              fechaRecepcion: DateTime.now(),
            ),
          );
    });
  }

  // ---------------------------------------------------------------------
  // Flujo de estados
  // ---------------------------------------------------------------------

  /// El técnico toma la orden: queda como responsable y pasa a
  /// "en reparación". La actualización es condicional para que dos
  /// técnicos nunca puedan tomar la misma orden.
  Future<void> tomarOrden(int ordenId, int tecnicoId) {
    return _db.transaction(() async {
      final filas = await (_db.update(_db.ordenes)
            ..where(
              (o) =>
                  o.id.equals(ordenId) &
                  o.tecnicoId.isNull() &
                  o.estado.equalsValue(EstadoOrden.recibida),
            ))
          .write(
        OrdenesCompanion(
          tecnicoId: Value(tecnicoId),
          estado: const Value(EstadoOrden.enReparacion),
          fechaToma: Value(DateTime.now()),
        ),
      );
      if (filas == 0) {
        final detalle = await obtenerDetalle(ordenId);
        final responsable = detalle?.tecnico;
        throw ReglaNegocio(
          responsable != null
              ? 'La orden ya fue tomada por ${responsable.nombre}.'
              : 'La orden ya no está disponible para tomar.',
        );
      }
    });
  }

  /// El responsable suelta la orden: vuelve a "recibida" sin responsable
  /// para que otro técnico pueda tomarla.
  Future<void> liberarOrden(int ordenId, int tecnicoId) {
    return _db.transaction(() async {
      await _ordenDelResponsable(
        ordenId,
        tecnicoId,
        const [EstadoOrden.enReparacion],
      );
      await _actualizar(
        ordenId,
        const OrdenesCompanion(
          tecnicoId: Value(null),
          estado: Value(EstadoOrden.recibida),
          fechaToma: Value(null),
        ),
      );
    });
  }

  /// La reparación terminó: el equipo queda listo para entregar.
  Future<void> marcarLista(int ordenId, int tecnicoId) {
    return _db.transaction(() async {
      await _ordenDelResponsable(
        ordenId,
        tecnicoId,
        const [EstadoOrden.enReparacion],
      );
      final trabajos = await (_db.select(_db.trabajos)
            ..where((t) => t.ordenId.equals(ordenId)))
          .get();
      if (trabajos.isEmpty) {
        throw const ReglaNegocio(
          'Anota al menos un trabajo realizado antes de marcar la orden '
          'como lista.',
        );
      }
      await _actualizar(
        ordenId,
        OrdenesCompanion(
          estado: const Value(EstadoOrden.lista),
          fechaLista: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Vuelve una orden lista a "en reparación" (quedó algo pendiente).
  Future<void> reabrirOrden(int ordenId, int tecnicoId) {
    return _db.transaction(() async {
      await _ordenDelResponsable(ordenId, tecnicoId, const [EstadoOrden.lista]);
      await _actualizar(
        ordenId,
        const OrdenesCompanion(
          estado: Value(EstadoOrden.enReparacion),
          fechaLista: Value(null),
        ),
      );
    });
  }

  /// El cliente recogió su equipo.
  Future<void> entregarOrden(int ordenId) {
    return _db.transaction(() async {
      final orden = await _orden(ordenId);
      if (orden.estado != EstadoOrden.lista) {
        throw const ReglaNegocio(
          'Solo se puede entregar una orden que esté lista.',
        );
      }
      await _actualizar(
        ordenId,
        OrdenesCompanion(
          estado: const Value(EstadoOrden.entregada),
          fechaCierre: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Cancela una orden abierta. Si ya fue tomada, solo su responsable
  /// puede cancelarla. Los repuestos que sigan anotados se consideran
  /// consumidos; para devolverlos al almacén hay que quitarlos antes.
  Future<void> cancelarOrden(int ordenId, int tecnicoId, String motivo) {
    return _db.transaction(() async {
      final orden = await _orden(ordenId);
      if (!orden.estado.abierta) {
        throw const ReglaNegocio('La orden ya está cerrada.');
      }
      if (orden.tecnicoId != null && orden.tecnicoId != tecnicoId) {
        throw const ReglaNegocio(
          'Solo el técnico responsable puede cancelar esta orden.',
        );
      }
      if (motivo.trim().isEmpty) {
        throw const ReglaNegocio('Indica el motivo de la cancelación.');
      }
      await _actualizar(
        ordenId,
        OrdenesCompanion(
          estado: const Value(EstadoOrden.cancelada),
          fechaCierre: Value(DateTime.now()),
          notaCierre: Value(motivo.trim()),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------
  // Trabajos y repuestos
  // ---------------------------------------------------------------------

  Future<void> agregarTrabajo({
    required int ordenId,
    required int tecnicoId,
    required String descripcion,
    required double costo,
  }) {
    return _db.transaction(() async {
      await _ordenDelResponsable(
        ordenId,
        tecnicoId,
        const [EstadoOrden.enReparacion],
      );
      if (descripcion.trim().isEmpty) {
        throw const ReglaNegocio('Describe el trabajo realizado.');
      }
      if (costo < 0) {
        throw const ReglaNegocio('El costo no puede ser negativo.');
      }
      await _db.into(_db.trabajos).insert(
            TrabajosCompanion.insert(
              ordenId: ordenId,
              tecnicoId: tecnicoId,
              descripcion: descripcion.trim(),
              costo: costo,
              fecha: DateTime.now(),
            ),
          );
    });
  }

  Future<void> eliminarTrabajo(int trabajoId, int tecnicoId) {
    return _db.transaction(() async {
      final trabajo = await (_db.select(_db.trabajos)
            ..where((t) => t.id.equals(trabajoId)))
          .getSingleOrNull();
      if (trabajo == null) return;
      await _ordenDelResponsable(
        trabajo.ordenId,
        tecnicoId,
        const [EstadoOrden.enReparacion],
      );
      await (_db.delete(_db.trabajos)..where((t) => t.id.equals(trabajoId)))
          .go();
    });
  }

  /// Anota un repuesto en la orden y descuenta las existencias del almacén
  /// en la misma transacción.
  Future<void> usarRepuesto({
    required int ordenId,
    required int tecnicoId,
    required int repuestoId,
    required int cantidad,
  }) {
    return _db.transaction(() async {
      await _ordenDelResponsable(
        ordenId,
        tecnicoId,
        const [EstadoOrden.enReparacion],
      );
      if (cantidad <= 0) {
        throw const ReglaNegocio('La cantidad debe ser mayor que cero.');
      }
      final repuesto = await (_db.select(_db.repuestos)
            ..where((r) => r.id.equals(repuestoId)))
          .getSingleOrNull();
      if (repuesto == null) {
        throw const ReglaNegocio('El repuesto no existe en el inventario.');
      }
      if (repuesto.existencias < cantidad) {
        throw ReglaNegocio(
          'No hay existencias suficientes de "${repuesto.nombre}" '
          '(quedan ${repuesto.existencias}).',
        );
      }

      await (_db.update(_db.repuestos)..where((r) => r.id.equals(repuestoId)))
          .write(
        RepuestosCompanion(
          existencias: Value(repuesto.existencias - cantidad),
        ),
      );

      // Si el repuesto ya estaba anotado en la orden se suma la cantidad.
      final previo = await (_db.select(_db.repuestosUsados)
            ..where(
              (u) =>
                  u.ordenId.equals(ordenId) & u.repuestoId.equals(repuestoId),
            ))
          .getSingleOrNull();
      if (previo != null) {
        await (_db.update(_db.repuestosUsados)
              ..where((u) => u.id.equals(previo.id)))
            .write(
          RepuestosUsadosCompanion(
            cantidad: Value(previo.cantidad + cantidad),
          ),
        );
      } else {
        await _db.into(_db.repuestosUsados).insert(
              RepuestosUsadosCompanion.insert(
                ordenId: ordenId,
                repuestoId: repuestoId,
                cantidad: cantidad,
                precioUnitario: repuesto.precio,
                fecha: DateTime.now(),
              ),
            );
      }
    });
  }

  /// Quita un repuesto de la orden y lo devuelve al almacén.
  Future<void> quitarRepuesto(int usoId, int tecnicoId) {
    return _db.transaction(() async {
      final uso = await (_db.select(_db.repuestosUsados)
            ..where((u) => u.id.equals(usoId)))
          .getSingleOrNull();
      if (uso == null) return;
      await _ordenDelResponsable(
        uso.ordenId,
        tecnicoId,
        const [EstadoOrden.enReparacion],
      );
      final repuesto = await (_db.select(_db.repuestos)
            ..where((r) => r.id.equals(uso.repuestoId)))
          .getSingle();
      await (_db.update(_db.repuestos)..where((r) => r.id.equals(repuesto.id)))
          .write(
        RepuestosCompanion(
          existencias: Value(repuesto.existencias + uso.cantidad),
        ),
      );
      await (_db.delete(_db.repuestosUsados)..where((u) => u.id.equals(usoId)))
          .go();
    });
  }

  // ---------------------------------------------------------------------
  // Auxiliares
  // ---------------------------------------------------------------------

  Future<Orden> _orden(int ordenId) async {
    final orden = await (_db.select(_db.ordenes)
          ..where((o) => o.id.equals(ordenId)))
        .getSingleOrNull();
    if (orden == null) throw const ReglaNegocio('La orden no existe.');
    return orden;
  }

  /// Comprueba que la orden esté en uno de los [estados] y que
  /// [tecnicoId] sea su responsable.
  Future<Orden> _ordenDelResponsable(
    int ordenId,
    int tecnicoId,
    List<EstadoOrden> estados,
  ) async {
    final orden = await _orden(ordenId);
    if (!estados.contains(orden.estado)) {
      throw ReglaNegocio(
        'La orden está ${orden.estado.etiqueta.toLowerCase()} y no admite '
        'esta acción.',
      );
    }
    if (orden.tecnicoId != tecnicoId) {
      throw const ReglaNegocio(
        'Solo el técnico responsable puede modificar esta orden.',
      );
    }
    return orden;
  }

  Future<void> _actualizar(int ordenId, OrdenesCompanion cambios) {
    return (_db.update(_db.ordenes)..where((o) => o.id.equals(ordenId)))
        .write(cambios);
  }
}
