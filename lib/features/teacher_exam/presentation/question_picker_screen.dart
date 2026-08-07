import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/teacher_question.dart';
import '../data/teacher_exam_repository.dart';

class QuestionPickerScreen extends StatefulWidget {
  const QuestionPickerScreen({
    super.key,
    required this.repository,
    this.initiallySelected = const [],
  });

  final TeacherExamRepository repository;
  final List<String> initiallySelected;

  @override
  State<QuestionPickerScreen> createState() => _QuestionPickerScreenState();
}

class _QuestionPickerScreenState extends State<QuestionPickerScreen> {
  List<TeacherQuestion> _questions = const [];
  late final Set<String> _selected = {...widget.initiallySelected};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final questions = await widget.repository.getQuestions(keyword: keyword);
      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = AppLocalizations.of(context)!.questionPickerLoadError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.questionPickerTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected.toList()),
            child: Text(l10n.questionPickerDone(_selected.length)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.questionPickerSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (value) => _load(keyword: value),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.textFaint)),
                      )
                    : ListView.builder(
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final q = _questions[index];
                          final checked = _selected.contains(q.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setState(() {
                                if (value ?? false) {
                                  _selected.add(q.id);
                                } else {
                                  _selected.remove(q.id);
                                }
                              });
                            },
                            title: Text(q.questionText),
                            subtitle: Text(q.type.name),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
