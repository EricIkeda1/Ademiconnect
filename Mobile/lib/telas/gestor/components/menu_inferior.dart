import 'package:flutter/material.dart';

class MenuInferior extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final PageController controller;

  const MenuInferior({
    super.key,
    required this.index,
    required this.onChanged,
    required this.controller,
  });

  @override
  State<MenuInferior> createState() => _MenuInferiorState();
}

class _MenuInferiorState extends State<MenuInferior> {
  // Cores
  static const _bg = Color(0xFFFFFFFF);
  static const _pillA = Color(0xFFEA3124);
  static const _pillB = Color(0xFFD03025);
  static const _off = Color(0xFF6B6B6B);
  static const _shadow = Color(0x14000000);

  final _items = const [
    _Item(icon: Icons.people_alt_rounded, label: 'Leads'),
    _Item(icon: Icons.account_circle_rounded, label: 'Consultores'),
    _Item(icon: Icons.place_rounded, label: 'Endereços'),
    _Item(icon: Icons.file_download_rounded, label: 'Exportar'),
  ];

  // Geometria ajustada para o mesmo tamanho da imagem
  static const double _barH = 68; // altura total da barra
  static const double _pillH = 54; // altura do "pill" vermelho
  static const double _pillW = 90; // largura do "pill"
  static const double _pillRadius = 20;
  static const double _padBottom = 10;

  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.controller.initialPage.toDouble();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final p = widget.controller.page;
    if (p != null && p != _page) setState(() => _page = p);
  }

  Rect _pillRect(Size size) {
    final count = _items.length;
    final slotW = size.width / count;
    final double y = (_barH - _pillH) / 2;
    final double x =
        (_page.clamp(0.0, (count - 1).toDouble()) * slotW) + (slotW - _pillW) / 2;
    return Rect.fromLTWH(x, y, _pillW, _pillH);
  }

  void _onDragEnd(DragEndDetails d) {
    final target = _page.round();
    widget.controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, cons) {
          final pill = _pillRect(Size(cons.maxWidth, _barH));
          final current = (widget.controller.page ??
                  widget.controller.initialPage.toDouble())
              .round();

          return Container(
            decoration: const BoxDecoration(
              color: _bg,
              boxShadow: [
                BoxShadow(color: _shadow, blurRadius: 4, offset: Offset(0, -1)),
              ],
            ),
            height: _barH + _padBottom,
            padding: const EdgeInsets.only(bottom: _padBottom),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fundo gradiente do item ativo
                Positioned(
                  left: pill.left,
                  top: pill.top,
                  width: pill.width,
                  height: pill.height,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_pillA, _pillB],
                        ),
                        borderRadius: BorderRadius.circular(_pillRadius),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Itens inativos
                Row(
                  children: List.generate(_items.length, (i) {
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => widget.onChanged(i),
                        child: SizedBox(
                          height: _barH,
                          child: Center(child: _ItemOff(item: _items[i])),
                        ),
                      ),
                    );
                  }),
                ),

                // Item ativo
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        final active = current == i;
                        return Expanded(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 120),
                            opacity: active ? 1.0 : 0.0,
                            child: SizedBox(
                              height: _barH,
                              child: Center(child: _ItemOn(item: _items[i])),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  const _Item({required this.icon, required this.label});
}

class _ItemOff extends StatelessWidget {
  final _Item item;
  const _ItemOff({required this.item});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6B6B6B);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 24, color: color),
        const SizedBox(height: 6),
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ItemOn extends StatelessWidget {
  final _Item item;
  const _ItemOn({required this.item});

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 26, color: white),
        const SizedBox(height: 6),
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 11.5,
            color: white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
