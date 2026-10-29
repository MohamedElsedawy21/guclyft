import 'dart:convert';
import 'api_service.dart';

class MedicalRequestModel {
  final int id;
  final String requestType;
  final String status;
  final int? priorityDays;
  final String? priorityUntil;
  final String createdAt;

  MedicalRequestModel({
    required this.id,
    required this.requestType,
    required this.status,
    this.priorityDays,
    this.priorityUntil,
    required this.createdAt,
  });

  factory MedicalRequestModel.fromJson(Map<String, dynamic> json) {
    return MedicalRequestModel(
      id: json['id'],
      requestType: json['request_type'],
      status: json['status'],
      priorityDays: json['priority_days'],
      priorityUntil: json['priority_until'],
      createdAt: json['created_at'],
    );
  }
}

class MedicalService {
  static Future<void> submitRequest({
    required String requestType,
    required String filePath,
  }) async {
    final res = await ApiService.postMultipart(
      "/medical-requests",
      fields: {"request_type": requestType},
      filePath: filePath,
      fileFieldName: "file",
    );
    if (res.statusCode != 200) {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to submit request");
    }
  }

  static Future<List<MedicalRequestModel>> getMyRequests() async {
    final res = await ApiService.get("/medical-requests/me", auth: true);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MedicalRequestModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load requests");
    }
  }
}