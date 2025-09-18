import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'home_consultor.dart';
import '../../models/cliente.dart';


class ExportarDadosTab extends StatelessWidget {
  final List<Cliente> clientes;
  const ExportarDadosTab({super.key, required this.clientes});

  Future<File> _createFile(String fileName, String contents) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(contents);
  }

  String _toCsv(List<Cliente> list) {
    final rows = <List<dynamic>>[
      ['Estabelecimento', 'Endereço', 'Data da Visita', 'Nome do Cliente', 'Telefone', 'Observações'],
      ...list.map((c) => [
            c.estabelecimento,
            c.endereco,
            '${c.dataVisita.day.toString().padLeft(2, '0')}/${c.dataVisita.month.toString().padLeft(2, '0')}/${c.dataVisita.year}',
            c.nomeCliente ?? '',
            c.telefone ?? '',
            (c.observacoes ?? '').replaceAll('\n', ' ').trim(),
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  String _onlyNotes(List<Cliente> list) {
    final buffer = StringBuffer();
    for (final c in list) {
      buffer.writeln('Estabelecimento: ${c.estabelecimento}');
      buffer.writeln('Observações: ${c.observacoes ?? '-'}');
      buffer.writeln('---');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Exportar para CRM', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              onPressed: () async {
                if (clientes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nada para exportar')));
                  return;
                }
                final csv = _toCsv(clientes);
                final file = await _createFile('clientes.csv', csv);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV salvo em: ${file.path}')));
                }
              },
              child: const Text('Baixar CSV'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Exportar Observações'),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () async {
                if (clientes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nada para exportar')));
                  return;
                }
                final txt = _onlyNotes(clientes);
                final file = await _createFile('observacoes.txt', txt);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('TXT salvo em: ${file.path}')));
                }
              },
              child: const Text('Baixar TXT'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Obs.: a exportação usa Documents do app; para mover/compartilhar o arquivo, abra pelo gerenciador de arquivos do sistema.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ]),
      ),
    );
  }
}
