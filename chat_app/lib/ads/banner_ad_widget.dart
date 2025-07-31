import 'package:flutter/foundation.dart'; // 👈 Needed for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!kIsWeb) {
      _bannerAd = BannerAd(
        adUnitId: 'ca-app-pub-3940256099942544/6300978111', // ✅ Test ID
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) => setState(() {}),
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            debugPrint('Ad load failed (code=${error.code}): ${error.message}');
          },
        ),
      )..load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Skip ad widget entirely if on web or if ad isn't loaded yet
    if (kIsWeb || _bannerAd == null) return const SizedBox.shrink();

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
