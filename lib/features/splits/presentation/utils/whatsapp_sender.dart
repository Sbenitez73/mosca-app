import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sends [text] (and optionally [photoPaths]) to [phone] via WhatsApp,
/// falling back to the system share sheet if WhatsApp isn't installed or
/// no phone is available.
///
/// Uses `LaunchMode.externalNonBrowserApplication` with a `wa.me` Universal
/// Link so iOS opens WhatsApp directly — no `LSApplicationQueriesSchemes`
/// declaration needed and no Safari detour.
/// Sends [text] and optional [photoPaths] via WhatsApp.
///
/// **With photos**: always uses the system share sheet so the files are
/// included. WhatsApp will ask the user to pick a recipient (iOS limitation —
/// file sharing via URL scheme is not supported).
///
/// **Text only + phone**: opens the WhatsApp chat directly via Universal Link,
/// skipping the share sheet and the recipient picker entirely.
Future<void> sendViaWhatsApp({
  required String text,
  String? phone,
  List<String> photoPaths = const [],
  Rect? sharePositionOrigin,
}) async {
  final photos = photoPaths
      .where((p) => p.isNotEmpty && File(p).existsSync())
      .toList();

  // Photos must go through the share sheet — WhatsApp URL scheme is text-only.
  if (photos.isNotEmpty) {
    await Share.shareXFiles(
      photos.map((p) => XFile(p)).toList(),
      text: text,
      sharePositionOrigin: sharePositionOrigin,
    );
    return;
  }

  // No photos + phone → open the chat directly, no share sheet needed.
  if (phone != null && phone.trim().isNotEmpty) {
    final digits = _normalizePhone(phone);
    final uri = Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
    bool launched = false;
    try {
      launched = await launchUrl(
          uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {}
    if (launched) return;
  }

  // Fallback: text-only share sheet.
  await Share.share(text, sharePositionOrigin: sharePositionOrigin);
}

/// Picks a contact using the system picker and returns `(name, phone)`.
///
/// Passes `{ContactProperty.phone}` so the picker returns phone numbers
/// directly — no second fetch or full contacts permission needed.
Future<(String name, String phone)> pickContact() async {
  final contact = await FlutterContacts.native
      .showPicker(properties: {ContactProperty.phone});
  if (contact == null) return ('', '');
  final name = contact.displayName ?? '';
  final phone = contact.phones.firstOrNull?.number ?? '';
  return (name, _normalizeContactPhone(phone));
}

/// Normalises a raw contact phone string to international format with `+`.
/// Assumes Colombia (+57) when no country code is present.
String _normalizeContactPhone(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  if (hasPlus) return '+$digits';
  if (digits.length == 10) return '+57$digits';
  return digits;
}

/// Normalises a raw phone string to digits-only international format.
/// Assumes Colombia (+57) when no country code is present.
String _normalizePhone(String raw) {
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  if (hasPlus) return digits;
  if (digits.length == 10) return '57$digits';
  return digits;
}
