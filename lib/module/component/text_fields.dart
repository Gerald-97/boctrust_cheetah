import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../app/theme.dart';
import '../../utils/input_formatters.dart';

class PinInputField extends StatelessWidget {
  const PinInputField({
    super.key,
    this.pinLength = 6,
    this.focusNode,
    this.autofocus = false,
    this.isActive = true,
    this.obscureText = false,
    required this.onChanged,
    this.onCompleteCode,
    this.pinCtrl,
  });

  final int pinLength;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool isActive;
  final bool obscureText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleteCode;
  final TextEditingController? pinCtrl;

  @override
  Widget build(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: pinLength,
      controller: pinCtrl,
      focusNode: focusNode,
      enabled: isActive,
      autoFocus: autofocus,
      enableActiveFill: true,
      enablePinAutofill: true,
      keyboardType: TextInputType.number,
      obscureText: obscureText,
      animationType: AnimationType.fade,
      textStyle: Theme.of(context).textTheme.bodyLarge,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(8),
        fieldHeight: 50,
        fieldWidth: 50,
        inactiveColor: kGreyMedium,
        activeColor: kYellowBorder,
        selectedColor: kPrimaryColor,
        disabledColor: kGreyMedium,
        inactiveFillColor: kGreyBg,
        activeFillColor: kGreyBg,
        selectedFillColor: kGreyBg,
        borderWidth: 1.3,
      ),
      separatorBuilder: (context, index) => const SizedBox(width: 3),
      onChanged: onChanged,
      onCompleted: onCompleteCode,
      beforeTextPaste: (_) => true,
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

class PasswordInputWidget extends StatefulWidget {
  const PasswordInputWidget({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<PasswordInputWidget> createState() => _PasswordInputWidgetState();
}

class _PasswordInputWidgetState extends State<PasswordInputWidget> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextInputWidget(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      validator: widget.validator,
      onSaved: widget.onSaved,
      onChanged: widget.onChanged,
      obscureText: _hidden,
      textInputAction: widget.textInputAction,
      suffix: IconButton(
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
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
