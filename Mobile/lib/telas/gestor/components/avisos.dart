import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvisosSheet extends StatefulWidget {
  final List<Map<String, dynamic>>? leads;
  const AvisosSheet({super.key, this.leads});

  @override
  State<AvisosSheet> createState() => _AvisosSheetState();
}

class _AvisosSheetState extends State<AvisosSheet> {
  static const texto = Color(0xFF231F20);
  static const branco = Color(0xFFFFFFFF);

  final _sb = Supabase.instance.client;

  final List<_Aviso> _itens = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _loadingMore = false;
  int _page = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _carregar(initial: true);
  }

  String _dataStr(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<_Aviso> _buildAtrasos(List<Map<String, dynamic>> leads) {
    final out = <_Aviso>[];
    final now = DateTime.now();

    for (final c in leads) {
      final id = c['id']?.toString() ?? '';
      final nome = (c['nome'] ?? '').toString();
      final dias = (c['dias'] as int?) ?? -1;
      final dvRaw = c['data_visita'];
      DateTime dataV;
      if (dvRaw is DateTime) {
        dataV = dvRaw;
      } else {
        dataV = DateTime.tryParse((dvRaw ?? '').toString()) ?? now;
      }
      if (dias < 84) continue;

      if (dias >= 90) {
        out.add(_Aviso(
          id: 'synthetic:urgente:$id',
          tipo: _TipoAviso.urgente,
          titulo: 'PAP - Retorno Urgente',
          mensagem:
              'O lead $nome está com $dias dias sem retorno. Providencie contato imediato.',
          data: dataV,
          lido: false,
          ref: 'lead:$id',
        ));
      } else {
        out.add(_Aviso(
          id: 'synthetic:programado:$id',
          tipo: _TipoAviso.programado,
          titulo: 'PAP - Retorno Programado',
          mensagem:
              'O lead $nome atinge 84+ dias ($dias dias). Programe o retorno.',
          data: dataV,
          lido: false,
          ref: 'lead:$id',
        ));
      }
    }
    return out;
  }

  Future<void> _carregar({bool initial = false}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _itens.clear();
        _page = 0;
        _hasMore = true;
        _loadingMore = false;
      });
    }
    if (!_hasMore || _loadingMore) return;

    try {
      setState(() => _loadingMore = true);
      final uid = _sb.auth.currentUser?.id;

      final start = _page * _pageSize;
      final end = start + _pageSize - 1;

      List realRows = [];
      if (uid != null) {
        realRows = await _sb
            .from('notificacoes')
            .select('id, user_id, ref, tipo, titulo, mensagem, data, lido')
            .eq('user_id', uid)
            .order('data', ascending: false)
            .range(start, end) as List;
      }
      final reais = <_Aviso>[];
      for (final r in realRows) {
        reais.add(_Aviso(
          id: r['id'].toString(),
          tipo: _TipoAvisoX.parse((r['tipo'] ?? '').toString()),
          titulo: (r['titulo'] ?? '').toString(),
          mensagem: (r['mensagem'] ?? '').toString(),
          data: DateTime.tryParse((r['data'] ?? '').toString()) ?? DateTime.now(),
          lido: (r['lido'] ?? false) == true,
          ref: (r['ref'] ?? '').toString(),
        ));
      }

      final leads = widget.leads ?? [];
      final sinteticos = leads.isEmpty ? <_Aviso>[] : _buildAtrasos(leads);

      final seen = <String>{ for (final a in reais) a.dedupeKey };
      final merged = <_Aviso>[];
      merged.addAll(reais);
      for (final s in sinteticos) {
        if (!seen.contains(s.dedupeKey)) merged.add(s);
      }

      merged.sort((a, b) => b.data.compareTo(a.data));

      setState(() {
        _itens.addAll(merged);
        _page += 1;
        _hasMore = realRows.length == _pageSize; 
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _marcarComoLido(String id, bool lido) async {
    if (!id.startsWith('synthetic:')) {
      try {
        await _sb.from('notificacoes').update({'lido': lido}).eq('id', id);
      } catch (_) {}
    }
    final i = _itens.indexWhere((e) => e.id == id);
    if (i >= 0) setState(() => _itens[i] = _itens[i].copyWith(lido: lido));
  }

  Future<void> _marcarTodasComoLidas() async {
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid != null) {
        await _sb.from('notificacoes').update({'lido': true}).eq('user_id', uid);
      }
      setState(() {
        for (var i = 0; i < _itens.length; i++) {
          _itens[i] = _itens[i].copyWith(lido: true);
        }
      });
    } catch (_) {}
  }

  int get _novas => _itens.where((e) => !e.lido).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_none_rounded, color: Color(0xFFEA3124)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Notificações',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: texto,
                      ),
                    ),
                  ),
                  if (_novas > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED1C24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_novas novas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Marcar todas como lidas',
                    icon: const Icon(Icons.mark_email_read_outlined),
                    onPressed: _novas == 0 ? null : _marcarTodasComoLidas,
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading && _itens.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _carregar(initial: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: _itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final a = _itens[i];
                      final urgenteChip = a.tipo == _TipoAviso.urgente;

                      return Material(
                        color: branco,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: a.isRedBorder
                                ? const Color(0xFFEA3124)
                                : const Color(0xFFDFDFDF),
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _marcarComoLido(a.id, !a.lido),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(a.iconData, color: a.iconColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.titulo,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: texto.withOpacity(a.lido ? 0.6 : 1.0),
                                        ),
                                      ),
                                    ),
                                    if (urgenteChip)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA3124),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Urgente',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a.mensagem,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: const Color(0xFF4B4B4F)
                                        .withOpacity(a.lido ? 0.6 : 1.0),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _dataStr(a.data),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF9A9AA0)
                                        .withOpacity(a.lido ? 0.6 : 1.0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _TipoAviso { urgente, programado, lead, lembrete, transferido, mensagem }

class _TipoAvisoX {
  static _TipoAviso parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'urgente':
        return _TipoAviso.urgente;
      case 'programado':
        return _TipoAviso.programado;
      case 'lead':
        return _TipoAviso.lead;
      case 'lembrete':
        return _TipoAviso.lembrete;
      case 'transferido':
        return _TipoAviso.transferido;
      case 'mensagem':
        return _TipoAviso.mensagem;
      default:
        return _TipoAviso.lembrete;
    }
  }
}

class _Aviso {
  final String id;      
  final _TipoAviso tipo;
  final String titulo;
  final String mensagem;
  final DateTime data;
  final bool lido;
  final String ref;    

  const _Aviso({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensagem,
    required this.data,
    required this.lido,
    this.ref = '',
  });

  bool get isRedBorder => tipo == _TipoAviso.urgente || tipo == _TipoAviso.programado;

  String get dedupeKey => ref.isNotEmpty ? '${tipo.name}|$ref' : '${tipo.name}|$titulo';

  IconData get iconData {
    switch (tipo) {
      case _TipoAviso.urgente:
        return Icons.notifications_active_outlined;
      case _TipoAviso.programado:
        return Icons.event_note_outlined;
      case _TipoAviso.lead:
        return Icons.check_circle_outline;
      case _TipoAviso.lembrete:
        return Icons.notifications_none_outlined;
      case _TipoAviso.transferido:
        return Icons.swap_horiz_outlined;
      case _TipoAviso.mensagem:
        return Icons.chat_bubble_outline;
    }
  }

  Color get iconColor {
    switch (tipo) {
      case _TipoAviso.urgente:
      case _TipoAviso.programado:
        return const Color(0xFFEA3124);
      case _TipoAviso.lead:
        return const Color(0xFF2E7D32);
      case _TipoAviso.lembrete:
        return const Color(0xFF9FA3A9);
      case _TipoAviso.transferido:
      case _TipoAviso.mensagem:
        return const Color(0xFF6D6D6D);
    }
  }

  _Aviso copyWith({
    String? id,
    _TipoAviso? tipo,
    String? titulo,
    String? mensagem,
    DateTime? data,
    bool? lido,
    String? ref,
  }) {
    return _Aviso(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      data: data ?? this.data,
      lido: lido ?? this.lido,
      ref: ref ?? this.ref,
    );
  }
}
