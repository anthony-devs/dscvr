/// Saving files directly is only supported on the web build; elsewhere the
/// caller falls back to copying to the clipboard.
bool get canDownload => false;

void downloadText(String fileName, String text, {String mime = 'text/markdown'}) {}
