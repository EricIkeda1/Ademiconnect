import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'telas/login.dart';
import 'telas/gestor/home_gestor.dart';
import 'telas/consultor/home_consultor.dart';
import 'telas/recuperar_senha.dart';
import 'telas/nova_senha.dart';
import 'services/notification_service.dart';
import 'services/cliente_service.dart';

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
ClienteService? clienteService;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> loadEnv() async {
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env carregado com sucesso');
  } catch (e) {
    debugPrint('❌ Falha ao carregar .env: $e');
  }
}

enum UserType { gestor, consultor }

class UserTypeCache {
  static const _keyType = 'user_type';
  static const _keyName = 'user_name';

  static Future<void> save(UserType type, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyType, type.name);
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_keyName, name);
    }
  }

  static Future<UserType?> loadType() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyType);
    if (value == null) return null;
    try {
      return UserType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> loadName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyType);
    await prefs.remove(_keyName);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Iniciando app: WidgetsBinding OK');

  if (!kIsWeb) {
    try {
      flutterLocalNotificationsPlugin = await NotificationService.initialize();
      debugPrint('✅ Notificações locais inicializadas.');

      await NotificationService.requestAndroid13Permission();
      debugPrint('✅ Permissão de notificação solicitada (Android 13+).');
    } on Exception catch (e) {
      debugPrint('⚠️ Falha ao inicializar notificações: $e');
    }
  }

  await loadEnv();

  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('❌ URL ou chave do Supabase não encontradas no .env');
    runApp(const ErrorScreen(
      error: 'Configuração do Supabase incorreta.\nVerifique o arquivo .env.',
    ));
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('✅ Supabase inicializado com sucesso!');
  } catch (e, s) {
    debugPrint('❌ Falha ao inicializar Supabase: $e');
    debugPrint('❌ Stack trace: $s');
    runApp(const ErrorScreen(
      error:
          'Erro ao conectar ao banco de dados.\nVerifique sua conexão com a internet.',
    ));
    return;
  }

  try {
    clienteService = ClienteService();
    await clienteService!.initialize();
    debugPrint('✅ ClienteService inicializado.');
  } catch (e) {
    debugPrint('⚠️ Falha ao inicializar ClienteService: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      debugPrint('🔐 Auth event: $event');

      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        navigatorKey.currentState?.pushNamed('/nova-senha');
      }

      if (event == AuthChangeEvent.signedOut) {
        await UserTypeCache.clear();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ADEMICON Londrina',
      theme: theme,
      navigatorKey: navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/gestor': (context) => const HomeGestor(),
        '/consultor': (context) => const HomeConsultor(),
        '/recuperar': (context) => const RecuperarSenhaPage(),
        '/nova-senha': (context) => const NovaSenhaPage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginPage();
    }
    return const UserTypeRedirector();
  }
}

class UserTypeRedirector extends StatelessWidget {
  const UserTypeRedirector({super.key});

  Future<(UserType?, String?)> _resolveUserTypeAndName() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentSession?.user.id;
    if (userId == null) return (null, null);

    try {
      final gestor = await client
          .from('gestor')
          .select('id, nome')
          .eq('id', userId)
          .maybeSingle();

      if (gestor != null) {
        final nomeGestor = gestor['nome'] as String?;
        await UserTypeCache.save(UserType.gestor, nomeGestor);
        return (UserType.gestor, nomeGestor);
      }

      final consultor = await client
          .from('consultor')
          .select('id, nome')
          .eq('id', userId)
          .maybeSingle();

      final nomeConsultor = consultor?['nome'] as String?;
      await UserTypeCache.save(UserType.consultor, nomeConsultor);
      return (UserType.consultor, nomeConsultor);
    } catch (e) {
      debugPrint('⚠️ Erro ao buscar tipo/nome (usando cache): $e');
      final type = await UserTypeCache.loadType();
      final name = await UserTypeCache.loadName();
      return (type, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(UserType?, String?)>(
      future: _resolveUserTypeAndName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verificando perfil...'),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        final type = data?.$1;
        final name = data?.$2;

        if (type == null) {
          return const LoginPage();
        }
        return type == UserType.gestor
            ? const HomeGestor()
            : const HomeConsultor();
      },
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(
                'Erro Crítico',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
