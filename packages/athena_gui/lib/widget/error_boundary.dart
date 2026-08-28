import 'package:athena_gui/theme/athena_colors.dart';
import 'package:athena_gui/widget/button.dart';
import 'package:flutter/material.dart';

class AthenaErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? message;
  final VoidCallback? onRetry;

  const AthenaErrorBoundary({
    super.key,
    required this.child,
    this.message,
    this.onRetry,
  });

  @override
  State<AthenaErrorBoundary> createState() => _AthenaErrorBoundaryState();
}

class _AthenaErrorBoundaryState extends State<AthenaErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorView();
    }
    return widget.child;
  }

  Widget _buildErrorView() {
    final colors = Theme.of(context).extension<AthenaColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.statusError),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(color: colors.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message ?? 'An unexpected error occurred',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.onRetry != null)
              AthenaPrimaryButton(
                onTap: () {
                  setState(() => _error = null);
                  widget.onRetry?.call();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Retry'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
