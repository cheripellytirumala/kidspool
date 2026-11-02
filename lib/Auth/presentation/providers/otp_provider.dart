import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../common/core/router/onboarding_route.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_flow_provider.dart';

/// State of the S03a "Enter the code" sheet: sends the code with
/// `request-otp`, verifies it with `verify-otp` and runs the resend
/// countdown. One instance per sheet.
class OtpProvider extends ChangeNotifier {
  OtpProvider({
    required AuthRepository repository,
    required AccountRepository account,
    required AuthFlowProvider flow,
  }) : _repository = repository,
       _account = account,
       _flow = flow;

  final AuthRepository _repository;
  final AccountRepository _account;
  final AuthFlowProvider _flow;

  static const int codeLength = 6;

  String _code = '';
  bool _autoFilled = false;
  bool _sending = false;
  int _resendSeconds = 0;
  ViewStatus _status = ViewStatus.initial;
  String? _errorMessage;
  Timer? _countdown;
  bool _disposed = false;

  String get code => _code;
  bool get isComplete => _code.length == codeLength;

  /// True while the code came from the server (demo mode) and was not edited.
  bool get autoFilled => _autoFilled;
  bool get isVerifying => _status.isLoading;
  bool get isSending => _sending;
  bool get canResend => _resendSeconds == 0 && !_sending;
  String? get errorMessage => _errorMessage;

  /// "0:24".
  String get resendCountdown {
    final minutes = _resendSeconds ~/ 60;
    final seconds = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Asks `request-otp` to send a code to the phone from S03.
  Future<void> start() async {
    if (_sending) return;
    _sending = true;
    _errorMessage = null;
    _notify();

    final result = await _repository.requestOtp(_flow.e164Phone);
    _sending = false;
    result.match(
      (failure) {
        _errorMessage = failure.message;
        final retryAfter = failure.data['retryAfter'];
        if (failure.code == 'resend_too_soon' && retryAfter is num) {
          _startCountdown(retryAfter.toInt());
        }
      },
      (request) {
        _startCountdown(request.resendAfter);
        // No SMS provider yet: the backend returns the code in demo mode.
        final demo = request.demoCode;
        if (demo != null && _code.isEmpty) {
          _code = demo;
          _autoFilled = true;
        }
      },
    );
    _notify();
  }

  void setCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final next = digits.length > codeLength
        ? digits.substring(0, codeLength)
        : digits;
    if (next == _code) return;
    _code = next;
    _autoFilled = false;
    _errorMessage = null;
    _notify();
  }

  Future<void> resend() async {
    if (!canResend) return;
    _code = '';
    _autoFilled = false;
    await start();
  }

  /// Verifies the code, stores the session and loads the account status.
  /// Returns the route to continue to, or `null` on failure.
  Future<String?> verify() async {
    if (!isComplete || isVerifying) return null;
    _status = ViewStatus.loading;
    _errorMessage = null;
    _notify();

    final verified = await _repository.verifyOtp(
      phone: _flow.e164Phone,
      code: _code,
    );
    final verifyError = verified.getLeft().toNullable();
    if (verifyError != null) {
      _status = ViewStatus.failure;
      _errorMessage = verifyError.message;
      _notify();
      return null;
    }

    final status = await _account.getMyStatus();
    return status.match(
      (failure) {
        _status = ViewStatus.failure;
        _errorMessage = failure.message;
        _notify();
        return null;
      },
      (myStatus) {
        _flow.applyStatus(myStatus);
        _status = ViewStatus.success;
        _notify();
        return OnboardingRoute.of(myStatus);
      },
    );
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _resendSeconds = seconds;
    if (seconds <= 0) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resendSeconds--;
      if (_resendSeconds <= 0) {
        _resendSeconds = 0;
        timer.cancel();
      }
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdown?.cancel();
    super.dispose();
  }
}
