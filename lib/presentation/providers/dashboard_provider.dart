import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/domain/entities/kupon_entity.dart';
import 'package:kupon_bbm_app/data/models/kupon_model.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository.dart';
import 'package:kupon_bbm_app/domain/repositories/kupon_repository_impl.dart';

class DashboardProvider extends ChangeNotifier {
  final KuponRepository _kuponRepository;

  List<KuponEntity> _kupons = [];
  List<KuponEntity> get kupons => _kupons;
  List<KuponEntity> get kuponList => _kupons;

  // Master data lists
  List<String> _satkerList = [];
  List<String> get satkerList => _satkerList;

  // Filter state
  String? nomorKupon;
  String? satker;
  String? jenisBBM;
  String? jenisKupon;
  String? nopol;
  String? jenisRanmor;
  int? bulanTerbit;
  int? tahunTerbit;

  DashboardProvider(this._kuponRepository);

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
    }
  }

  Future<void> fetchKupons() async {
    final db =
        await (_kuponRepository as KuponRepositoryImpl).dbHelper.database;

    // Build dynamic WHERE clause based on filters
    List<String> whereConditions = ['fact_kupon.is_deleted = 0'];
    List<dynamic> whereArgs = [];

    // Apply filters with proper SQL conditions
    if (nomorKupon != null && nomorKupon!.isNotEmpty) {
      whereConditions.add('fact_kupon.nomor_kupon LIKE ?');
      whereArgs.add('${nomorKupon!}%');
    }

    if (jenisKupon != null && jenisKupon!.isNotEmpty) {
      whereConditions.add('fact_kupon.jenis_kupon_id = ?');
      whereArgs.add(int.tryParse(jenisKupon!) ?? jenisKupon);
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

    // Build query with optional JOIN for nopol, satker, and jenisRanmor filters
    String query;
    if ((nopol != null && nopol!.isNotEmpty) ||
        (satker != null && satker!.isNotEmpty) ||
        (jenisRanmor != null && jenisRanmor!.isNotEmpty)) {
      // Need JOIN with dim_kendaraan and dim_satker for filtering
      query =
          '''
        SELECT fact_kupon.* FROM fact_kupon 
        LEFT JOIN dim_kendaraan ON fact_kupon.kendaraan_id = dim_kendaraan.kendaraan_id 
        LEFT JOIN dim_satker ON dim_kendaraan.satker_id = dim_satker.satker_id
        WHERE ${whereConditions.join(' AND ')}
      ''';

      if (nopol != null && nopol!.isNotEmpty) {
        query +=
            ' AND (LOWER(TRIM(COALESCE(dim_kendaraan.no_pol_kode, ""))) || "-" || LOWER(TRIM(COALESCE(dim_kendaraan.no_pol_nomor, "")))) LIKE ?';
        whereArgs.add('%${nopol!.toLowerCase().trim()}%');
      }

      if (satker != null && satker!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_satker.nama_satker)) LIKE ?';
        whereArgs.add('%${satker!.toLowerCase().trim()}%');
        print('[DASHBOARD] Satker filter value: ${satker!.toLowerCase().trim()}');
      }

      if (jenisRanmor != null && jenisRanmor!.isNotEmpty) {
        query += ' AND LOWER(TRIM(dim_kendaraan.jenis_ranmor)) LIKE ?';
        whereArgs.add('%${jenisRanmor!.toLowerCase().trim()}%');
      }
    } else {
      // Simple query without JOIN
      query = 'SELECT * FROM fact_kupon WHERE ${whereConditions.join(' AND ')}';
    }

    print('[DASHBOARD] Executing query: $query');
    print('[DASHBOARD] With args: $whereArgs');
    print('[DASHBOARD] Jenis BBM filter value: ${jenisBBM?.toLowerCase().trim()}');

    // Execute query
    final results = await db.rawQuery(query, whereArgs);

    // Convert to entities
    _kupons = results.map((map) => KuponModel.fromMap(map)).toList();

    print('[DASHBOARD] fetchKupons: jumlah data = ${_kupons.length}');
    for (final k in _kupons) {
      print(
        '[DASHBOARD] kupon: id=${k.kuponId}, nomor=${k.nomorKupon}, kendaraanId=${k.kendaraanId}, isDeleted=${k.isDeleted}, status=${k.status}',
      );
    }

    notifyListeners();
  }

  void setFilter({
    String? nomorKupon,
    String? satker,
    String? jenisBBM,
    String? jenisKupon,
    String? nopol,
    String? jenisRanmor,
    int? bulanTerbit,
    int? tahunTerbit,
  }) {
    this.nomorKupon = nomorKupon;
    this.satker = satker;
    this.jenisBBM = jenisBBM;
    this.jenisKupon = jenisKupon;
    this.nopol = nopol;
    this.jenisRanmor = jenisRanmor;
    this.bulanTerbit = bulanTerbit;
    this.tahunTerbit = tahunTerbit;
    fetchKupons();
  }
}
