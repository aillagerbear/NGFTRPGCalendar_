import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import 'dart:developer' as developer;

class SessionService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<List<Session>> fetchAllSessions() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final snapshot = await _firestore
        .collection('sessions')
        .where('createdBy', isEqualTo: user.uid)
        .get();

    return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
  }

  Future<void> addSession(Session session) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 세션 추가
      DocumentReference sessionRef =
          await _firestore.collection('sessions').add(session.toFirestore());

      // 현재 사용자의 UID 가져오기
      String userId = _auth.currentUser!.uid;

      // 공유 링크 정보 업데이트
      await _firestore.collection('shared_links').doc(userId).set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      developer.log('Session added successfully: ${sessionRef.id}',
          name: 'SessionService');
    } catch (e) {
      developer.log('Error adding session: $e',
          name: 'SessionService', error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<Session>> getUserSessionsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('sessions')
          .where('createdBy', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
        developer.log(
            'Received snapshot with ${snapshot.docs.length} documents',
            name: 'SessionService');
        return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
      }).handleError((error) {
        developer.log('Error in session stream: $error',
            name: 'SessionService', error: error);
        return <Session>[];
      });
    } else {
      developer.log('No user logged in, returning empty stream',
          name: 'SessionService');
      return Stream.value([]);
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      developer.log('Fetching user info for userId: $userId',
          name: 'SessionService');

      // Firestore에서 사용자 정보를 확인
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      developer.log('User document exists: ${userDoc.exists}',
          name: 'SessionService');
      if (userDoc.exists) {
        return {
          'displayName': userDoc.data()?['displayName'] ?? '알 수 없는 사용자',
          'photoURL': userDoc.data()?['photoURL'],
          'uid': userId,
        };
      }

      // Firestore에 정보가 없으면, 공유 링크 정보를 확인
      final sharedLinkDoc = await FirebaseFirestore.instance
          .collection('shared_links')
          .doc(userId)
          .get();
      developer.log('Shared link document exists: ${sharedLinkDoc.exists}',
          name: 'SessionService');
      if (sharedLinkDoc.exists) {
        return {
          'displayName': sharedLinkDoc.data()?['ownerName'] ?? '알 수 없는 사용자',
          'photoURL': sharedLinkDoc.data()?['ownerPhotoURL'],
          'uid': userId,
        };
      }

      // 둘 다 없으면 기본값 반환
      developer.log('User info not found, returning default values',
          name: 'SessionService');
      return {
        'displayName': '알 수 없는 사용자',
        'photoURL': null,
        'uid': userId,
      };
    } catch (e) {
      developer.log('Error getting user info: $e',
          name: 'SessionService', error: e);
      return {
        'displayName': '오류 발생',
        'photoURL': null,
        'uid': userId,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestore.collection('sessions').doc(sessionId).delete();
      developer.log('Session deleted successfully: $sessionId',
          name: 'SessionService');
    } catch (e) {
      developer.log('Error deleting session: $e',
          name: 'SessionService', error: e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Session>> getFutureSessions(String userId) async {
    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('createdBy', isEqualTo: userId)
        .where('startTime', isGreaterThan: now)
        .get();

    return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
  }

  Stream<List<Session>> getSharedUserSessionsStream(String userId) {
    developer.log('Setting up shared user sessions stream for userId: $userId',
        name: 'SessionService');
    return _firestore
        .collection('sessions')
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Session.fromFirestore(doc)).toList();
    });
  }
}
