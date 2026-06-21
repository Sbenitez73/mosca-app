import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/expense_category.dart';
import '../providers/expenses_provider.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  static const _palette = <Color>[
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFCDDC39),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customAsync = ref.watch(customCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis categorías')),
      body: customAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (customs) => ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // ── Custom categories ───────────────────────────────────────────
            if (customs.isNotEmpty) ...[
              _SectionLabel('Personalizadas'),
              ...customs.map(
                (cat) => ListTile(
                  leading: _ColorDot(color: cat.color),
                  title: Text(cat.label),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: theme.colorScheme.error,
                    onPressed: () => _confirmDelete(context, ref, cat),
                  ),
                ),
              ),
              const Divider(height: 32),
            ],

            // ── Built-ins (read-only) ───────────────────────────────────────
            _SectionLabel('Predeterminadas'),
            ...ExpenseCategory.builtins.map(
              (cat) => ListTile(
                leading: _CategoryIcon(category: cat),
                title: Text(cat.label),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva categoría'),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddCategorySheet(palette: _palette, ref: ref),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ExpenseCategory cat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Eliminar "${cat.label}"? Los gastos con esta categoría quedarán como "Otro".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Eliminar',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoryRepositoryProvider).delete(cat.key);
    }
  }
}

class _AddCategorySheet extends StatefulWidget {
  final List<Color> palette;
  final WidgetRef ref;

  const _AddCategorySheet({required this.palette, required this.ref});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _controller = TextEditingController();
  Color _selected = const Color(0xFFE91E63);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.palette.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _controller.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Escribe un nombre');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final cat = ExpenseCategory.custom(
      key: key,
      label: label,
      color: _selected,
    );
    await widget.ref.read(categoryRepositoryProvider).save(cat);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nueva categoría', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'Ej. Catalina, Mascota, Gym…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Color',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.palette.map((color) {
              final isSelected = color == _selected;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = color);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 2.5,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.label_rounded, color: Colors.white, size: 16),
      );
}

class _CategoryIcon extends StatelessWidget {
  final ExpenseCategory category;
  const _CategoryIcon({required this.category});

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(category.icon, color: category.color, size: 16),
      );
}
