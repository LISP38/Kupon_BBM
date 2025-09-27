import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class KuponRepositoryImpl implements KuponRepository {
  final DatabaseDatasource dbHelper;

  KuponRepositoryImpl(this.dbHelper);

  @override
  Future<List<KuponEntity>> getAllKupon() async {
    final db = await dbHelper.database;
    final result = await db.query(
      'fact_kupon',
      where: 'is_deleted = ?',
      whereArgs: [0],
    );
    return result.map((map) => KuponModel.fromMap(map)).toList();
  }

  @override
  Future<KuponEntity?> getKuponById(int kuponId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'fact_kupon',
      where: 'kupon_id = ?',
      whereArgs: [kuponId],
    );

    if (result.isNotEmpty) {
      return KuponModel.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<void> insertKupon(KuponEntity kupon) async {
    final db = await dbHelper.database;
    await db.insert(
      'fact_kupon',
      (kupon as KuponModel).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateKupon(KuponEntity kupon) async {
    final db = await dbHelper.database;
    await db.update(
      'fact_kupon',
      (kupon as KuponModel).toMap(),
      where: 'kupon_id = ?',
      whereArgs: [kupon.kuponId],
    );
  }

  @override
  Future<void> deleteKupon(int kuponId) async {
    final db = await dbHelper.database;
    await db.delete(
      'fact_kupon',
      where: 'kupon_id = ?',
      whereArgs: [kuponId],
    );
  }

  @override
  Future<KuponEntity?> getKuponByNomorKupon(String nomorKupon) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'fact_kupon',
      where: 'nomor_kupon = ? AND is_deleted = ?',
      whereArgs: [nomorKupon, 0],
    );
    if (result.isNotEmpty) {
      return KuponModel.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<void> deleteAllKupon() async {
    final db = await dbHelper.database;
    await db.delete('fact_kupon');
  }
}
