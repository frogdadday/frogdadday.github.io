// /////Block One/////////////////////////////////////////////////////////////
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps forms readable on tablets while remaining fluid on compact phones,
/// split-screen windows, foldables, and landscape layouts.
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 32),
    this.maxContentWidth = 840,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: math.min(constraints.maxWidth, maxContentWidth),
            height: constraints.maxHeight,
            child: ListView(padding: padding, children: children),
          ),
        ),
      ),
    );
  }
}
