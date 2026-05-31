import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class SmartFaceScanner extends StatefulWidget {
  final ValueChanged<File> onCapture;
  final VoidCallback onCancel;

  const SmartFaceScanner({
    super.key,
    required this.onCapture,
    required this.onCancel,
  });

  @override
  State<SmartFaceScanner> createState() => _SmartFaceScannerState();
}

class _SmartFaceScannerState extends State<SmartFaceScanner> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInit = false;
  String? _errorMsg;
  bool _isCapturing = false;
  
  // ML Kit Face Detector
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  bool _isProcessingFrame = false;
  
  CameraDescription? _cameraDescription;
  
  String _hintText = 'Đưa khuôn mặt vào trong khung';
  Color _maskColor = Colors.black.withValues(alpha: 0.75);
  Color _borderColor = Colors.white70;

  // Auto-capture counter
  int _validFramesCount = 0;
  static const int _requiredValidFrames = 8; // approx 1-2 seconds at 10fps processing
  
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
      _cameraDescription = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _cameraDescription!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInit = true);
        _controller!.startImageStream(_processCameraImage);
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
    try {
      _controller?.stopImageStream();
    } catch (_) {
      // Camera stream may not have been started yet
    }
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
  
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null || _cameraDescription == null) return null;
    
    final sensorOrientation = _cameraDescription!.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0; // simplify for front camera portrait
      if (_cameraDescription!.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      _validateFaces(faces, image.width.toDouble(), image.height.toDouble());
      
    } catch (e) {
      // ignore ML kit errors silently
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _validateFaces(List<Face> faces, double imgWidth, double imgHeight) {
    if (faces.isEmpty) {
      _updateState('Đưa khuôn mặt vào trong khung', Colors.white70, 0);
      return;
    }

    if (faces.length > 1) {
      _updateState('Chỉ một khuôn mặt trong khung', Colors.red, 0);
      return;
    }

    final face = faces.first;
    
    // Check face orientation (Yaw and Roll)
    if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 15) {
      _updateState('Nhìn thẳng vào màn hình', Colors.orange, 0);
      return;
    }
    if (face.headEulerAngleZ != null && face.headEulerAngleZ!.abs() > 15) {
      _updateState('Giữ đầu thẳng', Colors.orange, 0);
      return;
    }

    // Check if eyes are open
    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      if (face.leftEyeOpenProbability! < 0.4 || face.rightEyeOpenProbability! < 0.4) {
        _updateState('Vui lòng mở mắt', Colors.orange, 0);
        return;
      }
    }

    // Check face size — must be large enough for quality embedding
    final box = face.boundingBox;
    final faceWidthRatio = box.width / imgWidth;
    final faceHeightRatio = box.height / imgHeight;

    if (faceWidthRatio < 0.2 || faceHeightRatio < 0.2) {
      _updateState('Tiến lại gần hơn', Colors.orange, 0);
      return;
    }
    if (faceWidthRatio > 0.85) {
      _updateState('Lùi ra xa hơn một chút', Colors.orange, 0);
      return;
    }

    // Check face is roughly centered (within center 60% of frame)
    final faceCenterX = (box.left + box.right) / 2 / imgWidth;
    final faceCenterY = (box.top + box.bottom) / 2 / imgHeight;
    if ((faceCenterX - 0.5).abs() > 0.25 || (faceCenterY - 0.5).abs() > 0.25) {
      _updateState('Đưa mặt vào giữa khung', Colors.orange, 0);
      return;
    }

    // Face is good!
    _updateState('Giữ nguyên...', Colors.green, _validFramesCount + 1);

    if (_validFramesCount >= _requiredValidFrames) {
      _takePicture();
    }
  }

  void _updateState(String hint, Color borderColor, int validFrames) {
    if (!mounted || _isCapturing) return;
    
    if (_hintText != hint || _borderColor != borderColor || _validFramesCount != validFrames) {
      setState(() {
        _hintText = hint;
        _borderColor = borderColor;
        _validFramesCount = validFrames;
        if (validFrames > 0) {
          _maskColor = Colors.green.withValues(alpha: 0.2);
        } else {
          _maskColor = Colors.black.withValues(alpha: 0.75);
        }
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _hintText = 'Đang phân tích...';
      _borderColor = Colors.blue;
      _maskColor = Colors.black.withValues(alpha: 0.75);
    });

    try {
      await _controller!.stopImageStream();
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
                _maskColor,
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: _borderColor, width: 3),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(size.width * 0.75, size.height * 0.5),
                      ),
                    ),
                  ),
                  if (!_isCapturing && _validFramesCount == 0) 
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
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _hintText,
                key: ValueKey<String>(_hintText),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _borderColor == Colors.white70 ? Colors.white : _borderColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ),
          
          if (_isCapturing)
            const Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }
}
