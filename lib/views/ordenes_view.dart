import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../data/models/enums.dart';
import '../data/models/modelos.dart';
import '../viewmodels/ordenes_viewmodel.dart';
import 'estilo.dart';
import 'orden_view.dart';

/// Órdenes agrupadas por estado en una sola lista.
class OrdenesView extends ConsumerWidget {
  const OrdenesView({super.key, this.cerradas = false});

  /// Si es verdadero muestra las entregadas y canceladas.
  final bool cerradas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(ordenesViewModelProvider);
    final vm = ref.read(ordenesViewModelProvider.notifier);
    final estados = cerradas
        ? const [EstadoOrden.entregada, EstadoOrden.cancelada]
        : EstadoOrden.abiertas;
    final cargando = ref.watch(ordenesProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(cerradas ? 'Órdenes cerradas' : 'Órdenes abiertas'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: vm.buscar,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Buscar orden, cliente, equipo o técnico',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text('Solo las mías'),
                selected: filtro.soloMias,
                onSelected: vm.mostrarSoloMias,
              ),
            ],
          ),
          if (cargando) const LinearProgressIndicator(),
          for (final estado in estados) _Grupo(estado: estado),
        ],
      ),
    );
  }
}

class _Grupo extends ConsumerWidget {
  const _Grupo({required this.estado});

  final EstadoOrden estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordenes = ref.watch(ordenesPorEstadoProvider(estado));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloSeccion(
          '${estado.etiqueta} (${ordenes.length})',
          accion: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colorEstado(estado),
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (ordenes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Ninguna orden.',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        for (final o in ordenes) TarjetaOrden(o),
      ],
    );
  }
}

class TarjetaOrden extends StatelessWidget {
  const TarjetaOrden(this.resumen, {super.key});

  final OrdenResumen resumen;

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    final color = colorEstado(resumen.orden.estado);
    return Tarjeta(
      onTap: () => abrir(context, OrdenView(ordenId: resumen.orden.id)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Icon(iconoEquipo(resumen.equipo.tipo)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resumen.nombreEquipo,
                  style: estilos.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${resumen.cliente.nombre} · '
                  '${formatoFecha(resumen.orden.fechaRecepcion)}',
                  style: estilos.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  resumen.tecnico == null
                      ? 'Nadie la ha tomado'
                      : 'La tiene ${resumen.tecnico!.nombre}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          Text('#${resumen.orden.id}', style: estilos.titleLarge),
        ],
      ),
    );
  }
}
