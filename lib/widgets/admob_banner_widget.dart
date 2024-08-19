// lib/widgets/admob_banner_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Conditional imports
import 'admob_banner_web.dart' if (dart.library.io) 'admob_banner_mobile.dart' as platform;

class AdMobBannerWidget extends StatefulWidget {
  final bool hasEnoughContent;

  const AdMobBannerWidget({Key? key, required this.hasEnoughContent}) : super(key: key);

  @override
  _AdMobBannerWidgetState createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<AdMobBannerWidget> {
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.hasEnoughContent) {
      _loadMobileAd();
    }
  }

  void _loadMobileAd() {
    BannerAd(
      adUnitId: 'ca-app-pub-9391132389131438/2478785379',
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    ).load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasEnoughContent) {
      return SizedBox();
    }

    if (kIsWeb) {
      return platform.buildWebAd(hasEnoughContent: widget.hasEnoughContent);
    } else {
      return _bannerAd != null
          ? Container(
        height: 50,
        child: AdWidget(ad: _bannerAd!),
      )
          : SizedBox();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}