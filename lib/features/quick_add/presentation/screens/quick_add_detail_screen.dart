import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/quick_add_provider.dart';
import 'live_activity_service.dart';

class QuickAddDetailScreen extends ConsumerStatefulWidget {
  const QuickAddDetailScreen({super.key});

  @override
  ConsumerState<QuickAddDetailScreen> createState() => _QuickAddDetailScreenState();
}

class _QuickAddDetailScreenState extends ConsumerState<QuickAddDetailScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickAddProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Detalles'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: state.isSaving ? null : () => _save(context),
              child: state.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Guardar',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Summary card ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(state.category?.icon, size: 28, color: state.category?.color),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CurrencyFormatter.format(state.parsedAmount ?? 0),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      state.category?.label ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Title ────────────────────────────────────────────────────────
          Text(
            'Título',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            onChanged: ref.read(quickAddProvider.notifier).setTitle,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Ej. Almuerzo, Uber, Netflix…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 20),

          // ── Notes ────────────────────────────────────────────────────────
          Text(
            'Nota (opcional)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            onChanged: ref.read(quickAddProvider.notifier).setNotes,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Detalles adicionales…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    await LiveActivityService.end();
    final success = await ref.read(quickAddProvider.notifier).save();
    if (success && mounted) context.go('/');
  }
}
