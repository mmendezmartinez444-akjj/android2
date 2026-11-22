import '../database/app_database.dart';
import 'enums.dart';

/// Orden con los datos necesarios para mostrarla en un listado.
class OrdenResumen {
  const OrdenResumen({
    required this.orden,
    required this.equipo,
    required this.cliente,
    this.tecnico,
  });

  final Orden orden;
  final Equipo equipo;
  final Cliente cliente;

  /// Técnico responsable; nulo si nadie ha tomado la orden.
  final Tecnico? tecnico;

  String get nombreEquipo => '${equipo.marca} ${equipo.modelo}';

  String get responsable => tecnico?.nombre ?? 'Sin tomar';
}

/// Repuesto usado en una orden junto con su ficha de inventario.
class RepuestoUsadoDetalle {
  const RepuestoUsadoDetalle({required this.uso, required this.repuesto});

  final RepuestoUsado uso;
  final Repuesto repuesto;

  double get subtotal => uso.cantidad * uso.precioUnitario;
}

/// Orden completa: trabajos, repuestos y costos.
class OrdenDetalle {
  const OrdenDetalle({
    required this.resumen,
    required this.recibidoPor,
    required this.trabajos,
    required this.repuestos,
  });

  final OrdenResumen resumen;
  final Tecnico recibidoPor;
  final List<Trabajo> trabajos;
  final List<RepuestoUsadoDetalle> repuestos;

  Orden get orden => resumen.orden;
  Equipo get equipo => resumen.equipo;
  Cliente get cliente => resumen.cliente;
  Tecnico? get tecnico => resumen.tecnico;

  double get totalManoObra => trabajos.fold(0, (suma, t) => suma + t.costo);

  double get totalRepuestos =>
      repuestos.fold(0, (suma, r) => suma + r.subtotal);

  /// Costo total = mano de obra + repuestos.
  double get total => totalManoObra + totalRepuestos;
}

/// Lo que el técnico activo puede hacer con una orden.
class PermisosOrden {
  const PermisosOrden({
    this.puedeTomar = false,
    this.puedeEditar = false,
    this.puedeMarcarLista = false,
    this.puedeLiberar = false,
    this.puedeReabrir = false,
    this.puedeEntregar = false,
    this.puedeCancelar = false,
    this.aviso,
  });

  final bool puedeTomar;

  /// Añadir o quitar trabajos y repuestos.
  final bool puedeEditar;
  final bool puedeMarcarLista;
  final bool puedeLiberar;
  final bool puedeReabrir;
  final bool puedeEntregar;
  final bool puedeCancelar;

  /// Explicación para el técnico cuando no puede modificar la orden.
  final String? aviso;

  factory PermisosOrden.calcular(OrdenDetalle d, Tecnico? activo) {
    final estado = d.orden.estado;
    if (!estado.abierta) {
      return PermisosOrden(
        aviso: 'Orden ${estado.etiqueta.toLowerCase()}: solo consulta.',
      );
    }
    if (activo == null) {
      return const PermisosOrden(
        aviso: 'Selecciona qué técnico está usando la app para poder '
            'trabajar con la orden.',
      );
    }
    final esResponsable = d.orden.tecnicoId == activo.id;
    switch (estado) {
      case EstadoOrden.recibida:
        return const PermisosOrden(puedeTomar: true, puedeCancelar: true);
      case EstadoOrden.enReparacion:
        if (!esResponsable) {
          return PermisosOrden(
            aviso: 'Esta orden la tiene tomada ${d.resumen.responsable}. '
                'Solo ese técnico puede modificarla.',
          );
        }
        return const PermisosOrden(
          puedeEditar: true,
          puedeMarcarLista: true,
          puedeLiberar: true,
          puedeCancelar: true,
        );
      case EstadoOrden.lista:
        return PermisosOrden(
          puedeEntregar: true,
          puedeReabrir: esResponsable,
          puedeCancelar: esResponsable,
          aviso: esResponsable
              ? null
              : 'Reparada por ${d.resumen.responsable}. Puedes entregarla '
                  'al cliente.',
        );
      case EstadoOrden.entregada:
      case EstadoOrden.cancelada:
        return const PermisosOrden();
    }
  }
}

/// Cuánto trabajo tiene asignado un técnico.
class CargaTecnico {
  const CargaTecnico({
    required this.tecnico,
    required this.enReparacion,
    required this.listas,
    required this.cerradas,
  });

  final Tecnico tecnico;

  /// Órdenes que está reparando ahora mismo.
  final int enReparacion;

  /// Órdenes terminadas pendientes de entrega.
  final int listas;

  /// Órdenes entregadas a lo largo del tiempo.
  final int cerradas;

  /// Órdenes abiertas a su cargo.
  int get abiertas => enReparacion + listas;
}

/// Números generales del taller para la pantalla de inicio.
class ResumenTaller {
  const ResumenTaller({
    required this.recibidas,
    required this.enReparacion,
    required this.listas,
    required this.repuestosPorAgotarse,
  });

  final int recibidas;
  final int enReparacion;
  final int listas;
  final int repuestosPorAgotarse;

  int get abiertas => recibidas + enReparacion + listas;
}

class EquipoConCliente {
  const EquipoConCliente({required this.equipo, required this.cliente});

  final Equipo equipo;
  final Cliente cliente;

  String get nombreEquipo => '${equipo.marca} ${equipo.modelo}';
}

class ClienteConEquipos {
  const ClienteConEquipos({required this.cliente, required this.equipos});

  final Cliente cliente;
  final List<Equipo> equipos;
}

extension RepuestoStock on Repuesto {
  bool get agotado => existencias <= 0;

  /// Está por agotarse cuando las existencias llegan al mínimo definido.
  bool get porAgotarse => existencias <= stockMinimo;
}
