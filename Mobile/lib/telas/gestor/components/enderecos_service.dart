import 'package:supabase_flutter/supabase_flutter.dart';

class BairroResumo {
  final String nome;
  final List<String> enderecos;
  const BairroResumo({required this.nome, required this.enderecos});
}

class EnderecosService {
  final SupabaseClient sb;
  const EnderecosService(this.sb);

  String _removeDiacritics(String text) {
    const map = {
      'Á':'A','À':'A','Â':'A','Ã':'A','Ä':'A','á':'a','à':'a','â':'a','ã':'a','ä':'a',
      'É':'E','È':'E','Ê':'E','Ë':'E','é':'e','è':'e','ê':'e','ë':'e',
      'Í':'I','Ì':'I','Î':'I','Ï':'I','í':'i','ì':'i','î':'i','ï':'i',
      'Ó':'O','Ò':'O','Ô':'O','Õ':'O','Ö':'O','ó':'o','ò':'o','ô':'o','õ':'o','ö':'o',
      'Ú':'U','Ù':'U','Û':'U','Ü':'U','ú':'u','ù':'u','û':'u','ü':'u',
      'Ç':'C','ç':'c','Ñ':'N','ñ':'n','Ý':'Y','ý':'y','ÿ':'y'
    };
    final sb = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  String _normKey(String s) => _removeDiacritics(s).toLowerCase().trim();
  String _stripSpaces(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _toTitle(String s) {
    final base = _removeDiacritics(s).toLowerCase().trim();
    return base.split(RegExp(r'\s+')).map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  String _fixDuplicatedType(String s) {
    final re = RegExp(
      r'^(r\.|rua|av\.|avenida|rod\.|rodovia|al\.|alameda|trav\.|tv\.|travessa)\s+(rua|avenida|rodovia|alameda|travessa)\b',
      caseSensitive: false,
    );
    return s.replaceFirstMapped(re, (m) => m.group(2)!);
  }

  String _normalizeTypePrefix(String s) {
    final re = RegExp(r'^(r\.|rua|av\.|avenida|rod\.|rodovia|al\.|alameda|trav\.|tv\.|travessa)\b', caseSensitive: false);
    final m = re.firstMatch(s);
    if (m != null) {
      final t = m.group(1)!.toLowerCase();
      String full;
      switch (t) {
        case 'r.': case 'rua': full = 'rua'; break;
        case 'av.': case 'avenida': full = 'avenida'; break;
        case 'rod.': case 'rodovia': full = 'rodovia'; break;
        case 'al.': case 'alameda': full = 'alameda'; break;
        case 'trav.': case 'tv.': case 'travessa': full = 'travessa'; break;
        default: full = t;
      }
      s = s.replaceFirst(re, full);
    }
    s = s.replaceFirstMapped(
      RegExp(r'^(rua|avenida|rodovia|alameda|travessa)\s*,\s*', caseSensitive: false),
      (m) => '${m.group(1)} ',
    );
    s = _fixDuplicatedType(s);
    s = s.replaceFirstMapped(RegExp(r'^(rua)\b', caseSensitive: false), (_) => 'R.');
    s = s.replaceFirstMapped(RegExp(r'^(avenida)\b', caseSensitive: false), (_) => 'Av.');
    s = s.replaceFirstMapped(RegExp(r'^(rodovia)\b', caseSensitive: false), (_) => 'Rod.');
    s = s.replaceFirstMapped(RegExp(r'^(alameda)\b', caseSensitive: false), (_) => 'Al.');
    s = s.replaceFirstMapped(RegExp(r'^(travessa)\b', caseSensitive: false), (_) => 'Trav.');
    return s;
  }

  String _endKey({
    required String logradouro,
    required String endereco,
    required String numero,
    required String complemento,
  }) {
    var rua = '$logradouro $endereco';
    rua = _removeDiacritics(rua);
    rua = _normalizeTypePrefix(rua);
    rua = _stripSpaces(rua).toLowerCase();

    final n = _removeDiacritics(numero).toLowerCase().trim();
    final c = _removeDiacritics(complemento).toLowerCase().trim();

    final partes = <String>[];
    if (rua.isNotEmpty) partes.add(rua);
    if (n.isNotEmpty) partes.add(n);
    if (c.isNotEmpty) partes.add(c);
    return partes.join('|'); 
  }

  String _endLabel({
    required String logradouro,
    required String endereco,
    required String numero,
    required String complemento,
  }) {
    var rua = '$logradouro $endereco'.trim();
    rua = _normalizeTypePrefix(rua);
    rua = _stripSpaces(rua);

    final m = RegExp(r'^(R\.|Av\.|Rod\.|Al\.|Trav\.)\s+(.*)$', caseSensitive: false).firstMatch(rua);
    String titulo;
    if (m != null) {
      final pref = m.group(1)!;
      final resto = _toTitle(m.group(2)!);
      titulo = '$pref $resto';
    } else {
      titulo = _toTitle(rua);
    }

    final numClean = numero.trim();
    final comp = complemento.trim();

    final partes = <String>[];
    if (titulo.isNotEmpty) partes.add(titulo);
    if (numClean.isNotEmpty) partes.add(numClean);
    if (comp.isNotEmpty) partes.add(_toTitle(comp));
    return partes.join(', ');
  }

  Future<Map<String, List<BairroResumo>>> listarAgrupadoPorCidade() async {
    final gestorId = sb.auth.currentUser?.id;
    if (gestorId == null) return {};

    final cons = await sb
        .from('consultores')
        .select('uid')
        .filter('gestor_id', 'eq', gestorId)
        .filter('ativo', 'eq', true);

    final uids = (cons is List ? cons : const [])
        .map((e) => (e['uid'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    if (uids.isEmpty) return {};

    final inText = uids.map((e) => '"$e"').join(',');
    final rows = await sb
        .from('clientes')
        .select('cidade, bairro, logradouro, endereco, numero, complemento, consultor_uid_t')
        .filter('consultor_uid_t', 'in', '($inText)');

    final tmp = <String, Map<String, Map<String, String>>>{};

    if (rows is List) {
      for (final r in rows) {
        final cidadeRaw = (r['cidade'] ?? 'Sem cidade').toString();
        final bairroRaw = (r['bairro'] ?? 'Sem bairro').toString();
        final logradouro = (r['logradouro'] ?? '').toString();
        final endereco = (r['endereco'] ?? '').toString();
        final numero = (r['numero'] ?? '').toString();
        final compl = (r['complemento'] ?? '').toString();

        final key = _endKey(
          logradouro: logradouro, endereco: endereco, numero: numero, complemento: compl,
        );
        if (key.isEmpty) continue;

        final label = _endLabel(
          logradouro: logradouro, endereco: endereco, numero: numero, complemento: compl,
        );

        final cidadeKey = _normKey(cidadeRaw);
        final bairroKey  = _normKey(bairroRaw);

        final byCidade = (tmp[cidadeKey] ??= <String, Map<String, String>>{});
        final byBairro = (byCidade[bairroKey] ??= <String, String>{});
        byBairro[key] = label;
      }
    }

    final mapa = <String, List<BairroResumo>>{};
    for (final entry in tmp.entries) {
      final cidadeLabel = _toTitle(entry.key);
      final bairrosMap = entry.value;

      final bairrosList = <BairroResumo>[];
      for (final b in bairrosMap.entries) {
        final lista = b.value.values.toList()..sort();
        final bairroLabel = _toTitle(b.key);
        bairrosList.add(BairroResumo(nome: bairroLabel, enderecos: lista));
      }
      bairrosList.sort((a, b) => a.nome.compareTo(b.nome));
      mapa[cidadeLabel] = bairrosList;
    }

    final ordenado = Map<String, List<BairroResumo>>.fromEntries(
      mapa.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return ordenado;
  }
}
