import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../data/appeal_api.dart';
import '../data/appeal_repository.dart';
import '../data/models/appeal_summary.dart';
import 'appeal_detail_screen.dart';

/// Appeals & Re-evaluation list — formal requests for score re-checks.
class AppealsScreen extends StatefulWidget {
  const AppealsScreen({super.key});

  @override
  State<AppealsScreen> createState() => _AppealsScreenState();
}

class _AppealsScreenState extends State<AppealsScreen> {
  final _repository = AppealRepository(AppealApi(ApiClient(), GraphQLClient()));

  bool _loading = true;
  String? _error;
  List<AppealSummary> _appeals = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appeals = await _repository.getMyAppeals();
      if (!mounted) return;
      setState(() => _appeals = appeals);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your appeals.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Appeals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildBody(context),
                ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final pending = _appeals.where((a) => a.status == 'PENDING').length;
    final inReview = _appeals
        .where((a) => const {'APPROVED', 'GRADING', 'COMPARING'}.contains(a.status))
        .length;
    final resolved = _appeals
        .where((a) => const {'PUBLISHED', 'REJECTED'}.contains(a.status))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        Row(
          children: [
            Expanded(child: _SummaryBox(value: '$pending', label: 'Pending')),
            const SizedBox(width: 10),
            Expanded(child: _SummaryBox(value: '$inReview', label: 'In review')),
            const SizedBox(width: 10),
            Expanded(child: _SummaryBox(value: '$resolved', label: 'Resolved')),
          ],
        ),
        const SizedBox(height: 22),
        const SectionLabel('Your Requests'),
        const SizedBox(height: 14),
        if (_appeals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No appeals yet.\nAppeal a released result from its details screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else
          for (int i = 0; i < _appeals.length; i++) ...[
            _AppealCard(
              _appeals[i],
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AppealDetailScreen(appealId: _appeals[i].id),
              )),
            ),
            if (i != _appeals.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

extension _StatusMeta on String {
  String get statusLabel => switch (this) {
        'PENDING' => 'Pending',
        'APPROVED' || 'GRADING' || 'COMPARING' => 'Under review',
        'PUBLISHED' => 'Score adjusted',
        'REJECTED' => 'Rejected',
        _ => this,
      };
  Color get statusFg => switch (this) {
        'PENDING' => AppColors.warnFg,
        'APPROVED' || 'GRADING' || 'COMPARING' => AppColors.indigo,
        'PUBLISHED' => AppColors.success,
        _ => AppColors.muted,
      };
  Color get statusBg => switch (this) {
        'PENDING' => AppColors.warnBg,
        'APPROVED' || 'GRADING' || 'COMPARING' => AppColors.chipBlueBg,
        'PUBLISHED' => const Color(0xFFECFDF5),
        _ => AppColors.statusClosedBg,
      };
  IconData get statusIcon => switch (this) {
        'PENDING' => Icons.hourglass_empty,
        'APPROVED' || 'GRADING' || 'COMPARING' => Icons.search,
        'PUBLISHED' => Icons.check_circle,
        _ => Icons.cancel_outlined,
      };
}

class _AppealCard extends StatelessWidget {
  const _AppealCard(this.a, {required this.onTap});
  final AppealSummary a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.examName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    if (a.className != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.className!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusPill(a.status),
            ],
          ),
          if (a.partLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              a.partLabels.join(' · '),
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                if (a.originalScore != null)
                  _ScoreChip(label: 'Original', value: a.originalScore!),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(a.requestedAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (a.overdue) ...[
            const SizedBox(height: 10),
            const Text(
              'Overdue for review',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.statusBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.statusIcon, size: 13, color: status.statusFg),
          const SizedBox(width: 5),
          Text(
            status.statusLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: status.statusFg,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
      ],
    );
  }
}
