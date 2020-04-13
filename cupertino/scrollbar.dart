// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';

// All values eyeballed.
const double _kScrollbarMinLength = 36.0;
const double _kScrollbarMinOverscrollLength = 8.0;
const Duration _kScrollbarTimeToFade = Duration(milliseconds: 1200);
const Duration _kScrollbarFadeDuration = Duration(milliseconds: 250);
const Duration _kScrollbarResizeDuration = Duration(milliseconds: 100);

// Extracted from iOS 13.1 beta using Debug View Hierarchy.
const Color _kScrollbarColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x59000000),
  darkColor: Color(0x80FFFFFF),
);
const double _kScrollbarThickness = 3;
const double _kScrollbarThicknessDragging = 8.0;
const Radius _kScrollbarRadius = Radius.circular(1.5);
const Radius _kScrollbarRadiusDragging = Radius.circular(4.0);

// This is the amount of space from the top of a vertical scrollbar to the
// top edge of the scrollable, measured when the vertical scrollbar overscrolls
// to the top.
// TODO(LongCatIsLooong): fix https://github.com/flutter/flutter/issues/32175
const double _kScrollbarMainAxisMargin = 3.0;
const double _kScrollbarCrossAxisMargin = 3.0;

/// An iOS style scrollbar.
///
/// A scrollbar indicates which portion of a [Scrollable] widget is actually
/// visible.
///
/// To add a scrollbar to a [ScrollView], simply wrap the scroll view widget in
/// a [CupertinoScrollbar] widget.
///
/// By default, the CupertinoScrollbar will be draggable (a feature introduced
/// in iOS 13), it uses the PrimaryScrollController. For multiple scrollbars, or
/// other more complicated situations, see the [controller] parameter.
///
/// See also:
///
///  * [ListView], which display a linear, scrollable list of children.
///  * [GridView], which display a 2 dimensional, scrollable array of children.
///  * [Scrollbar], a Material Design scrollbar that dynamically adapts to the
///    platform showing either an Android style or iOS style scrollbar.
class CupertinoScrollbar extends StatefulWidget {
  /// Creates an iOS style scrollbar that wraps the given [child].
  ///
  /// The [child] should be a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  const CupertinoScrollbar({
    Key key,
    this.controller,
    @required this.child,
  }) : super(key: key);

  /// The subtree to place inside the [CupertinoScrollbar].
  ///
  /// This should include a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  final Widget child;

  /// {@template flutter.cupertino.cupertinoScrollbar.controller}
  /// The [ScrollController] used to implement Scrollbar dragging.
  ///
  /// introduced in iOS 13.
  ///
  /// If nothing is passed to controller, the default behavior is to automatically
  /// enable scrollbar dragging on the nearest ScrollController using
  /// [PrimaryScrollController.of].
  ///
  /// If a ScrollController is passed, then scrollbar dragging will be enabled on
  /// the given ScrollController. A stateful ancestor of this CupertinoScrollbar
  /// needs to manage the ScrollController and either pass it to a scrollable
  /// descendant or use a PrimaryScrollController to share it.
  ///
  /// Here is an example of using the `controller` parameter to enable
  /// scrollbar dragging for multiple independent ListViews:
  ///
  /// {@tool snippet}
  ///
  /// ```dart
  /// final ScrollController _controllerOne = ScrollController();
  /// final ScrollController _controllerTwo = ScrollController();
  ///
  /// build(BuildContext context) {
  /// return Column(
  ///   children: <Widget>[
  ///     Container(
  ///        height: 200,
  ///        child: CupertinoScrollbar(
  ///          controller: _controllerOne,
  ///          child: ListView.builder(
  ///            controller: _controllerOne,
  ///            itemCount: 120,
  ///            itemBuilder: (BuildContext context, int index) => Text('item $index'),
  ///          ),
  ///        ),
  ///      ),
  ///      Container(
  ///        height: 200,
  ///        child: CupertinoScrollbar(
  ///          controller: _controllerTwo,
  ///          child: ListView.builder(
  ///            controller: _controllerTwo,
  ///            itemCount: 120,
  ///            itemBuilder: (BuildContext context, int index) => Text('list 2 item $index'),
  ///          ),
  ///        ),
  ///      ),
  ///    ],
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  final ScrollController controller;

  @override
  _CupertinoScrollbarState createState() => _CupertinoScrollbarState();
}

class _CupertinoScrollbarState extends State<CupertinoScrollbar> with TickerProviderStateMixin {
  final GlobalKey _customPaintKey = GlobalKey();
  ScrollbarPainter _painter;

  AnimationController _fadeoutAnimationController;
  Animation<double> _fadeoutOpacityAnimation;
  AnimationController _thicknessAnimationController;
  Timer _fadeoutTimer;
  double _dragScrollbarPositionY;
  Drag _drag;

  double get _thickness {
    return _kScrollbarThickness + _thicknessAnimationController.value * (_kScrollbarThicknessDragging - _kScrollbarThickness);
  }

  Radius get _radius {
    return Radius.lerp(_kScrollbarRadius, _kScrollbarRadiusDragging, _thicknessAnimationController.value);
  }

  ScrollController _currentController;
  ScrollController get _controller =>
      widget.controller ?? PrimaryScrollController.of(context);

  @override
  void initState() {
    super.initState();
    _fadeoutAnimationController = AnimationController(
      vsync: this,
      duration: _kScrollbarFadeDuration,
    );
    _fadeoutOpacityAnimation = CurvedAnimation(
      parent: _fadeoutAnimationController,
      curve: Curves.fastOutSlowIn,
    );
    _thicknessAnimationController = AnimationController(
      vsync: this,
      duration: _kScrollbarResizeDuration,
    );
    _thicknessAnimationController.addListener(() {
      _painter.updateThickness(_thickness, _radius);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_painter == null) {
      _painter = _buildCupertinoScrollbarPainter(context);
    } else {
      _painter
        ..textDirection = Directionality.of(context)
        ..color = CupertinoDynamicColor.resolve(_kScrollbarColor, context)
        ..padding = MediaQuery.of(context).padding;
    }
  }

  /// Returns a [ScrollbarPainter] visually styled like the iOS scrollbar.
  ScrollbarPainter _buildCupertinoScrollbarPainter(BuildContext context) {
    return ScrollbarPainter(
      color: CupertinoDynamicColor.resolve(_kScrollbarColor, context),
      textDirection: Directionality.of(context),
      thickness: _thickness,
      fadeoutOpacityAnimation: _fadeoutOpacityAnimation,
      mainAxisMargin: _kScrollbarMainAxisMargin,
      crossAxisMargin: _kScrollbarCrossAxisMargin,
      radius: _radius,
      padding: MediaQuery.of(context).padding,
      minLength: _kScrollbarMinLength,
      minOverscrollLength: _kScrollbarMinOverscrollLength,
    );
  }

  // Handle a gesture that drags the scrollbar by the given amount.
  void _dragScrollbar(double primaryDelta) {
    assert(_currentController != null);

    // Convert primaryDelta, the amount that the scrollbar moved since the last
    // time _dragScrollbar was called, into the coordinate space of the scroll
    // position, and create/update the drag event with that position.
    final double scrollOffsetLocal = _painter.getTrackToScroll(primaryDelta);
    final double scrollOffsetGlobal = scrollOffsetLocal + _currentController.position.pixels;

    if (_drag == null) {
      _drag = _currentController.position.drag(
        DragStartDetails(
          globalPosition: Offset(0.0, scrollOffsetGlobal),
        ),
        () {},
      );
    } else {
      _drag.update(DragUpdateDetails(
        globalPosition: Offset(0.0, scrollOffsetGlobal),
        delta: Offset(0.0, -scrollOffsetLocal),
        primaryDelta: -scrollOffsetLocal,
      ));
    }
  }

  void _startFadeoutTimer() {
    _fadeoutTimer?.cancel();
    _fadeoutTimer = Timer(_kScrollbarTimeToFade, () {
      _fadeoutAnimationController.reverse();
      _fadeoutTimer = null;
    });
  }

  bool _checkVertical() {
    try {
      return _currentController.position.axis == Axis.vertical;
    } catch (_) {
      // Ignore the gesture if we cannot determine the direction.
      return false;
    }
  }

  double _pressStartY = 0.0;

  // Long press event callbacks handle the gesture where the user long presses
  // on the scrollbar thumb and then drags the scrollbar without releasing.
  void _handleLongPressStart(LongPressStartDetails details) {
    _currentController = _controller;
    if (!_checkVertical()) {
      return;
    }
    _pressStartY = details.localPosition.dy;
    _fadeoutTimer?.cancel();
    _fadeoutAnimationController.forward();
    _dragScrollbar(details.localPosition.dy);
    _dragScrollbarPositionY = details.localPosition.dy;
  }

  void _handleLongPress() {
    if (!_checkVertical()) {
      return;
    }
    _fadeoutTimer?.cancel();
    _thicknessAnimationController.forward().then<void>(
          (_) => HapticFeedback.mediumImpact(),
        );
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_checkVertical()) {
      return;
    }
    _dragScrollbar(details.localPosition.dy - _dragScrollbarPositionY);
    _dragScrollbarPositionY = details.localPosition.dy;
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (!_checkVertical()) {
      return;
    }
    _handleDragScrollEnd(details.velocity.pixelsPerSecond.dy);
    if (details.velocity.pixelsPerSecond.dy.abs() < 10 &&
        (details.localPosition.dy - _pressStartY).abs() > 0) {
      HapticFeedback.mediumImpact();
    }
    _currentController = null;
  }

  void _handleDragScrollEnd(double trackVelocityY) {
    _startFadeoutTimer();
    _thicknessAnimationController.reverse();
    _dragScrollbarPositionY = null;
    final double scrollVelocityY = _painter.getTrackToScroll(trackVelocityY);
    _drag?.end(DragEndDetails(
      primaryVelocity: -scrollVelocityY,
      velocity: Velocity(
        pixelsPerSecond: Offset(
          0.0,
          -scrollVelocityY,
        ),
      ),
    ));
    _drag = null;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final ScrollMetrics metrics = notification.metrics;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) {
      return false;
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      // Any movements always makes the scrollbar start showing up.
      if (_fadeoutAnimationController.status != AnimationStatus.forward) {
        _fadeoutAnimationController.forward();
      }

      _fadeoutTimer?.cancel();
      _painter.update(notification.metrics, notification.metrics.axisDirection);
    } else if (notification is ScrollEndNotification) {
      // On iOS, the scrollbar can only go away once the user lifted the finger.
      if (_dragScrollbarPositionY == null) {
        _startFadeoutTimer();
      }
    }
    return false;
  }

  // Get the GestureRecognizerFactories used to detect gestures on the scrollbar
  // thumb.
  Map<Type, GestureRecognizerFactory> get _gestures {
    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    gestures[_ThumbPressGestureRecognizer] =
        GestureRecognizerFactoryWithHandlers<_ThumbPressGestureRecognizer>(
      () => _ThumbPressGestureRecognizer(
        debugOwner: this,
        customPaintKey: _customPaintKey,
      ),
      (_ThumbPressGestureRecognizer instance) {
        instance
          ..onLongPressStart = _handleLongPressStart
          ..onLongPress = _handleLongPress
          ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
          ..onLongPressEnd = _handleLongPressEnd;
      },
    );

    return gestures;
  }

  @override
  void dispose() {
    _fadeoutAnimationController.dispose();
    _thicknessAnimationController.dispose();
    _fadeoutTimer?.cancel();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: RepaintBoundary(
        child: RawGestureDetector(
          gestures: _gestures,
          child: CustomPaint(
            key: _customPaintKey,
            foregroundPainter: _painter,
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),
    );
  }
}

// A longpress gesture detector that only responds to events on the scrollbar's
// thumb and ignores everything else.
class _ThumbPressGestureRecognizer extends LongPressGestureRecognizer {
  _ThumbPressGestureRecognizer({
    double postAcceptSlopTolerance,
    PointerDeviceKind kind,
    Object debugOwner,
    GlobalKey customPaintKey,
  }) :  _customPaintKey = customPaintKey,
        super(
          postAcceptSlopTolerance: postAcceptSlopTolerance,
          kind: kind,
          debugOwner: debugOwner,
          duration: const Duration(milliseconds: 100),
        );

  final GlobalKey _customPaintKey;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (!_hitTestInteractive(_customPaintKey, event.position)) {
      return false;
    }
    return super.isPointerAllowed(event);
  }
}

// foregroundPainter also hit tests its children by default, but the
// scrollbar should only respond to a gesture directly on its thumb, so
// manually check for a hit on the thumb here.
bool _hitTestInteractive(GlobalKey customPaintKey, Offset offset) {
  if (customPaintKey.currentContext == null) {
    return false;
  }
  final CustomPaint customPaint = customPaintKey.currentContext.widget as CustomPaint;
  final ScrollbarPainter painter = customPaint.foregroundPainter as ScrollbarPainter;
  final RenderBox renderBox = customPaintKey.currentContext.findRenderObject() as RenderBox;
  final Offset localOffset = renderBox.globalToLocal(offset);
  return painter.hitTestInteractive(localOffset);
}
