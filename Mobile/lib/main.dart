import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'telas/login.dart';
import 'telas/gestor/home_gestor.dart';
import 'telas/consultor/home_consultor.dart';
import 'telas/recuperar_senha.dart';
import 'services/notification_service.dart';
import 'services/cliente_service.dart';

// Evite late sem garantia de inicialização
FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
ClienteService? clienteService;

Future<void> loadEnv() async {
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env carregado com sucesso');
  } catch (e) {
    print('❌ Falha ao carregar .env: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ 1. Iniciando app: WidgetsBinding OK');

  // Inicialize com segurança para web
  if (!kIsWeb) {
    try {
      flutterLocalNotificationsPlugin = await NotificationService.initialize();
      print('✅ Notificações locais inicializadas.');
    } on Exception catch (e) {
      print('⚠️ Falha ao inicializar notificações: $e');
    }
  } else {
    print('ℹ️ Executando na Web. Notificações locais não são suportadas.');
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  }

  await loadEnv();

  print('🔍 FIREBASE_PROJECT_ID: ${dotenv.get('FIREBASE_PROJECT_ID')}');
  print('🔍 FIREBASE_API_KEY_WEB: ${dotenv.get('FIREBASE_API_KEY_WEB')}');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ 2. Firebase inicializado com sucesso!');
  } catch (e, s) {
    print('❌ ERRO FATAL ao inicializar Firebase: $e');
    print('❌ Stack trace: $s');
    runApp(ErrorScreen(error: 'Falha ao inicializar Firebase.\nVerifique a configuração.'));
    return;
  }

  try {
    clienteService = ClienteService();
    await clienteService!.initialize();
    print('✅ 3. ClienteService inicializado.');
  } catch (e) {
    print('⚠️ Falha ao inicializar ClienteService: $e');
  }

  print('✅ 4. Executando MyApp...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const UserTypeRedirector();
        }

        return const LoginPage();
      },
    );
  }
}

class UserTypeRedirector extends StatelessWidget {
  const UserTypeRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('gestor').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Usuário não encontrado no sistema.')),
            );
            FirebaseAuth.instance.signOut();
          });
          return const LoginPage();
        }

        final tipo = snapshot.data!.get('tipo') as String?;
        if (tipo == 'gestor' || tipo == 'supervisor') {
          return const HomeGestor();
        } else if (tipo == 'consultor') {
          return const HomeConsultor();
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tipo de usuário inválido.')),
            );
            FirebaseAuth.instance.signOut();
          });
          return const LoginPage();
        }
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
              Text(
                error,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
