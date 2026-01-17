import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _selectedIndex = 0;
  bool _showOnlyTodayReaders = false;
  final List<int> _history = [];

  int get selectedIndex => _selectedIndex;
  bool get showOnlyTodayReaders => _showOnlyTodayReaders;

  void setIndex(int index) {
    if (_selectedIndex != index) {
      _history.add(_selectedIndex);
      _selectedIndex = index;
      notifyListeners();
    }
  }

  bool popTab() {
    if (_history.isNotEmpty) {
      _selectedIndex = _history.removeLast();
      notifyListeners();
      return true;
    }
    return false;
  }

  void setShowOnlyTodayReaders(bool value) {
    _showOnlyTodayReaders = value;
    notifyListeners();
  }

  /// Convenience method to navigate to a screen with specific parameters
  void navigateToUserListWithTodayFilter() {
    _showOnlyTodayReaders = true;
    setIndex(1); // Use setIndex to preserve history
  }
}
