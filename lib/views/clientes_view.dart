import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/clientes_viewmodel.dart';
import 'estilo.dart';
import 'historial_view.dart';

enum _Modo { clientes, equipos }

/// Buscador de clientes y equipos para consultar su historial.
class ClientesView extends ConsumerStatefulWidget {
  const ClientesView({super.key});

  @override
  ConsumerState<ClientesView> createState() => _ClientesViewState();
}

class _ClientesViewState extends ConsumerState<ClientesView> {
  _Modo _modo = _Modo.clientes;
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final texto = _busqueda.trim().toLowerCase();
    final estilos = Theme.of(context).textTheme;

    final Widget resultados;
    if (_modo == _Modo.clientes) {
      resultados = ref.watch(clientesProvider).vista((todos) {
        final lista = todos
            .where(
              (c) =>
                  texto.isEmpty ||
                  c.cliente.nombre.toLowerCase().contains(texto) ||
                  c.cliente.telefono.contains(texto),
            )
            .toList();
        if (lista.isEmpty) {
          return const Vacio(
            'No hay clientes que coincidan.',
            icono: Icons.person_search_rounded,
          );
        }
        return Column(
          children: [
            for (final c in lista)
              Tarjeta(
                onTap: () => abrir(
                  context,
                  HistorialView.cliente(clienteId: c.cliente.id),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.cliente.nombre, style: estilos.titleMedium),
                          Text('Tel. ${c.cliente.telefono}'),
                          Text(
                            c.equipos
                                .map((e) => '${e.marca} ${e.modelo}')
                                .join(', '),
                            style: estilos.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
          ],
        );
      });
    } else {
      resultados = ref.watch(equiposProvider).vista((todos) {
        final lista = todos
            .where(
              (e) =>
                  texto.isEmpty ||
                  e.nombreEquipo.toLowerCase().contains(texto) ||
                  e.equipo.numeroSerie.toLowerCase().contains(texto),
            )
            .toList();
        if (lista.isEmpty) {
          return const Vacio(
            'No hay equipos que coincidan.',
            icono: Icons.devices_other_rounded,
          );
        }
        return Column(
          children: [
            for (final e in lista)
              Tarjeta(
                onTap: () => abrir(
                  context,
                  HistorialView.equipo(equipoId: e.equipo.id),
                ),
                child: Row(
                  children: [
                    CircleAvatar(child: Icon(iconoEquipo(e.equipo.tipo))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.nombreEquipo, style: estilos.titleMedium),
                          Text('Serie ${e.equipo.numeroSerie}'),
                          Text(
                            'Dueño: ${e.cliente.nombre}',
                            style: estilos.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
          ],
        );
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes y equipos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Modo>(
            segments: const [
              ButtonSegment(
                value: _Modo.clientes,
                label: Text('Por cliente'),
                icon: Icon(Icons.person_rounded),
              ),
              ButtonSegment(
                value: _Modo.equipos,
                label: Text('Por equipo'),
                icon: Icon(Icons.devices_rounded),
              ),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() => _modo = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: _modo == _Modo.clientes
                  ? 'Nombre o teléfono'
                  : 'Marca, modelo o número de serie',
            ),
          ),
          const SizedBox(height: 12),
          resultados,
        ],
      ),
    );
  }
}
