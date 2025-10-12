import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  late FlutterLocalNotificationsPlugin _notifications;

  NotificationService._internal() {
    _notifications = FlutterLocalNotificationsPlugin();
  }

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
  }

  Future<void> showSuccessNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'success_channel',
      'Cadastro de Clientes',
      channelDescription: 'Notificações para cadastros enviados com sucesso',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch,
      'Cadastro enviado',
      'O seu cadastro foi enviado ao banco de dados com sucesso!',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showOfflineNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'offline_channel',
      'Dados temporários',
      channelDescription: 'Notificações para dados salvos temporariamente',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch,
      'Cadastro temporário',
      'Seus dados Cadastrados está salvo no armazenamento temporariamente!',
      NotificationDetails(android: androidDetails),
    );
  }
}
