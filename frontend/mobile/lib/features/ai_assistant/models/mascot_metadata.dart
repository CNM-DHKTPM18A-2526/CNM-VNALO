class MascotMetadata {
  final String id;
  final String name;
  final String description;
  final String modelUrl;
  final double initialScale;
  final String previewImageUrl;

  MascotMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.modelUrl,
    this.initialScale = 1.0,
    required this.previewImageUrl,
  });

  static List<MascotMetadata> get defaultMascots => [
    MascotMetadata(
      id: 'astronaut',
      name: 'VNALO Explorer',
      description: 'Nhân vật thám hiểm không gian mặc định.',
      modelUrl: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
      previewImageUrl: 'https://modelviewer.dev/shared-assets/models/Astronaut.png',
    ),
    MascotMetadata(
      id: 'robot',
      name: 'VNALO Bot',
      description: 'Trợ lý Robot cơ bản siêu nhẹ.',
      modelUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.glb',
      previewImageUrl: 'https://modelviewer.dev/shared-assets/models/RobotExpressive.png',
    ),
  ];
}
