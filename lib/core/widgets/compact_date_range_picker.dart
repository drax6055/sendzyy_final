import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iFloraBuzz/core/theme/app_theme.dart';

/// Shows a compact inline date-range picker dialog.
Future<DateTimeRange?> showCompactDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _CompactDateRangeDialog(
      initialDateRange: initialDateRange,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime.now(),
    ),
  );
}

class _CompactDateRangeDialog extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const _CompactDateRangeDialog({
    required this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_CompactDateRangeDialog> createState() => _CompactDateRangeDialogState();
}

class _CompactDateRangeDialogState extends State<_CompactDateRangeDialog> {
  late DateTime _focusedMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialDateRange?.start;
    _end = widget.initialDateRange?.end;
    _focusedMonth = DateTime(
      (_start ?? DateTime.now()).year,
      (_start ?? DateTime.now()).month,
    );
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // Start fresh selection
        _start = day;
        _end = null;
      } else {
        // Second tap — set end
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else if (_isSameDay(day, _start!)) {
          // tapped same day — treat as single day range
          _end = day;
        } else {
          _end = day;
        }
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    return d.isAfter(_start!) && d.isBefore(_end!);
  }

  bool _isStart(DateTime day) => _start != null && _isSameDay(day, _start!);
  bool _isEnd(DateTime day) => _end != null && _isSameDay(day, _end!);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isOutsideBounds(DateTime day) =>
      day.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) ||
      day.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

  List<DateTime?> _buildDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final startWeekday = first.weekday % 7; // Sunday = 0
    final result = <DateTime?>[];
    for (var i = 0; i < startWeekday; i++) result.add(null);
    for (var d = 1; d <= daysInMonth; d++) {
      result.add(DateTime(month.year, month.month, d));
    }
    // Pad to complete last row
    while (result.length % 7 != 0) result.add(null);
    return result;
  }

  String get _hintText {
    if (_start == null) return 'Tap a start date';
    if (_end == null) return 'Tap an end date';
    return '${DateFormat('MMM d, yyyy').format(_start!)}  →  ${DateFormat('MMM d, yyyy').format(_end!)}';
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildDays(_focusedMonth);
    const cellSize = 50.0;
    const weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Dialog(
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Date Range',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Selected range hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (_start != null && _end != null)
                    ? AppTheme.primaryColor.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _hintText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: (_start != null && _end != null)
                      ? AppTheme.primaryColor
                      : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Month navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavButton(
                  icon: Icons.chevron_left,
                  onTap: () => setState(() {
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  }),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                _NavButton(
                  icon: Icons.chevron_right,
                  onTap: () => setState(() {
                    _focusedMonth =
                        DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Weekday headers
            Row(
              children: weekdays
                  .map((d) => SizedBox(
                        width: cellSize,
                        height: 28,
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            // Calendar grid
            ...List.generate(days.length ~/ 7, (row) {
              return Row(
                children: List.generate(7, (col) {
                  final day = days[row * 7 + col];
                  if (day == null) {
                    return SizedBox(width: cellSize, height: cellSize);
                  }
                  final isStart = _isStart(day);
                  final isEnd = _isEnd(day);
                  final inRange = _isInRange(day);
                  final disabled = _isOutsideBounds(day);
                  final isSelected = isStart || isEnd;

                  Color textColor = Colors.black87;
                  if (isSelected) textColor = Colors.white;
                  else if (inRange) textColor = AppTheme.primaryColor;
                  else if (disabled) textColor = Colors.grey.shade300;

                  return GestureDetector(
                    onTap: disabled ? null : () => _onDayTap(day),
                    child: Container(
                      width: cellSize,
                      height: cellSize,
                      decoration: inRange && !isSelected
                          ? BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            )
                          : null,
                      child: Center(
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                )
                              : null,
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
            const SizedBox(height: 16),
            // Quick presets
            Wrap(
              spacing: 8,
              children: [
                _PresetChip(label: 'Today', onTap: () => _applyPreset(0, 0)),
                _PresetChip(label: 'Last 7 days', onTap: () => _applyPreset(6, 0)),
                _PresetChip(label: 'Last 30 days', onTap: () => _applyPreset(29, 0)),
                _PresetChip(label: 'This month', onTap: _applyThisMonth),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _start = null;
                      _end = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_start != null && _end != null)
                        ? () => Navigator.pop(
                            context, DateTimeRange(start: _start!, end: _end!))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyPreset(int daysBack, int daysForward) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day + daysForward);
    final start = DateTime(now.year, now.month, now.day - daysBack);
    setState(() {
      _start = start;
      _end = end;
      _focusedMonth = DateTime(start.year, start.month);
    });
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month, now.day);
      _focusedMonth = DateTime(now.year, now.month);
    });
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
