import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository_impl.dart';
import 'package:kupon_bbm_app/data/services/database_change_listener.dart';
import 'dart:async';

class DashboardProvider extends ChangeNotifier {
  final KuponRepository _kuponRepository;

  // --- State Variables ---
  // Menyimpan data untuk setiap tipe kupon
  List<KuponEntity> _allKupons = [];
  List<KuponEntity> _ranjenKupons = [];
  List<KuponEntity> _dukunganKupons = [];

  // List kupon tanpa filter (untuk dropdown di halaman transaksi)
  List<KuponEntity> _allKuponsUnfiltered = [];

  // Master data lists
  List<String> _satkerList = [];
  List<int> _bulanList = [];
  List<int> _tahunList = [];
  // Filter options from database
  List<String> _daftarBulan = [];
  List<String> _daftarTahun = [];
  List<String> _jenisBbmList = [];
  Map<int, String> _jenisBbmMap = {};

  // Filter state
  String? nomorKupon;
  String? satker;
  String? jenisBBM;
  String? jenisKupon;
  String? nopol;
  String? jenisRanmor;
  int? bulanTerbit;
  int? tahunTerbit;

  // State untuk loading dan error
  bool _isLoading = false;
  String? _errorMessage;

  // State untuk mode tampilan (untuk refresh atau UI spesifik)
  /// Mode: true = Ranjen (default), false = Dukungan
  /// Default true karena tab pertama adalah Data Ranjen
  bool _isRanjenMode = true;

  // --- Real-time listener ---
  StreamSubscription<DatabaseChange>? _databaseChangeSubscription;

  // --- Getters ---
  List<KuponEntity> get kupons => _allKupons;
  List<KuponEntity> get kuponList => _allKupons;
  List<KuponEntity> get ranjenKupons => _ranjenKupons;
  List<KuponEntity> get dukunganKupons => _dukunganKupons;

  // Getter untuk dropdown di halaman transaksi (tanpa filter)
  List<KuponEntity> get allKuponsForDropdown => _allKuponsUnfiltered;

  // Getter khusus untuk menggabungkan semua data saat export
  List<KuponEntity> get allKuponsForExport => [
    ..._ranjenKupons,
    ..._dukunganKupons,
  ];

  List<String> get satkerList => _satkerList;
  List<int> get bulanList => _bulanList;
  List<int> get tahunList => _tahunList;
  List<String> get daftarBulan => _daftarBulan;
  List<String> get daftarTahun => _daftarTahun;
  List<String> get jenisBbmList => _jenisBbmList;
  List<String> get bulanTerbitList => _daftarBulan;
  List<String> get tahunTerbitList => _daftarTahun;
  Map<int, String> get jenisBbmMap => _jenisBbmMap;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRanjenMode => _isRanjenMode;

  /// Setter untuk mengubah mode (Ranjen/Dukungan)
  /// dan trigger notifyListeners() untuk update UI
  set isRanjenMode(bool value) {
    if (_isRanjenMode != value) {
      _isRanjenMode = value;
      notifyListeners();
    }
  }

  // --- Total Calculations (Per Tab - Ranjen or Dukungan) ---
  /// Total kuota awal untuk jenis kupon aktif (Ranjen atau Dukungan)
  double get totalKuotaAwal {
    if (_isRanjenMode) {
      return _ranjenKupons.fold(0.0, (sum, k) => sum + k.kuotaAwal);
    } else {
      return _dukunganKupons.fold(0.0, (sum, k) => sum + k.kuotaAwal);
    }
  }

  /// Total terpakai untuk jenis kupon aktif (Ranjen atau Dukungan)
  double get totalTerpakai {
    if (_isRanjenMode) {
      return _ranjenKupons.fold(
        0.0,
        (sum, k) => sum + (k.kuotaAwal - k.kuotaSisa),
      );
    } else {
      return _dukunganKupons.fold(
        0.0,
        (sum, k) => sum + (k.kuotaAwal - k.kuotaSisa),
      );
    }
  }

  /// Total saldo untuk jenis kupon aktif (Ranjen atau Dukungan)
  double get totalSaldo {
    if (_isRanjenMode) {
      return _ranjenKupons.fold(0.0, (sum, k) => sum + k.kuotaSisa);
    } else {
      return _dukunganKupons.fold(0.0, (sum, k) => sum + k.kuotaSisa);
    }
  }

  // --- Constructor ---
  DashboardProvider(this._kuponRepository) {
    // Initialize real-time listener
    _initializeRealtimeListener();

    // PENTING: Fetch data default (Ranjen) saat Provider di-create
    // Jadi data sudah tersedia sebelum UI render untuk pertama kalinya
    _initializeDefaultData();
  }

  /// Initialize default data saat Provider di-create
  /// Ini memastikan summary card menampilkan data yang benar sejak awal
  void _initializeDefaultData() {
    // Set mode ke Ranjen (default)
    _isRanjenMode = true;

    // Fetch Ranjen data async, tapi jangan block constructor
    Future.microtask(() async {
      try {
        debugPrint('🔄 _initializeDefaultData: Fetching Ranjen data...');
        await fetchRanjenKupons(forceRefresh: false);
        debugPrint('✅ _initializeDefaultData: Ranjen data loaded');
      } catch (e) {
        debugPrint('❌ _initializeDefaultData error: $e');
      }
    });
  }

  // --- Real-time Database Change Listener ---
  void _initializeRealtimeListener() {
    final listener = DatabaseChangeListener();
    _databaseChangeSubscription = listener.kuponChangeStream.listen((change) {
      print('[DashboardProvider] Received database change: ${change.type}');

      // Auto-refresh kupon dan filter options ketika ada perubahan
      if (change.type == DatabaseChangeType.bulkImport ||
          change.type == DatabaseChangeType.importCompleted) {
        print('[DashboardProvider] Import detected, refreshing kupon data...');

        // Refresh semua data async dengan proper await
        _handleImportedData();
      }
    });
  }

  /// Handle imported data refresh
  /// Ini memastikan semua fetch selesai sebelum notifyListeners
  void _handleImportedData() {
    // Use Future.microtask untuk non-blocking async execution
    Future.microtask(() async {
      try {
        print('[DashboardProvider] Starting import data refresh...');

        // Fetch KEDUA-DUA jenis kupon untuk memastikan keduanya update
        // PENTING: Fetch Dukungan DULU sebelum Ranjen
        // Jadi `_isRanjenMode` akan ter-set ke TRUE di akhir (dari fetchRanjenKupons)
        await fetchDukunganKupons(forceRefresh: true);
        await fetchRanjenKupons(forceRefresh: true);

        // Also fetch unfiltered for other uses
        await fetchAllKuponsUnfiltered();

        // Refresh dropdown options
        await loadFilterOptions(); // Bulan & Tahun dari database
        await fetchJenisBbm(); // BBM options
        await fetchSatkers(); // Satker options

        // PENTING: Ensure _isRanjenMode = true di akhir untuk menampilkan Ranjen
        _isRanjenMode = true;
        notifyListeners();

        print(
          '[DashboardProvider] Import refresh completed! Reset to Ranjen mode.',
        );
      } catch (e) {
        print('[DashboardProvider] Error refreshing import data: $e');
        _errorMessage = e.toString();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _databaseChangeSubscription?.cancel();
    super.dispose();
  }

  // --- Helper Methods ---

  /// Update status kupon yang sudah expired menjadi "Tidak Aktif" di database
  /// Dipanggil setiap kali fetch kupon untuk memastikan status selalu akurat
  Future<void> _updateExpiredKuponStatus() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      // Update semua kupon yang tanggal_sampainya sudah lewat
      await db.update(
        'dim_kupon',
        {'status': 'Tidak Aktif'},
        where:
            'is_current = 1 AND date(tanggal_sampai) < date("now") AND status != ?',
        whereArgs: ['Tidak Aktif'],
      );

      debugPrint('✅ Updated expired kupon status to "Tidak Aktif"');
    } catch (e) {
      debugPrint('❌ Error updating expired kupon status: $e');
    }
  }

  // --- Data Fetching Methods ---

  Future<void> fetchSatkers() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      final results = await db.query(
        'dim_satker',
        columns: ['nama_satker'],
        orderBy: 'nama_satker ASC',
      );

      _satkerList = results.map((row) => row['nama_satker'] as String).toList();
      notifyListeners();
    } catch (e) {
      _satkerList = [];
      notifyListeners();
    }
  }

  /// Fetch semua kupon tanpa filter untuk dropdown di halaman transaksi
  Future<void> fetchAllKuponsUnfiltered() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      String query = '''
        SELECT 
          dk.kupon_key as kupon_id,
          dk.nomor_kupon,
          dk.kendaraan_id,
          dk.jenis_bbm_id,
          dk.jenis_kupon_id,
          dk.bulan_terbit,
          dk.tahun_terbit,
          dk.tanggal_mulai,
          dk.tanggal_sampai,
          dk.kuota_awal,
          (dk.kuota_awal - COALESCE(ft_sum.total_used, 0)) as kuota_sisa,
          dk.satker_id,
          ds.nama_satker,
          dk.status,
          dk.valid_from as created_at,
          CURRENT_TIMESTAMP as updated_at,
          0 as is_deleted
        FROM dim_kupon dk
        LEFT JOIN dim_kendaraan ON dk.kendaraan_id = dim_kendaraan.kendaraan_id 
        LEFT JOIN dim_satker ds ON dk.satker_id = ds.satker_id
        LEFT JOIN (
          SELECT kupon_key, SUM(jumlah_liter) as total_used
          FROM fact_transaksi
          WHERE is_deleted = 0
          GROUP BY kupon_key
        ) ft_sum ON dk.kupon_key = ft_sum.kupon_key
        WHERE dk.is_current = 1
        ORDER BY CAST(dk.nomor_kupon AS INTEGER) ASC
      ''';

      // Update expired kupon status first
      await _updateExpiredKuponStatus();

      final results = await db.rawQuery(query);

      _allKuponsUnfiltered = results
          .map((row) => KuponModel.fromMap(row))
          .toList();
      notifyListeners();
    } catch (e) {
      _allKuponsUnfiltered = [];
      notifyListeners();
    }
  }

  Future<void> fetchJenisBbm() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;
    try {
      final rows = await db.query(
        'dim_jenis_bbm',
        orderBy: 'jenis_bbm_id ASC', // Order by ID to keep consistent mapping
      );
      final map = <int, String>{};
      final list = <String>[];
      final seenNames = <String>{}; // Track case-insensitive duplicates

      for (final r in rows) {
        final id = r['jenis_bbm_id'] as int?;
        final name = (r['nama_jenis_bbm'] as String).trim();
        final lowerName = name.toLowerCase();

        // Skip case-insensitive duplicates (keep first occurrence by ID)
        if (seenNames.contains(lowerName)) continue;
        seenNames.add(lowerName);

        list.add(name);
        if (id != null) map[id] = name;
      }
      _jenisBbmList = list;
      _jenisBbmMap = map;
      notifyListeners();
    } catch (e) {
      _jenisBbmList = [];
      _jenisBbmMap = {};
      notifyListeners();
    }
  }

  // Fetch bulan list from dim_bulan; fall back to 1..12 on error
  Future<void> fetchBulans() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;
    try {
      // check if dim_bulan exists
      final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        ['dim_bulan'],
      );
      List<int> months = [];
      if (exists.isNotEmpty) {
        final results = await db.query('dim_bulan');
        months = results
            .map<int>((row) {
              final v =
                  row['bulan_id'] ??
                  row['bulan'] ??
                  row['bulan_number'] ??
                  row['id'];
              if (v is int) return v;
              if (v is String) return int.tryParse(v) ?? 0;
              return 0;
            })
            .where((v) => v > 0)
            .toList();
      } else {
        // fallback to dim_date if available
        final dateExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
          ['dim_date'],
        );
        if (dateExists.isNotEmpty) {
          final rows = await db.rawQuery(
            'SELECT DISTINCT bulan_terbit FROM dim_date WHERE bulan_terbit IS NOT NULL ORDER BY bulan_terbit ASC',
          );
          months = rows
              .map<int>((r) {
                final v = r['bulan_terbit'];
                if (v is int) return v;
                if (v is String) return int.tryParse(v) ?? 0;
                return 0;
              })
              .where((v) => v > 0)
              .toList();
        }
      }

      if (months.isEmpty) months = List.generate(12, (i) => i + 1);
      _bulanList = months;
      notifyListeners();
    } catch (e) {
      _bulanList = List.generate(12, (i) => i + 1);
      notifyListeners();
    }
  }

  // Fetch tahun list from dim_tahun; fall back to current year +/- 1
  Future<void> fetchTahuns() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;
    try {
      // check dim_tahun
      final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        ['dim_tahun'],
      );
      List<int> years = [];
      if (exists.isNotEmpty) {
        final results = await db.query('dim_tahun');
        years = results
            .map<int>((row) {
              final v = row['tahun'] ?? row['tahun_id'] ?? row['id'];
              if (v is int) return v;
              if (v is String) return int.tryParse(v) ?? 0;
              return 0;
            })
            .where((v) => v > 0)
            .toList();
      } else {
        final dateExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
          ['dim_date'],
        );
        if (dateExists.isNotEmpty) {
          final rows = await db.rawQuery(
            'SELECT DISTINCT tahun_terbit FROM dim_date WHERE tahun_terbit IS NOT NULL ORDER BY tahun_terbit ASC',
          );
          years = rows
              .map<int>((r) {
                final v = r['tahun_terbit'];
                if (v is int) return v;
                if (v is String) return int.tryParse(v) ?? 0;
                return 0;
              })
              .where((v) => v > 0)
              .toList();
        }
      }

      if (years.isEmpty) {
        final y = DateTime.now().year;
        years = [y, y + 1];
      }
      _tahunList = years;
      notifyListeners();
    } catch (e) {
      final y = DateTime.now().year;
      _tahunList = [y, y + 1];
      notifyListeners();
    }
  }

  /// Load distinct `bulan` and `tahun` values from database.
  /// Values are returned as strings to preserve whatever format is stored
  /// (numeric or textual). UI will map numeric month strings to month names.
  Future<void> loadFilterOptions() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;
    try {
      // Primary source: dim_kupon (more reliable than dim_date since we populate dim_kupon directly)
      final bulanRows = await db.rawQuery(
        '''SELECT DISTINCT bulan_terbit FROM dim_kupon WHERE is_current = 1 AND bulan_terbit IS NOT NULL ORDER BY CAST(bulan_terbit AS INTEGER) ASC''',
      );
      final tahunRows = await db.rawQuery(
        '''SELECT DISTINCT tahun_terbit FROM dim_kupon WHERE is_current = 1 AND tahun_terbit IS NOT NULL ORDER BY CAST(tahun_terbit AS INTEGER) ASC''',
      );

      _daftarBulan = bulanRows
          .map<String>((r) => (r['bulan_terbit']?.toString() ?? ''))
          .where((s) => s.isNotEmpty)
          .toList();
      _daftarTahun = tahunRows
          .map<String>((r) => (r['tahun_terbit']?.toString() ?? ''))
          .where((s) => s.isNotEmpty)
          .toList();

      // Fallback: try dim_date if dim_kupon returned no rows
      if (_daftarBulan.isEmpty || _daftarTahun.isEmpty) {
        final dateExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name = 'dim_date'",
        );
        if (dateExists.isNotEmpty) {
          final dB = await db.rawQuery(
            '''SELECT DISTINCT bulan_terbit FROM dim_date WHERE bulan_terbit IS NOT NULL ORDER BY CAST(bulan_terbit AS INTEGER) ASC''',
          );
          final dT = await db.rawQuery(
            '''SELECT DISTINCT tahun_terbit FROM dim_date WHERE tahun_terbit IS NOT NULL ORDER BY CAST(tahun_terbit AS INTEGER) ASC''',
          );
          if (_daftarBulan.isEmpty) {
            _daftarBulan = dB
                .map<String>((r) => (r['bulan_terbit']?.toString() ?? ''))
                .where((s) => s.isNotEmpty)
                .toList();
          }
          if (_daftarTahun.isEmpty) {
            _daftarTahun = dT
                .map<String>((r) => (r['tahun_terbit']?.toString() ?? ''))
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
      }
      notifyListeners();
    } catch (e) {
      _daftarBulan = [];
      _daftarTahun = [];
      notifyListeners();
    }
  }

  /// Metode utama untuk mengambil SEMUA kupon (Ranjen & Dukungan) berdasarkan filter.
  /// Filter `jenisKupon` akan diabaikan di sini untuk mengambil semua tipe.
  Future<void> fetchKupons({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      List<String> whereConditions = ['dk.is_current = 1'];
      List<dynamic> whereArgs = [];

      if (nomorKupon != null && nomorKupon!.isNotEmpty) {
        whereConditions.add('dk.nomor_kupon = ?');
        whereArgs.add(nomorKupon!);
      }
      if (jenisBBM != null && jenisBBM!.isNotEmpty) {
        whereConditions.add('dk.jenis_bbm_id = ?');
        whereArgs.add(int.tryParse(jenisBBM!) ?? jenisBBM);
      }

      // Filter berdasarkan bulan_terbit dan tahun_terbit LANGSUNG
      // (bukan berdasarkan tanggal berlaku)
      if (bulanTerbit != null && tahunTerbit != null) {
        whereConditions.add('dk.bulan_terbit = ? AND dk.tahun_terbit = ?');
        whereArgs.addAll([bulanTerbit, tahunTerbit]);
      } else if (tahunTerbit != null && bulanTerbit == null) {
        whereConditions.add('dk.tahun_terbit = ?');
        whereArgs.add(tahunTerbit);
      } else if (bulanTerbit != null && tahunTerbit == null) {
        whereConditions.add('dk.bulan_terbit = ?');
        whereArgs.add(bulanTerbit);
      }

      String query =
          '''
        SELECT 
          dk.kupon_key as kupon_id,
          dk.nomor_kupon,
          dk.kendaraan_id,
          dk.jenis_bbm_id,
          dk.jenis_kupon_id,
          dk.bulan_terbit,
          dk.tahun_terbit,
          dk.tanggal_mulai,
          dk.tanggal_sampai,
          dk.kuota_awal,
          (dk.kuota_awal - COALESCE(ft_sum.total_used, 0)) as kuota_sisa,
          dk.satker_id,
          ds.nama_satker,
          dk.status,
          dk.valid_from as created_at,
          CURRENT_TIMESTAMP as updated_at,
          0 as is_deleted
        FROM dim_kupon dk
        LEFT JOIN dim_kendaraan ON dk.kendaraan_id = dim_kendaraan.kendaraan_id 
        LEFT JOIN dim_satker ds ON dk.satker_id = ds.satker_id
        LEFT JOIN (
          SELECT kupon_key, SUM(jumlah_liter) as total_used
          FROM fact_transaksi
          WHERE is_deleted = 0
          GROUP BY kupon_key
        ) ft_sum ON dk.kupon_key = ft_sum.kupon_key
        WHERE ${whereConditions.join(' AND ')}
      ''';

      if (nopol != null && nopol!.isNotEmpty) {
        query +=
            ' AND (LOWER(dim_kendaraan.no_pol_kode) || \'-\' || LOWER(dim_kendaraan.no_pol_nomor)) LIKE ?';
        whereArgs.add('%${nopol!.toLowerCase().trim()}%');
      }
      if (satker != null && satker!.isNotEmpty) {
        query += ' AND LOWER(TRIM(ds.nama_satker)) LIKE ?';
        whereArgs.add('%${satker!.toLowerCase().trim()}%');
      }
      if (jenisRanmor != null && jenisRanmor!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_kendaraan.jenis_ranmor)) LIKE ?';
        whereArgs.add('%${jenisRanmor!.toLowerCase().trim()}%');
      }

      query += ' ORDER BY CAST(dk.nomor_kupon AS INTEGER) ASC';

      final results = await db.rawQuery(query, whereArgs);
      _allKupons = results.map((map) => KuponModel.fromMap(map)).toList();

      // Pisahkan data berdasarkan jenis kupon setelah mengambil semua data
      _ranjenKupons = _allKupons.where((k) => k.jenisKuponId == 1).toList();
      _dukunganKupons = _allKupons.where((k) => k.jenisKuponId == 2).toList();
    } catch (e) {
      _errorMessage = e.toString();
      _allKupons = [];
      _ranjenKupons = [];
      _dukunganKupons = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Metode untuk mengambil data kupon berdasarkan tipe tertentu (Ranjen atau Dukungan).
  Future<void> _fetchKuponsByType(
    int jenisKuponId, {
    bool forceRefresh = false,
  }) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      List<String> whereConditions = [
        'dk.is_current = 1',
        'dk.jenis_kupon_id = ?',
      ];
      List<dynamic> whereArgs = [jenisKuponId];

      if (nomorKupon != null && nomorKupon!.isNotEmpty) {
        whereConditions.add('dk.nomor_kupon = ?');
        whereArgs.add(nomorKupon!);
      }
      if (jenisBBM != null && jenisBBM!.isNotEmpty) {
        whereConditions.add('dk.jenis_bbm_id = ?');
        whereArgs.add(int.tryParse(jenisBBM!) ?? jenisBBM);
      }

      // Filter berdasarkan bulan_terbit dan tahun_terbit LANGSUNG
      // (bukan berdasarkan tanggal berlaku)
      if (bulanTerbit != null && tahunTerbit != null) {
        whereConditions.add('dk.bulan_terbit = ? AND dk.tahun_terbit = ?');
        whereArgs.addAll([bulanTerbit, tahunTerbit]);
      } else if (tahunTerbit != null && bulanTerbit == null) {
        whereConditions.add('dk.tahun_terbit = ?');
        whereArgs.add(tahunTerbit);
      } else if (bulanTerbit != null && tahunTerbit == null) {
        whereConditions.add('dk.bulan_terbit = ?');
        whereArgs.add(bulanTerbit);
      }

      String query =
          '''
        SELECT 
          dk.kupon_key as kupon_id,
          dk.nomor_kupon,
          dk.kendaraan_id,
          dk.jenis_bbm_id,
          dk.jenis_kupon_id,
          dk.bulan_terbit,
          dk.tahun_terbit,
          dk.tanggal_mulai,
          dk.tanggal_sampai,
          dk.kuota_awal,
          (dk.kuota_awal - COALESCE(ft_sum.total_used, 0)) as kuota_sisa,
          dk.satker_id,
          ds.nama_satker,
          dk.status,
          dk.valid_from as created_at,
          CURRENT_TIMESTAMP as updated_at,
          0 as is_deleted
        FROM dim_kupon dk
        LEFT JOIN dim_kendaraan ON dk.kendaraan_id = dim_kendaraan.kendaraan_id 
        LEFT JOIN dim_satker ds ON dk.satker_id = ds.satker_id
        LEFT JOIN (
          SELECT kupon_key, SUM(jumlah_liter) as total_used
          FROM fact_transaksi
          WHERE is_deleted = 0
          GROUP BY kupon_key
        ) ft_sum ON dk.kupon_key = ft_sum.kupon_key
        WHERE ${whereConditions.join(' AND ')}
      ''';

      if (nopol != null && nopol!.isNotEmpty) {
        query +=
            ' AND (LOWER(dim_kendaraan.no_pol_kode) || \'-\' || LOWER(dim_kendaraan.no_pol_nomor)) LIKE ?';
        whereArgs.add('%${nopol!.toLowerCase().trim()}%');
      }
      if (satker != null && satker!.isNotEmpty) {
        query += ' AND LOWER(TRIM(ds.nama_satker)) LIKE ?';
        whereArgs.add('%${satker!.toLowerCase().trim()}%');
      }
      if (jenisRanmor != null && jenisRanmor!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_kendaraan.jenis_ranmor)) LIKE ?';
        whereArgs.add('%${jenisRanmor!.toLowerCase().trim()}%');
      }

      query += ' ORDER BY CAST(dk.nomor_kupon AS INTEGER) ASC';

      debugPrint('🔍 _fetchKuponsByType SQL: $query | WhereArgs: $whereArgs');

      // Update expired kupon status first
      await _updateExpiredKuponStatus();

      final results = await db.rawQuery(query, whereArgs);
      final fetchedKupons = results
          .map((map) => KuponModel.fromMap(map))
          .toList();

      debugPrint(
        '📊 _fetchKuponsByType: Jenis=$jenisKuponId, Filter: BBM=$jenisBBM, Bulan=$bulanTerbit, Tahun=$tahunTerbit, Total kupon fetched: ${fetchedKupons.length}',
      );

      if (jenisKuponId == 1) {
        _ranjenKupons = fetchedKupons;
      } else {
        _dukunganKupons = fetchedKupons;
      }

      // Update allKupons dengan data terbaru dari tipe ini + data tipe lain yang sudah ada
      _allKupons = [..._ranjenKupons, ..._dukunganKupons];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Metode publik untuk mengambil data Ranjen
  Future<void> fetchRanjenKupons({bool forceRefresh = false}) async {
    _isRanjenMode = true;
    await _fetchKuponsByType(1, forceRefresh: forceRefresh);
  }

  /// Metode publik untuk mengambil data Dukungan
  /// Set [preserveMode=true] untuk fetch Dukungan tanpa mengubah _isRanjenMode
  /// (berguna saat pre-fetching untuk dropdown tanpa mengubah UI mode)
  Future<void> fetchDukunganKupons({
    bool forceRefresh = false,
    bool preserveMode = false,
  }) async {
    if (!preserveMode) {
      _isRanjenMode = false;
    }
    await _fetchKuponsByType(2, forceRefresh: forceRefresh);
  }

  // --- Utility Methods ---

  Future<void> cleanDuplicateData() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      final duplicates = await db.rawQuery('''
        SELECT f1.kupon_key
        FROM dim_kupon f1
        INNER JOIN dim_kupon f2 
        WHERE f1.kupon_key > f2.kupon_key
        AND f1.nomor_kupon = f2.nomor_kupon
        AND f1.jenis_kupon_id = f2.jenis_kupon_id
        AND f1.satker_id = f2.satker_id
        AND f1.bulan_terbit = f2.bulan_terbit
        AND f1.tahun_terbit = f2.tahun_terbit
        AND f1.is_current = 1
        AND f2.is_current = 1
      ''');

      if (duplicates.isNotEmpty) {
        final batch = db.batch();
        for (final duplicate in duplicates) {
          batch.update(
            'dim_kupon',
            {
              'is_current': 0,
              'valid_to': DateTime.now().toIso8601String(),
              'status': 'Tidak Aktif',
            },
            where: 'kupon_key = ?',
            whereArgs: [duplicate['kupon_key']],
          );
        }

        await batch.commit(noResult: true);
        await fetchKupons(forceRefresh: true);
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> setFilter({
    String? nomorKupon,
    String? satker,
    String? jenisBBM,
    String? jenisKupon,
    String? nopol,
    String? jenisRanmor,
    int? bulanTerbit,
    int? tahunTerbit,
  }) async {
    this.nomorKupon = nomorKupon?.trim();
    this.satker = satker?.trim();
    this.jenisBBM = jenisBBM?.trim();
    this.jenisKupon = jenisKupon?.trim();
    this.nopol = nopol?.trim();
    this.jenisRanmor = jenisRanmor?.trim();
    this.bulanTerbit = bulanTerbit;
    this.tahunTerbit = tahunTerbit;

    debugPrint(
      '🎯 setFilter called: jenisKupon=$jenisKupon, BBM=$jenisBBM, Bulan=$bulanTerbit, Tahun=$tahunTerbit',
    );

    try {
      if (jenisKupon == 'Ranjen' || jenisKupon == '1') {
        _isRanjenMode = true;
        await fetchRanjenKupons(forceRefresh: true);
      } else if (jenisKupon == 'Dukungan' || jenisKupon == '2') {
        _isRanjenMode = false;
        await fetchDukunganKupons(forceRefresh: true);
      } else {
        _isRanjenMode = false;
        await fetchKupons(forceRefresh: true);
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void resetFilters() {
    nomorKupon = null;
    satker = null;
    jenisBBM = null;
    jenisKupon = null;
    nopol = null;
    jenisRanmor = null;
    bulanTerbit = null;
    tahunTerbit = null;
    _isRanjenMode = false;
    fetchKupons(forceRefresh: true);
  }

  Future<void> refreshData() async {
    if (_isRanjenMode) {
      await fetchRanjenKupons(forceRefresh: true);
    } else {
      await fetchKupons(forceRefresh: true);
    }
  }
}
