import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/regla_negocio.dart';
import '../data/database/app_database.dart';
import '../data/repositories/clientes_repository.dart';
import '../data/repositories/inventario_repository.dart';
import '../data/repositories/ordenes_repository.dart';
import '../data/repositories/tecnicos_repository.dart';

/// Base de datos única de la app. En las pruebas se sobrescribe con una
/// base de datos en memoria.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final ordenesRepositoryProvider = Provider<OrdenesRepository>(
  (ref) => OrdenesRepository(ref.watch(databaseProvider)),
);

final inventarioRepositoryProvider = Provider<InventarioRepository>(
  (ref) => InventarioRepository(ref.watch(databaseProvider)),
);

final tecnicosRepositoryProvider = Provider<TecnicosRepository>(
  (ref) => TecnicosRepository(ref.watch(databaseProvider)),
);

final clientesRepositoryProvider = Provider<ClientesRepository>(
  (ref) => ClientesRepository(ref.watch(databaseProvider)),
);

/// Ejecuta una acción de un ViewModel y devuelve `null` si salió bien o el
/// mensaje que la vista debe mostrar si no se pudo completar.
Future<String?> ejecutarAccion(Future<void> Function() accion) async {
  try {
    await accion();
    return null;
  } on ReglaNegocio catch (e) {
    return e.mensaje;
  } catch (e) {
    return 'Ocurrió un error inesperado: $e';
  }
}
