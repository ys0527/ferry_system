import 'package:flutter/material.dart';
import 'models/notification_item.dart';
import 'services/notification_service.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxState();
}

class _InboxState extends State<InboxPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  final NotificationService _service = NotificationService();

  bool _isLoading = true;
  String? _error;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notifications = await _service.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTap(NotificationItem notification) async {
    if (notification.isRead) return;
    try {
      await _service.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = NotificationItem(
            id: notification.id,
            type: notification.type,
            title: notification.title,
            body: notification.body,
            isRead: true,
            createdAt: notification.createdAt,
          );
        }
      });
    } catch (_) {
      // Not critical -- leave it showing as unread if this fails.
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'Booking':
        return Icons.check_circle;
      case 'Rewards':
        return Icons.card_giftcard;
      case 'Weather':
        return Icons.cloud;
      case 'Delay':
        return Icons.report_problem;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Inbox'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : _notifications.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No notifications yet.')),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildTile(_notifications[index]),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.cloud_off, size: 48, color: Colors.black38),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: teal),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(NotificationItem n) {
    return GestureDetector(
      onTap: () => _handleTap(n),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ice,
          borderRadius: BorderRadius.circular(14),
          border: n.isRead ? null : Border.all(color: teal, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: teal,
              child: Icon(_iconFor(n.type), color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: navy),
                  ),
                  if (n.body != null && n.body!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body!, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_formatDate(n.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}