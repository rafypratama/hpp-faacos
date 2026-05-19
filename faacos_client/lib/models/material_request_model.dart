import 'user_model.dart';
import 'ingredient_model.dart';
import 'production_order_model.dart';

class MaterialRequestItemModel {
  final int id;
  final int ingredientId;
  final IngredientModel? ingredient;
  final double quantityRequired;
  final String unit;
  final double quantityApproved;

  MaterialRequestItemModel({
    required this.id,
    required this.ingredientId,
    this.ingredient,
    required this.quantityRequired,
    required this.unit,
    required this.quantityApproved,
  });

  factory MaterialRequestItemModel.fromJson(Map<String, dynamic> json) {
    return MaterialRequestItemModel(
      id: json['id'],
      ingredientId: json['ingredient_id'],
      ingredient: json['ingredient'] != null ? IngredientModel.fromJson(json['ingredient']) : null,
      quantityRequired: double.parse(json['quantity_required'].toString()),
      unit: json['unit'],
      quantityApproved: double.parse(json['quantity_approved'].toString()),
    );
  }
}

class MaterialRequestModel {
  final int id;
  final String code;
  final int productionOrderId;
  final ProductionOrderModel? productionOrder;
  final String status;
  final String? rejectionReason;
  final UserModel? creator;
  final UserModel? verifier;
  final List<MaterialRequestItemModel> items;
  final DateTime createdAt;

  MaterialRequestModel({
    required this.id,
    required this.code,
    required this.productionOrderId,
    this.productionOrder,
    required this.status,
    this.rejectionReason,
    this.creator,
    this.verifier,
    required this.items,
    required this.createdAt,
  });

  factory MaterialRequestModel.fromJson(Map<String, dynamic> json) {
    return MaterialRequestModel(
      id: json['id'],
      code: json['code'],
      productionOrderId: json['production_order_id'],
      productionOrder: json['production_order'] != null ? ProductionOrderModel.fromJson(json['production_order']) : null,
      status: json['status'],
      rejectionReason: json['rejection_reason'],
      creator: json['creator'] != null ? UserModel.fromJson(json['creator']) : null,
      verifier: json['verifier'] != null ? UserModel.fromJson(json['verifier']) : null,
      items: (json['items'] as List? ?? [])
          .map((i) => MaterialRequestItemModel.fromJson(i))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
