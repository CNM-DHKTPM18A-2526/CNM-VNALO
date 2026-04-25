enum MascotRenderMode { premium2d }

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

  bool get uses3dModel => false;

  static List<MascotMetadata> get defaultMascots => [
    MascotMetadata(
      id: 'robot_core_2d',
      name: 'VNALO Core',
      description:
          'Robot trợ lý 2D cao cấp, tối ưu độ mượt và độ ổn định cảm ứng.',
      renderMode: MascotRenderMode.premium2d,
      recommended: true,
    ),
  ];
}
