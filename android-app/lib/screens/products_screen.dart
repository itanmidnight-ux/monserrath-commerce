import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final Set<int> _selected = {};

  void _showAddProduct() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final aliasCtrl = TextEditingController();
    final aliases = <String>[];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nuevo Producto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio', border: OutlineInputBorder(),
                prefixText: '\$'),
              keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: aliasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agregar apodo/alias',
                  border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                onPressed: () {
                  if (aliasCtrl.text.trim().isNotEmpty) {
                    setModal(() {
                      aliases.add(aliasCtrl.text.trim());
                      aliasCtrl.clear();
                    });
                  }
                }),
            ]),
            if (aliases.isNotEmpty) Wrap(spacing: 6, children: aliases
              .map((a) => Chip(
                label: Text(a),
                onDeleted: () => setModal(() => aliases.remove(a)),
              )).toList()),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () async {
                final price = double.tryParse(
                  priceCtrl.text.replaceAll(',', '').replaceAll('.', ''));
                if (nameCtrl.text.trim().isEmpty || price == null) return;
                Navigator.pop(ctx);
                await context.read<AppProvider>().createProduct(
                  Product(name: nameCtrl.text.trim(),
                    aliases: List.from(aliases), price: price));
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32)),
              child: const Text('Guardar Producto'),
            )),
          ]),
        ),
      ),
    );
  }

  void _showActions(List<Product> selected) {
    final provider = context.read<AppProvider>();
    showModalBottomSheet(context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(12),
          child: Text('${selected.length} producto(s) seleccionado(s)',
            style: const TextStyle(fontWeight: FontWeight.bold))),
        ListTile(
          leading: const Icon(Icons.visibility_off, color: Colors.orange),
          title: const Text('Marcar no disponible'),
          onTap: () async {
            Navigator.pop(context);
            for (final p in selected) {
              await provider.updateProduct(p.id!, {'available': 0});
            }
            setState(() => _selected.clear());
          },
        ),
        ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: const Text('Favorito'),
          onTap: () async {
            Navigator.pop(context);
            for (final p in selected) {
              await provider.updateProduct(p.id!, {'favorite': 1});
            }
            setState(() => _selected.clear());
          },
        ),
        ListTile(
          leading: const Icon(Icons.money_off, color: Colors.red),
          title: const Text('NO SE FÍA'),
          onTap: () async {
            Navigator.pop(context);
            for (final p in selected) {
              await provider.updateProduct(p.id!, {'no_fiado': 1});
            }
            setState(() => _selected.clear());
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(context);
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Eliminar'),
                content: Text('¿Eliminar ${selected.length} producto(s)?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                  FilledButton(onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar')),
                ],
              ),
            );
            if (confirm == true) {
              for (final p in selected) await provider.deleteProduct(p.id!);
              setState(() => _selected.clear());
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.close),
          title: const Text('Cancelar'),
          onTap: () { Navigator.pop(context); setState(() => _selected.clear()); },
        ),
      ])));
  }

  Widget _badge(String text, Color color) => Container(
    margin: const EdgeInsets.only(top: 4, right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(
      fontSize: 10, color: color, fontWeight: FontWeight.bold)),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final products = provider.products;

    return Scaffold(
      body: products.isEmpty
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sin productos. Agrega uno con +',
              style: TextStyle(color: Colors.grey)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final p = products[i];
              final isSelected = _selected.contains(p.id);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: GestureDetector(
                  onLongPress: () => setState(() {
                    if (isSelected) _selected.remove(p.id);
                    else _selected.add(p.id!);
                    if (_selected.isNotEmpty) {
                      _showActions(products
                        .where((x) => _selected.contains(x.id)).toList());
                    }
                  }),
                  child: Card(
                    color: isSelected ? Colors.green.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isSelected
                        ? const BorderSide(color: Colors.green, width: 2)
                        : BorderSide.none,
                    ),
                    child: Padding(padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : p.favorite
                            ? const Icon(Icons.star, color: Colors.amber, size: 20)
                            : const Icon(Icons.inventory_2_outlined,
                                color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15))),
                            Text(
                              '\$${NumberFormat('#,###', 'es_CO').format(p.price)}',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold)),
                          ]),
                          if (p.aliases.isNotEmpty)
                            Text(p.aliases.join(', '),
                              style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                          Row(children: [
                            if (!p.available) _badge('NO DISPONIBLE', Colors.orange),
                            if (p.noFiado) _badge('NO SE FÍA', Colors.red),
                          ]),
                        ])),
                      ])),
                  ),
                ),
              );
            }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
    );
  }
}
