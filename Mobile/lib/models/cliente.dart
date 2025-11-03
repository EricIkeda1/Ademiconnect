import 'package:meta/meta.dart';

@immutable
class Cliente {
  final String id;
  final String nomeCliente;
  final String telefone;
  final String estabelecimento;
  final String estado;
  final String cidade;

  // Endereço
  final String endereco;
  final String logradouro;
  final int? numero;
  final String? complemento;
  final String? bairro;
  final String? cep;

  // Agendamento
  final DateTime dataVisita;
  final String? horaVisita;

  // Metadados
  final String? observacoes;
  final String? consultorResponsavel;
  final String consultorUid;

  // Negócio
  final String? statusNegociacao; // 'conexao' | 'negociacao' | 'fechada'
  final num? valorProposta;
  final DateTime? dataNegociacao; // NOVO: date
  final String? horaNegociacao;   // NOVO: text

  const Cliente({
    required this.id,
    required this.nomeCliente,
    required this.telefone,
    required this.estabelecimento,
    required this.estado,
    required this.cidade,
    required this.endereco,
    required this.logradouro,
    required this.numero,
    this.complemento,
    this.bairro,
    this.cep,
    required this.dataVisita,
    this.horaVisita,
    this.observacoes,
    this.consultorResponsavel,
    required this.consultorUid,
    this.statusNegociacao,
    this.valorProposta,
    this.dataNegociacao, // novo
    this.horaNegociacao, // novo
  });

  Cliente copyWith({
    String? id,
    String? nomeCliente,
    String? telefone,
    String? estabelecimento,
    String? estado,
    String? cidade,
    String? endereco,
    String? logradouro,
    int? numero,
    String? complemento,
    String? bairro,
    String? cep,
    DateTime? dataVisita,
    String? horaVisita,
    String? observacoes,
    String? consultorResponsavel,
    String? consultorUid,
    String? statusNegociacao,
    num? valorProposta,
    DateTime? dataNegociacao, // novo
    String? horaNegociacao,   // novo
  }) {
    return Cliente(
      id: id ?? this.id,
      nomeCliente: nomeCliente ?? this.nomeCliente,
      telefone: telefone ?? this.telefone,
      estabelecimento: estabelecimento ?? this.estabelecimento,
      estado: estado ?? this.estado,
      cidade: cidade ?? this.cidade,
      endereco: endereco ?? this.endereco,
      logradouro: logradouro ?? this.logradouro,
      numero: numero ?? this.numero,
      complemento: complemento ?? this.complemento,
      bairro: bairro ?? this.bairro,
      cep: cep ?? this.cep,
      dataVisita: dataVisita ?? this.dataVisita,
      horaVisita: horaVisita ?? this.horaVisita,
      observacoes: observacoes ?? this.observacoes,
      consultorResponsavel: consultorResponsavel ?? this.consultorResponsavel,
      consultorUid: consultorUid ?? this.consultorUid,
      statusNegociacao: statusNegociacao ?? this.statusNegociacao,
      valorProposta: valorProposta ?? this.valorProposta,
      dataNegociacao: dataNegociacao ?? this.dataNegociacao, // novo
      horaNegociacao: horaNegociacao ?? this.horaNegociacao, // novo
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
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
        'bairro': bairro,
        'cep': cep,
        'dataVisita': dataVisita.toIso8601String(),
        'horaVisita': horaVisita,
        'observacoes': observacoes,
        'consultorResponsavel': consultorResponsavel,
        'consultorUid': consultorUid,
        'statusNegociacao': statusNegociacao,
        'valorProposta': valorProposta,
        'dataNegociacao': dataNegociacao?.toIso8601String(), // novo
        'horaNegociacao': horaNegociacao,                    // novo
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'] as String,
        nomeCliente: json['nomeCliente'] as String,
        telefone: json['telefone'] as String,
        estabelecimento: json['estabelecimento'] as String,
        estado: json['estado'] as String,
        cidade: json['cidade'] as String,
        endereco: json['endereco'] as String,
        logradouro: json['logradouro'] as String,
        numero: (json['numero'] as num?)?.toInt(),
        complemento: json['complemento'] as String?,
        bairro: json['bairro'] as String?,
        cep: json['cep'] as String?,
        dataVisita: DateTime.parse(json['dataVisita'] as String),
        horaVisita: json['horaVisita'] as String?,
        observacoes: json['observacoes'] as String?,
        consultorResponsavel: json['consultorResponsavel'] as String?,
        consultorUid: json['consultorUid'] as String? ?? '',
        statusNegociacao: json['statusNegociacao'] as String?,
        valorProposta: json['valorProposta'] as num?,
        dataNegociacao: (json['dataNegociacao'] as String?) != null
            ? DateTime.parse(json['dataNegociacao'] as String)
            : null,
        horaNegociacao: json['horaNegociacao'] as String?,
      );

  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
        id: map['id'] as String,
        nomeCliente: map['nome'] as String? ?? map['nome_cliente'] as String? ?? '',
        telefone: map['telefone'] as String? ?? '',
        estabelecimento: map['estabelecimento'] as String? ?? '',
        estado: map['estado'] as String? ?? '',
        cidade: map['cidade'] as String? ?? '',
        endereco: map['endereco'] as String? ?? '',
        logradouro: map['logradouro'] as String? ?? '',
        numero: (map['numero'] as num?)?.toInt(),
        complemento: map['complemento'] as String?,
        bairro: map['bairro'] as String?,
        cep: map['cep'] as String?,
        dataVisita: DateTime.parse((map['data_visita'] ?? map['dataVisita']) as String),
        horaVisita: map['hora_visita'] as String? ?? map['horaVisita'] as String?,
        observacoes: map['observacoes'] as String?,
        consultorResponsavel: map['responsavel'] as String? ?? map['consultor_responsavel'] as String?,
        consultorUid: map['consultor_uid_t'] as String? ?? map['consultor_uid'] as String? ?? '',
        statusNegociacao: map['status_negociacao'] as String? ?? map['statusNegociacao'] as String?,
        valorProposta: (map['valor_proposta'] as num?) ?? (map['valorProposta'] as num?),
        dataNegociacao: (map['data_negociacao'] as String?) != null
            ? DateTime.parse(map['data_negociacao'] as String)
            : null,
        horaNegociacao: map['hora_negociacao'] as String? ?? map['horaNegociacao'] as String?,
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'nome': nomeCliente,
        'telefone': telefone,
        'estabelecimento': estabelecimento,
        'estado': estado,
        'cidade': cidade,
        'endereco': endereco,
        'logradouro': logradouro,
        'numero': numero,
        'complemento': complemento,
        'bairro': bairro,
        'cep': cep,
        'data_visita': dataVisita.toIso8601String(),
        'hora_visita': horaVisita,
        'observacoes': observacoes,
        'responsavel': consultorResponsavel,
        'consultor_uid_t': consultorUid,
        'status_negociacao': statusNegociacao,
        'valor_proposta': valorProposta,
        'data_negociacao': dataNegociacao?.toIso8601String(), // novo
        'hora_negociacao': horaNegociacao,                    // novo
      };

  @override
  String toString() =>
      'Cliente(id=$id, nome=$nomeCliente, cidade=$cidade, logradouro=$logradouro, numero=$numero, status=$statusNegociacao, valor=$valorProposta, dataNeg=$dataNegociacao, horaNeg=$horaNegociacao)';
}
