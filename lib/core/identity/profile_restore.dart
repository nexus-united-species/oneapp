import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// Set after a seed-phrase restore until the device has looked for its own
/// latest Kind-0 profile on the relays (TD-59). While set, the app must not
/// publish its own Kind-0: a freshly restored device only knows a generated
/// name and would overwrite the real profile for all contacts.
const profileRestorePendingKey = 'nexus_profile_restore_pending';

Future<bool> isProfileRestorePending([SharedPreferences? prefs]) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  return p.getBool(profileRestorePendingKey) ?? false;
}

Future<void> setProfileRestorePending(
  bool pending, [
  SharedPreferences? prefs,
]) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  if (pending) {
    await p.setBool(profileRestorePendingKey, true);
  } else {
    await p.remove(profileRestorePendingKey);
  }
}

/// Placeholder `about` text the app publishes when no bio is set.
bool _isDidPlaceholder(String about) =>
    about.startsWith('DID: did:key:') || about.startsWith('DID: did:web:');

/// The display name in an own Kind-0 [content], or `null` if none is set.
String? nameFromKind0(Map<String, dynamic> content) {
  final displayName = (content['display_name'] as String?)?.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  final name = (content['name'] as String?)?.trim() ?? '';
  return name.isEmpty ? null : name;
}

/// Returns a copy of [profile] with the fields from the user's own Kind-0
/// [content] taken over: name, bio and the public `nexus_profile` fields.
///
/// [picturePath] is the local file of the decoded `picture`, if any; a
/// picture published in Kind-0 was public, so its visibility stays public.
/// Fields missing from [content] keep their current value. Private fields
/// (birth date) are never part of Kind-0 and stay untouched.
UserProfile profileFromOwnKind0(
  UserProfile profile,
  Map<String, dynamic> content, {
  String? picturePath,
}) {
  final result = UserProfile.fromJson(profile.toJson());

  final name = nameFromKind0(content);
  if (name != null) {
    result.pseudonym = result.pseudonym.copyWith(value: name);
  }

  final about = (content['about'] as String?)?.trim();
  if (about != null && about.isNotEmpty && !_isDidPlaceholder(about)) {
    result.bio = result.bio.copyWith(value: about);
  }

  if (picturePath != null) {
    result.profileImage = result.profileImage
        .copyWith(value: picturePath, visibility: VisibilityLevel.public);
  }

  final nexus = content['nexus_profile'];
  if (nexus is Map) {
    List<String>? stringList(Object? v) =>
        v is List ? v.whereType<String>().toList() : null;
    String? nonEmpty(Object? v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;

    final languages = stringList(nexus['languages']);
    if (languages != null && languages.isNotEmpty) {
      result.languages = result.languages.copyWith(value: languages);
    }
    final skills = stringList(nexus['skills']);
    if (skills != null && skills.isNotEmpty) {
      result.skills = result.skills.copyWith(value: skills);
    }
    final realName = nonEmpty(nexus['realName']);
    if (realName != null) {
      result.realName = result.realName.copyWith(value: realName);
    }
    final location = nonEmpty(nexus['location']);
    if (location != null) {
      result.location = result.location.copyWith(value: location);
    }
    final imageVisibility = nonEmpty(nexus['profileImageVisibility']);
    if (imageVisibility != null && picturePath == null) {
      result.profileImage = result.profileImage.copyWith(
        visibility: VisibilityLevelX.fromString(imageVisibility),
      );
    }
  }
  return result;
}
