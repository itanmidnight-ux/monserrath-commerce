class Message {
  final int? id;
  final String phone;
  final String? customerName;
  final String content;
  final String direction; // 'inbound' | 'outbound'
  final int sent;
  final String createdAt;

  Message({
    this.id,
    required this.phone,
    this.customerName,
    required this.content,
    required this.direction,
    this.sent = 0,
    required this.createdAt,
  });

  bool get isOutbound => direction == 'outbound';

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'],
    phone: j['phone'] ?? '',
    customerName: j['customer_name'],
    content: j['content'] ?? '',
    direction: j['direction'] ?? 'inbound',
    sent: j['sent'] ?? 0,
    createdAt: j['created_at'] ?? '',
  );
}

class Conversation {
  final String phone;
  final String? customerName;
  final String? lastMsg;
  final String? lastAt;
  final int unread;

  Conversation({
    required this.phone,
    this.customerName,
    this.lastMsg,
    this.lastAt,
    this.unread = 0,
  });

  String get displayName => customerName ?? phone;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    phone: j['phone'] ?? '',
    customerName: j['customer_name'],
    lastMsg: j['last_msg'],
    lastAt: j['last_at'],
    unread: j['unread'] ?? 0,
  );
}
