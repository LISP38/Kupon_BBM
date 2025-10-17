import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository_impl.dart';

class DashboardProvider extends ChangeNotifier {
  final KuponRepository _kuponRepository;

  // --- State Variables ---
  // Menyimpan data untuk setiap tipe kupon
  List<KuponEntity> _allKupons = [];
  List<KuponEntity> _ranjenKupons = [];
  List<KuponEntity> _dukunganKupons = [];

  // Master data lists
  List<String> _satkerList = [];

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
  bool _isRanjenMode = false;

  // --- Getters ---
  List<KuponEntity> get kupons => _allKupons;
  List<KuponEntity> get kuponList => _allKupons;
  List<KuponEntity> get ranjenKupons => _ranjenKupons;
  List<KuponEntity> get dukunganKupons => _dukunganKupons;

  // Getter khusus untuk menggabungkan semua data saat export
  List<KuponEntity> get allKuponsForExport => [..._ranjenKupons, ..._dukunganKupons];

  List<String> get satkerList => _satkerList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRanjenMode => _isRanjenMode;

  // --- Constructor ---
  DashboardProvider(this._kuponRepository);

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
      print('[DASHBOARD] Error fetching satkers: $e');
      _satkerList = [];
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

    print('[DASHBOARD] Starting fetchKupons (all types)...');
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      List<String> whereConditions = ['fact_kupon.is_deleted = 0'];
      List<dynamic> whereArgs = [];

      if (nomorKupon != null && nomorKupon!.isNotEmpty) {
        whereConditions.add('fact_kupon.nomor_kupon = ?');
        whereArgs.add(nomorKupon!);
      }
      if (jenisBBM != null && jenisBBM!.isNotEmpty) {
        whereConditions.add('fact_kupon.jenis_bbm_id = ?');
        whereArgs.add(int.tryParse(jenisBBM!) ?? jenisBBM);
      }
      if (bulanTerbit != null) {
        whereConditions.add('fact_kupon.bulan_terbit = ?');
        whereArgs.add(bulanTerbit);
      }
      if (tahunTerbit != null) {
        whereConditions.add('fact_kupon.tahun_terbit = ?');
        whereArgs.add(tahunTerbit);
      }

      String query = '''
        SELECT fact_kupon.* FROM fact_kupon 
        LEFT JOIN dim_kendaraan ON fact_kupon.kendaraan_id = dim_kendaraan.kendaraan_id 
        LEFT JOIN dim_satker ON fact_kupon.satker_id = dim_satker.satker_id
        WHERE ${whereConditions.join(' AND ')}
      ''';

      if (nopol != null && nopol!.isNotEmpty) {
        query +=
            ' AND (LOWER(dim_kendaraan.no_pol_kode) || \'-\' || LOWER(dim_kendaraan.no_pol_nomor)) LIKE ?';
        whereArgs.add('%${nopol!.toLowerCase().trim()}%');
      }
      if (satker != null && satker!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_satker.nama_satker)) LIKE ?';
        whereArgs.add('%${satker!.toLowerCase().trim()}%');
      }
      if (jenisRanmor != null && jenisRanmor!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_kendaraan.jenis_ranmor)) LIKE ?';
        whereArgs.add('%${jenisRanmor!.toLowerCase().trim()}%');
      }

      query += ' ORDER BY CAST(fact_kupon.nomor_kupon AS INTEGER) ASC';

      print('[DASHBOARD] Executing query: $query');
      print('[DASHBOARD] With args: $whereArgs');

      final results = await db.rawQuery(query, whereArgs);
      _allKupons = results.map((map) => KuponModel.fromMap(map)).toList();

      // Pisahkan data berdasarkan jenis kupon setelah mengambil semua data
      _ranjenKupons = _allKupons.where((k) => k.jenisKuponId == 1).toList();
      _dukunganKupons = _allKupons.where((k) => k.jenisKuponId == 2).toList();

      print('[DASHBOARD] fetchKupons: total = ${_allKupons.length}, ranjen = ${_ranjenKupons.length}, dukungan = ${_dukunganKupons.length}');
    } catch (e) {
      print('[DASHBOARD] Error fetching kupons: $e');
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
  Future<void> _fetchKuponsByType(int jenisKuponId, {bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final tipeName = jenisKuponId == 1 ? 'Ranjen' : 'Dukungan';
    print('[DASHBOARD] Starting fetchKupons for $tipeName...');
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      List<String> whereConditions = [
        'fact_kupon.is_deleted = 0',
        'fact_kupon.jenis_kupon_id = ?',
      ];
      List<dynamic> whereArgs = [jenisKuponId];

      if (nomorKupon != null && nomorKupon!.isNotEmpty) {
        whereConditions.add('fact_kupon.nomor_kupon = ?');
        whereArgs.add(nomorKupon!);
      }
      if (jenisBBM != null && jenisBBM!.isNotEmpty) {
        whereConditions.add('fact_kupon.jenis_bbm_id = ?');
        whereArgs.add(int.tryParse(jenisBBM!) ?? jenisBBM);
      }
      if (bulanTerbit != null) {
        whereConditions.add('fact_kupon.bulan_terbit = ?');
        whereArgs.add(bulanTerbit);
      }
      if (tahunTerbit != null) {
        whereConditions.add('fact_kupon.tahun_terbit = ?');
        whereArgs.add(tahunTerbit);
      }

      String query = '''
        SELECT fact_kupon.* FROM fact_kupon 
        LEFT JOIN dim_kendaraan ON fact_kupon.kendaraan_id = dim_kendaraan.kendaraan_id 
        LEFT JOIN dim_satker ON fact_kupon.satker_id = dim_satker.satker_id
        WHERE ${whereConditions.join(' AND ')}
      ''';

      if (nopol != null && nopol!.isNotEmpty) {
        query +=
            ' AND (LOWER(dim_kendaraan.no_pol_kode) || \'-\' || LOWER(dim_kendaraan.no_pol_nomor)) LIKE ?';
        whereArgs.add('%${nopol!.toLowerCase().trim()}%');
      }
      if (satker != null && satker!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_satker.nama_satker)) LIKE ?';
        whereArgs.add('%${satker!.toLowerCase().trim()}%');
      }
      if (jenisRanmor != null && jenisRanmor!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_kendaraan.jenis_ranmor)) LIKE ?';
        whereArgs.add('%${jenisRanmor!.toLowerCase().trim()}%');
      }

      query += ' ORDER BY CAST(fact_kupon.nomor_kupon AS INTEGER) ASC';

      final results = await db.rawQuery(query, whereArgs);
      final fetchedKupons = results.map((map) => KuponModel.fromMap(map)).toList();

      if (jenisKuponId == 1) {
        _ranjenKupons = fetchedKupons;
      } else {
        _dukunganKupons = fetchedKupons;
      }
      
      // Update allKupons dengan data terbaru dari tipe ini + data tipe lain yang sudah ada
      _allKupons = [..._ranjenKupons, ..._dukunganKupons];

      print('[DASHBOARD] fetchKupons ($tipeName): jumlah data = ${fetchedKupons.length}');
    } catch (e) {
      print('[DASHBOARD] Error fetching $tipeName kupons: $e');
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
  Future<void> fetchDukunganKupons({bool forceRefresh = false}) async {
    _isRanjenMode = false;
    await _fetchKuponsByType(2, forceRefresh: forceRefresh);
  }

  // --- Utility Methods ---

  Future<void> cleanDuplicateData() async {
    print('[DASHBOARD] Starting cleanDuplicateData...');
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    try {
      final duplicates = await db.rawQuery('''
        SELECT f1.kupon_id
        FROM fact_kupon f1
        INNER JOIN fact_kupon f2 
        WHERE f1.kupon_id > f2.kupon_id
        AND f1.nomor_kupon = f2.nomor_kupon
        AND f1.jenis_kupon_id = f2.jenis_kupon_id
        AND f1.satker_id = f2.satker_id
        AND f1.bulan_terbit = f2.bulan_terbit
        AND f1.tahun_terbit = f2.tahun_terbit
        AND f1.is_deleted = 0
        AND f2.is_deleted = 0
      ''');

      print('[DASHBOARD] Found ${duplicates.length} duplicate records');

      if (duplicates.isNotEmpty) {
        final batch = db.batch();
        for (final duplicate in duplicates) {
          batch.update(
            'fact_kupon',
            {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
            where: 'kupon_id = ?',
            whereArgs: [duplicate['kupon_id']],
          );
        }

        await batch.commit(noResult: true);
        print(
          '[DASHBOARD] Marked ${duplicates.length} duplicate records as deleted',
        );

        await fetchKupons(forceRefresh: true);
      }
    } catch (e) {
      print('[DASHBOARD] Error cleaning duplicate data: $e');
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
    print('[DASHBOARD] Setting filters...');
    this.nomorKupon = nomorKupon?.trim();
    this.satker = satker?.trim();
    this.jenisBBM = jenisBBM?.trim();
    this.jenisKupon = jenisKupon?.trim();
    this.nopol = nopol?.trim();
    this.jenisRanmor = jenisRanmor?.trim();
    this.bulanTerbit = bulanTerbit;
    this.tahunTerbit = tahunTerbit;

    try {
      if (jenisKupon == 'Ranjen' || jenisKupon == '1') {
        _isRanjenMode = true;
        print('[DASHBOARD] Fetching Ranjen kupons with filters');
        await fetchRanjenKupons(forceRefresh: true);
      } else if (jenisKupon == 'Dukungan' || jenisKupon == '2') {
        _isRanjenMode = false;
        print('[DASHBOARD] Fetching Dukungan kupons with filters');
        await fetchDukunganKupons(forceRefresh: true);
      } else {
        _isRanjenMode = false;
        print('[DASHBOARD] Fetching all kupons with filters');
        await fetchKupons(forceRefresh: true);
      }
    } catch (e) {
      print('[DASHBOARD] Error applying filters: $e');
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void resetFilters() {
    print('[DASHBOARD] Resetting filters');
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
    print('[DASHBOARD] Refreshing data...');
    if (_isRanjenMode) {
      await fetchRanjenKupons(forceRefresh: true);
    } else {
      await fetchKupons(forceRefresh: true);
    }
  }
}