/// Tipos de equipo que atiende el taller.
enum TipoEquipo {
  celular('Celular'),
  tablet('Tablet'),
  laptop('Laptop');

  const TipoEquipo(this.etiqueta);

  final String etiqueta;
}

/// Flujo de estados de una orden de reparación.
enum EstadoOrden {
  recibida('Recibida'),
  enReparacion('En reparación'),
  lista('Lista'),
  entregada('Entregada'),
  cancelada('Cancelada');

  const EstadoOrden(this.etiqueta);

  final String etiqueta;

  /// Una orden está abierta mientras el equipo sigue en el taller.
  bool get abierta => this == recibida || this == enReparacion || this == lista;

  static const List<EstadoOrden> abiertas = [recibida, enReparacion, lista];
}
