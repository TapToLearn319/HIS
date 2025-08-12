import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../sidebar_menu.dart';  // AppScaffold
        // isDisplay 전역 플래그


/// Presenter 모드일 때 보여줄 화면
class PresenterSettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(body:Scaffold(
      appBar: AppBar(
        title: const Text('Presenter setting'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text(
              'Presenter setting Selection',
              style: TextStyle(fontSize: 24),
            ),
            ElevatedButton(
              onPressed: () {
                final current = Localizations.localeOf(context);
                final newLocale = current.languageCode == 'en'
                    ? const Locale('ko')
                    : const Locale('en');
                setLocale(newLocale); // main.dart에 정의한 함수
              },
              child: Text(AppLocalizations.of(context)!.toggleLanguage),
            ),
          ],
        ),
      ),),
      selectedIndex: 2, // 사이드바에서 퀴즈 선택 메뉴 인덱스
      
    );
  }
}