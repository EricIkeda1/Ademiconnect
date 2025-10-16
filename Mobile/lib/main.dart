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
import 'services/notification_service.dart';
import 'services/cliente_service.dart';

// Serviço de notificações
FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
ClienteService? clienteService;

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

  // Inicializa notificações locais
  if (!kIsWeb) {
    try {
      flutterLocalNotificationsPlugin = await NotificationService.initialize();
      debugPrint('✅ Notificações locais inicializadas.');
    } on Exception catch (e) {
      debugPrint('⚠️ Falha ao inicializar notificações: $e');
    }
  }

  // Carrega as variáveis de ambiente
  await loadEnv();

  // Inicializa o Supabase
  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('❌ URL ou chave do Supabase não encontradas no .env');
    runApp(const ErrorScreen(error: 'Configuração do Supabase incorreta.'));
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
    runApp(const ErrorScreen(error: 'Erro ao conectar ao banco de dados.'));
    return;
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Inicializa o serviço de clientes após o app iniciar
    clienteService = ClienteService();
    clienteService!.initialize().then((_) {
      debugPrint('✅ ClienteService inicializado.');
    }).catchError((e) {
      debugPrint('⚠️ Falha ao inicializar ClienteService: $e');
    });
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

    return FutureBuilder(
      future: client
          .from('gestor')
          .select('tipo')
          .eq('id', client.auth.currentSession!.user.id)
          .single(),
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

        if (snapshot.hasData) {
          final data = snapshot.data as Map<String, dynamic>;
          final tipo = data['tipo'] as String?;

          if (tipo == 'gestor') {
            return const HomeGestor();
          }
        } else if (snapshot.hasError) {
          debugPrint('❌ Erro ao carregar tipo de usuário: ${snapshot.error}');
        }

        // Todos os outros (consultor ou não encontrado) vão para HomeConsultor
        return const HomeConsultor();
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
