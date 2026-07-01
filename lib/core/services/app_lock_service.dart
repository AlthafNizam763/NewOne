import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCredentialKey = 'app_lock_credential';
const _kTypeKey       = 'app_lock_type';

enum AppLockType { pin, password }

class AppLockService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> hasCredential() async {
    final val = await _storage.read(key: _kCredentialKey);
    return val != null && val.isNotEmpty;
  }

  static Future<void> setCredential(String value, AppLockType type) async {
    await _storage.write(key: _kCredentialKey, value: value);
    await _storage.write(key: _kTypeKey, value: type.name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', true);
  }

  static Future<bool> verify(String value) async {
    final stored = await _storage.read(key: _kCredentialKey);
    return stored == value;
  }

  static Future<void> clearCredential() async {
    await _storage.delete(key: _kCredentialKey);
    await _storage.delete(key: _kTypeKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', false);
  }

  static Future<AppLockType> getType() async {
    final val = await _storage.read(key: _kTypeKey);
    return val == 'password' ? AppLockType.password : AppLockType.pin;
  }
}
