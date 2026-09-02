import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://nprcxfvipxnjaecufhcz.supabase.co';
const String supabaseKey = 'sb_secret_QOYG1HmTZDSkm6ANOD1_fw_x2l2J6LG';

SupabaseClient get supabase => Supabase.instance.client;