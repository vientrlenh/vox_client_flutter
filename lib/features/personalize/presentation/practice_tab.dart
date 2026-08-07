import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/storage/preference_storage.dart';
import '../data/personalize_repository.dart';
import '../../../l10n/app_localizations.dart';
import 'onboarding/onboarding_flow.dart';
import 'practice_home_screen.dart';

/// Entry point of the "Luyện nói" tab.
///
/// Cổng chặn hỏi SERVER (`quizCompletedAt`), không hỏi cờ trên máy.
///
/// Bản trước chỉ đọc SharedPreferences. Cờ đó chỉ là trạng thái của MỘT thiết bị: cài lại
/// app, đổi máy, hay xoá dữ liệu ứng dụng là mất, và học sinh bị bắt làm lại bài quiz mà
/// server đã ghi nhận xong -- làm lại còn ghi đè điểm sở thích đang dùng để xếp chủ đề.
///
/// Cờ cục bộ giữ lại làm bộ nhớ đệm: vào tab là hiện ngay theo cờ, đồng thời hỏi server rồi
/// chỉnh lại nếu lệch. Mất mạng thì dùng cờ, vì bắt học sinh làm lại quiz chỉ vì rớt sóng còn
/// tệ hơn hiện nhầm màn hình một lúc.
class PracticeTab extends StatefulWidget {
  const PracticeTab({super.key});

  @override
  State<PracticeTab> createState() => PracticeTabState();
}

class PracticeTabState extends State<PracticeTab> {
  final _preferences = PreferenceStorage();

  bool _loading = true;
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await _preferences.getPracticeOnboardingDone();
    if (!mounted) return;
    setState(() {
      _onboarded = cached;
      _loading = false;
    });
    try {
      final completed = await PersonalizeRepository().isInterestQuizCompleted();
      if (!mounted) return;
      if (completed != cached) {
        await _preferences.savePracticeOnboardingDone(completed);
        if (!mounted) return;
        setState(() => _onboarded = completed);
      }
    } catch (_) {
      // Mất mạng: giữ nguyên cờ cục bộ. Không ép làm lại quiz vì một lần gọi hỏng.
    }
  }

  /// Runs onboarding and refreshes the gate. Also used by the Profile menu's
  /// "redo onboarding" entry.
  Future<void> startOnboarding() async {
    final completed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const OnboardingFlow()));
    if (!mounted) return;
    if (completed ?? false) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_onboarded) return const PracticeHomeScreen();
    return _OnboardingIntro(onStart: startOnboarding);
  }
}

class _OnboardingIntro extends StatelessWidget {
  const _OnboardingIntro({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.indigo, AppColors.secondary],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.pzOnboardingIntroTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.pzOnboardingIntroBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 32),
          GradientButton(
            label: l10n.pzOnboardingIntroStart,
            icon: Icons.arrow_forward,
            onTap: onStart,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.pzOnboardingIntroDuration,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textGhost),
          ),
        ],
      ),
    );
  }
}
