import 'package:kupon_bbm_app/data/datasources/database_datasource.dart';
import 'package:kupon_bbm_app/data/models/transaksi_model.dart';
import 'package:kupon_bbm_app/domain/entities/transaksi_entity.dart';
import 'package:kupon_bbm_app/domain/repositories/transaksi_repository.dart';
// sqflite import not required here; Database access via DatabaseDatasource

class TransaksiRepositoryImpl implements TransaksiRepository {
  final DatabaseDatasource dbHelper;

  TransaksiRepositoryImpl(this.dbHelper);

  @override
  Future<List<TransaksiEntity>> getAllTransaksi({
    int? bulan,
    int? tahun,
    int? isDeleted,
  }) async {
    try {
      final db = await dbHelper.database;

      // Filtering by month/year can be implemented by joining dim_date if needed

      // Prefer new star-schema fact_purchasing and dim_kupon; alias fields to match TransaksiModel.fromMap
      List<Map<String, dynamic>> result;
      try {
        print('DEBUG getAllTransaksi: Trying star-schema query (fact_purchasing)...');
        result = await db.rawQuery('''
          SELECT
            fp.purchasing_key as transaksi_id,
            COALESCE(
              (SELECT fk.kupon_id FROM fact_kupon fk WHERE fk.nomor_kupon = d.nomor_kupon LIMIT 1),
              fp.kupon_key
            ) as kupon_id,
            d.nomor_kupon as kupon_nomor,
            COALESCE(s.nama_satker, 'CADANGAN') as kupon_satker,
            fp.jenis_bbm_key as jenis_bbm_id,
            COALESCE(fp.jenis_kupon_key, (SELECT fk.jenis_kupon_id FROM fact_kupon fk WHERE fk.nomor_kupon = d.nomor_kupon LIMIT 1), 1) as jenis_kupon_id,
            dd.date_value as tanggal_transaksi,
            fp.jumlah_diambil as jumlah_liter,
            dd.date_value as created_at,
            dd.date_value as updated_at,
            0 as is_deleted,
            'Aktif' as status,
            COALESCE(d.tanggal_mulai, '') as kupon_created_at,
            COALESCE(d.tanggal_sampai, '') as kupon_expired_at
          FROM fact_purchasing fp
          LEFT JOIN dim_kupon d ON fp.kupon_key = d.kupon_key
          LEFT JOIN dim_date dd ON fp.date_key = dd.date_key
          LEFT JOIN dim_satker s ON fp.satker_key = s.satker_id
          WHERE 1=1
          ORDER BY dd.date_value DESC
        ''');
        print('DEBUG getAllTransaksi: Star-schema query returned ${result.length} rows');
      } catch (e) {
        print('DEBUG getAllTransaksi: Star-schema query failed: $e, falling back to legacy tables');
        // Fallback to legacy tables if new star-schema tables are not available
        result = await db.rawQuery('''
          SELECT 
            t.transaksi_id,
            t.kupon_id,
            t.nomor_kupon,
            t.nama_satker,
            t.jenis_bbm_id,
            t.tanggal_transaksi,
            t.jumlah_liter,
            t.created_at,
            t.updated_at,
            t.is_deleted,
            t.status,
            COALESCE(k.tanggal_mulai, '') as kupon_created_at,
            COALESCE(k.tanggal_sampai, '') as kupon_expired_at
          FROM fact_transaksi t
          LEFT JOIN fact_kupon k ON t.kupon_id = k.kupon_id
          WHERE t.is_deleted = 0
          ORDER BY t.tanggal_transaksi DESC, t.created_at DESC
        ''');
        print('DEBUG getAllTransaksi: Fallback query returned ${result.length} rows');
      }

      return result.map((map) => TransaksiModel.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to get all transaksi: $e');
    }
  }

  @override
  Future<TransaksiEntity?> getTransaksiById(int transaksiId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT
          fp.purchasing_key as transaksi_id,
          COALESCE(
            (SELECT fk.kupon_id FROM fact_kupon fk WHERE fk.nomor_kupon = d.nomor_kupon LIMIT 1),
            fp.kupon_key
          ) as kupon_id,
          d.nomor_kupon as kupon_nomor,
          s.nama_satker as kupon_satker,
          fp.jenis_bbm_key as jenis_bbm_id,
          COALESCE(fp.jenis_kupon_key, (SELECT fk.jenis_kupon_id FROM fact_kupon fk WHERE fk.nomor_kupon = d.nomor_kupon LIMIT 1), 1) as jenis_kupon_id,
          dd.date_value as tanggal_transaksi,
          fp.jumlah_diambil as jumlah_liter,
          dd.date_value as created_at,
          dd.date_value as updated_at,
          0 as is_deleted,
          '' as status,
          d.tanggal_mulai as kupon_created_at,
          d.tanggal_sampai as kupon_expired_at
        FROM fact_purchasing fp
        LEFT JOIN dim_kupon d ON fp.kupon_key = d.kupon_key
        LEFT JOIN dim_date dd ON fp.date_key = dd.date_key
        LEFT JOIN dim_satker s ON fp.satker_key = s.satker_id
        WHERE fp.purchasing_key = ?
      ''',
        [transaksiId],
      );

      if (result.isEmpty) {
        return null;
      }

      return TransaksiModel.fromMap(result.first);
    } catch (e) {
      throw Exception('Failed to get transaksi by id: $e');
    }
  }

  @override
  Future<void> insertTransaksi(TransaksiEntity transaksi) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        // Map incoming transaksi into star-schema keys
        final t = transaksi as TransaksiModel;

        print('DEBUG insertTransaksi: Starting with kupon_id=${t.kuponId}, nomor_kupon=${t.nomorKupon}, jenis_kupon_id=${t.jenisKuponId}, jumlah=${t.jumlahLiter}');

        // 1) Ensure dim_kupon exists and get kupon_key. If dim_kupon table doesn't exist (older DB), fall back to fact_kupon.
        int? kuponKey;
        try {
          final kuponRow = await txn.query(
            'dim_kupon',
            where: 'nomor_kupon = ?',
            whereArgs: [t.nomorKupon],
            limit: 1,
          );
          if (kuponRow.isNotEmpty) {
            kuponKey = kuponRow.first['kupon_key'] as int;
            print('DEBUG: Found kupon in dim_kupon with key: $kuponKey');
          } else {
            kuponKey = await txn.insert('dim_kupon', {
              'nomor_kupon': t.nomorKupon,
              'status': 'Aktif',
            });
            print('DEBUG: Created new kupon in dim_kupon with key: $kuponKey');
          }
        } catch (e) {
          print('DEBUG: dim_kupon not present or error: $e, trying legacy fact_kupon');
          // dim_kupon not present: try legacy fact_kupon
          final legacy = await txn.query(
            'fact_kupon',
            where: 'nomor_kupon = ?',
            whereArgs: [t.nomorKupon],
            limit: 1,
          );
          if (legacy.isNotEmpty) {
            kuponKey = legacy.first['kupon_id'] as int;
            print('DEBUG: Found kupon in fact_kupon with ID: $kuponKey');
          } else {
            kuponKey = null;
            print('WARNING: Kupon ${t.nomorKupon} not found in either table!');
          }
        }

        // 2) Ensure dim_date exists and get date_key (store only date part). Fallback to null if dim_date missing.
        final dateValue = t.tanggalTransaksi.split('T').first;
        int? dateKey;
        try {
          final dateRow = await txn.query(
            'dim_date',
            where: 'date_value = ?',
            whereArgs: [dateValue],
            limit: 1,
          );
          if (dateRow.isNotEmpty) {
            dateKey = dateRow.first['date_key'] as int;
            print('DEBUG: Found date in dim_date with key: $dateKey');
          } else {
            final dt = DateTime.parse(t.tanggalTransaksi);
            dateKey = await txn.insert('dim_date', {
              'date_value': dateValue,
              'year': dt.year,
              'month': dt.month,
              'day': dt.day,
              'week_of_year': ((dt.day - 1) / 7).floor() + 1,
              'quarter': ((dt.month - 1) / 3).floor() + 1,
            });
            print('DEBUG: Created new date in dim_date with key: $dateKey');
          }
        } catch (e) {
          print('DEBUG: dim_date not present or error: $e');
          dateKey = null;
        }

        // 3) Determine other keys: Find satker_key from dim_satker
        int? satkerKey;
        try {
          final satkerRows = await txn.query(
            'dim_satker',
            where: 'UPPER(TRIM(nama_satker)) = ?',
            whereArgs: [t.namaSatker.toUpperCase().trim()],
            limit: 1,
          );
          if (satkerRows.isNotEmpty) {
            satkerKey = satkerRows.first['satker_id'] as int;
            print('DEBUG: Found satker in dim_satker: ${t.namaSatker} -> key=$satkerKey');
          } else {
            // Satker tidak ada, coba INSERT baru
            satkerKey = await txn.insert('dim_satker', {
              'nama_satker': t.namaSatker,
            });
            print('DEBUG: Created new satker in dim_satker: ${t.namaSatker} -> key=$satkerKey');
          }
        } catch (e) {
          print('DEBUG: Error finding satker: $e, using NULL');
          satkerKey = null;
        }

        // 4) Insert into fact_purchasing if table exists, otherwise fallback to legacy fact_transaksi
        final tableCheck = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='fact_purchasing' LIMIT 1;",
        );
        print('DEBUG: Table check result: ${tableCheck.isNotEmpty ? "fact_purchasing exists" : "fact_purchasing NOT found"}');
        
        if (tableCheck.isNotEmpty && kuponKey != null && dateKey != null) {
          print('DEBUG: Inserting into fact_purchasing with kupon_key=$kuponKey, date_key=$dateKey, satker_key=$satkerKey, jenis_bbm_key=${t.jenisBbmId}, jumlah=${t.jumlahLiter}');
          try {
            final purchasingId = await txn.insert('fact_purchasing', {
              'kupon_key': kuponKey,
              'kendaraan_key': null,
              'satker_key': satkerKey,
              'jenis_bbm_key': t.jenisBbmId,
              'jenis_kupon_key': t.jenisKuponId ?? 1,
              'date_key': dateKey,
              'jumlah_diambil': t.jumlahLiter,
            });
            print('DEBUG: Successfully inserted into fact_purchasing with purchasing_key=$purchasingId');
            
            // PENTING: Update fact_kupon kuota_sisa HANYA untuk kupon_id yang benar (bukan nomor_kupon)
            print('DEBUG: Updating fact_kupon kuota_sisa for kupon_id=${t.kuponId}');
            final updateResult = await txn.rawUpdate(
              'UPDATE fact_kupon SET kuota_sisa = kuota_sisa - ? WHERE kupon_id = ?',
              [t.jumlahLiter, t.kuponId],
            );
            print('DEBUG: Updated $updateResult rows in fact_kupon for kuota tracking');
            
            // Also update fact_kupon jenis_kupon_id if not already set - gunakan kupon_id yang spesifik
            await txn.rawUpdate(
              'UPDATE fact_kupon SET jenis_kupon_id = ? WHERE kupon_id = ? AND (jenis_kupon_id IS NULL OR jenis_kupon_id = 0)',
              [t.jenisKuponId ?? 1, t.kuponId],
            );
          } catch (e) {
            print('ERROR inserting into fact_purchasing: $e');
            rethrow;
          }
        } else {
          print('DEBUG: Falling back to fact_transaksi (legacy schema)');
          // Fallback: older DB layout — insert into fact_transaksi for compatibility
          final map = t.toMap();
          map.remove('transaksi_id');
          print('DEBUG: Inserting into fact_transaksi with data: $map');
          try {
            await txn.insert('fact_transaksi', map);
            print('DEBUG: Successfully inserted into fact_transaksi');

            // For legacy schema, UPDATE fact_kupon kuota_sisa menggunakan kupon_id yang spesifik
            print('DEBUG: Updating fact_kupon kuota_sisa for kupon_id=${t.kuponId}');
            final updateResult = await txn.rawUpdate(
              'UPDATE fact_kupon SET kuota_sisa = kuota_sisa - ?, updated_at = DATETIME(\'now\', \'localtime\') WHERE kupon_id = ?',
              [t.jumlahLiter, t.kuponId],
            );
            print('DEBUG: Updated $updateResult rows in fact_kupon (kupon_id=${t.kuponId})');
          } catch (e) {
            print('ERROR inserting into fact_transaksi: $e');
            rethrow;
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to insert transaksi: $e');
    }
  }

  @override
  Future<void> updateTransaksi(TransaksiEntity transaksi) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        // Try star-schema first (fact_purchasing)
        var purchasing = await txn.query(
          'fact_purchasing',
          where: 'purchasing_key = ?',
          whereArgs: [transaksi.transaksiId],
        );

        if (purchasing.isNotEmpty) {
          // Star-schema update
          print('DEBUG: Updating fact_purchasing with purchasing_key=${transaksi.transaksiId}');
          
          final oldJumlahLiter = (purchasing.first['jumlah_diambil'] as num).toDouble();
          final newJumlahLiter = transaksi.jumlahLiter;
          final selisihLiter = newJumlahLiter - oldJumlahLiter;
          final kuponKey = purchasing.first['kupon_key'] as int;

          // Update fact_purchasing
          await txn.update(
            'fact_purchasing',
            {'jumlah_diambil': transaksi.jumlahLiter},
            where: 'purchasing_key = ?',
            whereArgs: [transaksi.transaksiId],
          );
          print('DEBUG: Updated fact_purchasing');

          // Get nomor_kupon from dim_kupon to update fact_kupon
          final kuponData = await txn.query(
            'dim_kupon',
            where: 'kupon_key = ?',
            whereArgs: [kuponKey],
            columns: ['nomor_kupon'],
          );

          if (kuponData.isNotEmpty) {
            final nomorKupon = kuponData.first['nomor_kupon'] as String;
            
            // Update kuota_sisa in fact_kupon (sub-select to avoid updating duplicates)
            await txn.rawUpdate(
              '''
              UPDATE fact_kupon 
              SET kuota_sisa = kuota_sisa - ?
              WHERE kupon_id = (
                SELECT kupon_id FROM fact_kupon WHERE nomor_kupon = ? LIMIT 1
              )
            ''',
              [selisihLiter, nomorKupon],
            );
            print('DEBUG: Updated kuota for nomor_kupon=$nomorKupon with selisih=$selisihLiter');
          }
          return;
        }

        // Fallback to legacy schema (fact_transaksi)
        final oldTransaksi = await txn.query(
          'fact_transaksi',
          where: 'transaksi_id = ?',
          whereArgs: [transaksi.transaksiId],
        );

        if (oldTransaksi.isEmpty) {
          throw Exception('Transaksi not found');
        }

        final oldJumlahLiter = (oldTransaksi.first['jumlah_liter'] as num)
            .toDouble();
        final newJumlahLiter = transaksi.jumlahLiter;
        final selisihLiter = newJumlahLiter - oldJumlahLiter;

        // Update transaksi
        await txn.update(
          'fact_transaksi',
          (transaksi as TransaksiModel).toMap(),
          where: 'transaksi_id = ?',
          whereArgs: [transaksi.transaksiId],
        );

        // Update kuota_sisa in fact_kupon
        await txn.rawUpdate(
          '''
          UPDATE fact_kupon 
          SET kuota_sisa = kuota_sisa - ?
          WHERE kupon_id = ?
        ''',
          [selisihLiter, transaksi.kuponId],
        );
      });
    } catch (e) {
      throw Exception('Failed to update transaksi: $e');
    }
  }
  Future<void> softDeleteTransaksi(int transaksiId) async {
    await _hardDeleteOrRestore(transaksiId, isDelete: true);
  }

  @override
  Future<void> deleteTransaksi(int transaksiId) async {
    await _hardDeleteOrRestore(transaksiId, isDelete: true);
  }

  Future<void> _hardDeleteOrRestore(
    int transaksiId, {
    required bool isDelete,
  }) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        // Try star-schema first (fact_purchasing)
        var purchasing = await txn.query(
          'fact_purchasing',
          where: 'purchasing_key = ?',
          whereArgs: [transaksiId],
        );

        if (purchasing.isNotEmpty) {
          // Star-schema delete
          print('DEBUG: Deleting from fact_purchasing with purchasing_key=$transaksiId');
          final jumlahLiter = purchasing.first['jumlah_diambil'] as double;
          final kuponKey = purchasing.first['kupon_key'] as int;

          if (isDelete) {
            // Delete from fact_purchasing
            await txn.delete(
              'fact_purchasing',
              where: 'purchasing_key = ?',
              whereArgs: [transaksiId],
            );
            print('DEBUG: Deleted from fact_purchasing');

            // Get nomor_kupon from dim_kupon to update fact_kupon
            final kuponData = await txn.query(
              'dim_kupon',
              where: 'kupon_key = ?',
              whereArgs: [kuponKey],
              columns: ['nomor_kupon'],
            );

            if (kuponData.isNotEmpty) {
              final nomorKupon = kuponData.first['nomor_kupon'] as String;
              
              // Return kuota to fact_kupon (sub-select to avoid updating duplicates)
              await txn.rawUpdate(
                '''
                UPDATE fact_kupon 
                SET kuota_sisa = kuota_sisa + ?
                WHERE kupon_id = (
                  SELECT kupon_id FROM fact_kupon WHERE nomor_kupon = ? LIMIT 1
                )
              ''',
                [jumlahLiter, nomorKupon],
              );
              print('DEBUG: Restored kuota for nomor_kupon=$nomorKupon');
            }
          }
          return;
        }

        // Fallback to legacy schema (fact_transaksi)
        final transaksi = await txn.query(
          'fact_transaksi',
          where: 'transaksi_id = ?',
          whereArgs: [transaksiId],
        );

        if (transaksi.isEmpty) {
          throw Exception('Transaksi not found');
        }

        final jumlahLiter = transaksi.first['jumlah_liter'] as double;
        final kuponId = transaksi.first['kupon_id'] as int;

        if (isDelete) {
          // Delete transaksi
          await txn.delete(
            'fact_transaksi',
            where: 'transaksi_id = ?',
            whereArgs: [transaksiId],
          );

          // Return kuota to fact_kupon
          await txn.rawUpdate(
            '''
            UPDATE fact_kupon 
            SET kuota_sisa = kuota_sisa + ?
            WHERE kupon_id = ?
          ''',
            [jumlahLiter, kuponId],
          );
        } else {
          // Restore transaksi
          await txn.update(
            'fact_transaksi',
            {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
            where: 'transaksi_id = ?',
            whereArgs: [transaksiId],
          );

          // Deduct kuota from fact_kupon
          await txn.rawUpdate(
            '''
            UPDATE fact_kupon 
            SET kuota_sisa = kuota_sisa - ?
            WHERE kupon_id = ?
          ''',
            [jumlahLiter, kuponId],
          );
        }
      });
    } catch (e) {
      throw Exception(
        'Failed to ${isDelete ? "delete" : "restore"} transaksi: $e',
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getKuponMinus() async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery('''
        SELECT 
          k.*,
          s.nama_satker,
          jk.nama_jenis_kupon,
          COALESCE(t.total_liter, 0) as total_liter,
          k.kuota_awal as kuota_satker,
          k.kuota_sisa,
          ABS(k.kuota_sisa) as minus
        FROM fact_kupon k
        LEFT JOIN dim_satker s ON k.satker_id = s.satker_id
        LEFT JOIN dim_jenis_kupon jk ON k.jenis_kupon_id = jk.jenis_kupon_id
        LEFT JOIN (
          SELECT d.nomor_kupon as nomor, SUM(fp.jumlah_diambil) as total_liter
          FROM fact_purchasing fp
          LEFT JOIN dim_kupon d ON fp.kupon_key = d.kupon_key
          GROUP BY d.nomor_kupon
        ) t ON k.nomor_kupon = t.nomor
        WHERE k.kuota_sisa < 0 AND k.is_deleted = 0
      ''');

      return result;
    } catch (e) {
      throw Exception('Failed to get kupon minus: $e');
    }
  }

  @override
  Future<void> restoreTransaksi(int transaksiId) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        // Get transaksi data
        final transaksi = await txn.query(
          'fact_transaksi',
          where: 'transaksi_id = ?',
          whereArgs: [transaksiId],
        );

        if (transaksi.isEmpty) {
          throw Exception('Transaksi not found');
        }

        final jumlahLiter = transaksi.first['jumlah_liter'] as int;
        final kuponId = transaksi.first['kupon_id'] as int;

        // Restore transaksi
        await txn.update(
          'fact_transaksi',
          {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
          where: 'transaksi_id = ?',
          whereArgs: [transaksiId],
        );

        // Deduct kuota from fact_kupon
        await txn.rawUpdate(
          '''
          UPDATE fact_kupon 
          SET kuota_sisa = kuota_sisa - ?,
              updated_at = DATETIME('now', 'localtime')
          WHERE kupon_id = ?
        ''',
          [jumlahLiter, kuponId],
        );
      });
    } catch (e) {
      throw Exception('Failed to restore transaksi: $e');
    }
  }
}
