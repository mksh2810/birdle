import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service to handle loading and showing rewarded ads.
///
/// To earn revenue from your ads:
/// 1. Register an account at https://admob.google.com/
/// 2. Create an App and get your AdMob App ID.
/// 3. Create a Rewarded Ad Unit and get your Rewarded Ad Unit ID.
/// 4. Replace the ID constants below with your real IDs.
class AdService {
  AdService._internal();
  static final AdService instance = AdService._internal();

  // =========================================================================
  // REPLACE THESE WITH YOUR REAL PRODUCTION ADMOB IDs TO EARN MONEY!
  // =========================================================================
  
  /// Your production AdMob Application ID.
  /// Replace these in android/app/src/main/AndroidManifest.xml and ios/Runner/Info.plist as well.
  static const String androidAppId = 'ca-app-pub-4649783662485857~9436700999';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  /// Your production Rewarded Ad Unit IDs.
  static const String androidRewardedAdUnitId = 'ca-app-pub-4649783662485857/1481767895';
  static const String iosRewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  // =========================================================================

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  /// Returns the appropriate Rewarded Ad Unit ID based on the current platform.
  String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return androidRewardedAdUnitId;
    } else if (Platform.isIOS) {
      return iosRewardedAdUnitId;
    }
    return '';
  }

  /// Initializes the Mobile Ads SDK.
  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return; // Ads are only supported on Android and iOS
    }
    await MobileAds.instance.initialize();
    loadRewardedAd();
  }

  /// Pre-loads a rewarded ad so it is ready when the player requests a hint.
  void loadRewardedAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    if (_isAdLoading || _rewardedAd != null) return;

    _isAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
          debugPrint('Rewarded ad loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isAdLoading = false;
          debugPrint('Rewarded ad failed to load: ${error.message}');
          // Retry loading after 15 seconds
          Future.delayed(const Duration(seconds: 15), loadRewardedAd);
        },
      ),
    );
  }

  /// Shows the pre-loaded rewarded ad to the player.
  ///
  /// Calls [onRewardEarned] if the user successfully watches the ad.
  /// Calls [onAdFailed] if the ad fails to display or is not loaded yet.
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    required VoidCallback onAdFailed,
  }) {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // In web/desktop or test modes, simulate a successful ad view
      onRewardEarned();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('Warning: Ad requested but not loaded yet. Retrying load.');
      loadRewardedAd();
      onAdFailed();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load the next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onRewardEarned();
      },
    );
  }
}
