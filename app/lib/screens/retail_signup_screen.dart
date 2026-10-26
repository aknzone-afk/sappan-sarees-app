import 'dart:async';

import 'package:catalog_app/widgets/caps_text.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/account_service.dart';
import '../services/order_service.dart';
import '../theme.dart';

/// ============================================================
/// SAPPAN SAREES SIGN-UP (owner 25-Oct-2026) — retail customers.
/// Name, mobile, address, pincode → straight into the catalogue.
/// No WhatsApp code, no approval, no GST / ID / business proof, no
/// transport. The same number signing up again simply updates its details.
/// ============================================================
class RetailSignupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const RetailSignupScreen({super.key, required this.onDone});

  @override
  State<RetailSignupScreen> createState() => _RetailSignupScreenState();
}

class _RetailSignupScreenState extends State<RetailSignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();
  final _dio = Dio();

  PincodeInfo? _pin;
  bool _pinChecking = false;
  bool _pinNotFound = false;
  Timer? _pinDebounce;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pincode.addListener(_onPin);
  }

  @override
  void dispose() {
    _pinDebounce?.cancel();
    for (final c in [_name, _mobile, _address, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPin() {
    _pinDebounce?.cancel();
    final pin = _pincode.text.trim();
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(pin)) {
      if (_pin != null || _pinNotFound) {
        setState(() {
          _pin = null;
          _pinNotFound = false;
        });
      }
      return;
    }
    _pinDebounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _pinChecking = true);
      try {
        final info = await OrderService.lookupPincode(_dio, pin);
        if (!mounted || _pincode.text.trim() != pin) return;
        setState(() {
          _pin = info;
          _pinNotFound = info == null;
        });
      } catch (_) {
        // Offline: never block the sign-up.
        if (mounted) setState(() => _pinNotFound = false);
      } finally {
        if (mounted) setState(() => _pinChecking = false);
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_pinNotFound) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This pincode does not exist. Please check it.')));
      return;
    }
    setState(() => _busy = true);
    final mobile = OrderService.normalizeIndianMobile(_mobile.text)!;
    final cust = <String, dynamic>{
      'name': _name.text.trim(),
      'billName': _name.text.trim(),
      'address': _address.text.trim(),
      'pincode': _pincode.text.trim(),
      'city': _pin?.district ?? '',
      'state': _pin?.state ?? '',
      'country': 'India',
    };
    // Tell the shop (best effort — no internet never stops the customer).
    await AccountService.retailSignup(mobile, cust);
    final prefs = await SharedPreferences.getInstance();
    await AccountService.approve(prefs, {
      'mobile': mobile,
      'india': true,
      'kind': 'retail',
      'cust': cust,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone();
  }

  InputDecoration _dec(String label, {String? hint, Widget? prefix, String? helper, Color? helperColor}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefix: prefix,
        helperText: helper,
        helperStyle: helperColor == null ? null : TextStyle(color: helperColor),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    String? pinHelper;
    Color? pinColor;
    if (_pinChecking) {
      pinHelper = 'Checking pincode…';
    } else if (_pinNotFound) {
      pinHelper = '✗ This pincode does not exist';
      pinColor = Theme.of(context).colorScheme.error;
    } else if (_pin != null) {
      pinHelper = '📍 ${_pin!.label}';
      pinColor = const Color(0xFF2E7D32);
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ClipOval(child: Image.asset('assets/icon/sappan_mark.png', width: 104, height: 104))),
                    const SizedBox(height: 14),
                    const UText(
                      'Sappan Sarees',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Playfair',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: kMaroon),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'THE FINEST WEAVES OF INDIA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 3.2, color: kGold),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'A curated house of designer sarees — zari and thread embroidery, '
                      'Swarovski and sequin work, Banarasi and organza weaves, bandhej, '
                      'mirror work and more. Delivered to your door, anywhere in India. '
                      'Begin with just one saree.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, height: 1.55, color: kInk),
                    ),
                    const SizedBox(height: 16),
                    const HouseCrafts(compact: true),
                    const SizedBox(height: 26),
                    const Text('Sign up — takes 30 seconds',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Your Name *'),
                      validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: _dec('Mobile No. *', prefix: const Text('+91 ')),
                      validator: (v) => OrderService.validateMobile(v ?? '', india: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _address,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.words,
                      decoration: _dec('Full Address *', hint: 'House no., street, area, city'),
                      validator: (v) => (v ?? '').trim().length < 5 ? 'Enter full address' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pincode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: _dec('Pincode *', helper: pinHelper, helperColor: pinColor),
                      validator: (v) => OrderService.validatePincode(v ?? '', india: true),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.arrow_forward_rounded),
                        label: const UText('START SHOPPING',
                            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(kPrivacyUrl), mode: LaunchMode.externalApplication),
                      child: const Text('Privacy policy'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// India's great weaves, one gold-edged card each (signup + shop card).
class HeritageWeaves extends StatelessWidget {
  const HeritageWeaves({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in kHeritageWeaves)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kLinen,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGold, width: 0.8),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(w.weave,
                  style: const TextStyle(
                      fontFamily: 'Playfair', fontSize: 13.5, fontWeight: FontWeight.w700, color: kMaroon)),
              const SizedBox(height: 1),
              Text(w.region.toUpperCase(),
                  style: const TextStyle(fontSize: 9.5, letterSpacing: 1.6, color: kInk)),
            ]),
          ),
      ],
    );
  }
}

/// The crafts of the house — name + one line each (home + sign-up).
class HouseCrafts extends StatelessWidget {
  final bool compact;
  const HouseCrafts({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in kHouseCrafts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: kLinen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kGold, width: 0.8),
              ),
              child: Text(c.craft,
                  style: const TextStyle(
                      fontFamily: 'Playfair', fontSize: 13.5, fontWeight: FontWeight.w700, color: kMaroon)),
            ),
        ],
      );
    }
    return Column(children: [
      for (final c in kHouseCrafts)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: kPaper,
            border: Border.all(color: kHairline, width: 0.8),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 2, height: 34, color: kGold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.craft,
                    style: const TextStyle(
                        fontFamily: 'Playfair', fontSize: 16, fontWeight: FontWeight.w700, color: kMaroon)),
                const SizedBox(height: 3),
                Text(c.line, style: const TextStyle(fontSize: 13, height: 1.45, color: kInk)),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
