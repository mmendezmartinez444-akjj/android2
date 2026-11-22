import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/models/modelos.dart';
import '../viewmodels/inventario_viewmodel.dart';
import '../viewmodels/ordenes_viewmodel.dart';
import '../viewmodels/tecnicos_viewmodel.dart';
import 'clientes_view.dart';
import 'estilo.dart';
import 'inventario_view.dart';
import 'ordenes_view.dart';
import 'recepcion_view.dart';
import 'tecnicos_view.dart';

/// Panel de inicio: desde aquí se llega a todas las secciones.
class PanelView extends ConsumerWidget {
  const PanelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estilos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final tecnicos = ref.watch(tecnicosProvider).valueOrNull ?? const [];
    final activo = ref.watch(tecnicoActivoProvider);
    final resumen = ref.watch(resumenTallerProvider).valueOrNull;
    final porAgotarse = ref.watch(repuestosPorAgotarseProvider);
    final mias = activo == null
        ? 0
        : ref.watch(ordenesDeTecnicoProvider(activo.id)).length;

    void verOrdenes({required bool soloMias, bool cerradas = false}) {
      ref.read(ordenesViewModelProvider.notifier)
        ..buscar('')
        ..mostrarSoloMias(soloMias);
      abrir(context, OrdenesView(cerradas: cerradas));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tu Solution',
              style: estilos.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: esquema.primary,
              ),
            ),
            Text('Taller de reparaciones', style: estilos.bodyLarge),
            const SizedBox(height: 20),
            Text('¿Quién está usando la app?', style: estilos.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tecnico in tecnicos)
                  ChoiceChip(
                    avatar: const Icon(Icons.person_rounded, size: 18),
                    label: Text(tecnico.nombre),
                    selected: tecnico.id == activo?.id,
                    onSelected: (_) => resolver(
                      context,
                      ref
                          .read(tecnicosViewModelProvider)
                          .seleccionarActivo(tecnico.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => abrir(context, const RecepcionView()),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Recibir un equipo'),
            ),
            const SizedBox(height: 20),
            if (porAgotarse.isNotEmpty) _AlertaStock(repuestos: porAgotarse),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
              children: [
                _Modulo(
                  icono: Icons.assignment_rounded,
                  titulo: 'Órdenes abiertas',
                  dato: resumen == null ? '…' : '${resumen.abiertas}',
                  detalle:
                      resumen == null ? '' : '${resumen.recibidas} sin tomar',
                  alPulsar: () => verOrdenes(soloMias: false),
                ),
                _Modulo(
                  icono: Icons.build_circle_rounded,
                  titulo: 'Mis órdenes',
                  dato: activo == null ? '—' : '$mias',
                  detalle: activo?.nombre ?? 'Elige un técnico',
                  alPulsar: () => verOrdenes(soloMias: true),
                ),
                _Modulo(
                  icono: Icons.inventory_2_rounded,
                  titulo: 'Inventario',
                  dato: '${porAgotarse.length}',
                  detalle: 'por agotarse',
                  alerta: porAgotarse.isNotEmpty,
                  alPulsar: () => abrir(context, const InventarioView()),
                ),
                _Modulo(
                  icono: Icons.groups_rounded,
                  titulo: 'Técnicos',
                  dato: '${tecnicos.length}',
                  detalle: 'carga de trabajo',
                  alPulsar: () => abrir(context, const TecnicosView()),
                ),
                _Modulo(
                  icono: Icons.manage_search_rounded,
                  titulo: 'Clientes y equipos',
                  dato: '',
                  detalle: 'historial de reparaciones',
                  alPulsar: () => abrir(context, const ClientesView()),
                ),
                _Modulo(
                  icono: Icons.task_alt_rounded,
                  titulo: 'Órdenes cerradas',
                  dato: '',
                  detalle: 'entregadas y canceladas',
                  alPulsar: () => verOrdenes(soloMias: false, cerradas: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertaStock extends StatelessWidget {
  const _AlertaStock({required this.repuestos});

  final List<Repuesto> repuestos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Tarjeta(
      color: esquema.errorContainer,
      onTap: () => abrir(context, const InventarioView()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: esquema.onErrorContainer),
              const SizedBox(width: 8),
              Text(
                'Repuestos por agotarse',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: esquema.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in repuestos.take(4))
            Text(
              r.agotado
                  ? '• ${r.nombre}: agotado'
                  : '• ${r.nombre}: quedan ${r.existencias}',
              style: TextStyle(color: esquema.onErrorContainer),
            ),
          if (repuestos.length > 4)
            Text(
              'y ${repuestos.length - 4} más…',
              style: TextStyle(color: esquema.onErrorContainer),
            ),
        ],
      ),
    );
  }
}

class _Modulo extends StatelessWidget {
  const _Modulo({
    required this.icono,
    required this.titulo,
    required this.dato,
    required this.detalle,
    required this.alPulsar,
    this.alerta = false,
  });

  final IconData icono;
  final String titulo;
  final String dato;
  final String detalle;
  final VoidCallback alPulsar;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estilos = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: alerta ? esquema.tertiaryContainer : esquema.primaryContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 30),
                  const Spacer(),
                  Text(
                    dato,
                    style: estilos.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                titulo,
                style:
                    estilos.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                detalle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: estilos.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
