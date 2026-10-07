String maskName(String name, {String fallback = ''}) {
  final normalized = name.trim();
  if (normalized.isEmpty) {
    return fallback;
  }

  return '${String.fromCharCode(normalized.runes.first)}**';
}

String maskPhoneNumber(String phone, {String fallback = ''}) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return fallback;
  }

  if (digits.length < 7) {
    return '****';
  }

  return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)}';
}
