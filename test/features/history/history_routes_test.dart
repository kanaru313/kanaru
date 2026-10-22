import 'package:flutter_test/flutter_test.dart';
import 'package:kanaru/app/shell/app_destination.dart';
import 'package:kanaru/features/history/history_routes.dart';

void main() {
  test('the route literal matches the destination', () {
    expect(historyPath, AppDestination.history.path);
  });
}
