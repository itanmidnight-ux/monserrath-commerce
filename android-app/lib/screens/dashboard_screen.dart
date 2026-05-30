import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/order_card.dart';
import 'products_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tab == 0 ? 'Pedidos Activos' : 'Productos',
          style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (!provider.isOnline)
            const Tooltip(
              message: 'Sin conexión',
              child: Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.wifi_off, color: Colors.orange))),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshAll()),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        RefreshIndicator(
          onRefresh: provider.refreshOrders,
          child: provider.loading
            ? const Center(child: CircularProgressIndicator())
            : provider.orders.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Column(children: [
                    Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No hay pedidos activos',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('Desliza hacia abajo para actualizar',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: provider.orders.length,
                  itemBuilder: (ctx, i) {
                    final order = provider.orders[i];
                    return OrderCard(
                      key: ValueKey(order.id),
                      order: order,
                      onDeliver: () => provider.deliverOrder(order.id!),
                      onComment: (c) => provider.addComment(order.id!, c),
                    );
                  }),
        ),
        const ProductsScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: provider.orders.isNotEmpty,
              label: Text('${provider.orders.length}'),
              child: const Icon(Icons.dashboard_rounded)),
            label: 'Pedidos'),
          const NavigationDestination(
            icon: Icon(Icons.inventory_rounded),
            label: 'Productos'),
        ],
      ),
    );
  }
}
