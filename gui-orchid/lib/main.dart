import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:orchid/api/purchase/orchid_purchase.dart';
import 'package:orchid/pages/orchid_app.dart';
import 'api/configuration/orchid_vpn_config.dart';
import 'api/orchid_api.dart';
import 'api/orchid_log_api.dart';
import 'api/orchid_platform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OrchidAPI().logger().write("App Startup");
  OrchidAPI().applicationReady();
  OrchidPlatform.pretendToBeAndroid = (await OrchidVPNConfig.getUserConfigJS())
      .evalBoolDefault('isAndroid', false);
  if (OrchidPlatform.pretendToBeAndroid) {
    log("pretendToBeAndroid = ${OrchidPlatform.pretendToBeAndroid}");
  }
  if (Platform.isIOS || Platform.isMacOS || Platform.isAndroid) {
    OrchidPurchaseAPI().initStoreListener();
  }
  runApp(OrchidApp());
}
