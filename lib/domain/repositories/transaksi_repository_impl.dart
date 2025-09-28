import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/models/transaksi_model.dart';
import 'package:kupon_bbm_app/domain/entities/transaksi_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository.dart';

class TransaksiRepositoryImpl implements TransaksiRepository {
  final DatabaseDatasource dbHelper;

  TransaksiRepositoryImpl(this.dbHelper);

  @override
  Future<List<TransaksiEntity>> getAllTransaksi({
    int? bulan,
    int? tahun,
    int? hari,
    String? nomorKupon,
    String? satker,
    int? jenisBbmId,
    int? isDeleted,
  }) async {
    final db = await dbHelper.database;

    String where = 't.is_deleted = ?';
    List<dynamic> whereArgs = [isDeleted ?? 0];

    if (bulan != null) {
      where += ' AND strftime("%m", t.tanggal_transaksi) = ?';
      whereArgs.add(bulan.toString().padLeft(2, '0'));
    }
    if (tahun != null) {
      where += ' AND strftime("%Y", t.tanggal_transaksi) = ?';
      whereArgs.add(tahun.toString());
    }
    if (hari != null) {
      where += ' AND strftime("%d", t.tanggal_transaksi) = ?';
      whereArgs.add(hari.toString().padLeft(2, '0'));
    }
    if (nomorKupon != null && nomorKupon.isNotEmpty) {
      where += ' AND t.nomor_kupon LIKE ?';
      whereArgs.add('%$nomorKupon%');
    }
    if (satker != null && satker.isNotEmpty) {
      where += ' AND t.nama_satker LIKE ?';
      whereArgs.add('%$satker%');
    }
    if (jenisBbmId != null) {
      where += ' AND t.jenis_bbm_id = ?';
      whereArgs.add(jenisBbmId);
    }

    final result = await db.rawQuery('''
      SELECT 
        t.*,
        k.nomor_kupon as kupon_nomor,
        k.nama_satker as kupon_satker,
        k.jenis_bbm_id as kupon_jenis_bbm,
        date(substr(k.created_at, 1, 4) || '-' || substr(k.created_at, 6, 2) || '-01') as kupon_created_at,
        date(date(substr(k.created_at, 1, 4) || '-' || substr(k.created_at, 6, 2) || '-01'), '+2 months', '-1 day') as kupon_expired_at
      FROM fact_transaksi t
      JOIN fact_kupon k ON t.kupon_id = k.kupon_id
      WHERE $where AND k.is_deleted = 0
      ORDER BY t.created_at DESC
    ''', whereArgs);

    return result.map((map) => TransaksiModel.fromMap(map)).toList();
  }

  @override
  Future<TransaksiEntity?> getTransaksiById(int transaksiId) async {
    final db = await dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT t.*, k.nomor_kupon, k.nama_satker, k.jenis_bbm_id
      FROM fact_transaksi t
      JOIN fact_kupon k ON t.kupon_id = k.kupon_id
      WHERE t.transaksi_id = ? AND t.is_deleted = 0
    ''',
      [transaksiId],
    );

    if (result.isEmpty) {
      return null;
    }

    return TransaksiModel.fromMap(result.first);
  }

  @override
  Future<void> insertTransaksi(TransaksiEntity transaksi) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. Get kupon info
      final kuponResult = await txn.query(
        'fact_kupon',
        where: 'kupon_id = ?',
        whereArgs: [transaksi.kuponId],
      );

      if (kuponResult.isEmpty) {
        throw Exception('Kupon tidak ditemukan');
      }

      final kupon = kuponResult.first;
      final kuotaSisa = (kupon['kuota_sisa'] as num).toDouble();

      if (kuotaSisa < transaksi.jumlahLiter) {
        throw Exception('Jumlah liter melebihi sisa kuota');
      }

      // 2. Insert new transaction
      await txn.insert('fact_transaksi', {
        'kupon_id': transaksi.kuponId,
        'nomor_kupon': transaksi.nomorKupon,
        'nama_satker': transaksi.namaSatker,
        'jenis_bbm_id': transaksi.jenisBbmId,
        'jumlah_liter': transaksi.jumlahLiter,
        'tanggal_transaksi': transaksi.tanggalTransaksi,
        'created_at': transaksi.createdAt,
        'updated_at': transaksi.createdAt,
        'is_deleted': 0,
      });

      // 3. Update kupon sisa
      final newKuotaSisa = kuotaSisa - transaksi.jumlahLiter;
      await txn.update(
        'fact_kupon',
        {
          'kuota_sisa': newKuotaSisa,
          'status': newKuotaSisa > 0 ? 'Aktif' : 'Habis',
          'updated_at': transaksi.createdAt,
        },
        where: 'kupon_id = ?',
        whereArgs: [transaksi.kuponId],
      );
    });
  }

  @override
  Future<void> updateTransaksi(TransaksiEntity transaksi) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. Get old transaction
      final oldTransaksi = await txn.query(
        'fact_transaksi',
        where: 'transaksi_id = ? AND is_deleted = 0',
        whereArgs: [transaksi.transaksiId],
      );

      if (oldTransaksi.isEmpty) {
        throw Exception('Transaksi tidak ditemukan');
      }

      final oldJumlahLiter = (oldTransaksi.first['jumlah_liter'] as num)
          .toDouble();

      // 2. Get kupon info
      final kuponResult = await txn.query(
        'fact_kupon',
        where: 'kupon_id = ?',
        whereArgs: [transaksi.kuponId],
      );

      if (kuponResult.isEmpty) {
        throw Exception('Kupon tidak ditemukan');
      }

      final kupon = kuponResult.first;
      final currentKuotaSisa = (kupon['kuota_sisa'] as num).toDouble();

      // Add back the old amount and check if new amount can be deducted
      final availableKuota = currentKuotaSisa + oldJumlahLiter;
      if (availableKuota < transaksi.jumlahLiter) {
        throw Exception('Jumlah liter melebihi sisa kuota');
      }

      // 3. Update transaction
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'fact_transaksi',
        {
          'jumlah_liter': transaksi.jumlahLiter,
          'tanggal_transaksi': transaksi.tanggalTransaksi,
          'updated_at': now,
        },
        where: 'transaksi_id = ?',
        whereArgs: [transaksi.transaksiId],
      );

      // 4. Update kupon sisa
      final newKuotaSisa = availableKuota - transaksi.jumlahLiter;
      await txn.update(
        'fact_kupon',
        {
          'kuota_sisa': newKuotaSisa,
          'status': newKuotaSisa > 0 ? 'Aktif' : 'Habis',
          'updated_at': now,
        },
        where: 'kupon_id = ?',
        whereArgs: [transaksi.kuponId],
      );
    });
  }

  @override
  Future<void> deleteTransaksi(int transaksiId) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. Get transaction info
      final transaksiResult = await txn.query(
        'fact_transaksi',
        where: 'transaksi_id = ? AND is_deleted = 0',
        whereArgs: [transaksiId],
      );

      if (transaksiResult.isEmpty) {
        throw Exception('Transaksi tidak ditemukan');
      }

      final transaksi = transaksiResult.first;
      final jumlahLiter = (transaksi['jumlah_liter'] as num).toDouble();
      final kuponId = transaksi['kupon_id'] as int;

      // 2. Get kupon info
      final kuponResult = await txn.query(
        'fact_kupon',
        where: 'kupon_id = ?',
        whereArgs: [kuponId],
      );

      if (kuponResult.isEmpty) {
        throw Exception('Kupon tidak ditemukan');
      }

      final kupon = kuponResult.first;
      final currentKuotaSisa = (kupon['kuota_sisa'] as num).toDouble();

      // 3. Soft delete transaction
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'fact_transaksi',
        {'is_deleted': 1, 'updated_at': now},
        where: 'transaksi_id = ?',
        whereArgs: [transaksiId],
      );

      // 4. Update kupon sisa
      final newKuotaSisa = currentKuotaSisa + jumlahLiter;
      await txn.update(
        'fact_kupon',
        {
          'kuota_sisa': newKuotaSisa,
          'status': newKuotaSisa > 0 ? 'Aktif' : 'Habis',
          'updated_at': now,
        },
        where: 'kupon_id = ?',
        whereArgs: [kuponId],
      );
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getKuponMinus() async {
    final db = await dbHelper.database;

    return await db.rawQuery('''
      SELECT k.kupon_id, k.nomor_kupon, k.kuota_awal, k.kuota_sisa,
      (SELECT SUM(t.jumlah_liter)
       FROM fact_transaksi t
       WHERE t.kupon_id = k.kupon_id AND t.is_deleted = 0) as total_diambil
      FROM fact_kupon k
      WHERE k.kuota_sisa < 0
    ''');
  }

  Future<void> restoreTransaksi(int transaksiId) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      // 1. Get transaction info
      final transaksiResult = await txn.query(
        'fact_transaksi',
        where: 'transaksi_id = ? AND is_deleted = 1',
        whereArgs: [transaksiId],
      );

      if (transaksiResult.isEmpty) {
        throw Exception('Transaksi tidak ditemukan');
      }

      final transaksi = transaksiResult.first;
      final jumlahLiter = (transaksi['jumlah_liter'] as num).toDouble();
      final kuponId = transaksi['kupon_id'] as int;

      // 2. Get kupon info
      final kuponResult = await txn.query(
        'fact_kupon',
        where: 'kupon_id = ?',
        whereArgs: [kuponId],
      );

      if (kuponResult.isEmpty) {
        throw Exception('Kupon tidak ditemukan');
      }

      final kupon = kuponResult.first;
      final currentKuotaSisa = (kupon['kuota_sisa'] as num).toDouble();

      // 3. Restore transaction
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'fact_transaksi',
        {'is_deleted': 0, 'updated_at': now},
        where: 'transaksi_id = ?',
        whereArgs: [transaksiId],
      );

      // 4. Update kupon sisa
      final newKuotaSisa = currentKuotaSisa - jumlahLiter;
      await txn.update(
        'fact_kupon',
        {
          'kuota_sisa': newKuotaSisa,
          'status': newKuotaSisa > 0 ? 'Aktif' : 'Habis',
          'updated_at': now,
        },
        where: 'kupon_id = ?',
        whereArgs: [kuponId],
      );
    });
  }
}
