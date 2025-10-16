class Cliente {
  final String id;
  final String estabelecimento;
  final String estado;
  final String cidade;
  final String endereco;
  final String? bairro;
  final String? cep;
  final DateTime dataVisita;
  final String? nomeCliente;
  final String? telefone;
  final String? observacoes;
  final String? consultorResponsavel;
  final String consultorUid; // adicionado campo obrigatório

  Cliente({
    required this.estabelecimento,
    required this.estado,
    required this.cidade,
    required this.endereco,
    required this.dataVisita,
    required this.consultorUid,
    this.bairro,
    this.cep,
    this.nomeCliente,
    this.telefone,
    this.observacoes,
    this.consultorResponsavel,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'estabelecimento': estabelecimento,
        'estado': estado,
        'cidade': cidade,
        'endereco': endereco,
        'bairro': bairro,
        'cep': cep,
        'data_visita': dataVisita.toIso8601String(),  // snake_case for Supabase
        'nome_cliente': nomeCliente,                  // snake_case for Supabase
        'telefone': telefone,
        'observacoes': observacoes,
        'consultor_responsavel': consultorResponsavel,
        'consultor_uid': consultorUid,                // snake_case for Supabase
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'],
        estabelecimento: json['estabelecimento'],
        estado: json['estado'],
        cidade: json['cidade'],
        endereco: json['endereco'],
        bairro: json['bairro'],
        cep: json['cep'],
        dataVisita: DateTime.parse(json['data_visita'] ?? json['dataVisita'] ?? ''),
        nomeCliente: json['nome_cliente'] ?? json['nomeCliente'],
        telefone: json['telefone'],
        observacoes: json['observacoes'],
        consultorResponsavel: json['consultor_responsavel'] ?? json['consultorResponsavel'],
        consultorUid: json['consultor_uid'] ?? json['consultorUid'] ?? 'desconhecido',
      );

  // New factory for Supabase - uses snake_case field names
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      estabelecimento: map['estabelecimento'],
      estado: map['estado'],
      cidade: map['cidade'],
      endereco: map['endereco'],
      bairro: map['bairro'],
      cep: map['cep'],
      dataVisita: map['data_visita'] is String 
          ? DateTime.parse(map['data_visita'])
          : map['data_visita'],
      nomeCliente: map['nome_cliente'],
      telefone: map['telefone'],
      observacoes: map['observacoes'],
      consultorResponsavel: map['consultor_responsavel'],
      consultorUid: map['consultor_uid'] ?? 'desconhecido',
    );
  }

  // toMap for database operations (snake_case)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'estabelecimento': estabelecimento,
      'estado': estado,
      'cidade': cidade,
      'endereco': endereco,
      'bairro': bairro,
      'cep': cep,
      'data_visita': dataVisita.toIso8601String(),
      'nome_cliente': nomeCliente,
      'telefone': telefone,
      'observacoes': observacoes,
      'consultor_responsavel': consultorResponsavel,
      'consultor_uid': consultorUid,
    };
  }
}
