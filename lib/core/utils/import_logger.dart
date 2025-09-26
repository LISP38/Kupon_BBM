import 'dart:developer' as developer;

class ImportLogger {
  static void log(String message, {String? error}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    
    // Log ke console dengan tag IMPORT
    developer.log(
      logMessage,
      name: 'IMPORT',
      error: error,
    );
  }

  static void logSuccess(String message) {
    log('✅ $message');
  }

  static void logError(String message, [dynamic error]) {
    log('❌ $message', error: error?.toString());
  }

  static void logInfo(String message) {
    log('ℹ️ $message');
  }

  static void logWarning(String message) {
    log('⚠️ $message');
  }
}