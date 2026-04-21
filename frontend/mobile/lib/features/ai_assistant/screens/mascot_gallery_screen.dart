import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/models/mascot_metadata.dart';
import 'package:vnalo_mobile/features/ai_assistant/providers/ai_assistant_provider.dart';
import 'package:vnalo_mobile/features/ai_assistant/widgets/ai_robot_avatar.dart';

class MascotGalleryScreen extends StatefulWidget {
  const MascotGalleryScreen({super.key});

  @override
  State<MascotGalleryScreen> createState() => _MascotGalleryScreenState();
}

class _MascotGalleryScreenState extends State<MascotGalleryScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final mascots = MascotMetadata.defaultMascots;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF050913) : const Color(0xFFF3F7FF),
      appBar: AppBar(
        title: const Text('Mascot Gallery'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Text(
              'Ưu tiên robot 2D cho độ ổn định gesture và độ mượt 60fps. 3D vẫn giữ làm tuỳ chọn mở rộng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: mascots.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final mascot = mascots[index];
                final isSelected = provider.currentMascot.id == mascot.id;
                final isCurrentPage = _currentPage == index;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isCurrentPage ? 20 : 50,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF121A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color:
                          isSelected ? Colors.blueAccent : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child:
                            mascot.uses3dModel
                                ? O3D(
                                  src: mascot.modelUrl!,
                                  autoPlay: true,
                                  cameraOrbit: CameraOrbit(0, 75, 105),
                                  disableZoom: true,
                                )
                                : const Center(
                                  child: AiRobotAvatar(
                                    state: AiState.idle,
                                    emotion: 'joyful',
                                    size: 190,
                                  ),
                                ),
                      ),
                      if (mascot.recommended)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.45),
                              ),
                            ),
                            child: const Text(
                              'Khuyến nghị mặc định',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              mascot.name,
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mascot.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed:
                                  isSelected
                                      ? null
                                      : () => provider.setMascot(mascot),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isSelected
                                        ? Colors.grey
                                        : Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                isSelected
                                    ? 'Đang chọn'
                                    : mascot.uses3dModel
                                    ? 'Dùng bản 3D'
                                    : 'Dùng bản 2D',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
