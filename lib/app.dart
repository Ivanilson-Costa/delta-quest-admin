import 'package:flutter/material.dart';
import 'core/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Delta Quest IT',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
