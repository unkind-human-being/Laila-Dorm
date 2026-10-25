import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../Database/app_database.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool hidePassword = true;
  bool loading = false;

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> login() async {
    final String username =
        usernameController.text.trim();

    final String password =
        passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      showMessage(
        'Please enter your username and password.',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    final Box settingsBox =
        Hive.box(
      AppDatabase.settingsBoxName,
    );

    final String savedUsername =
        settingsBox
            .get(
              'username',
              defaultValue: 'admin',
            )
            .toString();

    final String savedPasswordHash =
        settingsBox
            .get(
              'passwordHash',
              defaultValue:
                  AppDatabase.hashPassword(
                '123456',
              ),
            )
            .toString();

    final String enteredPasswordHash =
        AppDatabase.hashPassword(
      password,
    );

    if (!mounted) {
      return;
    }

    if (username == savedUsername &&
        enteredPasswordHash ==
            savedPasswordHash) {
      Navigator.pushReplacementNamed(
        context,
        '/home',
      );

      return;
    }

    setState(() {
      loading = false;
    });

    showMessage(
      'Invalid username or password.',
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color:
            const Color(0xFF17617D),
      ),

      suffixIcon: suffixIcon,

      filled: true,
      fillColor: Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        borderSide:
            BorderSide.none,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFE4E7EC),
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(0xFF17617D),
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN FORM
  // ============================================================

  Widget loginForm({
    required bool mobile,
  }) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        // Only show these on mobile because
        // desktop LOGIN.jpg already contains them.
        if (mobile) ...[
          const CircleAvatar(
            radius: 35,
            backgroundColor:
                Colors.white,
            child: Icon(
              Icons.apartment_rounded,
              size: 38,
              color:
                  Color(0xFF17617D),
            ),
          ),

          const SizedBox(
              height: 16),

          const Text(
            'WELCOME BACK!',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.bold,
              shadows: [
                Shadow(
                  color:
                      Colors.black54,
                  blurRadius: 5,
                ),
              ],
            ),
          ),

          const SizedBox(
              height: 5),

          const Text(
            'Enter your credentials to access the system',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 12,
              shadows: [
                Shadow(
                  color:
                      Colors.black54,
                  blurRadius: 4,
                ),
              ],
            ),
          ),

          const SizedBox(
              height: 22),
        ],

        TextField(
          controller:
              usernameController,

          textInputAction:
              TextInputAction.next,

          decoration:
              inputDecoration(
            hint:
                'Username',
            icon:
                Icons.person_outline,
          ),
        ),

        const SizedBox(
            height: 14),

        TextField(
          controller:
              passwordController,

          obscureText:
              hidePassword,

          textInputAction:
              TextInputAction.done,

          onSubmitted:
              (_) => login(),

          decoration:
              inputDecoration(
            hint:
                'Password',

            icon:
                Icons.lock_outline,

            suffixIcon:
                IconButton(
              onPressed: () {
                setState(() {
                  hidePassword =
                      !hidePassword;
                });
              },

              icon: Icon(
                hidePassword
                    ? Icons
                        .visibility_outlined
                    : Icons
                        .visibility_off_outlined,
              ),
            ),
          ),
        ),

        const SizedBox(
            height: 20),

        SizedBox(
          width:
              double.infinity,
          height: 53,

          child:
              ElevatedButton.icon(
            onPressed:
                loading
                    ? null
                    : login,

            style:
                ElevatedButton
                    .styleFrom(
              backgroundColor:
                  Colors.white,

              foregroundColor:
                  const Color(
                      0xFF17617D),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  12,
                ),
              ),
            ),

            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2,
                    ),
                  )
                : const Icon(
                    Icons.login,
                  ),

            label:
                Text(
              loading
                  ? 'LOGGING IN...'
                  : 'LOGIN',

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ),

        const SizedBox(
            height: 14),

        const Text(
          'Administrator Access Only',
          style:
              TextStyle(
            color:
                Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MOBILE LOGIN
  // ============================================================

  Widget mobileLogin() {
    return Stack(
      children: [
        Positioned.fill(
          child:
              Image.asset(
            'assets/LOGIN.jpg',
            fit:
                BoxFit.cover,
          ),
        ),

        // Small dark layer only on mobile
        // so inputs remain readable over the photo.
        Positioned.fill(
          child: Container(
            color:
                Colors.black
                    .withOpacity(
              .20,
            ),
          ),
        ),

        SafeArea(
          child:
              Center(
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets
                      .all(
                20,
              ),

              child:
                  Container(
                width:
                    double.infinity,

                constraints:
                    const BoxConstraints(
                  maxWidth:
                      420,
                ),

                padding:
                    const EdgeInsets
                        .all(
                  24,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                              0xFF0B6E3D)
                          .withOpacity(
                    .90,
                  ),

                  borderRadius:
                      BorderRadius
                          .circular(
                    22,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black
                              .withOpacity(
                        .25,
                      ),
                      blurRadius:
                          25,
                    ),
                  ],
                ),

                child:
                    loginForm(
                  mobile:
                      true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DESKTOP LOGIN
  // ============================================================

  Widget desktopLogin(
    BoxConstraints constraints,
  ) {
    final double width =
        constraints.maxWidth;

    final double height =
        constraints.maxHeight;

    return Stack(
      children: [
        Positioned.fill(
          child:
              Image.asset(
            'assets/LOGIN.jpg',
            fit:
                BoxFit.cover,
          ),
        ),

        // This positions the form inside
        // your existing green Welcome Back box.
        Positioned(
          left:
              width * 0.535,

          top:
              height * 0.405,

          width:
              width * 0.285,

          child:
              loginForm(
            mobile:
                false,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          LayoutBuilder(
        builder:
            (
          context,
          constraints,
        ) {
          final bool mobile =
              constraints.maxWidth <
                  700;

          if (mobile) {
            return mobileLogin();
          }

          return desktopLogin(
            constraints,
          );
        },
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();

    super.dispose();
  }
}