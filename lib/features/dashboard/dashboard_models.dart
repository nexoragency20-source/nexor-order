class DashboardSummary {
  final int ordersTodayCount;
  final double grossSalesTodaySyp;
  final double returnedTodaySyp;
  final double netSalesTodaySyp;
  final int receivedReturnsTodayCount;
  final int pendingReturnsCount;
  final int activeCustomersCount;
  final int activeProductsCount;
  final int lowStockProductsCount;
  final int totalOrdersCount;

  const DashboardSummary({
    required this.ordersTodayCount,
    required this.grossSalesTodaySyp,
    required this.returnedTodaySyp,
    required this.netSalesTodaySyp,
    required this.receivedReturnsTodayCount,
    required this.pendingReturnsCount,
    required this.activeCustomersCount,
    required this.activeProductsCount,
    required this.lowStockProductsCount,
    required this.totalOrdersCount,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        ordersTodayCount: _intValue(json['ordersTodayCount']),
        grossSalesTodaySyp: _doubleValue(json['grossSalesTodaySyp']),
        returnedTodaySyp: _doubleValue(json['returnedTodaySyp']),
        netSalesTodaySyp: _doubleValue(json['netSalesTodaySyp']),
        receivedReturnsTodayCount: _intValue(json['receivedReturnsTodayCount']),
        pendingReturnsCount: _intValue(json['pendingReturnsCount']),
        activeCustomersCount: _intValue(json['activeCustomersCount']),
        activeProductsCount: _intValue(json['activeProductsCount']),
        lowStockProductsCount: _intValue(json['lowStockProductsCount']),
        totalOrdersCount: _intValue(json['totalOrdersCount']),
      );
}

class DashboardTrendPoint {
  final String date;
  final double grossSalesSyp;
  final double returnedSyp;
  final double netSalesSyp;
  final int ordersCount;

  const DashboardTrendPoint({
    required this.date,
    required this.grossSalesSyp,
    required this.returnedSyp,
    required this.netSalesSyp,
    required this.ordersCount,
  });

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) => DashboardTrendPoint(
        date: '${json['date'] ?? ''}',
        grossSalesSyp: _doubleValue(json['grossSalesSyp']),
        returnedSyp: _doubleValue(json['returnedSyp']),
        netSalesSyp: _doubleValue(json['netSalesSyp']),
        ordersCount: _intValue(json['ordersCount']),
      );

  DateTime get day => DateTime.tryParse(date) ?? DateTime.now();
}

class DashboardOrderStatus {
  final String status;
  final int count;
  final double percentage;

  const DashboardOrderStatus({
    required this.status,
    required this.count,
    required this.percentage,
  });

  factory DashboardOrderStatus.fromJson(Map<String, dynamic> json) => DashboardOrderStatus(
        status: '${json['status'] ?? ''}',
        count: _intValue(json['count']),
        percentage: _doubleValue(json['percentage']),
      );
}

class DashboardRecentOrder {
  final String orderNumber;
  final String customerName;
  final String status;
  final double totalSyp;
  final DateTime createdAt;

  const DashboardRecentOrder({
    required this.orderNumber,
    required this.customerName,
    required this.status,
    required this.totalSyp,
    required this.createdAt,
  });

  factory DashboardRecentOrder.fromJson(Map<String, dynamic> json) => DashboardRecentOrder(
        orderNumber: '${json['orderNumber'] ?? ''}',
        customerName: '${json['customerName'] ?? 'عميل'}',
        status: '${json['status'] ?? ''}',
        totalSyp: _doubleValue(json['totalSyp']),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      );
}

class DashboardOverview {
  final String date;
  final DashboardSummary summary;
  final List<DashboardTrendPoint> salesTrend;
  final List<DashboardOrderStatus> orderStatuses;
  final List<DashboardRecentOrder> recentOrders;

  const DashboardOverview({
    required this.date,
    required this.summary,
    required this.salesTrend,
    required this.orderStatuses,
    required this.recentOrders,
  });

  factory DashboardOverview.fromJson(Map<String, dynamic> json) {
    final rawSummary = _mapValue(json['summary']);
    final rawTrend = json['salesTrend'];
    final rawStatuses = json['orderStatuses'];
    final rawOrders = json['recentOrders'];
    return DashboardOverview(
      date: '${json['date'] ?? ''}',
      summary: DashboardSummary.fromJson(rawSummary),
      salesTrend: rawTrend is List
          ? rawTrend.whereType<Map>().map((item) => DashboardTrendPoint.fromJson(_mapValue(item))).toList(growable: false)
          : const [],
      orderStatuses: rawStatuses is List
          ? rawStatuses.whereType<Map>().map((item) => DashboardOrderStatus.fromJson(_mapValue(item))).toList(growable: false)
          : const [],
      recentOrders: rawOrders is List
          ? rawOrders.whereType<Map>().map((item) => DashboardRecentOrder.fromJson(_mapValue(item))).toList(growable: false)
          : const [],
    );
  }
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return <String, dynamic>{};
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _intValue(dynamic value) => _doubleValue(value).round();
