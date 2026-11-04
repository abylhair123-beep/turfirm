import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryService {
  /// Default or injected DSN. Pass via --dart-define=SENTRY_DSN=... during build
  static const String _defaultDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  static bool get isEnabled => _defaultDsn.isNotEmpty;

  /// Initializes Sentry monitoring and wraps application runner
  static Future<void> init({
    required FutureOr<void> Function() appRunner,
    String? dsn,
  }) async {
    final effectiveDsn = dsn ?? _defaultDsn;
    if (effectiveDsn.isEmpty) {
      if (kDebugMode) {
        debugPrint('[SentryService] SENTRY_DSN is not configured. Running locally without remote error reporting.');
      }
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = effectiveDsn;
        options.tracesSampleRate = 0.2;
        options.environment = kReleaseMode ? 'production' : 'development';
        options.attachScreenshot = false;
        options.enableAutoSessionTracking = true;
      },
      appRunner: appRunner,
    );
  }

  /// Manually capture handled exceptions with context
  static Future<void> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    String? category,
    Map<String, dynamic>? extras,
  }) async {
    if (!isEnabled) {
      if (kDebugMode) {
        debugPrint('[SentryService (local)] Captured exception: $throwable');
      }
      return;
    }

    await Sentry.captureException(
      throwable,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (category != null) {
          scope.setTag('category', category);
        }
        if (extras != null) {
          scope.setContexts('extra_data', extras);
        }
      },
    );
  }

  /// Add breadcrumbs to user flow (navigation, clicks, API calls)
  static void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    if (!isEnabled) return;
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category ?? 'action',
        data: data,
        timestamp: DateTime.now(),
      ),
    );
  }
}
