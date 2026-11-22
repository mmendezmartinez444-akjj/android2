import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../data/models/enums.dart';
import '../data/models/modelos.dart';
import '../viewmodels/clientes_viewmodel.dart';
import 'estilo.dart';
import 'orden_view.dart';

/// Historial de reparaciones de un equipo o de un cliente, con resumen.
class HistorialView extends ConsumerWidget {
  const HistorialView.equipo({super.key, required int this.equipoId})
      : clienteId = null;

  const HistorialView.cliente({super.key, required int this.clienteId})
      : equipoId = null;

  final int? equipoId;
  final int? clienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esEquipo = equipoId != null;
    final historial = esEquipo
        ? ref.watch(historialEquipoProvider(equipoId!))
        : ref.watch(historialClienteProvider(clienteId!));
    final estilos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;

    String nombre = '';
    String detalle = '';
    if (esEquipo) {
      final e = ref.watch(equipoProvider(equipoId!)).valueOrNull;
      if (e != null) {
        nombre = e.nombreEquipo;
        detalle = 'Serie ${e.equipo.numeroSerie}\nDueño: ${e.cliente.nombre} '
            '(${e.cliente.telefono})';
      }
    } else {
      final c = ref.watch(clienteProvider(clienteId!)).valueOrNull;
      if (c != null) {
        nombre = c.nombre;
        detalle = 'Tel. ${c.telefono}';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(esEquipo ? 'Historial del equipo' : 'Historial del cliente'),
      ),
      body: historial.vista((lista) {
        final entregadas =
            lista.where((d) => d.orden.estado == EstadoOrden.entregada);
        final facturado = entregadas.fold<double>(0, (s, d) => s + d.total);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Tarjeta(
              color: esquema.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: estilos.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(detalle),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _Cifra('${lista.length}', 'visitas'),
                      _Cifra('${entregadas.length}', 'entregadas'),
                      _Cifra(formatoDinero(facturado), 'facturado'),
                    ],
                  ),
                ],
              ),
            ),
            if (lista.isEmpty) const Vacio('Sin reparaciones registradas.'),
            for (final d in lista) _Visita(detalle: d, conEquipo: !esEquipo),
          ],
        );
      }),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              valor,
              style: estilos.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(etiqueta, style: estilos.bodySmall),
        ],
      ),
    );
  }
}

class _Visita extends StatelessWidget {
  const _Visita({required this.detalle, required this.conEquipo});

  final OrdenDetalle detalle;
  final bool conEquipo;

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    return Tarjeta(
      onTap: () => abrir(context, OrdenView(ordenId: detalle.orden.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatoFecha(detalle.orden.fechaRecepcion)} · '
                  'Orden #${detalle.orden.id}',
                  style: estilos.titleSmall,
                ),
              ),
              PastillaEstado(detalle.orden.estado),
            ],
          ),
          if (conEquipo)
            Text(detalle.resumen.nombreEquipo, style: estilos.titleMedium),
          const SizedBox(height: 4),
          Text('Falla: ${detalle.orden.fallaReportada}'),
          Text('Reparó: ${detalle.resumen.responsable}'),
          const SizedBox(height: 8),
          Text('Trabajos', style: estilos.labelLarge),
          if (detalle.trabajos.isEmpty) const Text('Ninguno anotado'),
          for (final t in detalle.trabajos)
            Text('– ${t.descripcion}: ${formatoDinero(t.costo)}'),
          const SizedBox(height: 8),
          Text('Piezas cambiadas', style: estilos.labelLarge),
          if (detalle.repuestos.isEmpty) const Text('Ninguna'),
          for (final r in detalle.repuestos)
            Text(
              '– ${r.uso.cantidad} × ${r.repuesto.nombre}: '
              '${formatoDinero(r.subtotal)}',
            ),
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total ${formatoDinero(detalle.total)}',
              style: estilos.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
