import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/alocacoes_page.dart';
import '../pages/clientes_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/loading_page.dart';
import '../pages/login_page.dart';
import '../pages/perguntas_page.dart';
import '../pages/pesquisas_page.dart';
import '../pages/questionarios_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/loading',
  routes: [
    GoRoute(
      path: '/loading',
      builder: (context, state) => const LoadingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/clientes',
      builder: (context, state) => const ClientesPage(),
    ),
    GoRoute(
      path: '/pesquisas',
      builder: (context, state) => const PesquisasPage(),
    ),
    GoRoute(
      path: '/alocacoes',
      builder: (context, state) => const AlocacoesPage(),
    ),
    GoRoute(
      path: '/questionarios',
      builder: (context, state) => const QuestionariosPage(),
    ),
    GoRoute(
  path: '/perguntas/:id',
  builder: (context, state) {
    final id = state.pathParameters['id'] ?? '';

    final extra = state.extra;
    String titulo = '';
    String pesquisaTitulo = '';

    if (extra != null && extra is Map<String, dynamic>) {
      titulo = (extra['titulo'] ?? '').toString();
      pesquisaTitulo = (extra['pesquisaTitulo'] ?? '').toString();
    }

    return PerguntasPage(
      questionarioId: id,
      questionarioTitulo: titulo,
      pesquisaTitulo: pesquisaTitulo,
    );
  },
),
  ],
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLogin = state.matchedLocation == '/login';
    final isLoading = state.matchedLocation == '/loading';

    if (isLoading) {
      return session == null ? '/login' : '/dashboard';
    }

    if (session == null && !isLogin) {
      return '/login';
    }

    if (session != null && isLogin) {
      return '/dashboard';
    }

    return null;
  },
);