import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/screens.dart';
import '../widgets/sync_status.dart';
import 'state.dart';
import '../core/tr.dart';

/// [corto]: nombre para la barra inferior (el completo va en el tooltip y en el lector de pantalla).
class _Tab { final String path, label; final IconData icon; final Widget screen; final String? corto;
  const _Tab(this.path, this.label, this.icon, this.screen, {this.corto}); }

final _tabs = <Role, List<_Tab>>{
  Role.paciente: [
    const _Tab('/hoy', 'Hoy', Icons.home_outlined, HoyScreen()),
    const _Tab('/registrar', 'Registrar', Icons.edit_note, RegistrarScreen()),
    const _Tab('/medicamentos', 'Medicamentos', Icons.medication_outlined, MedicamentosScreen(), corto: 'Medicinas'),
    const _Tab('/historial', 'Historial', Icons.show_chart, HistorialScreen()),
    const _Tab('/perfil', 'Perfil', Icons.person_outline, PerfilScreen())],
  Role.cuidador: [
    const _Tab('/alertas', 'Alertas', Icons.notifications_outlined, AlertasScreen()),
    const _Tab('/medicamentos', 'Medicamentos', Icons.medication_outlined, MedicamentosScreen(), corto: 'Medicinas'),
    const _Tab('/historial', 'Historial', Icons.show_chart, HistorialScreen()),
    const _Tab('/perfil', 'Perfil', Icons.person_outline, PerfilScreen())],
  Role.equipo: [
    const _Tab('/cola', 'Alertas', Icons.notifications_outlined, AlertasScreen()),
    const _Tab('/pacientes', 'Pacientes', Icons.people_outline, PacientesScreen()),
    const _Tab('/escanear', 'Escanear QR', Icons.qr_code_scanner, EscanerScreen(), corto: 'Escanear'),
    const _Tab('/perfil', 'Perfil', Icons.person_outline, PerfilScreen())],
};
String homeFor(Role r) => _tabs[r]!.first.path;

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ValueNotifier(0);
  ref.listen(sessionProvider, (_, __) => listenable.value++);
  final seen = <String>{};
  final shellTabs = [for (final l in _tabs.values) for (final t in l) if (seen.add(t.path)) t];
  return GoRouter(
    initialLocation: '/splash', refreshListenable: listenable,
    redirect: (ctx, st) {
      final s = ref.read(sessionProvider); final atLogin = st.matchedLocation == '/login' || st.matchedLocation == '/registro' || st.matchedLocation == '/splash';
      if (s == null) return (atLogin || st.matchedLocation == '/consentimiento') ? null : '/login';
      if (atLogin) return homeFor(s.role);
      return null; // la API valida los permisos reales con el JWT
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/registro', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/preferencias', builder: (_, __) => const PreferenciasScreen()),
      GoRoute(path: '/perfil/editar', builder: (_, st) => EditarPerfilScreen(perfil: st.extra as Map)),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/consentimiento', builder: (_, st) => ConsentimientoScreen(tutor: st.extra == true)),
      GoRoute(path: '/notificaciones', builder: (_, __) => const NotificacionesScreen()),
      GoRoute(path: '/alerta/:id', builder: (_, st) => AlertaDetalleScreen(alerta: st.extra as Map)),
      GoRoute(path: '/receta', builder: (_, __) => const RecetaFlowScreen()),
      GoRoute(path: '/pendientes', builder: (_, __) => const PendientesScreen()),
      GoRoute(path: '/paciente/:id', builder: (_, st) => PacienteDetalleScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/alta', builder: (_, __) => const AltaPacienteScreen()),
      GoRoute(path: '/resultado', builder: (_, st) => ResultadoScreen(data: st.extra as Map)),
      GoRoute(path: '/recordatorio', builder: (_, st) => RecordatorioScreen(toma: st.extra as Map)),
      GoRoute(path: '/qr', builder: (_, __) => const QrScreen()),
      GoRoute(path: '/expediente/:id', builder: (_, st) => ExpedienteScreen(id: st.pathParameters['id']!)),
      GoRoute(path: '/plan/:id', builder: (_, st) => PlanControlScreen(id: st.pathParameters['id']!)),
      ShellRoute(builder: (ctx, st, child) => RoleShell(child: child),
        routes: [for (final t in shellTabs) GoRoute(path: t.path, builder: (_, __) => t.screen)]),
    ]);
});

class RoleShell extends ConsumerWidget {
  final Widget child; const RoleShell({super.key, required this.child});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final role = ref.watch(sessionProvider)?.role ?? Role.paciente; final tabs = _tabs[role]!;
    final loc = GoRouterState.of(c).matchedLocation;
    final i = tabs.indexWhere((t) => loc.startsWith(t.path));
    return Scaffold(body: SafeArea(child: Column(children: [const SyncStatus(compact: true), Expanded(child: child)])), bottomNavigationBar: MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: MediaQuery.textScalerOf(c).clamp(maxScaleFactor: 1.2)),
      child: NavigationBarTheme(data: NavigationBarThemeData(labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 11.5,
        fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500))), child: NavigationBar(
      height: role == Role.paciente ? 80 : 64, selectedIndex: i < 0 ? 0 : i,
      onDestinationSelected: (n) => c.go(tabs[n].path),
      destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: tr(t.corto ?? t.label), tooltip: tr(t.label))]))));
  }
}
