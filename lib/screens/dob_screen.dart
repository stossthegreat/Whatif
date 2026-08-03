import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/analytics.dart';
import '../state/session.dart';
import '../theme/tokens.dart';
import '../widgets/aurora.dart';
import '../widgets/glass.dart';
import 'onboarding_shell.dart';

/// The age gate. A tickbox saying "I'm 18+" is the weakest gate there is and
/// gives us no real age to match on — a date of birth gives us both.
///
/// Under 18 is a HARD stop, and the rejection is remembered: coming back and
/// typing a different year doesn't work.
class DobScreen extends StatefulWidget {
  const DobScreen({super.key, required this.onDone, required this.onBack, required this.onRejected});
  final ValueChanged<DateTime> onDone;
  final VoidCallback onBack;
  final VoidCallback onRejected;

  @override
  State<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends State<DobScreen> {
  // land the wheel somewhere plausible rather than on today's date
  late DateTime _value = DateTime(DateTime.now().year - 20, 6, 15);

  int get _age {
    final now = DateTime.now();
    var a = now.year - _value.year;
    final hadBirthday = now.month > _value.month ||
        (now.month == _value.month && now.day >= _value.day);
    if (!hadBirthday) a--;
    return a;
  }

  void _submit() {
    if (_age < 18) {
      Track.event('age_gate_blocked');
      AppSession.instance.setDobRejected();
      widget.onRejected();
      return;
    }
    widget.onDone(_value);
  }

  @override
  Widget build(BuildContext context) {
    final ok = _age >= 18;
    return OnboardStep(
      step: 1,
      total: 7,
      title: 'When were you born?',
      accent: 'born',
      sub: 'Rivlr is strictly 18+. Your birthday is never shown to anyone — '
          'we use it to keep this place adults-only and to match you better.',
      scrollable: false,
      onBack: widget.onBack,
      ctaLabel: ok ? 'Continue' : 'You must be 18+',
      onCta: ok ? _submit : null,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                brightness: Brightness.dark,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle:
                      TextStyle(fontSize: 21, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _value,
                minimumDate: DateTime(1920),
                maximumDate: DateTime.now(),
                onDateTimeChanged: (d) => setState(() => _value = d),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedOpacity(
            duration: M.quick,
            opacity: ok ? 1 : 0.55,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: C.glass,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: ok ? C.hair2 : C.live.withOpacity(0.6)),
              ),
              child: Text(
                ok ? "You're $_age" : 'Under 18 — you can’t use Rivlr yet',
                style: T.body.copyWith(
                  color: ok ? Colors.white : C.live,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Terminal screen for anyone under 18. Deliberately a dead end — no CTA back
/// into the flow.
class AgeBlockedScreen extends StatelessWidget {
  const AgeBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: C.black,
      body: Stack(
        children: [
          const Aurora(orbs: 2, opacity: 0.4),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  const Wordmark(size: 34),
                  const Spacer(),
                  Text('Come back\nwhen you’re 18.', style: T.huge(38 * r.scale)),
                  const SizedBox(height: 16),
                  Text(
                    'Rivlr is an adults-only app — everyone here has confirmed '
                    'they’re 18 or over, and we keep it that way. We’ll be here.',
                    style: T.body.copyWith(fontSize: 16, height: 1.5),
                  ),
                  const Spacer(),
                  Center(
                    child: Text('m2mb@info.com', style: T.tiny),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
