import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import 'order_detail_modal.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onDeliver;
  final ValueChanged<String> onComment;

  const OrderCard({
    super.key, required this.order,
    required this.onDeliver, required this.onComment,
  });

  bool get _isOverdue {
    final date = DateTime.tryParse(order.requestedAt);
    if (date == null) return false;
    return DateTime.now().difference(date).inDays >= 1;
  }

  String get _timeLabel {
    final date = DateTime.tryParse(order.requestedAt);
    if (date == null) return '';
    return DateFormat('dd/MM HH:mm').format(date.toLocal());
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => OrderDetailModal(
        order: order, onComment: onComment, onDeliver: onDeliver),
    );
  }

  void _showLongPressMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.comment),
          title: const Text('Dejar comentario'),
          onTap: () {
            Navigator.pop(context);
            _showCommentDialog(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Ver detalle / mensaje WA'),
          onTap: () { Navigator.pop(context); _showDetail(context); },
        ),
        ListTile(
          leading: const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
          title: const Text('Marcar entregado'),
          onTap: () { Navigator.pop(context); onDeliver(); },
        ),
      ])),
    );
  }

  void _showCommentDialog(BuildContext context) {
    final ctrl = TextEditingController(text: order.comment);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Comentario'),
        content: TextField(
          controller: ctrl, maxLines: 3,
          decoration: const InputDecoration(hintText: 'Escribe un comentario...')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
          FilledButton(
            onPressed: () { onComment(ctrl.text); Navigator.pop(context); },
            child: const Text('Guardar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Slidable(
        endActionPane: ActionPane(motion: const DrawerMotion(), children: [
          SlidableAction(
            onPressed: (_) => onDeliver(),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            icon: Icons.check_circle_rounded,
            label: 'ENTREGADO',
            borderRadius: BorderRadius.circular(16),
          ),
        ]),
        startActionPane: ActionPane(motion: const DrawerMotion(), children: [
          SlidableAction(
            onPressed: (_) => onDeliver(),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            icon: Icons.check_circle_rounded,
            label: 'ENTREGADO',
            borderRadius: BorderRadius.circular(16),
          ),
        ]),
        child: GestureDetector(
          onLongPress: () => _showLongPressMenu(context),
          onTap: () => _showDetail(context),
          child: Card(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  order.customerName ?? order.customerPhone ?? 'Cliente',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                if (order.isFiado) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12)),
                  child: const Text('FIADO',
                    style: TextStyle(color: Colors.orange, fontSize: 11,
                      fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(child: Text(order.productName,
                  style: const TextStyle(fontSize: 14))),
                if (order.productPrice != null)
                  Text(
                    '\$${NumberFormat('#,###', 'es_CO').format(order.productPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(order.deliveryAddress,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.access_time, size: 14,
                  color: _isOverdue ? Colors.red : Colors.grey),
                const SizedBox(width: 4),
                Text(_timeLabel, style: TextStyle(
                  fontSize: 12,
                  color: _isOverdue ? Colors.red : Colors.grey.shade600,
                  fontWeight: _isOverdue ? FontWeight.bold : FontWeight.normal)),
                if (_isOverdue) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)),
                    child: const Text('PENDIENTE',
                      style: TextStyle(color: Colors.red, fontSize: 10,
                        fontWeight: FontWeight.bold))),
                ],
                if (order.comment != null) ...[
                  const Spacer(),
                  const Icon(Icons.comment, size: 14, color: Colors.grey),
                ],
              ]),
            ]),
          )),
        ),
      ),
    );
  }
}
