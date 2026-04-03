import 'dart:async';

import 'package:flutter/material.dart';

class EdgeSwipeBackContainer extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onBack;

  const EdgeSwipeBackContainer({
    super.key,
    required this.child,
    required this.onBack,
  });

  @override
  State<EdgeSwipeBackContainer> createState() => _EdgeSwipeBackContainerState();
}

class _EdgeSwipeBackContainerState extends State<EdgeSwipeBackContainer> {
  double _dragOffset = 0;
  bool _trackingBackSwipe = false;

  Future<bool> _handleWillPop() async {
    await widget.onBack();
    return false;
  }

  void _handleBackSwipeStart(DragStartDetails details) {
    _trackingBackSwipe = details.globalPosition.dx <= 24;
    if (!_trackingBackSwipe && _dragOffset != 0) {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  void _handleBackSwipeUpdate(DragUpdateDetails details) {
    if (!_trackingBackSwipe) {
      return;
    }

    final nextOffset = (_dragOffset + details.delta.dx).clamp(0.0, 120.0);
    if (nextOffset == _dragOffset) {
      return;
    }

    setState(() {
      _dragOffset = nextOffset;
    });
  }

  void _handleBackSwipeEnd(DragEndDetails details) {
    final shouldReset =
        _trackingBackSwipe &&
        (_dragOffset > 72 || (details.primaryVelocity ?? 0) > 600);

    _trackingBackSwipe = false;

    if (shouldReset) {
      unawaited(widget.onBack());
      return;
    }

    if (_dragOffset == 0) {
      return;
    }

    setState(() {
      _dragOffset = 0;
    });
  }

  void _handleBackSwipeCancel() {
    _trackingBackSwipe = false;
    if (_dragOffset == 0) {
      return;
    }

    setState(() {
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleWillPop());
      },
      child: Stack(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: _trackingBackSwipe ? 0 : 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: _handleBackSwipeStart,
              onHorizontalDragUpdate: _handleBackSwipeUpdate,
              onHorizontalDragEnd: _handleBackSwipeEnd,
              onHorizontalDragCancel: _handleBackSwipeCancel,
            ),
          ),
        ],
      ),
    );
  }
}
