import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<void> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('Falha na autenticação');
    }
  }

  Future<void> signUpGestor(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user == null && response.session == null) {
      throw Exception('Falha ao criar usuário');
    }
    
    if (response.user != null) {
      final userId = response.user!.id;
      
      try {
        await _client.from('gestor').insert({
          'id': userId,
          'email': email,
          'tipo': 'gestor',
        });
        
        print('✅ Gestor cadastrado com sucesso: $email');
      } on PostgrestException catch (e) {
        if (response.user != null) {
          await _client.auth.admin.deleteUser(response.user!.id);
        }
        throw Exception('Erro ao registrar gestor: ${e.message}');
      } catch (e) {
        if (response.user != null) {
          await _client.auth.admin.deleteUser(response.user!.id);
        }
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  bool isAuthenticated() {
    final session = _client.auth.currentSession;
    return session != null;
  }

  User? getCurrentUser() {
    return _client.auth.currentSession?.user;
  }
}
