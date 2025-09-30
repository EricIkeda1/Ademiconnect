class Cliente {
  final String estabelecimento;
  final String estado;
  final String cidade;
  final String endereco;
  final DateTime dataVisita;
  final String? nomeCliente;
  final String? telefone;
  final String? observacoes;
  final String id;

  Cliente({
    required this.estabelecimento,
    required this.estado,
    required this.cidade,
    required this.endereco,
    required this.dataVisita,
    this.nomeCliente,
    this.telefone,
    this.observacoes,
    String? id,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'estabelecimento': estabelecimento,
      'estado': estado,
      'cidade': cidade,
      'endereco': endereco,
      'dataVisita': dataVisita.toIso8601String(),
      'nomeCliente': nomeCliente,
      'telefone': telefone,
      'observacoes': observacoes,
    };
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'],
      estabelecimento: json['estabelecimento'],
      estado: json['estado'],
      cidade: json['cidade'],
      endereco: json['endereco'],
      dataVisita: DateTime.parse(json['dataVisita']),
      nomeCliente: json['nomeCliente'],
      telefone: json['telefone'],
      observacoes: json['observacoes'],
    );
  }
}
