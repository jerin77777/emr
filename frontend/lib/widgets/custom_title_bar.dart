import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../config.dart';

class CustomAppTitleBar extends StatelessWidget {
  final Widget? leading;
  final String? title;
  final List<Widget>? actions;

  const CustomAppTitleBar({
    super.key,
    this.leading,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final buttonColors = WindowButtonColors(
      iconNormal: const Color(0xFFB2DFDB),
      mouseOver: const Color(0xFF004D40),
      mouseDown: const Color(0xFF00332C),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.tealAccent,
    );

    final closeButtonColors = WindowButtonColors(
      normal: Colors.transparent,
      iconNormal: const Color(0xFFB2DFDB),
      mouseOver: const Color(0xFFE53935),
      mouseDown: const Color(0xFFB71C1C),
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return WindowTitleBarBox(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF00241E),
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFF004D40),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left & Center Draggable Area
            Expanded(
              child: MoveWindow(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      // App Icon Pill
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.tealAccent.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // App Title
                      Text(
                        title ?? 'Anything EMR',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDemoVersion
                              ? Colors.orange.shade900.withValues(alpha: 0.7)
                              : const Color(0xFF004D40),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDemoVersion
                                ? Colors.orangeAccent.withValues(alpha: 0.6)
                                : const Color(0xFF00796B),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isDemoVersion
                                    ? Colors.orangeAccent
                                    : const Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isDemoVersion ? 'DEMO' : 'PRO SUITE',
                              style: TextStyle(
                                color: isDemoVersion
                                    ? Colors.orange.shade200
                                    : const Color(0xFFB2DFDB),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Center Security / HIPAA badge
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 11,
                            color: Colors.teal.shade300,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Encrypted Local Storage',
                            style: TextStyle(
                              color: Colors.teal.shade200.withValues(alpha: 0.8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ...?actions,
                    ],
                  ),
                ),
              ),
            ),
            // Window Action Buttons
            Row(
              children: [
                MinimizeWindowButton(colors: buttonColors),
                MaximizeWindowButton(colors: buttonColors),
                CloseWindowButton(colors: closeButtonColors),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
