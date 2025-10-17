// lib/presentation/pages/import/import_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/enhanced_import_provider.dart';

class ImportPage extends StatefulWidget {
  final VoidCallback? onImportSuccess;
  const ImportPage({super.key, this.onImportSuccess});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String _selectedFileName = 'Tidak ada file yang dipilih';
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

  Color _getStatusColor(bool success, bool hasWarnings) {
    if (!success) return Colors.red;
    if (hasWarnings) return Colors.orange;
    return Colors.green;
  }

  Future<void> _performImport(EnhancedImportProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Show loading indicator
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Memproses dan mengimport file...'),
            ],
          ),
          duration: Duration(seconds: 30), // Long duration
        ),
      );

      // Perform actual import
      final result = await provider.performImport();
      
      // Hide loading snackbar
      scaffoldMessenger.hideCurrentSnackBar();
      
      if (mounted) {
        // Update UI state
        setState(() {
          _importCompleted = true;
        });

        // Show result message
        final message = result.success
            ? 'Import berhasil! ${result.successCount} kupon berhasil diimport.'
            : 'Import gagal! ${result.errorCount} error ditemukan.';

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        // Call success callback if import was successful
        if (result.success && widget.onImportSuccess != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onImportSuccess!();
            }
          });
        }
      }
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error import: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EnhancedImportProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Import Kupon dari Excel'),
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

                  // Import Button - hide after successful import
                  if (provider.selectedFilePath != null && !_importCompleted) ...[
                    ElevatedButton.icon(
                      onPressed: provider.isLoading || provider.selectedFilePath == null
                          ? null
                          : () => _performImport(provider),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    if (provider.isLoading) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Sedang memproses file...'),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Results Section - Only show after import completed
                  if (_importCompleted && provider.lastImportResult != null) ...[
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
                                    provider.lastImportResult!.warnings.isNotEmpty,
                                  ),
                                  color: _getStatusColor(
                                    provider.lastImportResult!.success,
                                    provider.lastImportResult!.warnings.isNotEmpty,
                                  ),
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hasil Import',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                            provider.lastImportResult!.success,
                                            provider.lastImportResult!.warnings.isNotEmpty,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _getStatusLabel(
                                          provider.lastImportResult!.success,
                                          provider.lastImportResult!.warnings.isNotEmpty,
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            // Statistics
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Berhasil',
                                    provider.lastImportResult!.successCount.toString(),
                                    Colors.green,
                                    Icons.check_circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatCard(
                                    'Duplikat',
                                    provider.lastImportResult!.duplicateCount.toString(),
                                    Colors.orange,
                                    Icons.content_copy,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatCard(
                                    'Error',
                                    provider.lastImportResult!.errorCount.toString(),
                                    Colors.red,
                                    Icons.error,
                                  ),
                                ),
                              ],
                            ),

                            // Warnings section
                            if (provider.lastImportResult!.warnings.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ExpansionTile(
                                leading: const Icon(Icons.warning, color: Colors.orange),
                                title: Text(
                                  'Peringatan (${provider.lastImportResult!.warnings.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    padding: const EdgeInsets.all(8),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: provider.lastImportResult!.warnings.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ', style: TextStyle(fontSize: 12)),
                                              Expanded(
                                                child: Text(
                                                  provider.lastImportResult!.warnings[index],
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Errors section
                            if (provider.lastImportResult!.errors.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ExpansionTile(
                                leading: const Icon(Icons.error, color: Colors.red),
                                title: Text(
                                  'Error (${provider.lastImportResult!.errors.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                children: [
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    padding: const EdgeInsets.all(8),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: provider.lastImportResult!.errors.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ', style: TextStyle(fontSize: 12)),
                                              Expanded(
                                                child: Text(
                                                  provider.lastImportResult!.errors[index],
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // Import another file button
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _importCompleted = false;
                                  _selectedFileName = 'Tidak ada file yang dipilih';
                                });
                                provider.setFilePath('');
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Import File Lain'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
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

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(bool success, bool hasWarnings) {
    if (!success) return Icons.error;
    if (hasWarnings) return Icons.warning;
    return Icons.check_circle;
  }

  String _getStatusLabel(bool success, bool hasWarnings) {
    if (!success) return 'Import Gagal';
    if (hasWarnings) return 'Berhasil dengan Peringatan';
    return 'Import Berhasil';
  }
}