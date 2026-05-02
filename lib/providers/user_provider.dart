import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class UserProvider extends ChangeNotifier {
  final StorageService _storage;
  UserProfile _profile = UserProfile.defaultProfile();

  UserProvider(this._storage);

  UserProfile get profile => _profile;
  int get dailyGoal => _profile.calculatedGoal;

  Future<void> load() async {
    _profile = await _storage.getProfile();
    notifyListeners();
  }

  Future<void> save(UserProfile profile) async {
    _profile = profile;
    await _storage.saveProfile(profile);
    notifyListeners();
  }
}