import 'dart:convert';

import 'location_point.dart';

class PendingLocation {
  PendingLocation({
    required this.firebaseUid,
    required this.point,
    this.batteryLevel,
    this.activityType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String firebaseUid;
  final LocationPoint point;
  final int? batteryLevel;
  final String? activityType;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'firebaseUid': firebaseUid,
        'point': point.toJson(),
        if (batteryLevel != null) 'batteryLevel': batteryLevel,
        if (activityType != null) 'activityType': activityType,
        'createdAt': createdAt.toIso8601String(),
      };

  static PendingLocation fromJson(Map<String, dynamic> json) {
    return PendingLocation(
      firebaseUid: json['firebaseUid'] as String,
      point: LocationPoint.fromJson(
        Map<String, dynamic>.from(json['point'] as Map),
      ),
      batteryLevel: json['batteryLevel'] as int?,
      activityType: json['activityType'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static List<PendingLocation> decodeList(String? value) {
    if (value == null || value.isEmpty) return [];
    final list = jsonDecode(value) as List<dynamic>;
    return list
        .map((item) =>
            PendingLocation.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static String encodeList(List<PendingLocation> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}
