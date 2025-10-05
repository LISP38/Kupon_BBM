import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../../domain/entities/kupon_entity.dart';

class ExportService {
  // Export Data Kupon (4 sheets: RAN.PX, DUK.PX, RAN.DX, DUK.DX)
  static Future<bool> exportDataKupon({
    required List<KuponEntity> allKupons,
    required Map<int, String> jenisBBMMap,
    required Function(int?) getNopolByKendaraanId,
    required Function(int?) getJenisRanmorByKendaraanId,
  }) async {
    try {
      final excel = Excel.createExcel();
      
      // Hapus sheet default yang kosong
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Filter data berdasarkan jenis kupon dan BBM
      final ranPertamax = allKupons
          .where((k) => k.jenisKuponId == 1 && k.jenisBbmId == 1)
          .toList();
      final dukPertamax = allKupons
          .where((k) => k.jenisKuponId == 2 && k.jenisBbmId == 1)
          .toList();
      final ranDex = allKupons
          .where((k) => k.jenisKuponId == 1 && k.jenisBbmId == 2)
          .toList();
      final dukDex = allKupons
          .where((k) => k.jenisKuponId == 2 && k.jenisBbmId == 2)
          .toList();

      // Buat sheet RAN.PX
      if (ranPertamax.isNotEmpty) {
        _createRanjenSheet(
          excel,
          'RAN.PX',
          ranPertamax,
          getNopolByKendaraanId,
          getJenisRanmorByKendaraanId,
        );
      }

      // Buat sheet DUK.PX
      if (dukPertamax.isNotEmpty) {
        _createDukunganSheet(excel, 'DUK.PX', dukPertamax);
      }

      // Buat sheet RAN.DX
      if (ranDex.isNotEmpty) {
        _createRanjenSheet(
          excel,
          'RAN.DX',
          ranDex,
          getNopolByKendaraanId,
          getJenisRanmorByKendaraanId,
        );
      }

      // Buat sheet DUK.DX
      if (dukDex.isNotEmpty) {
        _createDukunganSheet(excel, 'DUK.DX', dukDex);
      }

      return await _saveExcelFile(excel, 'Data_Kupon');
    } catch (e) {
      print('Error in exportDataKupon: $e');
      return false;
    }
  }

  // Export Data Satker (2 sheets: REKAP.PX, REKAP.DX)
  static Future<bool> exportDataSatker({
    required List<KuponEntity> allKupons,
    required List<String> satkerList,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      // Buat rekap untuk Pertamax
      _createRekapSatkerSheet(excel, 'REKAP.PX', allKupons, satkerList, 1);

      // Buat rekap untuk Pertamina Dex
      _createRekapSatkerSheet(excel, 'REKAP.DX', allKupons, satkerList, 2);

      return await _saveExcelFile(excel, 'Data_Satker');
    } catch (e) {
      print('Error in exportDataSatker: $e');
      return false;
    }
  }

  static void _createRanjenSheet(
    Excel excel,
    String sheetName,
    List<KuponEntity> kupons,
    Function(int?) getNopolByKendaraanId,
    Function(int?) getJenisRanmorByKendaraanId,
  ) {
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
    final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;

    // BARIS 1: Header utama periode (merged across all columns)
    sheet.cell(CellIndex.indexByString('A1')).value = 
        TextCellValue('PERIODE $currentMonth-$currentYear s/d $nextMonth-$nextYear');

    // BARIS 2: Header kolom utama + header bulan
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('NO');
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue('JENIS RANMOR');
    sheet.cell(CellIndex.indexByString('C2')).value = TextCellValue('NO POL');
    sheet.cell(CellIndex.indexByString('D2')).value = TextCellValue('KODE');
    sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue('SATKER');
    sheet.cell(CellIndex.indexByString('F2')).value = TextCellValue('KUOTA');
    sheet.cell(CellIndex.indexByString('G2')).value = TextCellValue('PEMAKAIAN ALD');
    
    // Header bulan 1 (dimulai dari kolom H)
    sheet.cell(CellIndex.indexByString('H2')).value = 
        TextCellValue('BULAN $currentMonth-$currentYear');
    
    // Header bulan 2 (dimulai dari kolom AM = 39)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 38, rowIndex: 1)).value = 
        TextCellValue('BULAN $nextMonth-$nextYear');

    // BARIS 3: Tanggal 1-31 untuk kedua bulan
    // Tanggal untuk bulan 1 (kolom H sampai AL = 7-37)
    int col = 7; // Kolom H = index 7
    for (int i = 1; i <= 31; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2)).value = IntCellValue(i);
      col++;
    }
    
    // Tanggal untuk bulan 2 (kolom AM sampai BQ = 38-68)
    col = 38; // Kolom AM = index 38
    for (int i = 1; i <= 31; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2)).value = IntCellValue(i);
      col++;
    }

    // Styling headers
    // Baris 1: Header periode - bold, warna biru gelap
    final cell1 = sheet.cell(CellIndex.indexByString('A1'));
    cell1.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue300,
    );
    
    // Baris 2: Header kolom - bold, warna biru sedang  
    for (int i = 0; i < 69; i++) { 
      final cell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell2.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue200,
      );
    }
    
    // Baris 3: Header tanggal - bold, warna biru muda
    for (int i = 7; i < 69; i++) { 
      final cell3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell3.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue100,
      );
    }

    // Data rows mulai dari baris ke-4 (index 3)
    for (int i = 0; i < kupons.length; i++) {
      final kupon = kupons[i];
      final row = i + 3; // Mulai dari baris ke-4
      
      // Kolom A: NO
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(i + 1);
      
      // Kolom B: JENIS RANMOR
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = 
          TextCellValue(getJenisRanmorByKendaraanId(kupon.kendaraanId).toString());
      
      // Kolom C & D: NO POL dan KODE (split nomor polisi)
      final nopol = getNopolByKendaraanId(kupon.kendaraanId).toString();
      final nopolParts = nopol.split('-');
      if (nopolParts.length >= 2) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(nopolParts[0]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue(nopolParts[1]);
      } else {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(nopol);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = TextCellValue('');
      }
      
      // Kolom E: SATKER
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue(kupon.namaSatker);
      
      // Kolom F: KUOTA
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = DoubleCellValue(kupon.kuotaAwal);
      
      // Kolom 6: PEMAKAIAN ALD (kosong untuk saat ini)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue('');
      
      // Kolom 7-68: Tanggal pemakaian (kosong untuk saat ini)
      for (int day = 7; day < 69; day++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: day, rowIndex: row)).value = TextCellValue('');
      }
    }

    // Header sesuai gambar
    final headers = [
      'NO',
      'JENIS RANMOR',
      'NO POL',
      'KODE',
      'SATKER',
      'KUOTA',
      'PEMAKAIAN ALD',
      // Periode 2 bulan - bulan sekarang dan selanjutnya
      'BULAN 10 - 2025',
      'BULAN 11 - 2025',
    ];

    // Tambahkan hari untuk periode
    for (int day = 1; day <= 31; day++) {
      headers.add(day.toString());
    }

    // Set headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue200,
      );
    }

    // Isi data
    for (int i = 0; i < kupons.length; i++) {
      final kupon = kupons[i];
      final row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = IntCellValue(
        i + 1,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        getJenisRanmorByKendaraanId(kupon.kendaraanId),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(
        getNopolByKendaraanId(kupon.kendaraanId),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(
        kupon.nomorKupon,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(
        kupon.namaSatker,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = DoubleCellValue(
        kupon.kuotaAwal,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = DoubleCellValue(
        kupon.kuotaAwal - kupon.kuotaSisa,
      );

      // Kolom periode bulan (kosong untuk sekarang, bisa diisi manual)
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = TextCellValue(
        '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          .value = TextCellValue(
        '',
      );

      // Kolom hari (kosong untuk tracking harian)
      for (int day = 9; day < 9 + 31; day++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: day, rowIndex: row))
            .value = TextCellValue(
          '',
        );
      }
    }

    // Auto-fit columns
    for (int col = 0; col < headers.length; col++) {
      sheet.setColumnAutoFit(col);
    }
  }

  static void _createDukunganSheet(
    Excel excel,
    String sheetName,
    List<KuponEntity> kupons,
  ) {
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final nextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
    final nextYear = currentMonth == 12 ? currentYear + 1 : currentYear;

    // Baris 1: Header utama periode
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = 
        TextCellValue('PERIODE $currentMonth-$currentYear s/d $nextMonth-$nextYear');

    // Baris 2: Header kolom utama untuk Dukungan (tanpa NO POL dan JENIS RANMOR)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = TextCellValue('NO');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1)).value = TextCellValue('KODE');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1)).value = TextCellValue('SATKER');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1)).value = TextCellValue('KUOTA');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1)).value = TextCellValue('PEMAKAIAN ALD');
    
    // Header untuk bulan pertama (mulai kolom 5)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value = 
        TextCellValue('BULAN $currentMonth - $currentYear');
    
    // Header untuk bulan kedua (mulai kolom 36 = 5 + 31)
    final bulan2Start = 36;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: bulan2Start, rowIndex: 1)).value = 
        TextCellValue('BULAN $nextMonth - $nextYear');

    // Baris 3: Tanggal 1-31 untuk kedua bulan
    // Tanggal untuk bulan 1 (kolom 5-35)
    int col = 5;
    for (int i = 1; i <= 31; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: 2)).value = IntCellValue(i);
    }
    for (int i = 1; i <= 31; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: 2)).value = IntCellValue(i);
    }

    // Styling headers
    // Baris 1: Header utama periode
    final cell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    cell1.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.green300,
    );
    
    // Baris 2: Header kolom utama
    for (int i = 0; i < 67; i++) { // 0-4 untuk kolom utama, 5-35 bulan 1, 36-66 bulan 2
      final cell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1));
      cell2.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.green200,
      );
    }
    
    // Baris 3: Header tanggal
    for (int i = 5; i < 67; i++) { // Hanya untuk kolom tanggal
      final cell3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell3.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.green100,
      );
    }

    // Data rows mulai dari baris ke-4 (index 3) untuk Dukungan
    for (int i = 0; i < kupons.length; i++) {
      final kupon = kupons[i];
      final row = i + 3;
      
      // Kolom 0: NO
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(i + 1);
      
      // Kolom 1: KODE (nomor kupon)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(kupon.nomorKupon);
      
      // Kolom 2: SATKER
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(kupon.namaSatker);
      
      // Kolom 3: KUOTA
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(kupon.kuotaAwal);
      
      // Kolom 4: PEMAKAIAN ALD (kosong untuk saat ini)
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = TextCellValue('');
      
      // Kolom 5-66: Tanggal pemakaian (kosong untuk saat ini)
      for (int day = 5; day < 67; day++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: day, rowIndex: row)).value = TextCellValue('');
      }
    }

    // Auto-fit columns  
    for (int i = 0; i < 67; i++) {
      sheet.setColumnAutoFit(i);
    }
  }

  static void _createRekapSatkerSheet(
    Excel excel,
    String sheetName,
    List<KuponEntity> allKupons,
    List<String> satkerList,
    int jenisBbmId,
  ) {
    final sheet = excel[sheetName];

    // Filter kupon berdasarkan jenis BBM
    final kuponsFiltered = allKupons
        .where((k) => k.jenisBbmId == jenisBbmId)
        .toList();

    // Header
    final headers = [
      'NO',
      'SATKER',
      'TOTAL KUPON RANJEN',
      'TOTAL KUPON DUKUNGAN',
      'TOTAL KUOTA',
      'TOTAL PEMAKAIAN',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.orange200,
      );
    }

    // Rekap per satker
    for (int i = 0; i < satkerList.length; i++) {
      final satker = satkerList[i];
      final satkerKupons = kuponsFiltered
          .where((k) => k.namaSatker == satker)
          .toList();

      if (satkerKupons.isNotEmpty) {
        final row = i + 1;
        final ranjenCount = satkerKupons
            .where((k) => k.jenisKuponId == 1)
            .length;
        final dukunganCount = satkerKupons
            .where((k) => k.jenisKuponId == 2)
            .length;
        final totalKuota = satkerKupons.fold<double>(
          0,
          (sum, k) => sum + k.kuotaAwal,
        );
        final totalPemakaian = satkerKupons.fold<double>(
          0,
          (sum, k) => sum + (k.kuotaAwal - k.kuotaSisa),
        );

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(
          i + 1,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(
          satker,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = IntCellValue(
          ranjenCount,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = IntCellValue(
          dukunganCount,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = DoubleCellValue(
          totalKuota,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = DoubleCellValue(
          totalPemakaian,
        );
      }
    }

    // Auto-fit columns
    for (int col = 0; col < headers.length; col++) {
      sheet.setColumnAutoFit(col);
    }
  }

  static Future<bool> _saveExcelFile(Excel excel, String fileName) async {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan file Excel',
        fileName: '${fileName}_$timestamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        final fileBytes = excel.save();
        if (fileBytes != null) {
          final file = File(outputFile);
          await file.writeAsBytes(fileBytes);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error saving file: $e');
      return false;
    }
  }

  static Future<bool> exportKuponsToExcel({
    required List<KuponEntity> kupons,
    required String jenisData, // 'Ranjen' atau 'Dukungan'
    required Map<int, String> jenisBBMMap,
    required Function(int?) getNopolByKendaraanId,
    required Function(int?) getJenisRanmorByKendaraanId,
  }) async {
    try {
      // Buat Excel workbook baru
      final excel = Excel.createExcel();

      // Hapus sheet default
      excel.delete('Sheet1');

      // Buat sheet baru dengan nama sesuai jenis data
      final sheet = excel[jenisData];

      // Header untuk data Ranjen
      if (jenisData == 'Ranjen') {
        sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No');
        sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
          'Nomor Kupon',
        );
        sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
          'Satker',
        );
        sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
          'Jenis BBM',
        );
        sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
          'NoPol',
        );
        sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue(
          'Jenis Ranmor',
        );
        sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue(
          'Bulan/Tahun',
        );
        sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue(
          'Kuota Awal (L)',
        );
        sheet.cell(CellIndex.indexByString('I1')).value = TextCellValue(
          'Kuota Sisa (L)',
        );
        sheet.cell(CellIndex.indexByString('J1')).value = TextCellValue(
          'Status',
        );
      }
      // Header untuk data Dukungan
      else {
        sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No');
        sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
          'Nomor Kupon',
        );
        sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
          'Satker',
        );
        sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
          'Jenis BBM',
        );
        sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
          'Bulan/Tahun',
        );
        sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue(
          'Kuota Awal (L)',
        );
        sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue(
          'Kuota Sisa (L)',
        );
        sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue(
          'Status',
        );
      }

      // Styling untuk header
      for (int col = 0; col < (jenisData == 'Ranjen' ? 10 : 8); col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.blue200,
        );
      }

      // Isi data
      for (int i = 0; i < kupons.length; i++) {
        final kupon = kupons[i];
        final row = i + 1; // Mulai dari baris ke-2 (index 1)

        if (jenisData == 'Ranjen') {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value = IntCellValue(
            i + 1,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value = TextCellValue(
            '${kupon.nomorKupon}/${kupon.bulanTerbit}/${kupon.tahunTerbit}/LOGISTIK',
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value = TextCellValue(
            kupon.namaSatker,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
              .value = TextCellValue(
            jenisBBMMap[kupon.jenisBbmId] ?? kupon.jenisBbmId.toString(),
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
              .value = TextCellValue(
            getNopolByKendaraanId(kupon.kendaraanId),
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
              .value = TextCellValue(
            getJenisRanmorByKendaraanId(kupon.kendaraanId),
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
              .value = TextCellValue(
            '${kupon.bulanTerbit}/${kupon.tahunTerbit}',
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
              .value = DoubleCellValue(
            kupon.kuotaAwal,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
              .value = DoubleCellValue(
            kupon.kuotaSisa,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
              .value = TextCellValue(
            kupon.status,
          );
        } else {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
              .value = IntCellValue(
            i + 1,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
              .value = TextCellValue(
            '${kupon.nomorKupon}/${kupon.bulanTerbit}/${kupon.tahunTerbit}/LOGISTIK',
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
              .value = TextCellValue(
            kupon.namaSatker,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
              .value = TextCellValue(
            jenisBBMMap[kupon.jenisBbmId] ?? kupon.jenisBbmId.toString(),
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
              .value = TextCellValue(
            '${kupon.bulanTerbit}/${kupon.tahunTerbit}',
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
              .value = DoubleCellValue(
            kupon.kuotaAwal,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
              .value = DoubleCellValue(
            kupon.kuotaSisa,
          );
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
              .value = TextCellValue(
            kupon.status,
          );
        }
      }

      // Auto-fit columns
      for (int col = 0; col < (jenisData == 'Ranjen' ? 10 : 8); col++) {
        sheet.setColumnAutoFit(col);
      }

      // Generate file dengan timestamp
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.year}'
          '_${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';

      final fileName = 'Export_Data_${jenisData}_$timestamp.xlsx';

      // Biarkan user memilih lokasi penyimpanan
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        // Encode Excel ke bytes
        final excelBytes = excel.encode();

        // Tulis ke file
        final file = File(outputFile);
        await file.writeAsBytes(excelBytes!);

        return true;
      }

      return false;
    } catch (e) {
      print('Error saat export: $e');
      return false;
    }
  }

  static Future<bool> exportAllDataToExcel({
    required List<KuponEntity> allKupons,
    required Map<int, String> jenisBBMMap,
    required Map<int, String> jenisKuponMap,
    required Function(int?) getNopolByKendaraanId,
    required Function(int?) getJenisRanmorByKendaraanId,
  }) async {
    try {
      // Buat Excel workbook baru
      final excel = Excel.createExcel();

      // Hapus sheet default
      excel.delete('Sheet1');

      // Buat sheet untuk semua data
      final sheet = excel['Semua Data Kupon'];

      // Header
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('No');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
        'Nomor Kupon',
      );
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Satker');
      sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
        'Jenis BBM',
      );
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
        'Jenis Kupon',
      );
      sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('NoPol');
      sheet.cell(CellIndex.indexByString('G1')).value = TextCellValue(
        'Jenis Ranmor',
      );
      sheet.cell(CellIndex.indexByString('H1')).value = TextCellValue(
        'Bulan/Tahun',
      );
      sheet.cell(CellIndex.indexByString('I1')).value = TextCellValue(
        'Kuota Awal (L)',
      );
      sheet.cell(CellIndex.indexByString('J1')).value = TextCellValue(
        'Kuota Sisa (L)',
      );
      sheet.cell(CellIndex.indexByString('K1')).value = TextCellValue('Status');

      // Styling untuk header
      for (int col = 0; col < 11; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.blue200,
        );
      }

      // Isi data
      for (int i = 0; i < allKupons.length; i++) {
        final kupon = allKupons[i];
        final row = i + 1;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = IntCellValue(
          i + 1,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = TextCellValue(
          '${kupon.nomorKupon}/${kupon.bulanTerbit}/${kupon.tahunTerbit}/LOGISTIK',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = TextCellValue(
          kupon.namaSatker,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = TextCellValue(
          jenisBBMMap[kupon.jenisBbmId] ?? kupon.jenisBbmId.toString(),
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = TextCellValue(
          jenisKuponMap[kupon.jenisKuponId] ?? kupon.jenisKuponId.toString(),
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = TextCellValue(
          getNopolByKendaraanId(kupon.kendaraanId),
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = TextCellValue(
          getJenisRanmorByKendaraanId(kupon.kendaraanId),
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = TextCellValue(
          '${kupon.bulanTerbit}/${kupon.tahunTerbit}',
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = DoubleCellValue(
          kupon.kuotaAwal,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = DoubleCellValue(
          kupon.kuotaSisa,
        );
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
            .value = TextCellValue(
          kupon.status,
        );
      }

      // Auto-fit columns
      for (int col = 0; col < 11; col++) {
        sheet.setColumnAutoFit(col);
      }

      // Generate file dengan timestamp
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.year}'
          '_${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';

      final fileName = 'Export_Semua_Data_Kupon_$timestamp.xlsx';

      // Biarkan user memilih lokasi penyimpanan
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan File Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        // Encode Excel ke bytes
        final excelBytes = excel.encode();

        // Tulis ke file
        final file = File(outputFile);
        await file.writeAsBytes(excelBytes!);

        return true;
      }

      return false;
    } catch (e) {
      print('Error saat export: $e');
      return false;
    }
  }
}
