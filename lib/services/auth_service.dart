import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final client = Supabase.instance.client;

  Future<void> login(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await client.auth.signOut();
  }
}
