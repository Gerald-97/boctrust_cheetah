enum IdentifierType {
  email('email'),
  phoneNumber('phone_number'),
  unknown('unknown');

  const IdentifierType(this.wireValue);
  final String wireValue;

  static IdentifierType fromWire(Object? value) => switch (value) {
    'email' => email,
    'phone_number' => phoneNumber,
    _ => unknown,
  };
}

enum PhoneVerificationChannel {
  sms('sms'),
  whatsapp('whatsapp');

  const PhoneVerificationChannel(this.wireValue);
  final String wireValue;
}

enum OtpPurpose {
  signup('signup'),
  verifyAccount('verify_account'),
  forgotPassword('forgot_password'),
  forgotPin('forgot_pin'),
  newDeviceLogin('new_device_login'),
  other('other'),
  unknown('unknown');

  const OtpPurpose(this.wireValue);
  final String wireValue;

  static OtpPurpose fromWire(Object? value) => switch (value) {
    'signup' => signup,
    'verify_account' => verifyAccount,
    'forgot_password' => forgotPassword,
    'forgot_pin' => forgotPin,
    'new_device_login' => newDeviceLogin,
    'other' => other,
    _ => unknown,
  };
}

enum NotificationChannel {
  email('email'),
  sms('sms'),
  whatsapp('whatsapp'),
  unknown('unknown');

  const NotificationChannel(this.wireValue);
  final String wireValue;

  static NotificationChannel fromWire(Object? value) => switch (value) {
    'email' => email,
    'sms' => sms,
    'whatsapp' => whatsapp,
    _ => unknown,
  };
}

enum NotificationProvider {
  sendgrid('sendgrid'),
  termii('termii'),
  whatsapp('whatsapp'),
  unknown('unknown');

  const NotificationProvider(this.wireValue);
  final String wireValue;

  static NotificationProvider fromWire(Object? value) => switch (value) {
    'sendgrid' => sendgrid,
    'termii' => termii,
    'whatsapp' => whatsapp,
    _ => unknown,
  };
}
