// Pruebas de las utilidades de formato que usan las vistas.
// Las reglas del taller se prueban en reglas_taller_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_solution/core/formato.dart';
import 'package:tu_solution/data/models/enums.dart';

void main() {
  test('el dinero se muestra con dos decimales', () {
    expect(formatoDinero(1250), '\$1250.00');
    expect(formatoDinero(99.5), '\$99.50');
  });

  test('los costos aceptan coma o punto decimal', () {
    expect(leerDecimal('12,5'), 12.5);
    expect(leerDecimal(' 300 '), 300.0);
    expect(leerDecimal('abc'), isNull);
  });

  test('las fechas se muestran como día/mes/año', () {
    expect(formatoFecha(DateTime(2026, 11, 5)), '05/11/2026');
    expect(formatoFechaHora(DateTime(2026, 11, 5, 9, 7)), '05/11/2026 09:07');
  });

  test('una orden está abierta hasta que se entrega o se cancela', () {
    expect(EstadoOrden.recibida.abierta, true);
    expect(EstadoOrden.enReparacion.abierta, true);
    expect(EstadoOrden.lista.abierta, true);
    expect(EstadoOrden.entregada.abierta, false);
    expect(EstadoOrden.cancelada.abierta, false);
  });
}
