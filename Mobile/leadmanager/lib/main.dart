import 'package:flutter/material.dart';
import 'telas/login.dart';
import 'telas/dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ADEMICON Londrina",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const Dashboard(),
      },
    );
  }
}