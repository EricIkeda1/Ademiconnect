import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'telas/login.dart';
import 'telas/gestor/home_gestor.dart';
import 'telas/consultor/home_consultor.dart';
import 'telas/recuperar_senha.dart';

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

  await loadEnv();

  print('🔍 FIREBASE_PROJECT_ID: ${dotenv.get('FIREBASE_PROJECT_ID')}');
  print('🔍 FIREBASE_API_KEY_WEB: ${dotenv.get('FIREBASE_API_KEY_WEB')}');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ 2. Firebase inicializado com sucesso!');
  } catch (e, s) {
    print('❌ ERRO ao inicializar Firebase: $e');
    print('❌ Stack trace: $s');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Erro: $e\n\nVerifique:\n1. .env na raiz\n2. pubspec.yaml com assets: - .env\n3. web/index.html com Firebase JS',
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
    return;
  }

  print('✅ 3. Executando MyApp...');
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
          return const HomeRedirector();
        }

        return const LoginPage();
      },
    );
  }
}

class HomeRedirector extends StatelessWidget {
  const HomeRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Usuário não encontrado no banco de dados.'),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: Text('Voltar ao login'),
                  ),
                ],
              ),
            ),
          );
        }

        final tipo = snapshot.data!.get('tipo') as String?;

        if (tipo == 'gestor' || tipo == 'supervisor') {
          return const HomeGestor();
        } else if (tipo == 'consultor') {
          return const HomeConsultor();
        } else {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Tipo de usuário não reconhecido: $tipo'),
                  ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: Text('Sair'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
