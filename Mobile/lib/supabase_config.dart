import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    
    final url = dotenv.get('SUPABASE_URL');
    final anonKey = dotenv.get('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception('Configuração do Supabase não encontrada no .env');
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
