class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final String priority; // CRITICAL, HIGH, NORMAL, LOW

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    this.actionUrl,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
    this.priority = 'NORMAL',
  });

  bool get isUnread => !isRead;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      notificationType: json['notification_type'] as String? ?? 'INFO',
      isRead: json['is_read'] as bool? ?? false,
      actionUrl: json['action_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      priority: json['priority'] as String? ?? 'NORMAL',
    );
  }

  NotificationModel copyWith({bool? isRead, DateTime? readAt}) => NotificationModel(
        id: id,
        title: title,
        message: message,
        notificationType: notificationType,
        isRead: isRead ?? this.isRead,
        actionUrl: actionUrl,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
        expiresAt: expiresAt,
        priority: priority,
      );
}

class NotificationType {
  static const String info = 'INFO';
  static const String warning = 'WARNING';
  static const String success = 'SUCCESS';
  static const String error = 'ERROR';
  static const String order = 'ORDER';
  static const String payment = 'PAYMENT';
  static const String inventory = 'INVENTORY';
  static const String system = 'SYSTEM';
  static const String procurement = 'PROCUREMENT';
  static const String customer = 'CUSTOMER';
  static const String subscription = 'SUBSCRIPTION';
  static const String security = 'SECURITY';
}
