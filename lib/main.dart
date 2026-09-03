import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';

const String supabaseUrl = 'https://nprcxfvipxnjaecufhcz.supabase.co';
const String supabaseKey = 'sb_secret_QOYG1HmTZDSkm6ANOD1_fw_x2l2J6LG';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  Stripe.publishableKey =
      'pk_test_51UATPFFWH2R2KmW9YBGLxfmMpnJWyvcV3zVMget5tHVcctlAnhA1MGmEnydjIk2hTDiCsHi3o8dtQaO4bFuHJBUe00baDR3Ke8';
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const HomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(
        child: Column(mainAxisAlignment: .center, children: [

          ],
        ),
      ),
    );
  }
}
