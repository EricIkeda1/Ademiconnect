import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  /// Faz login com email e senha
  Future<void> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('Falha na autenticação');
    }
  }

  /// Cadastra um novo gestor no sistema
  Future<void> signUpGestor(String email, String password) async {
    // 1. Cria usuário no Supabase Auth
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    // CORREÇÃO: Para gotrue 2.16.0, verificamos user e session
    if (response.user == null && response.session == null) {
      throw Exception('Falha ao criar usuário');
    }
    
    // 2. Se o usuário foi criado com sucesso, adiciona na tabela gestor
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
        // Se der erro ao inserir na tabela gestor, limpa o usuário criado
        if (response.user != null) {
          await _client.auth.admin.deleteUser(response.user!.id);
        }
        throw Exception('Erro ao registrar gestor: ${e.message}');
      } catch (e) {
        // Limpa usuário criado se der qualquer outro erro
        if (response.user != null) {
          await _client.auth.admin.deleteUser(response.user!.id);
        }
        rethrow;
      }
    }
  }

  /// Faz logout do usuário atual
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Verifica se há uma sessão ativa
  bool isAuthenticated() {
    final session = _client.auth.currentSession;
    return session != null;
  }

  /// Obtém o usuário atual
  User? getCurrentUser() {
    return _client.auth.currentSession?.user;
  }
}
