import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';
import '../viewmodels/recepcion_viewmodel.dart';
import '../viewmodels/tecnicos_viewmodel.dart';
import 'estilo.dart';
import 'orden_view.dart';

/// Asistente de recepción en tres pasos: equipo, dueño y falla.
class RecepcionView extends ConsumerStatefulWidget {
  const RecepcionView({super.key});

  @override
  ConsumerState<RecepcionView> createState() => _RecepcionViewState();
}

class _RecepcionViewState extends ConsumerState<RecepcionView> {
  final _serie = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _cliente = TextEditingController();
  final _telefono = TextEditingController();
  final _falla = TextEditingController();
  TipoEquipo _tipo = TipoEquipo.celular;
  int _paso = 0;
  String? _avisoEquipo;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_serie, _marca, _modelo, _cliente, _telefono, _falla]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _vacio(TextEditingController c) => c.text.trim().isEmpty;

  Future<void> _buscarEquipo() async {
    final encontrado =
        await ref.read(recepcionViewModelProvider).buscarEquipo(_serie.text);
    if (!mounted) return;
    setState(() {
      if (encontrado == null) {
        _avisoEquipo = 'Es la primera vez que este equipo llega al taller.';
      } else {
        _tipo = encontrado.equipo.tipo;
        _marca.text = encontrado.equipo.marca;
        _modelo.text = encontrado.equipo.modelo;
        _cliente.text = encontrado.cliente.nombre;
        _telefono.text = encontrado.cliente.telefono;
        _avisoEquipo = 'Este equipo ya estuvo aquí: cargamos sus datos.';
      }
    });
  }

  Future<void> _buscarCliente() async {
    final cliente = await ref
        .read(recepcionViewModelProvider)
        .buscarCliente(_telefono.text);
    if (!mounted || cliente == null) return;
    setState(() => _cliente.text = cliente.nombre);
  }

  Future<void> _continuar() async {
    if (_paso == 0) {
      if (_vacio(_serie) || _vacio(_marca) || _vacio(_modelo)) {
        await mostrarError(
          context,
          'Escribe el número de serie, la marca y el modelo.',
        );
        return;
      }
      setState(() => _paso = 1);
    } else if (_paso == 1) {
      if (_vacio(_telefono) || _vacio(_cliente)) {
        await mostrarError(
            context, 'Escribe el teléfono y el nombre del dueño.');
        return;
      }
      setState(() => _paso = 2);
    } else {
      await _registrar();
    }
  }

  Future<void> _registrar() async {
    setState(() => _guardando = true);
    final resultado = await ref.read(recepcionViewModelProvider).registrar(
          tipo: _tipo,
          marca: _marca.text,
          modelo: _modelo.text,
          numeroSerie: _serie.text,
          nombreCliente: _cliente.text,
          telefono: _telefono.text,
          falla: _falla.text,
        );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (resultado.error != null) {
      await mostrarError(context, resultado.error!);
      return;
    }
    notificar(context, 'Se creó la orden #${resultado.ordenId}.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OrdenView(ordenId: resultado.ordenId!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activo = ref.watch(tecnicoActivoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir un equipo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              activo == null
                  ? 'Antes de registrar, elige en el panel quién usa la app.'
                  : 'Lo recibe ${activo.nombre}',
            ),
          ),
          Expanded(
            child: Stepper(
              currentStep: _paso,
              onStepTapped: (i) {
                if (i < _paso) setState(() => _paso = i);
              },
              onStepContinue: _guardando ? null : _continuar,
              onStepCancel:
                  _paso == 0 ? null : () => setState(() => _paso = _paso - 1),
              controlsBuilder: (context, detalles) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: detalles.onStepContinue,
                        child: Text(_paso == 2 ? 'Crear orden' : 'Siguiente'),
                      ),
                    ),
                    if (_paso > 0) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: detalles.onStepCancel,
                        child: const Text('Atrás'),
                      ),
                    ],
                  ],
                ),
              ),
              steps: [
                Step(
                  title: const Text('Equipo'),
                  subtitle:
                      _paso > 0 ? Text('${_marca.text} ${_modelo.text}') : null,
                  isActive: _paso >= 0,
                  state: _paso > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      TextField(
                        controller: _serie,
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _buscarEquipo(),
                        decoration: InputDecoration(
                          labelText: 'Número de serie',
                          suffixIcon: IconButton(
                            tooltip: '¿Ya estuvo en el taller?',
                            icon: const Icon(Icons.search_rounded),
                            onPressed: _buscarEquipo,
                          ),
                        ),
                      ),
                      if (_avisoEquipo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _avisoEquipo!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      DropdownMenu<TipoEquipo>(
                        key: ValueKey(_tipo),
                        initialSelection: _tipo,
                        label: const Text('Tipo de equipo'),
                        expandedInsets: EdgeInsets.zero,
                        onSelected: (tipo) {
                          if (tipo != null) setState(() => _tipo = tipo);
                        },
                        dropdownMenuEntries: [
                          for (final tipo in TipoEquipo.values)
                            DropdownMenuEntry(
                              value: tipo,
                              label: tipo.etiqueta,
                              leadingIcon: Icon(iconoEquipo(tipo)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _marca,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Marca'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _modelo,
                        decoration: const InputDecoration(labelText: 'Modelo'),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Dueño'),
                  subtitle: _paso > 1 ? Text(_cliente.text) : null,
                  isActive: _paso >= 1,
                  state: _paso > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      const SizedBox(height: 4),
                      TextField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => _buscarCliente(),
                        decoration:
                            const InputDecoration(labelText: 'Teléfono'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cliente,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre y apellidos',
                        ),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Falla'),
                  isActive: _paso >= 2,
                  content: Column(
                    children: [
                      const SizedBox(height: 4),
                      TextField(
                        controller: _falla,
                        minLines: 3,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: '¿Qué falla reporta el dueño?',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
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
