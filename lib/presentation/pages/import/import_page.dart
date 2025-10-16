// lib/presentation/pages/import/import_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/enhanced_import_provider.dart';
import '../../../data/services/enhanced_import_service.dart';
import 'import_preview_page.dart';

class ImportPage extends StatefulWidget {
  final VoidCallback? onImportSuccess;
  const ImportPage({super.key, this.onImportSuccess});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String _selectedFileName = 'Tidak ada file yang dipilih';
  int? _expectedMonth;
  int? _expectedYear;
  bool _importCompleted = false;

  Future<void> _pickFile(EnhancedImportProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        final file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _importCompleted = false; // Reset import completed flag
        });
        provider.setFilePath(file.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error memilih file: $e')));
      }
    }
  }

  void _showPeriodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Periode yang Diharapkan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Opsional: Set bulan dan tahun yang diharapkan untuk validasi',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Bulan'),
                    initialValue: _expectedMonth,
                    items: List.generate(12, (index) => index + 1)
                        .map(
                          (month) => DropdownMenuItem(
                            value: month,
                            child: Text(month.toString().padLeft(2, '0')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _expectedMonth = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Tahun'),
                    keyboardType: TextInputType.number,
                    initialValue: _expectedYear?.toString(),
                    onChanged: (value) => _expectedYear = int.tryParse(value),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<EnhancedImportProvider>(
                context,
                listen: false,
              ).setExpectedPeriod(_expectedMonth ?? 0, _expectedYear ?? 0);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool success, bool hasWarnings) {
    if (!success) return Colors.red;
    if (hasWarnings) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedImportProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Import Kupon dari Excel'),
            actions: [
              IconButton(
                icon: const Icon(Icons.schedule),
                tooltip: 'Set Periode',
                onPressed: _showPeriodDialog,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File Selection Area
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pilih File Excel',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _selectedFileName,
                                    style: TextStyle(
                                      color: provider.selectedFilePath != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => _pickFile(provider),
                                icon: const Icon(Icons.file_open),
                                label: const Text('Pilih File'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Import Type Selection - hide after successful import
                  if (provider.selectedFilePath != null &&
                      !_importCompleted) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mode Import',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Column(
                              children: ImportType.values.map((type) {
                                return RadioListTile<ImportType>(
                                  title: Text(_getImportTypeLabel(type)),
                                  subtitle: Text(
                                    _getImportTypeDescription(type),
                                  ),
                                  value: type,
                                  groupValue: provider.importType,
                                  onChanged: provider.isLoading
                                      ? null
                                      : (ImportType? value) {
                                          if (value != null) {
                                            provider.setImportType(value);
                                          }
                                        },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                provider.isLoading ||
                                    provider.selectedFilePath == null
                                ? null
                                : () async {
                                    try {
                                      // Set import type to validate_only first
                                      provider.setImportType(
                                        ImportType.validate_only,
                                      );
                                      await provider.getPreviewData();
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Validasi selesai! Lihat hasil di bawah.',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Error validasi: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Validasi Saja'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                provider.isLoading ||
                                    provider.selectedFilePath == null ||
                                    provider.importType ==
                                        ImportType.validate_only
                                ? null
                                : () async {
                                    try {
                                      // Save scaffold messenger reference
                                      final scaffoldMessenger =
                                          ScaffoldMessenger.of(context);

                                      // Show confirmation dialog
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                            'Konfirmasi Import',
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Pilih metode import:',
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text(
                                                  'Preview dulu',
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text(
                                                  'Langsung Import',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      if (confirm == null)
                                        return; // Dialog dismissed

                                      if (confirm) {
                                        // Direct import
                                        scaffoldMessenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Mengimport file...'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );

                                        // Set import type to validate_and_save for direct import
                                        provider.setImportType(
                                          ImportType.validate_and_save,
                                        );

                                        // Perform direct import
                                        final result = await provider
                                            .performImport();

                                        if (result.success) {
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Import berhasil!'),
                                            ),
                                          );
                                          setState(() {
                                            _importCompleted = true;
                                          });
                                        }
                                        return;
                                      }

                                      // Preview mode
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Memproses file untuk preview...',
                                          ),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );

                                      // Show loading indicator
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Memproses file...'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );

                                      // Set import type to dry_run for preview
                                      provider.setImportType(
                                        ImportType.dry_run,
                                      );

                                      // Set import type to dry_run for preview
                                      provider.setImportType(
                                        ImportType.dry_run,
                                      );

                                      // Get preview data
                                      final previewData = await provider
                                          .getPreviewData();
                                      if (previewData == null) {
                                        if (mounted) {
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Tidak ada data yang bisa dipreview',
                                              ),
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      final fileName = provider
                                          .selectedFilePath!
                                          .split('/')
                                          .last;

                                      if (mounted) {
                                        // Navigate to preview page
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ImportPreviewPage(
                                              parseResult: previewData,
                                              fileName: fileName,
                                              onConfirmImport: () async {
                                                Navigator.pop(context);

                                                // Capture scaffoldMessenger before async operation
                                                final scaffoldMessenger =
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    );

                                                // Perform actual import
                                                try {
                                                  final result = await provider
                                                      .performImport();
                                                  if (mounted) {
                                                    final message =
                                                        result.success
                                                        ? 'Import berhasil! ${result.successCount} kupon berhasil diimport.'
                                                        : 'Import gagal!';

                                                    // Use captured scaffoldMessenger
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              message,
                                                            ),
                                                          ),
                                                        );

                                                    // Handle success callback and UI updates
                                                    if (result.success) {
                                                      // Update UI state first
                                                      setState(() {
                                                        _importCompleted = true;
                                                      });

                                                      // Call success callback with proper delay and checks
                                                      if (widget
                                                              .onImportSuccess !=
                                                          null) {
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback((
                                                              _,
                                                            ) {
                                                              if (mounted) {
                                                                widget
                                                                    .onImportSuccess!();
                                                              }
                                                            });
                                                      }
                                                    }
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    // Use captured scaffoldMessenger
                                                    scaffoldMessenger
                                                        .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error import: $e',
                                                            ),
                                                          ),
                                                        );
                                                  }
                                                }
                                              },
                                              onCancel: () {
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        try {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error membaca file: $e',
                                              ),
                                            ),
                                          );
                                        } catch (_) {
                                          // Ignore if context is no longer valid
                                        }
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.preview),
                            label: const Text('Preview & Import'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (provider.isLoading) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Results Section
                  if (provider.lastImportResult != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getStatusIcon(
                                    provider.lastImportResult!.success,
                                    provider
                                        .lastImportResult!
                                        .warnings
                                        .isNotEmpty,
                                  ),
                                  color: _getStatusColor(
                                    provider.lastImportResult!.success,
                                    provider
                                        .lastImportResult!
                                        .warnings
                                        .isNotEmpty,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Hasil ${provider.importType == ImportType.validate_only ? "Validasi" : "Import"}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),

                            Text(
                              'Status: ${_getStatusLabel(provider.lastImportResult!.success, provider.lastImportResult!.warnings.isNotEmpty)}',
                            ),
                            Text(
                              'Berhasil: ${provider.lastImportResult!.successCount}',
                            ),
                            Text(
                              'Error: ${provider.lastImportResult!.errorCount}',
                            ),
                            Text(
                              'Duplikat: ${provider.lastImportResult!.duplicateCount}',
                            ),

                            if (provider
                                .lastImportResult!
                                .warnings
                                .isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Peringatan:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 100,
                                ),
                                child: ListView.builder(
                                  itemCount: provider
                                      .lastImportResult!
                                      .warnings
                                      .length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        '• ${provider.lastImportResult!.warnings[index]}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],

                            if (provider
                                .lastImportResult!
                                .errors
                                .isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Error:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 100,
                                ),
                                child: ListView.builder(
                                  itemCount:
                                      provider.lastImportResult!.errors.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2.0,
                                      ),
                                      child: Text(
                                        '• ${provider.lastImportResult!.errors[index]}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getImportTypeLabel(ImportType type) {
    switch (type) {
      case ImportType.validate_only:
        return 'Mode Validasi';
      case ImportType.dry_run:
        return 'Mode Simulasi';
      case ImportType.validate_and_save:
        return 'Mode Import Penuh';
    }
  }

  String _getImportTypeDescription(ImportType type) {
    switch (type) {
      case ImportType.validate_only:
        return 'Hanya mengecek validitas data tanpa menyimpan ke database';
      case ImportType.dry_run:
        return 'Menjalankan simulasi import tanpa menyimpan ke database';
      case ImportType.validate_and_save:
        return 'Import data dengan validasi dan simpan ke database';
    }
  }

  IconData _getStatusIcon(bool success, bool hasWarnings) {
    if (!success) return Icons.error;
    if (hasWarnings) return Icons.warning;
    return Icons.check_circle;
  }

  String _getStatusLabel(bool success, bool hasWarnings) {
    if (!success) return 'Error';
    if (hasWarnings) return 'Berhasil dengan Peringatan';
    return 'Berhasil';
  }
}
