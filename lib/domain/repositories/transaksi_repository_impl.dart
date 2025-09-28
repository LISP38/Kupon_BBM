import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kupon_bbm_app/domain/entities/transaksi_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository.dart';
import 'package:kupon_bbm_app/data/models/transaksi_model.dart';
import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';

class TransaksiRepositoryImpl implements TransaksiRepository {
  final DatabaseDatasource dbHelper;

  TransaksiRepositoryImpl(this.dbHelper);

  @override
  Future<bool> createTransaksi({
    required int kuponId,
    required double jumlahLiter,
  }) async {
    final db = await dbHelper.database;

    try {
      // Start a transaction
      await db.transaction((txn) async {
        // 1. Get kupon info
        final kuponResult = await txn.query(
          'fact_kupon',
          where: 'kupon_id = ?',
          whereArgs: [kuponId],
        );

        if (kuponResult.isEmpty) {
          throw Exception('Kupon tidak ditemukan');
        }

        final kupon = kuponResult.first;
        final kuotaSisa = (kupon['kuota_sisa'] as num).toDouble();

        if (kuotaSisa < jumlahLiter) {
          throw Exception('Jumlah liter melebihi sisa kuota');
        }

        // 2. Create new transaction
        final now = DateTime.now().toIso8601String();
        await txn.insert('fact_transaksi', {
          'kupon_id': kuponId,
          'jumlah_liter': jumlahLiter,
          'tanggal_transaksi': now,
          'created_at': now,
          'updated_at': now,
          'is_deleted': 0,
        });

        // 3. Update kupon's remaining quota
        await txn.update(
          'fact_kupon',
          {
            'kuota_sisa': kuotaSisa - jumlahLiter,
            'updated_at': now,
            'status': kuotaSisa - jumlahLiter > 0 ? 'Aktif' : 'Habis',
          },
          where: 'kupon_id = ?',
          whereArgs: [kuponId],
        );
      });

      return true;
    } catch (e) {
      print('Error creating transaction: $e');
      return false;
    }
  }

  @override
  Future<List<TransaksiEntity>> getAllTransaksi({
    int? bulan,
    int? tahun,
    int? hari,
    String? nomorKupon,
    String? satker,
    int? jenisBbmId,
  }) async {
    final db = await dbHelper.database;
    String where = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    if (bulan != null) {
      where += ' AND strftime("%m", tanggal_transaksi) = ?';
      whereArgs.add(bulan.toString().padLeft(2, '0'));
    }
    if (tahun != null) {
      where += ' AND strftime("%Y", tanggal_transaksi) = ?';
      whereArgs.add(tahun.toString());
    }
    if (hari != null) {
      where += ' AND strftime("%d", tanggal_transaksi) = ?';
      whereArgs.add(hari.toString().padLeft(2, '0'));
    }
    if (nomorKupon != null && nomorKupon.isNotEmpty) {
      where += ' AND nomor_kupon LIKE ?';
      whereArgs.add('%$nomorKupon%');
    }
    if (satker != null && satker.isNotEmpty) {
      where += ' AND nama_satker LIKE ?';
      whereArgs.add('%$satker%');
    }
    if (jenisBbmId != null) {
      where += ' AND jenis_bbm_id = ?';
      whereArgs.add(jenisBbmId);
    }
    final result = await db.query(
      'fact_purchasing',
      where: where,
      whereArgs: whereArgs,
    );
    return result.map((map) => TransaksiModel.fromMap(map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getKuponMinus() async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT * FROM fact_kupon WHERE kuota_sisa < 0',
    );
    return result;
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
    // Update kuota_sisa di fact_kupon
    await db.rawUpdate(
      'UPDATE fact_kupon SET kuota_sisa = kuota_sisa - ? WHERE kupon_id = ?',
      [transaksi.jumlahDiambil, transaksi.kuponId],
    );
    Future<List<Map<String, dynamic>>> getKuponMinus() async {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT * FROM fact_kupon WHERE kuota_sisa < 0',
      );
      return result;
    }
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
