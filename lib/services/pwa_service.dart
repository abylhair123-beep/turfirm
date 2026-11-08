import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Сервис для управления PWA-поведением на Web-платформе.
///
/// Определяет, запущено ли приложение в standalone-режиме (как PWA),
/// и управляет поведением, специфичным для мобильного веба.
class PwaService {
  PwaService._();

  /// Платформа — Web.
  static bool get isWeb => kIsWeb;

  /// Инициализация — вызывать при старте приложения.
  static Future<void> init() async {
    if (!kIsWeb) return;

    try {
      // В web-режиме — портретная ориентация для мобильных
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Стилизация status bar
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
      ));
    } catch (e) {
      debugPrint('[PwaService] Init error: $e');
    }
  }
}
