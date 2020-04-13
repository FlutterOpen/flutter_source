// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'button_theme.dart';
import 'color_scheme.dart';
import 'flat_button.dart';
import 'material.dart';
import 'scaffold.dart';
import 'snack_bar_theme.dart';
import 'theme.dart';
import 'theme_data.dart';

const double _singleLineVerticalPadding = 14.0;

// TODO(ianh): We should check if the given text and actions are going to fit on
// one line or not, and if they are, use the single-line layout, and if not, use
// the multiline layout. See link above.

// TODO(ianh): Implement the Tablet version of snackbar if we're "on a tablet".

const Duration _snackBarTransitionDuration = Duration(milliseconds: 250);
const Duration _snackBarDisplayDuration = Duration(milliseconds: 4000);
const Curve _snackBarHeightCurve = Curves.fastOutSlowIn;
const Curve _snackBarFadeInCurve = Interval(0.45, 1.0, curve: Curves.fastOutSlowIn);
const Curve _snackBarFadeOutCurve = Interval(0.72, 1.0, curve: Curves.fastOutSlowIn);

/// Specify how a [SnackBar] was closed.
///
/// The [ScaffoldState.showSnackBar] function returns a
/// [ScaffoldFeatureController]. The value of the controller's closed property
/// is a Future that resolves to a SnackBarClosedReason. Applications that need
/// to know how a snackbar was closed can use this value.
///
/// Example:
///
/// ```dart
/// Scaffold.of(context).showSnackBar(
///   SnackBar( ... )
/// ).closed.then((SnackBarClosedReason reason) {
///    ...
/// });
/// ```
enum SnackBarClosedReason {
  /// The snack bar was closed after the user tapped a [SnackBarAction].
  action,

  /// The snack bar was closed through a [SemanticAction.dismiss].
  dismiss,

  /// The snack bar was closed by a user's swipe.
  swipe,

  /// The snack bar was closed by the [ScaffoldFeatureController] close callback
  /// or by calling [ScaffoldState.hideCurrentSnackBar] directly.
  hide,

  /// The snack bar was closed by an call to [ScaffoldState.removeCurrentSnackBar].
  remove,

  /// The snack bar was closed because its timer expired.
  timeout,
}

/// A button for a [SnackBar], known as an "action".
///
/// Snack bar actions are always enabled. If you want to disable a snack bar
/// action, simply don't include it in the snack bar.
///
/// Snack bar actions can only be pressed once. Subsequent presses are ignored.
///
/// See also:
///
///  * [SnackBar]
///  * <https://material.io/design/components/snackbars.html>
class SnackBarAction extends StatefulWidget {
  /// Creates an action for a [SnackBar].
  ///
  /// The [label] and [onPressed] arguments must be non-null.
  const SnackBarAction({
    Key key,
    this.textColor,
    this.disabledTextColor,
    @required this.label,
    @required this.onPressed,
  }) : assert(label != null),
       assert(onPressed != null),
       super(key: key);

  /// The button label color. If not provided, defaults to [accentColor].
  final Color textColor;

  /// The button disabled label color. This color is shown after the
  /// [snackBarAction] is dismissed.
  final Color disabledTextColor;

  /// The button label.
  final String label;

  /// The callback to be called when the button is pressed. Must not be null.
  ///
  /// This callback will be called at most once each time this action is
  /// displayed in a [SnackBar].
  final VoidCallback onPressed;

  @override
  _SnackBarActionState createState() => _SnackBarActionState();
}

class _SnackBarActionState extends State<SnackBarAction> {
  bool _haveTriggeredAction = false;

  void _handlePressed() {
    if (_haveTriggeredAction)
      return;
    setState(() {
      _haveTriggeredAction = true;
    });
    widget.onPressed();
    Scaffold.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.action);
  }

  @override
  Widget build(BuildContext context) {
    final SnackBarThemeData snackBarTheme = Theme.of(context).snackBarTheme;
    final Color textColor = widget.textColor ?? snackBarTheme.actionTextColor;
    final Color disabledTextColor = widget.disabledTextColor ?? snackBarTheme.disabledActionTextColor;

    return FlatButton(
      onPressed: _haveTriggeredAction ? null : _handlePressed,
      child: Text(widget.label),
      textColor: textColor,
      disabledTextColor: disabledTextColor,
    );
  }
}

/// A lightweight message with an optional action which briefly displays at the
/// bottom of the screen.
///
/// To display a snack bar, call `Scaffold.of(context).showSnackBar()`, passing
/// an instance of [SnackBar] that describes the message.
///
/// To control how long the [SnackBar] remains visible, specify a [duration].
///
/// A SnackBar with an action will not time out when TalkBack or VoiceOver are
/// enabled. This is controlled by [AccessibilityFeatures.accessibleNavigation].
///
/// See also:
///
///  * [Scaffold.of], to obtain the current [ScaffoldState], which manages the
///    display and animation of snack bars.
///  * [ScaffoldState.showSnackBar], which displays a [SnackBar].
///  * [ScaffoldState.removeCurrentSnackBar], which abruptly hides the currently
///    displayed snack bar, if any, and allows the next to be displayed.
///  * [SnackBarAction], which is used to specify an [action] button to show
///    on the snack bar.
///  * [SnackBarThemeData], to configure the default property values for
///    [SnackBar] widgets.
///  * <https://material.io/design/components/snackbars.html>
class SnackBar extends StatefulWidget {
  /// Creates a snack bar.
  ///
  /// The [content] argument must be non-null. The [elevation] must be null or
  /// non-negative.
  const SnackBar({
    Key key,
    @required this.content,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.behavior,
    this.action,
    this.duration = _snackBarDisplayDuration,
    this.animation,
    this.onVisible,
  }) : assert(elevation == null || elevation >= 0.0),
       assert(content != null),
       assert(duration != null),
       super(key: key);

  /// The primary content of the snack bar.
  ///
  /// Typically a [Text] widget.
  final Widget content;

  /// The Snackbar's background color. If not specified it will use
  /// [ThemeData.snackBarTheme.backgroundColor]. If that is not specified
  /// it will default to a dark variation of [ColorScheme.surface] for light
  /// themes, or [ColorScheme.onSurface] for dark themes.
  final Color backgroundColor;

  /// The z-coordinate at which to place the snack bar. This controls the size
  /// of the shadow below the snack bar.
  ///
  /// Defines the card's [Material.elevation].
  ///
  /// If this property is null, then [ThemeData.snackBarTheme.elevation] is
  /// used, if that is also null, the default value is 6.0.
  final double elevation;

  /// The shape of the snack bar's [Material].
  ///
  /// Defines the snack bar's [Material.shape].
  ///
  /// If this property is null then [ThemeData.snackBarTheme.shape] is used.
  /// If that's null then the shape will depend on the [SnackBarBehavior]. For
  /// [SnackBarBehavior.fixed], no overriding shape is specified, so the
  /// [SnackBar] is rectangular. For [SnackBarBehavior.floating], it uses a
  /// [RoundedRectangleBorder] with a circular corner radius of 4.0.
  final ShapeBorder shape;

  /// This defines the behavior and location of the snack bar.
  ///
  /// Defines where a [SnackBar] should appear within a [Scaffold] and how its
  /// location should be adjusted when the scaffold also includes a
  /// [FloatingActionButton] or a [BottomNavigationBar]
  ///
  /// If this property is null, then [ThemeData.snackBarTheme.behavior]
  /// is used. If that is null, then the default is [SnackBarBehavior.fixed].
  final SnackBarBehavior behavior;

  /// (optional) An action that the user can take based on the snack bar.
  ///
  /// For example, the snack bar might let the user undo the operation that
  /// prompted the snackbar. Snack bars can have at most one action.
  ///
  /// The action should not be "dismiss" or "cancel".
  final SnackBarAction action;

  /// The amount of time the snack bar should be displayed.
  ///
  /// Defaults to 4.0s.
  ///
  /// See also:
  ///
  ///  * [ScaffoldState.removeCurrentSnackBar], which abruptly hides the
  ///    currently displayed snack bar, if any, and allows the next to be
  ///    displayed.
  ///  * <https://material.io/design/components/snackbars.html>
  final Duration duration;

  /// The animation driving the entrance and exit of the snack bar.
  final Animation<double> animation;

  /// Called the first time that the snackbar is visible within a [Scaffold].
  final VoidCallback onVisible;

  // API for Scaffold.showSnackBar():

  /// Creates an animation controller useful for driving a snack bar's entrance and exit animation.
  static AnimationController createAnimationController({ @required TickerProvider vsync }) {
    return AnimationController(
      duration: _snackBarTransitionDuration,
      debugLabel: 'SnackBar',
      vsync: vsync,
    );
  }

  /// Creates a copy of this snack bar but with the animation replaced with the given animation.
  ///
  /// If the original snack bar lacks a key, the newly created snack bar will
  /// use the given fallback key.
  SnackBar withAnimation(Animation<double> newAnimation, { Key fallbackKey }) {
    return SnackBar(
      key: key ?? fallbackKey,
      content: content,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      behavior: behavior,
      action: action,
      duration: duration,
      animation: newAnimation,
      onVisible: onVisible,
    );
  }

  @override
  State<SnackBar> createState() => _SnackBarState();
}


class _SnackBarState extends State<SnackBar> {
  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void didUpdateWidget(SnackBar oldWidget) {
    if (widget.animation != oldWidget.animation) {
      oldWidget.animation.removeStatusListener(_onAnimationStatusChanged);
      widget.animation.addStatusListener(_onAnimationStatusChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus animationStatus) {
    switch (animationStatus) {
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        break;
      case AnimationStatus.completed:
        if (widget.onVisible != null && !_wasVisible) {
          widget.onVisible();
        }
        _wasVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    assert(widget.animation != null);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final SnackBarThemeData snackBarTheme = theme.snackBarTheme;
    final bool isThemeDark = theme.brightness == Brightness.dark;

    // SnackBar uses a theme that is the opposite brightness from
    // the surrounding theme.
    final Brightness brightness = isThemeDark ? Brightness.light : Brightness.dark;
    final Color themeBackgroundColor = isThemeDark
      ? colorScheme.onSurface
      : Color.alphaBlend(colorScheme.onSurface.withOpacity(0.80), colorScheme.surface);
    final ThemeData inverseTheme = ThemeData(
      brightness: brightness,
      backgroundColor: themeBackgroundColor,
      colorScheme: ColorScheme(
        primary: colorScheme.onPrimary,
        primaryVariant: colorScheme.onPrimary,
        // For the button color, the spec says it should be primaryVariant, but for
        // backward compatibility on light themes we are leaving it as secondary.
        secondary: isThemeDark ? colorScheme.primaryVariant : colorScheme.secondary,
        secondaryVariant: colorScheme.onSecondary,
        surface: colorScheme.onSurface,
        background: themeBackgroundColor,
        error: colorScheme.onError,
        onPrimary: colorScheme.primary,
        onSecondary: colorScheme.secondary,
        onSurface: colorScheme.surface,
        onBackground: colorScheme.background,
        onError: colorScheme.error,
        brightness: brightness,
      ),
      snackBarTheme: snackBarTheme,
    );

    final TextStyle contentTextStyle = snackBarTheme.contentTextStyle ?? inverseTheme.textTheme.subtitle1;
    final SnackBarBehavior snackBarBehavior = widget.behavior ?? snackBarTheme.behavior ?? SnackBarBehavior.fixed;
    final bool isFloatingSnackBar = snackBarBehavior == SnackBarBehavior.floating;
    final double snackBarPadding = isFloatingSnackBar ? 16.0 : 24.0;

    final CurvedAnimation heightAnimation = CurvedAnimation(parent: widget.animation, curve: _snackBarHeightCurve);
    final CurvedAnimation fadeInAnimation = CurvedAnimation(parent: widget.animation, curve: _snackBarFadeInCurve);
    final CurvedAnimation fadeOutAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: _snackBarFadeOutCurve,
      reverseCurve: const Threshold(0.0),
    );

    Widget snackBar = SafeArea(
      top: false,
      bottom: !isFloatingSnackBar,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(width: snackBarPadding),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: _singleLineVerticalPadding),
              child: DefaultTextStyle(
                style: contentTextStyle,
                child: widget.content,
              ),
            ),
          ),
          if (widget.action != null)
            ButtonTheme(
              textTheme: ButtonTextTheme.accent,
              minWidth: 64.0,
              padding: EdgeInsets.symmetric(horizontal: snackBarPadding),
              child: widget.action,
            )
          else
            SizedBox(width: snackBarPadding),
        ],
      ),
    );

    final double elevation = widget.elevation ?? snackBarTheme.elevation ?? 6.0;
    final Color backgroundColor = widget.backgroundColor ?? snackBarTheme.backgroundColor ?? inverseTheme.backgroundColor;
    final ShapeBorder shape = widget.shape
      ?? snackBarTheme.shape
      ?? (isFloatingSnackBar ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)) : null);

    snackBar = Material(
      shape: shape,
      elevation: elevation,
      color: backgroundColor,
      child: Theme(
        data: inverseTheme,
        child: mediaQueryData.accessibleNavigation
            ? snackBar
            : FadeTransition(
                opacity: fadeOutAnimation,
                child: snackBar,
              ),
      ),
    );

    if (isFloatingSnackBar) {
      snackBar = Padding(
        padding: const EdgeInsets.fromLTRB(15.0, 5.0, 15.0, 10.0),
        child: snackBar,
      );
    }

    snackBar = Semantics(
      container: true,
      liveRegion: true,
      onDismiss: () {
        Scaffold.of(context).removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
      },
      child: Dismissible(
        key: const Key('dismissible'),
        direction: DismissDirection.down,
        resizeDuration: null,
        onDismissed: (DismissDirection direction) {
          Scaffold.of(context).removeCurrentSnackBar(reason: SnackBarClosedReason.swipe);
        },
        child: snackBar,
      ),
    );

    Widget snackBarTransition;
    if (mediaQueryData.accessibleNavigation) {
      snackBarTransition = snackBar;
    } else if (isFloatingSnackBar) {
      snackBarTransition = FadeTransition(
        opacity: fadeInAnimation,
        child: snackBar,
      );
    } else {
      snackBarTransition = AnimatedBuilder(
        animation: heightAnimation,
        builder: (BuildContext context, Widget child) {
          return Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: heightAnimation.value,
            child: child,
          );
        },
        child: snackBar,
      );
    }

    return ClipRect(child: snackBarTransition);
  }
}
