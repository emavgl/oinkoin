import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Global Talker instance for consistent logging across the app
final Talker _globalTalker = Talker(
  settings: TalkerSettings(
    enabled: true,
    useHistory: true,
    maxHistoryItems: 1000,
    useConsoleLogs: true,
  ),
  logger: TalkerLogger(),
);

/// Get the global Talker instance
Talker get globalTalker => _globalTalker;

/// Logger class that wraps Talker for consistent logging across the app.
/// Provides context-aware logging with class/component information.
///
/// Usage examples:
///
/// For static classes or static methods:
/// ```dart
/// class BackupService {
///   static final _logger = Logger.withContext('BackupService');
///
///   static void backup() {
///     _logger.info('Starting backup...');
///   }
/// }
/// ```
///
/// For instance classes (automatically uses runtimeType):
/// ```dart
/// class UserService {
///   final _logger = Logger(UserService);  // Automatically uses 'UserService' as context
///
///   void loadUser() {
///     _logger.info('Loading user...');
///   }
/// }
/// ```
///
/// For global/main contexts:
/// ```dart
/// final logger = Logger.withContext('main');
/// ```
class Logger {
  final String? _context;

  /// Create a logger with a custom context string
  /// Usage: Logger.withContext('CustomContext') - For static contexts or custom names
  Logger.withContext(String context) : _context = context;

  /// Create a logger using the Type of a class
  /// Usage: Logger.withClass(MyClass) - For static contexts using class names
  Logger.withClass(Type type) : _context = type.toString();

  /// Create a logger without context (not recommended)
  /// Usage: Logger.noContext() - Only for generic logging without class context
  Logger.noContext() : _context = null;

  /// Get the underlying Talker instance for advanced usage
  Talker get talker => _globalTalker;

  /// Log an informational message
  void info(String message) {
    _globalTalker.info(_formatMessage(message));
  }

  /// Log a debug message
  void debug(String message) {
    _globalTalker.debug(_formatMessage(message));
  }

  /// Log a warning message
  void warning(String message) {
    _globalTalker.warning(_formatMessage(message));
  }

  /// Log an error message
  void error(String message) {
    _globalTalker.error(_formatMessage(message));
  }

  /// Log a critical error message
  void critical(String message) {
    _globalTalker.critical(_formatMessage(message));
  }

  /// Handle exceptions with stack traces
  void handle(Object exception, StackTrace stackTrace, String message) {
    _globalTalker.handle(exception, stackTrace, _formatMessage(message));
  }

  /// Format log message with context
  String _formatMessage(String message) {
    if (_context != null && _context!.isNotEmpty) {
      return '[$_context] $message';
    }
    return message;
  }
}

/// Reusable Log Screen widget that uses the global talker instance
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  @override
  Widget build(BuildContext context) {
    return TalkerScreen(
      talker: globalTalker,
      theme: TalkerScreenTheme(
        backgroundColor: Theme.of(context).colorScheme.surface,
        cardColor: Theme.of(context).colorScheme.surfaceContainer,
        textColor: Theme.of(context).colorScheme.onSurface,
        logColors: {
          'error': Colors.redAccent,
          'info': Colors.grey,
          'warning': Colors.orange,
          'critical': Colors.red,
          'debug': Colors.blueGrey
        },
      ),
    );
  }
}

