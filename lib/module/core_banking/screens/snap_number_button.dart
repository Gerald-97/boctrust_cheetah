import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_flow/app_ui.dart';
import '../../kyc/service/dojah_camera_permission.dart';
import '../service/core_ocr_service.dart';

final _accountNumber = RegExp(r'^\d{10}$');

/// Reads a ten-digit account number from [image]. Null when none was found;
/// the reason is shown as a snackbar. Never submits anything.
Future<String?> readAccountNumber(
  BuildContext context,
  WidgetRef ref,
  Uint8List image,
) async {
  final result = await ref.read(coreOcrServiceProvider).readNumber(image);
  if (!context.mounted) return null;
  final number = result.data;
  final problem = number == null
      ? result.message ?? "We couldn't read that photo."
      : _accountNumber.hasMatch(number)
      ? null
      : "That number isn't a 10-digit account number.";
  if (problem != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(problem)));
    return null;
  }
  return number;
}

/// Asks for a photo from the camera or gallery and reads an account number
/// from it, for a field's suffix button.
Future<String?> snapAccountNumber(BuildContext context, WidgetRef ref) async {
  final source = await AppActionSheet.show<ImageSource>(
    context: context,
    builder: (sheet) => AppActionSheet(
      icon: IconsaxPlusLinear.scan,
      title: 'Read an account number',
      subtitle: 'Use a clear photo of the number.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppActionSheetOption(
            icon: IconsaxPlusLinear.camera,
            title: 'Take a photo',
            subtitle: 'Use your camera',
            onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
          ),
          const SizedBox(height: 12),
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
  // The app declares CAMERA for identity capture, so Android requires it to
  // be granted before the camera can be opened for this photo too.
  if (source == ImageSource.camera &&
      !await requestDojahCameraPermission(
        isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      )) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allow camera access in Settings to take a photo.'),
        ),
      );
    }
    return null;
  }
  final photo = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (photo == null || !context.mounted) return null;
  final bytes = await photo.readAsBytes();
  if (!context.mounted) return null;
  return readAccountNumber(context, ref, bytes);
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
