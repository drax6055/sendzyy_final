import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sendzyy/core/theme/app_theme.dart';
import 'package:sendzyy/core/di/injection.dart';
import 'package:sendzyy/features/whatsapp/data/repositories/retry_repository.dart';

/// Expandable settings tile that lets admins view and update the
/// multi-phase retry configuration.
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 8.5
class RetryConfigSection extends StatefulWidget {
  const RetryConfigSection({super.key});

  @override
  State<RetryConfigSection> createState() => _RetryConfigSectionState();
}

class _RetryConfigSectionState extends State<RetryConfigSection> {
  bool _expanded = true;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _successMsg;

  Map<String, dynamic>? _activeConfig;

  // Editable phase rows: each entry is {intervalHours controller}
  final List<TextEditingController> _controllers = [];
  // Track which phase index is currently being edited (-1 = none)
  int _editingIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = getIt<RetryRepository>();
      // Only fetch active config — history is removed from UI
      final active = await repo.getActiveConfig();
      _initControllers(active);
      if (mounted) {
        setState(() {
          _activeConfig = active;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _initControllers(Map<String, dynamic>? config) {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();
    _editingIndex = -1; // reset editing state on every load

    final phases = config != null
        ? List<Map<String, dynamic>>.from(config['phases'] ?? [])
        : <Map<String, dynamic>>[];

    for (final p in phases) {
      _controllers.add(
        TextEditingController(text: '${p['intervalHours'] ?? 2}'),
      );
    }
  }

  void _addPhase() {
    if (_controllers.length >= 5) return;
    setState(() {
      _controllers.add(TextEditingController(text: ''));
      _editingIndex = _controllers.length - 1; // open new phase in edit mode
      _successMsg = null;
    });
  }

  void _removePhase(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = -1;
      } else if (_editingIndex > index) {
        _editingIndex--;
      }
      _successMsg = null;
    });
  }

  /// Delete a phase from the active config by index and immediately save.
  Future<void> _deleteActivePhase(int index) async {
    if (_activeConfig == null) return;
    final phases = List<Map<String, dynamic>>.from(
        _activeConfig!['phases'] as List? ?? []);
    if (index < 0 || index >= phases.length) return;
    phases.removeAt(index);
    // Re-number phases sequentially
    for (int i = 0; i < phases.length; i++) {
      phases[i] = {...phases[i], 'phaseNumber': i + 1};
    }
    // Load into controllers and save
    _initControllers({'phases': phases});
    setState(() {});
    await _save();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; _successMsg = null; });

    // Build phases list and validate
    final phases = <Map<String, dynamic>>[];
    for (int i = 0; i < _controllers.length; i++) {
      final raw = _controllers[i].text.trim();
      final hours = int.tryParse(raw);
      if (hours == null || hours < 1 || hours > 48) {
        setState(() {
          _saving = false;
          _error = 'Phase ${i + 1}: interval must be an integer between 1 and 48 hours.';
        });
        return;
      }
      if (i > 0) {
        final prev = int.tryParse(_controllers[i - 1].text.trim()) ?? 0;
        if (hours <= prev) {
          setState(() {
            _saving = false;
            _error = 'Phase ${i + 1} interval ($hours h) must be greater than phase $i ($prev h).';
          });
          return;
        }
      }
      phases.add({'phaseNumber': i + 1, 'intervalHours': hours});
    }

    try {
      final repo = getIt<RetryRepository>();
      final result = await repo.saveConfig(phases);

      // Build the updated config from the save result so we don't depend
      // on getActiveConfig returning fresh data immediately
      final savedPhases = result['phases'] != null
          ? List<Map<String, dynamic>>.from(result['phases'])
          : phases; // fall back to what we just sent

      if (mounted) {
        setState(() {
          _activeConfig = {
            ...?(_activeConfig),
            'phases': savedPhases,
            'version': result['version'],
            'isActive': true,
          };
          _saving = false;
          _successMsg = 'Saved as version ${result['version']}. '
              'Applies to new campaigns only.';
        });
        // Re-init controllers from the saved phases so display mode shows them
        _initControllers(_activeConfig);
        setState(() {}); // trigger rebuild with updated controllers
      }

      // Also do a background refresh to sync history etc.
      _load();
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _toggle() {
    if (!_expanded) {
      setState(() => _expanded = true);
      _load();
    } else {
      setState(() { _expanded = false; _error = null; _successMsg = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.1),
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.replay_circle_filled_outlined,
                    color: _expanded ? AppTheme.primaryColor : Colors.blueGrey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Retry Phase Configuration',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: _expanded
                                ? AppTheme.primaryColor
                                : Colors.black87,
                          ),
                        ),
                        if (_activeConfig != null)
                          Text(
                            '${(_activeConfig!['phases'] as List?)?.length ?? 0} phase(s) active · v${_activeConfig!['version']}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.chevron_right,
                      color: _expanded ? AppTheme.primaryColor : Colors.grey,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildBody(),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 20),

          // ── Info banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Configure up to 5 retry phases. Each phase retries failed messages '
                    'after the specified interval. Changes apply to new campaigns only.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Phase rows / empty state ─────────────────────────────────────
          if (_controllers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No retry phases configured. Messages will not be retried.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            )
          else
            ...List.generate(_controllers.length, (i) => _buildPhaseRow(i)),

          // Show "Add Phase" only when no phases yet (+ button on each row handles adding more)
          if (_controllers.isEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addPhase,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Phase'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],

          // ── Error / success messages ─────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: 12),
            _buildAlert(_error!, isError: true),
          ],
          if (_successMsg != null) ...[
            const SizedBox(height: 12),
            _buildAlert(_successMsg!, isError: false),
          ],

          const SizedBox(height: 16),

          // ── Save button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Configuration',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

          // ── Active phases display (below save button) ────────────────────
          if (_activeConfig != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 15, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text(
                  'Active Phases  ·  v${_activeConfig!['version']}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...(() {
              final phases = List<Map<String, dynamic>>.from(
                  _activeConfig!['phases'] as List? ?? []);
              if (phases.isEmpty) {
                return [
                  Text('No active phases.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500))
                ];
              }
              return phases.asMap().entries.map((entry) {
                final idx = entry.key;
                final p = entry.value;
                final num = p['phaseNumber'] ?? (idx + 1);
                final hrs = p['intervalHours'] ?? '-';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$num',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$hrs hour${hrs == 1 ? '' : 's'} after previous',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      _badge('Active', AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      // Edit: load this phase into the editor fields
                      InkWell(
                        onTap: () {
                          // Pre-fill controllers with active config phases for editing
                          _initControllers(_activeConfig);
                          setState(() { _successMsg = null; _error = null; });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: Colors.blueGrey.shade400),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete: remove this phase from active config and save
                      InkWell(
                        onTap: () => _deleteActivePhase(idx),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            })(),
          ],
        ],
      ),
    );
  }

  Widget _buildPhaseRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // ── Input card ──────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Phase number badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Interval text field
                  Expanded(
                    child: TextFormField(
                      controller: _controllers[index],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Interval (hours)',
                        hintText: '1–48',
                        suffixText: 'h',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) =>
                          setState(() { _error = null; _successMsg = null; }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── + button (add phase after this one) ─────────────────────────
          if (_controllers.length < 5)
            _CircleActionButton(
              icon: Icons.add,
              color: AppTheme.primaryColor,
              tooltip: 'Add phase',
              onTap: _addPhase,
            ),
          if (_controllers.length < 5) const SizedBox(width: 6),
          // ── − button (remove this phase) ────────────────────────────────
          _CircleActionButton(
            icon: Icons.remove,
            color: Colors.red,
            tooltip: 'Remove phase',
            onTap: () => _removePhase(index),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String msg, {required bool isError}) {
    final color = isError ? Colors.red : Colors.green;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(fontSize: 12, color: color.shade700))),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
            color: color.withValues(alpha: 0.06),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

