import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/enhanced_import_provider.dart';
import '../../../data/models/import_history_model.dart';
import 'import_history_detail_page.dart';

class ImportHistoryPage extends StatefulWidget {
  const ImportHistoryPage({super.key});

  @override
  State<ImportHistoryPage> createState() => _ImportHistoryPageState();
}

class _ImportHistoryPageState extends State<ImportHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnhancedImportProvider>().loadImportHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Import'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<EnhancedImportProvider>().loadImportHistory();
            },
          ),
        ],
      ),
      body: Consumer<EnhancedImportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.importHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat import',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.importHistory.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final session = provider.importHistory[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: _buildStatusIcon(session.status),
                  title: Text(
                    session.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDateTime(session.importDate)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${session.importType.toUpperCase()}'),
                          if (session.expectedPeriod != null) ...[
                            const Text(' • '),
                            Text('Periode: ${session.expectedPeriod}'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildProgressBar(session),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        provider.getSessionStatusText(session.status),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(session.status),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.successCount}/${session.totalKupons}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  onTap: () => _showSessionDetail(context, session),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'SUCCESS':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'FAILED':
        icon = Icons.error;
        color = Colors.red;
        break;
      case 'PROCESSING':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        break;
      case 'VALIDATION_FAILED':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'VALIDATED':
        icon = Icons.verified;
        color = Colors.blue;
        break;
      case 'COMPLETED_WITH_ERRORS':
        icon = Icons.warning;
        color = Colors.amber;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
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

  Widget _buildProgressBar(ImportHistoryModel session) {
    final total = session.totalKupons;
    final success = session.successCount;
    final errors = session.errorCount;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    final successPercent = success / total;
    final errorPercent = errors / total;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: (successPercent * 100).round(),
              child: Container(height: 4, color: Colors.green),
            ),
            Expanded(
              flex: (errorPercent * 100).round(),
              child: Container(height: 4, color: Colors.red),
            ),
            Expanded(
              flex: ((1 - successPercent - errorPercent) * 100).round(),
              child: Container(height: 4, color: Colors.grey[300]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (success > 0) ...[
              Icon(Icons.check_circle, size: 12, color: Colors.green),
              const SizedBox(width: 4),
              Text('$success berhasil', style: const TextStyle(fontSize: 11)),
            ],
            if (success > 0 && errors > 0)
              const Text(' • ', style: TextStyle(fontSize: 11)),
            if (errors > 0) ...[
              Icon(Icons.error, size: 12, color: Colors.red),
              const SizedBox(width: 4),
              Text('$errors gagal', style: const TextStyle(fontSize: 11)),
            ],
            if (session.duplicateCount > 0) ...[
              if (success > 0 || errors > 0)
                const Text(' • ', style: TextStyle(fontSize: 11)),
              Icon(Icons.swap_horiz, size: 12, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${session.duplicateCount} diganti',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final formatter = DateFormat('dd MMM yyyy, HH:mm');
      return formatter.format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  void _showSessionDetail(BuildContext context, ImportHistoryModel session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportHistoryDetailPage(session: session),
      ),
    );
  }
}
