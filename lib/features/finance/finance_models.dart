class FinanceMovement {
  final String id;
  final String type;
  final String currency;
  final double amount;
  final double amountUsdEquivalent;
  final double amountSypEquivalent;
  final double exchangeRateSypPerUsd;
  final String category;
  final String description;
  final String note;
  final String referenceType;
  final String referenceId;
  final String transferGroupId;
  final DateTime occurredAt;
  final bool isAutomatic;
  final bool canEdit;

  const FinanceMovement({
    required this.id,
    required this.type,
    required this.currency,
    required this.amount,
    required this.amountUsdEquivalent,
    required this.amountSypEquivalent,
    required this.exchangeRateSypPerUsd,
    required this.category,
    required this.description,
    required this.note,
    required this.referenceType,
    required this.referenceId,
    required this.transferGroupId,
    required this.occurredAt,
    required this.isAutomatic,
    required this.canEdit,
  });

  factory FinanceMovement.fromJson(Map<String, dynamic> json) {
    return FinanceMovement(
      id: '${json['id'] ?? ''}',
      type: '${json['type'] ?? 'INCOME'}',
      currency: '${json['currency'] ?? 'SYP'}',
      amount: _number(json['amount']),
      amountUsdEquivalent: _number(json['amountUsdEquivalent']),
      amountSypEquivalent: _number(json['amountSypEquivalent']),
      exchangeRateSypPerUsd: _number(json['exchangeRateSypPerUsd']),
      category: '${json['category'] ?? ''}',
      description: '${json['description'] ?? ''}',
      note: '${json['note'] ?? ''}',
      referenceType: '${json['referenceType'] ?? ''}',
      referenceId: '${json['referenceId'] ?? ''}',
      transferGroupId: '${json['transferGroupId'] ?? ''}',
      occurredAt: DateTime.tryParse('${json['occurredAt'] ?? ''}') ?? DateTime.now(),
      isAutomatic: json['isAutomatic'] == true,
      canEdit: json['canEdit'] == true,
    );
  }

  bool get isIncoming =>
      const {'INCOME', 'DEPOSIT', 'OPENING_BALANCE', 'TRANSFER_IN'}.contains(type);
  bool get isTransfer => type == 'TRANSFER_IN' || type == 'TRANSFER_OUT';
}

class FinanceSummary {
  final double cashBalanceUsd;
  final double cashBalanceSyp;
  final double cashBalanceUsdEquivalent;
  final double cashBalanceSypEquivalent;
  final double todayReceiptsUsdEquivalent;
  final double todayPaymentsUsdEquivalent;
  final double todayReceiptsSypEquivalent;
  final double todayPaymentsSypEquivalent;
  final double todayTransfersUsdEquivalent;
  final double todayNetUsdEquivalent;
  final int todayTransactionCount;

  const FinanceSummary({
    required this.cashBalanceUsd,
    required this.cashBalanceSyp,
    required this.cashBalanceUsdEquivalent,
    required this.cashBalanceSypEquivalent,
    required this.todayReceiptsUsdEquivalent,
    required this.todayPaymentsUsdEquivalent,
    required this.todayReceiptsSypEquivalent,
    required this.todayPaymentsSypEquivalent,
    required this.todayTransfersUsdEquivalent,
    required this.todayNetUsdEquivalent,
    required this.todayTransactionCount,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    return FinanceSummary(
      cashBalanceUsd: _number(json['cashBalanceUsd']),
      cashBalanceSyp: _number(json['cashBalanceSyp']),
      cashBalanceUsdEquivalent: _number(json['cashBalanceUsdEquivalent']),
      cashBalanceSypEquivalent: _number(json['cashBalanceSypEquivalent']),
      todayReceiptsUsdEquivalent: _number(json['todayReceiptsUsdEquivalent']),
      todayPaymentsUsdEquivalent: _number(json['todayPaymentsUsdEquivalent']),
      todayReceiptsSypEquivalent: _number(json['todayReceiptsSypEquivalent']),
      todayPaymentsSypEquivalent: _number(json['todayPaymentsSypEquivalent']),
      todayTransfersUsdEquivalent: _number(json['todayTransfersUsdEquivalent']),
      todayNetUsdEquivalent: _number(json['todayNetUsdEquivalent']),
      todayTransactionCount: _number(json['todayTransactionCount']).round(),
    );
  }
}

class FinanceSnapshot {
  final String date;
  final double exchangeRateSypPerUsd;
  final FinanceSummary summary;
  final List<FinanceMovement> items;

  const FinanceSnapshot({
    required this.date,
    required this.exchangeRateSypPerUsd,
    required this.summary,
    required this.items,
  });

  factory FinanceSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSummary = _map(json['summary']);
    final rawItems = json['items'];
    return FinanceSnapshot(
      date: '${json['date'] ?? ''}',
      exchangeRateSypPerUsd: _number(json['exchangeRateSypPerUsd']),
      summary: FinanceSummary.fromJson(rawSummary),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => FinanceMovement.fromJson(_map(item)))
              .toList(growable: false)
          : const [],
    );
  }
}

class FinanceTransactionDraft {
  final String type;
  final String currency;
  final double amount;
  final String category;
  final String description;
  final String note;
  final DateTime occurredAt;

  const FinanceTransactionDraft({
    required this.type,
    required this.currency,
    required this.amount,
    required this.category,
    required this.description,
    required this.note,
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'currency': currency,
        'amount': amount,
        'category': category,
        'description': description,
        'note': note,
        'occurredAt': occurredAt.toIso8601String(),
      };
}

class FinanceTransferDraft {
  final String fromCurrency;
  final String toCurrency;
  final double fromAmount;
  final double toAmount;
  final String description;
  final String note;
  final DateTime occurredAt;

  const FinanceTransferDraft({
    required this.fromCurrency,
    required this.toCurrency,
    required this.fromAmount,
    required this.toAmount,
    required this.description,
    required this.note,
    required this.occurredAt,
  });

  Map<String, dynamic> toJson() => {
        'fromCurrency': fromCurrency,
        'toCurrency': toCurrency,
        'fromAmount': fromAmount,
        'toAmount': toAmount,
        'description': description,
        'note': note,
        'occurredAt': occurredAt.toIso8601String(),
      };
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry('$key', item));
  return <String, dynamic>{};
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
