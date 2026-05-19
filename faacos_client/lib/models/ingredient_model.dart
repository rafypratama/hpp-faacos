class IngredientModel {
  final int id;
  final String code;
  final String name;
  final String type; // raw_material, packaging
  final double currentStock;
  final String unit;
  final double pricePerUnit;
  final DateTime? expiredAt;

  IngredientModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.currentStock,
    required this.unit,
    required this.pricePerUnit,
    this.expiredAt,
  });

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    return IngredientModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      type: json['type'],
      currentStock: double.parse(json['current_stock'].toString()),
      unit: json['unit'],
      pricePerUnit: double.parse(json['price_per_unit'].toString()),
      expiredAt: json['expired_at'] != null ? DateTime.parse(json['expired_at']) : null,
    );
  }
}
