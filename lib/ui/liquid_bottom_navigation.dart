import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A backdrop capsule with a movable, springing selection lens.
class LiquidBottomNavigation extends StatefulWidget {
  const LiquidBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<(String, String)> destinations;

  @override
  State<LiquidBottomNavigation> createState() => _LiquidBottomNavigationState();
}

class _LiquidBottomNavigationState extends State<LiquidBottomNavigation> {
  ui.FragmentShader? _shader;
  ui.FragmentShader? _lensShader;
  double? _dragIndex;
  bool _pressed = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _loadLens();
  }

  Future<void> _loadLens() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/navigation_glass.frag',
      );
      if (!mounted) return;
      setState(() {
        _shader = program.fragmentShader();
        _lensShader = program.fragmentShader();
      });
    } catch (_) {
      // Blur remains available when the renderer cannot create the lens.
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    _lensShader?.dispose();
    super.dispose();
  }

  void _release({bool commit = false}) {
    final index = _dragIndex?.round();
    setState(() {
      _pressed = false;
      _dragIndex = null;
    });
    if (commit && index != null && index != widget.selectedIndex) {
      widget.onSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final count = widget.destinations.length;
    final active = dark ? const Color(0xff0091ff) : const Color(0xff0088ff);
    final foreground = dark ? Colors.white : const Color(0xff22252b);
    final height =
        64.0 +
        (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 24.0);
    final selected = _dragIndex ?? widget.selectedIndex.toDouble();
    final physicalIndex = rtl ? count - 1 - selected : selected;
    final blur = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8);
    final filter = _shader == null || highContrast
        ? blur
        : ui.ImageFilter.compose(
            outer: ui.ImageFilter.shader(_shader!),
            inner: blur,
          );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = (constraints.maxWidth - 8) / count;
              void track(Offset position) {
                final physical = ((position.dx - 4) / tabWidth - .5).clamp(
                  0.0,
                  count - 1.0,
                );
                setState(() {
                  _pressed = true;
                  _dragIndex = rtl ? count - 1 - physical : physical;
                });
              }

              return Listener(
                onPointerDown: (_) => _cancelled = false,
                onPointerCancel: (_) {
                  _cancelled = true;
                  _release();
                },
                child: GestureDetector(
                  onHorizontalDragStart: (details) =>
                      track(details.localPosition),
                  onHorizontalDragUpdate: (details) =>
                      track(details.localPosition),
                  onHorizontalDragEnd: (_) => _release(commit: !_cancelled),
                  onHorizontalDragCancel: _release,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? .28 : .10,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(height),
                              child: BackdropFilter(
                                filter: filter,
                                child: Container(
                                  key: const Key('floating-navigation'),
                                  height: height,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(height),
                                    color:
                                        (dark
                                                ? const Color(0xff181a20)
                                                : const Color(0xfffafafa))
                                            .withValues(
                                              alpha: highContrast ? .96 : .4,
                                            ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: dark ? .22 : .8,
                                      ),
                                      width: .8,
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(
                                          alpha: dark ? .10 : .22,
                                        ),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: physicalIndex),
                                duration: reduceMotion
                                    ? Duration.zero
                                    : Duration(
                                        milliseconds: _dragIndex == null
                                            ? 420
                                            : 45,
                                      ),
                                curve: _dragIndex == null
                                    ? Curves.easeOutBack
                                    : Curves.linear,
                                builder: (context, position, child) =>
                                    Positioned(
                                      left: 4 + position * tabWidth,
                                      top: 4,
                                      bottom: 4,
                                      width: tabWidth,
                                      child: child!,
                                    ),
                                child: AnimatedScale(
                                  scale: _pressed && !reduceMotion ? 1.24 : 1,
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(height),
                                    child: BackdropFilter(
                                      enabled: _pressed,
                                      filter:
                                          _lensShader != null && !highContrast
                                          ? ui.ImageFilter.shader(_lensShader!)
                                          : ui.ImageFilter.blur(
                                              sigmaX: 2,
                                              sigmaY: 2,
                                            ),
                                      child: AnimatedContainer(
                                        key: const Key('navigation-lens'),
                                        duration: reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            height,
                                          ),
                                          color:
                                              (dark
                                                      ? Colors.white
                                                      : Colors.black)
                                                  .withValues(
                                                    alpha: _pressed ? .04 : .08,
                                                  ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: _pressed ? .85 : .12,
                                            ),
                                            width: .8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    for (var i = 0; i < count; i++)
                                      Expanded(
                                        child: Semantics(
                                          key: ValueKey('navigation-$i'),
                                          label: widget.destinations[i].$1,
                                          selected: i == widget.selectedIndex,
                                          button: true,
                                          onTap: () => widget.onSelected(i),
                                          excludeSemantics: true,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              customBorder:
                                                  const StadiumBorder(),
                                              onTap: () => widget.onSelected(i),
                                              onHighlightChanged: (value) {
                                                if (_dragIndex == null) {
                                                  setState(
                                                    () => _pressed = value,
                                                  );
                                                }
                                              },
                                              splashColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              focusColor: active.withValues(
                                                alpha: .15,
                                              ),
                                              child: Center(
                                                child: AnimatedScale(
                                                  scale:
                                                      _pressed &&
                                                          selected.round() ==
                                                              i &&
                                                          !reduceMotion
                                                      ? 1.18
                                                      : 1,
                                                  duration: reduceMotion
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 180,
                                                        ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      SvgPicture.asset(
                                                        widget
                                                            .destinations[i]
                                                            .$2,
                                                        width: 27,
                                                        height: 27,
                                                        colorFilter:
                                                            ColorFilter.mode(
                                                              selected.round() ==
                                                                      i
                                                                  ? active
                                                                  : foreground,
                                                              BlendMode.srcIn,
                                                            ),
                                                        excludeFromSemantics:
                                                            true,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        widget
                                                            .destinations[i]
                                                            .$1,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          height: 1.15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              selected.round() ==
                                                                  i
                                                              ? active
                                                              : foreground,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
