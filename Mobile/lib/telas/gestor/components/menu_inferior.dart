import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class MenuInferior extends StatefulWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final PageController controller;

  final VoidCallback? onLeads;
  final VoidCallback? onVendas;
  final VoidCallback? onConsultores;
  final VoidCallback? onEnderecos;
  final VoidCallback? onExportar;

  const MenuInferior({
    super.key,
    required this.index,
    required this.onChanged,
    required this.controller,
    this.onLeads,
    this.onVendas,
    this.onConsultores,
    this.onEnderecos,
    this.onExportar,
  });

  @override
  State<MenuInferior> createState() => _MenuInferiorState();
}

class _MenuInferiorState extends State<MenuInferior> {
  static const _bg = Color(0xFFFFFFFF);
  static const _pillA = Color(0xFFED3B2E);
  static const _pillB = Color(0xFFCC2B22);
  static const _halo = Color(0x33ED3B2E);
  static const _shadow = Color(0x14000000);

  static const double _barH = 74;
  static const double _pillH = 56;
  static const double _pillW = 100;
  static const double _padBottom = 10;

  final _items = const [
    _Item(icon: Icons.people_alt_rounded, label: 'Leads'),
    _Item(icon: Icons.show_chart_rounded, label: 'Vendas'),
    _Item(icon: Icons.person_rounded, label: 'Consultores'),
    _Item(icon: Icons.place_rounded, label: 'Endereços'),
    _Item(icon: Icons.file_download_rounded, label: 'Exportar'),
  ];

  double _page = 0;

  double _lastEmitted = -10000;
  static const double _throttleDelta = 0.007;
  static const double _snapEps = 0.02;
  int _lastStableIndex = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.controller.initialPage.toDouble();
    _lastStableIndex = _page.round();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant MenuInferior oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idx = widget.index.toDouble();
    final cp = widget.controller.page;
    if ((idx - _page).abs() > 0.001 &&
        (cp == null || (cp - idx).abs() <= _snapEps)) {
      _page = idx;
      _lastStableIndex = idx.toInt();
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final p = widget.controller.page;
    if (p == null || p.isNaN) return;

    if ((p - _lastEmitted).abs() < _throttleDelta) return;
    _lastEmitted = p;

    final nearest = p.roundToDouble();
    final delta = (p - nearest).abs();

    if (delta <= _snapEps) {
      final ni = nearest.toInt();
      if (ni != _lastStableIndex || (nearest - _page).abs() > 0.001) {
        _lastStableIndex = ni;
        setState(() => _page = nearest);
      }
      return;
    }

    if ((p - _page).abs() > 0.003) {
      setState(() => _page = p);
    }
  }

  Rect _pillRect(Size size) {
    final count = _items.length;
    final slotW = size.width / count;
    final double y = (_barH - _pillH) / 2;
    final double x = (_page.clamp(0.0, (count - 1).toDouble()) * slotW) +
        (slotW - _pillW) / 2;
    return Rect.fromLTWH(x, y, _pillW, _pillH);
  }

  void _handleTap(int i) {
    switch (i) {
      case 0:
        widget.onLeads?.call();
        break;
      case 1:
        widget.onVendas?.call();
        break;
      case 2:
        widget.onConsultores?.call();
        break;
      case 3:
        widget.onEnderecos?.call();
        break;
      case 4:
        widget.onExportar?.call();
        break;
    }
    widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      splashColor: Colors.white.withOpacity(0.08),
      highlightColor: Colors.white.withOpacity(0.04),
    );

    return Theme(
      data: theme,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, cons) {
            final pill = _pillRect(Size(cons.maxWidth, _barH));

            final base = _lastStableIndex.toDouble();
            final next = (_page >= base) ? base + 1.0 : base - 1.0;
            final spanStart = (_page >= base) ? base : next;
            final spanEnd = (_page >= base) ? next : base;
            final fracRaw =
                ((_page - spanStart) / (spanEnd - spanStart)).clamp(0.0, 1.0);
            final eased = Curves.easeInOut.transform(fracRaw);
            final goingRight = _page >= base;
            final inertia =
                (goingRight ? eased : -(1 - eased)) * (8.0 * (1.0 + 0.4 * ((-_page + base).abs() + (_page - base).abs()) * 0.5));

            final blur = lerpDouble(12, 18, eased)!;
            final dy = lerpDouble(-2, -3, eased)!;

            return Container(
              decoration: const BoxDecoration(
                color: _bg,
                boxShadow: [
                  BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0, -2))
                ],
              ),
              height: _barH + _padBottom,
              padding: const EdgeInsets.only(bottom: _padBottom),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Row(
                        children: List.generate(_items.length, (i) {
                          final dist = (_page - i).abs().clamp(0.0, 1.0);
                          final ti = 1.0 - Curves.easeOut.transform(dist);
                          return Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              opacity: lerpDouble(0.0, 1.0, ti * 0.6)!,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(0, 0.4),
                                    radius: 0.85,
                                    colors: [
                                      Color(0x14FFFFFF), 
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  Positioned(
                    left: pill.left - 18 + inertia,
                    top: pill.top - 10 + dy,
                    width: pill.width + 36,
                    height: pill.height + 20,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _halo,
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LiquidPillPainter(
                          page: _page,
                          count: _items.length,
                          pillH: _pillH,
                          pillW: _pillW,
                          barH: _barH,
                          colorA: _pillA,
                          colorB: _pillB,
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: List.generate(_items.length, (i) {
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _handleTap(i),
                            child: SizedBox(
                              height: _barH,
                              child: _AnimatedItem(
                                item: _items[i],
                                index: i,
                                page: _page,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String label;
  const _Item({required this.icon, required this.label});
}

class _AnimatedItem extends StatelessWidget {
  final _Item item;
  final int index;
  final double page;
  const _AnimatedItem(
      {required this.item, required this.index, required this.page});

  static const Color _inactive = Color(0xFF6B6B6B);

  @override
  Widget build(BuildContext context) {
    final dist = (page - index).abs().clamp(0.0, 1.0);
    final t = 1.0 - Curves.easeOut.transform(dist);
    final iconSize = lerpDouble(24, 28, t)!;
    final labelSize = lerpDouble(11, 12.5, t)!;
    final iconColor = Color.lerp(_inactive, Colors.white, t)!;
    final labelColor = Color.lerp(_inactive, Colors.white, t)!;
    final fontWeight = t > 0.6 ? FontWeight.w700 : FontWeight.w500;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            offset: Offset(0, lerpDouble(0.10, 0.0, t)!), 
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              opacity: lerpDouble(0.85, 1.0, t)!,
              child: Transform.scale(
                scale: lerpDouble(1.0, 1.05, t)!,
                child: Icon(item.icon, size: iconSize, color: iconColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            offset: Offset(0, lerpDouble(-0.06, 0.0, t)!), 
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 120),
              style: TextStyle(
                fontSize: labelSize,
                color: labelColor,
                fontWeight: fontWeight,
              ),
              child: Text(item.label),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidPillPainter extends CustomPainter {
  final double page;
  final int count;
  final double pillH;
  final double pillW;
  final double barH;
  final Color colorA, colorB;

  _LiquidPillPainter({
    required this.page,
    required this.count,
    required this.pillH,
    required this.pillW,
    required this.barH,
    required this.colorA,
    required this.colorB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final slotW = size.width / count;
    final y = (barH - pillH) / 2;
    final base = page.floor().clamp(0, count - 1);
    final frac = (page - base).clamp(0.0, 1.0);

    final startX = (base * slotW) + (slotW - pillW) / 2;
    final endX =
        (((base + 1).clamp(0, count - 1)) * slotW) + (slotW - pillW) / 2;

    final stretch = 1 + 0.06 * math.sin(frac * math.pi);
    final w = pillW * stretch;
    final x = lerpDouble(startX, endX, frac)! + (pillW - w) / 2;

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, pillH),
      const Radius.circular(22),
    );

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(colorA, colorB, 0.2 + 0.8 * frac)!,
        Color.lerp(colorB, colorA, 0.2 + 0.8 * frac)!,
      ],
    ).createShader(r.outerRect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;
    final light = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final glow = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawRRect(r, paint);
    canvas.drawRRect(r, glow);
    canvas.drawRRect(r, light);
  }

  @override
  bool shouldRepaint(covariant _LiquidPillPainter old) {
    return old.page != page ||
        old.count != count ||
        old.pillH != pillH ||
        old.pillW != pillW ||
        old.barH != barH ||
        old.colorA != colorA ||
        old.colorB != colorB;
  }
}
