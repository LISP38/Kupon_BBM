import 'package:get_it/get_it.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/datasources/excel_datasource.dart';
import 'package:kupon_bbm_app/data/validators/kupon_validator.dart';
import 'package:kupon_bbm_app/data/services/enhanced_import_service.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kendaraan_repository_impl.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository_impl.dart';
import 'package:kupon_bbm_app/domain/repositories/master_data_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/master_data_repository_impl.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository_impl.dart';
import 'package:kupon_bbm_app/presentation/providers/enhanced_import_provider.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  getIt.registerLazySingleton<TransaksiRepositoryImpl>(
    () => TransaksiRepositoryImpl(getIt<DatabaseDatasource>()),
  );
  // Datasources
  getIt.registerLazySingleton<DatabaseDatasource>(() => DatabaseDatasource());

  // Repositories - harus didaftarkan sebelum validator karena digunakan oleh validator
  getIt.registerLazySingleton<KendaraanRepository>(
    () => KendaraanRepositoryImpl(getIt<DatabaseDatasource>()),
  );

  getIt.registerLazySingleton<KuponRepository>(
    () => KuponRepositoryImpl(getIt<DatabaseDatasource>()),
  );

  getIt.registerLazySingleton<MasterDataRepository>(
    () => MasterDataRepositoryImpl(getIt<DatabaseDatasource>()),
  );

  // Validators
  getIt.registerLazySingleton<KuponValidator>(() => KuponValidator());

  // Excel datasource - harus didaftarkan setelah validator
  getIt.registerLazySingleton<ExcelDatasource>(
    () => ExcelDatasource(getIt<KuponValidator>(), getIt<DatabaseDatasource>()),
  );

  // Enhanced Import Service
  getIt.registerLazySingleton<EnhancedImportService>(
    () => EnhancedImportService(
      excelDatasource: getIt<ExcelDatasource>(),
      kuponRepository: getIt<KuponRepository>(),
      databaseDatasource: getIt<DatabaseDatasource>(),
    ),
  );

  // Enhanced Import Provider
  getIt.registerFactory<EnhancedImportProvider>(
    () => EnhancedImportProvider(getIt<EnhancedImportService>()),
  );
}