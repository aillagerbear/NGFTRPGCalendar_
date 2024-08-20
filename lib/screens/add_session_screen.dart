import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_time_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'loading_screen.dart';
import 'package:provider/provider.dart';

class AddSessionScreen extends StatefulWidget {
  final DateTime selectedDate;

  AddSessionScreen({required this.selectedDate});

  @override
  _AddSessionScreenState createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _platformController = TextEditingController();
  final _gamemasterController = TextEditingController();
  final _playersController = TextEditingController();
  final _customGameRuleController = TextEditingController();

  late DateTime _startTime;
  late DateTime _endTime;
  int _estimatedPlayTime = 3;

  final SessionService _sessionService = SessionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedGameRule = 'D&D 5e';
  final List<String> _gameRules = ['D&D 5e', 'Pathfinder', 'Call of Cthulhu', '기타'];
  bool _isCustomGameRule = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      19,
      0,
    );
    _updateEndTime();
    _loadDefaultGameRule();
    _logCurrentTimeZone();
    developer.log('InitState: Selected Date: ${widget.selectedDate}, Start Time: $_startTime', name: 'AddSessionScreen');
  }

  void _logCurrentTimeZone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final offsetHours = offset.inHours;
    final offsetMinutes = offset.inMinutes.remainder(60).abs();
    developer.log('Current Time Zone: UTC${offset.isNegative ? '-' : '+'}$offsetHours:${offsetMinutes.toString().padLeft(2, '0')}', name: 'AddSessionScreen');
    developer.log('개발 완료후 삭제', name: 'AddSessionScreen');
  }

  Future<void> _loadDefaultGameRule() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedGameRule = prefs.getString('defaultGameRule') ?? 'D&D 5e';
        _isCustomGameRule = !_gameRules.contains(_selectedGameRule);
        if (_isCustomGameRule) {
          _customGameRuleController.text = _selectedGameRule;
        }
      });
    } catch (e) {
      developer.log('Error loading default game rule: $e', name: 'AddSessionScreen');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateEndTime() {
    _endTime = _startTime.add(Duration(hours: _estimatedPlayTime));
    developer.log('Updated End Time: $_endTime', name: 'AddSessionScreen');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('새 세션 추가')),
      body: _isLoading
          ? LoadingScreen()
          : LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600 && kIsWeb) {
            // 웹에서 넓은 화면용 레이아웃
            return Center(
              child: Container(
                width: 600,
                child: _buildForm(),
              ),
            );
          } else {
            // 모바일 또는 좁은 화면용 레이아웃
            return _buildForm();
          }
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(labelText: '세션 제목'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '세션 제목을 입력해주세요';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          _buildDateTimePicker('시작 시간', _startTime, (newDateTime) {
            setState(() {
              _startTime = newDateTime;
              _updateEndTime();
            });
          }),
          SizedBox(height: 16),
          _buildDateTimePicker('종료 시간', _endTime, (newDateTime) {
            setState(() {
              _endTime = newDateTime;
              _updateEstimatedPlayTime();
            });
          }),
          SizedBox(height: 16),
          ListTile(
            title: Text('예상 플레이 시간'),
            subtitle: Text('$_estimatedPlayTime 시간'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    setState(() {
                      if (_estimatedPlayTime > 1) {
                        _estimatedPlayTime--;
                        _updateEndTime();
                      }
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _estimatedPlayTime++;
                      _updateEndTime();
                    });
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _isCustomGameRule ? '기타' : _selectedGameRule,
            items: _gameRules.map((String rule) {
              return DropdownMenuItem<String>(
                value: rule,
                child: Text(rule),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                if (newValue == '기타') {
                  _isCustomGameRule = true;
                } else {
                  _isCustomGameRule = false;
                  _selectedGameRule = newValue!;
                }
              });
            },
            decoration: InputDecoration(labelText: '게임 룰'),
          ),
          if (_isCustomGameRule)
            TextFormField(
              controller: _customGameRuleController,
              decoration: InputDecoration(labelText: '사용자 정의 게임 룰'),
              validator: (value) {
                if (_isCustomGameRule && (value == null || value.isEmpty)) {
                  return '사용자 정의 게임 룰을 입력해주세요';
                }
                return null;
              },
            ),
          SizedBox(height: 16),
          TextFormField(
            controller: _scenarioController,
            decoration: InputDecoration(labelText: '시나리오'),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _platformController,
            decoration: InputDecoration(labelText: '플랫폼/장소'),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _gamemasterController,
            decoration: InputDecoration(labelText: '게임마스터'),
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _playersController,
            decoration: InputDecoration(labelText: '플레이어 (쉼표로 구분)'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            child: Text('세션 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime dateTime, Function(DateTime) onChanged) {
    return ListTile(
      title: Text(label),
      subtitle: Text('${DateTimeUtils.formatDateTime(dateTime)}'),
      trailing: Icon(Icons.calendar_today),
      onTap: () => _selectDateTime(dateTime, onChanged),
    );
  }

  Future<void> _selectDateTime(DateTime initialDateTime, Function(DateTime) onChanged) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDateTime),
      );
      if (pickedTime != null) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        onChanged(newDateTime);
        developer.log('DateTime selected: $newDateTime', name: 'AddSessionScreen');
      }
    }
  }

  void _updateEstimatedPlayTime() {
    setState(() {
      _estimatedPlayTime = _endTime.difference(_startTime).inHours;
    });
    developer.log('Updated Estimated Play Time: $_estimatedPlayTime', name: 'AddSessionScreen');
  }

  void _submitForm() async {
    developer.log('Submitting form', name: 'AddSessionScreen');
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = _auth.currentUser;
      if (user != null) {
        final gameRule = _isCustomGameRule ? _customGameRuleController.text : _selectedGameRule;
        final session = Session(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          startTime: _startTime,
          endTime: _endTime,
          estimatedPlayTime: _estimatedPlayTime,
          gameRule: gameRule,
          scenario: _scenarioController.text,
          platform: _platformController.text,
          sessionGoal: '',
          gamemaster: _gamemasterController.text,
          players: _playersController.text.split(',').map((e) => e.trim()).toList(),
          createdBy: user.uid,
          createdAt: DateTime.now(),
          oneHourNotificationSent: false,
          oneDayNotificationSent: false,
        );

        developer.log('Session object created: ${session.toString()}', name: 'AddSessionScreen');

        try {
          await _sessionService.addSession(session);
          developer.log('Session submitted successfully: ${session.title}', name: 'AddSessionScreen');

          // 사용된 게임 룰을 기본값으로 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('defaultGameRule', gameRule);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('세션이 성공적으로 추가되었습니다.')),
          );
          Navigator.pop(context, true);
        } catch (e) {
          developer.log('Error submitting session: $e', name: 'AddSessionScreen', error: e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('세션 추가 중 오류가 발생했습니다: $e')),
          );
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else {
        developer.log('User not logged in, cannot add session', name: 'AddSessionScreen');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('세션을 추가하려면 로그인이 필요합니다.')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}