// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'navigator.dart';

/// Messages for route change notifications.
class RouteNotificationMessages {
  // This class is not meant to be instatiated or extended; this constructor
  // prevents instantiation and extension.
  // ignore: unused_element
  RouteNotificationMessages._();

  /// When the engine is Web notify the platform for a route change.
  static void maybeNotifyRouteChange(String methodName, Route<dynamic> route, Route<dynamic> previousRoute) {
    if(kIsWeb) {
      _notifyRouteChange(methodName, route, previousRoute);
    } else {
      // No op.
    }
  }

  /// Notifies the platform of a route change.
  ///
  /// There are three methods: 'routePushed', 'routePopped', 'routeReplaced'.
  ///
  /// See also:
  ///
  ///  * [SystemChannels.navigation], which handles subsequent navigation
  ///    requests.
  static void _notifyRouteChange(String methodName, Route<dynamic> route, Route<dynamic> previousRoute) {
    final String previousRouteName = previousRoute?.settings?.name;
    final String routeName = route?.settings?.name;
    SystemChannels.navigation.invokeMethod<void>(
      methodName,
      <String, dynamic>{
        'previousRouteName': previousRouteName,
        'routeName': routeName,
      },
    );
  }
}
