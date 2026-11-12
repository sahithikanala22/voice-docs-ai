import 'package:flutter/material.dart';

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final mode in const [
          ThemeMode.system,
          ThemeMode.light,
          ThemeMode.dark,
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Semantics(
                button: true,
                selected: value == mode,
                label: '${mode.name} appearance',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: value == mode
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: value == mode
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: value == mode ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 66,
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: mode == ThemeMode.system
                                  ? [
                                      const Color(0xFFF8FAFC),
                                      const Color(0xFF141C2B),
                                    ]
                                  : mode == ThemeMode.dark
                                  ? [
                                      const Color(0xFF0A0E18),
                                      const Color(0xFF141C2B),
                                    ]
                                  : [Colors.white, const Color(0xFFEDF0F8)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 18,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: mode == ThemeMode.dark
                                      ? const Color(0xFFA794FF)
                                      : const Color(0xFF6242C6),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 9),
                              Container(
                                height: 22,
                                decoration: BoxDecoration(
                                  color: mode == ThemeMode.dark
                                      ? const Color(0xFF263148)
                                      : const Color(0xFFDDE2EF),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          switch (mode) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: value == mode
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                        if (mode == ThemeMode.dark)
                          Text(
                            'Default',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: value == mode
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        if (value == mode) ...[
                          const SizedBox(height: 5),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
