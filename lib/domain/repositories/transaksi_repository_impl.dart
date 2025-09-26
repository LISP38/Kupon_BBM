import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kupon_bbm_app/domain/entities/transaksi_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository.dart';
import 'package:kupon_bbm_app/data/models/transaksi_model.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';

class TransaksiRepositoryImpl implements TransaksiRepository {
  final DatabaseDatasource dbHelper;

  TransaksiRepositoryImpl(this.dbHelper);

  @override
  Future<List<TransaksiEntity>> getAllTransaksi() async {
    final db = await dbHelper.database;
    final result = await db.query('fact_purchasing');
    return result.map((map) => TransaksiModel.fromMap(map)).toList();
  }

  @override
  Future<TransaksiEntity?> getTransaksiById(int transaksiId) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'fact_purchasing',
      where: 'purchasing_id = ?',
      whereArgs: [transaksiId],
    );
    if (result.isNotEmpty) {
      return TransaksiModel.fromMap(result.first);
    }
    return null;
  }

  @override
  Future<void> insertTransaksi(TransaksiEntity transaksi) async {
    final db = await dbHelper.database;
    await db.insert(
      'fact_purchasing',
      (transaksi as TransaksiModel).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateTransaksi(TransaksiEntity transaksi) async {
    final db = await dbHelper.database;
    await db.update(
      'fact_purchasing',
      (transaksi as TransaksiModel).toMap(),
      where: 'purchasing_id = ?',
      whereArgs: [transaksi.transaksiId],
    );
  }

  @override
  Future<void> deleteTransaksi(int transaksiId) async {
    final db = await dbHelper.database;
    await db.delete(
      'fact_purchasing',
      where: 'purchasing_id = ?',
      whereArgs: [transaksiId],
    );
  }
}
