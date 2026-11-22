import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/enums.dart';

Color colorEstado(EstadoOrden estado) => switch (estado) {
      EstadoOrden.recibida => const Color(0xFF5C6BC0),
      EstadoOrden.enReparacion => const Color(0xFFEF6C00),
      EstadoOrden.lista => const Color(0xFF2E7D32),
      EstadoOrden.entregada => const Color(0xFF00796B),
      EstadoOrden.cancelada => const Color(0xFFC62828),
    };

IconData iconoEquipo(TipoEquipo tipo) => switch (tipo) {
      TipoEquipo.celular => Icons.smartphone_rounded,
      TipoEquipo.tablet => Icons.tablet_rounded,
      TipoEquipo.laptop => Icons.laptop_mac_rounded,
    };

void abrir(BuildContext context, Widget pantalla) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
}

/// Pastilla con punto de color y nombre del estado.
class PastillaEstado extends StatelessWidget {
  const PastillaEstado(this.estado, {super.key});

  final EstadoOrden estado;

  @override
  Widget build(BuildContext context) {
    final color = colorEstado(estado);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          estado.etiqueta,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Tarjeta redondeada sin sombra usada en toda la app.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: color ?? Theme.of(context).colorScheme.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});

  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

void notificar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

Future<void> mostrarError(BuildContext context, String mensaje) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error_outline_rounded, size: 40),
      title: const Text('No se pudo completar'),
      content: Text(mensaje, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Espera una acción de un ViewModel: los errores se muestran en un
/// diálogo y el éxito en un aviso breve.
Future<bool> resolver(
  BuildContext context,
  Future<String?> accion, {
  String? exito,
}) async {
  final error = await accion;
  if (!context.mounted) return error == null;
  if (error != null) {
    await mostrarError(context, error);
  } else if (exito != null) {
    notificar(context, exito);
  }
  return error == null;
}

Future<bool> preguntar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String aceptar,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}

Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String inicial = '',
}) {
  final controlador = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: controlador,
        autofocus: true,
        decoration: InputDecoration(labelText: etiqueta),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controlador.text),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

extension VistaAsync<T> on AsyncValue<T> {
  Widget vista(Widget Function(T datos) constructor) => when(
        data: constructor,
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Center(child: Text('Error: $error')),
      );
}

class Vacio extends StatelessWidget {
  const Vacio(this.texto, {super.key, this.icono = Icons.inbox_rounded});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(texto, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
