import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/models/import_history_model.dart';
import '../../providers/enhanced_import_provider.dart';

class ImportHistoryDetailPage extends StatefulWidget {
  final ImportHistoryModel session;

  const ImportHistoryDetailPage({super.key, required this.session});

  @override
  State<ImportHistoryDetailPage> createState() =>
      _ImportHistoryDetailPageState();
}

class _ImportHistoryDetailPageState extends State<ImportHistoryDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnhancedImportProvider>().loadSessionDetails(
        widget.session.sessionId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Import #${widget.session.sessionId}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus Riwayat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<EnhancedImportProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSessionInfo(),
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 24),
                _buildDetailsSection(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(widget.session.status),
                  color: _getStatusColor(widget.session.status),
                ),
                const SizedBox(width: 8),
                Text(
                  'Informasi Import',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow('File Name', widget.session.fileName),
            _buildInfoRow(
              'Tipe Import',
              widget.session.importType.toUpperCase(),
            ),
            _buildInfoRow(
              'Tanggal Import',
              _formatDateTime(widget.session.importDate),
            ),
            if (widget.session.expectedPeriod != null)
              _buildInfoRow('Periode Target', widget.session.expectedPeriod!),
            _buildInfoRow('Status', _getStatusText(widget.session.status)),
            if (widget.session.errorMessage != null)
              _buildInfoRow(
                'Error Message',
                widget.session.errorMessage!,
                isError: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Hasil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Kupon',
                    widget.session.totalKupons.toString(),
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Berhasil',
                    widget.session.successCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Gagal',
                    widget.session.errorCount.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Diganti',
                    widget.session.duplicateCount.toString(),
                    Icons.swap_horiz,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final total = widget.session.totalKupons;
    if (total == 0) return const SizedBox.shrink();

    final success = widget.session.successCount / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Progress:', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: success,
          backgroundColor: Colors.red.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
        const SizedBox(height: 4),
        Text(
          '${(success * 100).toStringAsFixed(1)}% berhasil',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(EnhancedImportProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.sessionDetails.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tidak ada detail tersedia'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Proses (${provider.sessionDetails.length} item)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.sessionDetails.length,
              itemBuilder: (context, index) {
                final detail = provider.sessionDetails[index];
                return _buildDetailItem(detail);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(ImportDetailModel detail) {
    final isError = detail.status == 'ERROR' || detail.status == 'FAILED';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle,
                size: 16,
                color: isError ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                detail.status,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isError ? Colors.red : Colors.green,
                ),
              ),
              if (detail.action != null) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    detail.action!,
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ],
          ),
          if (detail.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              detail.errorMessage!,
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ],
          if (detail.kuponData != 'VALIDATION_ERROR' &&
              detail.kuponData != 'VALIDATION_WARNING' &&
              detail.kuponData != 'SYSTEM_ERROR') ...[
            const SizedBox(height: 8),
            Text(
              'Data: ${detail.kuponData}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isError ? Colors.red : null),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'SUCCESS':
        return Icons.check_circle;
      case 'FAILED':
        return Icons.error;
      case 'PROCESSING':
        return Icons.hourglass_empty;
      case 'VALIDATION_FAILED':
        return Icons.warning;
      case 'VALIDATED':
        return Icons.verified;
      case 'COMPLETED_WITH_ERRORS':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'PROCESSING':
        return Colors.orange;
      case 'VALIDATION_FAILED':
        return Colors.orange;
      case 'VALIDATED':
        return Colors.blue;
      case 'COMPLETED_WITH_ERRORS':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'SUCCESS':
        return 'Berhasil';
      case 'FAILED':
        return 'Gagal';
      case 'PROCESSING':
        return 'Sedang Proses';
      case 'VALIDATION_FAILED':
        return 'Validasi Gagal';
      case 'VALIDATED':
        return 'Hanya Validasi';
      case 'COMPLETED_WITH_ERRORS':
        return 'Selesai dengan Error';
      default:
        return status;
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final formatter = DateFormat('dd MMMM yyyy, HH:mm:ss');
      return formatter.format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Riwayat Import'),
        content: Text(
          'Apakah Anda yakin ingin menghapus riwayat import "${widget.session.fileName}"?\n\n'
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                await context.read<EnhancedImportProvider>().deleteSession(
                  widget.session.sessionId,
                );

                if (mounted) {
                  Navigator.pop(context); // Go back to history list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Riwayat import berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus riwayat: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
