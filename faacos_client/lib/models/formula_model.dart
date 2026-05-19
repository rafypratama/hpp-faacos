import 'user_model.dart';
import 'ingredient_model.dart';

class FormulaIngredientModel {
  final int id;
  final int ingredientId;
  final IngredientModel? ingredient;
  final double quantityPerBatch;
  final String unit;
  final double unitPrice;
  final double subtotal;

  FormulaIngredientModel({
    required this.id,
    required this.ingredientId,
    this.ingredient,
    required this.quantityPerBatch,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
  });

  factory FormulaIngredientModel.fromJson(Map<String, dynamic> json) {
    return FormulaIngredientModel(
      id: json['id'],
      ingredientId: json['ingredient_id'],
      ingredient: json['ingredient'] != null ? IngredientModel.fromJson(json['ingredient']) : null,
      quantityPerBatch: double.parse(json['quantity_per_batch'].toString()),
      unit: json['unit'],
      unitPrice: double.parse(json['unit_price'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
    );
  }
}

class FormulaCostModel {
  final int id;
  final String type;
  final String description;
  final double costValue;

  FormulaCostModel({
    required this.id,
    required this.type,
    required this.description,
    required this.costValue,
  });

  factory FormulaCostModel.fromJson(Map<String, dynamic> json) {
    return FormulaCostModel(
      id: json['id'],
      type: json['type'],
      description: json['description'],
      costValue: double.parse(json['cost_value'].toString()),
    );
  }
}

class HppCalculationModel {
  final int id;
  final double totalIngredientCost;
  final double totalLaborCost;
  final double totalOverheadCost;
  final double totalOtherCost;
  final double totalHpp;
  final double hppPerUnit;
  final double profitMarginPercent;
  final double sellingPrice;

  HppCalculationModel({
    required this.id,
    required this.totalIngredientCost,
    required this.totalLaborCost,
    required this.totalOverheadCost,
    required this.totalOtherCost,
    required this.totalHpp,
    required this.hppPerUnit,
    required this.profitMarginPercent,
    required this.sellingPrice,
  });

  factory HppCalculationModel.fromJson(Map<String, dynamic> json) {
    return HppCalculationModel(
      id: json['id'],
      totalIngredientCost: double.parse(json['total_ingredient_cost'].toString()),
      totalLaborCost: double.parse(json['total_labor_cost'].toString()),
      totalOverheadCost: double.parse(json['total_overhead_cost'].toString()),
      totalOtherCost: double.parse(json['total_other_cost'].toString()),
      totalHpp: double.parse(json['total_hpp'].toString()),
      hppPerUnit: double.parse(json['hpp_per_unit'].toString()),
      profitMarginPercent: double.parse(json['profit_margin_percent'].toString()),
      sellingPrice: double.parse(json['selling_price'].toString()),
    );
  }
}

class FormulaModel {
  final int id;
  final String code;
  final String name;
  final double batchSize;
  final String status;
  final UserModel? creator;
  final UserModel? approver;
  final List<FormulaIngredientModel> ingredients;
  final List<FormulaCostModel> costs;
  final HppCalculationModel? hpp;
  final DateTime createdAt;

  FormulaModel({
    required this.id,
    required this.code,
    required this.name,
    required this.batchSize,
    required this.status,
    this.creator,
    this.approver,
    required this.ingredients,
    required this.costs,
    this.hpp,
    required this.createdAt,
  });

  factory FormulaModel.fromJson(Map<String, dynamic> json) {
    return FormulaModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      batchSize: double.parse(json['batch_size'].toString()),
      status: json['status'],
      creator: json['creator'] != null ? UserModel.fromJson(json['creator']) : null,
      approver: json['approver'] != null ? UserModel.fromJson(json['approver']) : null,
      ingredients: (json['ingredients'] as List? ?? [])
          .map((i) => FormulaIngredientModel.fromJson(i))
          .toList(),
      costs: (json['costs'] as List? ?? [])
          .map((c) => FormulaCostModel.fromJson(c))
          .toList(),
      hpp: json['hpp'] != null ? HppCalculationModel.fromJson(json['hpp']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
