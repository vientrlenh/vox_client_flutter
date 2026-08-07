import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../data/appeal_api.dart';
import '../data/appeal_repository.dart';

/// One appealable part of the result — a paper item, labeled by its section.
class AppealablePart {
  const AppealablePart({
    required this.paperItemId,
    required this.label,
    required this.score,
  });

  final String paperItemId;
  final String label;
  final double score;
}

/// New Appeal form — submit a request to re-evaluate a graded attempt.
class NewAppealScreen extends StatefulWidget {
  const NewAppealScreen({
    super.key,
    required this.candidateResultId,
    required this.examName,
    required this.parts,
  });

  final String candidateResultId;
  final String examName;
  final List<AppealablePart> parts;

  @override
  State<NewAppealScreen> createState() => _NewAppealScreenState();
}

class _NewAppealScreenState extends State<NewAppealScreen> {
  final _repository =
      AppealRepository(AppealApi(ApiClient(), GraphQLClient()));

  final Set<String> _selectedPaperItemIds = {};
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  bool _agree = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _valid =>
      _selectedPaperItemIds.isNotEmpty &&
      _reason.text.trim().length >= 10 &&
      _agree &&
      !_submitting;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.createAppeal(
        candidateResultId: widget.candidateResultId,
        paperItemIds: _selectedPaperItemIds.toList(),
        reason: _reason.text.trim(),
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _SubmittedSheet(),
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFor(Object e) {
    // Display backend error directly
    if (e is DioException) {
      final data = e.response?.data;
      final serverMessage = data is Map ? data['message'] : null;
      if (serverMessage is String && serverMessage.isNotEmpty) {
        return serverMessage;
      }
    }
    return 'Could not submit appeal. $e';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'New Appeal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.chipBlueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, size: 18, color: AppColors.indigo),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A teacher will manually re-check the parts you select. '
                    'The re-evaluated score may be higher, lower, or unchanged.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF3730A3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            widget.examName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Parts to re-evaluate', required: true),
          const SizedBox(height: 10),
          for (int i = 0; i < widget.parts.length; i++) ...[
            _PartOption(
              part: widget.parts[i],
              selected: _selectedPaperItemIds.contains(
                widget.parts[i].paperItemId,
              ),
              onTap: () => setState(() {
                final id = widget.parts[i].paperItemId;
                _selectedPaperItemIds.contains(id)
                    ? _selectedPaperItemIds.remove(id)
                    : _selectedPaperItemIds.add(id);
              }),
            ),
            if (i != widget.parts.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),

          const _FieldLabel('Reason for appeal', required: true),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            onChanged: (_) => setState(() {}),
            maxLines: 5,
            maxLength: 512,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText:
                  'Explain why you believe the score should be reviewed…',
              hintStyle:
                  const TextStyle(fontSize: 14, color: AppColors.textGhost),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.indigo, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),

          const _FieldLabel('Notes (optional)'),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 512,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Anything else the reviewer should know…',
              hintStyle:
                  const TextStyle(fontSize: 14, color: AppColors.textGhost),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.indigo, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Agreement
          GestureDetector(
            onTap: () => setState(() => _agree = !_agree),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _agree ? AppColors.indigo : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _agree
                          ? AppColors.indigo
                          : const Color(0xFFCBD5E1),
                      width: 1.6,
                    ),
                  ),
                  child: _agree
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'I understand the re-evaluated score is final and may be '
                    'higher, lower, or unchanged.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
            const SizedBox(height: 12),
          ],

          FilledButton(
            onPressed: _valid ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
              textStyle:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit appeal'),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: AppColors.danger)),
      ],
    );
  }
}

class _PartOption extends StatelessWidget {
  const _PartOption({
    required this.part,
    required this.selected,
    required this.onTap,
  });

  final AppealablePart part;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.indigo : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                part.label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ),
            Text(
              part.score.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.indigo : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.indigo : const Color(0xFFCBD5E1),
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmittedSheet extends StatelessWidget {
  const _SubmittedSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 18),
          const Text(
            'Appeal submitted',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your request is now pending. A teacher will review it — '
            'you’ll get a notification when it’s resolved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
