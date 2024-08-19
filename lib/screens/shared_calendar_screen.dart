import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/auth_service.dart';
import '../utils/date_time_utils.dart';
import '../widgets/session_card.dart';
import '../widgets/admob_banner_widget.dart';
import 'loading_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class SharedCalendarScreen extends StatefulWidget {
  final String userId;
  final Function(ThemeMode) toggleTheme;
  final ThemeMode themeMode;

  SharedCalendarScreen({
    required this.userId,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  _SharedCalendarScreenState createState() => _SharedCalendarScreenState();
}

class _SharedCalendarScreenState extends State<SharedCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Session>> _sessions = {};
  final SessionService _sessionService = SessionService();
  String _ownerName = '';
  String? _ownerPhotoUrl;
  String _ownerUid = '';
  bool _isLoading = true;
  String? _errorMessage;
  int _signInAttempts = 0;
  final int _maxSignInAttempts = 3;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    print('SharedCalendarScreen initState called for user: ${widget.userId}');
    _loadData();
  }

  Future<void> _loadData() async {
    print('_loadData called');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _signInAnonymously();
      await _fetchUserInfo();
      await _setupSharedUserSessionsStream();
    } catch (e) {
      print('Error in _loadData: $e');
      setState(() {
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    if (_isSigningIn) {
      print('Sign in already in progress, skipping');
      return;
    }
    _isSigningIn = true;

    print('Attempting anonymous sign in. Attempt: ${_signInAttempts + 1}');

    if (_signInAttempts >= _maxSignInAttempts) {
      print('Max sign in attempts reached');
      throw Exception('로그인 시도 횟수를 초과했습니다.');
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInAnonymously();
      print('Anonymous sign in successful');
      _signInAttempts = 0;
    } catch (e) {
      print('Failed to sign in anonymously: $e');
      _signInAttempts++;
      if (_signInAttempts < _maxSignInAttempts) {
        print('Retrying sign in after delay');
        await Future.delayed(Duration(seconds: 2));
        _isSigningIn = false;
        await _signInAnonymously();
      } else {
        throw Exception('익명 로그인 중 오류가 발생했습니다.');
      }
    } finally {
      _isSigningIn = false;
    }
  }

  Future<void> _fetchUserInfo() async {
    print('Fetching user info for user: ${widget.userId}');
    final userInfo = await _sessionService.getUserInfo(widget.userId);
    print('Fetched user info: $userInfo');

    setState(() {
      _ownerName = userInfo['displayName'] ?? '알 수 없는 사용자';
      _ownerPhotoUrl = userInfo['photoURL'];
      _ownerUid = userInfo['uid'] ?? '';
    });
  }

  Future<void> _setupSharedUserSessionsStream() async {
    print('Setting up shared user sessions stream for user: ${widget.userId}');
    _sessionService.getSharedUserSessionsStream(widget.userId).listen((sessions) {
      if (mounted) {
        setState(() {
          _sessions = _groupSessionsByDate(sessions);
        });
        print('Data loaded and state updated');
      } else {
        print('Widget no longer mounted, state update skipped');
      }
    });
  }

  Map<DateTime, List<Session>> _groupSessionsByDate(List<Session> sessions) {
    print('Grouping ${sessions.length} sessions by date');
    final sessionMap = <DateTime, List<Session>>{};
    for (var session in sessions) {
      final date = DateTimeUtils.dateOnly(session.startTime);
      if (!sessionMap.containsKey(date)) {
        sessionMap[date] = [];
      }
      sessionMap[date]!.add(session);
    }
    print('Grouped sessions into ${sessionMap.length} dates');
    return sessionMap;
  }

  List<Session> _getSessionsForDay(DateTime day) {
    final sessions = _sessions[DateTimeUtils.dateOnly(day)] ?? [];
    print('Getting sessions for day ${day.toString()}: ${sessions.length} sessions');
    return sessions;
  }

  void _launchURL() async {
    const url = 'https://ngftrpgcalendar.xyz';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building SharedCalendarScreen. isLoading: $_isLoading, errorMessage: $_errorMessage');
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_ownerPhotoUrl != null)
                    CircleAvatar(
                      backgroundImage: NetworkImage(_ownerPhotoUrl!),
                      radius: 15,
                    ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _ownerName == '오류 발생' || _ownerName == '알 수 없는 사용자'
                          ? '공유 캘린더'
                          : '$_ownerName님의 공유 캘린더',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_ownerUid.isNotEmpty)
                Text(
                  '@${_ownerUid.substring(0, 8)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () {
              print('Toggling theme');
              widget.toggleTheme(Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark);
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      print('Showing loading indicator');
      return LoadingScreen();
    }

    if (_errorMessage != null) {
      print('Showing error message: $_errorMessage');
      return Center(child: Text(_errorMessage!));
    }

    print('Building main calendar view');
    return Column(
      children: [
        if (!kIsWeb) AdMobBannerWidget(hasEnoughContent: _sessions.isNotEmpty),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _launchURL,
            icon: Icon(Icons.calendar_today),
            label: Text('나도 사용하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ),
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
            print('Day selected: $selectedDay');
          },
          eventLoader: _getSessionsForDay,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _getSessionsForDay(_selectedDay ?? _focusedDay).length,
            itemBuilder: (context, index) {
              final session = _getSessionsForDay(_selectedDay ?? _focusedDay)[index];
              return SessionCard(
                session: session,
                isSharedCalendar: true,
              );
            },
          ),
        ),
      ],
    );
  }
}