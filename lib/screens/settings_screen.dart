import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../widgets/admob_banner_widget.dart';
import '../services/session_service.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Function(ThemeMode) toggleTheme;
  final Function() logout;

  SettingsScreen({required this.themeMode, required this.toggleTheme, required this.logout});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SessionService _sessionService;
  String _sharedUrl = '';
  String? _profileImageUrl;
  bool _notificationsEnabled = false;
  int _notificationMinutesBefore = 30;

  @override
  void initState() {
    super.initState();
    _generateSharedUrl();
    _loadProfileImage();
    if (!kIsWeb) {
      _loadNotificationSettings();
    }
  }

  void _generateSharedUrl() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _sharedUrl = 'https://ngftrpgcalendar.xyz/shared/${user.uid}';
      });
    }
  }

  void _loadProfileImage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.photoURL != null) {
      setState(() {
        _profileImageUrl = user.photoURL;
      });
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      _notificationMinutesBefore = prefs.getInt('notificationMinutesBefore') ?? 30;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setInt('notificationMinutesBefore', _notificationMinutesBefore);

    final notificationService = Provider.of<NotificationService>(context, listen: false);
    if (_notificationsEnabled) {
      // Fetch all sessions and update notifications
      final sessions = await _sessionService.fetchAllSessions();
      await notificationService.updateSessionNotifications(sessions);
    } else {
      await notificationService.cancelAllNotifications();
    }
  }

  Widget _buildProfileImage(User user) {
    print('프로필 이미지 빌드 시작: ${user.photoURL}');
    return CircleAvatar(
      backgroundImage: user.photoURL != null
          ? NetworkImage(user.photoURL!)
          : null,
      onBackgroundImageError: (exception, stackTrace) {
        print('프로필 이미지 로드 실패: $exception');
        print('스택 트레이스: $stackTrace');
      },
      child: FutureBuilder(
        future: _checkImageLoading(user.photoURL),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('이미지 로딩 중...');
            return CircularProgressIndicator();
          } else if (snapshot.hasError || snapshot.data == false) {
            print('이미지 로드 실패 또는 URL 없음. 대체 텍스트 표시');
            return Text(
              user.displayName?.isNotEmpty == true
                  ? user.displayName![0].toUpperCase()
                  : '?',
              style: TextStyle(color: Colors.white),
            );
          } else {
            print('이미지 로드 성공');
            return Container();
          }
        },
      ),
      radius: 16,
    );
  }

  Future<bool> _checkImageLoading(String? url) async {
    if (url == null) return false;
    try {
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      print('이미지 확인 중 오류 발생: $e');
      return false;
    }
  }

  void _handleLogout() async {
    await widget.logout();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  void _handleThemeChange(ThemeMode? newThemeMode) {
    if (newThemeMode != null) {
      setState(() {
        widget.toggleTheme(newThemeMode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('설정')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            Card(
              child: ListTile(
                leading: _buildProfileImage(user),
                title: Text(user.displayName ?? '이름 없음'),
                subtitle: Text(user.email ?? ''),
              ),
            ),
            SizedBox(height: 16),
          ],
          if (!kIsWeb) AdMobBannerWidget(hasEnoughContent: true),
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.palette),
              title: Text('테마 모드'),
              trailing: DropdownButton<ThemeMode>(
                value: widget.themeMode,
                items: ThemeMode.values.map((ThemeMode mode) {
                  return DropdownMenuItem<ThemeMode>(
                    value: mode,
                    child: Text(mode == ThemeMode.system ? '시스템' :
                    mode == ThemeMode.light ? '라이트' : '다크'),
                  );
                }).toList(),
                onChanged: _handleThemeChange,
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.share),
              title: Text('캘린더 공유 URL'),
              subtitle: Text(_sharedUrl),
              trailing: IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _sharedUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('URL이 클립보드에 복사되었습니다.')),
                  );
                },
              ),
            ),
          ),
          if (!kIsWeb) ...[
            SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('알람 기능'),
                    subtitle: Text(_notificationsEnabled ? '알람이 활성화되었습니다.' : '알람이 비활성화되었습니다.'),
                    value: _notificationsEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      _saveNotificationSettings();
                    },
                  ),
                  if (_notificationsEnabled)
                    ListTile(
                      title: Text('알람 시간 설정'),
                      subtitle: Text('세션 시작 $_notificationMinutesBefore분 전에 알림'),
                      trailing: DropdownButton<int>(
                        value: _notificationMinutesBefore,
                        items: [5, 10, 15, 30, 60, 120].map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value분 전'),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _notificationMinutesBefore = newValue;
                            });
                            _saveNotificationSettings();
                          }
                        },
                      ),
                    ),
                  // Insert the new ListTile here
                  ListTile(
                    title: Text('배터리 최적화 비활성화'),
                    subtitle: Text('정확한 알림을 위해 배터리 최적화를 비활성화합니다.'),
                    trailing: FutureBuilder<bool>(
                      future: Provider.of<NotificationService>(context, listen: false).isBatteryOptimizationDisabled(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }
                        return Switch(
                          value: snapshot.data ?? false,
                          onChanged: (bool value) async {
                            if (value) {
                              await Provider.of<NotificationService>(context, listen: false).requestDisableBatteryOptimization();
                            } else {
                              // 사용자에게 시스템 설정으로 이동하라는 메시지 표시
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('시스템 설정에서 배터리 최적화를 다시 활성화할 수 있습니다.')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(Icons.notifications_off),
                title: Text('알람 기능'),
                subtitle: Text('웹 버전에서는 알람 기능을 제공하지 않습니다.'),
              ),
            ),
          ],
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('로그아웃'),
              onTap: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }
}
