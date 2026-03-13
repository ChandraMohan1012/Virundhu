import 'package:flutter/material.dart';

class OrderStatusStepper extends StatelessWidget {
  final String currentStatus;

  const OrderStatusStepper({
    super.key,
    required this.currentStatus,
  });

  static const List<String> _steps = [
    'Placed',
    'Accepted',
    'Preparing',
    'Out for Delivery',
    'Delivered',
  ];

  int get _currentIndex {
    final normalized = currentStatus.trim().toLowerCase();
    return _steps.indexWhere((step) => step.toLowerCase() == normalized);
  }

  @override
  Widget build(BuildContext context) {
    if (currentStatus.trim().toLowerCase() == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This order was cancelled.',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final isDone = index < _currentIndex;
        final isCurrent = index == _currentIndex;
        final color = isCurrent || isDone ? Colors.red.shade700 : Colors.grey.shade300;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCurrent || isDone ? color : Colors.white,
                    border: Border.all(color: color, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDone ? Icons.check : Icons.circle,
                    size: isDone ? 14 : 8,
                    color: isCurrent || isDone ? Colors.white : color,
                  ),
                ),
                if (index != _steps.length - 1)
                  Container(
                    width: 2,
                    height: 30,
                    color: index < _currentIndex ? Colors.red.shade700 : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent || isDone ? Colors.black87 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCurrent
                          ? 'Current status'
                          : isDone
                              ? 'Completed'
                              : 'Waiting',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}