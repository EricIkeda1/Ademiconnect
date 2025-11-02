import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});
  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _chan;

  String consultor = '';

  double totalVendas = 0;
  double mediaMensal = 0;
  double melhorMesValor = 0;
  int periodoMeses = 6;

  List<String> meses = [];
  List<double> realizado = [];

  final Color primary = const Color(0xFFDC2C2C);
  final Color primaryLight = const Color(0xFFF06666);

  String moeda(double v) => NumberFormat.simpleCurrency(locale: 'pt_BR').format(v);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarDados());
    _inscreverRealtime();
  }

  @override
  void dispose() {
    if (_chan != null) {
      _client.removeChannel(_chan!);
    }
    super.dispose();
  }

  void _inscreverRealtime() {
    try {
      _chan = _client
          .channel('realtime:dash_vendas_finalizadas')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'clientes',
            callback: (_) {
              if (mounted) {
                _carregarDados();
              }
            },
          )
          .subscribe();
    } catch (e) {
    }
  }

  Future<void> _carregarDados() async {
    try {
      final mensal = await _client
          .from('vendas_mensais')
          .select('mes_ord, mes_abrev, realizado')
          .order('mes_ord', ascending: true);

      if (mensal is List && mensal.isNotEmpty) {
        if (mounted) {
          setState(() {
            meses = mensal.map((e) => (e['mes_abrev'] ?? '').toString()).toList().cast<String>();
            realizado = mensal.map((e) => (e['realizado'] ?? 0).toDouble()).toList().cast<double>();
          });
        }
      } else {
        await _agregarLocalmenteApenasFinalizadas();
      }

      final kpis = await _client.from('vendas_kpis').select().limit(1);
      if (kpis is List && kpis.isNotEmpty) {
        final k = kpis.first as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            totalVendas = (k['total_vendas'] ?? 0).toDouble();
            mediaMensal = (k['media_mensal'] ?? 0).toDouble();
            melhorMesValor = (k['melhor_mes'] ?? 0).toDouble();
            periodoMeses = (k['periodo_meses'] ?? 6).toInt();
          });
        }
      } else {
        _calcularKpisFallback();
      }

    } catch (_) {
      await _agregarLocalmenteApenasFinalizadas();
      _calcularKpisFallback();
    }
  }

  Future<void> _agregarLocalmenteApenasFinalizadas() async {
    final now = DateTime.now();
    final inicio = DateTime(now.year, now.month - 5, 1);
    final inicioStr = DateFormat('yyyy-MM-dd').format(inicio);

    try {
      final res = await _client
          .from('clientes')
          .select('data_visita, status_negociacao, valor_proposta')
          .filter('status_negociacao', 'in', '("fechado","fechada","venda")')
          .gte('data_visita', inicioStr)
          .order('data_visita', ascending: true);

      final Map<String, double> somaMes = {};
      final DateFormat abrev = DateFormat('MMM', 'pt_BR');

      for (var i = 0; i < 6; i++) {
        final d = DateTime(now.year, now.month - 5 + i, 1);
        final key = abrev.format(d);
        somaMes[key] = 0;
      }

      if (res is List) {
        for (final row in res) {
          final ds = (row['data_visita'] ?? '').toString();
          if (ds.isEmpty) continue;
          final d = DateTime.tryParse(ds)?.toLocal();
          if (d == null) continue;

          final key = abrev.format(DateTime(d.year, d.month, 1));

          final rawValor = row['valor_proposta'];
          final v = switch (rawValor) {
            num n => n.toDouble(),
            String s => double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0,
            _ => 0.0,
          };

          somaMes.update(key, (old) => old + v, ifAbsent: () => v);
        }
      }

      final sortedMeses = somaMes.keys.toList()
        ..sort((a, b) {
          final order = ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'];
          return order.indexOf(a.toLowerCase()).compareTo(order.indexOf(b.toLowerCase()));
        });

      if (mounted) {
        setState(() {
          meses = sortedMeses;
          realizado = sortedMeses.map((m) => somaMes[m] ?? 0).toList();
        });
      }
    } catch (e) {    }
  }

  void _calcularKpisFallback() {
    if (mounted) {
      setState(() {
        totalVendas = realizado.fold<double>(0, (a, b) => a + b);
        periodoMeses = meses.isEmpty ? 6 : meses.length;
        mediaMensal = periodoMeses == 0 ? 0 : totalVendas / periodoMeses;
        melhorMesValor = realizado.isEmpty ? 0 : realizado.reduce((a, b) => a > b ? a : b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false, 
            backgroundColor: Colors.white, 
            elevation: 0, 
            toolbarHeight: 0,
            collapsedHeight: 0,
            expandedHeight: 0,
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7F9FB), Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: _HeaderRow(
                title: 'Dashboard de Vendas',
                showConsultor: false,
                consultorText: '',
                primary: primary,
                primaryLight: primaryLight,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardsGrid(
                    children: [
                      _BigKpiCard(
                        title: 'Total Vendas',
                        value: moeda(totalVendas),
                        icon: Icons.attach_money_rounded,
                        gradient: LinearGradient(colors: [primary, primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      _KpiCard(title: 'Média Mensal', value: moeda(mediaMensal), icon: Icons.track_changes_rounded),
                      _KpiCard(title: 'Melhor Mês', value: moeda(melhorMesValor), icon: Icons.emoji_events_outlined),
                      _KpiCard(title: 'Período', value: '$periodoMeses meses', icon: Icons.event_note_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: 'Evolução de Vendas',
                    subtitle: 'Somente vendas finalizadas entram nos totais - Dados Gerais',
                    child: _BarrasVendasChart(meses: meses, realizado: realizado, primary: primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String title;
  final bool showConsultor;
  final String consultorText;
  final Color primary;
  final Color primaryLight;

  const _HeaderRow({
    required this.title,
    required this.primary,
    required this.primaryLight,
    this.showConsultor = false,
    this.consultorText = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [primary, primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF222222), letterSpacing: .1),
              ),
              if (showConsultor) ...[
                const SizedBox(height: 2),
                Text(
                  consultorText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CardsGrid extends StatelessWidget {
  final List<Widget> children;
  const _CardsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 1000;
    final cross = isWide ? 4 : 2;
    final childAspect = isWide ? 1.55 : 1.15;

    return GridView.builder(
      itemCount: children.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspect,
      ),
      itemBuilder: (context, i) => children[i],
    );
  }
}

const double _cardH = 136;
const double _r = 14;
const double _iconTop = 10;
const double _iconLeft = 12;
const double _titleTop = 48;
const double _side = 16;
const double _valueBottom = 16;

class _KpiLayoutFixed extends StatelessWidget {
  final Widget icon;
  final String title;
  final String value;
  final Color titleColor;
  final Color valueColor;

  const _KpiLayoutFixed({
    required this.icon,
    required this.title,
    required this.value,
    required this.titleColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Stack(
      children: [
        Positioned(top: _iconTop, left: _iconLeft, child: SizedBox(height: 24, width: 24, child: FittedBox(child: icon))),
        Positioned(top: _titleTop, left: _side, right: _side, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.labelLarge?.copyWith(color: titleColor, fontWeight: FontWeight.w600))),
        Positioned(left: _side, right: _side, bottom: _valueBottom, child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium?.copyWith(color: valueColor, fontWeight: FontWeight.w800))),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _KpiCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(_r),
      child: Container(
        height: _cardH,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(_r)),
        child: _KpiLayoutFixed(
          icon: Icon(icon, color: const Color(0xFFDD3A3A), size: 26),
          title: title,
          value: value,
          titleColor: Colors.black54,
          valueColor: const Color(0xFF222222),
        ),
      ),
    );
  }
}

class _BigKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  const _BigKpiCard({required this.title, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(_r),
      child: Container(
        height: _cardH,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(_r)),
        child: _KpiLayoutFixed(
          icon: Icon(icon, color: Colors.white, size: 26),
          title: title,
          value: value,
          titleColor: Colors.white70,
          valueColor: Colors.white,
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.trending_up, color: Color(0xFFDD3A3A)),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(height: 260, child: child),
          ],
        ),
      ),
    );
  }
}

class _BarrasVendasChart extends StatelessWidget {
  final List<String> meses;
  final List<double> realizado;
  final Color primary;
  const _BarrasVendasChart({required this.meses, required this.realizado, required this.primary});

  @override
  Widget build(BuildContext context) {
    final barGroups = List.generate(meses.length, (i) {
      return BarChartGroupData(
        x: i,
        barsSpace: 10,
        barRods: [
          BarChartRodData(
            toY: (realizado[i] / 1000).clamp(0, double.infinity),
            width: 20,
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: [primary, primary.withOpacity(.85)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
          ),
        ],
      );
    });

    final maxY = [
      ...realizado.map((e) => e / 1000),
      10,
    ].reduce((a, b) => a > b ? a : b) * 1.1;

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(enabled: false),
        
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('R\$ ${value.toInt()}k', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= meses.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(meses[i], style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black87)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: barGroups,
      ),
      
      swapAnimationDuration: Duration.zero,
      swapAnimationCurve: Curves.linear,
    );
  }
}