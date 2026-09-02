import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/messaging/notification_signal.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/app_notification.dart';
import 'notification_destination.dart';
import '../data/notification_graphql_api.dart';
import '../data/notification_repository.dart';
import '../data/notification_rest_api.dart';

/// Thông báo — điểm thi, phúc khảo, nhắc lịch chấm.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;

  final _repository = NotificationRepository(
    NotificationGraphQLApi(GraphQLClient()),
    NotificationRestApi(ApiClient()),
  );
  final _scrollController = ScrollController();

  List<AppNotification> _items = const [];
  String? _cursor;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Push chỉ là tín hiệu "có cái mới": nội dung thật vẫn nạp lại từ server.
    NotificationSignal.instance.revision.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    NotificationSignal.instance.revision.removeListener(_reload);
    _scrollController.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) _load();
  }

  void _onScroll() {
    if (!_hasNext || _loadingMore || _loading) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.getPage(limit: _pageSize);
      // Đồng bộ badge với server ngay lúc mở màn: con số cộng dồn tại chỗ theo
      // push có thể đã lệch (đọc trên web, cài lại app...).
      await _repository.refreshUnreadCount();
      if (!mounted) return;
      setState(() {
        _items = page.content;
        _cursor = page.nextCursor;
        _hasNext = page.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.getPage(cursor: _cursor, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.content];
        _cursor = page.nextCursor;
        _hasNext = page.hasNext;
        _loadingMore = false;
      });
    } catch (_) {
      // Trang sau hỏng thì giữ nguyên những gì đã có -- người dùng vẫn đọc được
      // phần cũ, và cuộn tiếp sẽ thử lại.
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    final previous = _items;
    final now = DateTime.now();
    setState(() {
      _items = [for (final n in _items) n.unread ? n.copyWith(readAt: now) : n];
    });
    try {
      await _repository.markAllRead();
    } catch (_) {
      if (!mounted) return;
      // Trả lại đúng trạng thái cũ: để nguyên "đã đọc" trong khi server vẫn đang
      // chưa đọc là kiểu sai lệch khiến người dùng bỏ lỡ thông báo thật.
      setState(() => _items = previous);
      _showError(AppLocalizations.of(context)!.notificationsMarkAllReadError);
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (notification.unread) {
      setState(() {
        _items = [
          for (final n in _items)
            n.id == notification.id ? n.copyWith(readAt: DateTime.now()) : n,
        ];
      });
      // Không chặn điều hướng: đánh dấu đã đọc hỏng cũng không đáng giữ người
      // dùng lại ở màn danh sách.
      _repository.markRead(notification.id).catchError((_) {});
    }

    // Cùng một bảng tra với luồng bấm từ khay thông báo, xem notification_destination.dart.
    // Null nghĩa là app này không có màn hình cho target đó -- ở nguyên danh sách, nơi nội
    // dung thông báo đã hiển thị đầy đủ.
    final page = notificationDestination(notification.payload);
    if (page == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasUnread = _items.any((n) => n.unread);
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
        title: Text(
          l10n.notificationsTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: hasUnread ? _markAllRead : null,
            child: Text(
              l10n.notificationsMarkAllRead,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasUnread ? AppColors.indigo : AppColors.textGhost,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(context, l10n),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: l10n.notificationsLoadError(_error.toString()),
        action: TextButton(
          onPressed: _load,
          child: Text(l10n.notificationsRetry),
        ),
      );
    }
    if (_items.isEmpty) {
      return _MessageState(
        icon: Icons.notifications_none,
        title: l10n.notificationsEmptyTitle,
        body: l10n.notificationsEmptyBody,
      );
    }

    final unread = _items.where((n) => n.unread).toList();
    final read = _items.where((n) => !n.unread).toList();
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (unread.isNotEmpty) ...[
          _group(context, l10n.notificationsGroupNew, unread),
          const SizedBox(height: 22),
        ],
        if (read.isNotEmpty) _group(context, l10n.notificationsGroupEarlier, read),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }

  Widget _group(BuildContext context, String label, List<AppNotification> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
        ),
        for (int i = 0; i < items.length; i++) ...[
          _NotifTile(items[i], onTap: () => _open(items[i])),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Trạng thái rỗng/lỗi — cùng một khung để hai màn không lệch nhau.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // ListView chứ không Center: RefreshIndicator cần một scrollable để kéo.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        Icon(icon, size: 48, color: AppColors.textGhost),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 12),
          Center(child: action),
        ],
      ],
    );
  }
}

extension _KindMeta on NotificationKind {
  IconData get icon => switch (this) {
        NotificationKind.examResult => Icons.assignment_turned_in_outlined,
        NotificationKind.appeal => Icons.gavel_outlined,
        NotificationKind.grading => Icons.rate_review_outlined,
        NotificationKind.blueprint => Icons.description_outlined,
        NotificationKind.invoice => Icons.receipt_long_outlined,
        NotificationKind.account => Icons.person_outline,
        NotificationKind.other => Icons.notifications_none,
      };

  Color get fg => switch (this) {
        NotificationKind.examResult => AppColors.success,
        NotificationKind.appeal => AppColors.accent,
        NotificationKind.grading => AppColors.warning,
        NotificationKind.blueprint => AppColors.indigo,
        NotificationKind.invoice => AppColors.success,
        NotificationKind.account => AppColors.indigo,
        NotificationKind.other => AppColors.muted,
      };

  Color get bg => switch (this) {
        NotificationKind.examResult => AppColors.chipGreenBg,
        NotificationKind.appeal => const Color(0xFFF5F3FF),
        NotificationKind.grading => AppColors.warnBg,
        NotificationKind.blueprint => AppColors.chipBlueBg,
        NotificationKind.invoice => AppColors.chipGreenBg,
        NotificationKind.account => AppColors.chipBlueBg,
        NotificationKind.other => AppColors.chipNeutralBg,
      };
}

/// Thời điểm hiển thị dạng tương đối cho vài ngày gần đây, quá đó thì hiện ngày
/// thật — "37 ngày trước" không nói lên điều gì.
String _relativeTime(AppLocalizations l10n, String locale, DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l10n.notificationsTimeNow;
  if (diff.inHours < 1) return l10n.notificationsTimeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.notificationsTimeHours(diff.inHours);
  if (diff.inDays < 7) return l10n.notificationsTimeDays(diff.inDays);
  return DateFormat.yMMMd(locale).format(time);
}

class _NotifTile extends StatelessWidget {
  const _NotifTile(this.notification, {required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unread = notification.unread;
    final kind = notification.kind;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.chipBlueBg.withValues(alpha: 0.4)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kind.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(kind.icon, size: 21, color: kind.fg),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(top: 5, left: 6),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(
                      l10n,
                      Localizations.localeOf(context).toString(),
                      notification.createdAt,
                    ),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGhost,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
