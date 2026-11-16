import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/order.dart';
import '../../core/models/chat_message.dart';
import '../../core/theme/hardware_theme.dart';

class DeliveryChatScreen extends StatefulWidget {
  final OrderModel order;
  const DeliveryChatScreen({super.key, required this.order});

  @override
  State<DeliveryChatScreen> createState() => _DeliveryChatScreenState();
}

class _DeliveryChatScreenState extends State<DeliveryChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final userId = auth.currentUser?.uid ?? 'guest';

    final convId = await fs.getOrCreateConversation(
      type: 'delivery',
      customerId: widget.order.customerId,
      orderId: widget.order.id,
    );

    if (mounted) {
      setState(() {
        _conversationId = convId;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_conversationId == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final auth = Provider.of<AuthService>(context, listen: false);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final user = auth.currentUser;

    final msg = ChatMessage(
      id: '',
      conversationId: _conversationId!,
      senderId: user?.uid ?? 'customer',
      senderName: user?.fullName ?? 'Customer',
      senderRole: 'customer',
      recipientId: 'driver',
      text: text,
      timestamp: DateTime.now(),
      orderId: widget.order.id,
    );

    try {
      await fs.sendChatMessage(_conversationId!, msg);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final auth = Provider.of<AuthService>(context);
    final fs = Provider.of<FirestoreService>(context);
    final userId = auth.currentUser?.uid ?? 'customer';
    final isClosed = widget.order.status == 'completed' || widget.order.status == 'cancelled';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Glass(
                        radius: 22,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: Icon(Icons.arrow_back_rounded, color: p.text, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver Delivery Chat', style: ts(p.text, 18, FontWeight.w800)),
                            Text('Order #${widget.order.id.substring(0, math.min(5, widget.order.id.length))}', style: ts(p.faint, 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isClosed)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Text('This delivery chat is closed (order completed or cancelled).', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                Expanded(
                  child: _isLoading || _conversationId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<ChatMessage>>(
                          stream: fs.streamChatMessages(_conversationId!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final messages = snapshot.data ?? [];
                            if (messages.isEmpty) {
                              return Center(child: Text('No messages with your driver yet.', style: ts(p.faint, 14)));
                            }
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe = msg.senderId == userId;
                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe ? hwOrange : p.fill,
                                      borderRadius: BorderRadius.circular(18),
                                      border: isMe ? null : Border.all(color: p.line),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Text(msg.senderName, style: ts(p.dark ? hwYellow : hwRust, 10, FontWeight.w800)),
                                        Text(msg.text, style: ts(isMe ? Colors.white : p.text, 13, FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                if (!isClosed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Glass(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                hintText: 'Message your rider / driver...',
                                hintStyle: ts(p.faint, 13),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send_rounded, color: hwOrange),
                            onPressed: _sendMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
