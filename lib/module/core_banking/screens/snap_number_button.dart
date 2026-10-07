import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../kyc/service/dojah_camera_permission.dart';
import '../service/core_ocr_service.dart';
import 'core_flow_widgets.dart';

final _accountNumber = RegExp(r'^\d{10}$');

/// Asks for a photo from the camera or gallery and reads a ten-digit account
/// number from it. Null when the customer cancels or no account number was
/// found; the reason is shown as a snackbar. Never submits anything.
Future<String?> snapAccountNumber(BuildContext context, WidgetRef ref) async {
  final source = await AppActionSheet.show<ImageSource>(
    context: context,
    builder: (sheet) => AppActionSheet(
      icon: IconsaxPlusLinear.scan,
      title: 'Read an account number',
      subtitle: 'Use a clear photo of the number.',
      child: Column(
        children: [
          AppActionSheetOption(
            icon: IconsaxPlusLinear.camera,
            title: 'Take a photo',
            subtitle: 'Use your camera',
            onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
          ),
          AppActionSheetOption(
            icon: IconsaxPlusLinear.gallery,
            title: 'Choose a photo',
            subtitle: 'From your gallery',
            onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  void say(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // The app declares CAMERA for identity capture, so Android requires it to
  // be granted before the camera can be opened for this photo too.
  if (source == ImageSource.camera &&
      !await requestDojahCameraPermission(
        isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      )) {
    say('Allow camera access in Settings to take a photo.');
    return null;
  }
  final photo = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (photo == null || !context.mounted) return null;
  final result = await ref
      .read(coreOcrServiceProvider)
      .readNumber(await photo.readAsBytes());
  final number = result.data;
  if (number == null) {
    say(result.message ?? "We couldn't read that photo.");
    return null;
  }
  if (!_accountNumber.hasMatch(number)) {
    say("That number isn't a 10-digit account number.");
    return null;
  }
  return number;
}

/// A field suffix that fills an account number from a photo.
class SnapNumberButton extends ConsumerStatefulWidget {
  const SnapNumberButton({required this.onNumber, super.key});

  final ValueChanged<String> onNumber;

  @override
  ConsumerState<SnapNumberButton> createState() => _SnapNumberButtonState();
}

class _SnapNumberButtonState extends ConsumerState<SnapNumberButton> {
  bool _reading = false;

  Future<void> _snap() async {
    setState(() => _reading = true);
    final number = await snapAccountNumber(context, ref);
    if (!mounted) return;
    setState(() => _reading = false);
    if (number != null) widget.onNumber(number);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Read number from a photo',
    onPressed: _reading ? null : _snap,
    icon: _reading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(IconsaxPlusLinear.scan),
  );
}

/// Payments → Scan to pay: read a number, then choose where to send to.
class SnapToPayPage extends ConsumerStatefulWidget {
  const SnapToPayPage({
    required this.onExit,
    required this.onSectionSelected,
    required this.onSend,
    super.key,
  });

  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  /// Opens [route] with [number] to prefill its account field.
  final void Function(String route, String number) onSend;

  @override
  ConsumerState<SnapToPayPage> createState() => _SnapToPayPageState();
}

class _SnapToPayPageState extends ConsumerState<SnapToPayPage> {
  String? _number;
  bool _reading = false;

  Future<void> _snap() async {
    setState(() => _reading = true);
    final number = await snapAccountNumber(context, ref);
    if (!mounted) return;
    setState(() {
      _reading = false;
      _number = number ?? _number;
    });
  }

  bool _available(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  @override
  Widget build(BuildContext context) {
    final number = _number;
    return AppScaffold(
      title: 'Scan to pay',
      activeSection: AppSection.payments,
      onBack: widget.onExit,
      onSectionSelected: widget.onSectionSelected,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: [
          const FlowHeading('Pay from a photo'),
          const Text(
            'Take or choose a photo of an account number. You will check '
            'the details before anything is sent.',
          ),
          const SizedBox(height: BocSpace.lg),
          if (number != null) ...[
            ApiStateCard(
              title: number,
              message: 'Account number read from your photo.',
              tone: ApiStateTone.info,
            ),
            const SizedBox(height: BocSpace.md),
            if (_available(FeatureCapability.boctrustTransfers)) ...[
              PrimaryButton(
                label: 'Send to a BOCTRUST account',
                onPressed: () =>
                    widget.onSend(AppRoutes.sendBeneficiary, number),
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
          ],
          if (number == null)
            PrimaryButton(
              label: 'Take or choose a photo',
              isLoading: _reading,
              onPressed: _snap,
            )
          else
            BocTextButton(
              label: 'Use a different photo',
              onPressed: _reading ? null : _snap,
            ),
        ],
      ),
    );
  }
}
