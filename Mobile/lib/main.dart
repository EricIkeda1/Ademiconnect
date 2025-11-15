import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ Iniciando app: WidgetsBinding OK');

  if (!kIsWeb) {
    try {
      flutterLocalNotificationsPlugin = await NotificationService.initialize();
      debugPrint('✅ Notificações locais inicializadas.');
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
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      debugPrint('🔐 Auth event: $event');

      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        navigatorKey.currentState?.pushNamed('/nova-senha');
      }

      if (event == AuthChangeEvent.signedOut) {
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
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando...'),
                ],
              ),
            ),
          );
        }

        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginPage();
        }

        return const UserTypeRedirector();
      },
    );
  }
}

class UserTypeRedirector extends StatelessWidget {
  const UserTypeRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final userId = client.auth.currentSession?.user.id;
    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 60),
              SizedBox(height: 16),
              Text('Sessão inválida', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text('Faça login novamente'),
            ],
          ),
        ),
      );
    }

    return FutureBuilder(
      future: client
          .from('gestor')
          .select('id')
          .eq('id', userId)
          .maybeSingle(),
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

        if (snapshot.hasError) {
          debugPrint('❌ Erro ao carregar tipo: ${snapshot.error}');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, color: Colors.red, size: 60),
                  SizedBox(height: 16),
                  Text('Erro de conexão', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Verifique sua internet'),
                ],
              ),
            ),
          );
        }

        return snapshot.hasData && snapshot.data != null
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
