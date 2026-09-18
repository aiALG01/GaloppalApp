import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ToastOverlay extends StatelessWidget {
  const ToastOverlay({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: message == null
            ? const SizedBox.shrink()
            : Align(
                key: ValueKey(message),
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 108,
                    left: 22,
                    right: 22,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: .35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sans(
                        size: 13,
                        weight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
