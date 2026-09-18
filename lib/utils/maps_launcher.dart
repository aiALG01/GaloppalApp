import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Opens [address] in the platform's map app — Apple Maps on iOS, Google
/// Maps (or whatever handles `geo:`) on Android, Google Maps on the web.
Future<void> openAddressInMaps(String address) async {
  final query = Uri.encodeComponent(address);
  final uri = Platform.isIOS
      ? Uri.parse('https://maps.apple.com/?q=$query')
      : Platform.isAndroid
      ? Uri.parse('geo:0,0?q=$query')
      : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
