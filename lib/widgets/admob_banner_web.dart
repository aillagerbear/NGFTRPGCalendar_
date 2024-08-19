import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

Widget buildWebAd({required bool hasEnoughContent}) {
  if (!hasEnoughContent) return SizedBox();

  final String adId = 'adSenseAd-${DateTime.now().millisecondsSinceEpoch}';
  final String viewType = 'adSenseView-$adId';

  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
        (int viewId) {
      final div = html.DivElement()
        ..id = adId
        ..style.width = '100%'
        ..style.height = '100px';

      div.innerHtml = '''
        <ins class="adsbygoogle"
             style="display:block"
             data-ad-client="ca-pub-9391132389131438"
             data-ad-slot="3051400941"
             data-ad-format="auto"
             data-full-width-responsive="true"></ins>
      ''';

      // 광고 초기화를 페이지 로드 후로 지연
      html.window.onLoad.listen((_) {
        Future.delayed(Duration(seconds: 2), () {
          try {
            if (!js.context.hasProperty('adsbygoogle')) {
              print('AdSense 스크립트가 로드되지 않았습니다.');
              return;
            }

            final ads = js.context['adsbygoogle'] as js.JsArray;
            if (ads.any((ad) => ad['adLayoutKey'] == adId)) {
              print('이 광고는 이미 초기화되었습니다: $adId');
              return;
            }

            js.context.callMethod('eval', ['''
              (adsbygoogle = window.adsbygoogle || []).push({
                adLayoutKey: "$adId"
              });
            ''']);
          } catch (e) {
            print('AdSense 광고 초기화 중 오류 발생: $e');
          }
        });
      });

      return div;
    },
  );

  return SizedBox(
    height: 100,
    child: HtmlElementView(viewType: viewType),
  );
}