import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'biometric_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final BiometricAuthService _authService = BiometricAuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _authStatus = 'Enter your details';
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _authStatus = 'Initializing...';
    });

    try {
      // Ensure clean state
      await _firebaseAuth.signOut();
      await _checkAuthState();
    } catch (e) {
      setState(() {
        _authStatus = 'Error initializing: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _checkAuthState() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Check if this is a biometric-authenticated user
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            _isAuthenticated = true;
            _authStatus = 'Welcome back!';
          });
        } else {
          // If no user document exists, sign out
          await _firebaseAuth.signOut();
          setState(() {
            _isAuthenticated = false;
            _authStatus = 'Please register or login';
          });
        }
      } else {
        setState(() {
          _isAuthenticated = false;
          _authStatus = 'Please register or login';
        });
      }
    } catch (e) {
      // If any error occurs, ensure clean state
      await _firebaseAuth.signOut();
      setState(() {
        _isAuthenticated = false;
        _authStatus = 'Please register or login';
      });
    }
  }

  Future<void> _register() async {
    if (_usernameController.text.isEmpty) {
      setState(() => _authStatus = 'Please enter a username');
      return;
    }

    setState(() {
      _isLoading = true;
      _authStatus = 'Registering...';
    });

    try {
      // Ensure clean state before registration
      await _firebaseAuth.signOut();

      // Check if username already exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        setState(() {
          _authStatus = 'Username already exists';
          _isLoading = false;
        });
        return;
      }

      // Create user and save data to Firestore
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: 'example@example.com', // Temporary email for new user
        password: 'password123', // Temporary password for new user
      );

      if (userCredential.user == null) {
        throw Exception('Failed to create user');
      }

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': _usernameController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Retrieve user document after creation (no need for custom mapping)
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // You can now use the data directly, e.g., userData['username'], userData['createdAt']
        print('User Data: $userData');
      }

      setState(() {
        _isAuthenticated = true;
        _authStatus =
            'Registration successful! You can now login with biometrics.';
        _isLoading = false;
      });
    } catch (e) {
      // Ensure clean state on error
      await _firebaseAuth.signOut();
      setState(() {
        _authStatus = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _authStatus = 'Authenticating...';
    });

    try {
      // Ensure clean state before login
      await _firebaseAuth.signOut();

      final userCredential = await _authService.signInWithBiometrics();
      setState(() {
        _isAuthenticated = true;
        _authStatus = 'Login successful!';
        _isLoading = false;
      });
    } catch (e) {
      // Ensure clean state on error
      await _firebaseAuth.signOut();
      setState(() {
        _authStatus = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _firebaseAuth.signOut();
      setState(() {
        _isAuthenticated = false;
        _authStatus = 'Signed out successfully';
      });
    } catch (e) {
      setState(() {
        _authStatus = 'Error signing out: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Authentication'),
        centerTitle: true,
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isAuthenticated) ...[
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    _authStatus,
                    style: TextStyle(
                      fontSize: 18,
                      color: _isAuthenticated ? Colors.green : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  if (!_isAuthenticated)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add),
                          label: const Text('Register'),
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            backgroundColor: Colors.blue,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Login with Biometrics'),
                          onPressed: _loginWithBiometrics,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}
