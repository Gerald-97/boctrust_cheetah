import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../utils/input_formatters.dart';

class PinInputField extends StatefulWidget {
  const PinInputField({
    super.key,
    this.pinLength = 6,
    this.focusNode,
    this.autofocus = false,
    this.isActive = true,
    this.obscureText = false,
    this.onChanged,
    this.onCompleteCode,
    this.pinCtrl,
    this.validator,
    this.autoValidateMode,
  });

  final int pinLength;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool isActive;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleteCode;
  final TextEditingController? pinCtrl;
  final String? Function(String?)? validator;
  final AutovalidateMode? autoValidateMode;

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;

  @override
  void dispose() {
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pinLength = widget.pinLength;
    final scale = MediaQuery.textScalerOf(context);
    final controller =
        widget.pinCtrl ?? (_ownedController ??= TextEditingController());
    final focusNode = widget.focusNode ?? (_ownedFocusNode ??= FocusNode());
    return LayoutBuilder(
      builder: (context, constraints) => PinCodeTextField(
        // The package binds these in initState; a new flow stage must rebind.
        key: ValueKey((controller, focusNode, pinLength)),
        appContext: context,
        length: pinLength,
        controller: controller,
        focusNode: focusNode,
        autoDisposeControllers: false,
        enabled: widget.isActive,
        autoFocus: widget.autofocus,
        enableActiveFill: true,
        enablePinAutofill: true,
        keyboardType: TextInputType.number,
        obscureText: widget.obscureText,
        animationType: AnimationType.fade,
        validator: widget.validator,
        autovalidateMode: widget.autoValidateMode ?? AutovalidateMode.disabled,
        textStyle: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: colorScheme.primary,
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(8),
          fieldHeight: (scale.scale(20) + 24).clamp(50, double.infinity),
          fieldWidth: ((constraints.maxWidth - 3 * (pinLength - 1)) / pinLength)
              .clamp(1, 50),
          inactiveColor: Theme.of(context).dividerColor,
          activeColor: colorScheme.primary,
          selectedColor: colorScheme.primary,
          errorBorderColor: colorScheme.error,
          disabledColor: colorScheme.outlineVariant,
          inactiveFillColor: colorScheme.surface,
          activeFillColor: colorScheme.surface,
          selectedFillColor: colorScheme.surface,
          borderWidth: 1.3,
        ),
        separatorBuilder: (context, index) => const SizedBox(width: 3),
        onChanged: widget.onChanged ?? (_) {},
        onCompleted: widget.onCompleteCode,
        beforeTextPaste: (_) => true,
      ),
    );
  }
}

class TextInputWidget extends StatelessWidget {
  const TextInputWidget({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.onTapField,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autoValidateMode,
    this.autofillHints,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final void Function(String)? onChanged;
  final VoidCallback? onTapField;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final AutovalidateMode? autoValidateMode;
  final Iterable<String>? autofillHints;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      validator: validator,
      onSaved: onSaved,
      onChanged: onChanged,
      onTap: onTapField,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      autovalidateMode: autoValidateMode,
      autofillHints: autofillHints,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: suffix,
      ),
    );
    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label!, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class PhoneNumberInput extends StatelessWidget {
  const PhoneNumberInput({
    super.key,
    this.controller,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.autoValidateMode,
  });

  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final void Function(String)? onChanged;
  final AutovalidateMode? autoValidateMode;

  @override
  Widget build(BuildContext context) {
    return TextInputWidget(
      controller: controller,
      label: 'Phone number',
      hint: '0800-000-0000',
      keyboardType: TextInputType.phone,
      inputFormatters: [PhoneDashFormatter()],
      validator: validator,
      onSaved: onSaved,
      onChanged: onChanged,
      autoValidateMode: autoValidateMode,
    );
  }
}

class FormDropdownWidget<T> extends StatelessWidget {
  const FormDropdownWidget({
    super.key,
    required this.items,
    this.value,
    this.label,
    this.hint,
    this.validator,
    this.onChanged,
    this.onSaved,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final String? label;
  final String? hint;
  final String? Function(T?)? validator;
  final ValueChanged<T?>? onChanged;
  final FormFieldSetter<T>? onSaved;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      isExpanded: true,
      itemHeight: null,
      initialValue: value,
      items: items,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      decoration: InputDecoration(hintText: hint),
    );

    if (label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label!, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class FormDropdown<T> extends FormDropdownWidget<T> {
  const FormDropdown({
    super.key,
    required super.items,
    super.value,
    super.label,
    super.hint,
    super.validator,
    super.onChanged,
    super.onSaved,
  });
}
