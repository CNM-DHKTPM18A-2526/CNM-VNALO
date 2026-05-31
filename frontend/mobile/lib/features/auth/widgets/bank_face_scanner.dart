import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class BankFaceScanner extends StatefulWidget {
  final ValueChanged<File> onCapture;
  final VoidCallback onCancel;

  const BankFaceScanner({
    super.key,
    required this.onCapture,
    required this.onCancel,
  });

  @override
  State<BankFaceScanner> createState() => _BankFaceScannerState();
}

class _BankFaceScannerState extends State<BankFaceScanner> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInit = false;
  String? _errorMsg;
  bool _isCapturing = false;

  late AnimationController _animationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Không thể kết nối với Camera.');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      widget.onCapture(File(xFile.path));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _errorMsg = 'Lỗi khi chụp ảnh.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: Colors.white, onPressed: widget.onCancel),
        ),
        body: Center(
          child: Text(_errorMsg!, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );
    }

    if (!_isInit || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Positioned.fill(
            child: Transform.scale(
              scale: 1.0,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1 / _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Dark Overlay with Oval Hole
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.75),
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: size.width * 0.75,
                      height: size.height * 0.5,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(size.width * 0.75, size.height * 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Oval Border and Scanning Line
          Center(
            child: SizedBox(
              width: size.width * 0.75,
              height: size.height * 0.5,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(size.width * 0.75, size.height * 0.5),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: (size.height * 0.5) * _scanAnimation.value,
                        left: 0,
                        right: 0,
                        child: child!,
                      );
                    },
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0068FF),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0068FF).withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hints and Buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: widget.onCancel,
            ),
          ),
          const Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Text(
              'Đưa khuôn mặt vào trong khung',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: _isCapturing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
