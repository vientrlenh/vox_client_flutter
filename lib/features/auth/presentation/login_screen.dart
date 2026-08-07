import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/device/device_info_service.dart';
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
  final _formKey = GlobalKey<FormState>();
  // Điền sẵn tài khoản học sinh demo (seed bằng DemoEducationDataInitializer, bật qua
  // `demo-data.enabled=true` -- đã bật sẵn trong vox/.env) để test nhanh -- XOÁ 2 dòng
  // default text này trước khi build bản thật.
  final _loginController = TextEditingController(text: 'student1a.demosch01@vox.demo');
  final _passwordController = TextEditingController(text: 'Password@123');
  bool rememberMe = true;
  bool obscurePassword = true;
  bool isLoggingIn = false;
  bool isGoogleLoggingIn = false;

  final _googleSignIn = GoogleSignIn.instance;

  final _authRepository = AuthRepository(
    authApi: AuthApi(ApiClient()),
    secureStorage: SecureStorage(),
  );

  Future<void> _login() async {
    final deviceInfo = await DeviceInfoService().getDeviceInfo();
    if (!_formKey.currentState!.validate() || isLoggingIn || deviceInfo == null) {
      return;
    }

    setState(() => isLoggingIn = true);

    try {
      await _authRepository.login(
        login: _loginController.text.trim(),
        password: _passwordController.text,
        device: deviceInfo,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.shell);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoggingIn = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _googleSignIn.initialize(serverClientId: dotenv.get('GOOGLE_SERVER_CLIENT_ID'));
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithGoogle() async {
    if (isGoogleLoggingIn) return;
    final deviceInfo = await DeviceInfoService().getDeviceInfo();
    if (deviceInfo == null) return;

    setState(() => isGoogleLoggingIn = true);
    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('No Google ID token returned');

      await _authRepository.loginWithGoogle(idToken: idToken, device: deviceInfo);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.shell);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập Google thất bại.')),
      );
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập Google thất bại.')),
      );
    } finally {
      if (mounted) setState(() => isGoogleLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                _buildBrand(),
                const SizedBox(height: 34),
                _buildHeading(),
                const SizedBox(height: 26),
                _label('Email'),
                const SizedBox(height: 8),
                _field(
                  icon: Icons.mail_outline_rounded,
                  hint: 'Nhập email của bạn',
                  isPassword: false,
                ),
                const SizedBox(height: 16),
                _label('Mật khẩu'),
                const SizedBox(height: 8),
                _field(
                  icon: Icons.lock_outline_rounded,
                  hint: 'Nhập mật khẩu',
                  isPassword: true,
                  obscure: obscurePassword,
                  suffix: IconButton(
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF999999),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _buildRememberRow(),
                const SizedBox(height: 22),
                _buildPrimaryButton(),
                _buildDivider(),
                _buildGoogleButton(),
                const SizedBox(height: 22),
                _buildSignupLine(),
                _buildSecurityNote(),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    '© 2026 VOX. Tất cả quyền được bảo lưu.',
                    style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset('assets/logo-v2.png', height: 32, fit: BoxFit.contain),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chào mừng trở lại',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            text: 'Đăng nhập để tiếp tục quản lý và ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF888888), height: 1.5),
            children: [
              TextSpan(
                text: 'đánh giá bài thi nói với AI',
                style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
    );
  }

  Widget _field({
    required IconData icon,
    required String hint,
    required bool isPassword,
    bool obscure = false,
    Widget? suffix,
  }) {
    final controller = isPassword ? _passwordController : _loginController;

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isPassword ? null : TextInputType.emailAddress,
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: isPassword ? (_) => _login() : null,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return isPassword ? 'Vui lòng nhập mật khẩu' : 'Vui lòng nhập email';
        }
        return null;
      },
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111111)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFF999999), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF4F4F4),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.indigo, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRememberRow() {
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() => rememberMe = !rememberMe),
          borderRadius: BorderRadius.circular(7),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: rememberMe ? AppColors.indigo : const Color(0xFFF4F4F4),
                  border: rememberMe ? null : Border.all(color: const Color(0xFFE8E8E8), width: 1.5),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: rememberMe
                    ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              const Text(
                'Ghi nhớ đăng nhập',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
          child: Text(
            'Quên mật khẩu?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.indigo),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.indigo,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.indigo.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoggingIn ? null : _login,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoggingIn
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFECECEC))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('hoặc', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFAAAAAA))),
          ),
          Expanded(child: Divider(color: Color(0xFFECECEC))),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: isGoogleLoggingIn ? null : _loginWithGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Color(0xFFE6E6E6), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: isGoogleLoggingIn
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF333333)),
            )
          : const Text(
              'Đăng nhập bằng Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
            ),
    );
  }

  Widget _buildSignupLine() {
    return Center(
      child: Text.rich(
        TextSpan(
          text: 'Chưa có tài khoản? ',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
          children: [
            TextSpan(
              text: 'Liên hệ nhà trường / Đăng ký',
              style: TextStyle(color: AppColors.indigo, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.chipBlueBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_outlined, color: AppColors.indigo, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thông tin của bạn được bảo mật tuyệt đối.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                ),
                SizedBox(height: 2),
                Text(
                  'Truy cập được kiểm soát theo vai trò và quyền hạn.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF999999), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
