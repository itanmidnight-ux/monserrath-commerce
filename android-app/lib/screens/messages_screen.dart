import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _convs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _convs = await ApiService.getConversations();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) return DateFormat('HH:mm').format(dt);
    return DateFormat('dd/MM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EE),
      body: _loading
        ? const Center(child: CircularProgressIndicator(
            color: Color(0xFF2D5016)))
        : _convs.isEmpty
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('💬', style: TextStyle(fontSize: 56)),
                SizedBox(height: 12),
                Text('Sin conversaciones aún',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
                SizedBox(height: 4),
                Text('Los mensajes de WhatsApp aparecerán aquí',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF2D5016),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _convs.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1, indent: 72, endIndent: 16),
                itemBuilder: (ctx, i) {
                  final c = _convs[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2D5016),
                      radius: 24,
                      child: Text(
                        c.displayName.isNotEmpty
                          ? c.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Text(
                      c.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      c.lastMsg ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_formatTime(c.lastAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.unread > 0
                              ? const Color(0xFF2D5016) : Colors.grey,
                          )),
                        if (c.unread > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D5016),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${c.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              )),
                          ),
                        ],
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(ctx, MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          phone: c.phone,
                          name: c.displayName,
                        ),
                      ));
                      _load();
                    },
                  );
                },
              ),
            ),
    );
  }
}
