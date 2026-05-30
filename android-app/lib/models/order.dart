class Order {
  final int? id;
  final String productName;
  final double? productPrice;
  final String deliveryAddress;
  final bool isFiado;
  String status;
  final String waMessage;
  String? comment;
  final String requestedAt;
  final String? deliveredAt;
  final String? customerName;
  final String? customerPhone;
  bool pendingSync;

  Order({
    this.id, required this.productName, this.productPrice,
    required this.deliveryAddress, required this.isFiado,
    required this.status, required this.waMessage, this.comment,
    required this.requestedAt, this.deliveredAt,
    this.customerName, this.customerPhone, this.pendingSync = false,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'],
    productName: j['product_name'] ?? '',
    productPrice: (j['product_price'] as num?)?.toDouble(),
    deliveryAddress: j['delivery_address'] ?? '',
    isFiado: j['is_fiado'] == 1 || j['is_fiado'] == true,
    status: j['status'] ?? 'pending',
    waMessage: j['wa_message'] ?? '',
    comment: j['comment'],
    requestedAt: j['requested_at'] ?? '',
    deliveredAt: j['delivered_at'],
    customerName: j['customer_name'],
    customerPhone: j['phone'],
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'product_name': productName, 'product_price': productPrice,
    'delivery_address': deliveryAddress, 'is_fiado': isFiado ? 1 : 0,
    'status': status, 'wa_message': waMessage, 'comment': comment,
    'requested_at': requestedAt, 'delivered_at': deliveredAt,
    'customer_name': customerName, 'customer_phone': customerPhone,
    'pending_sync': pendingSync ? 1 : 0,
  };
}
