import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/network_service.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  bool _wasOffline = false;
  bool _showBanner = false;
  bool _isReconnected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _yAnim = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkServiceProvider);

    if (!network.isOnline) {
      if (!_wasOffline) {
        // Just went offline
        _wasOffline = true;
        _showBanner = true;
        _isReconnected = false;
        _controller.forward();
      }
    } else {
      if (_wasOffline) {
        // Just returned online
        _wasOffline = false;
        _isReconnected = true;
        // Keep banner showing for 2 seconds as "Back Online"
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !ref.read(networkServiceProvider).isOnline) {
            // Checked again in case dropped offline again
            return;
          }
          if (mounted) {
            _controller.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showBanner = false;
                  _isReconnected = false;
                });
              }
            });
          }
        });
      }
    }

    if (!_showBanner) return const SizedBox.shrink();

    final bgColor = _isReconnected
        ? Colors.green.withOpacity(0.9)
        : Colors.redAccent.withOpacity(0.9);

    final bannerText = _isReconnected
        ? 'Back Online'
        : 'Offline Mode';

    final bannerIcon = _isReconnected
        ? Icons.wifi_rounded
        : Icons.wifi_off_rounded;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0.0, _yAnim.value),
          child: Opacity(
            opacity: _controller.value,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: bgColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(bannerIcon, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    bannerText,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
