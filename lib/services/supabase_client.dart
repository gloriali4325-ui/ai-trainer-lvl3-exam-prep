import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static const String supabaseUrl = 'https://wqdzhtqoxsfymahtjhgv.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndxZHpodHFveHNmeW1haHRqaGd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMzAzODMsImV4cCI6MjA4NDcwNjM4M30.JJwbPiFryeFJvqb-ZXMYeGXgGA2ATOSgWrvHi-Wj50k';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint('[Supabase] Initialized');
  }

  static SupabaseClient get client => Supabase.instance.client;
}
