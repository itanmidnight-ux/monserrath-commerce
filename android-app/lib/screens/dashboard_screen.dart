import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/order_card.dart';
import '../widgets/company_header.dart';
import 'products_screen.dart';
import 'messages_screen.dart';

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

  static const _titles = ['Pedidos Activos', 'Productos', 'Mensajes'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      appBar: CompanyHeader(
        pageTitle: _titles[_tab],
        actions: [
          if (!provider.isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Sin conexión',
                child: Icon(Icons.wifi_off, color: Color(0xFFD4800A), size: 20),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => provider.refreshAll(),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: [
        // PEDIDOS
        RefreshIndicator(
          onRefresh: provider.refreshOrders,
          color: const Color(0xFF2D5016),
          child: provider.loading
            ? const Center(child: CircularProgressIndicator(
                color: Color(0xFF2D5016)))
            : provider.orders.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 100),
                  Column(children: [
                    Text('📦', style: TextStyle(fontSize: 64)),
                    SizedBox(height: 12),
                    Text('No hay pedidos activos',
                      style: TextStyle(color: Colors.grey, fontSize: 16,
                        fontWeight: FontWeight.w500)),
                    SizedBox(height: 4),
                    Text('Desliza para actualizar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        // PRODUCTOS
        const ProductsScreen(),
        // MENSAJES
        const MessagesScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD4ECB8),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: provider.orders.isNotEmpty,
              label: Text('${provider.orders.length}'),
              backgroundColor: const Color(0xFFD4800A),
              child: const Icon(Icons.dashboard_rounded)),
            selectedIcon: const Icon(Icons.dashboard_rounded,
              color: Color(0xFF2D5016)),
            label: 'Pedidos'),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded,
              color: Color(0xFF2D5016)),
            label: 'Productos'),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded,
              color: Color(0xFF2D5016)),
            label: 'Mensajes'),
        ],
      ),
    );
  }
}
