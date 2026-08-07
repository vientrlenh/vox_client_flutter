import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../data/appeal_api.dart';
import '../data/appeal_repository.dart';
import '../data/models/appeal_detail.dart';

class AppealDetailScreen extends StatefulWidget {
  const AppealDetailScreen({super.key, required this.appealId});
  final String appealId;

  @override
  State<AppealDetailScreen> createState() => _AppealDetailScreenState();
}

class _AppealDetailScreenState extends State<AppealDetailScreen> {
  final _repository = AppealRepository(AppealApi(ApiClient(), GraphQLClient()));
  AppealDetail? _appeal;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final appeal = await _repository.getAppeal(widget.appealId); if (mounted) setState(() => _appeal = appeal); }
    catch (e) { if (mounted) setState(() => _error = '$e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Chi tiết phúc khảo')),
      body: _error != null ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger))) : _appeal == null ? const Center(child: CircularProgressIndicator()) : _body(_appeal!),
    );
  }

  Widget _body(AppealDetail appeal) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(appeal.examName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.dark)),
      const SizedBox(height: 6),
      Text('${appeal.className ?? 'Chưa có lớp'} · ${_statusLabel(appeal.status)}', style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 18),
      _section('Lý do phúc khảo', appeal.reason),
      if (appeal.notes?.isNotEmpty == true) _section('Ghi chú của bạn', appeal.notes!),
      _section('Hạn xử lý', appeal.deadline == null ? 'Không có' : DateFormat('dd/MM/yyyy HH:mm').format(appeal.deadline!.toLocal())),
      if (appeal.status == 'PUBLISHED') Container(
        margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFA7F3D0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: _score('Điểm ban đầu', appeal.originalScore)), const Icon(Icons.arrow_forward, color: AppColors.success), Expanded(child: _score('Điểm sau phúc khảo', appeal.finalScore))]),
          const Divider(height: 24),
          const Text('Ghi chú công bố', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
          const SizedBox(height: 6),
          Text(appeal.decisionNote ?? 'Không có ghi chú bổ sung.', style: const TextStyle(color: AppColors.muted)),
        ]),
      ),
    ],
  );

  Widget _section(String label, String value) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 14, color: AppColors.dark))]));
  Widget _score(String label, double? value) => Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)), const SizedBox(height: 4), Text(value?.toStringAsFixed(1) ?? '-', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.dark))]);
  String _statusLabel(String value) => switch (value) { 'PUBLISHED' => 'Đã công bố', 'REJECTED' => 'Bị từ chối', 'PENDING' => 'Chờ xử lý', _ => 'Đang xử lý' };
}
