import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/call/providers/call_provider.dart';
import 'package:vnalo_mobile/features/call/screens/call_screen.dart';

class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, call, child) {
        if (call.state != CallState.ringing || call.localStream != null) {
          // call.localStream != null means we are the caller or we already accepted
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Cuộc gọi đến',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          'Cần trả lời...', // TODO: Get name
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => call.rejectCall(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      call.acceptCall().then((_) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CallScreen(
                              remoteUserName: 'Người gọi',
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
