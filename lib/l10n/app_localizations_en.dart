// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profileTitle => 'Profile';

  @override
  String get defaultUserName => 'User';

  @override
  String get statusActive => 'Active';

  @override
  String get roleSystemAdmin => 'System Admin';

  @override
  String get roleSchoolAdmin => 'School Admin';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get roleStudent => 'Student';

  @override
  String get statPracticesDone => 'Practices Done';

  @override
  String get statAverageScore => 'Average Score';

  @override
  String get statDayStreak => 'Day Streak';

  @override
  String get sectionAccount => 'Account';

  @override
  String get sectionSettings => 'Settings';

  @override
  String get menuMyResults => 'My Results';

  @override
  String get menuRecordings => 'Recordings';

  @override
  String get menuAppeals => 'Appeals & Re-evaluation';

  @override
  String get menuLanguage => 'Language';

  @override
  String get menuNotifications => 'Notifications';

  @override
  String get menuLogOut => 'Log Out';

  @override
  String get profileLoadError => 'Could not load profile information.';

  @override
  String get chooseLanguage => 'Choose Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageVietnamese => 'Vietnamese';

  @override
  String get navHome => 'Home';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navProfile => 'Profile';

  @override
  String get greetingLateNight => 'Late night session?';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get homeContinueLearning => 'Continue with';

  @override
  String get homeExamsToComplete => 'Exams To Complete';

  @override
  String get homeNoExamsLeft => 'No exams left to complete';

  @override
  String get homeNoDateSet => 'No date set';

  @override
  String get homeNotCompleted => 'Not completed';

  @override
  String get homeSearchLessons => 'Search lessons…';

  @override
  String get homeResume => 'Resume →';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsGroupNew => 'New';

  @override
  String get notificationsGroupEarlier => 'Earlier';

  @override
  String get scheduleTitle => 'Your Schedules';

  @override
  String scheduleLoadError(String error) {
    return 'Could not load your schedule.\n$error';
  }

  @override
  String get scheduleRetry => 'Retry';

  @override
  String scheduleToday(String date) {
    return 'Today · $date';
  }

  @override
  String get scheduleNoSessionsToday => 'No sessions today.';

  @override
  String scheduleTomorrow(String date) {
    return 'Tomorrow · $date';
  }

  @override
  String get scheduleNoSessionsTomorrow => 'No sessions tomorrow.';

  @override
  String scheduleOnDate(String weekday, String date) {
    return '$weekday · $date';
  }

  @override
  String get scheduleNoSessionsOnDate => 'No sessions on this day.';

  @override
  String get scheduleKindCentralized => 'Centralized';

  @override
  String get scheduleKindClassTest => 'Class Test';

  @override
  String get scheduleTimeUnset => '--:--';

  @override
  String get scheduleJumpToday => 'Today';

  @override
  String get scheduleLegendHasSession => 'Has a scheduled session';

  @override
  String scheduleRoomLabel(String room) {
    return 'Room $room';
  }

  @override
  String get scheduleStatusOpen => 'Open';

  @override
  String get scheduleStatusUpcoming => 'Upcoming';

  @override
  String get scheduleStatusClosed => 'Closed';

  @override
  String get teacherExamClassTestsTab => 'Class Tests';

  @override
  String get teacherExamCentralizedTab => 'Centralized';

  @override
  String get teacherExamKindClassTest => 'Class Test';

  @override
  String get teacherExamCentralizedSection => 'Centralized Exams';

  @override
  String get teacherExamNoClassTests => 'No class tests yet.';

  @override
  String get teacherExamNoCentralizedExams =>
      'No centralized exams assigned to you.';

  @override
  String get teacherExamStatusDraft => 'Draft';

  @override
  String get teacherExamStatusScheduled => 'Scheduled';

  @override
  String get teacherExamStatusInProgress => 'In Progress';

  @override
  String get teacherExamStatusClosed => 'Closed';

  @override
  String get teacherExamStatusResultsPublished => 'Results Published';

  @override
  String get teacherExamStatusCancelled => 'Cancelled';

  @override
  String get teacherExamActionSchedule => 'Schedule';

  @override
  String get teacherExamActionCancel => 'Cancel';

  @override
  String get teacherExamActionStart => 'Start';

  @override
  String get teacherExamActionClose => 'Close';

  @override
  String get teacherExamActionPublishResults => 'Publish Results';

  @override
  String get classTestUpdateStatusError => 'Could not update status.';

  @override
  String get classTestDeleteTitle => 'Delete class test?';

  @override
  String classTestDeleteBody(String name) {
    return 'This will remove \"$name\" permanently.';
  }

  @override
  String get classTestCancel => 'Cancel';

  @override
  String get classTestDelete => 'Delete';

  @override
  String get classTestDeleteError => 'Could not delete class test.';

  @override
  String get classTestOpens => 'Opens';

  @override
  String get classTestCloses => 'Closes';

  @override
  String get classTestNotSet => 'Not set';

  @override
  String get classTestActions => 'Actions';

  @override
  String get classTestNameRequired => 'Name is required.';

  @override
  String get classTestSelectClass => 'Select a class.';

  @override
  String get classTestSelectQuestion => 'Select at least one question.';

  @override
  String get classTestSaveError => 'Could not save the class test.';

  @override
  String get classTestEditTitle => 'Edit Class Test';

  @override
  String get classTestNewTitle => 'New Class Test';

  @override
  String get classTestNameLabel => 'Name';

  @override
  String get classTestDescriptionLabel => 'Description';

  @override
  String get classTestClassLabel => 'Class';

  @override
  String get classTestOpensAt => 'Opens at';

  @override
  String get classTestClosesAt => 'Closes at';

  @override
  String get classTestQuestions => 'Questions';

  @override
  String classTestQuestionsSelected(int count) {
    return '$count selected';
  }

  @override
  String get classTestSaveButton => 'Save';

  @override
  String get classTestCreateButton => 'Create Class Test';

  @override
  String get centralizedExamBlueprint => 'Blueprint';

  @override
  String get centralizedExamMembers => 'Members';

  @override
  String get centralizedExamNoMembers => 'No members assigned.';

  @override
  String get questionPickerLoadError => 'Could not load questions.';

  @override
  String get questionPickerTitle => 'Select Questions';

  @override
  String questionPickerDone(int count) {
    return 'Done ($count)';
  }

  @override
  String get questionPickerSearchHint => 'Search questions';

  @override
  String get navPractice => 'Practice';

  @override
  String get pzPreparingQuestions =>
      'Preparing questions for this topic…\nThis takes about 10-20 seconds the first time.';

  @override
  String get pzRetry => 'Retry';

  @override
  String get pzLoadError => 'Could not load personalized practice.';

  @override
  String get pzSeeAll => 'See all';

  @override
  String pzMinutes(int count) {
    return '$count min';
  }

  @override
  String get pzHomeSessionToday => 'TODAY\'S SESSION';

  @override
  String get pzHomePersonalizedBadge => 'PERSONALIZED';

  @override
  String get pzHomeSessionMeta => '1-on-1 conversation with AI';

  @override
  String get pzHomeStartSpeaking => 'Start speaking';

  @override
  String get pzHomeChangeTopic => 'Change topic';

  @override
  String get pzHomeStatSessions => 'Sessions done';

  @override
  String get pzHomeStatAverage => 'Average score';

  @override
  String get pzHomeStatWeeklyGoal => 'Sessions this week';

  @override
  String get pzHomeNoTopicYet =>
      'No suggestions yet — pick a topic to get started';

  @override
  String get pzHomeSuggestions => 'Suggested for you';

  @override
  String get pzPreparingTopics => 'Finding topics that fit you…';

  @override
  String get pzPreparingHint =>
      'The first time takes a little longer while we write new ones.';

  @override
  String get pzTopicsPreparing => 'We are putting your profile together';

  @override
  String get pzTopicsPreparingBody =>
      'Your topics are being written from the survey you just finished. Come back in a minute or two.';

  @override
  String get pzTopicsRefresh => 'Reload';

  @override
  String get pzTopicsTitle => 'Speaking topics';

  @override
  String get pzTopicsSearchHint => 'Search topics, skills…';

  @override
  String get pzTopicsFilterForYou => 'For you';

  @override
  String get pzTopicsFilterSaved => 'Saved';

  @override
  String get pzTopicsRandom => 'Random topic';

  @override
  String get pzTopicsSave => 'Save topic';

  @override
  String get pzTopicsUnsave => 'Unsave';

  @override
  String get pzTopicsPriority => 'PRIORITY #1';

  @override
  String pzTopicsMatch(int percent) {
    return '$percent% match';
  }

  @override
  String get pzTopicsSpeakThis => 'Speak this topic';

  @override
  String get pzTopicsOtherSuggestions => 'Other suggestions';

  @override
  String get pzTopicsEmpty => 'No topics in this list yet.';

  @override
  String get pzTopicsFooterTip =>
      'This list updates after every session — based on the topics you get excited about and your recent scores.';

  @override
  String get pzTopicsWhy => 'Why?';

  @override
  String pzSessionSpoken(String spoken, String budget) {
    return 'Spoken · $spoken / $budget';
  }

  @override
  String pzSessionLive(String time) {
    return 'Speaking · $time';
  }

  @override
  String pzSessionCorrectNow(int count) {
    return 'FIX NOW · $count POINTS';
  }

  @override
  String pzSessionKnownWeakness(int count) {
    return 'Known weak spot · time #$count';
  }

  @override
  String get pzSessionHearCorrect => 'Hear it right';

  @override
  String get pzSessionContinue => 'Continue';

  @override
  String get pzSessionRecording => 'Recording your answer…';

  @override
  String get pzSessionTapToSpeak => 'Tap the mic to answer';

  @override
  String get pzSessionThinking => 'Listening…';

  @override
  String get pzSessionFinish => 'Finish session';

  @override
  String get pzSessionMicDenied =>
      'Microphone permission is needed to record your answer.';

  @override
  String get pzSessionRecordError =>
      'Could not start recording. Please try again.';

  @override
  String get pzSessionExitTitle => 'Leave this session?';

  @override
  String get pzSessionExitBody =>
      'Your progress in this session will not be saved.';

  @override
  String get pzSessionExitStay => 'Keep speaking';

  @override
  String get pzSessionExitLeave => 'Leave';

  @override
  String get pzSessionPlaybackUnavailable => 'No recording available yet.';

  @override
  String get pzSessionNoSampleAudio => 'No model audio for this sentence yet.';

  @override
  String get pzSessionTurnSaveFailed =>
      'Your last turn couldn\'t be saved. Please try again.';

  @override
  String get pzSessionEndedQuotaExceeded =>
      'You\'ve used up your practice quota. The session has ended.';

  @override
  String get pzSessionReconnectFailed =>
      'Connection lost and couldn\'t be restored. The session has ended.';

  @override
  String get pzSummaryTitle => 'Session summary';

  @override
  String pzSummaryHeader(String topic, int minutes) {
    return '$topic · $minutes MIN';
  }

  @override
  String pzSummaryDelta(String delta) {
    return '$delta vs last session';
  }

  @override
  String get pzSummaryRubric => 'Rubric · 5 criteria';

  @override
  String get pzSummaryRubricLegend => 'weight · score /10';

  @override
  String get pzSummaryPronunciation => 'Words to work on';

  @override
  String get pzSummaryPronunciationEmpty =>
      'No word scored below the threshold this session.';

  @override
  String pzSummaryWorstPhoneme(String phoneme, String percent) {
    return '/$phoneme/ · $percent%';
  }

  @override
  String get pzSummaryRepeatedErrors => 'Repeated mistakes this session';

  @override
  String pzSummaryDrill(int count, int minutes) {
    return 'Drill these $count mistakes · $minutes min';
  }

  @override
  String get pzSummaryReplay => 'Replay my recording';

  @override
  String get pzLearningProfile => 'Learning profile';

  @override
  String get pzLearningProfileHint => 'Average score and recent sessions';

  @override
  String get pzHistoryTitle => 'Practice history';

  @override
  String get pzHistoryEmpty => 'No practice sessions yet';

  @override
  String get pzOnboardingIntroTitle => 'Let\'s build your speaking profile';

  @override
  String get pzOnboardingIntroBody =>
      'Answer a few quick questions so every practice session is picked for you — your level, your interests, your weak spots.';

  @override
  String get pzOnboardingIntroStart => 'Get started';

  @override
  String get pzOnboardingIntroDuration => 'About 3 minutes · no right answers';

  @override
  String get pzOnboardingQuizTitle => 'Your learning style';

  @override
  String pzOnboardingProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get pzOnboardingQuizTip =>
      'There are no right answers — answer honestly so the plan fits you.';

  @override
  String get pzOnboardingBack => 'Back';

  @override
  String get pzOnboardingContinue => 'Continue';

  @override
  String get pzOnboardingSkip => 'Skip';

  @override
  String get pzOnboardingInterestsTitle => 'Interests & goals';

  @override
  String get pzOnboardingInterestsHeading => 'What do you want to talk about?';

  @override
  String get pzOnboardingInterestsBody =>
      'Pick at least 3 topics. I\'ll use exactly these for your speaking practice — and update them as you start talking about other things.';

  @override
  String get pzOnboardingMainGoal => 'Main goal';

  @override
  String pzOnboardingContinueWithCount(int count) {
    return 'Continue · $count topics picked';
  }

  @override
  String get pzOnboardingPickThree => 'Pick at least 3 topics';

  @override
  String get pzOnboardingProfileHeader => 'YOUR LEARNING PROFILE';

  @override
  String get pzOnboardingCefr => 'Estimated CEFR';

  @override
  String get pzOnboardingFlas => 'Attitude & motivation (FLAS)';

  @override
  String get pzOnboardingRoadmap => 'Suggested 4-week plan';

  @override
  String get pzOnboardingStartFirst => 'Start your first session';

  @override
  String get pzOnboardingRestart => 'Redo speaking onboarding';

  @override
  String get pzGoalTitle => 'Practice goal';

  @override
  String get pzGoalExamPrep => 'Exam prep';

  @override
  String get pzGoalAbilityImprovement => 'Skill building';

  @override
  String get pzGoalUpdateError =>
      'Couldn\'t update your practice goal, please try again';

  @override
  String get pzInterestQuizTitle => 'Discover your interests';

  @override
  String get pzInterestQuizHeading => 'Of these 3 things…';

  @override
  String get pzInterestQuizBody =>
      'Pick the one most like you and the one least like you. No right answer.';

  @override
  String get pzInterestQuizMostLike => 'Most like me';

  @override
  String get pzInterestQuizLeastLike => 'Least like me';

  @override
  String get pzInterestQuizSubmitError =>
      'Couldn\'t submit your answers, please try again';
}
