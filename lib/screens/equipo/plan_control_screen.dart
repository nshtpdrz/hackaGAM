import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared.dart';
import '../../core/tr.dart';

class PlanControlScreen extends ConsumerWidget { final String id; const PlanControlScreen({super.key, required this.id});
  @override
  Widget build(BuildContext c, WidgetRef ref) => page(c, tr('Plan de control'),
    Center(child: Text(tr('mín / máx / frecuencia / meta → PUT /pacientes/:id/plan'))));
}

