import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../widgets/admob_banner_widget.dart';

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
  String _sharedUrl = '';
  String? _profileImageUrl;
  bool _notificationsEnabled = false;

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
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    final enabled = await notificationService.getNotificationsEnabled();
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _saveNotificationSettings(bool value) async {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    await notificationService.setNotificationsEnabled(value);
    setState(() {
      _notificationsEnabled = value;
    });
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
                      _saveNotificationSettings(value);
                    },
                  ),
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