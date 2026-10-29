import 'dart:convert';
import 'api_service.dart';

class SendItemModel {
  final int id;
  final String senderId;
  final String? recipientId;
  final int pickupLocationId;
  final int dropoffLocationId;
  final String itemDescription;
  final String status;
  final String createdAt;
  final String? deliveredAt;

  SendItemModel({
    required this.id,
    required this.senderId,
    this.recipientId,
    required this.pickupLocationId,
    required this.dropoffLocationId,
    required this.itemDescription,
    required this.status,
    required this.createdAt,
    this.deliveredAt,
  });

  factory SendItemModel.fromJson(Map<String, dynamic> json) {
    return SendItemModel(
      id: json['id'],
      senderId: json['sender_id'],
      recipientId: json['recipient_id'],
      pickupLocationId: json['pickup_location_id'],
      dropoffLocationId: json['dropoff_location_id'],
      itemDescription: json['item_description'],
      status: json['status'],
      createdAt: json['created_at'],
      deliveredAt: json['delivered_at'],
    );
  }
}

class SendItemService {
  static Future<SendItemModel> create({
    required int pickupLocationId,
    required int dropoffLocationId,
    required String itemDescription,
    String? recipientId,
  }) async {
    final res = await ApiService.post("/send-items", {
      "pickup_location_id": pickupLocationId,
      "dropoff_location_id": dropoffLocationId,
      "item_description": itemDescription,
      if (recipientId != null && recipientId.isNotEmpty) "recipient_id": recipientId,
    }, auth: true);

    if (res.statusCode == 200) {
      return SendItemModel.fromJson(jsonDecode(res.body));
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to send item");
    }
  }

  static Future<List<SendItemModel>> getMine() async {
    final res = await ApiService.get("/send-items/mine", auth: true);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => SendItemModel.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load items");
    }
  }

  static Future<void> cancel(int itemId) async {
    final res = await ApiService.put("/send-items/$itemId/cancel", {}, auth: true);
    if (res.statusCode != 200) {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to cancel");
    }
  }

  static Future<Map<String, dynamic>> getLiveStatus(int itemId) async {
    final res = await ApiService.get("/send-items/$itemId/live", auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load item status");
    }
  }
}