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

      // Buat sheets terlebih dahulu
      excel['RAN.PX'];
      excel['DUK.PX'];
      excel['RAN.DX'];
      excel['DUK.DX'];

      // Hapus sheet default setelah membuat sheet baru
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

      // Buat sheets dalam urutan yang benar
      _createRanjenSheet(
        excel,
        'RAN.PX',
        ranPertamax,
        getNopolByKendaraanId,
        getJenisRanmorByKendaraanId,
      );
      _createDukunganSheet(excel, 'DUK.PX', dukPertamax);
      _createRanjenSheet(
        excel,
        'RAN.DX',
        ranDex,
        getNopolByKendaraanId,
        getJenisRanmorByKendaraanId,
      );
      _createDukunganSheet(excel, 'DUK.DX', dukDex);

      // Save file
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Data Kupon',
        fileName: 'Data_Kupon_$timestamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(excel.encode()!);
        return true;
      }
      return false;
    } catch (e) {
      // Logger akan ditambahkan jika diperlukan
      return false;
    }
  }

  // Export Data Satker (2 sheets: REKAP.PX, REKAP.DX)
  static Future<bool> exportDataSatker({
    required List<KuponEntity> allKupons,
    required Map<int, String> jenisBBMMap,
  }) async {
    try {
      final excel = Excel.createExcel();

      // Buat sheets terlebih dahulu
      excel['REKAP.PX'];
      excel['REKAP.DX'];

      // Hapus sheet default setelah membuat sheet baru
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      _createRekapSheet(excel, 'REKAP.PX', allKupons, 1); // Pertamax
      _createRekapSheet(excel, 'REKAP.DX', allKupons, 2); // Pertamina Dex

      // Save file
      final now = DateTime.now();
      final timestamp =
          '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Data Satker',
        fileName: 'Data_Satker_$timestamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsBytes(excel.encode()!);
        return true;
      }
      return false;
    } catch (e) {
      // Logger akan ditambahkan jika diperlukan
      return false;
    }
  }

  // Buat sheet Ranjen dengan format 3 baris header yang bersih
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

    // BARIS 1: Header periode - merge dari A1 sampai kolom terakhir
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'PERIODE $currentMonth-$currentYear',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blue700,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Medium),
      topBorder: Border(borderStyle: BorderStyle.Medium),
      leftBorder: Border(borderStyle: BorderStyle.Medium),
      rightBorder: Border(borderStyle: BorderStyle.Medium),
    );
    // Merge cells A1 sampai kolom terakhir untuk periode
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByColumnRow(columnIndex: 69, rowIndex: 0),
    );

    // BARIS 2: Header kolom utama
    final headers = [
      'NO',
      'JENIS RANMOR',
      'NOMOR POLISI',
      'SATKER',
      'KUOTA',
      'PEMAKAIAN',
      'SALDO',
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.blue600,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
      // Merge header utama sampai baris 3 agar tidak bentrok dengan tanggal
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
      );
    }

    // Header bulan 1 - merge dari kolom 7 sampai 38
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1)).value =
        TextCellValue('BULAN $currentMonth-$currentYear');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.green600,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 38, rowIndex: 1),
    );

    // Header bulan 2 - merge dari kolom 39 sampai 70
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 39, rowIndex: 1)).value =
        TextCellValue('BULAN $nextMonth-$nextYear');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 39, rowIndex: 1))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.green600,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 39, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 70, rowIndex: 1),
    );

    // BARIS 3: Tanggal 1-31 untuk kedua bulan
    // Bulan 1: kolom 7-38 (H-AM)
    for (int i = 1; i <= 31; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 6 + i, rowIndex: 2),
      );
      cell.value = IntCellValue(i);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.green100,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // Bulan 2: kolom 39-70 (AN-BS)
    for (int i = 1; i <= 31; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 38 + i, rowIndex: 2),
      );
      cell.value = IntCellValue(i);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.green100,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // DATA: mulai dari baris 4
    for (int i = 0; i < kupons.length; i++) {
      final kupon = kupons[i];
      final row = i + 3;
      final isEvenRow = (i % 2) == 0;

      // Kolom NO
      final noCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      noCell.value = IntCellValue(i + 1);
      noCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom JENIS RANMOR
      final ranmorCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
      );
      ranmorCell.value = TextCellValue(
        getJenisRanmorByKendaraanId(kupon.kendaraanId).toString(),
      );
      ranmorCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom NOMOR POLISI (gabungan nopol dan kode wilayah)
      final nopol = getNopolByKendaraanId(kupon.kendaraanId).toString();
      final nopolCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
      );
      nopolCell.value = TextCellValue(nopol);
      nopolCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom SATKER
      final satkerCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
      );
      satkerCell.value = TextCellValue(kupon.namaSatker);
      satkerCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom KUOTA
      final kuotaCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      kuotaCell.value = DoubleCellValue(kupon.kuotaAwal);
      kuotaCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.standard_2,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom PEMAKAIAN (kosong untuk input manual)
      final pemakaiianCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row),
      );
      pemakaiianCell.value = TextCellValue('');
      pemakaiianCell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.yellow100,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom SALDO
      final saldoCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row),
      );
      saldoCell.value = DoubleCellValue(kupon.kuotaSisa);
      saldoCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.standard_2,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom tanggal kosong (untuk input manual pemakaian harian)
      for (int col = 7; col <= 70; col++) {
        final dateCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        dateCell.value = TextCellValue('');
        dateCell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.white,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
    }
  }

  // Buat sheet Dukungan dengan format yang sama
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

    // BARIS 1: Header periode - merge dari A1 sampai kolom terakhir
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'PERIODE $currentMonth-$currentYear',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blue700,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Medium),
      topBorder: Border(borderStyle: BorderStyle.Medium),
      leftBorder: Border(borderStyle: BorderStyle.Medium),
      rightBorder: Border(borderStyle: BorderStyle.Medium),
    );
    // Merge cells A1 sampai kolom terakhir untuk periode
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByColumnRow(columnIndex: 69, rowIndex: 0),
    );

    // BARIS 2: Header kolom untuk Dukungan - pisahkan Pemakaian dan Saldo
    final headers = ['NO', 'SATKER', 'KUOTA', 'PEMAKAIAN', 'SALDO'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.blue600,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
      // Merge header utama sampai baris 3 agar tidak bentrok dengan tanggal
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2),
      );
    }

    // Header bulan 1 - merge dari kolom F sampai AK (5-36)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1)).value =
        TextCellValue('BULAN $currentMonth-$currentYear');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.green600,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 36, rowIndex: 1),
    );

    // Header bulan 2 - merge dari kolom AL sampai BP (37-69)
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 37, rowIndex: 1)).value =
        TextCellValue('BULAN $nextMonth-$nextYear');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 37, rowIndex: 1))
        .cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.green600,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 37, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 69, rowIndex: 1),
    );

    // BARIS 3: Tanggal 1-31 untuk kedua bulan
    // Bulan 1: kolom 5-36 (F-AK)
    for (int i = 1; i <= 31; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 4 + i, rowIndex: 2),
      );
      cell.value = IntCellValue(i);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.green100,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // Bulan 2: kolom 37-69 (AL-BP)
    for (int i = 1; i <= 31; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 36 + i, rowIndex: 2),
      );
      cell.value = IntCellValue(i);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 10,
        backgroundColorHex: ExcelColor.green100,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // DATA: mulai dari baris 4
    for (int i = 0; i < kupons.length; i++) {
      final kupon = kupons[i];
      final row = i + 3;
      final isEvenRow = (i % 2) == 0;

      // Kolom NO
      final noCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      noCell.value = IntCellValue(i + 1);
      noCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom SATKER
      final satkerCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row),
      );
      satkerCell.value = TextCellValue(kupon.namaSatker);
      satkerCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom KUOTA
      final kuotaCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row),
      );
      kuotaCell.value = DoubleCellValue(kupon.kuotaAwal);
      kuotaCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.standard_2,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom PEMAKAIAN (kosong - untuk input manual)
      final pemakaiianCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
      );
      pemakaiianCell.value = TextCellValue('');
      pemakaiianCell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.yellow100,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom SALDO
      final saldoCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      saldoCell.value = DoubleCellValue(kupon.kuotaSisa);
      saldoCell.cellStyle = CellStyle(
        backgroundColorHex: isEvenRow ? ExcelColor.blue50 : ExcelColor.white,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        numberFormat: NumFormat.standard_2,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );

      // Kolom tanggal kosong (untuk input manual pemakaian harian)
      for (int col = 5; col <= 69; col++) {
        final dateCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        dateCell.value = TextCellValue('');
        dateCell.cellStyle = CellStyle(
          backgroundColorHex: ExcelColor.white,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          bottomBorder: Border(borderStyle: BorderStyle.Thin),
          topBorder: Border(borderStyle: BorderStyle.Thin),
          leftBorder: Border(borderStyle: BorderStyle.Thin),
          rightBorder: Border(borderStyle: BorderStyle.Thin),
        );
      }
    }
  }

  // Buat sheet rekap satker
  static void _createRekapSheet(
    Excel excel,
    String sheetName,
    List<KuponEntity> allKupons,
    int jenisBbmId,
  ) {
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // BARIS 1: Header periode - merge dari A1 sampai kolom terakhir
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'PERIODE $currentMonth-$currentYear',
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blue700,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Medium),
      topBorder: Border(borderStyle: BorderStyle.Medium),
      leftBorder: Border(borderStyle: BorderStyle.Medium),
      rightBorder: Border(borderStyle: BorderStyle.Medium),
    );
    // Merge cells A1 sampai kolom D untuk periode
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0),
    );

    // Filter berdasarkan jenis BBM
    final kupons = allKupons.where((k) => k.jenisBbmId == jenisBbmId).toList();

    // Group by satker untuk Ranjen (jenisKuponId == 1)
    final satkerMap = <String, List<KuponEntity>>{};
    // Group by satker untuk Dukungan (jenisKuponId == 2)
    final dukunganMap = <String, List<KuponEntity>>{};

    for (final kupon in kupons) {
      final satker = kupon.namaSatker;
      if (kupon.jenisKuponId == 1) {
        // Ranjen
        if (!satkerMap.containsKey(satker)) {
          satkerMap[satker] = [];
        }
        satkerMap[satker]!.add(kupon);
      } else if (kupon.jenisKuponId == 2) {
        // Dukungan
        if (!dukunganMap.containsKey(satker)) {
          dukunganMap[satker] = [];
        }
        dukunganMap[satker]!.add(kupon);
      }
    }

    // BARIS 2: Header kolom dengan styling yang konsisten
    final headers = ['SATKER', 'KUOTA', 'PEMAKAIAN', 'SALDO'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.blue600,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: Border(borderStyle: BorderStyle.Thin),
        topBorder: Border(borderStyle: BorderStyle.Thin),
        leftBorder: Border(borderStyle: BorderStyle.Thin),
        rightBorder: Border(borderStyle: BorderStyle.Thin),
      );
    }

    // Data dengan styling yang konsisten
    int rowIndex = 2;
    double grandTotalKuota = 0;
    double grandTotalPemakaian = 0;
    double grandTotalSaldo = 0;

    // DATA SATKER RANJEN
    satkerMap.forEach((satker, kuponList) {
      final totalKuota = kuponList.fold<double>(
        0,
        (sum, k) => sum + k.kuotaAwal,
      );
      final totalSisa = kuponList.fold<double>(
        0,
        (sum, k) => sum + k.kuotaSisa,
      );
      final totalPemakaian = totalKuota - totalSisa;
      final isEvenRow = (rowIndex % 2) == 0;

      grandTotalKuota += totalKuota;
      grandTotalPemakaian += totalPemakaian;
      grandTotalSaldo += totalSisa;

      _addSatkerRow(
        sheet,
        rowIndex,
        satker,
        totalKuota,
        totalPemakaian,
        totalSisa,
        isEvenRow,
        false,
      );
      rowIndex++;
    });

    // SUBTOTAL RANJEN (jika ada data ranjen)
    if (satkerMap.isNotEmpty) {
      final subtotalKuota = satkerMap.values
          .expand((e) => e)
          .fold<double>(0, (sum, k) => sum + k.kuotaAwal);
      final subtotalSisa = satkerMap.values
          .expand((e) => e)
          .fold<double>(0, (sum, k) => sum + k.kuotaSisa);
      final subtotalPemakaian = subtotalKuota - subtotalSisa;

      _addSatkerRow(
        sheet,
        rowIndex,
        'SUBTOTAL RANJEN',
        subtotalKuota,
        subtotalPemakaian,
        subtotalSisa,
        false,
        true,
      );
      rowIndex++;
    }

    // DATA DUKUNGAN
    dukunganMap.forEach((satker, kuponList) {
      final totalKuota = kuponList.fold<double>(
        0,
        (sum, k) => sum + k.kuotaAwal,
      );
      final totalSisa = kuponList.fold<double>(
        0,
        (sum, k) => sum + k.kuotaSisa,
      );
      final totalPemakaian = totalKuota - totalSisa;
      final isEvenRow = (rowIndex % 2) == 0;

      grandTotalKuota += totalKuota;
      grandTotalPemakaian += totalPemakaian;
      grandTotalSaldo += totalSisa;

      _addSatkerRow(
        sheet,
        rowIndex,
        satker,
        totalKuota,
        totalPemakaian,
        totalSisa,
        isEvenRow,
        false,
      );
      rowIndex++;
    });

    // SUBTOTAL DUKUNGAN (jika ada data dukungan)
    if (dukunganMap.isNotEmpty) {
      final subtotalKuota = dukunganMap.values
          .expand((e) => e)
          .fold<double>(0, (sum, k) => sum + k.kuotaAwal);
      final subtotalSisa = dukunganMap.values
          .expand((e) => e)
          .fold<double>(0, (sum, k) => sum + k.kuotaSisa);
      final subtotalPemakaian = subtotalKuota - subtotalSisa;

      _addSatkerRow(
        sheet,
        rowIndex,
        'SUBTOTAL DUKUNGAN',
        subtotalKuota,
        subtotalPemakaian,
        subtotalSisa,
        false,
        true,
      );
      rowIndex++;
    }

    // GRAND TOTAL
    _addSatkerRow(
      sheet,
      rowIndex,
      'GRAND TOTAL',
      grandTotalKuota,
      grandTotalPemakaian,
      grandTotalSaldo,
      false,
      true,
    );
  }

  // Helper method untuk menambah baris satker
  static void _addSatkerRow(
    Sheet sheet,
    int rowIndex,
    String satkerName,
    double kuota,
    double pemakaian,
    double saldo,
    bool isEvenRow,
    bool isSubtotal,
  ) {
    final bgColor = isSubtotal
        ? ExcelColor.green200
        : (isEvenRow ? ExcelColor.blue50 : ExcelColor.white);
    final fontWeight = isSubtotal;

    // Kolom SATKER
    final satkerCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
    );
    satkerCell.value = TextCellValue(satkerName);
    satkerCell.cellStyle = CellStyle(
      bold: fontWeight,
      backgroundColorHex: bgColor,
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Kolom KUOTA
    final kuotaCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
    );
    kuotaCell.value = DoubleCellValue(kuota);
    kuotaCell.cellStyle = CellStyle(
      bold: fontWeight,
      backgroundColorHex: bgColor,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_2,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Kolom PEMAKAIAN
    final pemakaiianCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
    );
    pemakaiianCell.value = DoubleCellValue(pemakaian);
    pemakaiianCell.cellStyle = CellStyle(
      bold: fontWeight,
      backgroundColorHex: isSubtotal
          ? ExcelColor.orange200
          : ExcelColor.yellow100,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_2,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Kolom SALDO
    final saldoCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
    );
    saldoCell.value = DoubleCellValue(saldo);
    saldoCell.cellStyle = CellStyle(
      bold: fontWeight,
      backgroundColorHex: bgColor,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: NumFormat.standard_2,
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
    );
  }
}
