import 'user_model.dart';
import 'formula_model.dart';
import 'material_request_model.dart';

class ProductionOrderModel {
  final int id;
  final String code;
  final int formulaId;
  final FormulaModel? formula;
  final double targetQuantity;
  final int batchCount;
  final String status;
  final DateTime? scheduledStartDate;
  final DateTime? scheduledEndDate;
  final UserModel? creator;
  final MaterialRequestModel? materialRequest;

  ProductionOrderModel({
    required this.id,
    required this.code,
    required this.formulaId,
    this.formula,
    required this.targetQuantity,
    required this.batchCount,
    required this.status,
    this.scheduledStartDate,
    this.scheduledEndDate,
    this.creator,
    this.materialRequest,
  });

  factory ProductionOrderModel.fromJson(Map<String, dynamic> json) {
    return ProductionOrderModel(
      id: json['id'],
      code: json['code'],
      formulaId: json['formula_id'],
      formula: json['formula'] != null ? FormulaModel.fromJson(json['formula']) : null,
      targetQuantity: double.parse(json['target_quantity'].toString()),
      batchCount: json['batch_count'],
      status: json['status'],
      scheduledStartDate: json['scheduled_start_date'] != null ? DateTime.parse(json['scheduled_start_date']) : null,
      scheduledEndDate: json['scheduled_end_date'] != null ? DateTime.parse(json['scheduled_end_date']) : null,
      creator: json['creator'] != null ? UserModel.fromJson(json['creator']) : null,
      materialRequest: json['material_request'] != null ? MaterialRequestModel.fromJson(json['material_request']) : null,
    );
  }
}
