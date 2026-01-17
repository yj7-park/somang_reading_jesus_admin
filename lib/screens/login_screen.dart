import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isCodeSent = false;
  String? _verificationId;
  String? _errorMessage;

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = "휴대폰 번호를 입력해 주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Basic formatting for Korean phone numbers if missing +82
      String formattedPhone = phone;
      if (!phone.startsWith('+')) {
        if (phone.startsWith('0')) {
          formattedPhone = '+82${phone.substring(1)}';
        } else {
          formattedPhone = '+82$phone';
        }
      }

      await _authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        onCodeSent: (verificationId) {
          setState(() {
            _isLoading = false;
            _isCodeSent = true;
            _verificationId = verificationId;
          });
        },
        onVerificationFailed: (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = "인증번호 발송 실패: ${e.message}";
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "오류가 발생했습니다: $e";
      });
    }
  }

  Future<void> _verifyAndLogin() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) {
      setState(() => _errorMessage = "인증번호를 입력해 주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithCredential(_verificationId!, otp);

      // Verify admin role
      final isAdmin = await _authService.isAdmin();
      if (!isAdmin) {
        final uid = _authService.currentUser?.uid;
        await _authService.signOut();
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isCodeSent = false;
            _errorMessage =
                "관리 권한이 없는 계정입니다.\nUID: $uid\n(Firestore에 위 UID로 문서를 생성하고 role: 'admin'을 추가해 주세요.)";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "로그인 실패: 인증번호를 확인해 주세요.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxCircle.circle,
                ),
                child: Image.asset(
                  'assets/icon/official_icon_transparent.png',
                  width: 100,
                  height: 100,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                "리딩지저스 매니저",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "리딩지저스 통독 관리 시스템",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!_isCodeSent)
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "휴대폰 번호",
                    prefixIcon: Icon(Icons.phone_android_outlined),
                    border: OutlineInputBorder(),
                    hintText: "01012345678",
                  ),
                  keyboardType: TextInputType.phone,
                  onSubmitted: (_) => _sendCode(),
                )
              else
                TextField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: "인증번호 (6자리)",
                    prefixIcon: Icon(Icons.lock_clock_outlined),
                    border: OutlineInputBorder(),
                    hintText: "123456",
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _verifyAndLogin(),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_isCodeSent ? _verifyAndLogin : _sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isCodeSent ? "인증 및 로그인" : "인증번호 발송",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (_isCodeSent)
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _isCodeSent = false;
                          _errorMessage = null;
                        }),
                  child: const Text("번호 다시 입력하기"),
                ),
              const SizedBox(height: 20),
              Text(
                "Copy Right © 2026 소망교회",
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fixed some typos in the above manual decoration attempt
class BoxCircle {
  static const BoxShape circle = BoxShape.circle;
}

class RoundedRectangleArray {
  static BorderRadius circular(double r) => BorderRadius.circular(r);
}
