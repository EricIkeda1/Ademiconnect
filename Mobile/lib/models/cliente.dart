import 'package:cloud_firestore/cloud_firestore.dart';

class Cliente {
  final String id;
  final String estabelecimento;
  final String estado;
  final String cidade;
  final String endereco;
  final DateTime dataVisita;
  final String? nomeCliente;
  final String? telefone;
  final String? observacoes;
  final String? consultorResponsavel;

  Cliente({
    required this.estabelecimento,
    required this.estado,
    required this.cidade,
    required this.endereco,
    required this.dataVisita,
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
        'dataVisita': dataVisita.toIso8601String(),
        'nomeCliente': nomeCliente,
        'telefone': telefone,
        'observacoes': observacoes,
        'consultorResponsavel': consultorResponsavel,
      };

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
        id: json['id'],
        estabelecimento: json['estabelecimento'],
        estado: json['estado'],
        cidade: json['cidade'],
        endereco: json['endereco'],
        dataVisita: DateTime.parse(json['dataVisita']),
        nomeCliente: json['nomeCliente'],
        telefone: json['telefone'],
        observacoes: json['observacoes'],
        consultorResponsavel: json['consultorResponsavel'],
      );

  factory Cliente.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cliente(
      id: doc.id,
      estabelecimento: data['estabelecimento'] ?? '',
      estado: data['estado'] ?? '',
      cidade: data['cidade'] ?? '',
      endereco: data['endereco'] ?? '',
      dataVisita: DateTime.tryParse(data['dataVisita'] ?? '') ?? DateTime.now(),
      nomeCliente: data['nomeCliente'],
      telefone: data['telefone'],
      observacoes: data['observacoes'],
      consultorResponsavel: data['consultorResponsavel'],
    );
  }
}
