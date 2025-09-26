import 'package:get_it/get_it.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/datasources/excel_datasource.dart';
import 'package:kupon_bbm_app/data/validators/kupon_validator.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository_impl.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository_impl.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // Datasources
  getIt.registerLazySingleton<DatabaseDatasource>(() => DatabaseDatasource());

  // Repositories - harus didaftarkan sebelum validator karena digunakan oleh validator
  getIt.registerLazySingleton<KendaraanRepository>(
    () => KendaraanRepositoryImpl(getIt<DatabaseDatasource>()),
  );

  getIt.registerLazySingleton<KuponRepository>(
    () => KuponRepositoryImpl(getIt<DatabaseDatasource>()),
  );

  // Validators
  getIt.registerLazySingleton<KuponValidator>(
    () => KuponValidator(getIt<KendaraanRepository>()),
  );

  // Excel datasource - harus didaftarkan setelah validator
  getIt.registerLazySingleton<ExcelDatasource>(
    () => ExcelDatasource(getIt<KuponValidator>()),
  );
}
