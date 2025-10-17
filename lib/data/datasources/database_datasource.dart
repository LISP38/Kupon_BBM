import 'dart:io';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/data/models/kendaraan_model.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseDatasource {
  Database? _database;
  final String _dbFileName = 'kupon_bbm.db';

  DatabaseDatasource() {
    sqfliteFfiInit();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbFileName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbDir = Directory('data');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final path = join(dbDir.path, filePath);
    final dbFactory = databaseFactoryFfi;

    print('DEBUG: Opening database at path: $path');

    return await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) async {
          print('DEBUG: onConfigure called');
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          print('DEBUG: onCreate called, creating tables...');
          await _createDB(db, version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('DEBUG: onUpgrade called from $oldVersion to $newVersion');
          if (oldVersion < 2) {
            // Remove UNIQUE constraint from nomor_kupon
            await db.execute('CREATE TABLE fact_kupon_temp AS SELECT * FROM fact_kupon');
            await db.execute('DROP TABLE fact_kupon');
            await db.execute('''
              CREATE TABLE fact_kupon (
                kupon_id INTEGER PRIMARY KEY AUTOINCREMENT,
                nomor_kupon TEXT NOT NULL,
                kendaraan_id INTEGER NOT NULL,
                jenis_bbm_id INTEGER NOT NULL,
                jenis_kupon_id INTEGER NOT NULL,
                bulan_terbit INTEGER NOT NULL,
                tahun_terbit INTEGER NOT NULL,
                tanggal_mulai TEXT NOT NULL,
                tanggal_sampai TEXT NOT NULL,
                kuota_awal REAL NOT NULL,
                kuota_sisa REAL NOT NULL CHECK (kuota_sisa >= -999999),
                nama_satker TEXT NOT NULL,
                status TEXT DEFAULT 'Aktif',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                is_deleted INTEGER DEFAULT 0,
                FOREIGN KEY (kendaraan_id) REFERENCES dim_kendaraan(kendaraan_id)
                  ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (jenis_bbm_id) REFERENCES dim_jenis_bbm(jenis_bbm_id),
                FOREIGN KEY (jenis_kupon_id) REFERENCES dim_jenis_kupon(jenis_kupon_id)
              );
            ''');
            await db.execute('INSERT INTO fact_kupon SELECT * FROM fact_kupon_temp');
            await db.execute('DROP TABLE fact_kupon_temp');
            print('DEBUG: UNIQUE constraint removed from nomor_kupon');
          }

          if (oldVersion < 3) {
            print('DEBUG: Version 3 migration skipped');
          }

          if (oldVersion < 4) {
            // Make kendaraan_id nullable to support DUKUNGAN kupon
            print('DEBUG: Making kendaraan_id nullable in fact_kupon');

            // Create new table with nullable kendaraan_id
            await db.execute('''
              CREATE TABLE fact_kupon_new (
                kupon_id INTEGER PRIMARY KEY AUTOINCREMENT,
                nomor_kupon TEXT NOT NULL,
                kendaraan_id INTEGER,
                jenis_bbm_id INTEGER NOT NULL,
                jenis_kupon_id INTEGER NOT NULL,
                bulan_terbit INTEGER NOT NULL,
                tahun_terbit INTEGER NOT NULL,
                tanggal_mulai TEXT NOT NULL,
                tanggal_sampai TEXT NOT NULL,
                kuota_awal REAL NOT NULL,
                kuota_sisa REAL NOT NULL CHECK (kuota_sisa >= -999999),
                satker_id INTEGER NOT NULL,
                nama_satker TEXT NOT NULL,
                status TEXT DEFAULT 'Aktif',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                is_deleted INTEGER DEFAULT 0,
                FOREIGN KEY (kendaraan_id) REFERENCES dim_kendaraan(kendaraan_id)
                  ON DELETE CASCADE ON UPDATE CASCADE,
                FOREIGN KEY (jenis_bbm_id) REFERENCES dim_jenis_bbm(jenis_bbm_id),
                FOREIGN KEY (jenis_kupon_id) REFERENCES dim_jenis_kupon(jenis_kupon_id),
                FOREIGN KEY (satker_id) REFERENCES dim_satker(satker_id)
                  ON DELETE RESTRICT ON UPDATE CASCADE
              );
            ''');

            // Copy data from old table
            await db.execute('''
              INSERT INTO fact_kupon_new 
              SELECT * FROM fact_kupon;
            ''');

            // Drop old table and rename
            await db.execute('DROP TABLE fact_kupon');
            await db.execute('ALTER TABLE fact_kupon_new RENAME TO fact_kupon');

            print('DEBUG: fact_kupon table migrated with nullable kendaraan_id');
          }

          if (oldVersion < 5) {
            print('DEBUG: Adding unique index to fact_kupon');
            await db.execute('''
              CREATE UNIQUE INDEX IF NOT EXISTS idx_fact_kupon_unique_key 
              ON fact_kupon (nomor_kupon, jenis_kupon_id, satker_id, bulan_terbit, tahun_terbit) 
              WHERE is_deleted = 0;
            ''');
          }
        },
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    print('DEBUG: _createDB called');
    final batch = db.batch();

    // Dimension tables
    batch.execute('''
      CREATE TABLE IF NOT EXISTS dim_satker (
        satker_id INTEGER PRIMARY KEY,
        nama_satker TEXT NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS dim_jenis_bbm (
        jenis_bbm_id INTEGER PRIMARY KEY,
        nama_jenis_bbm TEXT NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS dim_jenis_kupon (
        jenis_kupon_id INTEGER PRIMARY KEY,
        nama_jenis_kupon TEXT NOT NULL
      );
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS dim_kendaraan (
        kendaraan_id INTEGER PRIMARY KEY AUTOINCREMENT,
        satker_id INTEGER NOT NULL,
        jenis_ranmor TEXT NOT NULL,
        no_pol_kode TEXT NOT NULL,
        no_pol_nomor TEXT NOT NULL,
        status_aktif INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(no_pol_kode, no_pol_nomor),
        FOREIGN KEY (satker_id) REFERENCES dim_satker(satker_id) 
          ON DELETE RESTRICT ON UPDATE CASCADE
      );
    ''');

    // Fact tables
    batch.execute('''
      CREATE TABLE IF NOT EXISTS fact_kupon (
        kupon_id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_kupon TEXT NOT NULL,
        kendaraan_id INTEGER,
        jenis_bbm_id INTEGER NOT NULL,
        jenis_kupon_id INTEGER NOT NULL,
        bulan_terbit INTEGER NOT NULL,
        tahun_terbit INTEGER NOT NULL,
        tanggal_mulai TEXT NOT NULL,
        tanggal_sampai TEXT NOT NULL,
        kuota_awal REAL NOT NULL,
        kuota_sisa REAL NOT NULL CHECK (kuota_sisa >= -999999),
        satker_id INTEGER NOT NULL,
        nama_satker TEXT NOT NULL,
        status TEXT DEFAULT 'Aktif',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (kendaraan_id) REFERENCES dim_kendaraan(kendaraan_id)
          ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (jenis_bbm_id) REFERENCES dim_jenis_bbm(jenis_bbm_id),
        FOREIGN KEY (jenis_kupon_id) REFERENCES dim_jenis_kupon(jenis_kupon_id),
        FOREIGN KEY (satker_id) REFERENCES dim_satker(satker_id)
          ON DELETE RESTRICT ON UPDATE CASCADE
      );
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS fact_transaksi (
        transaksi_id INTEGER PRIMARY KEY AUTOINCREMENT,
        kupon_id INTEGER NOT NULL,
        nomor_kupon TEXT NOT NULL,
        nama_satker TEXT NOT NULL,
        jenis_bbm_id INTEGER NOT NULL,
        jumlah_liter REAL NOT NULL,
        tanggal_transaksi TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        status TEXT DEFAULT 'Aktif',
        FOREIGN KEY (kupon_id) REFERENCES fact_kupon(kupon_id) ON DELETE CASCADE
      );
    ''');

    // Indexes
    batch.execute('CREATE INDEX IF NOT EXISTS idx_kendaraan_satker ON dim_kendaraan(satker_id);');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_kupon_kendaraan ON fact_kupon(kendaraan_id);');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_kupon_status ON fact_kupon(status);');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_transaksi_kupon ON fact_transaksi(kupon_id);');

    batch.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_fact_kupon_unique_key 
      ON fact_kupon (nomor_kupon, jenis_kupon_id, satker_id, bulan_terbit, tahun_terbit) 
      WHERE is_deleted = 0;
    ''');

    await batch.commit(noResult: true);
    print('DEBUG: Tables created, seeding master data...');
    await _seedMasterData(db);
    print('DEBUG: Master data seeded.');
  }

  Future<void> _seedMasterData(Database db) async {
    print('DEBUG: _seedMasterData called');
    await db.transaction((txn) async {
      // dim_jenis_bbm
      await txn.insert('dim_jenis_bbm', {
        'jenis_bbm_id': 1,
        'nama_jenis_bbm': 'Pertamax',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      
      await txn.insert('dim_jenis_bbm', {
        'jenis_bbm_id': 2,
        'nama_jenis_bbm': 'Pertamina Dex',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // dim_jenis_kupon
      await txn.insert('dim_jenis_kupon', {
        'jenis_kupon_id': 1,
        'nama_jenis_kupon': 'Ranjen',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      
      await txn.insert('dim_jenis_kupon', {
        'jenis_kupon_id': 2,
        'nama_jenis_kupon': 'Dukungan',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      // dim_satker: now fully dynamic, no hardcoded list
    });
    print('DEBUG: _seedMasterData finished');
  }

  // PERBAIKAN: Cek duplikat sebelum insert
  Future<void> insertKupons(List<KuponModel> kupons) async {
    final db = await database;
    
    int insertedCount = 0;
    int skippedCount = 0;
    
    // Ambil mapping satker dari master
    final satkerRows = await db.query('dim_satker');
    final satkerMap = <String, int>{};
    for (final row in satkerRows) {
      final name = (row['nama_satker'] as String)
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
          .toUpperCase();
      satkerMap[name] = row['satker_id'] as int;
    }

    // Insert satu per satu dengan validasi duplikat
    for (final k in kupons) {
      try {
        // Normalisasi nama satker
        final namaSatkerRaw = k.namaSatker;
        final namaSatker = (namaSatkerRaw.trim().isEmpty)
            ? 'CADANGAN'
            : namaSatkerRaw
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ')
                .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
                .toUpperCase();
        
        // Cari di map dengan normalisasi yang sama
        int? satkerId = satkerMap[namaSatker];
        
        if (satkerId == null) {
          // Gunakan normalisasi yang sama saat mencari di database
          final existing = await db.query(
            'dim_satker',
            where: 'UPPER(TRIM(nama_satker)) = ?',
            whereArgs: [namaSatker],
          );
          if (existing.isNotEmpty) {
            satkerId = existing.first['satker_id'] as int;
            satkerMap[namaSatker] = satkerId;
          } else {
            satkerId = await db.insert('dim_satker', {'nama_satker': namaSatker});
            satkerMap[namaSatker] = satkerId;
            print('INFO: Satker baru ditambahkan: "$namaSatker" dengan id $satkerId');
          }
        }

        // PERBAIKAN: Cek duplikat berdasarkan unique index
        final duplicateCheck = await db.query(
          'fact_kupon',
          where: '''
            nomor_kupon = ? AND 
            jenis_kupon_id = ? AND 
            satker_id = ? AND 
            bulan_terbit = ? AND 
            tahun_terbit = ? AND
            is_deleted = 0
          ''',
          whereArgs: [
            k.nomorKupon,
            k.jenisKuponId,
            satkerId,
            k.bulanTerbit,
            k.tahunTerbit,
          ],
          limit: 1,
        );

        if (duplicateCheck.isNotEmpty) {
          skippedCount++;
          print('SKIP: Kupon ${k.nomorKupon} sudah ada di database (duplikat)');
          continue;
        }

        // kendaraan_id: null jika jenisKuponId == 2 (DUKUNGAN)
        int? kendaraanId;
        if (k.jenisKuponId == 2) {
          kendaraanId = null;
        } else if (k.kendaraanId != null) {
          // Check if kendaraan exists in dim_kendaraan
          final kendaraanRow = await db.query(
            'dim_kendaraan',
            where: 'kendaraan_id = ?',
            whereArgs: [k.kendaraanId],
            limit: 1,
          );
          if (kendaraanRow.isNotEmpty) {
            kendaraanId = k.kendaraanId;
          } else {
            kendaraanId = null;
          }
        }

        final jenisBbmId = k.jenisBbmId;
        final jenisKuponId = k.jenisKuponId;
        
        // Insert kupon
        final insertedId = await db.insert('fact_kupon', {
          'nomor_kupon': k.nomorKupon,
          'kendaraan_id': kendaraanId,
          'jenis_bbm_id': jenisBbmId,
          'jenis_kupon_id': jenisKuponId,
          'bulan_terbit': k.bulanTerbit,
          'tahun_terbit': k.tahunTerbit,
          'tanggal_mulai': k.tanggalMulai,
          'tanggal_sampai': k.tanggalSampai,
          'kuota_awal': k.kuotaAwal,
          'kuota_sisa': k.kuotaSisa,
          'satker_id': satkerId,
          'nama_satker': namaSatker,
          'status': k.status,
          'created_at': k.createdAt,
          'updated_at': k.updatedAt,
          'is_deleted': k.isDeleted,
        });
        
        if (insertedId > 0) {
          insertedCount++;
        }
      } catch (e) {
        if (e.toString().contains('UNIQUE constraint failed')) {
          skippedCount++;
          print('SKIP: Kupon ${k.nomorKupon} melanggar constraint unik (duplikat)');
        } else {
          print('ERROR: Failed to insert kupon ${k.nomorKupon}: ${e.toString()}');
          rethrow;
        }
      }
    }
    
    print('DEBUG: InsertKupons completed - Inserted: $insertedCount, Skipped: $skippedCount, Total attempted: ${kupons.length}');
  }

  // Metode insertKendaraans tanpa batch processing
  Future<void> insertKendaraans(List<KendaraanModel> kendaraans) async {
    final db = await database;
    
    int insertedCount = 0;
    int skippedCount = 0;
    
    // Insert satu per satu
    for (final k in kendaraans) {
      try {
        final insertedId = await db.insert('dim_kendaraan', {
          'satker_id': k.satkerId,
          'jenis_ranmor': k.jenisRanmor,
          'no_pol_kode': k.noPolKode,
          'no_pol_nomor': k.noPolNomor,
          'status_aktif': k.statusAktif,
          'created_at': k.createdAt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        
        if (insertedId > 0) {
          insertedCount++;
        } else {
          skippedCount++;
        }
      } catch (e) {
        if (e.toString().contains('UNIQUE constraint failed')) {
          skippedCount++;
          print('SKIP: Kendaraan ${k.noPolKode} ${k.noPolNomor} sudah ada (duplikat)');
        } else {
          print('ERROR: Failed to insert kendaraan ${k.noPolKode} ${k.noPolNomor}: ${e.toString()}');
          rethrow;
        }
      }
    }
    
    print('DEBUG: InsertKendaraans completed - Inserted: $insertedCount, Skipped: $skippedCount, Total attempted: ${kendaraans.length}');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}