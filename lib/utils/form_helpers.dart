import 'package:flutter/material.dart';

bool validateAndSave({
  required GlobalKey<FormState> formKey,
  required VoidCallback onSuccess,
  required ValueSetter<AutovalidateMode> onFailure,
}) {
  final state = formKey.currentState;
  if (state != null && state.validate()) {
    state.save();
    onSuccess();
    return true;
  }
  onFailure(AutovalidateMode.onUserInteraction);
  return false;
}
