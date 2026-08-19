import 'dart:convert';
import 'api_service.dart';


class GucianAdminView {
  final String id;
  final String firstname;
  final String lastname;
  final String email;
  final String? faculty;
  final bool isinjured;
  final String username;
  final String createdat;

  GucianAdminView({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    this.faculty,
    required this.isinjured,
    required this.username,
    required this.createdat,
  });

  factory GucianAdminView.fromJson(Map<String, dynamic> json) {
    return GucianAdminView(
      id: json['id'],
      firstname: json['firstname'],
      lastname: json['lastname'],
      email: json['email'],
      faculty: json['faculty'],
      isinjured: json['isinjured'] ?? false,
      username: json['username'],
      createdat: json['createdat'],
    );
  }
}

class AdminService {
  
    static Future<String> getDocumentUrl(int requestId) async {
    final token = await ApiService.getToken();
    return "${ApiService.baseUrl}/admin/medical-requests/$requestId/document?token=$token";
  }

  static Future<List<GucianAdminView>> getAllGucians() async {
    final res = await ApiService.get("/admin/gucians", auth: true);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => GucianAdminView.fromJson(e)).toList();
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to load gucians");
    }
  }

    static Future<List<MedicalRequestAdminModel>> getAllMedicalRequests({String? status}) async {
    final path = status != null ? "/admin/medical-requests?status=$status" : "/admin/medical-requests";
    final res = await ApiService.get(path, auth: true);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MedicalRequestAdminModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load medical requests");
    }
  }

  static Future<void> reviewMedicalRequest({
    required int requestId,
    required String status,
    int? priorityDays,
  }) async {
    final res = await ApiService.put("/admin/medical-requests/$requestId/review", {
      "status": status,
      if (priorityDays != null) "priority_days": priorityDays,
    }, auth: true);

    if (res.statusCode != 200) {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to review request");
    }
  }
}

class MedicalRequestAdminModel {
  final int id;
  final String gucianId;
  final String gucianName;
  final String requestType;
  final String documentPath;
  final String status;
  final int? priorityDays;
  final String? priorityUntil;
  final String createdAt;

  MedicalRequestAdminModel({
    required this.id,
    required this.gucianId,
    required this.gucianName,
    required this.requestType,
    required this.documentPath,
    required this.status,
    this.priorityDays,
    this.priorityUntil,
    required this.createdAt,
  });

  factory MedicalRequestAdminModel.fromJson(Map<String, dynamic> json) {
    return MedicalRequestAdminModel(
      id: json['id'],
      gucianId: json['gucian_id'],
      gucianName: json['gucian_name'],
      requestType: json['request_type'],
      documentPath: json['document_path'],
      status: json['status'],
      priorityDays: json['priority_days'],
      priorityUntil: json['priority_until'],
      createdAt: json['created_at'],
    );
  }
}