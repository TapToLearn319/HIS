import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LoadingView extends StatefulWidget {
  final String title;
  final String subtitle;
  final double height;
  final String videoAsset;

  const LoadingView({
    super.key,
    this.title = 'Loading . . .',
    this.subtitle = 'The bird is spreading its wings...',
    this.height = 620,
    this.videoAsset = 'assets/videos/loading.mp4',
  });

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  late final VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset(widget.videoAsset)
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Center(
        child: Container(
          width: 560,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE1ECF7), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 32,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 320,
                height: 190,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAFF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child:
                    _videoController.value.isInitialized
                        ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController.value.size.width,
                            height: _videoController.value.size.height,
                            child: VideoPlayer(_videoController),
                          ),
                        )
                        : const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF44A0FF),
                          ),
                        ),
              ),
              const SizedBox(height: 30),
              const _LoadingDots(),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF002B4E),
                  fontSize: 26,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF868C98),
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final active = (_controller.value * 3).floor() % 3;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final isActive = i == active;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: isActive ? 14 : 9,
              height: 9,
              decoration: BoxDecoration(
                color:
                    isActive
                        ? const Color(0xFF44A0FF)
                        : const Color(0xFFCEE6FF),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}