import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../utils/date_time_utils.dart';
import 'add_session_screen.dart';
import '../widgets/session_card.dart';
import '../widgets/admob_banner_widget.dart';
import 'loading_screen.dart';
import 'profile_edit_dialog.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Session>> _sessions = {};
  final SessionService _sessionService = SessionService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<List<Session>>? _sessionsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _setupSessionListener();
      if (!kIsWeb) {
        await _notificationService.initialize();
      }
    } catch (e) {
      developer.log('Error initializing CalendarScreen: $e', name: 'CalendarScreen', error: e);
      // 사용자에게 오류 메시지를 표시하는 로직 추가
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setupSessionListener() async {
    _sessionsSubscription?.cancel();
    _sessionsSubscription = _sessionService.getUserSessionsStream().listen((sessions) {
      if (mounted) {
        setState(() {
          _sessions = _groupSessionsByDate(sessions);
          _isLoading = false; // 데이터를 받았으므로 로딩 상태 해제
        });
      }
    });
    // 첫 번째 이벤트를 기다림
    await _sessionsSubscription?.asFuture();
  }

  Map<DateTime, List<Session>> _groupSessionsByDate(List<Session> sessions) {
    final sessionMap = <DateTime, List<Session>>{};
    for (var session in sessions) {
      final date = DateTimeUtils.dateOnly(session.startTime);
      if (!sessionMap.containsKey(date)) {
        sessionMap[date] = [];
      }
      sessionMap[date]!.add(session);
    }
    return sessionMap;
  }

  List<Session> _getSessionsForDay(DateTime day) {
    return _sessions[DateTimeUtils.dateOnly(day)] ?? [];
  }

  Widget _buildProfileSection(User user) {
    return GestureDetector(
      onTap: () => _showProfileEditDialog(context, user),
      child: Row(
        children: [
          FutureBuilder(
            future: _checkImageUrl(user.photoURL),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data == true) {
                  return CircleAvatar(
                    backgroundImage: NetworkImage(user.photoURL!),
                    onBackgroundImageError: (exception, stackTrace) {
                      developer.log(
                        '프로필 이미지 로드 실패',
                        error: exception,
                        stackTrace: stackTrace,
                      );
                    },
                    radius: 16,
                  );
                } else {
                  return CircleAvatar(
                    child: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName![0].toUpperCase()
                          : '?',
                      style: TextStyle(color: Colors.white),
                    ),
                    radius: 16,
                  );
                }
              } else {
                return CircularProgressIndicator();
              }
            },
          ),
          SizedBox(width: 8),
          Text(user.displayName ?? ''),
        ],
      ),
    );
  }

  Future<bool> _checkImageUrl(String? url) async {
    if (url == null) return false;
    try {
      final response = await http.get(Uri.parse(url));
      developer.log('Image URL response status: ${response.statusCode}');
      developer.log('Image URL response headers: ${response.headers}');
      return response.statusCode == 200;
    } catch (e) {
      developer.log('Error checking image URL: $e');
      return false;
    }
  }

  void _showProfileEditDialog(BuildContext context, User user) {
    developer.log('프로필 수정 다이얼로그 열기 시도', name: 'CalendarScreen');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ProfileEditDialog(user: user);
      },
    ).then((_) {
      developer.log('프로필 수정 다이얼로그 닫힘', name: 'CalendarScreen');
      setState(() {});
    });
  }

  void _showAddSessionModal(BuildContext context) async {
    final selectedDate = _selectedDay ?? _focusedDay;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSessionScreen(selectedDate: selectedDate),
      ),
    );
    if (result == true) {
      setState(() => _isLoading = true);
      await _setupSessionListener();

      if (!kIsWeb) {
        // 새로 추가된 세션에 대한 알림 스케줄링 (앱에서만)
        final newSessions = _getSessionsForDay(selectedDate);
        for (var session in newSessions) {
          await _notificationService.scheduleSessionNotification(session); // 여기를 수정했습니다
        }
      }

      setState(() => _isLoading = false);
    }
  }

  void _deleteSession(Session session) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('세션 삭제'),
          content: Text('정말로 이 세션을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('삭제'),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                try {
                  await _sessionService.deleteSession(session.id);
                  await _setupSessionListener();
                  if (!kIsWeb) {
                    await _notificationService.cancelNotification(session.id.hashCode);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('세션이 삭제되었습니다.')),
                  );
                } catch (e) {
                  developer.log('Error deleting session: $e', name: 'CalendarScreen');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('세션 삭제 중 오류가 발생했습니다.')),
                  );
                } finally {
                  setState(() => _isLoading = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('TRPG 세션 플래너')),
        body: Center(
          child: Text('로그인이 필요합니다.'),
        ),
      );
    }

    if (_isLoading) {
      return LoadingScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('TRPG 세션 플래너'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _buildProfileSection(user),
          ),
        ],
      ),
      body: Column(
        children: [
          AdMobBannerWidget(hasEnoughContent: _sessions.isNotEmpty),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getSessionsForDay,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _getSessionsForDay(_selectedDay ?? _focusedDay).length,
              itemBuilder: (context, index) {
                if (index > 0 && index % 5 == 0) {
                  return Column(
                    children: [
                      AdMobBannerWidget(hasEnoughContent: true),
                      SessionCard(
                        session: _getSessionsForDay(_selectedDay ?? _focusedDay)[index],
                        onDelete: () => _deleteSession(_getSessionsForDay(_selectedDay ?? _focusedDay)[index]),
                      ),
                    ],
                  );
                }
                return SessionCard(
                  session: _getSessionsForDay(_selectedDay ?? _focusedDay)[index],
                  onDelete: () => _deleteSession(_getSessionsForDay(_selectedDay ?? _focusedDay)[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSessionModal(context),
        child: Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    super.dispose();
  }
}