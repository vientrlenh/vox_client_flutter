import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/exam_detail.dart';
import 'teacher_exam_status.dart';

/// Read-only: centralized exams are admin-created; teachers only view
/// status/membership here until blueprint/paper authoring UI is built.
class CentralizedExamDetailScreen extends StatelessWidget {
  const CentralizedExamDetailScreen({super.key, required this.exam});

  final ExamDetail exam;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          exam.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(children: [examStatusChip(exam.status, l10n)]),
          const SizedBox(height: 16),
          DetailCard(
            children: [
              if (exam.description != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    exam.description!,
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
                value: examDateTimeLabel(context, exam.openAt, l10n.classTestNotSet),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              InfoRow(
                label: l10n.classTestCloses,
                value: examDateTimeLabel(context, exam.closeAt, l10n.classTestNotSet),
              ),
              if (exam.blueprintId != null) ...[
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                InfoRow(
                  label: l10n.centralizedExamBlueprint,
                  value:
                      '${exam.blueprintId} (v${exam.blueprintVersionId ?? '-'})',
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          SectionLabel(l10n.centralizedExamMembers),
          const SizedBox(height: 12),
          DetailCard(
            children: [
              if (exam.members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    l10n.centralizedExamNoMembers,
                    style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
                  ),
                )
              else
                for (int i = 0; i < exam.members.length; i++) ...[
                  _MemberRow(exam.members[i]),
                  if (i != exam.members.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.member);
  final ExamMemberRef member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.chipBlueBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 16,
              color: AppColors.chipBlueFg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.fullName ?? member.userId,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
          ),
          TagChip(member.role),
        ],
      ),
    );
  }
}
