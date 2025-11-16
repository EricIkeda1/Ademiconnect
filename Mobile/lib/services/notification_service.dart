import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _lastAlertKey = 'last_alert_date';

  static Future<FlutterLocalNotificationsPlugin?> initialize() async {
    if (kIsWeb) return null;

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
      await flutterLocalNotificationsPlugin.initialize(initSettings);
      return flutterLocalNotificationsPlugin;
    } catch (_) {
      return null;
    }
  }

  static Future<void> requestAndroid13Permission() async {
    if (kIsWeb) return;
    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
  }

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

  static const AndroidNotificationDetails _androidAlertDetails =
      AndroidNotificationDetails(
    'channel_alertas',
    'Alertas de Visitas',
    channelDescription: 'Notificações de visitas atrasadas ou urgentes',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> showSuccessNotification({String? title, String? body}) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      title ?? 'Cadastro enviado',
      body ?? 'O seu cadastro foi enviado ao banco de dados com sucesso!',
      const NotificationDetails(android: _androidSuccessDetails),
    );
  }

  static Future<void> showOfflineNotification() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      'Cadastro temporário',
      'Seus dados cadastrados estão salvos temporariamente!',
      const NotificationDetails(android: _androidOfflineDetails),
    );
  }

  static Future<void> showErrorNotification([String? msg]) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch,
      'Erro de sincronização',
      msg ?? 'Falha ao enviar dados. Verifique sua conexão e tente novamente.',
      const NotificationDetails(android: _androidErrorDetails),
    );
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<bool> _jaMostrouAlertaHoje() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastAlertKey);
    final today = _todayKey();
    return last == today;
  }

  static Future<void> _marcarAlertaMostradoHoje() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    await prefs.setString(_lastAlertKey, today);
  }

  static Future<void> showAlertNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    final jaMostrou = await _jaMostrouAlertaHoje();
    if (jaMostrou) return;

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: _androidAlertDetails),
    );

    await _marcarAlertaMostradoHoje();
  }
}
