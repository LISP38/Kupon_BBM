import 'package:flutter/material.dart';
import '../../../data/models/kupon_model.dart';
import '../../../data/models/kendaraan_model.dart';
import '../../../data/datasources/excel_datasource.dart';

class ImportPreviewItem {
  final KuponModel kupon;
  final KendaraanModel? kendaraan; // Nullable untuk kupon DUKUNGAN
  final bool isDuplicate;
  final String status;

  ImportPreviewItem({
    required this.kupon,
    required this.kendaraan,
    required this.isDuplicate,
    required this.status,
  });
}

class ImportPreviewPage extends StatelessWidget {
  final ExcelParseResult parseResult;
  final String fileName;
  final VoidCallback onConfirmImport;
  final VoidCallback onCancel;

  const ImportPreviewPage({
    Key? key,
    required this.parseResult,
    required this.fileName,
    required this.onConfirmImport,
    required this.onCancel,
  }) : super(key: key);

  List<ImportPreviewItem> _buildPreviewItems() {
    final items = <ImportPreviewItem>[];

    // Add new items
    for (int i = 0; i < parseResult.kupons.length; i++) {
      final kupon = parseResult.kupons[i];

      // Cari kendaraan yang sesuai berdasarkan satker, bukan indeks
      KendaraanModel? kendaraan;
      if (kupon.jenisKuponId == 1) {
        // Kupon RANJEN - cari kendaraan yang sesuai berdasarkan satkerId
        for (final k in parseResult.newKendaraans) {
          if (k.satkerId == kupon.satkerId) {
            kendaraan = k;
            break;
          }
        }
      } else if (kupon.jenisKuponId == 2) {
        // Kupon DUKUNGAN - tidak ada kendaraan langsung
        kendaraan = null;
      }

      items.add(
        ImportPreviewItem(
          kupon: kupon,
          kendaraan: kendaraan,
          isDuplicate: false,
          status: 'BARU',
        ),
      );
    }

    // Add duplicate items
    for (int i = 0; i < parseResult.duplicateKupons.length; i++) {
      final kupon = parseResult.duplicateKupons[i];

      // Cari kendaraan duplicate yang sesuai berdasarkan satker, bukan indeks
      KendaraanModel? kendaraan;
      if (kupon.jenisKuponId == 1) {
        // Kupon RANJEN duplicate - cari kendaraan yang sesuai berdasarkan satkerId
        for (final k in parseResult.duplicateKendaraans) {
          if (k.satkerId == kupon.satkerId) {
            kendaraan = k;
            break;
          }
        }
      } else if (kupon.jenisKuponId == 2) {
        // Kupon DUKUNGAN duplicate - tidak ada kendaraan langsung
        kendaraan = null;
      }

      items.add(
        ImportPreviewItem(
          kupon: kupon,
          kendaraan: kendaraan,
          isDuplicate: true,
          status: 'DUPLIKAT',
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildPreviewItems();
    final newCount = parseResult.kupons.length;
    final duplicateCount = parseResult.duplicateKupons.length;
    final totalCount = newCount + duplicateCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Import'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File: $fileName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSummaryItem('Total', totalCount, Colors.blue),
                    _buildSummaryItem('Baru', newCount, Colors.green),
                    _buildSummaryItem(
                      'Duplikat',
                      duplicateCount,
                      Colors.orange,
                    ),
                  ],
                ),
                if (parseResult.validationMessages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Pesan Validasi:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...parseResult.validationMessages
                      .take(3)
                      .map(
                        (msg) => Text(
                          '• $msg',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  if (parseResult.validationMessages.length > 3)
                    Text(
                      '... dan ${parseResult.validationMessages.length - 3} pesan lainnya',
                      style: TextStyle(
                        color: Colors.red.shade500,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),

          // Column Headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Nomor Kupon',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'No Pol',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Kendaraan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Jenis Kupon',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Kuota',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Data List
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Tidak ada data untuk ditampilkan'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildDataRow(item, index);
                    },
                  ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: newCount > 0 ? onConfirmImport : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      newCount > 0
                          ? 'Import $newCount Kupon Baru'
                          : 'Tidak Ada Data Baru',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildDataRow(ImportPreviewItem item, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Colors.white : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: backgroundColor,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              _formatNomorKupon(item.kupon),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.kendaraan != null
                  ? '${item.kendaraan!.noPolNomor}-${item.kendaraan!.noPolKode}'
                  : 'N/A (DUKUNGAN)',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.kendaraan?.jenisRanmor.toUpperCase() ?? 'N/A',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _getJenisKuponText(item.kupon.jenisKuponId),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.kupon.kuotaAwal.toInt()}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isDuplicate ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNomorKupon(KuponModel kupon) {
    // Format: nokupon/bulan/tahun/LOGISTIK
    // Convert month number to Roman numeral
    final romanMonths = [
      '',
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII',
    ];

    final romanMonth = kupon.bulanTerbit >= 1 && kupon.bulanTerbit <= 12
        ? romanMonths[kupon.bulanTerbit]
        : kupon.bulanTerbit.toString();

    return '${kupon.nomorKupon}/$romanMonth/${kupon.tahunTerbit}/LOGISTIK';
  }

  String _getJenisKuponText(int jenisKuponId) {
    switch (jenisKuponId) {
      case 1:
        return 'RANJEN';
      case 2:
        return 'DUKUNGAN';
      default:
        return 'Unknown';
    }
  }
}
