import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://nprcxfvipxnjaecufhcz.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5wcmN4ZnZpcHhuamFlY3VmaGN6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNTkzOTksImV4cCI6MjEwMTgzNTM5OX0.YBpbQ736kdFlIfkzttloW7xHOY3Bn1efC8QVp35TL2I';

SupabaseClient get supabase => Supabase.instance.client;