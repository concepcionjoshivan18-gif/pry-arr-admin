import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/chat_message.dart';
import '../../core/theme/hardware_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  final String? initialChatId;
  const HelpSupportScreen({super.key, this.initialChatId});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I place an order for hardware tools & materials?',
      'answer': 'Browse our Shop Catalog, select the item and desired quantity (you can type exact amounts or use + / -), then tap "ADD TO CART" or "BUY NOW" to proceed to Checkout.',
    },
    {
      'question': 'What payment methods are available?',
      'answer': 'We support Cash on Delivery (COD), GCash, and Credit/Debit Cards. You can also redeem your accumulated Loyalty Points during checkout for instant discounts.',
    },
    {
      'question': 'How does delivery work and what are the shipping fees?',
      'answer': 'Standard Delivery is FREE for orders amounting to ₱500 and above (₱50 fee for smaller orders). Express Delivery is available for ₱150 for same-day priority dispatch.',
    },
    {
      'question': 'How can I contact my delivery rider / driver?',
      'answer': 'When your order status becomes "Out for Delivery", open "My Orders" from your Account menu and tap the "Contact Rider" button to message or call your assigned driver directly.',
    },
    {
      'question': 'What is the Return and Exchange Policy?',
      'answer': 'Items can be exchanged within 7 days from delivery provided they are in original condition with the official receipt. Custom-cut materials (pipes, wires, glass) are non-returnable unless defective.',
    },
    {
      'question': 'How do Loyalty Points work?',
      'answer': 'You automatically earn 1 point for every ₱10 spent. Every 10 points can be redeemed for a ₱2 discount on future orders!',
    },
  ];

  String? _conversationId;
  bool _isLoadingConv = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialChatId != null) {
      _tabController.index = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initConversation();
  }

  void _initConversation() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final userId = auth.currentUser?.uid ?? 'guest';

    String convId;
    if (widget.initialChatId != null) {
      convId = widget.initialChatId!;
    } else {
      convId = await fs.getOrCreateConversation(type: 'support', customerId: userId);
    }
    if (mounted) {
      setState(() {
        _conversationId = convId;
        _isLoadingConv = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String userId, String userName) async {
    if (_conversationId == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    final fs = Provider.of<FirestoreService>(context, listen: false);

    final msg = ChatMessage(
      id: '',
      conversationId: _conversationId!,
      senderId: userId,
      senderName: userName,
      senderRole: 'customer',
      recipientId: 'admin_staff',
      text: text,
      timestamp: DateTime.now(),
    );

    await fs.sendChatMessage(_conversationId!, msg);

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
    final userId = auth.currentUser?.uid ?? 'guest';
    final userName = auth.currentUser?.fullName.isNotEmpty == true ? auth.currentUser!.fullName : 'Customer';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                // Top App Bar
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
                      Text('Help & Support', style: ts(p.text, 22, FontWeight.w800)),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.fill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.line),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: hwOrange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: p.faint,
                    labelStyle: ts(Colors.white, 13, FontWeight.w700),
                    tabs: const [
                      Tab(text: 'FAQ & Questions'),
                      Tab(text: 'Live Chat Support'),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: FAQ Section
                      ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _faqs.length,
                        itemBuilder: (context, index) {
                          final item = _faqs[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Glass(
                              radius: 20,
                              child: ExpansionTile(
                                shape: const Border(),
                                title: Text(item['question']!, style: ts(p.text, 14, FontWeight.w700)),
                                leading: Icon(Icons.help_outline_rounded, color: hwOrange, size: 20),
                                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  Text(
                                    item['answer']!,
                                    style: ts(p.sub, 13).copyWith(height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // TAB 2: Live Support Chat
                      _isLoadingConv || _conversationId == null
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                Expanded(
                                  child: StreamBuilder<List<ChatMessage>>(
                                    stream: fs.streamChatMessages(_conversationId!),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      final messages = snapshot.data ?? [];

                                      if (messages.isEmpty) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(32.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.headset_mic_outlined, size: 54, color: p.faint),
                                                const SizedBox(height: 12),
                                                Text('Need assistance?', style: ts(p.text, 18, FontWeight.w800)),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Send a message below and PRY-ARR Admin / Staff will reply shortly.',
                                                  textAlign: TextAlign.center,
                                                  style: ts(p.faint, 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
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
                                                borderRadius: BorderRadius.circular(18).copyWith(
                                                  bottomRight: isMe ? Radius.zero : const Radius.circular(18),
                                                  bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                                                ),
                                                border: isMe ? null : Border.all(color: p.line),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (!isMe)
                                                    Text(
                                                      '${msg.senderName} (${msg.senderRole.toUpperCase()})',
                                                      style: ts(p.dark ? hwYellow : hwRust, 10, FontWeight.w800),
                                                    ),
                                                  Text(
                                                    msg.text,
                                                    style: ts(isMe ? Colors.white : p.text, 13, FontWeight.w500),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
                                                      DateFormat('HH:mm').format(msg.timestamp),
                                                      style: ts(isMe ? Colors.white60 : p.faint, 9),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),

                                // Message Input Bar
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  child: Glass(
                                    radius: 24,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _messageController,
                                            style: ts(p.text, 14),
                                            decoration: InputDecoration(
                                              hintText: 'Type your message to Admin / Staff...',
                                              hintStyle: ts(p.faint, 13),
                                              border: InputBorder.none,
                                            ),
                                            onSubmitted: (_) => _sendMessage(userId, userName),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.send_rounded, color: hwOrange),
                                          onPressed: () => _sendMessage(userId, userName),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
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
