import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/exam_detail.dart';
import '../data/models/school_class.dart';
import '../data/teacher_exam_repository.dart';
import 'class_test_form_screen.dart';
import 'teacher_exam_status.dart';

class ClassTestDetailScreen extends StatefulWidget {
  const ClassTestDetailScreen({
    super.key,
    required this.repository,
    required this.schoolClasses,
    required this.exam,
  });

  final TeacherExamRepository repository;
  final List<SchoolClass> schoolClasses;
  final ExamDetail exam;

  @override
  State<ClassTestDetailScreen> createState() => _ClassTestDetailScreenState();
}

class _ClassTestDetailScreenState extends State<ClassTestDetailScreen> {
  late ExamDetail _exam = widget.exam;
  bool _busy = false;

  Future<void> _refresh() async {
    final detail = await widget.repository.getExamDetail(_exam.id);
    if (!mounted) return;
    setState(() => _exam = detail);
  }

  Future<void> _runAction(String action) async {
    setState(() => _busy = true);
    try {
      await widget.repository.updateClassTestStatus(_exam.id, action);
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.classTestUpdateStatusError),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassTestFormScreen(
          repository: widget.repository,
          schoolClasses: widget.schoolClasses,
          existing: _exam,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.classTestDeleteTitle),
        content: Text(l10n.classTestDeleteBody(_exam.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.classTestCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.classTestDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.repository.deleteClassTest(_exam.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.classTestDeleteError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = nextStatusActions(_exam.status, l10n);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          _exam.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.dark),
            onPressed: _busy ? null : _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(children: [examStatusChip(_exam.status, l10n)]),
          const SizedBox(height: 16),
          DetailCard(
            children: [
              if (_exam.description != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _exam.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textFaint,
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
              InfoRow(
                label: l10n.classTestOpens,
                value: examDateTimeLabel(context, _exam.openAt, l10n.classTestNotSet),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              InfoRow(
                label: l10n.classTestCloses,
                value: examDateTimeLabel(context, _exam.closeAt, l10n.classTestNotSet),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionLabel(l10n.classTestActions),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final action in actions)
                  action.key == 'CANCEL'
                      ? OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _runAction(action.key),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: Text(action.value),
                        )
                      : FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _runAction(action.key),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.indigo,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: Text(action.value),
                        ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
