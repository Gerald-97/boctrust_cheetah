import 'dart:async';
import 'dart:io';

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
import '../model/interbank_models.dart';
import '../model/scan_text_models.dart';
import '../provider/core_payments_providers.dart';
import '../service/scan_candidate_extractor.dart';
import '../service/scan_image_file.dart';
import '../service/scan_text_recognizer.dart';
import 'core_flow_widgets.dart';
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
  final void Function(String route, String number, String? bankCode) onSend;

  @override
  ConsumerState<SnapToPayPage> createState() => _SnapToPayPageState();
}

enum _CameraState { starting, ready, denied, unavailable }

class _SnapToPayPageState extends ConsumerState<SnapToPayPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  _CameraState _cameraState = _CameraState.starting;
  final _image = ScanImageFile();
  bool _recognizing = false;

  /// Bumped by every new image, Retake and exit, so a result that arrives
  /// for an earlier image is ignored.
  int _scan = 0;
  ScanCandidates? _candidates;
  String? _number;
  String? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !ref
              .read(
                featureAvailabilityProvider(
                  FeatureCapability.interbankTransfers,
                ),
              )
              .isAvailable) {
        return;
      }
      unawaited(ref.read(interbankBanksProvider.notifier).ensureLoaded());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _image.clear();
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
      // Photos are read on the device, so small print gets every pixel.
      final camera = CameraController(
        back,
        ResolutionPreset.max,
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
    if (_recognizing || camera == null || !camera.value.isInitialized) return;
    setState(() => _recognizing = true);
    final XFile photo;
    try {
      photo = await camera.takePicture();
    } on CameraException {
      if (mounted) setState(() => _recognizing = false);
      _say("We couldn't take that photo. Try again.");
      return;
    }
    await _recognize(photo.path);
  }

  Future<void> _pickFromGallery() async {
    if (_recognizing) return;
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo == null) return;
    await _recognize(photo.path);
  }

  /// Shows [path] in place of the viewfinder and reads it on the device.
  Future<void> _recognize(String path) async {
    _image.replace(path);
    if (!mounted) {
      _image.clear();
      return;
    }
    final scan = ++_scan;
    final recognizer = ref.read(scanTextRecognizerProvider);
    setState(() {
      _recognizing = true;
      _candidates = null;
      _number = null;
      _problem = null;
    });
    ScanCandidates? candidates;
    String? problem;
    try {
      candidates = extractScanCandidates(await recognizer.recognize(path));
    } on ScanRecognitionFailure catch (failure) {
      problem = failure.message;
    }
    if (!mounted || scan != _scan) return;
    final numbers = candidates?.accountNumbers ?? const [];
    setState(() {
      _recognizing = false;
      _candidates = candidates;
      _problem =
          problem ??
          (numbers.isEmpty
              ? "We couldn't find a 10-digit account number."
              : null);
      if (numbers.length == 1) _number = numbers.single;
    });
    if (numbers.length > 1) await _chooseNumber();
  }

  Future<void> _chooseNumber() async {
    final scan = _scan;
    final numbers = _candidates?.accountNumbers ?? const [];
    final number = await chooseScannedNumber(context, numbers);
    if (number != null && mounted && scan == _scan) {
      setState(() => _number = number);
    }
  }

  /// Drops the photo and returns to the live viewfinder.
  void _retake() {
    _scan++;
    _image.clear();
    setState(() {
      _recognizing = false;
      _candidates = null;
      _number = null;
      _problem = null;
    });
  }

  void _exit() {
    _scan++;
    _image.clear();
    widget.onExit();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final photo = _image.path;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (photo == null)
            _viewfinder()
          else
            Image.file(
              File(photo),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const Spacer(),
                if (photo == null)
                  _controls()
                else if (!_recognizing)
                  ..._still(),
              ],
            ),
          ),
          if (_recognizing)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: BocSpace.sm),
                    Text(
                      'Reading the photo…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Retake and Choose another over the photo, then what was read from it.
  List<Widget> _still() {
    final number = _number;
    final several = (_candidates?.accountNumbers.length ?? 0) > 1;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: BocSpace.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _retake,
              icon: const Icon(IconsaxPlusLinear.camera),
              label: const Text('Retake'),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _pickFromGallery,
              icon: const Icon(IconsaxPlusLinear.gallery),
              label: const Text('Choose another'),
            ),
          ],
        ),
      ),
      const SizedBox(height: BocSpace.xs),
      if (number != null)
        _result(number)
      else
        _message(
          _problem ?? 'This photo has more than one account number.',
          onChoose: several ? _chooseNumber : null,
        ),
    ];
  }

  Widget _message(String message, {VoidCallback? onChoose}) => Material(
    color: Theme.of(context).cardColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(BocSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (onChoose != null) ...[
            const SizedBox(height: BocSpace.md),
            PrimaryButton(label: 'Choose the number', onPressed: onChoose),
          ],
        ],
      ),
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: BocSpace.xs,
      vertical: BocSpace.xxs,
    ),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: _exit,
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
          // Leaves room for the top bar and the shutter row.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.lg,
              96,
              BocSpace.lg,
              160,
            ),
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(BocRadius.md),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: BocSpace.sm),
                const Text(
                  'Fit the bank name and account number inside the frame',
                  textAlign: TextAlign.center,
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
          onPressed: _recognizing ? null : _pickFromGallery,
        ),
        Semantics(
          button: true,
          label: 'Take photo',
          child: GestureDetector(
            onTap: _cameraState == _CameraState.ready && !_recognizing
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

  Widget _result(String number) {
    final canBoctrust = _available(FeatureCapability.boctrustTransfers);
    final canInterbank = _available(FeatureCapability.interbankTransfers);
    final banksState = ref.watch(interbankBanksProvider);
    final banks = scanToPayBanks(
      canBoctrust: canBoctrust,
      canInterbank: canInterbank,
      fetched: banksState.data ?? const [],
    );
    return ScannedAccountResult(
      number: number,
      banks: banks,
      loading: canInterbank && banksState.isLoading,
      errorMessage: canInterbank && banksState.isError
          ? banksState.message ?? 'We could not load banks.'
          : null,
      onRetry: canInterbank
          ? ref.read(interbankBanksProvider.notifier).load
          : null,
      onSend: (route, number, bankCode) {
        _retake();
        widget.onSend(route, number, bankCode);
      },
      onScanAgain: _retake,
    );
  }
}

/// Shown when neither transfer flow can take a scanned number.
const kNoScanBanks =
    'Transfers to a scanned account are unavailable right now.';

/// The banks a scanned number can be sent to: BOCTRUST first, then the
/// fetched banks. Any fetched BOCTRUST entry is dropped so a BOCTRUST number
/// always goes through the internal flow and its account enquiry.
List<CommercialBank> scanToPayBanks({
  required bool canBoctrust,
  required bool canInterbank,
  required List<CommercialBank> fetched,
}) => [
  if (canBoctrust) boctrustBank,
  if (canInterbank)
    for (final bank in fetched)
      if (!bank.name.toLowerCase().contains('boctrust')) bank,
];

/// The confirmed OCR result. A bank must still be selected before routing to
/// the matching transfer flow; OCR never infers the receiving bank.
class ScannedAccountResult extends StatefulWidget {
  const ScannedAccountResult({
    required this.number,
    required this.banks,
    required this.loading,
    required this.onSend,
    required this.onScanAgain,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final String number;
  final List<CommercialBank> banks;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final void Function(String route, String number, String? bankCode) onSend;
  final VoidCallback onScanAgain;

  @override
  State<ScannedAccountResult> createState() => _ScannedAccountResultState();
}

class _ScannedAccountResultState extends State<ScannedAccountResult> {
  CommercialBank? _bank;

  @override
  Widget build(BuildContext context) => Material(
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
          Text(widget.number, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: BocSpace.md),
          BankSelectorTile(
            bank: _bank,
            banks: widget.banks,
            loading: widget.loading,
            onSelected: (bank) => setState(() => _bank = bank),
          ),
          if (widget.banks.isEmpty &&
              !widget.loading &&
              widget.errorMessage == null) ...[
            const SizedBox(height: BocSpace.sm),
            const FieldError(kNoScanBanks),
          ],
          if (widget.errorMessage case final message?) ...[
            const SizedBox(height: BocSpace.sm),
            ApiStateCard(
              title: 'Banks unavailable',
              message: message,
              tone: ApiStateTone.error,
              actionLabel: widget.onRetry == null ? null : 'Retry',
              onAction: widget.onRetry,
            ),
          ],
          const SizedBox(height: BocSpace.md),
          PrimaryButton(
            label: 'Continue',
            onPressed: _bank == null
                ? null
                : () {
                    final bank = _bank!;
                    widget.onSend(
                      bank.isBoctrust
                          ? AppRoutes.sendBeneficiary
                          : AppRoutes.sendOtherBank,
                      widget.number,
                      bank.isBoctrust ? null : bank.code,
                    );
                  },
          ),
          const SizedBox(height: BocSpace.sm),
          BocTextButton(label: 'Scan again', onPressed: widget.onScanAgain),
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
