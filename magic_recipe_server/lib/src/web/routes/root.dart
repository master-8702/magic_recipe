import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:magic_recipe_server/src/web/widgets/flutter_web_page.dart';

class RouteRoot extends WidgetRoute {
  @override
  Future<Widget> build(Session session, HttpRequest request) async {
    return FlutterWebPage();
  }
}
