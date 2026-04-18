import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

class AiChatBoard extends StatelessWidget {
  final VoidCallback onClose;

  const AiChatBoard({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (aiProvider.aiResponse.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          maxWidth: 300,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? DarkColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: (isDarkMode ? DarkColors.primary : AppColors.primary).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.appBarGradient,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VNALO AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose,
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: MarkdownBody(
                      data: aiProvider.aiResponse,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
