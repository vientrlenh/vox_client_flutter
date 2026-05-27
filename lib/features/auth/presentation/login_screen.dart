
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  
  @override
  State<StatefulWidget> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool rememberMe = true;
  bool obscurePassword = true;

  final _authRepository = AuthRepository(
    authApi: AuthApi(ApiClient()),
    secureStorage: SecureStorage()
  );

  Future<void> _login() async {
    try {
      await _authRepository.login(login: _loginController.text, password: _passwordController.text);
    } catch (e) {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06135F), Color(0xFF10108C), Color(0xFF5207D8)],
          )
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 100,
                      height: 70,
                      fit: BoxFit.contain
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Chào mừng trở lại',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w700
                      )
                    ),
                    const SizedBox(height: 12),
                    const Text.rich(
                      TextSpan(
                        text: 'Đăng nhập để tiếp tục quản lý và ',
                        style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600
                        ),
                        children: [
                          TextSpan(
                            text: "đánh giá bài thi nói với AI",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 18,
                              fontWeight: FontWeight.w600
                            )
                          )
                        ]
                      ) 
                    ),
                    const SizedBox(height: 36),
                    _buildLoginCard(),
                    const SizedBox(height: 26),
                    const Text(
                      '© 2026 VOX. Tất cả quyền được bảo lưu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 14
                      )
                    )
                  ],
                )
              )
            )
          ],
        ),
      )
    );
  }
  
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24, 
            offset: Offset(0, 16)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Email / Số điện thoại'),
          const SizedBox(height: 10),
          _field(
            Icons.mail_outline_rounded, 
            'Nhập email hoặc số điện thoại của bạn'
          ),
          const SizedBox(height: 10),
          _label("Mật khẩu"),
          const SizedBox(height: 10),
          _field(
            Icons.lock_outline_rounded, 
            'Nhập mật khẩu',
            obscure: obscurePassword, 
            suffix: IconButton(
              onPressed: () => setState(() => obscurePassword = !obscurePassword
              ), 
              icon: Icon(
                obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF697083),
              )
            )
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: rememberMe,
                onChanged: (value) => setState(() => rememberMe = value ?? false),
                activeColor: const Color(0xFF2563EB),
              ),
              const Expanded(
                child: Text(
                  'Ghi nhớ đăng nhập',
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600
                  )
                )
              ),
              TextButton(
                onPressed: (){},
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    color: Color(0xFF5B21D9), 
                    fontWeight: FontWeight.w600
                  )
                )
              )
            ],
          ),
          const SizedBox(height: 15),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1688FF), Color(0xFF7517F8)]
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ElevatedButton.icon(
              onPressed: () => _login(),
              icon: const Icon(
                Icons.arrow_forward_rounded
              ),
              label: Text('Đăng nhập'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w800
                ),
              )
            ),
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('hoặc'),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52)
            ),
            child: const Text(
              'G Đăng nhập bằng Google',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 25),
          const Center(
            child: Text.rich(
              TextSpan(
                text: 'Chưa có tài khoản? ',
                style: TextStyle(color: Color(0xFF597083)),
                children: [
                  TextSpan(
                    text: 'Liên hệ nhà trường / Đăng ký',
                    style: TextStyle(
                      color: Color(0xFF5B21D9),
                      fontWeight: FontWeight.w700
                    )
                  )
                ]
              )
            )
          )
        ],
      )
    );
  }

  Widget _label(String text) {
    return Text(
      text, 
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700
      )
    );
  }

  Widget _field(IconData icon, String hint, {bool obscure = false, Widget? suffix}) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10)
        )
      ),
    );
  }
}

