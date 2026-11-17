import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/chat_message.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/responsive_page_header.dart';
import '../../core/components/skeleton_loader.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  String? _selectedChatId;
  String? _selectedCustomerName;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendReply(FirestoreService fs, AuthService auth) async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedChatId == null) return;

    _replyController.clear();
    final adminUser = auth.currentUser;

    final msg = ChatMessage(
      id: '',
      conversationId: _selectedChatId!,
      senderId: adminUser?.uid ?? 'admin',
      senderName: adminUser?.fullName.isNotEmpty == true ? adminUser!.fullName : 'PRY-ARR Admin',
      senderRole: 'admin',
      recipientId: _selectedChatId!.replaceAll('support_', ''),
      text: text,
      timestamp: DateTime.now(),
    );

    await fs.sendChatMessage(_selectedChatId!, msg);

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
    final fs = Provider.of<FirestoreService>(context);
    final auth = Provider.of<AuthService>(context);
    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: ResponsivePageHeader(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Customer Support Messages',
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: fs.streamActiveConversationsAdmin(type: 'support'),
                    builder: (context, snapshot) {
                      if (_isLoading || snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: 4,
                          itemBuilder: (_, __) => const SkeletonCard(),
                        );
                      }
                      final chats = snapshot.data ?? [];

                      if (chats.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mark_email_read_outlined, size: 64, color: p.faint),
                              const SizedBox(height: 12),
                              Text('No active customer inquiries yet.', style: ts(p.faint, 16)),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;

                          Widget chatThreadWidget = _selectedChatId == null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_outlined, size: 48, color: p.faint),
                                      const SizedBox(height: 12),
                                      Text('Select a customer conversation on the left to reply.', style: ts(p.faint, 14)),
                                    ],
                                  ),
                                )
                              : Container(
                                  margin: EdgeInsets.fromLTRB(isWide ? 10 : 0, 0, isWide ? 20 : 0, isWide ? 20 : 0),
                                  child: Glass(
                                    radius: 24,
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            if (!isWide) ...[
                                              IconButton(
                                                icon: Icon(Icons.arrow_back_rounded, color: p.text),
                                                onPressed: () => setState(() => _selectedChatId = null),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            const CircleAvatar(
                                              backgroundColor: hwOrange,
                                              child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _selectedCustomerName ?? "Customer",
                                                style: ts(p.text, 16, FontWeight.w800),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Divider(color: p.line, height: 20),
                                        Expanded(
                                          child: StreamBuilder<List<ChatMessage>>(
                                            stream: fs.streamChatMessages(_selectedChatId!),
                                            builder: (context, msgSnap) {
                                              if (_isLoading || msgSnap.connectionState == ConnectionState.waiting) {
                                                return ListView.builder(
                                                  padding: const EdgeInsets.all(24),
                                                  itemCount: 4,
                                                  itemBuilder: (_, __) => const SkeletonCard(),
                                                );
                                              }
                                              final messages = msgSnap.data ?? [];

                                              return ListView.builder(
                                                controller: _scrollController,
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                itemCount: messages.length,
                                                itemBuilder: (context, idx) {
                                                  final m = messages[idx];
                                                  final isAdmin = m.senderRole == 'admin' || m.senderRole == 'staff';

                                                  return Align(
                                                    alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                                                    child: Container(
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: isAdmin
                                                            ? hwOrange
                                                            : (p.dark ? Colors.white12 : const Color(0xFFEFE8E0)),
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: isAdmin ? null : Border.all(color: p.line),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            '${m.senderName} (${m.senderRole.toUpperCase()})',
                                                            style: ts(isAdmin ? Colors.white70 : (p.dark ? hwYellow : hwRust), 10, FontWeight.w800),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            m.text,
                                                            style: ts(isAdmin ? Colors.white : p.text, 13, FontWeight.w600),
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
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _replyController,
                                                style: ts(p.text, 14),
                                                decoration: InputDecoration(
                                                  hintText: 'Type your official reply...',
                                                  hintStyle: ts(p.faint, 13),
                                                  filled: true,
                                                  fillColor: p.fill,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
                                                ),
                                                onSubmitted: (_) => _sendReply(fs, auth),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () => _sendReply(fs, auth),
                                              style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white, minimumSize: const Size(54, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                              child: const Icon(Icons.send_rounded),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                          Widget chatListWidget = ListView.builder(
                            padding: EdgeInsets.fromLTRB(isWide ? 20 : 16, 0, isWide ? 10 : 16, 20),
                            itemCount: chats.length,
                            itemBuilder: (context, index) {
                              final chat = chats[index];
                              final chatId = chat['chatId'] as String;
                              final lastMsg = chat['lastMessage'] ?? 'Inquiry received';
                              final lastSender = chat['lastSender'] ?? 'Customer';
                              final isSelected = chatId == _selectedChatId;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedChatId = chatId;
                                      _selectedCustomerName = lastSender;
                                    });
                                  },
                                  child: Glass(
                                    radius: 18,
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: isSelected ? hwOrange : p.fill,
                                          child: Icon(Icons.person_rounded, color: isSelected ? Colors.white : p.text, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(lastSender, style: ts(p.text, 13, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text(lastMsg, style: ts(p.faint, 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );

                          if (!isWide) {
                            return _selectedChatId == null ? chatListWidget : chatThreadWidget;
                          }

                          return Row(
                            children: [
                              SizedBox(width: 280, child: chatListWidget),
                              Expanded(child: chatThreadWidget),
                            ],
                          );
                        },
                      );
                    },
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
