class FormatHelper {
  static String formatPhone(String phone) {
    if (phone.isEmpty) return "";

    // Convert +82 to 0
    String processed = phone;
    if (processed.startsWith('+82')) {
      processed = '0${processed.substring(3)}';
    }

    String clean = processed.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 11) {
      return "${clean.substring(0, 3)}-${clean.substring(3, 7)}-${clean.substring(7)}";
    } else if (clean.length == 10) {
      if (clean.startsWith('02')) {
        return "${clean.substring(0, 2)}-${clean.substring(2, 6)}-${clean.substring(6)}";
      }
      return "${clean.substring(0, 3)}-${clean.substring(3, 6)}-${clean.substring(6)}";
    }
    return processed;
  }
}
