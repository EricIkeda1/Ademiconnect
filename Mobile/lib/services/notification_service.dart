import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Remove 'late' declaration - moved to after initialization
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static Future<FlutterLocalNotificationsPlugin?> initialize() async {
    if (kIsWeb) return null;

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Fixed: Removed onDidReceiveLocalNotification
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    try {
      // CORREÇÃO: Método initialize não retorna mais bool
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      if (!kIsWeb) {
        try {
          final AndroidFlutterLocalNotificationsPlugin? androidImpl = 
              flutterLocalNotificationsPlugin
                  .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
          
          if (androidImpl != null) {
            // CORREÇÃO DEFINITIVA: O método requestPermission() foi removido.
            // As permissões são gerenciadas automaticamente pelo sistema.
            // Remova completamente esta chamada.
            debugPrint('NotificationService: Android permissions handled by system');
          }
        } catch (e) {
          debugPrint('NotificationService: Platform-specific initialization: $e');
        }
      }

      debugPrint('NotificationService: Initialized successfully');
      return flutterLocalNotificationsPlugin;

    } catch (e, stack) {
      debugPrint('NotificationService: Initialization error: $e\n$stack');
      return null;
    }
  }

  // Fixed: Proper const constructor usage
  static const AndroidNotificationDetails _androidSuccessDetails = 
      AndroidNotificationDetails(
    'channel_success',
    'Cadastro de Clientes',
    channelDescription: 'Notificações para cadastros enviados com sucesso',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails _androidOfflineDetails = 
      AndroidNotificationDetails(
    'channel_offline',
    'Dados temporários',
    channelDescription: 'Notificações para dados salvos localmente',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const AndroidNotificationDetails _androidErrorDetails = 
      AndroidNotificationDetails(
    'channel_error',
    'Erros de sincronização',
    channelDescription: 'Notificações para erros de conexão ou salvamento',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> showSuccessNotification() async {
    if (kIsWeb) return;

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        'Cadastro enviado',
        'O seu cadastro foi enviado ao banco de dados com sucesso!',
        NotificationDetails(android: _androidSuccessDetails),
      );
    } catch (e, stack) {
      debugPrint('❌ Falha ao exibir notificação de sucesso: $e\n$stack');
    }
  }

  static Future<void> showOfflineNotification() async {
    if (kIsWeb) return;

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        'Cadastro temporário',
        'Seus dados cadastrados estão salvos temporariamente!',
        NotificationDetails(android: _androidOfflineDetails),
      );
    } catch (e, stack) {
      debugPrint('❌ Falha ao exibir notificação offline: $e\n$stack');
    }
  }

  static Future<void> showErrorNotification() async {
    if (kIsWeb) return;

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        'Erro de sincronização',
        'Falha ao enviar dados. Verifique sua conexão e tente novamente.',
        NotificationDetails(android: _androidErrorDetails),
      );
    } catch (e, stack) {
      debugPrint('❌ Falha ao exibir notificação de erro: $e\n$stack');
    }
  }
}