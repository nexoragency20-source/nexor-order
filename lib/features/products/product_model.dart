class ProductModel {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final double purchasePriceUsd;
  final double purchasePriceSyp;
  final double sellingPriceUsd;
  final double sellingPriceSyp;
  final double exchangeRateSypPerUsd;
  final int stockQuantity;
  final int minimumStock;
  final String description;
  final bool isActive;
  final DateTime createdAt;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.purchasePriceUsd,
    required this.purchasePriceSyp,
    required this.sellingPriceUsd,
    required this.sellingPriceSyp,
    required this.exchangeRateSypPerUsd,
    required this.stockQuantity,
    required this.minimumStock,
    this.description = '',
    this.isActive = true,
    required this.createdAt,
  });

  double get purchasePrice => purchasePriceSyp;
  double get sellingPrice => sellingPriceSyp;
  double get profitPerUnitUsd => sellingPriceUsd - purchasePriceUsd;
  double get profitPerUnitSyp => sellingPriceSyp - purchasePriceSyp;
  double get stockCostValue => purchasePriceSyp * stockQuantity;
  double get stockCostValueUsd => purchasePriceUsd * stockQuantity;
  double get stockSellingValue => sellingPriceSyp * stockQuantity;
  double get stockSellingValueUsd => sellingPriceUsd * stockQuantity;
  bool get isOutOfStock => stockQuantity <= 0;
  bool get isLowStock => stockQuantity > 0 && stockQuantity <= minimumStock;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    double number(String key) => _asDouble(json[key]);
    int integer(String key) => _asDouble(json[key]).round();

    return ProductModel(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      barcode: '${json['barcode'] ?? ''}',
      category: '${json['category'] ?? ''}',
      purchasePriceUsd: number('purchasePriceUsd'),
      purchasePriceSyp: number('purchasePriceSyp'),
      sellingPriceUsd: number('sellingPriceUsd'),
      sellingPriceSyp: number('sellingPriceSyp'),
      exchangeRateSypPerUsd: number('exchangeRateSypPerUsd'),
      stockQuantity: integer('stockQuantity'),
      minimumStock: integer('minimumStock'),
      description: '${json['description'] ?? ''}',
      isActive: json['isActive'] == true,
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toApiJson() => {
    'name': name,
    'barcode': barcode,
    'category': category,
    'purchasePriceUsd': purchasePriceUsd,
    'sellingPriceUsd': sellingPriceUsd,
    'stockQuantity': stockQuantity,
    'minimumStock': minimumStock,
    'description': description,
    'isActive': isActive,
  };

  ProductModel copyWith({
    String? id,
    String? name,
    String? barcode,
    String? category,
    double? purchasePriceUsd,
    double? purchasePriceSyp,
    double? sellingPriceUsd,
    double? sellingPriceSyp,
    double? exchangeRateSypPerUsd,
    int? stockQuantity,
    int? minimumStock,
    String? description,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      purchasePriceUsd: purchasePriceUsd ?? this.purchasePriceUsd,
      purchasePriceSyp: purchasePriceSyp ?? this.purchasePriceSyp,
      sellingPriceUsd: sellingPriceUsd ?? this.sellingPriceUsd,
      sellingPriceSyp: sellingPriceSyp ?? this.sellingPriceSyp,
      exchangeRateSypPerUsd:
          exchangeRateSypPerUsd ?? this.exchangeRateSypPerUsd,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
