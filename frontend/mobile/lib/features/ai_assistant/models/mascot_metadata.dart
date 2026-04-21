enum MascotRenderMode { premium2d, model3d }

class MascotMetadata {
  final String id;
  final String name;
  final String description;
  final MascotRenderMode renderMode;
  final String? modelUrl;
  final double initialScale;
  final String? previewImageUrl;
  final bool recommended;

  MascotMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.renderMode,
    this.modelUrl,
    this.initialScale = 1.0,
    this.previewImageUrl,
    this.recommended = false,
  });

  bool get uses3dModel =>
      renderMode == MascotRenderMode.model3d && modelUrl != null;

  static List<MascotMetadata> get defaultMascots => [
    MascotMetadata(
      id: 'robot_core_2d',
      name: 'VNALO Core',
      description:
          'Robot trợ lý 2D cao cấp, tối ưu độ mượt và độ ổn định cảm ứng.',
      renderMode: MascotRenderMode.premium2d,
      recommended: true,
    ),
    MascotMetadata(
      id: 'robot_expressive_3d',
      name: 'VNALO Bot 3D',
      description: 'Robot 3D biểu cảm. Dùng khi ưu tiên hiệu ứng thị giác.',
      renderMode: MascotRenderMode.model3d,
      modelUrl:
          'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb',
      previewImageUrl:
          'https://modelviewer.dev/shared-assets/models/RobotExpressive.png',
    ),
    MascotMetadata(
      id: 'astronaut_legacy_3d',
      name: 'VNALO Explorer (Legacy)',
      description:
          'Mascot phi hành gia cũ. Giữ lại để tương thích cấu hình trước đây.',
      renderMode: MascotRenderMode.model3d,
      modelUrl: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
      previewImageUrl:
          'https://modelviewer.dev/shared-assets/models/Astronaut.png',
    ),
  ];
}
