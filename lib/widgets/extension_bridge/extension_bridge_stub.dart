/// The DSCVR browser extension only runs next to the web app.
bool get extensionInstalled => false;

Future<bool> sendTokenToExtension(String token) async => false;
