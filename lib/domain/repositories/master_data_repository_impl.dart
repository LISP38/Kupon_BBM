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
    // Query untuk mengambil satker yang memiliki kupon aktif dan KAPOLDA
    final result = await db.rawQuery('''
      SELECT DISTINCT ds.* 
      FROM dim_satker ds
      WHERE ds.satker_id = 1  -- KAPOLDA selalu ditampilkan
      UNION
      SELECT DISTINCT ds.* 
      FROM dim_satker ds
      INNER JOIN dim_kendaraan dk ON dk.satker_id = ds.satker_id
      INNER JOIN fact_kupon fk ON fk.kendaraan_id = dk.kendaraan_id
      WHERE ds.satker_id != 1  -- Exclude KAPOLDA karena sudah diambil di atas
        AND fk.status = 'Aktif' 
        AND fk.kuota_sisa > 0
        AND fk.is_deleted = 0
      ORDER BY nama_satker
    ''');
    print('DEBUG getAllSatker: Found ${result.length} satkers');
    for (var satker in result) {
      print('DEBUG satker: ${satker['satker_id']}, ${satker['nama_satker']}');
    }
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
