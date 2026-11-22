import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/modelos.dart';
import '../viewmodels/inventario_viewmodel.dart';
import '../viewmodels/orden_detalle_viewmodel.dart';
import 'estilo.dart';
import 'historial_view.dart';

/// Orden de reparación con barra de avance y tarjetas por sección.
class OrdenView extends ConsumerWidget {
  const OrdenView({super.key, required this.ordenId});

  final int ordenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carga = ref.watch(ordenDetalleProvider(ordenId));
    final detalle = carga.valueOrNull;
    final permisos = ref.watch(permisosOrdenProvider(ordenId));
    final vm = ref.watch(ordenDetalleViewModelProvider(ordenId));

    // Botón principal fijo en la parte inferior.
    Widget? principal;
    if (detalle != null && permisos.puedeMarcarLista) {
      principal = FilledButton.icon(
        onPressed: () => resolver(
          context,
          vm.marcarLista(),
          exito: 'La orden quedó lista para entregar.',
        ),
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text('Reparación terminada'),
      );
    } else if (detalle != null && permisos.puedeEntregar) {
      principal = FilledButton.icon(
        onPressed: () async {
          final ok = await preguntar(
            context,
            titulo: '¿Entregar el equipo?',
            mensaje: 'El cliente debe pagar '
                '${formatoDinero(detalle.total)}.',
            aceptar: 'Sí, entregar',
          );
          if (!ok || !context.mounted) return;
          await resolver(context, vm.entregar(), exito: 'Equipo entregado.');
        },
        icon: const Icon(Icons.how_to_reg_rounded),
        label: Text('Entregar · ${formatoDinero(detalle.total)}'),
      );
    } else if (detalle != null && permisos.puedeTomar) {
      principal = FilledButton.icon(
        onPressed: () => resolver(
          context,
          vm.tomar(),
          exito: 'Ahora esta orden es tuya.',
        ),
        icon: const Icon(Icons.back_hand_rounded),
        label: const Text('Tomar esta orden'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Orden #$ordenId')),
      bottomNavigationBar: principal == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: principal,
              ),
            ),
      body: detalle == null
          ? Center(
              child: carga.isLoading
                  ? const CircularProgressIndicator()
                  : const Vacio('La orden no existe.'),
            )
          : _Cuerpo(detalle: detalle, permisos: permisos, vm: vm),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.detalle,
    required this.permisos,
    required this.vm,
  });

  final OrdenDetalle detalle;
  final PermisosOrden permisos;
  final OrdenDetalleViewModel vm;

  @override
  Widget build(BuildContext context) {
    final orden = detalle.orden;
    final estilos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    Future<void> nuevoTrabajo() async {
      final datos = await Navigator.push<(String, String)>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const TrabajoFormView(),
        ),
      );
      if (datos == null || !context.mounted) return;
      await resolver(context, vm.agregarTrabajo(datos.$1, datos.$2));
    }

    Future<void> nuevoRepuesto() async {
      final datos = await Navigator.push<(int, int)>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ElegirRepuestoView(),
        ),
      );
      if (datos == null || !context.mounted) return;
      await resolver(
        context,
        vm.usarRepuesto(datos.$1, datos.$2),
        exito: 'Repuesto anotado y descontado del inventario.',
      );
    }

    Future<void> cancelar() async {
      final motivo = await pedirTexto(
        context,
        titulo: 'Cancelar la orden',
        etiqueta: '¿Por qué se cancela?',
      );
      if (motivo == null || !context.mounted) return;
      await resolver(context, vm.cancelar(motivo), exito: 'Orden cancelada.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Avance(estado: orden.estado),
        const SizedBox(height: 16),
        // Quién es el responsable.
        Tarjeta(
          color: esquema.primaryContainer,
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: Icon(
                  detalle.tecnico == null
                      ? Icons.person_off_rounded
                      : Icons.engineering_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Responsable', style: estilos.labelMedium),
                    Text(
                      detalle.tecnico?.nombre ?? 'Nadie la ha tomado',
                      style: estilos.titleLarge,
                    ),
                  ],
                ),
              ),
              if (permisos.puedeLiberar)
                TextButton(
                  onPressed: () => resolver(
                    context,
                    vm.liberar(),
                    exito: 'Orden liberada para otro técnico.',
                  ),
                  child: const Text('Liberar'),
                ),
            ],
          ),
        ),
        if (permisos.aviso != null)
          Tarjeta(
            color: esquema.tertiaryContainer,
            child: Row(
              children: [
                const Icon(Icons.info_rounded),
                const SizedBox(width: 12),
                Expanded(child: Text(permisos.aviso!)),
              ],
            ),
          ),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconoEquipo(detalle.equipo.tipo), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detalle.resumen.nombreEquipo,
                          style: estilos.titleMedium,
                        ),
                        Text(
                          '${detalle.equipo.tipo.etiqueta} · '
                          'Serie ${detalle.equipo.numeroSerie}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                '${detalle.cliente.nombre} · ${detalle.cliente.telefono}',
                style: estilos.titleSmall,
              ),
              const SizedBox(height: 8),
              Text('Falla: ${orden.fallaReportada}'),
              const SizedBox(height: 8),
              Text(
                'Recibió ${detalle.recibidoPor.nombre} el '
                '${formatoFechaHora(orden.fechaRecepcion)}',
                style: estilos.bodySmall,
              ),
              if (orden.fechaCierre != null)
                Text(
                  '${orden.estado == EstadoOrden.cancelada ? 'Cancelada' : 'Entregada'} el '
                  '${formatoFechaHora(orden.fechaCierre!)}',
                  style: estilos.bodySmall,
                ),
              if (orden.notaCierre != null)
                Text('Motivo: ${orden.notaCierre}', style: estilos.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => abrir(
                      context,
                      HistorialView.equipo(equipoId: detalle.equipo.id),
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Equipo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => abrir(
                      context,
                      HistorialView.cliente(clienteId: detalle.cliente.id),
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Cliente'),
                  ),
                ],
              ),
            ],
          ),
        ),
        TituloSeccion(
          'Trabajos realizados',
          accion: permisos.puedeEditar
              ? IconButton.filledTonal(
                  tooltip: 'Añadir trabajo',
                  onPressed: nuevoTrabajo,
                  icon: const Icon(Icons.add_rounded),
                )
              : null,
        ),
        Tarjeta(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              if (detalle.trabajos.isEmpty)
                const ListTile(title: Text('Todavía no se anotó ninguno.')),
              for (final t in detalle.trabajos)
                ListTile(
                  title: Text(t.descripcion),
                  subtitle: Text(formatoDinero(t.costo)),
                  trailing: permisos.puedeEditar
                      ? IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              resolver(context, vm.eliminarTrabajo(t.id)),
                        )
                      : null,
                ),
            ],
          ),
        ),
        TituloSeccion(
          'Repuestos utilizados',
          accion: permisos.puedeEditar
              ? IconButton.filledTonal(
                  tooltip: 'Añadir repuesto',
                  onPressed: nuevoRepuesto,
                  icon: const Icon(Icons.add_rounded),
                )
              : null,
        ),
        Tarjeta(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              if (detalle.repuestos.isEmpty)
                const ListTile(title: Text('No se usó ningún repuesto.')),
              for (final r in detalle.repuestos)
                ListTile(
                  title: Text('${r.uso.cantidad} × ${r.repuesto.nombre}'),
                  subtitle: Text(formatoDinero(r.subtotal)),
                  trailing: permisos.puedeEditar
                      ? IconButton(
                          tooltip: 'Devolver al inventario',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => resolver(
                            context,
                            vm.quitarRepuesto(r.uso.id),
                            exito: 'Repuesto devuelto al inventario.',
                          ),
                        )
                      : null,
                ),
            ],
          ),
        ),
        TituloSeccion('Costo'),
        Tarjeta(
          color: esquema.primaryContainer,
          child: Column(
            children: [
              _Linea('Mano de obra', formatoDinero(detalle.totalManoObra)),
              _Linea('Repuestos', formatoDinero(detalle.totalRepuestos)),
              const Divider(),
              Row(
                children: [
                  Expanded(child: Text('Total', style: estilos.titleLarge)),
                  Text(
                    formatoDinero(detalle.total),
                    style: estilos.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (permisos.puedeReabrir)
          TextButton.icon(
            onPressed: () => resolver(context, vm.reabrir()),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Falta algo: volver a reparación'),
          ),
        if (permisos.puedeCancelar)
          TextButton.icon(
            onPressed: cancelar,
            style: TextButton.styleFrom(foregroundColor: esquema.error),
            icon: const Icon(Icons.block_rounded),
            label: const Text('Cancelar esta orden'),
          ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [Expanded(child: Text(etiqueta)), Text(valor)],
      ),
    );
  }
}

/// Barra de avance: recibida → en reparación → lista → entregada.
class _Avance extends StatelessWidget {
  const _Avance({required this.estado});

  final EstadoOrden estado;

  static const _pasos = [
    EstadoOrden.recibida,
    EstadoOrden.enReparacion,
    EstadoOrden.lista,
    EstadoOrden.entregada,
  ];

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (estado == EstadoOrden.cancelada) {
      return Tarjeta(
        color: esquema.errorContainer,
        child: Row(
          children: [
            Icon(Icons.block_rounded, color: esquema.onErrorContainer),
            const SizedBox(width: 12),
            Text(
              'Orden cancelada',
              style: TextStyle(
                color: esquema.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    final actual = _pasos.indexOf(estado);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _pasos.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : i <= actual
                                ? esquema.primary
                                : esquema.outlineVariant,
                      ),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: i <= actual
                          ? esquema.primary
                          : esquema.outlineVariant,
                      foregroundColor: esquema.onPrimary,
                      child: i < actual
                          ? const Icon(Icons.check_rounded, size: 16)
                          : Text('${i + 1}'),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == _pasos.length - 1
                            ? Colors.transparent
                            : i < actual
                                ? esquema.primary
                                : esquema.outlineVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _pasos[i].etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        i == actual ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pantalla para anotar un trabajo: devuelve (descripción, costo).
class TrabajoFormView extends StatefulWidget {
  const TrabajoFormView({super.key});

  @override
  State<TrabajoFormView> createState() => _TrabajoFormViewState();
}

class _TrabajoFormViewState extends State<TrabajoFormView> {
  final _descripcion = TextEditingController();
  final _costo = TextEditingController();

  @override
  void dispose() {
    _descripcion.dispose();
    _costo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo trabajo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('¿Qué trabajo se realizó?'),
          const SizedBox(height: 8),
          TextField(
            controller: _descripcion,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ej.: cambio de pantalla',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Costo de la mano de obra'),
          const SizedBox(height: 8),
          TextField(
            controller: _costo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(prefixText: '\$ ', hintText: '0.00'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, (_descripcion.text, _costo.text)),
            child: const Text('Guardar trabajo'),
          ),
        ],
      ),
    );
  }
}

/// Pantalla para elegir un repuesto del inventario: devuelve (id, cantidad).
class ElegirRepuestoView extends ConsumerStatefulWidget {
  const ElegirRepuestoView({super.key});

  @override
  ConsumerState<ElegirRepuestoView> createState() => _ElegirRepuestoViewState();
}

class _ElegirRepuestoViewState extends ConsumerState<ElegirRepuestoView> {
  String _busqueda = '';
  Repuesto? _elegido;
  double _cantidad = 1;

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(repuestosProvider).valueOrNull ?? const [];
    final texto = _busqueda.trim().toLowerCase();
    final lista = todos
        .where(
          (r) =>
              texto.isEmpty ||
              r.nombre.toLowerCase().contains(texto) ||
              r.codigo.toLowerCase().contains(texto),
        )
        .toList();
    final elegido = _elegido;
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Elegir repuesto')),
      bottomNavigationBar: elegido == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${elegido.nombre}: ${_cantidad.round()} '
                      '${_cantidad.round() == 1 ? 'unidad' : 'unidades'}',
                    ),
                    if (elegido.existencias > 1)
                      Slider(
                        value: _cantidad,
                        min: 1,
                        max: elegido.existencias.toDouble(),
                        divisions: elegido.existencias - 1,
                        label: '${_cantidad.round()}',
                        onChanged: (v) => setState(() => _cantidad = v),
                      ),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        (elegido.id, _cantidad.round()),
                      ),
                      child: Text(
                        'Usar · '
                        '${formatoDinero(elegido.precio * _cantidad.round())}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar por nombre o código',
            ),
          ),
          const SizedBox(height: 12),
          for (final r in lista)
            Tarjeta(
              color: elegido?.id == r.id ? esquema.primaryContainer : null,
              onTap: r.agotado
                  ? null
                  : () => setState(() {
                        _elegido = r;
                        _cantidad = 1;
                      }),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.nombre,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text('${r.codigo} · ${formatoDinero(r.precio)}'),
                      ],
                    ),
                  ),
                  Text(
                    r.agotado ? 'AGOTADO' : 'Hay ${r.existencias}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: r.porAgotarse ? esquema.error : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
