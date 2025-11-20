import 'package:flutter/material.dart';

class GestorHeaderRow extends StatelessWidget {
  final int totalGeral;
  final int totalFiltro;

  final VoidCallback onAvisos;

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onClearQuery;

  final int avisosNaoLidos;

  const GestorHeaderRow({
    super.key,
    required this.totalGeral,
    required this.totalFiltro,
    required this.onAvisos,
    required this.query,
    required this.onQueryChanged,
    this.onClearQuery,
    this.avisosNaoLidos = 0,
  });

  @override
  Widget build(BuildContext context) {
    const branco = Color(0xFFFFFFFF);
    const preto09 = Color(0xFF231F20);
    const cinzaClaro = Color(0xFFDCDDDE);
    const vermelhoClaro = Color(0xFFEA3124);

    final bool emBusca = query.trim().isNotEmpty;
    final String textoTotal =
        emBusca ? '$totalFiltro resultado(s)' : '$totalGeral total';

    return Container(
      color: branco,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ChipBox(
                backgroundColor: vermelhoClaro,
                borderColor: cinzaClaro,
                child: Text(
                  textoTotal,
                  style: const TextStyle(
                    color: branco,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // AVISOS – mesmo tamanho/base do TOTAL
              GestureDetector(
                onTap: onAvisos,
                child: _ChipBox(
                  backgroundColor: branco,
                  borderColor: cinzaClaro,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 16,
                            color: preto09,
                          ),
                          if (avisosNaoLidos > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: vermelhoClaro,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                child: Center(
                                  child: Text(
                                    avisosNaoLidos > 9
                                        ? '9+'
                                        : '$avisosNaoLidos',
                                    style: const TextStyle(
                                      color: branco,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Avisos',
                        style: TextStyle(
                          color: preto09,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  'Meus Leads',
                  style: TextStyle(
                    color: preto09,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SearchPill(
            query: query,
            onChanged: onQueryChanged,
            onClear: onClearQuery,
          ),
        ],
      ),
    );
  }
}

class _ChipBox extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const _ChipBox({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}

class _SearchPill extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const _SearchPill({
    required this.query,
    required this.onChanged,
    this.onClear,
  });

  @override
  State<_SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<_SearchPill> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant _SearchPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query &&
        _controller.text != widget.query) {
      _controller
        ..text = widget.query
        ..selection = TextSelection.fromPosition(
          TextPosition(offset: widget.query.length),
        );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const branco = Color(0xFFFFFFFF);
    const cinzaClaro = Color(0xFFDCDDDE);
    const cinzaIcone = Color(0xFF6B6B6B);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cinzaClaro),
        color: branco,
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search, color: cinzaIcone),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Pesquisar leads...',
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: cinzaIcone),
              onPressed: () {
                if (widget.onClear != null) {
                  widget.onClear!();
                } else {
                  _controller.clear();
                  widget.onChanged('');
                }
              },
              splashRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
