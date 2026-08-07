import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/exam_detail.dart';
import '../data/models/school_class.dart';
import '../data/teacher_exam_repository.dart';
import 'question_picker_screen.dart';
import 'teacher_exam_status.dart';

/// Single screen for creating a class test, and editing name/description/
/// dates of an existing one (`existing != null`). The class and question
/// set can only be chosen at creation time — the backend's UpdateExamRequest
/// has no schoolClassId field, and question changes go through a separate
/// endpoint the teacher can invoke again from the detail screen if needed.
class ClassTestFormScreen extends StatefulWidget {
  const ClassTestFormScreen({
    super.key,
    required this.repository,
    required this.schoolClasses,
    this.existing,
  });

  final TeacherExamRepository repository;
  final List<SchoolClass> schoolClasses;
  final ExamDetail? existing;

  @override
  State<ClassTestFormScreen> createState() => _ClassTestFormScreenState();
}

class _ClassTestFormScreenState extends State<ClassTestFormScreen> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name);
  late final _descriptionController =
      TextEditingController(text: widget.existing?.description);

  String? _schoolClassId;
  DateTime? _openAt;
  DateTime? _closeAt;
  List<String> _questionIds = [];
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _schoolClassId = widget.existing?.schoolClassId;
    _openAt = widget.existing?.openAt;
    _closeAt = widget.existing?.closeAt;
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickQuestions() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => QuestionPickerScreen(
          repository: widget.repository,
          initiallySelected: _questionIds,
        ),
      ),
    );
    if (result != null) setState(() => _questionIds = result);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = l10n.classTestNameRequired);
      return;
    }
    if (!_isEdit) {
      if (_schoolClassId == null) {
        setState(() => _error = l10n.classTestSelectClass);
        return;
      }
      if (_questionIds.isEmpty) {
        setState(() => _error = l10n.classTestSelectQuestion);
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.repository.updateClassTest(
          widget.existing!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          openAt: _openAt,
          closeAt: _closeAt,
        );
      } else {
        await widget.repository.createClassTest(
          schoolClassId: _schoolClassId!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          openAt: _openAt,
          closeAt: _closeAt,
          questionIds: _questionIds,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.classTestSaveError);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.classTestEditTitle : l10n.classTestNewTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.classTestNameLabel),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration:
                InputDecoration(labelText: l10n.classTestDescriptionLabel),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          if (!_isEdit) ...[
            DropdownButtonFormField<String>(
              initialValue: _schoolClassId,
              decoration: InputDecoration(labelText: l10n.classTestClassLabel),
              items: [
                for (final c in widget.schoolClasses)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (value) => setState(() => _schoolClassId = value),
            ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.classTestOpensAt),
            subtitle: Text(examDateTimeLabel(context, _openAt, l10n.classTestNotSet)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await _pickDateTime(_openAt);
              if (picked != null) setState(() => _openAt = picked);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.classTestClosesAt),
            subtitle: Text(examDateTimeLabel(context, _closeAt, l10n.classTestNotSet)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await _pickDateTime(_closeAt);
              if (picked != null) setState(() => _closeAt = picked);
            },
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.classTestQuestions),
              subtitle:
                  Text(l10n.classTestQuestionsSelected(_questionIds.length)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickQuestions,
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? l10n.classTestSaveButton : l10n.classTestCreateButton),
          ),
        ],
      ),
    );
  }
}
