import 'package:kupon_bbm_app/domain/entities/satker_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/master_data_repository.dart';
import 'package:kupon_bbm_app/data/models/satker_model.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';

class MasterDataRepositoryImpl implements MasterDataRepository {
  final DatabaseDatasource dbHelper;

  MasterDataRepositoryImpl(this.dbHelper);

  @override
  Future<List<SatkerEntity>> getAllSatker() async {
    final db = await dbHelper.database;
    final result = await db.query('dim_satker');
    return result.map((map) => SatkerModel.fromMap(map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllJenisBBM() async {
    final db = await dbHelper.database;
    return await db.query('dim_jenis_bbm');
  }

  @override
  Future<List<Map<String, dynamic>>> getAllJenisKupon() async {
    final db = await dbHelper.database;
    return await db.query('dim_jenis_kupon');
  }
}
