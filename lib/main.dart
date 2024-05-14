import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

class Camera extends StatefulWidget {
  const Camera({Key? key}) : super(key: key);

  @override
  State<Camera> createState() {
    return _CameraState();
  }
}

void _logError(String code, String? message) {
  print('Error: $code${message == null ? '' : '\nError Messages: $message'}');
}

class _CameraState extends State<Camera>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? controller;
  XFile? imageFile;
  XFile? videoFile;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
  bool enableAudio = true;
  bool isRequestingPermission = false;
  bool isCameraPermissionRequestOngoing = false;
  CameraMode currentMode = CameraMode.photo;
  bool isButtonTapped = false;
  int _pointers = 0;
  bool isRecording = false;
  CameraMode selectedMode = CameraMode.photo;
  bool isFlashOn = false;
  List<String> texts = ['Floors', " Wall ", 'Ceiling'];
  int currentTextIndex = 0;

   void changeTextUpward() {
    setState(() {
      currentTextIndex = (currentTextIndex + 1) % texts.length;
    });
    print('-----------------Arrow Upward');
  }

  void changeTextDownward() {
    setState(() {
      currentTextIndex = (currentTextIndex - 1 + texts.length) % texts.length;
    });
    print('-----------------Arrow Downward');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  void _startCamera() async {
    print('Start Camera: Before permission check');
    if (controller == null && !isRequestingPermission) {
      print('Start Camera: Inside permission check');
      // Set the flag to indicate that a permissions request is ongoing
      isRequestingPermission = true;

      try {
        // Check if the app has camera permissions
        bool hasPermissions = await _handleCameraPermissions();

        if (hasPermissions) {
          _cameras = await availableCameras();
          final rearCamera = _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );

          // Initialize the camera controller
          _initializeCameraController(rearCamera);
        } else {
          print('Start Camera: Permission check failed or request ongoing');
          showInSnackBar('Camera permissions not granted');
        }
      } on CameraException catch (e) {
        _showCameraException(e);
      } finally {
        isCameraPermissionRequestOngoing = false;
      }
    }
  }

  Future<void> _initializeController() async {
    if (controller != null) {
      if (isCameraPermissionRequestOngoing) {
        try {
          // isCameraPermissionRequestOngoing = true;
          await controller!.initialize();
        } on CameraException catch (e) {
          print("Camera initialization error: $e");
        } finally {
          isCameraPermissionRequestOngoing = false;
        }
      }
    }
  }

  Future<bool> _handleCameraPermissions() async {
    PermissionStatus status = await Permission.camera.status;

    if (status != PermissionStatus.granted) {
      Map<Permission, PermissionStatus> statusMap =
          await [Permission.camera].request();
      return statusMap[Permission.camera] == PermissionStatus.granted;
    }

    return true;
  }

  void _disposeCamera() {
    if (controller != null) {
      controller!.dispose();
      controller = null;
    }
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          // First Column: Icons
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xff232323),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 40,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          currentMode = CameraMode.photo;
                          if (currentMode == CameraMode.video) {
                            isRecording = false;
                          }
                        });
                      },
                      child: Container(
                        width: 100,
                        height: 50,
                        //color: Colors.green,
                        child: Row(
                          children: [
                            Icon(
                              Icons.camera_alt_outlined,
                              color: currentMode == CameraMode.photo
                                  ? Colors.yellow
                                  : Colors.white,
                              //color: Colors.yellow,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Text(
                              "Photo",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: currentMode == CameraMode.photo
                                    ? Colors.yellow
                                    : Colors.white,
                                //color: Colors.yellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          currentMode = CameraMode.video;
                          isRecording = false;
                        });
                      },
                      child: Container(
                        width: 100,
                        height: 50,
                        //color: Colors.green,
                        child: Row(
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              color: currentMode == CameraMode.video
                                  ? Colors.yellow
                                  : Colors.white,
                              //color: Colors.yellow,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Text(
                              "Video",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: currentMode == CameraMode.video
                                    ? Colors.yellow
                                    : Colors.white,
                                //color: Colors.yellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Second Column: Camera View
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color:
                      controller != null && controller!.value.isRecordingVideo
                          ? Colors.redAccent
                          : Colors.grey,
                  width: 3.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: _cameraPreviewWidget(),
                    ),
                    Positioned(
                      top: 34,
                      left: 400.0,
                      child: GestureDetector(
                        onTap: changeTextUpward,
                        child: Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(
                              3,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 90,
                      left: 400.0,
                      child: Container(
                        width: 40,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(
                            3,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Transform.rotate(
                            angle: -pi / 2, // Using the imported pi
                            child:  Text(
                             texts[currentTextIndex],
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 400.0,
                      top: 330,
                      child: GestureDetector(
                        onTap: changeTextDownward,
                        child: Container(
                          width: 40.0,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(
                              3,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_downward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Third Column: Reset Button
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xff232323),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 55,
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        //color: Colors.white,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            onSetFlashModeButtonPressed();
                          },
                          child: const Icon(
                            Icons.lightbulb,
                            color: Colors.yellow,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 75,
                  ),
                  // Adjust the spacing between buttons
                  GestureDetector(
                    onTap: () {
                      if (controller != null &&
                          controller!.value.isInitialized) {
                        if (currentMode == CameraMode.photo) {
                          onTakePictureButtonPressed();
                        } else if (currentMode == CameraMode.video) {
                          // Check if not recording, start recording
                          if (!controller!.value.isRecordingVideo) {
                            onVideoRecordButtonPressed();
                          } else {
                            // If recording, stop recording
                            onStopButtonPressed();
                          }
                          setState(() {
                            isRecording = !isRecording;
                          });
                        }
                      }
                    },
                    child: Container(
                      width: 67,
                      height: 67,
                      decoration: BoxDecoration(
                        shape: currentMode == CameraMode.photo
                            ? BoxShape.circle
                            : isRecording
                                ? BoxShape.rectangle
                                : BoxShape.circle,
                        color: currentMode == CameraMode.photo
                            ? Colors.white
                            : isRecording
                                ? Colors.red
                                : Colors.white,
                        border: Border.all(color: Colors.grey, width: 3),
                      ),
                      child: Center(
                        child: Icon(
                          isRecording ? Icons.stop : Icons.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(height: 75,),
                  Container(
                    child: _thumbnailWidget(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: CameraPreview(
          controller!,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails details) =>
                    onViewFinderTap(details, constraints),
              );
            },
          ),
        ),
      );
    }
  }

  Widget _thumbnailWidget() {
    final VideoPlayerController? localVideoController = videoController;

    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (localVideoController == null && imageFile == null)
            Container()
          else
            SizedBox(
              width: 80.0,
              height: 65,
              // height: 100.0,
              child: (localVideoController == null)
                  ? (kIsWeb
                      ? Image.network(imageFile!.path)
                      : Image.file(File(imageFile!.path)))
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                        ),
                      ),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: localVideoController.value.aspectRatio,
                          child: VideoPlayer(localVideoController),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  // Widget _captureControlRowWidget() {
  //   final CameraController? cameraController = controller;

  //   return Column(
  //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //     children: <Widget>[
  //       IconButton(
  //         icon: const Icon(Icons.camera_alt),
  //         color: Colors.blue,
  //         onPressed: cameraController != null &&
  //                 cameraController.value.isInitialized &&
  //                 !cameraController.value.isRecordingVideo
  //             ? onTakePictureButtonPressed
  //             : null,
  //       ),
  //       IconButton(
  //         icon: const Icon(Icons.videocam),
  //         color: Colors.blue,
  //         onPressed: cameraController != null &&
  //                 cameraController.value.isInitialized &&
  //                 !cameraController.value.isRecordingVideo
  //             ? onVideoRecordButtonPressed
  //             : null,
  //       ),
  //       IconButton(
  //         icon: cameraController != null &&
  //                 cameraController.value.isRecordingPaused
  //             ? const Icon(Icons.play_arrow)
  //             : const Icon(Icons.pause),
  //         color: Colors.blue,
  //         onPressed: cameraController != null &&
  //                 cameraController.value.isInitialized &&
  //                 cameraController.value.isRecordingVideo
  //             ? (cameraController.value.isRecordingPaused)
  //                 ? onResumeButtonPressed
  //                 : onPauseButtonPressed
  //             : null,
  //       ),
  //       IconButton(
  //         icon: const Icon(Icons.stop),
  //         color: Colors.red,
  //         onPressed: cameraController != null &&
  //                 cameraController.value.isInitialized &&
  //                 cameraController.value.isRecordingVideo
  //             ? onStopButtonPressed
  //             : null,
  //       ),
  //       IconButton(
  //         icon: const Icon(Icons.pause_presentation),
  //         color:
  //             cameraController != null && cameraController.value.isPreviewPaused
  //                 ? Colors.red
  //                 : Colors.blue,
  //         onPressed:
  //             cameraController == null ? null : onPausePreviewButtonPressed,
  //       ),
  //     ],
  //   );
  // }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.setDescription(cameraDescription);
      // _initializeController(); // Remove this line
    } else {
      _initializeCameraController(cameraDescription);
    }
  }

  void _initializeCameraController(CameraDescription cameraDescription) async {
    print('Initialize Camera Controller: Start');
    final CameraController cameraController = CameraController(
      cameraDescription,
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // Assign the controller before initializing
    controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        _showCameraException(
            cameraController.value.errorDescription as CameraException);
      }
    });

    try {
      // Initialize the controller
      await cameraController.initialize();
      await Future.wait(<Future<Object>>[]);
    } on CameraException catch (e) {
      _showCameraException(e);
    } finally {
      isCameraPermissionRequestOngoing = false;
    }

    if (mounted) {
      setState(() {});
    }
    print('Initialize Camera Controller: End');
  }

  Future<void> onTakePictureButtonPressed() async {
    _initializeController();
    if (controller != null && controller!.value.isInitialized) {
      takePicture().then((XFile? file) {
        if (mounted) {
          setState(() {
            imageFile = file;
            videoController?.dispose();
            videoController = null;
          });
          if (file != null) {
            showInSnackBar('Picture saved to ${file.path}');
          }
          setFlashMode(FlashMode.off);
        }
      });
    } else {
      // Handle the case when the controller is not initialized
      showInSnackBar('Error: Camera not initialized');
    }
  }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      final XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  // void onAudioModeButtonPressed() {
  //   enableAudio = !enableAudio;
  //   if (controller != null) {
  //     onNewCameraSelected(controller!.description);
  //   }
  // }

  // Future<void> onCaptureOrientationLockButtonPressed() async {
  //   try {
  //     if (controller != null) {
  //       final CameraController cameraController = controller!;
  //       if (cameraController.value.isCaptureOrientationLocked) {
  //         await cameraController.unlockCaptureOrientation();
  //         showInSnackBar('Capture orientation unlocked');
  //       } else {
  //         await cameraController.lockCaptureOrientation();
  //         showInSnackBar(
  //             'Capture orientation locked to ${cameraController.value.lockedCaptureOrientation.toString().split('.').last}');
  //       }
  //     }
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //   }
  // }

  void onSetFlashModeButtonPressed() {
    if (controller == null) {
      return;
    }

    FlashMode currentFlashMode = controller!.value.flashMode;

    // If the current flash mode is off or torch, switch to the opposite mode
    FlashMode newFlashMode =
        (currentFlashMode == FlashMode.off) ? FlashMode.torch : FlashMode.off;

    setFlashMode(newFlashMode).then((_) {
      if (mounted) {
        setState(() {});
      }
      showInSnackBar(
          'Flash mode set to ${newFlashMode.toString().split('.').last}');
    });
  }

  void onSetExposureModeButtonPressed(ExposureMode mode) {
    setExposureMode(mode).then((_) {
      if (mounted) {
        setState(() {});
      }
      showInSnackBar('Exposure mode set to ${mode.toString().split('.').last}');
    });
  }

  void onSetFocusModeButtonPressed(FocusMode mode) {
    setFocusMode(mode).then((_) {
      if (mounted) {
        setState(() {});
      }
      showInSnackBar('Focus mode set to ${mode.toString().split('.').last}');
    });
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void onStopButtonPressed() {
    stopVideoRecording().then((XFile? file) {
      if (mounted) {
        setState(() {});
      }
      if (file != null) {
        showInSnackBar('Video recorded to ${file.path}');
        videoFile = file;
        _startVideoPlayer();
      }
    });
  }

  Future<void> onPausePreviewButtonPressed() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isPreviewPaused) {
      await cameraController.resumePreview();
    } else {
      await cameraController.pausePreview();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void onPauseButtonPressed() {
    pauseVideoRecording().then((_) {
      if (mounted) {
        setState(() {});
      }
      showInSnackBar('Video recording paused');
    });
  }

  void onResumeButtonPressed() {
    resumeVideoRecording().then((_) {
      if (mounted) {
        setState(() {});
      }
      showInSnackBar('Video recording resumed');
    });
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return;
    }

    try {
      await cameraController.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.pauseVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.resumeVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setFlashMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setExposureMode(ExposureMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setExposureMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setExposureOffset(double offset) async {
    if (controller == null) {
      return;
    }

    // setState(() {
    //   _currentExposureOffset = offset;
    // });
    try {
      offset = await controller!.setExposureOffset(offset);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> setFocusMode(FocusMode mode) async {
    if (controller == null) {
      return;
    }

    try {
      await controller!.setFocusMode(mode);
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> _startVideoPlayer() async {
    if (videoFile != null) {
      await setFlashMode(FlashMode.off);
      final VideoPlayerController vController = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(videoFile!.path))
          : VideoPlayerController.file(File(videoFile!.path));

      videoPlayerListener = () {
        if (videoController != null) {
          if (mounted) {
            setState(() {});
          }
          videoController!.removeListener(videoPlayerListener!);
        }
      };
      vController.addListener(videoPlayerListener!);
      await vController.setLooping(true);
      await vController.initialize();
      await videoController?.dispose();
      if (mounted) {
        setState(() {
          imageFile = null;
          videoController = vController;
        });
      }
      await vController.play();
    }
  }

  void _showCameraException(CameraException e) {
    print('Camera Exception: ${e.code}, ${e.description}');
    _logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

/// CameraApp is the Main Application.
class CameraApp extends StatelessWidget {
  /// Default Constructor
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    return const MaterialApp(
      home: Camera(),
    );
  }
}

List<CameraDescription> _cameras = <CameraDescription>[];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    _cameras = await availableCameras();
    final rearCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
  } on CameraException catch (e) {
    _logError(e.code, e.description);
  }
  runApp(const CameraApp());
}

enum CameraMode {
  photo,
  video,
}
