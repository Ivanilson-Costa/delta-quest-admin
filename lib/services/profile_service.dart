import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile() async {
    final user = client.auth.currentUser;

    debugPrint('AUTH USER ID: ${user?.id}');
    debugPrint('AUTH USER EMAIL: ${user?.email}');

    if (user == null) return null;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    debugPrint('PROFILE DATA: $data');

    return data;
  }
}