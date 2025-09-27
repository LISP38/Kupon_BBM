// lib/data/datasources/database_datasource.dart
import 'dart:io';

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
        version: 2,
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
        },
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    print('DEBUG: _createDB called');
    final batch = db.batch();

    // ---- Dimension tables ----
    // CREATE TABLE dulu, baru INSERT default data
    batch.execute('''
      CREATE TABLE IF NOT EXISTS dim_satker (
        satker_id INTEGER PRIMARY KEY,
        nama_satker TEXT NOT NULL
      );
    ''');
    batch.execute('''
      INSERT OR IGNORE INTO dim_satker (satker_id, nama_satker)
      VALUES (1, 'Default');
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

    // ---- Fact tables ----
    batch.execute('''
      CREATE TABLE IF NOT EXISTS fact_kupon (
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

    batch.execute('''
      CREATE TABLE IF NOT EXISTS fact_purchasing (
        purchasing_id INTEGER PRIMARY KEY,
        kupon_id INTEGER NOT NULL,
        tanggal_transaksi TEXT NOT NULL,
        jumlah_diambil REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        is_deleted INTEGER DEFAULT 0,
        deleted_at TEXT,
        FOREIGN KEY (kupon_id) REFERENCES fact_kupon(kupon_id) ON DELETE CASCADE
      );
    ''');

    // Indexes
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_kendaraan_satker ON dim_kendaraan(satker_id);',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_kupon_kendaraan ON fact_kupon(kendaraan_id);',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_kupon_status ON fact_kupon(status);',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchasing_kupon ON fact_purchasing(kupon_id);',
    );

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

      // dim_satker
      final List<Map<String, dynamic>> satkerList = [
        {'id': 1, 'name': 'KAPOLDA'},
        {'id': 2, 'name': 'WAKAPOLDA'},
        {'id': 3, 'name': 'IRWASDA'},
        {'id': 4, 'name': 'ROOPS'},
        {'id': 5, 'name': 'RORENA'},
        {'id': 6, 'name': 'RO SDM'},
        {'id': 7, 'name': 'ROLOG'},
        {'id': 8, 'name': 'DITINTELKAM'},
        {'id': 9, 'name': 'DITKRIMUM'},
        {'id': 10, 'name': 'DITKRIMSUS'},
        {'id': 11, 'name': 'DITNARKOBA'},
        {'id': 12, 'name': 'DITLANTAS'},
        {'id': 13, 'name': 'DITBINMAS'},
        {'id': 14, 'name': 'DITSAMAPTA'},
        {'id': 15, 'name': 'DITPAMOBVIT'},
        {'id': 16, 'name': 'DITPOLAIRUD'},
        {'id': 17, 'name': 'SATBRIMOB'},
        {'id': 18, 'name': 'BIDPROPAM'},
        {'id': 19, 'name': 'BIDHUMAS'},
        {'id': 20, 'name': 'BIDKUM'},
        {'id': 21, 'name': 'BID TIK'},
        {'id': 22, 'name': 'BIDDOKKES'},
        {'id': 23, 'name': 'BIDKEU'},
        {'id': 24, 'name': 'SPN'},
        {'id': 25, 'name': 'DITRESSIBER'},
        {'id': 26, 'name': 'DITLABFOR'},
        {'id': 271, 'name': 'KOORPSPRIPIM'},
        {'id': 272, 'name': 'YANMA'},
        {'id': 273, 'name': 'SETUM'},
        {'id': 28, 'name': 'SPKT'},
        {'id': 29, 'name': 'DITTAHTI'},
        {'id': 34, 'name': 'RUMAH SAKIT BHAYANGKARA SARTIKA ASIH (RSSA)'},
        {'id': 35, 'name': 'RUMAH SAKIT BHAYANGKARA INDRAMAYU'},
        {'id': 36, 'name': 'RUMAH SAKIT BHAYANGKARA BOGOR'},
      ];

      for (final s in satkerList) {
        await txn.insert('dim_satker', {
          'satker_id': s['id'],
          'nama_satker': s['name'],
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    print('DEBUG: _seedMasterData finished');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
