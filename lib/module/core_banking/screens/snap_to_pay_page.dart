import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import 'snap_number_button.dart';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool _isAccessDenied(CameraException error) =>
    error.code.contains('AccessDenied') ||
    error.code.contains('AccessRestricted');

/// Asks for camera access before the Scan to pay page opens, so the system
/// prompt never interrupts the viewfinder. Android asks through the runtime
/// permission; iOS has no permission_handler camera macro here, so opening
/// the camera once raises its own prompt. A refusal still opens the page,
/// which then offers the gallery and Settings.
Future<void> prepareScanCamera() async {
  if (_isAndroid) {
    await Permission.camera.request();
    return;
  }
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final probe = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
    );
    try {
      await probe.initialize();
    } finally {
      await probe.dispose();
    }
  } on CameraException {
    // Refused or unavailable; the page shows the gallery-only state.
  }
}

/// Send → Scan to pay: a live viewfinder with a shutter and a gallery button.
/// A read number is only offered for a transfer the customer then reviews.
class SnapToPayPage extends ConsumerStatefulWidget {
  const SnapToPayPage({required this.onExit, required this.onSend, super.key});

  final VoidCallback onExit;

  /// Opens [route] with [number] to prefill its account field.
  final void Function(String route, String number) onSend;

  @override
  ConsumerState<SnapToPayPage> createState() => _SnapToPayPageState();
}

enum _CameraState { starting, ready, denied, unavailable }

class _SnapToPayPageState extends ConsumerState<SnapToPayPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  _CameraState _cameraState = _CameraState.starting;
  bool _reading = false;
  String? _number;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  /// The camera is released while the app is in the background and reopened
  /// on return, so it is never held by an invisible page.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final camera = _camera;
      _camera = null;
      camera?.dispose();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    setState(() => _cameraState = _CameraState.starting);
    if (_isAndroid && !await Permission.camera.isGranted) {
      if (mounted) setState(() => _cameraState = _CameraState.denied);
      return;
    }
    try {
      final cameras = await availableCameras();
      final back = cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .followedBy(cameras)
          .firstOrNull;
      if (back == null) {
        if (mounted) setState(() => _cameraState = _CameraState.unavailable);
        return;
      }
      // Medium keeps a capture near the size of a picked gallery photo. On a
      // Pixel 7 Pro a high-resolution capture made a 766 KB upload that the
      // staging server reset after 45 seconds; ~38 KB uploads return in ~2s.
      final camera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() {
        _camera = camera;
        _cameraState = _CameraState.ready;
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(
          () => _cameraState = _isAccessDenied(error)
              ? _CameraState.denied
              : _CameraState.unavailable,
        );
      }
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_reading || camera == null || !camera.value.isInitialized) return;
    setState(() => _reading = true);
    try {
      final photo = await camera.takePicture();
      await _read(await photo.readAsBytes());
    } on CameraException {
      _say("We couldn't take that photo. Try again.");
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_reading) return;
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    setState(() => _reading = true);
    try {
      await _read(await photo.readAsBytes());
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _read(Uint8List image) async {
    final number = await readAccountNumber(context, ref, image);
    if (number != null && mounted) setState(() => _number = number);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final number = _number;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewfinder(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                if (number == null) _controls() else _result(number),
              ],
            ),
          ),
          if (_reading)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: BocSpace.xs,
      vertical: BocSpace.xxs,
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: widget.onExit,
          icon: const Icon(IconsaxPlusLinear.arrow_left_2, color: Colors.white),
        ),
        const Expanded(
          child: Text(
            'Scan to pay',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _viewfinder() {
    final camera = _camera;
    if (_cameraState == _CameraState.ready && camera != null) {
      final size = camera.value.previewSize;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (size != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.height,
                height: size.width,
                child: CameraPreview(camera),
              ),
            )
          else
            CameraPreview(camera),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.86,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(BocRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: BocSpace.sm),
                const Text(
                  'Fit the account number inside the frame',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BocSpace.lg),
        child: switch (_cameraState) {
          _CameraState.starting => const CircularProgressIndicator(
            color: Colors.white,
          ),
          _CameraState.denied => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                IconsaxPlusLinear.camera_slash,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: BocSpace.sm),
              const Text(
                'Camera access is off. Allow it in Settings, or choose a '
                'photo from your gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: BocSpace.md),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              ),
            ],
          ),
          _ => const Text(
            'The camera is not available. Choose a photo from your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        },
      ),
    );
  }

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(
      BocSpace.lg,
      0,
      BocSpace.lg,
      BocSpace.lg,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundButton(
          tooltip: 'Choose a photo',
          icon: IconsaxPlusLinear.gallery,
          onPressed: _reading ? null : _pickFromGallery,
        ),
        Semantics(
          button: true,
          label: 'Take photo',
          child: GestureDetector(
            onTap: _cameraState == _CameraState.ready && !_reading
                ? _capture
                : null,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cameraState == _CameraState.ready
                      ? Colors.white
                      : Colors.white38,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 56),
      ],
    ),
  );

  bool _available(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  Widget _result(String number) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(BocSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Account number', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: BocSpace.xxs),
          Text(number, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: BocSpace.md),
          if (_available(FeatureCapability.boctrustTransfers)) ...[
            PrimaryButton(
              label: 'Send to a BOCTRUST account',
              onPressed: () => widget.onSend(AppRoutes.sendBeneficiary, number),
            ),
            const SizedBox(height: BocSpace.sm),
          ],
          if (_available(FeatureCapability.interbankTransfers)) ...[
            SecondaryButton(
              label: 'Send to another bank',
              onPressed: () => widget.onSend(AppRoutes.sendOtherBank, number),
            ),
            const SizedBox(height: BocSpace.sm),
          ],
          BocTextButton(
            label: 'Scan again',
            onPressed: () => setState(() => _number = null),
          ),
        ],
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    iconSize: 26,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white24,
      foregroundColor: Colors.white,
      fixedSize: const Size.square(56),
    ),
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
