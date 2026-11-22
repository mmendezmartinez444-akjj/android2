import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formato.dart';
import '../data/database/app_database.dart';
import '../data/models/modelos.dart';
import '../viewmodels/inventario_viewmodel.dart';
import 'estilo.dart';

/// Inventario dividido en "reponer pronto" y "con existencias", con
/// botones para sumar o restar unidades en la misma fila.
class InventarioView extends ConsumerStatefulWidget {
  const InventarioView({super.key});

  @override
  ConsumerState<InventarioView> createState() => _InventarioViewState();
}

class _InventarioViewState extends ConsumerState<InventarioView> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final repuestos = ref.watch(repuestosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(
            tooltip: 'Nuevo repuesto',
            onPressed: () => abrir(context, const RepuestoFormView()),
            icon: const Icon(Icons.add_circle_rounded),
          ),
        ],
      ),
      body: repuestos.vista((todos) {
        final texto = _busqueda.trim().toLowerCase();
        final lista = todos
            .where(
              (r) =>
                  texto.isEmpty ||
                  r.nombre.toLowerCase().contains(texto) ||
                  r.codigo.toLowerCase().contains(texto),
            )
            .toList();
        final bajos = lista.where((r) => r.porAgotarse).toList();
        final bien = lista.where((r) => !r.porAgotarse).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar repuesto',
              ),
            ),
            const SizedBox(height: 8),
            TituloSeccion('Reponer pronto (${bajos.length})'),
            if (bajos.isEmpty) const Text('Ningún repuesto está por agotarse.'),
            for (final r in bajos) _Fila(repuesto: r),
            TituloSeccion('Con existencias (${bien.length})'),
            for (final r in bien) _Fila(repuesto: r),
          ],
        );
      }),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.repuesto});

  final Repuesto repuesto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final estilos = Theme.of(context).textTheme;
    final vm = ref.watch(inventarioViewModelProvider);
    return Tarjeta(
      color: repuesto.agotado
          ? esquema.errorContainer
          : repuesto.porAgotarse
              ? esquema.tertiaryContainer
              : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      onTap: () => abrir(context, RepuestoFormView(repuesto: repuesto)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repuesto.nombre, style: estilos.titleSmall),
                Text(
                  '${repuesto.codigo} · ${formatoDinero(repuesto.precio)}',
                  style: estilos.bodySmall,
                ),
                Text(
                  repuesto.agotado
                      ? 'Agotado'
                      : repuesto.porAgotarse
                          ? 'Por agotarse (mínimo ${repuesto.stockMinimo})'
                          : 'Mínimo ${repuesto.stockMinimo}',
                  style:
                      estilos.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restar una unidad',
            onPressed: repuesto.existencias > 0
                ? () => resolver(
                      context,
                      vm.ajustarExistencias(repuesto.id, -1),
                    )
                : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${repuesto.existencias}',
              textAlign: TextAlign.center,
              style: estilos.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'Sumar una unidad',
            onPressed: () =>
                resolver(context, vm.ajustarExistencias(repuesto.id, 1)),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

/// Pantalla para crear o editar un repuesto.
class RepuestoFormView extends ConsumerStatefulWidget {
  const RepuestoFormView({super.key, this.repuesto});

  final Repuesto? repuesto;

  @override
  ConsumerState<RepuestoFormView> createState() => _RepuestoFormViewState();
}

class _RepuestoFormViewState extends ConsumerState<RepuestoFormView> {
  late final _nombre = TextEditingController(text: widget.repuesto?.nombre);
  late final _codigo = TextEditingController(text: widget.repuesto?.codigo);
  late final _precio = TextEditingController(
    text: widget.repuesto?.precio.toStringAsFixed(2),
  );
  late final _existencias = TextEditingController(
    text: widget.repuesto?.existencias.toString() ?? '0',
  );
  late final _minimo = TextEditingController(
    text: widget.repuesto?.stockMinimo.toString() ?? '3',
  );
  final _entrada = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _codigo,
      _precio,
      _existencias,
      _minimo,
      _entrada,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final vm = ref.read(inventarioViewModelProvider);
    final ok = await resolver(
      context,
      vm.guardar(
        id: widget.repuesto?.id,
        nombre: _nombre.text,
        codigo: _codigo.text,
        precio: _precio.text,
        existencias: _existencias.text,
        stockMinimo: _minimo.text,
      ),
    );
    if (!ok || !mounted) return;
    // Entrada de mercancía opcional al editar.
    final entrada = int.tryParse(_entrada.text.trim());
    if (widget.repuesto != null && entrada != null && entrada > 0) {
      final sumado = await resolver(
        context,
        vm.ajustarExistencias(widget.repuesto!.id, entrada),
      );
      if (!sumado || !mounted) return;
    }
    notificar(context, 'Repuesto guardado.');
    Navigator.pop(context);
  }

  Future<void> _eliminar() async {
    final ok = await preguntar(
      context,
      titulo: '¿Eliminar el repuesto?',
      mensaje: 'Se quitará "${widget.repuesto!.nombre}" del inventario.',
      aceptar: 'Eliminar',
    );
    if (!ok || !mounted) return;
    final eliminado = await resolver(
      context,
      ref.read(inventarioViewModelProvider).eliminar(widget.repuesto!.id),
    );
    if (eliminado && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.repuesto == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(esNuevo ? 'Nuevo repuesto' : 'Editar repuesto'),
        actions: [
          if (!esNuevo)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _eliminar,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Código'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _precio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minimo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Avisar cuando queden (mínimo)',
            ),
          ),
          const SizedBox(height: 12),
          if (esNuevo)
            TextField(
              controller: _existencias,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Existencias iniciales',
              ),
            )
          else
            TextField(
              controller: _entrada,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Entrada de mercancía (opcional)',
                helperText:
                    'Hay ${widget.repuesto!.existencias}. Escribe cuántas '
                    'unidades llegaron.',
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
