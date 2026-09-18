import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/slot_form_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chip_option.dart';
import '../widgets/labeled_field.dart';
import '../widgets/primary_button.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _registerMode = false;
  bool _forgotMode = false;
  // No role pre-selected — registering requires an explicit choice.
  String? _role;
  bool _submitting = false;

  // Trainer slot-creation defaults, chosen at sign-up.
  String _defaultDuration = '45';
  SlotFormMode _defaultMode = SlotFormMode.single;
  String _defaultRepeat = 'Einmalig';

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  final _facility = TextEditingController();
  final _resetEmail = TextEditingController();
  final _resetCode = TextEditingController();
  final _newPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _facility.dispose();
    _resetEmail.dispose();
    _resetCode.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (_registerMode && _role == null) return;
    setState(() => _submitting = true);
    final ok = _registerMode
        ? await (_role == 'trainer'
              ? app.registerTrainer(
                  email: _email.text.trim(),
                  password: _password.text,
                  fullName: _fullName.text.trim(),
                  facility: _facility.text.trim(),
                  defaultDurationMinutes: int.tryParse(_defaultDuration),
                  defaultSlotMode: slotModeToString(_defaultMode),
                  defaultRepeat: _defaultRepeat,
                )
              : app.registerRider(
                  email: _email.text.trim(),
                  password: _password.text,
                  fullName: _fullName.text.trim(),
                ))
        : await app.login(email: _email.text.trim(), password: _password.text);
    if (mounted) setState(() => _submitting = false);
    if (ok && mounted && _registerMode && app.needsEmailConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bitte bestätige deine E-Mail-Adresse, um dich anzumelden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isTrainer = _role == 'trainer';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: SizedBox(
                  height: 210,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/hero_horse.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.black.withValues(alpha: .35),
                              Colors.transparent,
                            ],
                            stops: const [0, .5],
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: .4),
                            ],
                            stops: const [.7, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 18,
                        child: Text(
                          'Galoppal',
                          style:
                              AppTextStyles.serif(
                                size: 24,
                                color: AppColors.green,
                                letterSpacing: -.3,
                              ).copyWith(
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: .8),
                                    blurRadius: 10,
                                  ),
                                  Shadow(
                                    color: Colors.white.withValues(alpha: .8),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              if (_forgotMode)
                _ResetPasswordBlock(
                  app: app,
                  resetEmail: _resetEmail,
                  resetCode: _resetCode,
                  newPassword: _newPassword,
                  onBackToLogin: () {
                    app.beginPasswordReset();
                    setState(() => _forgotMode = false);
                  },
                )
              else ...[
                Text(
                  _registerMode ? 'Konto\nerstellen.' : 'Willkommen\nzurück.',
                  style: AppTextStyles.serif(
                    size: 34,
                    height: 1.12,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _registerMode
                      ? 'Erstelle dein Konto, um Stunden zu planen oder zu buchen.'
                      : 'Melde dich an, um Stunden zu planen oder zu buchen.',
                  style: AppTextStyles.sans(
                    size: 13.5,
                    color: AppColors.inkFaint(.6),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_registerMode) ...[
                      LabeledField(
                        label: 'Name',
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 10),
                    ],
                    LabeledField(
                      label: 'E-Mail',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    LabeledField(
                      label: 'Passwort',
                      controller: _password,
                      obscureText: true,
                    ),
                    if (_registerMode && isTrainer) ...[
                      const SizedBox(height: 10),
                      LabeledField(
                        label: 'Bezeichnung deines Standard-Trainingsorts',
                        controller: _facility,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'z. B. „Reitanlage Sonnenhof" — der Ort, den du '
                        'normalerweise für deine Stunden nutzt.',
                        style: AppTextStyles.sans(
                          size: 11,
                          color: AppColors.inkFaint(.45),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DefaultsPicker(
                        duration: _defaultDuration,
                        mode: _defaultMode,
                        repeat: _defaultRepeat,
                        onDuration: (v) => setState(() => _defaultDuration = v),
                        onMode: (v) => setState(() => _defaultMode = v),
                        onRepeat: (v) => setState(() => _defaultRepeat = v),
                      ),
                    ],
                  ],
                ),
                if (!_registerMode) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        app.beginPasswordReset();
                        _resetEmail.text = _email.text.trim();
                        setState(() => _forgotMode = true);
                      },
                      child: Text(
                        'Passwort vergessen?',
                        style: AppTextStyles.sans(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ),
                ],
                if (app.authError != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    app.authError!,
                    style: AppTextStyles.sans(
                      size: 12.5,
                      color: const Color(0xFFB3261E),
                    ),
                  ),
                ],
                if (app.needsEmailConfirmation) ...[
                  const SizedBox(height: 14),
                  _ResendConfirmationCard(app: app),
                ],
                if (_registerMode) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Ich bin …',
                    style: AppTextStyles.sans(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.inkFaint(.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.inkFaint(.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _RoleChip(
                          label: 'Reitlehrer',
                          selected: _role == 'trainer',
                          selectedBg: AppColors.green,
                          onTap: () => setState(() => _role = 'trainer'),
                        ),
                        _RoleChip(
                          label: 'Schüler',
                          selected: _role == 'rider',
                          selectedBg: AppColors.blue,
                          onTap: () => setState(() => _role = 'rider'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: _registerMode ? 'Konto erstellen' : 'Anmelden',
                  loading: _submitting,
                  color: _role == 'rider' ? AppColors.blue : AppColors.green,
                  onPressed: _registerMode && _role == null
                      ? null
                      : () => _submit(app),
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _registerMode = !_registerMode),
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.sans(
                          size: 12.5,
                          color: AppColors.inkFaint(.5),
                        ),
                        children: [
                          TextSpan(
                            text: _registerMode
                                ? 'Bereits ein Konto? '
                                : 'Noch kein Konto? ',
                          ),
                          TextSpan(
                            text: _registerMode ? 'Anmelden' : 'Registrieren',
                            style: AppTextStyles.sans(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultsPicker extends StatelessWidget {
  const _DefaultsPicker({
    required this.duration,
    required this.mode,
    required this.repeat,
    required this.onDuration,
    required this.onMode,
    required this.onRepeat,
  });

  final String duration;
  final SlotFormMode mode;
  final String repeat;
  final ValueChanged<String> onDuration;
  final ValueChanged<SlotFormMode> onMode;
  final ValueChanged<String> onRepeat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STANDARDS FÜR NEUE STUNDEN',
          style: AppTextStyles.eyebrow(color: AppColors.inkFaint(.42)),
        ),
        const SizedBox(height: 3),
        Text(
          'Voreinstellungen beim Erstellen — jederzeit pro Stunde änderbar.',
          style: AppTextStyles.sans(
            size: 11,
            color: AppColors.inkFaint(.45),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Dauer',
          style: AppTextStyles.sans(size: 12, color: AppColors.inkFaint(.55)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in kSlotDurations) ...[
              ChipOption(
                label: '$d Min',
                selected: duration == d,
                onTap: () => onDuration(d),
                selectedBg: AppColors.green,
                fillWidth: true,
              ),
              if (d != kSlotDurations.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Modus',
          style: AppTextStyles.sans(size: 12, color: AppColors.inkFaint(.55)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            ChipOption(
              label: 'Einzelne Stunde',
              selected: mode == SlotFormMode.single,
              onTap: () => onMode(SlotFormMode.single),
              selectedBg: AppColors.green,
              fillWidth: true,
            ),
            const SizedBox(width: 8),
            ChipOption(
              label: 'Zeitraum',
              selected: mode == SlotFormMode.range,
              onTap: () => onMode(SlotFormMode.range),
              selectedBg: AppColors.green,
              fillWidth: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Wiederholung',
          style: AppTextStyles.sans(size: 12, color: AppColors.inkFaint(.55)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final r in kSlotRepeats) ...[
              ChipOption(
                label: r,
                selected: repeat == r,
                onTap: () => onRepeat(r),
                fillWidth: true,
              ),
              if (r != kSlotRepeats.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _ResendConfirmationCard extends StatelessWidget {
  const _ResendConfirmationCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final left = app.resendSecondsLeft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.blueFaint(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wir haben dir eine Bestätigungs-E-Mail geschickt. '
            'Eine weitere kann frühestens nach 30 Sekunden gesendet werden.',
            style: AppTextStyles.sans(
              size: 12,
              color: AppColors.blueText,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: left == 0 ? app.resendConfirmationEmail : null,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              left == 0
                  ? 'E-Mail erneut senden'
                  : 'Erneut senden in $left s',
              style: AppTextStyles.sans(
                size: 12.5,
                weight: FontWeight.w600,
                color: left == 0
                    ? AppColors.green
                    : AppColors.inkFaint(.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetPasswordBlock extends StatelessWidget {
  const _ResetPasswordBlock({
    required this.app,
    required this.resetEmail,
    required this.resetCode,
    required this.newPassword,
    required this.onBackToLogin,
  });

  final AppState app;
  final TextEditingController resetEmail;
  final TextEditingController resetCode;
  final TextEditingController newPassword;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final stage = app.passwordResetStage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Passwort\nzurücksetzen.',
          style: AppTextStyles.serif(size: 34, height: 1.12, letterSpacing: -.4),
        ),
        const SizedBox(height: 10),
        Text(
          switch (stage) {
            'code' =>
              'Wir haben dir einen 6-stelligen Code per E-Mail geschickt. '
                  'Gib ihn hier ein.',
            'password' => 'Wähle jetzt ein neues Passwort.',
            _ =>
              'Gib deine E-Mail-Adresse ein — du bekommst einen Code zum '
                  'Zurücksetzen.',
          },
          style: AppTextStyles.sans(
            size: 13.5,
            color: AppColors.inkFaint(.6),
            height: 1.55,
          ),
        ),
        const SizedBox(height: 20),
        if (stage == null) ...[
          LabeledField(
            label: 'E-Mail',
            controller: resetEmail,
            keyboardType: TextInputType.emailAddress,
          ),
        ] else if (stage == 'code') ...[
          LabeledField(
            label: '6-stelliger Code',
            controller: resetCode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
        ] else ...[
          LabeledField(
            label: 'Neues Passwort',
            controller: newPassword,
            obscureText: true,
          ),
        ],
        if (app.passwordResetError != null) ...[
          const SizedBox(height: 12),
          Text(
            app.passwordResetError!,
            style: AppTextStyles.sans(
              size: 12.5,
              color: const Color(0xFFB3261E),
            ),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: switch (stage) {
            'code' => 'Code prüfen',
            'password' => 'Passwort setzen',
            _ => 'Code senden',
          },
          loading: app.passwordResetBusy,
          onPressed: app.passwordResetBusy
              ? null
              : () async {
                  switch (stage) {
                    case 'code':
                      await app.verifyPasswordResetCode(resetCode.text);
                    case 'password':
                      await app.setNewPassword(newPassword.text);
                    default:
                      await app.sendPasswordResetCode(resetEmail.text);
                  }
                },
        ),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: onBackToLogin,
            child: Text(
              'Zurück zur Anmeldung',
              style: AppTextStyles.sans(
                size: 12.5,
                weight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedBg = AppColors.green,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.sans(
                size: 13.5,
                weight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.inkFaint(.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
