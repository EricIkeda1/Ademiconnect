import 'package:supabase_flutter/supabase_flutter.dart';

class Consultor {
  final String uid;
  final String nome;

  Consultor({required this.uid, required this.nome});

  factory Consultor.fromMap(Map<String, dynamic> map) {
    return Consultor(
      uid: map['id'].toString(),
      nome: (map['nome'] as String?) ?? 'Sem nome',
    );
  }

  Map<String, dynamic> toMap() => {'id': uid, 'nome': nome};
}

class ConsultorService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 🔹 Busca todos os consultores de um gestor
  Future<List<Consultor>> getConsultoresByGestor(String gestorUid) async {
    try {
      final response = await _client
          .from('consultor')
          .select('id, nome')
          .eq('gestor_id', gestorUid)
          .order('nome');

      if (response is List) {
        return response.map((r) => Consultor.fromMap(r)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Erro ao buscar consultores: $e');
      rethrow;
    }
  }

  /// 🔹 Stream em tempo real de consultores (novo formato Supabase)
  Stream<List<Consultor>> getConsultoresStreamByGestor(String gestorUid) {
    return _client
        .from('consultor')
        .stream(primaryKey: ['id']) // ✅ método atualizado
        .eq('gestor_id', gestorUid)
        .order('nome')
        .map((rows) =>
            rows.map((r) => Consultor.fromMap(r as Map<String, dynamic>)).toList())
        .handleError((error) {
      print('❌ Erro na stream: $error');
    });
  }

  /// 🔹 Cria novo consultor
  Future<Consultor> createConsultor({
    required String nome,
    required String gestorId,
    required String email,
    required String uid,
  }) async {
    try {
      final response = await _client
          .from('consultor')
          .insert({
            'nome': nome,
            'gestor_id': gestorId,
            'email': email,
            'uid': uid,
            'tipo': 'consultor',
            'data_cadastro': DateTime.now().toIso8601String(),
          })
          .select('id, nome')
          .single();

      return Consultor.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Erro ao criar consultor: $e');
      rethrow;
    }
  }

  /// 🔹 Atualiza consultor
  Future<void> updateConsultor(Consultor consultor) async {
    try {
      await _client
          .from('consultor')
          .update({'nome': consultor.nome})
          .eq('id', consultor.uid);
    } catch (e) {
      print('❌ Erro ao atualizar consultor: $e');
      rethrow;
    }
  }

  /// 🔹 Exclui consultor
  Future<void> deleteConsultor(String consultorUid) async {
    try {
      await _client.from('consultor').delete().eq('id', consultorUid);
    } catch (e) {
      print('❌ Erro ao excluir consultor: $e');
      rethrow;
    }
  }

  /// 🔹 Busca consultores por nome
  Future<List<Consultor>> searchConsultores(String query, String gestorUid) async {
    try {
      final response = await _client
          .from('consultor')
          .select('id, nome')
          .eq('gestor_id', gestorUid)
          .ilike('nome', '%$query%')
          .order('nome');

      if (response is List) {
        return response.map((r) => Consultor.fromMap(r)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Erro ao buscar consultores: $e');
      rethrow;
    }
  }
}
