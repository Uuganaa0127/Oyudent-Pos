part of '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showPassword = false;
  bool loginBusy = false;
  String? loginError;
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (loginBusy) return;
    final username = usernameController.text.trim();
    final password = passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => loginError = 'Enter your username and password.');
      return;
    }
    setState(() {
      loginBusy = true;
      loginError = null;
    });
    try {
      final response = await http
          .post(
            Uri.parse('https://api.oyudent.com/admin/api/v1/admin-user/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = _decodeResponse(response);
      final payload = decoded['data'];
      final accessToken = payload is String
          ? payload
          : payload is Map
          ? (payload['accessToken'] ??
                    payload['access_token'] ??
                    payload['token'])
                ?.toString()
          : null;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          accessToken == null ||
          accessToken.isEmpty) {
        throw Exception(_apiMessage(decoded, response.statusCode));
      }

      final userResponse = await http
          .get(
            Uri.parse('https://api.oyudent.com/admin/api/v1/admin-user/info'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));
      final userDecoded = _decodeResponse(userResponse);
      if (userResponse.statusCode < 200 || userResponse.statusCode >= 300) {
        throw Exception(_apiMessage(userDecoded, userResponse.statusCode));
      }
      final userData = userDecoded['data'];
      final userMap = userData is Map
          ? Map<String, dynamic>.from(userData)
          : <String, dynamic>{};
      final displayName =
          (userMap['name'] ??
                  userMap['username'] ??
                  userMap['email'] ??
                  username)
              .toString();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              PosShell(initialToken: accessToken, userName: displayName),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          loginError = error is SocketException || error is http.ClientException
              ? 'Could not connect to Oyudent. Check your internet connection and try again.'
              : '$error'.replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => loginBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deepSpace, deepSpaceMid, Color(0xFF242044)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 820;
          final form = Container(
            padding: EdgeInsets.all(wide ? 36 : 24),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x36030615),
                  blurRadius: 36,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: -1.3,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _FieldLabel('Email or username'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usernameController,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,

                    decoration: InputDecoration(
                      hintText: 'name@company.com',
                      prefixIcon: Icon(Icons.person_outline, size: 19),
                    ),
                  ),
                  const SizedBox(height: 19),
                  const _FieldLabel('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    autofillHints: const [AutofillHints.password],
                    obscureText: !showPassword,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (loginError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        loginError!,
                        style: const TextStyle(
                          color: Color(0xFF9E3128),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 49,
                    child: FilledButton(
                      onPressed: loginBusy ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loginBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(
                    child: Text(
                      'Sign in with your admin.oyudent.com account',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _ScannerPattern()),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(wide ? 48 : 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1000 : 420),
                    child: wide
                        ? Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _Brand(inverse: true),
                                    SizedBox(height: 32),
                                    Text(
                                      'Point of sale',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 52,
                                        height: 1.05,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(child: form),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _Brand(inverse: true),
                              const SizedBox(height: 22),
                              form,
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ScannerPattern extends CustomPainter {
  const _ScannerPattern();
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0x0CFFFFFF);
    for (double x = 0; x < size.width; x += 40)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    for (double y = 0; y < size.height; y += 40)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (var i = 0; i < 22; i++) {
      final dy = i * 8.0;
      final wave = Path()
        ..moveTo(-8, size.height * .79 + dy)
        ..cubicTo(
          size.width * .29,
          size.height * .82 + dy,
          size.width * .38,
          size.height * .30 + dy,
          size.width + 8,
          size.height * .27 + dy,
        );
      stroke.color = Color.lerp(
        const Color(0x4047DBCE),
        const Color(0x206E6FFE),
        i / 21,
      )!;
      canvas.drawPath(wave, stroke);
    }
  }

  @override
  bool shouldRepaint(_ScannerPattern oldDelegate) => false;
}
