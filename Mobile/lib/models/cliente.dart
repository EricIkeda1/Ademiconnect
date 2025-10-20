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

  Cliente copyWith({
    String? id,
    String? nomeCliente,
    String? telefone,
    String? estabelecimento,
    String? estado,
    String? cidade,
    String? endereco,
    String? bairro,
    String? cep,
    DateTime? dataVisita,
    String? observacoes,
    String? consultorResponsavel,
    String? consultorUid,
    String? horaVisita,
  }) {
    return Cliente(
      id: id ?? this.id,
      nomeCliente: nomeCliente ?? this.nomeCliente,
      telefone: telefone ?? this.telefone,
      estabelecimento: estabelecimento ?? this.estabelecimento,
      estado: estado ?? this.estado,
      cidade: cidade ?? this.cidade,
      endereco: endereco ?? this.endereco,
      bairro: bairro ?? this.bairro,
      cep: cep ?? this.cep,
      dataVisita: dataVisita ?? this.dataVisita,
      observacoes: observacoes ?? this.observacoes,
      consultorResponsavel: consultorResponsavel ?? this.consultorResponsavel,
      consultorUid: consultorUid ?? this.consultorUid,
      horaVisita: horaVisita ?? this.horaVisita,
    );
  }

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
        'horaVisita': horaVisita,
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
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
        horaVisita: json['horaVisita'] as String?,
      );

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
        id: map['id'] as String,
        nomeCliente: map['nome'] as String? ?? map['nome_cliente'] as String? ?? '',
        telefone: map['telefone'] as String? ?? '',
        estabelecimento: map['estabelecimento'] as String? ?? '',
        estado: map['estado'] as String? ?? '',
        cidade: map['cidade'] as String? ?? '',
        endereco: map['endereco'] as String? ?? '',
        bairro: map['bairro'] as String?,
        cep: map['cep'] as String?,
        dataVisita: DateTime.parse((map['data_visita'] ?? map['dataVisita']) as String),
        observacoes: map['observacoes'] as String?,
        consultorResponsavel: map['responsavel'] as String? ?? map['consultor_responsavel'] as String?,
        consultorUid: map['consultor_uid_t'] as String? ?? map['consultor_uid'] as String? ?? '',
        horaVisita: map['hora_visita'] as String? ?? map['horaVisita'] as String?,
      );

  Map<String, dynamic> toSupabaseMap() => {
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
        'hora_visita': horaVisita,
      };
}
