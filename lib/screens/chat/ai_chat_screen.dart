import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    // Stub functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng AI Chat đang được phát triển')),
    );
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lịch sử trò chuyện đang được phát triển')),
              );
            },
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử',
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tạo mới cuộc trò chuyện')),
              );
            },
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Cuộc trò chuyện mới',
          ),
          const SizedBox(width: 8),
        ],
        title: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundImage: AssetImage('lib/assets/ai_bot_avatar.png'),
              backgroundColor: Colors.transparent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trợ lý AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Luôn sẵn sàng hỗ trợ bạn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF0A8F47),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: const [
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Bắt đầu trò chuyện với Trợ lý AI\nCác tin nhắn sẽ hiển thị tại đây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              color: AppColors.bgCard,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn cho AI...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Image.asset('lib/assets/emoij_icon.png', width: 20, height: 20),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.bgInput,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {},
                    icon: Image.asset(
                      'lib/assets/microphone.png', 
                      width: 24, 
                      height: 24, 
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF168AFF),
                      padding: const EdgeInsets.all(10),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
