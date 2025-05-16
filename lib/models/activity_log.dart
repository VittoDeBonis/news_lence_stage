import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final String userId;
  final String activityType;
  final String description;
  final String newsTitle;
  final DateTime timestamp;
  
  ActivityLog({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.description,
    required this.newsTitle,
    required this.timestamp,
  });
  
  // Metodo di fabbrica per creare ActivityLog dal documento Firestore
  factory ActivityLog.fromFirestore(Map<String, dynamic> data, String docId) {
    return ActivityLog(
      id: docId,
      userId: data['userId'] ?? '',
      activityType: data['activityType'] ?? 'unknown',
      description: data['description'] ?? '',
      newsTitle: data['newsTitle'] ?? '',
      // Gestire sia gli oggetti Timestamp che DateTime
      timestamp: data['timestamp'] is Timestamp 
        ? (data['timestamp'] as Timestamp).toDate()
        : (data['timestamp'] ?? DateTime.now()),
    );
  }
  
  // Convertire in mappa per la memorizzazione in Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'activityType': activityType,
      'description': description,
      'newsTitle': newsTitle,
      'timestamp': timestamp,
    };
  }
}