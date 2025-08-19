import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// No description provided for @noLog.
  ///
  /// In en, this message translates to:
  /// **'There is no log'**
  String get noLog;

  /// No description provided for @classTools.
  ///
  /// In en, this message translates to:
  /// **'Class Tools'**
  String get classTools;

  /// No description provided for @classContents.
  ///
  /// In en, this message translates to:
  /// **'Class Contents'**
  String get classContents;

  /// No description provided for @quiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get quiz;

  /// No description provided for @aiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChat;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @hideLogs.
  ///
  /// In en, this message translates to:
  /// **'Hide Logs'**
  String get hideLogs;

  /// No description provided for @showLogs.
  ///
  /// In en, this message translates to:
  /// **'Show Logs'**
  String get showLogs;

  /// No description provided for @setting.
  ///
  /// In en, this message translates to:
  /// **'Setting'**
  String get setting;

  /// No description provided for @seat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get seat;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a student name'**
  String get enterName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get cancel;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'logout'**
  String get logout;

  /// No description provided for @resetLogs.
  ///
  /// In en, this message translates to:
  /// **'Reset Logs'**
  String get resetLogs;

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get noName;

  /// No description provided for @toggleLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch to Korean'**
  String get toggleLanguage;

  /// No description provided for @presenterMain.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get presenterMain;

  /// No description provided for @toolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Classroom Tools'**
  String get toolsTitle;

  /// No description provided for @toolOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get toolOpen;

  /// No description provided for @toolAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get toolAttendance;

  /// No description provided for @toolAttendanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Smart attendance tracking'**
  String get toolAttendanceDesc;

  /// No description provided for @toolRandomGrouping.
  ///
  /// In en, this message translates to:
  /// **'Random Grouping'**
  String get toolRandomGrouping;

  /// No description provided for @toolRandomGroupingDesc.
  ///
  /// In en, this message translates to:
  /// **'Fair team distribution system'**
  String get toolRandomGroupingDesc;

  /// No description provided for @toolRandomSeat.
  ///
  /// In en, this message translates to:
  /// **'Random Seat'**
  String get toolRandomSeat;

  /// No description provided for @toolRandomSeatDesc.
  ///
  /// In en, this message translates to:
  /// **'Optimal seat arrangements'**
  String get toolRandomSeatDesc;

  /// No description provided for @toolTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get toolTimer;

  /// No description provided for @toolTimerDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage class time with precision'**
  String get toolTimerDesc;

  /// No description provided for @toolVoting.
  ///
  /// In en, this message translates to:
  /// **'Voting'**
  String get toolVoting;

  /// No description provided for @toolVotingDesc.
  ///
  /// In en, this message translates to:
  /// **'Collect instant class feedback'**
  String get toolVotingDesc;

  /// No description provided for @toolQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get toolQuiz;

  /// No description provided for @toolQuizDesc.
  ///
  /// In en, this message translates to:
  /// **'Interactive learning assessments'**
  String get toolQuizDesc;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
