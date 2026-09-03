import '../supabase_config.dart';

Future<String> currentUserId() async {
  final authUser = supabase.auth.currentUser;
  if (authUser == null) {
    throw StateError('No user is logged in.');
  }

  final row = await supabase
      .from('users')
      .select('user_id')
      .eq('auth_id', authUser.id)
      .single();

  return row['user_id'] as String;
}
