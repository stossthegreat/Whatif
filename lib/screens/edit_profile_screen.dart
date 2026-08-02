import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/haptics.dart';
import '../net/api_client.dart';
import '../net/network_client.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';

/// Edit your identity — photo, bio, where you are, languages, what you're
/// looking for, what you're into. Saves to the server (setProfile) and
/// mirrors the bits the device keeps.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static void push(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
  }

  static const lookingFor = [
    '😆 Make people laugh', '🤝 Friends', '❤️ Flirting',
    '🎮 Competitive', '🌍 Meet people worldwide', '🎤 Deep conversations',
  ];
  static const interests = [
    'Gaming', 'Football', 'Gym', 'Anime', 'Music', 'Travel', 'Business',
    'Fashion', 'Memes', 'Cars', 'Cooking', 'Movies', 'Art', 'Basketball',
    'Crypto', 'Books', 'Photography', 'Dancing',
  ];
  static const languages = [
    'English', 'Spanish', 'French', 'German', 'Portuguese', 'Italian',
    'Arabic', 'Hindi', 'Turkish', 'Polish', 'Dutch', 'Russian',
  ];

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final s = AppSession.instance;
  late final _bio = TextEditingController(text: s.bio);
  late final _city = TextEditingController(text: s.city);
  late final _country = TextEditingController(text: s.country);
  late final _pronouns = TextEditingController(text: s.pronouns);
  late final Set<String> _looking = {...s.lookingForChips};
  late final Set<String> _interests = {...s.interests};
  late final Set<String> _langs = {...s.languages};
  bool _uploading = false;

  @override
  void dispose() {
    _save(); // leaving the screen saves — no lost edits, no Save button drama
    _bio.dispose();
    _city.dispose();
    _country.dispose();
    _pronouns.dispose();
    super.dispose();
  }

  void _save() {
    s.setIdentityDetails(
      bio: _bio.text.trim(),
      city: _city.text.trim(),
      country: _country.text.trim(),
      pronouns: _pronouns.text.trim(),
      lookingForChips: _looking.toList(),
      interests: _interests.toList(),
      languages: _langs.toList(),
    );
    NetworkClient.instance.setProfile({
      'bio': _bio.text.trim(),
      'city': _city.text.trim(),
      'country': _country.text.trim(),
      'pronouns': _pronouns.text.trim(),
      'lookingFor': _looking.toList(),
      'interests': _interests.toList(),
      'languages': _langs.toList(),
      if (s.age != null) 'age': s.age,
    });
  }

  Future<void> _pickPhoto() async {
    if (_uploading) return;
    Buzz.tick();
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 720, maxHeight: 720, imageQuality: 80,
      );
      if (x == null || !mounted) return;
      setState(() => _uploading = true);
      final bytes = await x.readAsBytes();
      final id = await Api.uploadMedia(bytes, kind: 'avatar', mime: 'image/jpeg');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (id != null) s.setPhotoId(id);
      });
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.char2,
          content: Text('photo didn’t upload — try again',
              style: T.body.copyWith(color: Colors.white)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
              child: Row(
                children: [
                  Press(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: C.tx2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Your identity', style: T.big.copyWith(fontSize: 24)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 40),
                children: [
                  Center(
                    child: Press(
                      haptic: false,
                      onTap: _pickPhoto,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedBuilder(
                            animation: s,
                            builder: (context, _) =>
                                Avatar(hue: s.myHue, photoId: s.photoId, size: 104, ring: C.sig),
                          ),
                          Positioned(
                            right: -2, bottom: -2,
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: C.black, width: 3),
                              ),
                              child: _uploading
                                  ? const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.black))
                                  : const Icon(Icons.camera_alt_rounded,
                                      size: 16, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _field('BIO', _bio, hint: 'one line that sounds like you', maxLen: 240, lines: 2),
                  Row(
                    children: [
                      Expanded(child: _field('CITY', _city, hint: 'London')),
                      const SizedBox(width: 10),
                      Expanded(child: _field('COUNTRY', _country, hint: 'UK')),
                    ],
                  ),
                  _field('PRONOUNS (OPTIONAL)', _pronouns, hint: 'they/them'),
                  const SizedBox(height: 8),
                  _chips('LOOKING FOR', EditProfileScreen.lookingFor, _looking),
                  _chips('LANGUAGES', EditProfileScreen.languages, _langs),
                  _chips('INTO', EditProfileScreen.interests, _interests),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl,
      {String? hint, int maxLen = 48, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.eyebrow),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: C.glass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.hair2),
            ),
            child: TextField(
              controller: ctl,
              maxLength: maxLen,
              maxLines: lines,
              style: T.body.copyWith(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: T.body.copyWith(color: C.tx3, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(String label, List<String> all, Set<String> selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: T.eyebrow),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in all)
                Press(
                  haptic: false,
                  onTap: () {
                    Buzz.tick();
                    setState(() {
                      if (!selected.remove(item)) selected.add(item);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected.contains(item) ? Colors.white : C.glass,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: selected.contains(item) ? Colors.white : C.hair2),
                    ),
                    child: Text(item,
                        style: T.tiny.copyWith(
                          color: selected.contains(item) ? Colors.black : C.tx2,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        )),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
