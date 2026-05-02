import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

/// A customizable shimmer loading effect widget.
/// Used as a placeholder during data loading to improve perceived performance.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return widget.isLoading
            ? ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: const [
                      Color(0xFFE0E0E0),
                      Color(0xFFF5F5F5),
                      Color(0xFFE0E0E0),
                    ],
                    stops: [
                      0.0,
                      0.5 + _animation.value * 0.3,
                      1.0,
                    ],
                    transform: _SlidingGradientTransform(_animation.value),
                  ).createShader(bounds);
                },
                child: widget.child,
              )
            : widget.child;
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// Dark-mode compatible shimmer box for building custom skeletons.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: color ?? (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8E8E8)),
      ),
    );
  }
}

/// Skeleton placeholder for a chat list item (Zalo-style).
class ChatListSkeletonItem extends StatelessWidget {
  const ChatListSkeletonItem({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF131313) : Colors.white;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const ShimmerBox(width: 52, height: 52, borderRadius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ShimmerBox(width: 140, height: 16, borderRadius: 4),
                    const ShimmerBox(width: 40, height: 12, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: ShimmerBox(width: double.infinity, height: 13, borderRadius: 4)),
                    const SizedBox(width: 8),
                    const ShimmerBox(width: 20, height: 20, borderRadius: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for a message bubble in chat detail.
class MessageBubbleSkeleton extends StatelessWidget {
  final bool isMine;
  final double widthFraction;

  const MessageBubbleSkeleton({
    super.key,
    required this.isMine,
    this.widthFraction = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMine
        ? (isDark ? const Color(0xFF115684) : const Color(0xFFDDF2FF))
        : (isDark ? const Color(0xFF2A2B2F) : Colors.white);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            const ShimmerBox(width: 30, height: 30, borderRadius: 15),
            const SizedBox(width: 6),
          ],
          Container(
            width: MediaQuery.of(context).size.width * widthFraction,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE0E0E0),
                ),
                const SizedBox(height: 6),
                ShimmerBox(
                  width: 180,
                  height: 14,
                  borderRadius: 4,
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE0E0E0),
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for chat detail screen (messages area).
class ChatDetailSkeleton extends StatelessWidget {
  const ChatDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 12,
      itemBuilder: (context, index) {
        final isMine = index % 3 == 0;
        final widthFraction = 0.55 + (index % 4) * 0.08;
        return MessageBubbleSkeleton(
          isMine: isMine,
          widthFraction: widthFraction.clamp(0.45, 0.75),
        );
      },
    );
  }
}

/// Skeleton placeholder for profile screen.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Center(child: ShimmerBox(width: 96, height: 96, borderRadius: 48)),
          const SizedBox(height: 16),
          const Center(child: ShimmerBox(width: 160, height: 22, borderRadius: 6)),
          const SizedBox(height: 8),
          const Center(child: ShimmerBox(width: 100, height: 14, borderRadius: 4)),
          const SizedBox(height: 24),
          const ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 48, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for a contact list item.
class ContactListSkeletonItem extends StatelessWidget {
  const ContactListSkeletonItem({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const ShimmerBox(width: 44, height: 44, borderRadius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 140, height: 15, borderRadius: 4),
                const SizedBox(height: 6),
                const ShimmerBox(width: 90, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder for contacts screen (loading state).
class ContactsSkeleton extends StatelessWidget {
  const ContactsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = isDark ? DarkColors.surface : Colors.white;

    return ListView(
      children: [
        // Header action row
        Container(
          color: sectionColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const ShimmerBox(width: 150, height: 34, borderRadius: 17),
              const SizedBox(width: 8),
              const ShimmerBox(width: 120, height: 34, borderRadius: 17),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Friend requests + Birthday
        Container(
          color: sectionColor,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: const [
              ShimmerBox(width: double.infinity, height: 56, borderRadius: 0),
              ShimmerBox(width: double.infinity, height: 56, borderRadius: 0),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Letter groups
        ...List.generate(4, (i) {
          return Container(
            color: sectionColor,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 20, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                ...List.generate(i + 1, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ContactListSkeletonItem(),
                )),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Skeleton placeholder for discover screen.
class DiscoverSkeleton extends StatelessWidget {
  const DiscoverSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = isDark ? DarkColors.surface : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerBox(width: double.infinity, height: 56, borderRadius: 12),
        const SizedBox(height: 24),
        ...List.generate(6, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            color: sectionColor,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const ShimmerBox(width: 48, height: 48, borderRadius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 160, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 220, height: 13, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

/// Skeleton placeholder for GroupSettingsScreen.
class GroupSettingsSkeleton extends StatelessWidget {
  const GroupSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionColor = isDark ? DarkColors.surface : Colors.white;

    return ListView(
      children: [
        const SizedBox(height: 16),
        ...List.generate(3, (i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ShimmerBox(width: 120, height: 14, borderRadius: 4),
            ),
            Container(
              color: sectionColor,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: List.generate(2 + i, (j) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(child: ShimmerBox(width: double.infinity, height: 16, borderRadius: 4)),
                      const SizedBox(width: 12),
                      ShimmerBox(width: 40, height: 24, borderRadius: 12),
                    ],
                  ),
                )),
              ),
            ),
            const SizedBox(height: 12),
          ],
        )),
      ],
    );
  }
}
