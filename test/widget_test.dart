import 'package:flutter_test/flutter_test.dart';
import 'package:patadlg/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppTheme.light builds without throwing', () {
    final theme = AppTheme.light;
    expect(theme.useMaterial3, isTrue);
  });
}
