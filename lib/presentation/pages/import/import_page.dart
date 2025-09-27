// lib/presentation/pages/import/import_page.dart

import 'package:flutter/material.dart';
import 'package:kupon_bbm_app/presentation/providers/import_provider.dart';
import 'package:provider/provider.dart';

class ImportPage extends StatelessWidget {
  final VoidCallback? onImportSuccess;
  const ImportPage({super.key, this.onImportSuccess});

  @override
  Widget build(BuildContext context) {
    return Consumer<ImportProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Import Kupon dari Excel')),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File Selection Area
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          provider.fileName,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: provider.isLoading ? null : provider.pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Pilih File'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Status & Validation Messages
                if (provider.statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(provider.statusMessage),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      provider.statusMessage,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                if (provider.validationMessages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Peringatan:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      itemCount: provider.validationMessages.length,
                      itemBuilder: (context, index) => Text(
                        '• ${provider.validationMessages[index]}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Data Preview
                if (provider.kupons.isNotEmpty) ...[
                  Text(
                    'Preview Data (${provider.kupons.length} kupon):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (provider.replaceMode) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Mode replace aktif: Data existing akan diganti berdasarkan nomor kupon.',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('No Kupon')),
                              DataColumn(label: Text('Jenis')),
                              DataColumn(label: Text('BBM')),
                              DataColumn(label: Text('Nomor Polisi')),
                              DataColumn(label: Text('Kuota')),
                              DataColumn(label: Text('Periode')),
                            ],
                            rows: List.generate(provider.kupons.length, (
                              index,
                            ) {
                              final kupon = provider.kupons[index];
                              final kendaraan = provider.newKendaraans[index];
                              return DataRow(
                                cells: [
                                  DataCell(Text(kupon.nomorKupon)),
                                  DataCell(
                                    Text(
                                      kupon.jenisKuponId == 1
                                          ? 'Ranjen'
                                          : 'Dukungan',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      kupon.jenisBbmId == 1
                                          ? 'Pertamax'
                                          : 'Dex',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${kendaraan.noPolNomor}-${kendaraan.noPolKode}',
                                    ),
                                  ),
                                  DataCell(Text('${kupon.kuotaAwal}')),
                                  DataCell(
                                    Text(
                                      '${kupon.bulanTerbit}/${kupon.tahunTerbit}',
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Replace Checkbox
                if (provider.kupons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Ganti data yang sudah ada (Replace)'),
                    subtitle: const Text(
                      'Data kupon existing akan diganti berdasarkan nomor kupon.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: provider.replaceMode,
                    onChanged: provider.isLoading
                        ? null
                        : (bool? value) {
                            provider.setReplaceMode(value ?? false);
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],

                // Import Button
                if (provider.kupons.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            final success = await provider.startImport(replaceMode: provider.replaceMode);
                            if (success == true && onImportSuccess != null) {
                              onImportSuccess!();
                            }
                          },
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(
                      provider.isLoading
                          ? 'Mengimport...'
                          : 'Import ${provider.kupons.length} Kupon ${provider.replaceMode ? '(Replace)' : ''}',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),

                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String message) {
    if (message.contains('Error') || message.contains('error')) {
      return Colors.red.shade700;
    }
    if (message.contains('peringatan') || message.contains('warning')) {
      return Colors.orange.shade700;
    }
    return Colors.green.shade700;
  }
}
