import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final List<String> tips = [
    "TRPG 세션을 정기적으로 계획하세요!",
    "캐릭터 배경 스토리를 깊이 있게 만들어보세요.",
    "룰북을 자주 참고하면 게임 진행이 수월해집니다.",
    "팀원들과 소통하며 캐릭터 간 관계를 발전시켜보세요.",
    "세션 후 피드백을 나누면 더 재미있는 게임을 만들 수 있습니다.",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                tips[DateTime.now().second % tips.length],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}