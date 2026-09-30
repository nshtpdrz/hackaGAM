import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/state.dart';
import '../core/sync.dart';
import '../core/theme.dart';
import '../core/tr.dart';

/// Estado vacío: qué pasa y qué hacer.
class EmptyView extends StatelessWidget {
  final IconData icon; final String title; final String? message; final Widget? action;
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.action});
  @override
  Widget build(BuildContext c) => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Semantics(
    container: true, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: C.p600), const SizedBox(height: 16),
      Text(tr(title), style: Theme.of(c).textTheme.headlineSmall, textAlign: TextAlign.center),
      if (message != null) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(tr(message!), style: Theme.of(c).textTheme.bodyMedium, textAlign: TextAlign.center)),
      if (action != null) Padding(padding: const EdgeInsets.only(top: 24), child: action)]))));
}

/// Estado de error: distingue sin conexión, sesión expirada (401), sin permisos (403) y otros.
class ErrorView extends ConsumerWidget {
  final Object error; final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final e = error; final code = e is DioException ? e.response?.statusCode : null;
    final (icon, title, msg) = code == 401
        ? (Icons.lock_clock, tr('Tu sesión expiró'), tr('Inicia sesión otra vez para continuar.'))
        : code == 403
            ? (Icons.block, tr('Sin permisos'), tr('Tu cuenta no puede ver esta información.'))
            : isNetworkError(e)
                ? (Icons.cloud_off, tr('Sin conexión'), tr('Revisa tu internet. Lo que registres se guarda en el teléfono.'))
                : (Icons.error_outline, tr('No se pudo cargar'), tr('Intenta de nuevo en un momento.'));
    return EmptyView(icon: icon, title: title, message: msg, action: code == 401
        ? FilledButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: Text(tr('Iniciar sesión')))
        : (onRetry != null && code != 403 ? FilledButton(onPressed: onRetry, child: Text(tr('Reintentar'))) : null));
  }
}
