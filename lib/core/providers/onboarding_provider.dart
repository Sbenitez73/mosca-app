import 'package:flutter_riverpod/flutter_riverpod.dart';

// Overridden in main() with the real value from DB.
// Defaults to true so hot-reload doesn't force onboarding on existing installs.
final onboardingDoneProvider = StateProvider<bool>((ref) => true);
