import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_oneapp/core/identity/profile.dart';
import 'package:nexus_oneapp/core/identity/profile_restore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('nameFromKind0', () {
    test('prefers display_name, falls back to name', () {
      expect(nameFromKind0({'name': 'joachim', 'display_name': 'Joachim R.'}),
          'Joachim R.');
      expect(nameFromKind0({'name': ' Joachim '}), 'Joachim');
      expect(nameFromKind0({'name': ''}), isNull);
      expect(nameFromKind0({}), isNull);
    });
  });

  group('profileFromOwnKind0 (TD-59)', () {
    test('takes over name, bio and public nexus_profile fields', () {
      final generated = UserProfile.defaults('Mutiger Fuchs 42');
      final restored = profileFromOwnKind0(generated, {
        'name': 'Joachim',
        'about': 'Pionier auf Teneriffa',
        'nexus_profile': {
          'languages': ['de', 'es'],
          'skills': ['Funk'],
          'location': 'Teneriffa',
          'realName': 'Joachim R.',
          'profileImageVisibility': 'contacts',
        },
      });

      expect(restored.pseudonym.value, 'Joachim');
      expect(restored.bio.value, 'Pionier auf Teneriffa');
      expect(restored.languages.value, ['de', 'es']);
      expect(restored.skills.value, ['Funk']);
      expect(restored.location.value, 'Teneriffa');
      expect(restored.realName.value, 'Joachim R.');
      expect(restored.profileImage.visibility, VisibilityLevel.contacts);
    });

    test('does not change the original profile', () {
      final generated = UserProfile.defaults('Mutiger Fuchs 42');
      profileFromOwnKind0(generated, {'name': 'Joachim'});

      expect(generated.pseudonym.value, 'Mutiger Fuchs 42');
    });

    test('ignores the DID placeholder the app sends instead of a bio', () {
      final restored = profileFromOwnKind0(
        UserProfile.defaults('Mutiger Fuchs 42'),
        {'name': 'Joachim', 'about': 'DID: did:key:z6MkTest'},
      );

      expect(restored.bio.value, isNull);
    });

    test('a decoded picture becomes the public profile image', () {
      final restored = profileFromOwnKind0(
        UserProfile.defaults('Mutiger Fuchs 42'),
        {'name': 'Joachim'},
        picturePath: '/tmp/profile.jpg',
      );

      expect(restored.profileImage.value, '/tmp/profile.jpg');
      expect(restored.profileImage.visibility, VisibilityLevel.public);
    });

    test('missing fields keep their current values', () {
      final profile = UserProfile.defaults('Joachim')
        ..bio = ProfileField<String?>(
          value: 'Alte Bio',
          visibility: VisibilityLevel.public,
          updatedAt: DateTime(2026),
        );
      final restored = profileFromOwnKind0(profile, {'name': ''});

      expect(restored.pseudonym.value, 'Joachim');
      expect(restored.bio.value, 'Alte Bio');
    });
  });

  group('restore pending flag', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is off by default and survives as set', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await isProfileRestorePending(prefs), isFalse);

      await setProfileRestorePending(true, prefs);
      expect(await isProfileRestorePending(prefs), isTrue);

      await setProfileRestorePending(false, prefs);
      expect(await isProfileRestorePending(prefs), isFalse);
      expect(prefs.containsKey(profileRestorePendingKey), isFalse);
    });
  });
}
