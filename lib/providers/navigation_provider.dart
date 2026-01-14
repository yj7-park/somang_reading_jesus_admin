import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;
  bool _showOnlyTodayReaders = false;

  int get selectedIndex => _selectedIndex;
  bool get showOnlyTodayReaders => _showOnlyTodayReaders;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void setShowOnlyTodayReaders(bool value) {
    _showOnlyTodayReaders = value;
    notifyListeners();
  }

  /// Convenience method to navigate to a screen with specific parameters
  void navigateToUserListWithTodayFilter() {
    _selectedIndex = 1; // User List Screen
    _showOnlyTodayReaders = true;
    notifyListeners();
  }
}
