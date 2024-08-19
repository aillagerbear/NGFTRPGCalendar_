import 'package:flutter/material.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSessionScreen extends StatefulWidget {
  @override
  _AddSessionScreenState createState() => _AddSessionScreenState();
}

class _AddSessionScreenState extends State<AddSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _platformController = TextEditingController();
  final _sessionGoalController = TextEditingController();
  final _gamemasterController = TextEditingController();
  final _playersController = TextEditingController();
  final _gameRuleController = TextEditingController();

  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(Duration(hours: 3));
  int _estimatedPlayTime = 3;

  final SessionService _sessionService = SessionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('새 세션 추가')),
      body: Form(
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
            ListTile(
              title: Text('시작 시간'),
              subtitle: Text('${_startTime.toString().substring(0, 16)}'),
              trailing: Icon(Icons.access_time),
              onTap: () => _selectDateTime(isStartTime: true),
            ),
            ListTile(
              title: Text('종료 시간'),
              subtitle: Text('${_endTime.toString().substring(0, 16)}'),
              trailing: Icon(Icons.access_time),
              onTap: () => _selectDateTime(isStartTime: false),
            ),
            ListTile(
              title: Text('예상 플레이 시간'),
              subtitle: Text('$_estimatedPlayTime 시간'),
            ),
            TextFormField(
              controller: _gameRuleController,
              decoration: InputDecoration(labelText: '게임 룰'),
            ),
            TextFormField(
              controller: _scenarioController,
              decoration: InputDecoration(labelText: '시나리오'),
            ),
            TextFormField(
              controller: _platformController,
              decoration: InputDecoration(labelText: '플랫폼/장소'),
            ),
            TextFormField(
              controller: _sessionGoalController,
              decoration: InputDecoration(labelText: '세션 목표'),
            ),
            TextFormField(
              controller: _gamemasterController,
              decoration: InputDecoration(labelText: '게임마스터'),
            ),
            TextFormField(
              controller: _playersController,
              decoration: InputDecoration(labelText: '플레이어 (쉼표로 구분)'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitForm,
              child: Text('세션 추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime({required bool isStartTime}) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
      );
      if (pickedTime != null) {
        setState(() {
          if (isStartTime) {
            _startTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          } else {
            _endTime = DateTime(
              pickedDate.year,
              pickedDate.month,
              pickedDate.day,
              pickedTime.hour,
              pickedTime.minute,
            );
          }
          _updateEstimatedPlayTime();
        });
      }
    }
  }

  void _updateEstimatedPlayTime() {
    _estimatedPlayTime = _endTime.difference(_startTime).inHours;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final user = _auth.currentUser;
      if (user != null) {
        final session = Session(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          startTime: _startTime,
          endTime: _endTime,
          estimatedPlayTime: _estimatedPlayTime,
          gameRule: _gameRuleController.text,
          scenario: _scenarioController.text,
          platform: _platformController.text,
          sessionGoal: _sessionGoalController.text,
          gamemaster: _gamemasterController.text,
          players: _playersController.text.split(',').map((e) => e.trim()).toList(),
          createdBy: user.uid,
          createdAt: DateTime.now(),
        );

        _sessionService.addSession(session);
        Navigator.pop(context);
      } else {
        // 사용자가 로그인하지 않은 경우 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('세션을 추가하려면 로그인이 필요합니다.')),
        );
      }
    }
  }
}