import 'package:flutter/material.dart';

class NotificationModel {
  final int? id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String type;
  final Map<String, dynamic> data;
  
  NotificationModel({
    this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.type,
    this.data = const {},
  });
  
  // Create a copy with updated fields
  NotificationModel copyWith({
    int? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? type,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      data: data ?? this.data,
    );
  }
  
  // Create from JSON
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
      type: json['type'] ?? 'unknown',
      data: json['data'] ?? {},
    );
  }
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'type': type,
      'data': data,
    };
  }
}