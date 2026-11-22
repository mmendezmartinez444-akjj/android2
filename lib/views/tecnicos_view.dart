import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/modelos.dart';
import '../viewmodels/tecnicos_viewmodel.dart';
import 'estilo.dart';
import 'orden_view.dart';

/// Técnicos y reparto del trabajo abierto entre ellos.
class TecnicosView extends ConsumerWidget {
  const TecnicosView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carga = ref.watch(cargaTrabajoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Técnicos')),
      body: carga.vista((lista) {
        final total = lista.fold<int>(0, (s, c) => s + c.abiertas);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              total == 0
                  ? 'Ningún técnico tiene órdenes abiertas a su cargo.'
                  : 'Hay $total órdenes abiertas repartidas así:',
            ),
            const SizedBox(height: 12),
            for (final c in lista) _Ficha(carga: c, total: total),
          ],
        );
      }),
    );
  }
}

class _Ficha extends ConsumerWidget {
  const _Ficha({required this.carga, required this.total});

  final CargaTecnico carga;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tecnico = carga.tecnico;
    final esActivo = ref.watch(tecnicoActivoProvider)?.id == tecnico.id;
    final ordenes = ref.watch(ordenesDeTecnicoProvider(tecnico.id));
    final vm = ref.watch(tecnicosViewModelProvider);
    final estilos = Theme.of(context).textTheme;
    final esquema = Theme.of(context).colorScheme;
    final parte = total == 0 ? 0.0 : carga.abiertas / total;

    Future<void> renombrar() async {
      final nombre = await pedirTexto(
        context,
        titulo: 'Cambiar nombre',
        etiqueta: 'Nombre del técnico',
        inicial: tecnico.nombre,
      );
      if (nombre == null || !context.mounted) return;
      await resolver(context, vm.renombrar(tecnico.id, nombre));
    }

    return Tarjeta(
      color: esActivo ? esquema.primaryContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tecnico.nombre,
                  style:
                      estilos.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Cambiar nombre',
                onPressed: renombrar,
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          Text(
            '${carga.abiertas} abiertas (${(parte * 100).round()} % del taller)',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: parte, minHeight: 12),
          ),
          const SizedBox(height: 8),
          Text(
            'En reparación: ${carga.enReparacion}   ·   '
            'Listas: ${carga.listas}   ·   Entregadas: ${carga.cerradas}',
            style: estilos.bodySmall,
          ),
          for (final o in ordenes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(iconoEquipo(o.equipo.tipo)),
              title: Text('#${o.orden.id} · ${o.nombreEquipo}'),
              subtitle: PastillaEstado(o.orden.estado),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => abrir(context, OrdenView(ordenId: o.orden.id)),
            ),
          const SizedBox(height: 8),
          if (esActivo)
            const Row(
              children: [
                Icon(Icons.check_circle_rounded),
                SizedBox(width: 8),
                Text('Está usando la app'),
              ],
            )
          else
            OutlinedButton(
              onPressed: () => resolver(
                context,
                vm.seleccionarActivo(tecnico.id),
                exito: 'Ahora usa la app ${tecnico.nombre}.',
              ),
              child: Text('Usar la app como ${tecnico.nombre}'),
            ),
        ],
      ),
    );
  }
}
