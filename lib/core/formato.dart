/// Utilidades de formato compartidas por las vistas.
String formatoDinero(double valor) => '\$${valor.toStringAsFixed(2)}';

String _dos(int n) => n.toString().padLeft(2, '0');

String formatoFecha(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

String formatoFechaHora(DateTime f) =>
    '${formatoFecha(f)} ${_dos(f.hour)}:${_dos(f.minute)}';

/// Convierte el texto de un campo numérico a double aceptando coma o punto.
double? leerDecimal(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));
