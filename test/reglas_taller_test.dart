import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_solution/core/regla_negocio.dart';
import 'package:tu_solution/data/database/app_database.dart';
import 'package:tu_solution/data/models/enums.dart';
import 'package:tu_solution/data/models/modelos.dart';
import 'package:tu_solution/data/repositories/clientes_repository.dart';
import 'package:tu_solution/data/repositories/inventario_repository.dart';
import 'package:tu_solution/data/repositories/ordenes_repository.dart';
import 'package:tu_solution/data/repositories/tecnicos_repository.dart';

/// Pruebas de las reglas del taller sobre una base de datos en memoria.
void main() {
  late AppDatabase db;
  late OrdenesRepository ordenes;
  late InventarioRepository inventario;
  late TecnicosRepository tecnicos;
  late ClientesRepository clientes;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ordenes = OrdenesRepository(db);
    inventario = InventarioRepository(db);
    tecnicos = TecnicosRepository(db);
    clientes = ClientesRepository(db);
  });

  tearDown(() => db.close());

  Future<int> recibir({
    String serie = 'SN-001',
    String telefono = '55512345',
    int tecnicoId = 1,
  }) {
    return ordenes.registrarRecepcion(
      tecnicoId: tecnicoId,
      tipo: TipoEquipo.celular,
      marca: 'Samsung',
      modelo: 'Galaxy A14',
      numeroSerie: serie,
      nombreCliente: 'Ana Pérez',
      telefono: telefono,
      falla: 'No enciende',
    );
  }

  test('el taller arranca con tres técnicos y repuestos en el almacén',
      () async {
    expect((await tecnicos.watchTecnicos().first).length, 3);
    expect((await inventario.watchRepuestos().first).isNotEmpty, true);
  });

  test('la recepción crea una orden en estado recibida y sin responsable',
      () async {
    final id = await recibir();
    final detalle = (await ordenes.obtenerDetalle(id))!;
    expect(detalle.orden.estado, EstadoOrden.recibida);
    expect(detalle.tecnico, isNull);
    expect(detalle.recibidoPor.id, 1);
    expect(detalle.equipo.numeroSerie, 'SN-001');
    expect(detalle.cliente.telefono, '55512345');
  });

  test('un equipo con una orden abierta no puede recibirse otra vez', () async {
    await recibir();
    await expectLater(recibir(), throwsA(isA<ReglaNegocio>()));
  });

  test('dos técnicos no pueden tomar la misma orden', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    await expectLater(
      ordenes.tomarOrden(id, 2),
      throwsA(isA<ReglaNegocio>()),
    );
    final detalle = (await ordenes.obtenerDetalle(id))!;
    expect(detalle.orden.estado, EstadoOrden.enReparacion);
    expect(detalle.tecnico!.id, 1);
  });

  test('solo el responsable puede anotar trabajos y repuestos', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    await expectLater(
      ordenes.agregarTrabajo(
        ordenId: id,
        tecnicoId: 2,
        descripcion: 'Cambio de pantalla',
        costo: 500,
      ),
      throwsA(isA<ReglaNegocio>()),
    );
    await expectLater(
      ordenes.usarRepuesto(
        ordenId: id,
        tecnicoId: 2,
        repuestoId: 1,
        cantidad: 1,
      ),
      throwsA(isA<ReglaNegocio>()),
    );
  });

  test('usar un repuesto baja las existencias y quitarlo las devuelve',
      () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    final antes = (await inventario.watchRepuestos().first)
        .firstWhere((r) => r.id == 1)
        .existencias;

    await ordenes.usarRepuesto(
      ordenId: id,
      tecnicoId: 1,
      repuestoId: 1,
      cantidad: 2,
    );
    var actual = (await inventario.watchRepuestos().first)
        .firstWhere((r) => r.id == 1)
        .existencias;
    expect(actual, antes - 2);

    final detalle = (await ordenes.obtenerDetalle(id))!;
    await ordenes.quitarRepuesto(detalle.repuestos.first.uso.id, 1);
    actual = (await inventario.watchRepuestos().first)
        .firstWhere((r) => r.id == 1)
        .existencias;
    expect(actual, antes);
  });

  test('no se puede usar más repuestos de los que hay en existencia', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    await expectLater(
      ordenes.usarRepuesto(
        ordenId: id,
        tecnicoId: 1,
        repuestoId: 1,
        cantidad: 999,
      ),
      throwsA(isA<ReglaNegocio>()),
    );
  });

  test('un repuesto se marca por agotarse al llegar a su mínimo', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    // Pantalla Samsung: 5 en existencia, mínimo 3.
    var pantalla =
        (await inventario.watchRepuestos().first).firstWhere((r) => r.id == 1);
    expect(pantalla.porAgotarse, false);
    await ordenes.usarRepuesto(
      ordenId: id,
      tecnicoId: 1,
      repuestoId: 1,
      cantidad: 2,
    );
    pantalla =
        (await inventario.watchRepuestos().first).firstWhere((r) => r.id == 1);
    expect(pantalla.porAgotarse, true);
  });

  test('el costo total es la mano de obra más los repuestos', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    await ordenes.agregarTrabajo(
      ordenId: id,
      tecnicoId: 1,
      descripcion: 'Cambio de pantalla',
      costo: 800,
    );
    await ordenes.agregarTrabajo(
      ordenId: id,
      tecnicoId: 1,
      descripcion: 'Limpieza interna',
      costo: 200,
    );
    await ordenes.usarRepuesto(
      ordenId: id,
      tecnicoId: 1,
      repuestoId: 1, // 4500 c/u
      cantidad: 1,
    );
    final detalle = (await ordenes.obtenerDetalle(id))!;
    expect(detalle.totalManoObra, 1000.0);
    expect(detalle.totalRepuestos, 4500.0);
    expect(detalle.total, 5500.0);
  });

  test('flujo completo: recibida, en reparación, lista y entregada', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);

    // Sin trabajos anotados no puede marcarse como lista.
    await expectLater(
      ordenes.marcarLista(id, 1),
      throwsA(isA<ReglaNegocio>()),
    );
    // Todavía no está lista: no puede entregarse.
    await expectLater(
      ordenes.entregarOrden(id),
      throwsA(isA<ReglaNegocio>()),
    );

    await ordenes.agregarTrabajo(
      ordenId: id,
      tecnicoId: 1,
      descripcion: 'Reparación de placa',
      costo: 1500,
    );
    await ordenes.marcarLista(id, 1);
    expect((await ordenes.obtenerDetalle(id))!.orden.estado, EstadoOrden.lista);

    await ordenes.entregarOrden(id);
    final detalle = (await ordenes.obtenerDetalle(id))!;
    expect(detalle.orden.estado, EstadoOrden.entregada);
    expect(detalle.orden.fechaCierre, isNotNull);

    // Una orden cerrada ya no admite cambios.
    await expectLater(
      ordenes.agregarTrabajo(
        ordenId: id,
        tecnicoId: 1,
        descripcion: 'Extra',
        costo: 1,
      ),
      throwsA(isA<ReglaNegocio>()),
    );
  });

  test('liberar una orden permite que otro técnico la tome', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    await ordenes.liberarOrden(id, 1);
    await ordenes.tomarOrden(id, 2);
    expect((await ordenes.obtenerDetalle(id))!.tecnico!.id, 2);
  });

  test('una orden puede quedar cancelada con su motivo', () async {
    final id = await recibir();
    await ordenes.tomarOrden(id, 1);
    // Otro técnico no puede cancelarla.
    await expectLater(
      ordenes.cancelarOrden(id, 2, 'No hay piezas'),
      throwsA(isA<ReglaNegocio>()),
    );
    await ordenes.cancelarOrden(id, 1, 'El cliente no aceptó el costo');
    final detalle = (await ordenes.obtenerDetalle(id))!;
    expect(detalle.orden.estado, EstadoOrden.cancelada);
    expect(detalle.orden.notaCierre, 'El cliente no aceptó el costo');
  });

  test('el equipo que vuelve conserva su historial y el del cliente', () async {
    final primera = await recibir();
    await ordenes.tomarOrden(primera, 1);
    await ordenes.agregarTrabajo(
      ordenId: primera,
      tecnicoId: 1,
      descripcion: 'Cambio de batería',
      costo: 300,
    );
    await ordenes.marcarLista(primera, 1);
    await ordenes.entregarOrden(primera);

    // El mismo equipo vuelve al taller.
    final segunda = await recibir();
    // El mismo dueño trae otro equipo.
    await recibir(serie: 'SN-002');

    final equipo = (await clientes.buscarEquipoPorSerie('sn-001'))!;
    final historialEquipo =
        await ordenes.watchHistorialEquipo(equipo.equipo.id).first;
    expect(historialEquipo.length, 2);
    expect(historialEquipo.first.orden.id, segunda);
    expect(
        historialEquipo.last.trabajos.first.descripcion, 'Cambio de batería');

    final historialCliente =
        await ordenes.watchHistorialCliente(equipo.cliente.id).first;
    expect(historialCliente.length, 3);

    final lista = await clientes.watchClientes().first;
    expect(lista.length, 1);
    expect(lista.first.equipos.length, 2);
  });

  test('el inventario no admite códigos repetidos ni existencias negativas',
      () async {
    await expectLater(
      inventario.guardarRepuesto(
        nombre: 'Otra pantalla',
        codigo: 'pan-sam-a14',
        precio: 10,
        existencias: 1,
        stockMinimo: 1,
      ),
      throwsA(isA<ReglaNegocio>()),
    );
    await expectLater(
      inventario.ajustarExistencias(1, -999),
      throwsA(isA<ReglaNegocio>()),
    );
    await inventario.ajustarExistencias(1, 10);
    final pantalla =
        (await inventario.watchRepuestos().first).firstWhere((r) => r.id == 1);
    expect(pantalla.existencias, 15);
  });

  test('se recuerda el técnico que está usando el teléfono', () async {
    expect(await tecnicos.watchTecnicoActivoId().first, isNull);
    await tecnicos.seleccionarTecnicoActivo(2);
    expect(await tecnicos.watchTecnicoActivoId().first, 2);
    await tecnicos.seleccionarTecnicoActivo(3);
    expect(await tecnicos.watchTecnicoActivoId().first, 3);
  });
}
