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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset('assets/icon/ic_launcher.png', width: 96, height: 96),
                    ),
                    const SizedBox(height: 14),
                    const UText(
                      'Sappan Sarees',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Playfair',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: kInk),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sarees direct from Surat — order even one saree.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
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
