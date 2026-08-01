import 'package:flutter/material.dart';
import '../core/haptics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/glass.dart';

/// The onboarding questions: age (18+ gate), gender, and who you want to meet —
/// the signals matchmaking needs. Sleek, one screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _age = 18;
  String? _gender;
  String _lookingFor = 'Everyone';

  static const _genders = ['Woman', 'Man', 'Nonbinary', 'Other'];
  static const _prefs = ['Everyone', 'Women', 'Men'];

  bool get _ready => _gender != null && _age >= 18;

  void _continue() {
    AppSession.instance.setProfile(age: _age, gender: _gender, lookingFor: _lookingFor);
    Buzz.commit();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('A few quick\nthings.', style: T.huge(38 * r.scale)),
              const SizedBox(height: 8),
              Text('Rivlr is 18+. This helps us match you well.', style: T.sub),
              const SizedBox(height: 30),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HOW OLD ARE YOU?', style: T.eyebrow),
                      const SizedBox(height: 12),
                      _AgeStepper(
                        age: _age,
                        onChanged: (v) { Buzz.tick(); setState(() => _age = v); },
                      ),
                      const SizedBox(height: 28),
                      Text('YOU ARE', style: T.eyebrow),
                      const SizedBox(height: 12),
                      _Chips(
                        options: _genders,
                        selected: _gender,
                        onTap: (v) { Buzz.tick(); setState(() => _gender = v); },
                      ),
                      const SizedBox(height: 28),
                      Text('YOU WANT TO MEET', style: T.eyebrow),
                      const SizedBox(height: 12),
                      _Chips(
                        options: _prefs,
                        selected: _lookingFor,
                        onTap: (v) { Buzz.tick(); setState(() => _lookingFor = v); },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              Press(
                haptic: false,
                onTap: _ready ? _continue : null,
                child: Opacity(
                  opacity: _ready ? 1 : 0.4,
                  child: Container(
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text('Continue', style: T.h3.copyWith(color: Colors.black, fontSize: 17)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeStepper extends StatelessWidget {
  const _AgeStepper({required this.age, required this.onChanged});
  final int age;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _round(Icons.remove_rounded, age > 18 ? () => onChanged(age - 1) : null),
        Expanded(
          child: Center(
            child: Text('$age', style: T.mono.copyWith(fontSize: 56)),
          ),
        ),
        _round(Icons.add_rounded, age < 99 ? () => onChanged(age + 1) : null),
      ],
    );
  }

  Widget _round(IconData icon, VoidCallback? onTap) {
    return Press(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: C.glass, border: Border.all(color: C.hair2)),
          child: Icon(icon, color: C.tx),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.selected, required this.onTap});
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          Press(
            haptic: false,
            onTap: () => onTap(o),
            child: AnimatedContainer(
              duration: M.quick,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: selected == o ? C.glass2 : C.glass,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: selected == o ? C.sig : C.hair, width: selected == o ? 2 : 1),
              ),
              child: Text(o, style: T.body.copyWith(
                color: selected == o ? C.tx : C.tx2, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
      ],
    );
  }
}
