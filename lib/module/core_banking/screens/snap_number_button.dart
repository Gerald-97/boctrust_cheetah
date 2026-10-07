import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_flow/app_ui.dart';
import '../../kyc/service/dojah_camera_permission.dart';
import '../model/scan_text_models.dart';
import '../service/scan_candidate_extractor.dart';
import '../service/scan_image_file.dart';
import '../service/scan_text_recognizer.dart';

/// Recognizes the photo at [path] on the device and deletes it once
/// recognition ends, whether or not it succeeded.
Future<ScanCandidates> readScanFile(
  ScanTextRecognizer recognizer,
  String path,
) async {
  final image = ScanImageFile()..replace(path);
  try {
    return extractScanCandidates(await recognizer.recognize(path));
  } finally {
    image.clear();
  }
}

/// Asks which of several [numbers] read from one photo to use. Null when the
/// sheet is dismissed; a number is never picked for the customer.
Future<String?> chooseScannedNumber(
  BuildContext context,
  List<String> numbers,
) => AppActionSheet.show<String>(
  context: context,
  builder: (sheet) => AppActionSheet(
    icon: IconsaxPlusLinear.scan,
    title: 'Choose the account number',
    subtitle: 'This photo has more than one account number.',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, number) in numbers.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          AppActionSheetOption(
            icon: IconsaxPlusLinear.card,
            title: number,
            subtitle: 'Use this number',
            onTap: () => Navigator.of(sheet).pop(number),
          ),
        ],
      ],
    ),
  ),
);

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
  final recognizer = ref.read(scanTextRecognizerProvider);
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
  final photo = await ImagePicker().pickImage(source: source);
  if (photo == null) return null;
  final ScanCandidates candidates;
  try {
    candidates = await readScanFile(recognizer, photo.path);
  } on ScanRecognitionFailure catch (failure) {
    if (context.mounted) _say(context, failure.message);
    return null;
  }
  if (!context.mounted) return null;
  final numbers = candidates.accountNumbers;
  if (numbers.isEmpty) {
    _say(context, "We couldn't find a 10-digit account number.");
    return null;
  }
  if (numbers.length == 1) return numbers.single;
  return chooseScannedNumber(context, numbers);
}

void _say(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

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
