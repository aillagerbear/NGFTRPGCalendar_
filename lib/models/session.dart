import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final int estimatedPlayTime;
  final String gameRule;
  final String scenario;
  final String platform;
  final String sessionGoal;
  final String gamemaster;
  final List<String> players;
  final String createdBy;
  final DateTime createdAt;
  final bool oneHourNotificationSent;
  final bool oneDayNotificationSent;

  Session({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.estimatedPlayTime,
    required this.gameRule,
    required this.scenario,
    required this.platform,
    required this.sessionGoal,
    required this.gamemaster,
    required this.players,
    required this.createdBy,
    required this.createdAt,
    this.oneHourNotificationSent = false,
    this.oneDayNotificationSent = false,
  });

  factory Session.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      title: data['title'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      estimatedPlayTime: data['estimatedPlayTime'] ?? 0,
      gameRule: data['gameRule'] ?? '',
      scenario: data['scenario'] ?? '',
      platform: data['platform'] ?? '',
      sessionGoal: data['sessionGoal'] ?? '',
      gamemaster: data['gamemaster'] ?? '',
      players: List<String>.from(data['players'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      oneHourNotificationSent: data['oneHourNotificationSent'] ?? false,
      oneDayNotificationSent: data['oneDayNotificationSent'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'estimatedPlayTime': estimatedPlayTime,
      'gameRule': gameRule,
      'scenario': scenario,
      'platform': platform,
      'sessionGoal': sessionGoal,
      'gamemaster': gamemaster,
      'players': players,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'oneHourNotificationSent': oneHourNotificationSent,
      'oneDayNotificationSent': oneDayNotificationSent,
    };
  }
}