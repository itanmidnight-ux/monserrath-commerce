import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';

class OrderDetailModal extends StatelessWidget {
  final Order order;
  final ValueChanged<String> onComment;
  final VoidCallback onDeliver;

  const OrderDetailModal({
    super.key, required this.order,
    required this.onComment, required this.onDeliver,
  });

  Widget _row(IconData icon, String label, String value, {Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color ?? const Color(0xFF2E7D32)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, color: color ?? Colors.black87)),
        ])),
      ]),
    );

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(order.requestedAt)?.toLocal();
    final dateStr = date != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'N/A';

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5,
      maxChildSize: 0.95, expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(controller: ctrl, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          Text('Detalle del Pedido',
            style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          _row(Icons.person, 'Cliente',
            order.customerName ?? order.customerPhone ?? 'N/A'),
          _row(Icons.inventory_2, 'Producto', order.productName),
          if (order.productPrice != null)
            _row(Icons.attach_money, 'Precio',
              '\$${NumberFormat('#,###', 'es_CO').format(order.productPrice)}'),
          _row(Icons.location_on, 'Dirección', order.deliveryAddress),
          _row(Icons.access_time, 'Solicitado', dateStr),
          if (order.isFiado)
            _row(Icons.warning_amber, 'Pago', 'FIADO', color: Colors.orange),
          const Divider(height: 24),
          const Text('Mensaje original WhatsApp',
            style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCF8C6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(order.waMessage,
              style: const TextStyle(fontSize: 13)),
          ),
          if (order.comment != null) ...[
            const SizedBox(height: 16),
            const Text('Comentario',
              style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(order.comment!,
              style: TextStyle(color: Colors.grey.shade700)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () { onDeliver(); Navigator.pop(context); },
            icon: const Icon(Icons.check_circle),
            label: const Text('Marcar como ENTREGADO'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ]),
      ),
    );
  }
}
