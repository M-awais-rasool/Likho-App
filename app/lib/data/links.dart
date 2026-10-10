import 'package:url_launcher/url_launcher.dart';

/// Likho's web pages (likho.io). They open in the phone's browser, and only
/// from the parent area (behind the parent gate).
abstract final class LikhoLinks {
  static final privacy = Uri.parse('https://likho.io/privacy/');

  /// Opens [uri] in the browser; false when nothing could open it.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
