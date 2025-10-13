import 'package:cloud_firestore/cloud_firestore.dart';

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
        'dataVisita': dataVisita.toIso8601String(),
        'nomeCliente': nomeCliente,
        'telefone': telefone,
        'observacoes': observacoes,
        'consultorResponsavel': consultorResponsavel,
        'consultorUid': consultorUid,
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'],
        estabelecimento: json['estabelecimento'],
        estado: json['estado'],
        cidade: json['cidade'],
        endereco: json['endereco'],
        bairro: json['bairro'],
        cep: json['cep'],
        dataVisita: DateTime.parse(json['dataVisita']),
        nomeCliente: json['nomeCliente'],
        telefone: json['telefone'],
        observacoes: json['observacoes'],
        consultorResponsavel: json['consultorResponsavel'],
        consultorUid: json['consultorUid'] ?? 'desconhecido',
      );

  factory Cliente.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cliente(
      id: doc.id,
      estabelecimento: data['estabelecimento'] ?? '',
      estado: data['estado'] ?? '',
      cidade: data['cidade'] ?? '',
      endereco: data['endereco'] ?? '',
      bairro: data['bairro'],
      cep: data['cep'],
      dataVisita: DateTime.tryParse(data['dataVisita'] ?? '') ?? DateTime.now(),
      nomeCliente: data['nomeCliente'],
      telefone: data['telefone'],
      observacoes: data['observacoes'],
      consultorResponsavel: data['consultorResponsavel'],
      consultorUid: data['consultorUid'] ?? 'desconhecido',
    );
  }
}
