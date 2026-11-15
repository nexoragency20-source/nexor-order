import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dashboard_catalog.dart';
import 'dashboard_models.dart';

class DashboardHomePage extends StatefulWidget {
  final String storeName;
  final VoidCallback onViewAllOrders;

  const DashboardHomePage({
    super.key,
    required this.storeName,
    required this.onViewAllOrders,
  });

  @override
  State<DashboardHomePage> createState() => _DashboardHomePageState();
}

class _DashboardHomePageState extends State<DashboardHomePage> {
  final DashboardCatalog _catalog = DashboardCatalog.instance;

  @override
  void initState() {
    super.initState();
    _catalog.load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _catalog,
      builder: (context, _) {
        final overview = _catalog.overview;
        return RefreshIndicator(
          onRefresh: () => _catalog.load(force: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DashboardWelcome(
                  storeName: widget.storeName,
                  isLoading: _catalog.isLoading,
                  onRefresh: () => _catalog.load(force: true),
                ),
                const SizedBox(height: 22),
                if (overview == null && _catalog.isLoading)
                  const SizedBox(
                    height: 360,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (overview == null)
                  _DashboardLoadError(
                    message: _catalog.errorMessage ?? 'لا توجد بيانات لعرضها.',
                    onRetry: () => _catalog.load(force: true),
                  )
                else ...[
                  if (_catalog.errorMessage != null) ...[
                    _DashboardInfoBanner(message: _catalog.errorMessage!),
                    const SizedBox(height: 14),
                  ],
                  _DashboardStatsGrid(summary: overview.summary),
                  const SizedBox(height: 18),
                  _DashboardInventoryStrip(summary: overview.summary),
                  const SizedBox(height: 22),
                  _DashboardMainGrid(overview: overview),
                  const SizedBox(height: 22),
                  _DashboardRecentOrders(
                    orders: overview.recentOrders,
                    onViewAll: widget.onViewAllOrders,
                  ),
                ],
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'الأرقام المعروضة مستخرجة مباشرة من بيانات هذا المتجر.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .45),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardWelcome extends StatelessWidget {
  final String storeName;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _DashboardWelcome({
    required this.storeName,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('yyyy/MM/dd').format(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF25213F), Color(0xFF171923)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B84FF).withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: .10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B84FF).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.query_stats_rounded, color: Color(0xFFAAA5FF), size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملخص أداء ${storeName.isEmpty ? 'متجرك' : storeName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'بيانات فعلية من قاعدة البيانات • $today',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: .68)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'تحديث البيانات',
            onPressed: isLoading ? null : onRefresh,
            icon: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF8B84FF).withValues(alpha: .16),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  final DashboardSummary summary;
  const _DashboardStatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData('طلبات اليوم', _count(summary.ordersTodayCount), 'طلبات غير ملغاة', Icons.shopping_bag_rounded, const Color(0xFF8B84FF)),
      _StatData('صافي مبيعات اليوم', '${_money(summary.netSalesTodaySyp)} ل.س', 'بعد خصم المرتجعات المستلمة', Icons.trending_up_rounded, const Color(0xFF20B990)),
      _StatData('العملاء النشطون', _count(summary.activeCustomersCount), 'عملاء مسجلون في المتجر', Icons.people_alt_rounded, const Color(0xFF4EA4F5)),
      _StatData('مرتجعات مستلمة اليوم', _count(summary.receivedReturnsTodayCount), '${_money(summary.returnedTodaySyp)} ل.س قيمة المرتجع', Icons.assignment_return_rounded, const Color(0xFFE59A56)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 4 ? 1.9 : columns == 2 ? 2.3 : 3.1,
          children: items.map((item) => _DashboardStatCard(item: item)).toList(),
        );
      },
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  const _StatData(this.title, this.value, this.caption, this.icon, this.color);
}

class _DashboardStatCard extends StatelessWidget {
  final _StatData item;
  const _DashboardStatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .58), fontSize: 11)),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 3),
                  Text(item.caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .42), fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardInventoryStrip extends StatelessWidget {
  final DashboardSummary summary;
  const _DashboardInventoryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .35)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final children = [
            _InventoryMetric(icon: Icons.inventory_2_outlined, title: 'المنتجات النشطة', value: _count(summary.activeProductsCount)),
            _InventoryMetric(icon: Icons.warning_amber_rounded, title: 'أصناف وصلت حد التنبيه', value: _count(summary.lowStockProductsCount), warning: summary.lowStockProductsCount > 0),
            _InventoryMetric(icon: Icons.receipt_long_outlined, title: 'إجمالي الطلبات', value: _count(summary.totalOrdersCount)),
          ];
          if (compact) {
            return Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                children[i],
              ],
            ]);
          }
          return Row(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 28),
              Expanded(child: children[i]),
            ],
          ]);
        },
      ),
    );
  }
}

class _InventoryMetric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool warning;
  const _InventoryMetric({required this.icon, required this.title, required this.value, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final color = warning ? const Color(0xFFE59A56) : const Color(0xFF8B84FF);
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 9),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: warning ? color : null)),
    ]);
  }
}

class _DashboardMainGrid extends StatelessWidget {
  final DashboardOverview overview;
  const _DashboardMainGrid({required this.overview});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = _SalesChartCard(points: overview.salesTrend);
        final statuses = _OrderStatusCard(statuses: overview.orderStatuses);
        if (constraints.maxWidth < 950) {
          return Column(children: [chart, const SizedBox(height: 16), statuses]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: chart),
          const SizedBox(width: 16),
          Expanded(child: statuses),
        ]);
      },
    );
  }
}

class _SalesChartCard extends StatelessWidget {
  final List<DashboardTrendPoint> points;
  const _SalesChartCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = points.map((point) => point.netSalesSyp).toList(growable: false);
    final hasSales = values.any((value) => value.abs() > .000001);
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 340,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('صافي المبيعات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('آخر 7 أيام • بعد احتساب المرتجعات المستلمة', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: .55))),
            const SizedBox(height: 15),
            if (!hasSales) Expanded(child: Center(child: Text('لا توجد مبيعات أو مرتجعات خلال هذه الفترة', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .48), fontSize: 12))))
            else Expanded(child: CustomPaint(
              painter: _SalesChartPainter(values: values),
              child: const SizedBox.expand(),
            )),
            const SizedBox(height: 11),
            Row(children: [
              for (var i = 0; i < points.length; i++)
                Expanded(child: Text(DateFormat('MM/dd').format(points[i].day), textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withValues(alpha: .48)))),
            ]),
            const SizedBox(height: 8),
            Text('إجمالي الفترة: ${_money(values.fold<double>(0, (sum, value) => sum + value))} ل.س',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF8B84FF))),
          ]),
        ),
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  final List<double> values;
  _SalesChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
    final minValue = values.fold<double>(0.0, (current, value) => value < current ? value : current);
    final maxValue = values.fold<double>(1.0, (current, value) => value > current ? value : current);
    final range = (maxValue - minValue).abs() < .000001 ? 1.0 : maxValue - minValue;
    const horizontalPadding = 8.0;
    const verticalPadding = 10.0;
    final chartWidth = (size.width - horizontalPadding * 2).clamp(0.0, double.infinity).toDouble();
    final chartHeight = (size.height - verticalPadding * 2).clamp(0.0, double.infinity).toDouble();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1 ? size.width / 2 : horizontalPadding + chartWidth * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final dy = verticalPadding + chartHeight * (1 - normalized);
      points.add(Offset(dx, dy));
    }
    final zeroY = verticalPadding + chartHeight * (1 - (0 - minValue) / range);
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(points[i].dx, points[i].dy);
    }
    final fill = Path()
      ..moveTo(points.first.dx, zeroY)
      ..lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      fill.lineTo(points[i].dx, points[i].dy);
    }
    fill..lineTo(points.last.dx, zeroY)..close();
    final fillPaint = Paint()..color = const Color(0xFF6C63FF).withValues(alpha: .10)..style = PaintingStyle.fill;
    final linePaint = Paint()..color = const Color(0xFF786BFA)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(line, linePaint);
    final dotPaint = Paint()..color = const Color(0xFF8B84FF);
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
    final zeroPaint = Paint()..color = Colors.grey.withValues(alpha: .22)..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _OrderStatusCard extends StatelessWidget {
  final List<DashboardOrderStatus> statuses;
  const _OrderStatusCard({required this.statuses});

  @override
  Widget build(BuildContext context) {
    const ordered = ['PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'COMPLETED', 'CANCELLED'];
    final sorted = [...statuses]..sort((a, b) => ordered.indexOf(a.status).compareTo(ordered.indexOf(b.status)));
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 340,
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('حالة الطلبات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text('توزيع كل الطلبات المسجلة', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 17),
            Expanded(
              child: sorted.isEmpty
                  ? const Center(child: Text('لا توجد طلبات مسجلة بعد', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView.separated(
                      physics: const ClampingScrollPhysics(),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _StatusProgressRow(item: sorted[index]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatusProgressRow extends StatelessWidget {
  final DashboardOrderStatus item;
  const _StatusProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(_statusLabel(item.status), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        Text('${_count(item.count)} • ${item.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: (item.percentage / 100).clamp(0.0, 1.0).toDouble(),
          minHeight: 7,
          backgroundColor: Colors.grey.withValues(alpha: .12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

class _DashboardRecentOrders extends StatelessWidget {
  final List<DashboardRecentOrder> orders;
  final VoidCallback onViewAll;
  const _DashboardRecentOrders({required this.orders, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(21),
        child: Column(children: [
          Row(children: [
            const Expanded(child: Text('آخر الطلبات الفعلية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            TextButton(onPressed: onViewAll, child: const Text('عرض كل الطلبات')),
          ]),
          const SizedBox(height: 10),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('لا توجد طلبات حتى الآن.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...orders.map((order) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: .035),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                SizedBox(width: 115, child: Text('#${order.orderNumber}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                Expanded(child: Text(order.customerName.isEmpty ? 'عميل غير محدد' : order.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: Text('${_money(order.totalSyp)} ل.س', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                const SizedBox(width: 10),
                _OrderStatusBadge(status: order.status),
                const SizedBox(width: 12),
                Text(DateFormat('MM/dd').format(order.createdAt.toLocal()), style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: .48), fontSize: 10)),
              ]),
            )),
        ]),
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final String status;
  const _OrderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _DashboardLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _DashboardLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 36),
        const SizedBox(height: 12),
        const Text('تعذر تحميل بيانات لوحة التحكم', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
      ]),
    ),
  );
}

class _DashboardInfoBanner extends StatelessWidget {
  final String message;
  const _DashboardInfoBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
    child: Text('تعذر تحديث البيانات؛ المعروض هو آخر ملخص تم تحميله. $message', style: const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
  );
}

String _money(double value) => NumberFormat('#,##0.##').format(value);
String _count(int value) => NumberFormat('#,##0').format(value);

String _statusLabel(String status) {
  switch (status) {
    case 'PENDING': return 'جديد';
    case 'CONFIRMED': return 'مؤكد';
    case 'PROCESSING': return 'قيد التنفيذ';
    case 'SHIPPED': return 'تم الشحن';
    case 'COMPLETED': return 'مكتمل';
    case 'CANCELLED': return 'ملغى';
    default: return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'PENDING': return const Color(0xFF8B84FF);
    case 'CONFIRMED': return const Color(0xFF4EA4F5);
    case 'PROCESSING': return const Color(0xFFE59A56);
    case 'SHIPPED': return const Color(0xFF20A8B8);
    case 'COMPLETED': return const Color(0xFF20B990);
    case 'CANCELLED': return const Color(0xFFE36E77);
    default: return Colors.grey;
  }
}
