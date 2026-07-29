import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;
  final _scrollController = ScrollController();
  bool _scrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_scrolledToEnd &&
          _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 24) {
        setState(() => _scrolledToEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    await AuthService.instance.markTermsAccepted();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _accepted && _scrolledToEnd;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Terms & Privacy Policy')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.gavel_rounded, color: AppColors.primary600),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Please read before you continue',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const _TermsSection(
                          title: '1. Official Use Only',
                          body:
                              'This application is provisioned exclusively for authorized Union Council Governance Platform officials — Super Admin, ADLG, DDLG and Secretary UC roles. Access is granted per your official designation and jurisdiction.',
                        ),
                        const _TermsSection(
                          title: '2. Data Accuracy & Responsibility',
                          body:
                              'Every action you take — case decisions, registrations, reports, attendance — is recorded against your account with a permanent, tamper-evident timestamp. You are responsible for the accuracy of information you submit.',
                        ),
                        const _TermsSection(
                          title: '3. Confidentiality',
                          body:
                              'Case files, citizen records and internal communications accessed through this app are official and confidential. They must not be shared, screenshotted or exported outside the platform except through the app\'s own authorized channels.',
                        ),
                        const _TermsSection(
                          title: '4. Account Security',
                          body:
                              'Keep your login credentials private. You are accountable for all activity recorded under your account. Report a lost device or suspected unauthorized access to your administrator immediately.',
                        ),
                        const _TermsSection(
                          title: '5. Audit & Compliance',
                          body:
                              'All approvals, rejections and status changes made in this app are logged to the platform\'s audit trail, visible to supervisory roles, and may be used for compliance review.',
                        ),
                        const _TermsSection(
                          title: '6. Availability',
                          body:
                              'While the platform is built for reliability, features depending on network connectivity may be temporarily unavailable. Critical time-bound actions should not be left to the last moment.',
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _accepted = !_accepted),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _accepted,
                              onChanged: (v) => setState(() => _accepted = v ?? false),
                            ),
                            const Expanded(
                              child: Text(
                                'I have read and agree to the Terms of Use and Privacy Policy',
                                style: TextStyle(fontSize: 13, color: AppColors.inkMuted, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!_scrolledToEnd)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Scroll to the end to continue',
                          style: TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w600),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canContinue ? _continue : null,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.inkMuted)),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}
