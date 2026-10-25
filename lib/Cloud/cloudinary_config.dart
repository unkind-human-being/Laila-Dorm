class CloudinaryConfig {
  static const String cloudName =
      'dxo9ga32o';

  static const String uploadPreset =
      'laila_residents';

  static bool get configured =>
      cloudName.isNotEmpty &&
      !cloudName.startsWith('YOUR_') &&
      uploadPreset.isNotEmpty;
}