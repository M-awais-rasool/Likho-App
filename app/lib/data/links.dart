import 'package:url_launcher/url_launcher.dart';

/// Likho's web pages (likho.io). They open in the phone's browser, and only
/// from the parent area (behind the parent gate).
abstract final class LikhoLinks {
  static final privacy = Uri.parse('https://likho.io/privacy/');

  /// Google Play's page for this app's subscription (manage, cancel, change payment).
  static final playSubscription = Uri.parse('https://play.google.com/store/account/subscriptions?sku=likho_plus&package=com.likho.abcwriting');

  /// Likho in Google Play (the "please update" screen).
  static final store = Uri.parse('https://play.google.com/store/apps/details?id=com.likho.abcwriting');

  /// Opens [uri] in the browser; false when nothing could open it.
  static Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
