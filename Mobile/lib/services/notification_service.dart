import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static Future<FlutterLocalNotificationsPlugin> initialize() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    return flutterLocalNotificationsPlugin;
  }

  static Future<void> showSuccessNotification() async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'channel_success',
        'Cadastro de Clientes',
        channelDescription: 'Notificações para cadastros enviados com sucesso',
        importance: Importance.high,
        priority: Priority.high,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        'Cadastro enviado',
        'O seu cadastro foi enviado ao banco de dados com sucesso!',
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      print('❌ Falha ao exibir notificação de sucesso: $e');
    }
  }

  static Future<void> showOfflineNotification() async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'channel_offline',
        'Dados temporários',
        channelDescription: 'Notificações para dados salvos localmente',
        importance: Importance.high,
        priority: Priority.high,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        'Cadastro temporário',
        'Seus dados Cadastrados estão salvos no armazenamento temporariamente!',
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      print('❌ Falha ao exibir notificação offline: $e');
    }
  }
}
