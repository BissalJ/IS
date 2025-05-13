import 'package:flutter/material.dart';
import 'package:fingerprint_auth_app/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cmsIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _registerUser() async {
    try {
      final name = _nameController.text.trim();
      final cmsId = _cmsIdController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (name.isEmpty || cmsId.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All fields are required')),
        );
        return;
      }

      if (!RegExp(r'^\d{6}$').hasMatch(cmsId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CMS ID must be exactly 6 digits')),
        );
        return;
      }

      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address')),
        );
        return;
      }

      if (password.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password must be at least 8 characters long')),
        );
        return;
      }

      if (!RegExp(
              r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$')
          .hasMatch(password)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Password must contain at least one letter, one number and one special character')),
        );
        return;
      }

      setState(() => _loading = true);

      final authService = AuthService();
      final result =
          await authService.registerUser(email, password, name, cmsId);

      if (!mounted) return;
      setState(() => _loading = false);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registration successful. Please log in.')),
        );
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: ${e.toString()}')),
      );
    }
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboardType, int? maxLength}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF395075),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        counterText: '',
        suffixIcon: label == 'Password'
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final hasMinLength = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[@$!%*#?&]').hasMatch(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password must contain:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              hasMinLength ? Icons.check_circle : Icons.error,
              color: hasMinLength ? Colors.green : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '8 characters minimum',
              style: TextStyle(
                color: hasMinLength ? Colors.green : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              hasLetter ? Icons.check_circle : Icons.error,
              color: hasLetter ? Colors.green : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'At least one letter',
              style: TextStyle(
                color: hasLetter ? Colors.green : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              hasNumber ? Icons.check_circle : Icons.error,
              color: hasNumber ? Colors.green : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'At least one number',
              style: TextStyle(
                color: hasNumber ? Colors.green : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              hasSpecialChar ? Icons.check_circle : Icons.error,
              color: hasSpecialChar ? Colors.green : Colors.white70,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              'At least one special character (@\$!%*#?&)',
              style: TextStyle(
                color: hasSpecialChar ? Colors.green : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C3E5D),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E5D),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Register Account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                _buildTextField(_nameController, 'Name', Icons.person),
                const SizedBox(height: 16),
                _buildTextField(_cmsIdController, 'CMS ID (6 digits)',
                    Icons.confirmation_number,
                    keyboardType: TextInputType.number, maxLength: 6),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', Icons.email,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Password', Icons.lock,
                    obscure: _obscurePassword),
                const SizedBox(height: 8),
                _buildPasswordRequirements(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CA6D1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Register',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cmsIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
