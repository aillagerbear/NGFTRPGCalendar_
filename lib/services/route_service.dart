import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RouteService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> determineInitialRoute() async {
    if (kIsWeb) {
      final uri = Uri.parse(Uri.base.toString());
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'shared') {
        return '/shared/${uri.pathSegments.last}';
      }
    }

    // Check if the user is logged in and not anonymous
    User? user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      return '/';
    } else {
      return '/login';
    }
  }
}