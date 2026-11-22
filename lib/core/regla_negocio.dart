/// Error controlado que representa una regla del taller que no se cumple.
/// Las vistas muestran [mensaje] directamente al técnico.
class ReglaNegocio implements Exception {
  const ReglaNegocio(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}
