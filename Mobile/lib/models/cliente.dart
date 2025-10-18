// lib/models/cliente.dart
class Cliente {
  final String id;
  final String nomeCliente;
  final String telefone;
  final String estabelecimento;
  final String estado;
  final String cidade;
  final String endereco;
  final String? bairro;
  final String? cep;
  final DateTime dataVisita;
  final String? observacoes;
  final String? consultorResponsavel;
  final String consultorUid;

  // ✅ Novo campo: hora da visita
  final String? horaVisita;

  Cliente({
    required this.id,
    required this.nomeCliente,
    required this.telefone,
    required this.estabelecimento,
    required this.estado,
    required this.cidade,
    required this.endereco,
    this.bairro,
    this.cep,
    required this.dataVisita,
    this.observacoes,
    this.consultorResponsavel,
    required this.consultorUid,
    this.horaVisita,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nomeCliente': nomeCliente,
        'telefone': telefone,
        'estabelecimento': estabelecimento,
        'estado': estado,
        'cidade': cidade,
        'endereco': endereco,
        'bairro': bairro,
        'cep': cep,
        'dataVisita': dataVisita.toIso8601String(),
        'observacoes': observacoes,
        'consultorResponsavel': consultorResponsavel,
        'consultorUid': consultorUid,
        // ✅ Salva a hora
        'horaVisita': horaVisita,
      };

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] as String,
      nomeCliente: json['nomeCliente'] as String,
      telefone: json['telefone'] as String,
      estabelecimento: json['estabelecimento'] as String,
      estado: json['estado'] as String,
      cidade: json['cidade'] as String,
      endereco: json['endereco'] as String,
      bairro: json['bairro'] as String?,
      cep: json['cep'] as String?,
      dataVisita: DateTime.parse(json['dataVisita'] as String),
      observacoes: json['observacoes'] as String?,
      consultorResponsavel: json['consultorResponsavel'] as String?,
      consultorUid: json['consultorUid'] as String? ?? '',
      // ✅ Lê a hora do JSON
      horaVisita: json['horaVisita'] as String?,
    );
  }

  // Mantenha o fromMap para compatibilidade com Supabase
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as String,
      nomeCliente: map['nome'] as String? ?? 'Sem nome',
      telefone: map['telefone'] as String? ?? '',
      estabelecimento: map['estabelecimento'] as String? ?? 'Cliente',
      estado: map['estado'] as String? ?? '',
      cidade: map['cidade'] as String? ?? '',
      endereco: map['endereco'] as String? ?? '',
      bairro: map['bairro'] as String?,
      cep: map['cep'] as String?,
      dataVisita: DateTime.parse(map['data_visita'] as String),
      observacoes: map['observacoes'] as String?,
      consultorResponsavel: map['responsavel'] as String?,
      consultorUid: map['consultor_uid_t'] as String? ?? '',
      // ✅ Lê do banco
      horaVisita: map['hora_visita'] as String?,
    );
  }

  // Para enviar ao Supabase (se precisar)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nomeCliente,
      'telefone': telefone,
      'estabelecimento': estabelecimento,
      'estado': estado,
      'cidade': cidade,
      'endereco': endereco,
      'bairro': bairro,
      'cep': cep,
      'data_visita': dataVisita.toIso8601String(),
      'observacoes': observacoes,
      'responsavel': consultorResponsavel,
      'consultor_uid_t': consultorUid,
      // ✅ Envia para o banco
      'hora_visita': horaVisita,
    };
  }

  @override
  String toString() {
    return 'Cliente(id: $id, estabelecimento: $estabelecimento, dataVisita: $dataVisita, horaVisita: $horaVisita)';
  }
}
