import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        TextInputFormatter,
        TextEditingValue,
        TextSelection;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart'
    show Geolocator, LocationPermission, LocationSettings, LocationAccuracy;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:mobile_scanner/mobile_scanner.dart'
    show MobileScanner, BarcodeCapture;
import 'package:qr_flutter/qr_flutter.dart' show QrImageView;
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        Supabase,
        SupabaseClient,
        PostgrestException,
        AuthException,
        AuthChangeEvent,
        AuthState,
        UserAttributes,
        FileOptions;

import 'config.dart';
import 'road_routes.dart';
import 'pay_logos.dart';

SupabaseClient get _sb => Supabase.instance.client;

const bool kDemoPayments = true;

const bool kDemoBuses = true;



const bool kSimulateTrip = false;
const double kSimSpeedKmh = 65;


const bool kSimFleet = true;

const bool kUseAiFunction = true;
bool get kAiOn => kUseAiFunction || kClaudeKey.isNotEmpty;

const Color kBg0 = Color(0xFF070B14);
const Color kBg1 = Color(0xFF0E1627);
const Color kSurface = Color(0xFF131D33);
const Color kSurface2 = Color(0xFF1B2A47);
const Color kGold = Color(0xFFE6B84A);
const Color kGoldLight = Color(0xFFF7DC8B);
const Color kGoldDark = Color(0xFFB8892B);
const Color kInk = Color(0xFF1A1405);
const Color kMuted = Color(0xFF9AA7BF);
const Color kGood = Color(0xFF3DDC97);
const Color kWarn = Color(0xFFFFB454);
const Color kBad = Color(0xFFFF6B6B);

const LinearGradient kGoldGradient = LinearGradient(
  colors: [kGoldLight, kGold, kGoldDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kBgGradient = LinearGradient(
  colors: [kBg1, kBg0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: kGold,
        brightness: Brightness.dark,
      ).copyWith(
        primary: kGold,
        onPrimary: kInk,
        secondary: kGoldLight,
        surface: kSurface,
        error: kBad,
      );

  final round = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg0,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGold,
        foregroundColor: kInk,
        shape: round,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kGoldLight,
        side: const BorderSide(color: kGoldDark),
        shape: round,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kGoldLight),
    ),
    dividerTheme: const DividerThemeData(color: Colors.white12),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurface2,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: round,
    ),
  );
}

// ---------- reusable widgets ----------
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kSurface2.withAlpha(215), kSurface.withAlpha(235)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool compact;

  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          gradient: kGoldGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: kGold.withAlpha(70),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 20,
                vertical: compact ? 9 : 15,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kInk,
                        ),
                      )
                    else if (icon != null)
                      Icon(icon, size: 18, color: kInk),
                    if (busy || icon != null) const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        fontSize: compact ? 13 : 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kGoldGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: kGold.withAlpha(90),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(Icons.directions_bus_filled, size: size * 0.58, color: kInk),
    );
  }
}

class Backdrop extends StatefulWidget {
  final Widget child;
  const Backdrop({super.key, required this.child});

  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _BackdropPainter(_c)),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

// Night sky + glowing orbs + dotted bus routes with little buses driving on
// them. Painted behind every screen.
class _BackdropPainter extends CustomPainter {
  final Animation<double> anim;
  final List<List<double>> _stars = () {
    final r = Random(7);
    return List.generate(
      46,
      (_) => [r.nextDouble(), r.nextDouble(), r.nextDouble()],
    );
  }();

  _BackdropPainter(this.anim) : super(repaint: anim);

  void _glow(Canvas c, Offset o, double r, Color col, int a) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(colors: [col.withAlpha(a), col.withAlpha(0)])
            .createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  Path _route(Size s, int k) {
    final w = s.width, h = s.height;
    final p = Path();
    if (k == 0) {
      p.moveTo(-10, h * 0.30);
      p.cubicTo(w * 0.25, h * 0.16, w * 0.45, h * 0.46, w * 0.70, h * 0.33);
      p.cubicTo(w * 0.85, h * 0.25, w * 0.95, h * 0.36, w + 10, h * 0.29);
    } else {
      p.moveTo(-10, h * 0.74);
      p.cubicTo(w * 0.20, h * 0.92, w * 0.40, h * 0.55, w * 0.62, h * 0.70);
      p.cubicTo(w * 0.80, h * 0.82, w * 0.90, h * 0.60, w + 10, h * 0.68);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final a = 2 * pi * t;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [kBg1, kBg0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );

    // drifting glow orbs
    _glow(
      canvas,
      Offset(
        size.width * (0.86 + 0.05 * sin(a)),
        size.height * (0.06 + 0.03 * cos(a)),
      ),
      280,
      kGold,
      50,
    );
    _glow(
      canvas,
      Offset(
        size.width * (0.10 + 0.05 * cos(a)),
        size.height * (0.95 - 0.03 * sin(a)),
      ),
      320,
      const Color(0xFF2F6BFF),
      44,
    );
    _glow(
      canvas,
      Offset(size.width * 0.55, size.height * (0.52 + 0.05 * sin(2 * a))),
      240,
      const Color(0xFF8A4DFF),
      18,
    );

    // twinkling city lights
    for (final st in _stars) {
      final tw = 0.5 + 0.5 * sin(a * 2 + st[2] * 2 * pi);
      canvas.drawCircle(
        Offset(st[0] * size.width, st[1] * size.height),
        0.8 + st[2] * 1.2,
        Paint()..color = Colors.white.withAlpha((14 + 40 * tw).round()),
      );
    }

    // dotted routes, stops and moving buses
    for (var k = 0; k < 2; k++) {
      final m = _route(size, k).computeMetrics().first;
      final dot = Paint()..color = Colors.white.withAlpha(26);
      for (double d = 0; d < m.length; d += 16) {
        final tg = m.getTangentForOffset(d);
        if (tg != null) canvas.drawCircle(tg.position, 1.6, dot);
      }
      for (final f in [0.2, 0.5, 0.8]) {
        final tg = m.getTangentForOffset(m.length * f);
        if (tg == null) continue;
        canvas.drawCircle(tg.position, 7, Paint()..color = kGold.withAlpha(20));
        canvas.drawCircle(tg.position, 3, Paint()..color = kGold.withAlpha(90));
      }
      final f = (t + k * 0.45) % 1.0;
      final tg = m.getTangentForOffset(m.length * f);
      if (tg != null) {
        canvas.drawCircle(
          tg.position,
          16,
          Paint()..color = kGold.withAlpha(34),
        );
        canvas.drawCircle(
          tg.position,
          5,
          Paint()..color = kGold.withAlpha(210),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) => false;
}

// Scaffold whose whole page sits on the animated backdrop.
class BackdropScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  const BackdropScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

// soft pulsing ring (used for running buses)
class PulseRing extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color color;
  final double size;
  const PulseRing({
    super.key,
    required this.child,
    this.active = true,
    this.color = kGold,
    this.size = 38,
  });

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              return Transform.scale(
                scale: 1 + 0.9 * v,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withAlpha((95 * (1 - v)).round()),
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

// ---------- payment methods + logo badges ----------
// The brand logos of GCash / Maya are trademarks, so the app ships neutral
// icon badges. To show the official logos, put the files from each brand's
// media kit in assets/pay/ (gcash.png, maya.png, card.png) and list the
// folder under flutter > assets in pubspec.yaml. They are picked up
// automatically; if a file is missing the icon badge is shown instead.
class PayMethod {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  const PayMethod(this.key, this.name, this.icon, this.color);
}

const List<PayMethod> kPayMethods = [
  PayMethod(
    'gcash',
    'GCash',
    Icons.account_balance_wallet_rounded,
    Color(0xFF2F6BFF),
  ),
  PayMethod('maya', 'Maya', Icons.smartphone_rounded, kGood),
  PayMethod('card', 'Card', Icons.credit_card_rounded, kGold),
];

class PayLogo extends StatelessWidget {
  final PayMethod method;
  final double size;
  final bool selected;
  const PayLogo({
    super.key,
    required this.method,
    this.size = 48,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = size * 0.28;
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: method.color.withAlpha(35),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: method.color.withAlpha(130)),
      ),
      child: Icon(method.icon, color: method.color, size: size * 0.52),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: method.color.withAlpha(selected ? 120 : 0),
            blurRadius: selected ? 16 : 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: kPayLogoBytes[method.key] == null
            ? badge
            : Image.memory(
                kPayLogoBytes[method.key]!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                errorBuilder: (_, e, __) {
                  debugPrint('PayLogo ${method.key} failed: $e');
                  return badge;
                },
              ),
      ),
    );
  }
}

/// One selectable payment row (logo + name + radio).
class PayMethodTile extends StatelessWidget {
  final PayMethod method;
  final bool selected;
  final VoidCallback? onTap;
  const PayMethodTile({
    super.key,
    required this.method,
    required this.selected,
    this.onTap,
  });

  String get _sub => switch (method.key) {
    'gcash' => 'Pay with your GCash wallet',
    'maya' => 'Pay with your Maya wallet',
    'cash' => 'Pay the conductor face to face when you board',
    _ => 'Visa / Mastercard',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      method.color.withAlpha(45),
                      method.color.withAlpha(12),
                    ],
                  )
                : null,
            color: selected ? null : kSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? method.color : Colors.white12,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              PayLogo(method: method, size: 50, selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _sub,
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  key: ValueKey(selected),
                  color: selected ? method.color : kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades + slides a child up when it first appears.
class FadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlide({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index.clamp(0, 8)) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Small stat card: icon + big number + label.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = kGold,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(40), color.withAlpha(10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seat-occupancy bar for a bus card.
class OccupancyBar extends StatelessWidget {
  final int taken;
  final int total;
  final int standingTaken;
  const OccupancyBar({
    super.key,
    required this.taken,
    required this.total,
    this.standingTaken = 0,
  });

  @override
  Widget build(BuildContext context) {
    final f = total == 0 ? 0.0 : (taken / total).clamp(0.0, 1.0);
    final c = f > 0.85 ? kBad : (f > 0.6 ? kWarn : kGood);
    final full = taken >= total;
    final standLeft = (kStandingMax - standingTaken).clamp(0, kStandingMax);
    return Row(
      children: [
        Icon(Icons.event_seat_rounded, size: 13, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 4,
              backgroundColor: Colors.white12,
              color: c,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          full
              ? (standLeft > 0 ? 'Full • $standLeft standing' : 'Full')
              : '${total - taken} free',
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

AppBar premiumBar(
  String title, {
  List<Widget> actions = const [],
  PreferredSizeWidget? bottom,
  bool brand = false,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: Colors.white,
    titleSpacing: 16,
    title: Row(
      children: [
        if (brand) ...[const BrandMark(size: 30), const SizedBox(width: 10)],
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}

TabBar premiumTabs(List<String> labels) => TabBar(
  indicatorColor: kGold,
  labelColor: kGold,
  unselectedLabelColor: kMuted,
  dividerColor: Colors.transparent,
  indicatorSize: TabBarIndicatorSize.label,
  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
  tabs: labels.map((t) => Tab(text: t)).toList(),
);

InputDecoration fieldDeco(String label, IconData icon) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: kMuted),
  prefixIcon: Icon(icon, color: kGold, size: 20),
  filled: true,
  fillColor: kBg1,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Colors.white12),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: kGold, width: 1.4),
  ),
);

class PDrop<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String hint;
  final ValueChanged<T?>? onChanged;

  const PDrop({
    super.key,
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: kSurface2,
          iconEnabledColor: kGold,
          hint: Text(hint, style: const TextStyle(color: kMuted)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: kMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class MsgBox extends StatelessWidget {
  final String text;
  final bool good;
  const MsgBox(this.text, {super.key, this.good = false});

  @override
  Widget build(BuildContext context) {
    final c = good ? kGood : kBad;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            good ? Icons.check_circle_outline : Icons.error_outline,
            color: c,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

Widget kv(String k, String v, {bool bold = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Flexible(
        child: Text(
          k,
          style: TextStyle(
            color: bold ? Colors.white : kMuted,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          v,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: bold ? kGold : Colors.white,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ),
    ],
  ),
);

Widget tileCard({
  required IconData icon,
  required String title,
  required String subtitle,
  Widget? trailing,
  Color accent = kGold,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: GlassCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: kMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  ),
);

// ticket "tear" line with two cut-outs
class TearLine extends StatelessWidget {
  const TearLine({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Container(
            width: 12,
            decoration: const BoxDecoration(
              color: kBg0,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) {
                final n = (cons.maxWidth / 10).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    n,
                    (_) =>
                        Container(width: 5, height: 1.5, color: Colors.white24),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 12,
            decoration: const BoxDecoration(
              color: kBg0,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// (the map now uses normal OpenStreetMap colours)

// ---------- HELPERS ----------
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

String peso(num v) => '₱${v.toStringAsFixed(2)}';

// ---- standing room ----
// When every seat is taken, passengers can still reserve a standing place.
// Standing places are numbered after the last seat (seat 37 = "Standing 1").
const int kStandingMax = 20;
String seatLabel(int s) => s > kSeats ? 'Standing ${s - kSeats}' : 'Seat $s';
int seatedCount(Iterable<int> taken) => taken.where((n) => n <= kSeats).length;
int standingCount(Iterable<int> taken) => taken.where((n) => n > kSeats).length;

String typeLabel(String t) => switch (t) {
  'student' => 'Student',
  'senior' => 'Senior',
  'pwd' => 'PWD',
  _ => 'Regular',
};

String statusText(String s) => switch (s) {
  'reserved' => 'Reserved - not paid yet',
  'boarded' => 'Boarded - paid',
  'completed' => 'Trip finished',
  'cancelled' => 'Cancelled',
  'missed' => 'Cancelled - bus passed your pick-up point',
  _ => s,
};

String statusShort(String s) => switch (s) {
  'reserved' => 'Reserved',
  'boarded' => 'Boarded',
  'completed' => 'Finished',
  'cancelled' => 'Cancelled',
  'missed' => 'Missed',
  _ => s,
};

Color statusColor(String s) => switch (s) {
  'reserved' => kWarn,
  'boarded' => kGood,
  'completed' => kMuted,
  _ => kBad,
};

// ---- how a ticket is paid ----
// due = still to collect in cash, online = paid in the app,
// cash = the conductor already collected it, paid = paid (method unknown).
String payState(Ticket t) {
  if (!t.paid) return 'due';
  if (t.payMethod == 'cash') return 'cash';
  if (t.payMethod == 'online') return 'online';
  return t.status == 'reserved' ? 'online' : 'paid';
}

String payLabel(Ticket t) => switch (payState(t)) {
  'online' => 'Paid online',
  'cash' => 'Paid in cash',
  'paid' => 'Paid',
  _ => 'Collect cash',
};

Color payColor(Ticket t) => payState(t) == 'due' ? kWarn : kGood;

String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

Future<T> _call<T>(Future<T> Function() f) async {
  try {
    return await f();
  } on PostgrestException catch (e) {
    throw Exception(e.message);
  }
}

// ---------- MODELS ----------
class Profile {
  final String id;
  final String name;
  final String role; // commuter, driver, conductor
  final String type; // regular, student, senior, pwd
  final String? busId;

  Profile({
    required this.id,
    required this.name,
    required this.role,
    required this.type,
    this.busId,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: '${m['id']}',
    name: '${m['full_name'] ?? ''}',
    role: '${m['role'] ?? 'commuter'}',
    type: '${m['passenger_type'] ?? 'regular'}',
    busId: m['bus_id']?.toString(),
  );
}

class Stop {
  final int seq;
  final String name;
  final LatLng pos;
  Stop({required this.seq, required this.name, required this.pos});
}

class Bus {
  final String id;
  final String routeId;
  final String route;
  final String destination;
  final LatLng pos;
  final double speed;
  final bool running;
  final int currentSeq;
  final String operator; // e.g. Bachelor Express
  final String busType; // e.g. Aircon, Ordinary
  final DateTime? updatedAt;
  final bool isLive; // a real driver phone is sending GPS right now

  Bus({
    required this.id,
    required this.routeId,
    required this.route,
    required this.destination,
    required this.pos,
    required this.speed,
    required this.running,
    required this.currentSeq,
    this.operator = 'Bachelor Express',
    this.busType = '',
    this.updatedAt,
    this.isLive = false,
  });

  Bus asLive() => Bus(
    id: id,
    routeId: routeId,
    route: route,
    destination: destination,
    pos: pos,
    speed: speed,
    running: running,
    currentSeq: currentSeq,
    operator: operator,
    busType: busType,
    updatedAt: updatedAt,
    isLive: true,
  );

  String get title => busType.isEmpty ? operator : '$operator • $busType';

  /// seconds since the bus phone last sent a GPS point
  int? get ageSeconds => updatedAt == null
      ? null
      : DateTime.now().toUtc().difference(updatedAt!).inSeconds;

  factory Bus.fromRow(Map<String, dynamic> j) {
    final updated = DateTime.tryParse('${j['updated_at']}')?.toUtc();
    final fresh =
        kDemoBuses ||
        (updated != null &&
            DateTime.now().toUtc().difference(updated).inSeconds <
                kStaleSeconds);
    final running = (j['running'] == true) && fresh;
    return Bus(
      id: '${j['id']}',
      routeId: '${j['route_id'] ?? ''}',
      route: '${j['route'] ?? ''}',
      destination: '${j['destination'] ?? ''}',
      pos: LatLng(_d(j['lat']), _d(j['lng'])),
      speed: running ? _d(j['speed']) : 0,
      running: running,
      currentSeq: _i(j['current_seq']),
      operator: (j['operator'] ?? 'Bachelor Express').toString(),
      busType: (j['bus_type'] ?? '').toString(),
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'operator': operator,
    'bus_type': busType,
    'route': route,
    'destination': destination,
    'running': running,
    'speed_kmh': speed.round(),
    'lat': double.parse(pos.latitude.toStringAsFixed(4)),
    'lng': double.parse(pos.longitude.toStringAsFixed(4)),
  };
}

class Quote {
  final double distance;
  final double fare;
  final double discount;
  final double fee;
  final double total;
  Quote({
    required this.distance,
    required this.fare,
    required this.discount,
    required this.fee,
    required this.total,
  });
}

class Ticket {
  final String id;
  final String busId;
  final String name;
  final String type;
  final String pickupName;
  final String dropoffName;
  final String code;
  final String status;
  final int seat;
  final int pickupSeq;
  final int dropoffSeq;
  final double fare;
  final double discount;
  final double fee;
  final double total;
  final bool paid;
  final String payMethod; // online, cash, or empty (older tickets)
  final LatLng? pickupPin; // exact red pin the passenger placed (optional)
  final LatLng? dropoffPin;

  Ticket({
    required this.id,
    required this.busId,
    required this.name,
    required this.type,
    required this.pickupName,
    required this.dropoffName,
    required this.code,
    required this.status,
    required this.seat,
    required this.pickupSeq,
    required this.dropoffSeq,
    required this.fare,
    required this.discount,
    required this.fee,
    required this.total,
    required this.paid,
    this.payMethod = '',
    this.pickupPin,
    this.dropoffPin,
  });

  factory Ticket.fromMap(Map<String, dynamic> m) => Ticket(
    id: '${m['id']}',
    busId: '${m['bus_id'] ?? ''}',
    name: '${m['passenger_name'] ?? ''}',
    type: '${m['passenger_type'] ?? 'regular'}',
    pickupName: '${m['pickup_name'] ?? ''}',
    dropoffName: '${m['dropoff_name'] ?? ''}',
    code: '${m['code'] ?? ''}',
    status: '${m['status'] ?? ''}',
    seat: _i(m['seat']),
    pickupSeq: _i(m['pickup_seq']),
    dropoffSeq: _i(m['dropoff_seq']),
    fare: _d(m['fare']),
    discount: _d(m['discount']),
    fee: _d(m['fee']),
    total: _d(m['total']),
    paid: m['paid'] == true,
    payMethod: '${m['pay_method'] ?? ''}',
    pickupPin: (m['pickup_lat'] != null && m['pickup_lng'] != null)
        ? LatLng(_d(m['pickup_lat']), _d(m['pickup_lng']))
        : null,
    dropoffPin: (m['dropoff_lat'] != null && m['dropoff_lng'] != null)
        ? LatLng(_d(m['dropoff_lat']), _d(m['dropoff_lng']))
        : null,
  );
}

// ---------- API (everything that talks to Supabase) ----------
class Api {
  static Future<Profile> myProfile() async {
    final row = await _sb
        .from('profiles')
        .select()
        .eq('id', _sb.auth.currentUser!.id)
        .single();
    return Profile.fromMap(row);
  }

  static Future<List<Bus>> buses() async {
    final rows = await _sb.from('buses').select().order('id', ascending: true);
    return rows.map((j) => Bus.fromRow(j)).toList();
  }

  static Future<Bus?> bus(String id) async {
    final rows = await _sb.from('buses').select().eq('id', id);
    if (rows.isEmpty) return null;
    return Bus.fromRow(rows.first);
  }

  static Future<List<Stop>> stops(String routeId) async {
    final rows = await _sb
        .from('route_stops')
        .select()
        .eq('route_id', routeId)
        .order('seq', ascending: true);
    final list = rows
        .map(
          (j) => Stop(
            seq: _i(j['seq']),
            name: '${j['name']}',
            pos: LatLng(_d(j['lat']), _d(j['lng'])),
          ),
        )
        .toList();
    list.sort((a, b) => a.seq.compareTo(b.seq)); // always 1, 2, 3 ...
    return list;
  }

  static Future<List<Map<String, dynamic>>> routes() async {
    final rows = await _sb
        .from('routes')
        .select()
        .order('name', ascending: true);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Quote> quote(
    String routeId,
    int pickup,
    int dropoff,
    String type,
  ) async {
    final res = await _call(
      () => _sb.rpc(
        'quote_fare',
        params: {
          'p_route': routeId,
          'p_pickup': pickup,
          'p_dropoff': dropoff,
          'p_type': type,
        },
      ),
    );
    final m = Map<String, dynamic>.from((res as List).first as Map);
    return Quote(
      distance: _d(m['distance_km']),
      fare: _d(m['fare']),
      discount: _d(m['discount']),
      fee: _d(m['fee']),
      total: _d(m['total']),
    );
  }

  static Future<Set<int>> takenSeats(String busId) async {
    try {
      final rows = await _sb.from('taken_seats').select().eq('bus_id', busId);
      return rows.map((r) => _i(r['seat'])).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<Ticket> reserve(
    Bus bus,
    int seat,
    int pickup,
    int dropoff,
  ) async {
    try {
      final res = await _sb.rpc(
        'reserve_seat',
        params: {
          'p_bus': bus.id,
          'p_seat': seat,
          'p_pickup': pickup,
          'p_dropoff': dropoff,
        },
      );
      return Ticket.fromMap(Map<String, dynamic>.from(res as Map));
    } on PostgrestException catch (e) {
      // 23505 = someone took the seat first
      if (e.code == '23505') {
        throw Exception('Seat $seat was just taken. Pick another seat.');
      }
      throw Exception(e.message);
    }
  }

  static Future<List<Ticket>> myTickets() async {
    final rows = await _sb
        .from('reservations')
        .select()
        .order('created_at', ascending: false);
    return rows.map((m) => Ticket.fromMap(m)).toList();
  }

  static Future<Ticket> myTicket(String id) async {
    final row = await _sb.from('reservations').select().eq('id', id).single();
    return Ticket.fromMap(row);
  }

  // Opens a PayMongo checkout (GCash / Maya / card) for one reservation.
  static Future<String> payUrl(String reservationId) async {
    try {
      final res = await _sb.functions.invoke(
        'create-payment',
        body: {'reservation_id': reservationId},
      );
      final data = res.data;
      final m = data is Map ? data : jsonDecode('$data') as Map;
      if (m['checkout_url'] == null) {
        throw Exception('${m['error'] ?? 'Could not start payment.'}');
      }
      return '${m['checkout_url']}';
    } catch (e) {
      throw Exception(_msg(e).replaceFirst('FunctionException', '').trim());
    }
  }

  static Future<void> demoPay(String id) =>
      _call(() => _sb.rpc('demo_pay', params: {'p_id': id}));

  static Future<void> cancel(String id) =>
      _call(() => _sb.rpc('cancel_reservation', params: {'p_id': id}));

  // ----- conductor -----
  static Future<Ticket?> lookup(String code) async {
    final res = await _call(
      () => _sb.rpc('conductor_lookup', params: {'p_code': code}),
    );
    final list = res as List;
    if (list.isEmpty) return null;
    return Ticket.fromMap(Map<String, dynamic>.from(list.first as Map));
  }

  static Future<bool> confirm(String code) async {
    final res = await _call(
      () => _sb.rpc('conductor_confirm', params: {'p_code': code}),
    );
    return res == true;
  }

  // The passenger pays cash to the conductor.
  static Future<bool> collectCash(String id) async {
    final res = await _call(
      () => _sb.rpc('conductor_collect_cash', params: {'p_id': id}),
    );
    return res == true;
  }

  // ----- driver / conductor applications (ID photo, admin approves) -----
  static Future<Map<String, dynamic>?> myStaffRequest() async {
    final rows = await _sb
        .from('staff_requests')
        .select()
        .eq('user_id', _sb.auth.currentUser!.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  // Uploads the ID photo to the private "staff-ids" bucket, then files the request.
  static Future<void> applyStaff({
    required String role,
    required String busHint,
    required String idNumber,
    String idCheck = 'unchecked',
    String idCheckNote = '',
    required XFile photo,
    required bool replace,
  }) async {
    final uid = _sb.auth.currentUser!.id;
    final bytes = await photo.readAsBytes();
    if (bytes.length > 6 * 1024 * 1024) {
      throw Exception('That photo is too big. Please use one under 6 MB.');
    }
    var ext = photo.name.contains('.')
        ? photo.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext)) ext = 'jpg';
    final path = '$uid/id_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage
        .from('staff-ids')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: photo.mimeType ?? 'image/jpeg'),
        );
    final row = {
      'wanted_role': role,
      'bus_hint': busHint.isEmpty ? null : busHint,
      'id_number': idNumber,
      'id_check': idCheck,
      'id_check_note': idCheckNote,
      'id_photo_path': path,
      'status': 'pending',
    };
    try {
      if (replace) {
        await _sb.from('staff_requests').update(row).eq('user_id', uid);
      } else {
        await _sb.from('staff_requests').insert({...row, 'user_id': uid});
      }
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  // ----- admin (enforced in the database, see admin_setup.sql) -----
  static Future<bool> isAdmin() async {
    try {
      final r = await _sb.rpc('is_admin');
      return r == true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> adminRequests() async {
    final res = await _call(() => _sb.rpc('admin_requests'));
    return (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> adminDecide(String userId, bool approve, String bus) =>
      _call(
        () => _sb.rpc(
          'admin_decide',
          params: {
            'p_user': userId,
            'p_approve': approve,
            // null (not '') when no bus: '' would violate profiles_bus_id_fkey
            'p_bus': bus.trim().isEmpty ? null : bus.trim(),
          },
        ),
      );

  // red pins: the exact spot a passenger chose to get on / off
  static Future<void> setPins(String ticketId, LatLng? pick, LatLng? drop) =>
      _call(
        () => _sb.rpc(
          'set_reservation_pins',
          params: {
            'p_id': ticketId,
            'p_plat': pick?.latitude,
            'p_plng': pick?.longitude,
            'p_dlat': drop?.latitude,
            'p_dlng': drop?.longitude,
          },
        ),
      );

  static Future<List<Map<String, dynamic>>> busPins() async {
    final res = await _call(() => _sb.rpc('bus_pins'));
    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // a driver picks which bus they are driving today
  static Future<void> chooseBus(String busId) =>
      _call(() => _sb.rpc('driver_select_bus', params: {'p_bus': busId}));

  static Future<String> idPhotoUrl(String path) =>
      _sb.storage.from('staff-ids').createSignedUrl(path, 600);

  // ----- driver + conductor -----
  static Future<List<Ticket>> manifest() async {
    final res = await _call(() => _sb.rpc('bus_manifest'));
    return (res as List)
        .map((e) => Ticket.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> complete(String id) =>
      _call(() => _sb.rpc('staff_complete', params: {'p_id': id}));

  // ----- driver -----
  static Future<void> startTrip(String routeId) =>
      _call(() => _sb.rpc('start_trip', params: {'p_route': routeId}));

  static Future<void> endTrip() => _call(() => _sb.rpc('end_trip'));

  static Future<void> updateBus(double lat, double lng, double speed) => _call(
    () => _sb.rpc(
      'update_bus',
      params: {'p_lat': lat, 'p_lng': lng, 'p_speed': speed},
    ),
  );
}

// ---------- CHAT ASSISTANT ----------
// Works without a key: it reads your live bus data and answers many kinds
// of questions. If kClaudeKey is set in config.dart, it uses Claude for
// free-form conversation instead (and still computes exact fares itself).
class ChatMsg {
  final bool mine;
  final String text;
  final DateTime time = DateTime.now();
  bool fresh; // bot message that should still type itself out
  bool shown = false; // entrance animation already played
  ChatMsg(this.mine, this.text, {this.fresh = false});
}

class BusAssistant {
  final Profile profile;
  BusAssistant(this.profile);

  final Map<String, List<Stop>> _stopCache = {};
  Map<String, double>? _cfgCache;
  List<Map<String, dynamic>>? _routeCache;

  // ----- data helpers -----
  Future<List<Stop>> _stopsOf(String routeId) async {
    if (routeId.isEmpty) return [];
    final cached = _stopCache[routeId];
    if (cached != null) return cached;
    final s = await Api.stops(routeId);
    _stopCache[routeId] = s;
    return s;
  }

  Future<List<Map<String, dynamic>>> _routes() async {
    final c = _routeCache;
    if (c != null) return c;
    final r = await Api.routes();
    _routeCache = r;
    return r;
  }

  Future<Map<String, double>> _cfg() async {
    final c = _cfgCache;
    if (c != null) return c;
    final rows = await _sb.from('settings').select();
    final m = <String, double>{
      for (final r in rows) '${r['key']}': _d(r['value']),
    };
    _cfgCache = m;
    return m;
  }

  // short names for a stop: "Purisima, Tago" -> purisima, tago, purisima, tago
  List<String> _aliases(String name) {
    final n = name.toLowerCase();
    final out = <String>{n};
    for (final part in n.split(',')) {
      final p = part.trim();
      if (p.length >= 3) out.add(p);
    }
    out.add(n.replaceAll(' city', '').trim());
    return out.where((a) => a.length >= 3).toList();
  }

  // stop names found in the message, in the order they were typed
  Future<List<String>> _places(String q) async {
    final names = <String>{};
    for (final r in await _routes()) {
      for (final s in await _stopsOf('${r['id']}')) {
        names.add(s.name);
      }
    }
    final found = <MapEntry<int, String>>[];
    for (final name in names) {
      int? best;
      for (final a in _aliases(name)) {
        final i = q.indexOf(a);
        if (i >= 0 && (best == null || i < best)) best = i;
      }
      if (best != null) found.add(MapEntry(best, name));
    }
    found.sort((a, b) {
      final c = a.key.compareTo(b.key);
      return c != 0 ? c : a.value.length.compareTo(b.value.length);
    });
    final out = <String>[];
    int? lastKey;
    for (final e in found) {
      if (e.key == lastKey) continue; // same spot matched by two stop names
      lastKey = e.key;
      out.add(e.value);
    }
    return out;
  }

  Bus? _busIn(String q, List<Bus> buses) {
    for (final b in buses) {
      final id = b.id.toLowerCase();
      if (q.contains(id) || q.contains(id.replaceAll('-', ''))) return b;
    }
    return null;
  }

  String? _typeIn(String q) {
    if (q.contains('student') || q.contains('estudyante')) return 'student';
    if (q.contains('senior') || q.contains('elderly')) return 'senior';
    if (q.contains('pwd') || q.contains('disab')) return 'pwd';
    if (q.contains('regular')) return 'regular';
    return null;
  }

  String _clean(String message) =>
      ' ${message.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s\-]'), ' ')} ';

  bool _isFareWords(String q) => [
    'fare',
    'how much',
    'magkano',
    'pila ',
    'pamasahe',
    'plete',
    'price',
    'cost',
  ].any((w) => q.contains(w));

  // ----- main entry -----
  Future<String> reply(
    String message,
    List<Bus> buses,
    List<ChatMsg> history,
  ) async {
    // exact fares always come from the server formula
    final exact = await _tryFare(message);
    if (exact != null) return exact;

    if (kAiOn) {
      try {
        return await _claude(message, buses, history);
      } catch (e) {
        debugPrint('AI error: $e');
        final text = await _offline(message, buses);
        var why = '$e'.replaceAll('\n', ' ');
        if (why.length > 220) why = '${why.substring(0, 220)}...';
        return '$text\n\n(The AI service could not be reached, so I answered from the bus data.\nReason: $why)';
      }
    }
    return _offline(message, buses);
  }

  Future<String?> _tryFare(String message) async {
    final q = _clean(message);
    if (!_isFareWords(q)) return null;
    final places = await _places(q);
    if (places.length < 2) return null;
    return _fare(q);
  }

  // ----- answers from data (no AI key needed) -----
  Future<String> _offline(String message, List<Bus> buses) async {
    final q = _clean(message);
    bool any(List<String> words) => words.any((w) => q.contains(w));

    if (any([' thanks', ' thank you', ' salamat', ' ty '])) {
      return 'You are welcome! Ask me anything else about the buses.';
    }
    if (any([
          ' hi ',
          ' hello ',
          ' hey ',
          ' kumusta',
          ' kamusta',
          ' musta ',
          'magandang',
          'good day',
          'good morning',
          'good afternoon',
          'good evening',
          'maayong',
        ]) &&
        message.trim().length < 30) {
      return _greeting();
    }
    if (any(['who are you', 'what are you'])) {
      return 'I am the BusTrack assistant. I read the live bus data, so I can tell you which buses are running, fares, free seats, and the status of your tickets.';
    }
    if (any(['what can you do', 'what do you do', 'how to use', ' help ']) &&
        message.trim().split(' ').length <= 5) {
      return _help();
    }

    if (any([
      'my ticket',
      'my reservation',
      'my booking',
      'my code',
      'my seat',
      'reservation status',
      'akong ticket',
    ])) {
      return _myTickets();
    }
    if (any(['cancel', 'refund', 'ikansel'])) return _cancelInfo();
    if (any([
      'how do i reserve',
      'how to reserve',
      'how to book',
      'how do i book',
      'reserve a seat',
      'make a reservation',
      'unsaon pag',
      'paano mag',
    ])) {
      return _reserveInfo();
    }
    if (_isFareWords(q)) return _fare(q);
    if (any(['pay', 'payment', 'cash', 'gcash', 'bayad', 'mabayran'])) {
      return _payInfo();
    }
    if (any(['discount', 'diskwento', 'senior', 'student', 'pwd'])) {
      return _discountInfo();
    }
    if (any([' qr', 'scan', ' code'])) return _qrInfo();
    if (any(['seat', 'upuan'])) return _seats(q, buses);
    if (any([
      ' eta',
      'arrive',
      'how long',
      'how far',
      'kanus-a',
      'kanusa',
      'dugay',
    ])) {
      return _eta(q, buses);
    }
    if (any([' stop', 'route', 'ruta', 'terminal', 'pass by'])) {
      return _routeInfo(q, buses);
    }

    final bus = _busIn(q, buses);
    if (bus != null) return _busDetail(bus);

    final places = await _places(q);
    if (places.isNotEmpty ||
        any([
          'bus',
          'running',
          'available',
          'padulong',
          'going',
          'biyahe',
          'trip',
          'ride',
          'karon',
        ])) {
      return _busesTo(places, buses);
    }

    return 'I am not sure I understood that. I can help with:\n'
        '• Buses to a place: "Buses to Davao City"\n'
        '• Fares: "Fare from Tandag City to Davao City"\n'
        '• Seats: "Seats available" or "Seats on DV-01"\n'
        '• A bus: "Where is DV-01?"\n'
        '• Stops: "What stops does DV-01 have?"\n'
        '• Your tickets, payment, discounts and cancelling\n\n'
        'For general questions in any language (Tagalog, Bisaya, travel tips...), the app owner needs to turn on AI mode (deploy the ask-claude function, or set kClaudeKey in config.dart).';
  }

  String _greeting() {
    final name = profile.name.trim().split(' ').first;
    return 'Hi${name.isEmpty ? '' : ' $name'}! I can tell you which buses are running, fares, free seats and your ticket status. What do you need?';
  }

  String _help() =>
      'Here is what I can do:\n'
      '• Show running buses and where they are going\n'
      '• Work out your fare, with your discount\n'
      '• Show free seats on a bus\n'
      '• Estimate how far a bus is from its next stop\n'
      '• List the stops on a route\n'
      '• Show your tickets and explain payment, discounts and cancelling\n\n'
      'Try: "Fare from Tandag City to Davao City"';

  Future<String> _myTickets() async {
    final list = await Api.myTickets();
    if (list.isEmpty) {
      return 'You have no reservations yet. Tap Reserve on a running bus to book a seat.';
    }
    final lines = list
        .take(5)
        .map((t) {
          return '• Bus ${t.busId}, ${seatLabel(t.seat).toLowerCase()}: ${t.pickupName} to ${t.dropoffName}\n'
              '  ${statusText(t.status)} • ${peso(t.total)} • code ${t.code}';
        })
        .join('\n');
    return 'Your latest reservations:\n$lines\n\nOpen My tickets (the ticket icon) to show your QR code.';
  }

  String _cancelInfo() =>
      'You can cancel for free until you board. Open My tickets, tap your reservation, then tap Cancel reservation. You have not paid anything yet, so there is nothing to refund.\n\n'
      'If you are not on the bus before it passes your pick-up point, the reservation is cancelled automatically.';

  String _reserveInfo() =>
      'To reserve a seat:\n'
      '1. Tap Reserve on a running bus.\n'
      '2. Choose your pick-up and drop-off points.\n'
      '3. Check your fare, then pick a seat.\n'
      '4. Tap Confirm reservation.\n'
      '5. Show your QR code to the conductor and pay when you board.';

  Future<String> _payInfo() async {
    final cfg = await _cfg();
    final fee = peso(cfg['reservation_fee'] ?? 0);
    return 'Nothing is paid in the app. You pay the conductor in cash when you board: the fare plus the $fee reservation fee.\n\n'
        'A reservation stays unpaid until the conductor scans your QR code and you pay. If you do not board before the bus passes your pick-up point, it cancels automatically.';
  }

  Future<String> _discountInfo() async {
    final cfg = await _cfg();
    final pct = (cfg['discount_pct'] ?? 20).toStringAsFixed(0);
    final mine = profile.type == 'regular'
        ? 'Your account is Regular, so no discount applies.'
        : 'Your account is ${typeLabel(profile.type)}, so your fare is $pct% off.';
    return 'Students, seniors and PWD get $pct% off the fare. The reservation fee is not discounted. Bring a valid ID, because the conductor checks it when you board.\n$mine';
  }

  String _qrInfo() =>
      'After you reserve, your ticket shows a QR code and a 6-letter code. Show either one to the conductor. They scan it (or type the code), you pay in cash, and your seat is confirmed as boarded and paid.';

  Future<String> _fare(String q) async {
    final places = await _places(q);
    final type = _typeIn(q) ?? profile.type;

    if (places.length >= 2) {
      for (final r in await _routes()) {
        final stops = await _stopsOf('${r['id']}');
        final a = stops.where((s) => s.name == places[0]).toList();
        final b = stops.where((s) => s.name == places[1]).toList();
        if (a.isNotEmpty && b.isNotEmpty && a.first.seq < b.first.seq) {
          final qt = await Api.quote(
            '${r['id']}',
            a.first.seq,
            b.first.seq,
            type,
          );
          final lines = <String>[
            'Fare from ${places[0]} to ${places[1]} (${r['name']}):',
            'Distance: ${qt.distance.toStringAsFixed(1)} km',
            'Fare: ${peso(qt.fare)}',
            if (qt.discount > 0)
              '${typeLabel(type)} discount: -${peso(qt.discount)}',
            'Walk-in: pay ${peso(qt.fare - qt.discount)} to the conductor.',
            'With a reservation: ${peso(qt.total)} (includes the ${peso(qt.fee)} reservation fee).',
            if (qt.discount > 0) 'Bring a valid ID for the discount.',
          ];
          return lines.join('\n');
        }
      }
      return 'I could not find a route that goes from ${places[0]} to ${places[1]}. Try the other direction, or ask "What stops does DV-01 have?"';
    }

    final cfg = await _cfg();
    final formula =
        'The fare starts at ${peso(cfg['base_fare'] ?? 0)} for the first ${(cfg['base_km'] ?? 0).toStringAsFixed(0)} km, then ${peso(cfg['per_km'] ?? 0)} for every extra km. '
        'Students, seniors and PWD get ${(cfg['discount_pct'] ?? 0).toStringAsFixed(0)}% off.';
    if (places.length == 1) {
      return 'Where do you get on, and where do you get off? Example: "Fare from ${places.first} to Davao City".\n\n$formula';
    }
    return 'Tell me where you get on and off, for example: "Fare from Tandag City to Davao City".\n\n$formula';
  }

  Future<String> _busLine(Bus b) async {
    final stops = await _stopsOf(b.routeId);
    final next = stops.where((s) => s.seq == b.currentSeq + 1).toList();
    final taken = await Api.takenSeats(b.id);
    final free = kSeats - seatedCount(taken);
    final nextTxt = next.isEmpty
        ? 'near the end of its route'
        : 'next stop: ${next.first.name}';
    return '${b.id} • ${b.route.isEmpty ? 'no route' : b.route} • ${b.speed.toStringAsFixed(0)} km/h • $nextTxt • $free seats free';
  }

  Future<String> _etaLine(Bus b) async {
    if (!b.running) return '• ${b.id} is not running right now.';
    final stops = await _stopsOf(b.routeId);
    final next = stops.where((s) => s.seq == b.currentSeq + 1).toList();
    if (next.isEmpty) return '• ${b.id} is near the end of its route.';
    final km = const Distance().as(LengthUnit.Kilometer, b.pos, next.first.pos);
    if (b.speed < 5) {
      return '• ${b.id}: ${km.toStringAsFixed(1)} km from ${next.first.name}, but it is not moving right now.';
    }
    final mins = (km * 1.25 / b.speed * 60).round();
    return '• ${b.id}: about ${km.toStringAsFixed(1)} km to ${next.first.name}, roughly $mins min at ${b.speed.toStringAsFixed(0)} km/h.';
  }

  Future<String> _eta(String q, List<Bus> buses) async {
    final one = _busIn(q, buses);
    final running = buses.where((x) => x.running).toList();
    if (one == null && running.isEmpty)
      return 'No buses are running right now.';
    final list = one != null ? [one] : running;
    final out = <String>[];
    for (final x in list) {
      out.add(await _etaLine(x));
    }
    return '${out.join('\n')}\n\nThese are rough estimates from the bus GPS and speed, not an official schedule.';
  }

  Future<String> _seats(String q, List<Bus> buses) async {
    final one = _busIn(q, buses);
    final list = one != null ? [one] : buses.where((b) => b.running).toList();
    if (list.isEmpty) {
      return 'No buses are running right now, so there are no seats to book yet.';
    }
    final lines = <String>[];
    for (final b in list) {
      final taken = await Api.takenSeats(b.id);
      final free = kSeats - seatedCount(taken);
      final route = b.route.isEmpty ? 'no route' : b.route;
      final stand = kStandingMax - standingCount(taken);
      lines.add(
        '• ${b.id} ($route): ${free > 0 ? '$free of $kSeats seats free' : 'FULL, $stand standing places left'}${b.running ? '' : ' (not running)'}',
      );
    }
    return 'Seat availability:\n${lines.join('\n')}\n\nTap Reserve on a bus card to choose your seat.';
  }

  Future<String> _routeInfo(String q, List<Bus> buses) async {
    final b = _busIn(q, buses);
    if (b != null) {
      final stops = await _stopsOf(b.routeId);
      if (stops.isEmpty) {
        return '${b.id} has no route yet. The driver must start a trip.';
      }
      final list = stops.map((s) => '${s.seq}. ${s.name}').join('\n');
      return '${b.id} (${b.route}) stops at:\n$list';
    }
    final out = <String>[];
    for (final r in await _routes()) {
      final stops = await _stopsOf('${r['id']}');
      final names = stops.map((s) => s.name).join(' > ');
      out.add('• ${r['name']}: $names');
    }
    return out.isEmpty
        ? 'No routes are set up yet.'
        : 'Routes:\n${out.join('\n')}';
  }

  Future<String> _busDetail(Bus b) async {
    if (!b.running) {
      final route = b.route.isEmpty ? 'no route yet' : b.route;
      return '${b.id} is not running right now ($route). Check back after the driver starts the trip.';
    }
    final stops = await _stopsOf(b.routeId);
    final last = stops.where((s) => s.seq == b.currentSeq).toList();
    final taken = await Api.takenSeats(b.id);
    final lines = <String>[
      '${b.id} is running on ${b.route}.',
      'Speed: ${b.speed.toStringAsFixed(0)} km/h',
      if (last.isNotEmpty) 'Last stop reached: ${last.first.name}',
      (await _etaLine(b)).replaceFirst('• ', ''),
      'Seats free: ${kSeats - seatedCount(taken)} of $kSeats',
    ];
    return lines.join('\n');
  }

  Future<String> _busesTo(List<String> places, List<Bus> buses) async {
    final running = buses.where((b) => b.running).toList();
    if (running.isEmpty) {
      return 'No buses are running right now. Please check again in a few minutes.';
    }

    if (places.isEmpty) {
      final lines = <String>[];
      for (final b in running) {
        final line = await _busLine(b);
        lines.add('• $line');
      }
      return '${running.length} bus(es) running right now:\n${lines.join('\n')}';
    }

    final String? from = places.length >= 2 ? places.first : null;
    final to = places.last;
    final ok = <String>[];
    final passed = <String>[];

    for (final b in running) {
      final stops = await _stopsOf(b.routeId);
      final toStops = stops.where((s) => s.name == to).toList();
      if (toStops.isEmpty) continue;
      final toSeq = toStops.first.seq;

      if (from != null) {
        final fromStops = stops.where((s) => s.name == from).toList();
        if (fromStops.isEmpty || fromStops.first.seq >= toSeq) continue;
        if (fromStops.first.seq <= b.currentSeq) {
          passed.add('${b.id} (already passed $from)');
          continue;
        }
      } else if (toSeq <= b.currentSeq) {
        passed.add('${b.id} (already passed $to)');
        continue;
      }
      final line = await _busLine(b);
      ok.add('• $line');
    }

    final title = from == null
        ? 'Running buses that still stop at $to'
        : 'Running buses from $from to $to';
    final tail = passed.isEmpty
        ? ''
        : '\n\nNot available: ${passed.join(', ')}';

    if (ok.isEmpty) {
      return 'No running bus can take you ${from == null ? 'to $to' : 'from $from to $to'} right now.$tail';
    }
    return '$title:\n${ok.join('\n')}$tail\n\nTap Reserve on a bus card to book a seat.';
  }

  // ----- Claude (only when kClaudeKey is set) -----
  Future<String> _claude(
    String message,
    List<Bus> buses,
    List<ChatMsg> history,
  ) async {
    final cfg = await _cfg();

    final busData = <Map<String, dynamic>>[];
    for (final b in buses) {
      final stops = await _stopsOf(b.routeId);
      final next = stops.where((s) => s.seq == b.currentSeq + 1).toList();
      final taken = b.running ? await Api.takenSeats(b.id) : <int>{};
      busData.add({
        ...b.toMap(),
        'stops_in_order': stops.map((s) => s.name).toList(),
        'next_stop': next.isEmpty ? null : next.first.name,
        'free_seats': b.running ? kSeats - seatedCount(taken) : null,
      });
    }

    var mine = <Map<String, dynamic>>[];
    try {
      final t = await Api.myTickets();
      mine = t
          .take(5)
          .map(
            (x) => <String, dynamic>{
              'bus': x.busId,
              'seat': x.seat,
              'from': x.pickupName,
              'to': x.dropoffName,
              'status': x.status,
              'total_php': x.total,
              'code': x.code,
            },
          )
          .toList();
    } catch (_) {}

    final data = jsonEncode({
      'passenger': {'name': profile.name, 'type': profile.type},
      'fare_settings': cfg,
      'buses': busData,
      'my_tickets': mine,
    });

    final system =
        'You are the BusTrack assistant inside a bus tracking and seat reservation app in the Philippines (Caraga / Mindanao area). '
        'You are a knowledgeable, friendly general assistant. Answer any question the passenger asks, including travel tips, local places, '
        'what to bring on a long bus ride, safety, and general knowledge, using your own knowledge. '
        'For anything about THIS app (buses, routes, stops, seats, fares, tickets), rely on the LIVE DATA below and never invent buses, times, fares or seats. '
        'If the live data does not cover an app-specific question, say you do not have that information. '
        'If you are unsure about a real-world fact, say so instead of guessing. '
        'Rules of the app: nothing is paid in the app. The passenger pays the conductor in cash when boarding (fare plus reservation fee). '
        'When a bus has no free seats, the passenger can still reserve a standing place (limit $kStandingMax per bus). '
        'Pick-up and drop-off can be typed: the app finds the place on the map and picks the nearest stop of the route. '
        'A reservation is unpaid until the conductor scans the QR code. Cancelling is free until boarding. '
        'If the passenger does not board before the bus passes the pick-up point, the reservation is cancelled automatically. '
        'Students, seniors and PWD get the discount in fare_settings.discount_pct and must show an ID. '
        'Fare = base_fare for the first base_km, then per_km for each extra km, rounded; the reservation fee is added and is not discounted. '
        'For an exact fare between two stops, tell the passenger to ask like "fare from A to B" or use the Reserve screen. '
        'Reply in the same language as the passenger (English, Tagalog or Bisaya), in short plain text without markdown.\n\n'
        'LIVE DATA:\n$data';

    final msgs = <Map<String, String>>[];
    final recent = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    for (final m in recent) {
      msgs.add({'role': m.mine ? 'user' : 'assistant', 'content': m.text});
    }
    while (msgs.isNotEmpty && msgs.first['role'] != 'user') {
      msgs.removeAt(0);
    }
    msgs.add({'role': 'user', 'content': message});

    Map<String, dynamic> j;
    if (kUseAiFunction) {
      // key lives in Supabase secrets; the app only sends the conversation
      final r = await _sb.functions
          .invoke('ask-claude', body: {'system': system, 'messages': msgs})
          .timeout(const Duration(seconds: 40));
      final d = r.data;
      j = d is Map
          ? Map<String, dynamic>.from(d)
          : jsonDecode('$d') as Map<String, dynamic>;
      if (j['content'] == null) {
        throw Exception('AI error: ${j['error'] ?? 'no answer'}');
      }
    } else {
      // direct call with the key inside the app (testing only)
      final res = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': kClaudeKey,
              'anthropic-version': '2023-06-01',
              // needed when calling from a browser (Chrome) for testing
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': kModel,
              'max_tokens': 800,
              'system': system,
              'messages': msgs,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        throw Exception('AI error ${res.statusCode}');
      }
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    final parts = (j['content'] as List)
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'].toString());
    return parts.join('\n');
  }
}

// ---------- APP START ----------
// ---------- APP START ----------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // An unexpected error should never silently kill the app.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    return true;
  };
  runApp(const BootApp());
}

/// Shows a dark loading screen right away, starts Supabase with a time limit,
/// and shows a readable error + Retry button instead of a blank white screen.
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  static Future<Supabase>? _initFuture;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _retry() {
    setState(() {
      _ready = false;
      _error = null;
    });
    _start();
  }

  Future<void> _start() async {
    try {
      if (kSupabaseUrl.isNotEmpty) {
        _initFuture ??= Supabase.initialize(
          url: kSupabaseUrl,
          anonKey: kSupabaseAnonKey,
        );
        await _initFuture!.timeout(const Duration(seconds: 15));
      }
      if (!mounted) return;
      setState(() => _ready = true);
    } on TimeoutException {
      if (!mounted) return;
      setState(
        () => _error =
            'Starting took too long. Check your internet connection and the '
            "phone's date and time, then tap Retry.",
      );
    } catch (e) {
      _initFuture = null;
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const BusApp();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: kBg0,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: _error == null ? _loading() : _failed(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading() => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.directions_bus_rounded, size: 64, color: kGold),
      SizedBox(height: 16),
      Text(
        'BusTrack',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: 20),
      SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 3, color: kGold),
      ),
    ],
  );

  Widget _failed() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline_rounded, size: 56, color: kGold),
      const SizedBox(height: 14),
      const Text(
        "Can't start BusTrack",
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _error!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 22),
      ElevatedButton(onPressed: _retry, child: const Text('Retry')),
    ],
  );
}

class BusApp extends StatelessWidget {
  const BusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BusTrack',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: kSupabaseUrl.isEmpty ? const SetupPage() : const AuthGate(),
    );
  }
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Setup needed\n\n'
            'Open lib/config.dart and fill in kSupabaseUrl and '
            'kSupabaseAnonKey (Supabase > Project Settings > API), '
            'then restart the app.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// INTRO (shown before login)
// =====================================================
class _RoutePainter extends CustomPainter {
  final double t;
  _RoutePainter(this.t);

  Path _path(Size s) {
    final p = Path();
    p.moveTo(s.width * 0.10, s.height * 0.76);
    p.cubicTo(
      s.width * 0.30,
      s.height * 0.95,
      s.width * 0.38,
      s.height * 0.35,
      s.width * 0.58,
      s.height * 0.50,
    );
    p.cubicTo(
      s.width * 0.78,
      s.height * 0.64,
      s.width * 0.78,
      s.height * 0.14,
      s.width * 0.90,
      s.height * 0.24,
    );
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final metric = _path(size).computeMetrics().first;

    // dotted route
    final dot = Paint()..color = Colors.white30;
    for (double d = 0; d < metric.length; d += 14) {
      final tan = metric.getTangentForOffset(d);
      if (tan != null) canvas.drawCircle(tan.position, 2.2, dot);
    }

    // stops
    for (final f in [0.0, 0.5, 1.0]) {
      final tan = metric.getTangentForOffset(metric.length * f);
      if (tan == null) continue;
      canvas.drawCircle(tan.position, 10, Paint()..color = kGold.withAlpha(45));
      canvas.drawCircle(tan.position, 5, Paint()..color = kGold);
    }

    // moving bus
    final tan = metric.getTangentForOffset(metric.length * t);
    if (tan == null) return;
    canvas.drawCircle(tan.position, 26, Paint()..color = kGold.withAlpha(55));
    canvas.drawCircle(tan.position, 17, Paint()..color = kGold);

    final icon = Icons.directions_bus_filled;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 20,
          color: kInk,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, tan.position - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.t != t;
}

class _Scene {
  final String eyebrow;
  final String title;
  final String text;
  const _Scene(this.eyebrow, this.title, this.text);
}

class _CrewItem {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  const _CrewItem(this.icon, this.title, this.text, this.color);
}

/// Faint street map used behind the "pick your stops" scene.
class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final road = Paint()
      ..color = Colors.white12
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(-10, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.40,
        size.height * 0.58,
        size.width * 0.55,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.26,
        size.width + 10,
        size.height * 0.20,
      );
    canvas.drawPath(path, road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Dotted line that draws itself from [a] to [b] as [p] goes 0 -> 1.
class _DashPainter extends CustomPainter {
  final double p;
  final Offset a;
  final Offset b;
  _DashPainter(this.p, this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(a.dx, b.dy, b.dx, b.dy);
    final metric = path.computeMetrics().first;
    final upTo = metric.length * p;
    final dot = Paint()..color = kGold;
    for (double d = 0; d < upTo; d += 12) {
      final tan = metric.getTangentForOffset(d);
      if (tan != null) canvas.drawCircle(tan.position, 2.6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.p != p;
}

/// The intro is an auto-playing, story-style animation that walks through
/// every feature of the app.
///   - tap the right side  -> next scene      - tap the left side -> back
///   - press and hold      -> pause           - swipe             -> back / next
///   - top bar             -> tap a segment to jump to that scene
class WelcomePage extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomePage({super.key, required this.onDone});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  static const int _sceneMs = 4200;

  static const List<_Scene> _scenes = [
    _Scene(
      'LIVE TRACKING',
      'See your bus, live',
      'Follow every bus on the map in real time. Know where your ride is and when it arrives.',
    ),
    _Scene(
      'PLAN YOUR TRIP',
      'Pick your stops',
      'Choose where you get on and off from the route, or drop a pin right on the map.',
    ),
    _Scene(
      'SEAT RESERVATION',
      'Reserve your seat',
      'Pick your seat or a standing spot and see how full the bus is before you book.',
    ),
    _Scene(
      'FAIR FARES',
      'Discounts built in',
      'Students, seniors and PWD get their discount after a quick ID and age check. It shows in the fare before you book.',
    ),
    _Scene(
      'EASY PAYMENT',
      'Pay your way',
      'Pay online with GCash, Maya or card, or pay when you board.',
    ),
    _Scene(
      'QR BOARDING',
      'Scan and ride',
      'Show your QR code to the conductor and ride. Cancel for free until you get on the bus.',
    ),
    _Scene(
      'AI ASSISTANT',
      'Ask anything',
      'Get quick answers about buses, fares, seats, discounts and your tickets, in English or Filipino.',
    ),
    _Scene(
      'FOR THE CREW',
      'Drivers, conductors, admins',
      'Drivers share their trip live. Conductors scan tickets and work out fares. Admins approve new staff.',
    ),
    _Scene(
      'ALL IN ONE',
      'Everything for your ride',
      'One app for commuters, drivers and conductors. Ready when you are.',
    ),
  ];

  static const List<_CrewItem> _crew = [
    _CrewItem(
      Icons.directions_bus_filled_rounded,
      'Driver',
      'Start trips and share live location',
      kGold,
    ),
    _CrewItem(
      Icons.qr_code_scanner_rounded,
      'Conductor',
      'Scan tickets, check fares, see riders',
      kGood,
    ),
    _CrewItem(
      Icons.admin_panel_settings_rounded,
      'Admin',
      'Approve new drivers and conductors',
      kWarn,
    ),
  ];

  int get _n => _scenes.length;

  /// master timeline: 0 -> 1 across all scenes
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _sceneMs * _scenes.length),
  );

  /// gentle looping motion (floating art, pulsing rings)
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  int _scene = 0;
  bool _userPaused = false;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_onTick);
    _ctl.addStatusListener((s) {
      if (mounted) setState(() {});
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _anim.dispose();
    super.dispose();
  }

  // ---------- playback ----------
  int _sceneAt(double v) => min(max((v * _n).floor(), 0), _n - 1);

  void _onTick() {
    final i = _sceneAt(_ctl.value);
    if (i != _scene && mounted) setState(() => _scene = i);
  }

  void _resume() {
    if (_userPaused || _holding) return;
    if (_ctl.value < 1.0 && !_ctl.isAnimating) _ctl.forward();
  }

  void _seek(int i) {
    final idx = min(max(i, 0), _n - 1);
    _ctl.value = (idx + 0.001) / _n;
    _resume();
  }

  void _prev() => _seek(_scene - 1);

  void _tapNext() {
    if (_scene < _n - 1) _seek(_scene + 1);
  }

  void _next() {
    if (_scene >= _n - 1) {
      widget.onDone();
    } else {
      _seek(_scene + 1);
    }
  }

  void _setHold(bool h) {
    _holding = h;
    if (h) {
      _ctl.stop();
    } else {
      _resume();
    }
  }

  void _replay() {
    setState(() => _userPaused = false);
    _ctl.value = 0.001;
    _resume();
  }

  void _togglePlay() {
    if (_ctl.isCompleted) {
      _replay();
      return;
    }
    setState(() => _userPaused = !_userPaused);
    if (_userPaused) {
      _ctl.stop();
    } else {
      _resume();
    }
  }

  // ---------- small helpers ----------
  /// 0 -> 1 progress of [t] between [a] and [b], shaped by [c].
  double _seg(double t, double a, double b, [Curve c = Curves.easeOutCubic]) =>
      c.transform(((t - a) / (b - a)).clamp(0.0, 1.0).toDouble());

  /// fade + scale in
  Widget _pop(double v, Widget child) => Opacity(
    opacity: v.clamp(0.0, 1.0).toDouble(),
    child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
  );

  Widget _bob(Widget child) => AnimatedBuilder(
    animation: _anim,
    builder: (context, c) => Transform.translate(
      offset: Offset(0, 6 * sin(_anim.value * 2 * pi * 3)),
      child: c,
    ),
    child: child,
  );

  Widget _frame(Widget child) => Container(
    width: 300,
    height: 264,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [kSurface2, kSurface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.white12),
      boxShadow: [
        const BoxShadow(
          color: Colors.black54,
          blurRadius: 30,
          offset: Offset(0, 16),
        ),
        BoxShadow(color: kGold.withAlpha(22), blurRadius: 60),
      ],
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(32), child: child),
  );

  Widget _livePill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: kGood.withAlpha(35),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kGood.withAlpha(120)),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseDot(color: kGood),
        SizedBox(width: 2),
        Text(
          'LIVE',
          style: TextStyle(
            color: kGood,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );

  // ---------- scene 0: live tracking ----------
  Widget _artTrack(double t) => _frame(
    Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _RoutePainter(_seg(t, 0.04, 0.97, Curves.easeInOut)),
          ),
        ),
        Positioned(left: 16, top: 16, child: _livePill()),
        Positioned(
          right: 16,
          top: 16,
          child: _pop(
            _seg(t, 0.45, 0.6, Curves.easeOutBack),
            const Pill(text: 'Arriving soon', color: kGold),
          ),
        ),
      ],
    ),
  );

  // ---------- scene 1: pick your stops ----------
  List<Widget> _pin(Offset p, Color c, String label, double v) => [
    Positioned(
      left: p.dx - 11,
      top: p.dy - 3,
      child: Opacity(
        opacity: v.clamp(0.0, 1.0).toDouble(),
        child: Container(
          width: 22,
          height: 7,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    Positioned(
      left: p.dx - 40,
      top: p.dy - 63 - 90 * (1 - v),
      width: 80,
      child: Opacity(
        opacity: min(1.0, v * 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pill(text: label, color: c),
            Icon(Icons.location_on_rounded, size: 40, color: c),
          ],
        ),
      ),
    ),
  ];

  Widget _artStops(double t) {
    const a = Offset(80, 190);
    const b = Offset(224, 100);
    return _frame(
      Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          Positioned.fill(
            child: CustomPaint(
              painter: _DashPainter(_seg(t, 0.62, 0.92, Curves.easeInOut), a, b),
            ),
          ),
          ..._pin(a, kGood, 'Get on', _seg(t, 0.08, 0.34, Curves.bounceOut)),
          ..._pin(b, kGold, 'Get off', _seg(t, 0.38, 0.64, Curves.bounceOut)),
        ],
      ),
    );
  }

  // ---------- scene 2: seat reservation ----------
  Widget _artSeats(double t) {
    Widget seat(int r, int s) {
      final idx = r * 4 + s;
      final chosen = r == 1 && s == 2;
      final taken = (r + s) % 3 == 0 && !chosen;
      final takenV = taken
          ? _seg(t, 0.04 + idx * 0.03, 0.10 + idx * 0.03)
          : 0.0;
      final chosenV = chosen ? _seg(t, 0.55, 0.72, Curves.elasticOut) : 0.0;
      final on = chosen && t >= 0.55;
      final base = kGoldDark.withAlpha(150);
      final box = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: on ? kGoldGradient : null,
          color: on
              ? null
              : (taken
                    ? Colors.white.withAlpha((26 * takenV).round())
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: on
                ? kGold
                : (taken ? Color.lerp(base, Colors.white12, takenV)! : base),
          ),
          boxShadow: on
              ? [BoxShadow(color: kGold.withAlpha(110), blurRadius: 14)]
              : null,
        ),
        child: on ? const Icon(Icons.check, size: 18, color: kInk) : null,
      );
      return Padding(
        padding: const EdgeInsets.all(4),
        child: on ? Transform.scale(scale: 0.7 + 0.3 * chosenV, child: box) : box,
      );
    }

    return _frame(
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_bus_filled, size: 16, color: kMuted),
                SizedBox(width: 6),
                Text(
                  'FRONT',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (int r = 0; r < 4; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  seat(r, 0),
                  seat(r, 1),
                  const SizedBox(width: 18),
                  seat(r, 2),
                  seat(r, 3),
                ],
              ),
            const SizedBox(height: 12),
            _pop(
              _seg(t, 0.8, 0.92, Curves.easeOutBack),
              const Pill(text: 'Seat reserved', color: kGood),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- scene 3: fares and discounts ----------
  Widget _bar(double f, {required bool gold}) => Container(
    height: 14,
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(8),
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: f.clamp(0.0, 1.0).toDouble(),
      child: Container(
        decoration: BoxDecoration(
          gradient: gold ? kGoldGradient : null,
          color: gold ? null : Colors.white38,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  Widget _artFare(double t) {
    const chips = [
      (Icons.school_rounded, 'Student'),
      (Icons.elderly_rounded, 'Senior'),
      (Icons.accessible_rounded, 'PWD'),
    ];
    final active = t < 0.14
        ? -1
        : t < 0.42
        ? 0
        : t < 0.68
        ? 1
        : 2;
    final disc = _seg(t, 0.14, 0.3);
    return _frame(
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (int i = 0; i < chips.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: active == i ? kGoldGradient : null,
                          color: active == i ? null : Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: active == i ? kGold : Colors.white12,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              chips[i].$1,
                              size: 22,
                              color: active == i ? kInk : kMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chips[i].$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active == i ? kInk : kMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Regular fare',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            _bar(_seg(t, 0.0, 0.12), gold: false),
            const SizedBox(height: 14),
            const Text(
              'Your fare',
              style: TextStyle(color: kGoldLight, fontSize: 12),
            ),
            const SizedBox(height: 6),
            _bar(_seg(t, 0.04, 0.14) * (1 - 0.22 * disc), gold: true),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: _pop(disc, const Pill(text: 'Discount applied', color: kGood)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- scene 4: payment ----------
  Widget _artPay(double t) {
    final sel = t < 0.12
        ? -1
        : t < 0.32
        ? 0
        : t < 0.52
        ? 1
        : 2;
    final fill = _seg(t, 0.58, 0.82, Curves.easeInOut);
    final paid = t >= 0.84;
    final onGold = fill > 0.5 && !paid;
    return _frame(
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < kPayMethods.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      scale: sel == i ? 1.15 : 1.0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PayLogo(
                            method: kPayMethods[i],
                            size: 56,
                            selected: sel == i,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kPayMethods[i].name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel == i ? kGoldLight : kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: 240,
              height: 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: paid ? kGood : Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  if (!paid)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fill,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(gradient: kGoldGradient),
                        ),
                      ),
                    ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          paid ? Icons.check_circle_rounded : Icons.lock_rounded,
                          size: 18,
                          color: paid
                              ? Colors.white
                              : (onGold ? kInk : Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          paid ? 'Paid' : 'Pay online',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: paid
                                ? Colors.white
                                : (onGold ? kInk : Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'or pay when you board',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- scene 5: QR boarding ----------
  Widget _artQr(double t) {
    final p = 0.5 + 0.5 * sin(t * 2 * pi * 3);
    final scan = 0.5 + 0.5 * sin(t * 2 * pi * 2.5 - pi / 2);
    final ok = _seg(t, 0.72, 0.86, Curves.easeOutBack);
    return _frame(
      Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190 + 20 * p,
              height: 190 + 20 * p,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kGold.withAlpha((90 * (1 - p)).round() + 20),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: kGold.withAlpha(90), blurRadius: 30),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(Icons.qr_code_2, size: 110, color: kBg0),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 10 + 120 * scan,
                      child: Opacity(
                        opacity: (1 - ok).clamp(0.0, 1.0).toDouble(),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                kGold.withAlpha(0),
                                kGold,
                                kGold.withAlpha(0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kGold.withAlpha(150),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 22,
              bottom: 22,
              child: _pop(
                ok,
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: kGood,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- scene 6: AI assistant ----------
  Widget _revealText(String full, int n, TextStyle style) {
    final k = min(max(n, 0), full.length);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: full.substring(0, k)),
          TextSpan(
            text: full.substring(k),
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _artAssistant(double t) {
    const q = 'When is the next bus?';
    const a = 'Your bus arrives in about 8 minutes, and 12 seats are free.';
    final typing = t > 0.32 && t < 0.5;
    final answering = t >= 0.5;
    final chars = (a.length * _seg(t, 0.52, 0.86, Curves.linear)).round();
    final bubble = BoxDecoration(
      color: kSurface2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    );
    return _frame(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BrandMark(size: 28),
                const SizedBox(width: 8),
                const Text(
                  'Assistant',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kGold.withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kGold.withAlpha(120)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulseDot(color: kGold),
                      SizedBox(width: 2),
                      Text(
                        'AI mode',
                        style: TextStyle(
                          color: kGold,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _pop(
                _seg(t, 0.06, 0.2, Curves.easeOutBack),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    gradient: kGoldGradient,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: const Text(
                    q,
                    style: TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (typing)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: bubble,
                  child: const _TypingDots(),
                ),
              ),
            if (answering)
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: bubble,
                    child: _revealText(
                      a,
                      chars,
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            _pop(
              _seg(t, 0.88, 0.97, Curves.easeOutBack),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Pill(text: 'Fares', color: kGold),
                  Pill(text: 'Seats', color: kGood),
                  Pill(text: 'Discounts', color: kWarn),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- scene 7: drivers, conductors, admins ----------
  Widget _artCrew(double t) => _frame(
    Padding(
      padding: const EdgeInsets.all(12),
      // FittedBox shrinks the list if it is ever taller than the frame
      // (long text / large phone font size), so it can't overflow.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 276,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          for (int i = 0; i < _crew.length; i++)
            Builder(
              builder: (context) {
                final v = _seg(t, 0.08 + i * 0.22, 0.28 + i * 0.22);
                final c = _crew[i];
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(60 * (1 - v), 0),
                    child: Container(
                      margin: EdgeInsets.only(bottom: i == _crew.length - 1 ? 0 : 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.color.withAlpha(90)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.color.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(c.icon, color: c.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            ],
          ),
        ),
      ),
    ),
  );

  // ---------- scene 8: recap ----------
  Widget _artFinale(double t) {
    const names = [
      'Live map',
      'Seats',
      'Discounts',
      'GCash · Maya',
      'QR pass',
      'Assistant',
      'Driver tools',
    ];
    const colors = [kGold, kGood, kWarn];
    return _frame(
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120,
                height: 100,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) {
                    final p = (_anim.value * 3) % 1.0;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 70 + 50 * p,
                          height: 70 + 50 * p,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kGold.withAlpha((110 * (1 - p)).round()),
                              width: 2,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _seg(t, 0.0, 0.25, Curves.easeOutBack),
                          child: const BrandMark(size: 64),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: _seg(t, 0.12, 0.3),
                child: const Text(
                  'BusTrack',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (int i = 0; i < names.length; i++)
                    _pop(
                      _seg(t, 0.25 + i * 0.08, 0.4 + i * 0.08, Curves.easeOutBack),
                      Pill(text: names[i], color: colors[i % colors.length]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _art(int i, double t) => switch (i) {
    0 => _artTrack(t),
    1 => _artStops(t),
    2 => _artSeats(t),
    3 => _artFare(t),
    4 => _artPay(t),
    5 => _artQr(t),
    6 => _artAssistant(t),
    7 => _artCrew(t),
    _ => _artFinale(t),
  };

  // ---------- layout ----------
  Widget _sceneContent(int i) {
    final s = _scenes[i];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bob(
          AnimatedBuilder(
            animation: _ctl,
            builder: (context, _) {
              // outgoing scenes hold their last frame, incoming ones start at 0
              final t = (_ctl.value * _n - i).clamp(0.0, 1.0).toDouble();
              return _art(i, t);
            },
          ),
        ),
        const SizedBox(height: 28),
        Text(
          s.eyebrow,
          style: const TextStyle(
            color: kGold,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          s.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          s.text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, fontSize: 15, height: 1.45),
        ),
      ],
    );
  }

  Widget _stage() {
    return LayoutBuilder(
      builder: (context, box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              d.localPosition.dx < box.maxWidth * 0.3 ? _prev() : _tapNext(),
          onLongPressStart: (_) => _setHold(true),
          onLongPressEnd: (_) => _setHold(false),
          onLongPressCancel: () => _setHold(false),
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -250) {
              _tapNext();
            } else if (v > 250) {
              _prev();
            }
          },
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1).animate(a),
                    child: c,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_scene),
                  child: _sceneContent(_scene),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _progressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final pos = _ctl.value * _n;
        return Row(
          children: List.generate(_n, (i) {
            final f = (pos - i).clamp(0.0, 1.0).toDouble();
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _seek(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(height: 4, color: Colors.white24),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: f,
                          child: Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: kGoldGradient,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final last = _scene == _n - 1;
    final done = _ctl.isCompleted;
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Column(
            children: [
              FadeSlide(index: 0, child: _progressBar()),
              FadeSlide(
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 8, 0),
                  child: Row(
                    children: [
                      const BrandMark(size: 34),
                      const SizedBox(width: 10),
                      const Text(
                        'BusTrack',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: done
                            ? 'Watch again'
                            : (_userPaused ? 'Play' : 'Pause'),
                        onPressed: _togglePlay,
                        icon: Icon(
                          done
                              ? Icons.replay_rounded
                              : (_userPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded),
                          color: kGoldLight,
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 250),
                        opacity: last ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: last,
                          child: TextButton(
                            onPressed: widget.onDone,
                            child: const Text('Skip'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: FadeSlide(index: 2, child: _stage())),
              FadeSlide(
                index: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.96, end: 1).animate(a),
                        child: c,
                      ),
                    ),
                    child: SizedBox(
                      key: ValueKey(last),
                      width: double.infinity,
                      child: GoldButton(
                        label: last ? 'Get started' : 'Next',
                        icon: last
                            ? Icons.rocket_launch_rounded
                            : Icons.arrow_forward_rounded,
                        onPressed: _next,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// INTRO VIDEO (plays first, then the WelcomePage slides)
// =====================================================
/// Plays the app showcase video full-screen. When it ends, or when the user
/// taps "Skip", [onDone] is called and the normal slide intro takes over.
/// Tap the video to pause / resume.
class IntroVideoPage extends StatefulWidget {
  final VoidCallback onDone;
  const IntroVideoPage({super.key, required this.onDone});

  @override
  State<IntroVideoPage> createState() => _IntroVideoPageState();
}

class _IntroVideoPageState extends State<IntroVideoPage> {
  static const String _asset =
      'assets/icon/videos/BusTrack_AppGUI_Showcase.mp4';

  late final VideoPlayerController _vc = VideoPlayerController.asset(_asset);
  bool _ready = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _vc
        .initialize()
        .then((_) {
          if (!mounted) return;
          _vc.setLooping(true); // repeat until the user taps Skip
          _vc.addListener(_tick);
          setState(() => _ready = true);
          _vc.play();
        })
        .catchError((_) {
          // video could not load -> go straight to the slides
          _finish();
        });
  }

  void _tick() {
    // the video loops, so it never "ends" - only Skip leaves this page.
    // Just keep the play/pause overlay in sync.
    if (!_vc.value.isInitialized || _finished) return;
    if (mounted) setState(() {});
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    if (mounted) widget.onDone();
  }

  void _togglePlay() {
    if (!_ready) return;
    _vc.value.isPlaying ? _vc.pause() : _vc.play();
  }

  @override
  void dispose() {
    _vc.removeListener(_tick);
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paused = _ready && !_vc.value.isPlaying;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Center(
              child: _ready
                  ? SizedBox.expand(
                      // contain = show the whole video, nothing cropped
                      // (black bars fill any leftover space)
                      child: FittedBox(
                        fit: BoxFit.contain,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: _vc.value.size.width,
                          height: _vc.value.size.height,
                          child: VideoPlayer(_vc),
                        ),
                      ),
                    )
                  : const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: kGold,
                      ),
                    ),
            ),
          ),
          if (paused)
            const IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 76,
                  color: Colors.white70,
                ),
              ),
            ),
          if (_ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: VideoProgressIndicator(
                  _vc,
                  allowScrubbing: true,
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                  colors: const VideoProgressColors(
                    playedColor: kGold,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 14, 0),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Skip',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.skip_next_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// LOGIN
// =====================================================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static bool _seenIntro = false;
  bool _replayVideo = false; // teaser re-opened from the login page
  bool _recovery = false; // opened from a "reset password" email link

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      stream: _sb.auth.onAuthStateChange,
      builder: (context, snap) {
        final st = snap.data;
        if (st is AuthState && st.event == AuthChangeEvent.passwordRecovery) {
          _recovery = true;
        }
        if (_recovery && _sb.auth.currentSession != null) {
          return ResetPasswordPage(
            onDone: () => setState(() => _recovery = false),
          );
        }
        if (_sb.auth.currentSession != null) {
          if (_showGetStarted) {
            return WelcomeFlow(
              onDone: () => setState(() => _showGetStarted = false),
            );
          }
          return const RoleRouter();
        }
        if (_replayVideo) {
          // teaser opened from the login page: go back to login afterwards
          return IntroVideoPage(
            onDone: () => setState(() => _replayVideo = false),
          );
        }
        if (!_seenIntro) {
          return WelcomePage(onDone: () => setState(() => _seenIntro = true));
        }
        return LoginPage(
          onBack: () => setState(() => _seenIntro = false),
          onWatchVideo: () => setState(() => _replayVideo = true),
        );
      },
    );
  }
}

/// Shown after the user opens the link in the "reset password" email.
class ResetPasswordPage extends StatefulWidget {
  final VoidCallback onDone;
  const ResetPasswordPage({super.key, required this.onDone});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _p1 = TextEditingController();
  final TextEditingController _p2 = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _good = false;
  String? _message;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_p1.text.length < 6) {
      setState(() {
        _good = false;
        _message = 'Use at least 6 characters.';
      });
      return;
    }
    if (_p1.text != _p2.text) {
      setState(() {
        _good = false;
        _message = 'The two passwords are not the same.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _sb.auth.updateUser(UserAttributes(password: _p1.text));
      if (!mounted) return;
      setState(() {
        _good = true;
        _message = 'Password changed.';
      });
      await Future.delayed(const Duration(milliseconds: 900));
      widget.onDone();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _good = false;
          _message = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _good = false;
          _message = _msg(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandMark(size: 56)),
                      const SizedBox(height: 16),
                      const Text(
                        'Set a new password',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _p1,
                        obscureText: _obscure,
                        decoration: fieldDeco('New password', Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: kMuted,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _p2,
                        obscureText: _obscure,
                        onSubmitted: (_) => _save(),
                        decoration: fieldDeco('Confirm new password', Icons.lock_reset_rounded),
                      ),
                      if (_message != null) MsgBox(_message!, good: _good),
                      const SizedBox(height: 18),
                      GoldButton(
                        label: 'Save password',
                        icon: Icons.check_rounded,
                        busy: _busy,
                        onPressed: _busy ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App logo with a pop-in entrance and soft expanding rings behind it.
class _LogoHalo extends StatefulWidget {
  const _LogoHalo();

  @override
  State<_LogoHalo> createState() => _LogoHaloState();
}

class _LogoHaloState extends State<_LogoHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                for (var k = 0; k < 2; k++)
                  Builder(
                    builder: (_) {
                      final v = (_c.value + k * 0.5) % 1.0;
                      final s = 72 + 70 * v;
                      return Container(
                        width: s,
                        height: s,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kGold.withAlpha(((1 - v) * 90).round()),
                            width: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (_, v, c) => Transform.scale(scale: v, child: c),
            child: const BrandMark(size: 72),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onWatchVideo; // re-play the teaser video
  const LoginPage({super.key, this.onBack, this.onWatchVideo});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _idNo = TextEditingController();
  late final AnimationController _shakeC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  bool _signUp = false;
  bool _busy = false;
  bool _obscure = true;
  bool _good = false;
  String _type = 'regular';
  String _portal = 'passenger'; // passenger, driver or conductor
  DateTime? _dob; // birth date, needed for the student / senior / PWD discount
  String? _message;
  // shown on the login screen after we signed someone out on purpose
  static String? _flash;

  @override
  void initState() {
    super.initState();
    _message = _flash;
    _flash = null;
    // refresh the strength meter while typing (sign up only)
    _pass.addListener(() {
      if (_signUp && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _idNo.dispose();
    _shakeC.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - (_type == 'senior' ? 65 : 18), 1, 1),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (d != null && mounted) setState(() => _dob = d);
  }

  void _fail(String text) {
    _showGetStarted = false;
    if (!mounted) return;
    setState(() => _message = text);
    _shakeC.forward(from: 0);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
      _good = false;
    });
    try {
      _showGetStarted = true; // show "Let's get started" after success
      if (_signUp) {
        if (_portal != 'passenger') {
          final bad = IdCheck.idNumber(_idNo.text);
          if (bad != null) throw Exception(bad);
        }
        if (_name.text.trim().isEmpty) {
          throw Exception('Please type your name.');
        }
        if (_portal == 'passenger' && _isDiscountType(_type)) {
          final bad = ageProblem(_type, _dob) ?? IdCheck.idNumber(_idNo.text);
          if (bad != null) throw Exception(bad);
        }
        final res = await _sb.auth.signUp(
          email: _email.text.trim(),
          password: _pass.text,
          data: {
            'full_name': _name.text.trim(),
            // the discount only starts after the ID is verified by an admin
            'passenger_type': 'regular',
            if (_portal == 'passenger' && _isDiscountType(_type))
              'wants_discount': _type,
            if (_portal == 'passenger' && _isDiscountType(_type))
              'birth_date': _isoDate(_dob!),
            if (_portal == 'passenger' && _isDiscountType(_type))
              'id_number': _idNo.text.trim(),
            if (_portal != 'passenger') 'wants_role': _portal,
            if (_portal != 'passenger') 'id_number': _idNo.text.trim(),
          },
        );
        if (res.session == null && mounted) {
          _showGetStarted = false; // they log in after confirming
          setState(() {
            _good = true;
            _message = _portal == 'passenger'
                ? 'Account created. Check your email to confirm, then log in.'
                : 'Account created. Check your email to confirm, then log in as $_portal and send your ID photo.';
          });
        }
      } else {
        await _sb.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
        // Driver / Conductor login: the account must really be one
        // (or have applied to be one).
        if (_portal != 'passenger') {
          Profile? me;
          try {
            me = await Api.myProfile();
          } catch (_) {}
          final wants = _sb.auth.currentUser?.userMetadata?['wants_role'];
          if (me != null && me.role != _portal && wants != _portal) {
            _flash =
                'This account is not a $_portal account. Choose Sign up to apply.';
            _showGetStarted = false;
            await _sb.auth.signOut();
            if (mounted) {
              _fail(_flash!);
              _flash = null;
            }
          }
        }
      }
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // sends the "reset password" email
  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _fail('Type your email above first, then tap "Forgot password?".');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _good = false;
    });
    try {
      await _sb.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() {
          _good = true;
          _message =
              'We sent a password reset link to $email. Open it, set a new password, then log in.';
        });
      }
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMode(bool signUp) {
    if (_signUp == signUp) return;
    setState(() {
      _signUp = signUp;
      _message = null;
    });
  }

  Widget _tab(String text, bool on, bool signUp) => Expanded(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setMode(signUp),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: on ? kInk : kMuted,
            ),
            child: Text(text),
          ),
        ),
      ),
    ),
  );

  /// Sliding gold pill behind the "Log in / Sign up" labels.
  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: kBg1,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: _signUp ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: kGoldGradient,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: kGold.withAlpha(70),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            _tab('Log in', !_signUp, false),
            _tab('Sign up', _signUp, true),
          ],
        ),
      ],
    ),
  );

  String _portalLabel(String p) => switch (p) {
    'driver' => 'Driver',
    'conductor' => 'Conductor',
    _ => 'Passenger',
  };

  /// Passenger / Driver / Conductor selector (login and sign up).
  Widget _portalBtn(String p) {
    final on = _portal == p;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _portal = p;
          _message = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(right: p == 'conductor' ? 0 : 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? kGold : kSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? kGold : Colors.white12),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _portalLabel(p),
              style: TextStyle(
                color: on ? kInk : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _strength() {
    final p = _pass.text;
    if (p.isEmpty) return const SizedBox.shrink();
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    final color = score <= 1 ? kBad : (score == 2 ? kWarn : kGood);
    final label = ['Too weak', 'Weak', 'Okay', 'Good', 'Strong'][score];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    height: 4,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i < score ? color : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  Widget _trust(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: kGold),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: kMuted, fontSize: 12)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onBack != null)
                      FadeSlide(
                        index: 0,
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: widget.onBack,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: const Text('Intro'),
                            ),
                            const Spacer(),
                            if (widget.onWatchVideo != null)
                              TextButton.icon(
                                onPressed: widget.onWatchVideo,
                                icon: const Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Watch AppFlow'),
                              ),
                          ],
                        ),
                      ),
                    const Center(child: _LogoHalo()),
                    FadeSlide(
                      index: 1,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _signUp ? 'Create your account' : 'Welcome back',
                          key: ValueKey(_signUp),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeSlide(
                      index: 2,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _signUp
                              ? 'Join BusTrack and ride in comfort.'
                              : 'Log in to track and reserve your ride.',
                          key: ValueKey(_signUp),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMuted),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlide(
                      index: 3,
                      child: AnimatedBuilder(
                        animation: _shakeC,
                        builder: (context, c) {
                          final t = _shakeC.value;
                          return Transform.translate(
                            offset: Offset(sin(t * pi * 7) * 9 * (1 - t), 0),
                            child: c,
                          );
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _tabs(),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _portalBtn('passenger'),
                                  _portalBtn('driver'),
                                  _portalBtn('conductor'),
                                ],
                              ),
                              const SizedBox(height: 18),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_signUp)
                                      FadeSlide(
                                        key: const ValueKey('name'),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 14,
                                          ),
                                          child: TextField(
                                            controller: _name,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            decoration: fieldDeco(
                                              'Full name',
                                              Icons.person_outline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    TextField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: fieldDeco(
                                        'Email',
                                        Icons.mail_outline,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _pass,
                                      obscureText: _obscure,
                                      onSubmitted: (_) => _submit(),
                                      decoration:
                                          fieldDeco(
                                            'Password',
                                            Icons.lock_outline,
                                          ).copyWith(
                                            suffixIcon: IconButton(
                                              icon: AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                transitionBuilder: (c, a) =>
                                                    ScaleTransition(
                                                      scale: a,
                                                      child: c,
                                                    ),
                                                child: Icon(
                                                  _obscure
                                                      ? Icons
                                                            .visibility_off_outlined
                                                      : Icons
                                                            .visibility_outlined,
                                                  key: ValueKey(_obscure),
                                                  color: kMuted,
                                                ),
                                              ),
                                              onPressed: () => setState(
                                                () => _obscure = !_obscure,
                                              ),
                                            ),
                                          ),
                                    ),
                                    if (!_signUp)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _busy ? null : _forgot,
                                          child: const Text('Forgot password?'),
                                        ),
                                      ),
                                    if (_signUp) _strength(),
                                    if (_signUp && _portal != 'passenger')
                                      FadeSlide(
                                        key: const ValueKey('idno'),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 14,
                                          ),
                                          child: TextField(
                                            controller: _idNo,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            decoration: fieldDeco(
                                              'ID number (required, e.g. 25-00542)',
                                              Icons.badge_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_signUp && _portal == 'passenger')
                                      FadeSlide(
                                        key: const ValueKey('extra'),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const SizedBox(height: 18),
                                            const Label('I AM A'),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children:
                                                  [
                                                    'regular',
                                                    'student',
                                                    'senior',
                                                    'pwd',
                                                  ].map((t) {
                                                    final on = _type == t;
                                                    return ChoiceChip(
                                                      label: Text(typeLabel(t)),
                                                      selected: on,
                                                      showCheckmark: false,
                                                      selectedColor: kGold,
                                                      backgroundColor:
                                                          kSurface2,
                                                      side: BorderSide(
                                                        color: on
                                                            ? kGold
                                                            : Colors.white12,
                                                      ),
                                                      labelStyle: TextStyle(
                                                        color: on
                                                            ? kInk
                                                            : Colors.white,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      onSelected: (_) =>
                                                          setState(
                                                            () => _type = t,
                                                          ),
                                                    );
                                                  }).toList(),
                                            ),
                                            const SizedBox(height: 8),
Text(
  _type == 'regular'
      ? 'Regular fare. Choose Student, Senior or PWD to get a discount.'
      : 'Student, senior and PWD discounts need your birth date and a valid ID. After you sign up you send a photo of your ID, and an admin checks it before the discount applies.',
  style: const TextStyle(color: kMuted, fontSize: 12),
),
if (_type != 'regular') ...[
  const SizedBox(height: 14),
  InkWell(
    onTap: _pickDob,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      decoration: fieldDeco('Date of birth', Icons.cake_outlined),
      child: Text(
        _dob == null
            ? 'Tap to choose'
            : '${_niceDate(_dob!)}  \u2022  age ${ageOf(_dob!)}',
        style: TextStyle(color: _dob == null ? kMuted : Colors.white),
      ),
    ),
  ),
  const SizedBox(height: 14),
  TextField(
    controller: _idNo,
    textCapitalization: TextCapitalization.characters,
    decoration: fieldDeco('ID number (as printed on your ID)', Icons.badge_outlined),
  ),
],
                                          ],
                                        ),
                                      ),
                                    if (_signUp && _portal != 'passenger')
                                      FadeSlide(
                                        key: const ValueKey('staffnote'),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 14,
                                          ),
                                          child: Text(
                                            'Your ID number is required to sign up. After you create the account, you will also send a photo of your ID. '
                                            'An admin checks it before you can use the ${_portalLabel(_portal).toLowerCase()} screen.',
                                            style: const TextStyle(
                                              color: kMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_message != null)
                                      FadeSlide(
                                        key: ValueKey(_message),
                                        child: MsgBox(_message!, good: _good),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              GoldButton(
                                label: _signUp ? 'Create account' : 'Log in',
                                icon: Icons.arrow_forward_rounded,
                                busy: _busy,
                                onPressed: _busy ? null : _submit,
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _setMode(!_signUp),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: Text(
                                    _signUp
                                        ? 'Already have an account? Log in'
                                        : 'New here? Create an account',
                                    key: ValueKey(_signUp),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeSlide(
                      index: 5,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _trust(Icons.gps_fixed, 'Live GPS'),
                          _trust(Icons.event_seat_rounded, 'Reserve seats'),
                          _trust(Icons.qr_code_2_rounded, 'QR ticket'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- ID number check for driver / conductor applications ----
// This only catches typing mistakes and obvious
// fakes. The admin still checks the photo before approving anyone.
class IdCheck {
  // The sample ID (25-00542) is only an example. Any real ID number is
  // accepted: 4-20 letters, digits, dashes, slashes or spaces.
  static final RegExp _fmt = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/ ]{3,19}$');

  /// null = looks valid, otherwise the message to show.
  static String? idNumber(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return 'Type the ID number shown on your ID.';
    if (!_fmt.hasMatch(v)) {
      return 'That ID number does not look right. Copy it exactly from your ID.';
    }
    if (RegExp(r'^[0\-/ ]+$').hasMatch(v)) return 'That ID number is not valid.';
    return null;
  }

  static List<String> _words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 2)
      .toList();

  /// The name typed from the ID must share at least two words with the
  /// account name (so "Pett Randolph G. Quizada" matches "Pett Quizada").
  static String? name(String idName, String accountName) {
    final a = _words(idName);
    if (a.length < 2) return 'Type your full name exactly as printed on the ID.';
    final b = _words(accountName).toSet();
    final hits = a.where(b.contains).length;
    if (hits < 2) {
      return 'The name on the ID must match the name of your account.';
    }
    return null;
  }
}

// ---- automatic ID photo check ----
// Claude reads the photo and compares it with the sample ID design. The
// description below is the "template": it only lists the layout and kinds of
// fields (never anyone's personal data). To accept another kind of ID, add a
// description to kIdTemplates.
const List<String> kIdTemplates = [
  'North Eastern Mindanao State University (NEMSU) student ID card, portrait '
      'orientation, white plastic: a dark-blue vertical band on the left with '
      'the words NORTH EASTERN MINDANAO STATE UNIVERSITY printed along it; a '
      'round blue university seal at the top right; a passport-style photo of '
      'the holder at the top left; a boxed ID number in the format YY-NNNNN '
      '(two digits, dash, five digits) under the seal; the holder name in '
      'white capitals on a dark-blue banner; lines for COURSE, DATE OF BIRTH, '
      'EMAIL and ADDRESS; and two printed names with handwritten signatures at '
      'the bottom: the Campus Director (Tandag Campus) and the University '
      'President.',
];

class IdScan {
  final bool? valid; // null = could not check (service down)
  final String idNumber;
  final String name;
  final String reason;
  const IdScan(this.valid, this.idNumber, this.name, this.reason);
}

class IdScanner {
  static String _fold(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Future<IdScan> scan({
    required Uint8List bytes,
    required String mime,
    required String typedIdNumber,
  }) async {
    if (!kAiOn) return const IdScan(null, '', '', 'AI check is off');
    final system =
        'You check photos of ID cards for a bus app. Compare the photo with '
        'these accepted ID designs:\n'
        '${kIdTemplates.map((t) => '- $t').join('\n')}\n\n'
        'Answer with ONE json object and nothing else: '
        '{"matches_design": true/false, "id_number": "text read from the card or empty", '
        '"holder_name": "name read from the card or empty", '
        '"looks_edited_or_screen": true/false, "readable": true/false, '
        '"reason": "one short sentence for the user"}. '
        'matches_design is true only if the card clearly has the same layout, '
        'colors, seal, band, fields and signatures. It must be a real physical '
        'card, not a screenshot, a photocopy or an edited image. '
        'If the photo is blurry, cropped or in the dark, set readable to false.';
    final msgs = [
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mime,
              'data': base64Encode(bytes),
            },
          },
          {'type': 'text', 'text': 'Check this ID photo.'},
        ],
      },
    ];
    try {
      final r = await _sb.functions
          .invoke('ask-claude', body: {'system': system, 'messages': msgs})
          .timeout(const Duration(seconds: 45));
      final d = r.data;
      final j = d is Map
          ? Map<String, dynamic>.from(d)
          : jsonDecode('$d') as Map<String, dynamic>;
      if (j['content'] == null) throw Exception('${j['error'] ?? 'no answer'}');
      var text = (j['content'] as List)
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'].toString())
          .join('\n');
      final a = text.indexOf('{'), b = text.lastIndexOf('}');
      if (a < 0 || b <= a) throw Exception('bad answer');
      final o = jsonDecode(text.substring(a, b + 1)) as Map<String, dynamic>;
      final readable = o['readable'] != false;
      final design = o['matches_design'] == true;
      final fake = o['looks_edited_or_screen'] == true;
      final read = '${o['id_number'] ?? ''}'.trim();
      final name = '${o['holder_name'] ?? ''}'.trim();
      final why = '${o['reason'] ?? ''}'.trim();
      if (!readable) {
        return IdScan(false, read, name,
            'The photo is not clear. Lay the ID flat in good light so every word can be read.');
      }
      if (!design || fake) {
        return IdScan(false, read, name,
            why.isEmpty ? 'This does not look like a valid ID card.' : why);
      }
      if (read.isEmpty || _fold(read) != _fold(typedIdNumber)) {
        return IdScan(false, read, name,
            'The ID number on the photo does not match the number you typed.');
      }
      return IdScan(true, read, name, why);
    } catch (e) {
      debugPrint('ID scan failed: $e');
      return const IdScan(null, '', '', 'Could not run the automatic check');
    }
  }
}

// =====================================================
// DRIVER / CONDUCTOR APPLICATION
// A driver or conductor sends a photo of their ID. An admin checks it
// (Supabase > Storage > staff-ids) and then approves the account.
// =====================================================
class StaffApplyPage extends StatefulWidget {
  final Profile profile;
  final String role; // driver or conductor
  final VoidCallback onRefresh;
  const StaffApplyPage({
    super.key,
    required this.profile,
    required this.role,
    required this.onRefresh,
  });

  @override
  State<StaffApplyPage> createState() => _StaffApplyPageState();
}

class _StaffApplyPageState extends State<StaffApplyPage> {
  final TextEditingController _bus = TextEditingController();
  final TextEditingController _idNo = TextEditingController();
  final TextEditingController _idName = TextEditingController();
  Map<String, dynamic>? _req;
  bool _loading = true;
  bool _busy = false;
  XFile? _photo;
  Uint8List? _preview;
  String? _message;
  bool _good = false;

  String get _roleName => widget.role == 'driver' ? 'Driver' : 'Conductor';

  @override
  void initState() {
    super.initState();
    // the ID number typed at sign-up
    _idNo.text =
        '${_sb.auth.currentUser?.userMetadata?['id_number'] ?? ''}';
    _load();
  }

  @override
  void dispose() {
    _bus.dispose();
    _idNo.dispose();
    _idName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.myStaffRequest();
      if (!mounted) return;
      setState(() {
        _req = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _good = false;
        _message = _msg(e);
      });
    }
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = x;
        _preview = bytes;
        _message = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _good = false;
        _message = _msg(e);
      });
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) {
      setState(() {
        _good = false;
        _message = 'Add a clear photo of your ID first.';
      });
      return;
    }
    final bad =
        IdCheck.idNumber(_idNo.text) ??
        IdCheck.name(_idName.text, widget.profile.name);
    if (bad != null) {
      setState(() {
        _good = false;
        _message = bad;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    IdScan? sc;
    try {
      final bytes = _preview ?? await photo.readAsBytes();
      sc = await IdScanner.scan(
        bytes: bytes,
        mime: photo.mimeType ?? 'image/jpeg',
        typedIdNumber: _idNo.text.trim(),
      );
      if (sc.valid == false) {
        if (mounted) {
          setState(() {
            _busy = false;
            _good = false;
            _message = sc!.reason;
          });
        }
        return;
      }
    } catch (_) {}
    try {
      await Api.applyStaff(
        idCheck: sc?.valid == true ? 'passed' : 'unchecked',
        idCheckNote: sc?.reason ?? '',
        role: widget.role,
        busHint: _bus.text.trim(),
        idNumber: _idNo.text.trim(),
        photo: photo,
        replace: _req != null,
      );
      _photo = null;
      _preview = null;
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _good = false;
          _message = _msg(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _waitingView() => [
    GlassCard(
      child: Column(
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 44, color: kGold),
          const SizedBox(height: 12),
          const Text(
            'Waiting for approval',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ID photo was sent. An admin will check it and assign your bus. '
            'After that, log in again to open the $_roleName screen.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Check again',
            icon: Icons.refresh_rounded,
            onPressed: widget.onRefresh,
          ),
        ],
      ),
    ),
  ];

  List<Widget> _formView(String status) => [
    GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hi ${widget.profile.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'To use the $_roleName screen we need a clear photo of your ID. '
            'An admin checks it before your account is approved. '
            'Only you and the admin can see it.',
            style: const TextStyle(color: kMuted),
          ),
          if (status == 'rejected')
            MsgBox('Your last photo was not accepted. Please send a clearer one.'),
          const SizedBox(height: 16),
          TextField(
            controller: _idName,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco(
              'Full name on the ID',
              Icons.badge_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _idNo,
            keyboardType: TextInputType.number,
            decoration: fieldDeco(
              'ID number (e.g. 25-00542)',
              Icons.pin_outlined,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bus,
            textCapitalization: TextCapitalization.characters,
            decoration: fieldDeco(
              'Bus number (optional, e.g. DV-03)',
              Icons.directions_bus_outlined,
            ),
          ),
          const SizedBox(height: 14),
          if (_preview != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_preview!, height: 200, fit: BoxFit.cover),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ),
            ],
          ),
          if (_message != null) MsgBox(_message!, good: _good),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Send for approval',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final status = '${_req?['status'] ?? ''}';
    final waiting = _req != null && status != 'rejected';
    return BackdropScaffold(
      appBar: premiumBar('$_roleName application', actions: [_logoutButton()]),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: waiting ? _waitingView() : _formView(status),
            ),
    );
  }
}

// =====================================================
// ADMIN: approve or reject driver / conductor applications
// Only accounts listed in the database table "admins" get this screen, and
// the database itself refuses everyone else (see admin_setup.sql).
// =====================================================
// Big, tidy ID photo for the admin. Tap it to open a full-screen viewer where
// the photo can be pinched / double-tapped to zoom.
class IdPhotoThumb extends StatelessWidget {
  final String url;
  final String title;
  const IdPhotoThumb({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IdPhotoViewer(url: url, title: title),
        ),
      ),
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withAlpha(110)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                loadingBuilder: (_, child, p) => p == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                          color: kGold,
                          strokeWidth: 2,
                        ),
                      ),
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Could not load the photo',
                    style: TextStyle(color: kMuted),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC070B14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_out_map_rounded, size: 14, color: kGoldLight),
                      SizedBox(width: 6),
                      Text(
                        'Tap to enlarge',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IdPhotoViewer extends StatelessWidget {
  final String url;
  final String title;
  const IdPhotoViewer({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'ID photo - $title',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              loadingBuilder: (_, child, p) => p == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: kGold),
                    ),
              errorBuilder: (_, __, ___) => const Text(
                'Could not load the photo',
                style: TextStyle(color: kMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// TRIP RATINGS (passenger) + ADMIN DASHBOARD
// Both need features_setup.sql to be run once in Supabase.
// =====================================================
class RatingApi {
  static Future<Map<String, dynamic>?> mine(String ticketId) async {
    final rows = await _sb
        .from('trip_ratings')
        .select()
        .eq('reservation_id', ticketId)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  static Future<void> save(Ticket t, int stars, String comment) async {
    try {
      await _sb.from('trip_ratings').upsert({
        'reservation_id': t.id,
        'bus_id': t.busId,
        'stars': stars,
        'comment': comment.trim().isEmpty ? null : comment.trim(),
      });
    } on PostgrestException catch (e) {
      throw Exception('${e.message} (run features_setup.sql in Supabase)');
    }
  }
}

/// Shown on a finished ticket: 1-5 stars and an optional comment.
class RateTripCard extends StatefulWidget {
  final Ticket ticket;
  const RateTripCard({super.key, required this.ticket});

  @override
  State<RateTripCard> createState() => _RateTripCardState();
}

class _RateTripCardState extends State<RateTripCard> {
  final TextEditingController _c = TextEditingController();
  int _stars = 0;
  bool _busy = false;
  bool _saved = false;
  bool _good = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await RatingApi.mine(widget.ticket.id);
      if (!mounted || r == null) return;
      setState(() {
        _stars = _i(r['stars']);
        _c.text = '${r['comment'] ?? ''}';
        _saved = true;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() {
        _good = false;
        _note = 'Tap a star first.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      await RatingApi.save(widget.ticket, _stars, _c.text);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _good = true;
        _note = 'Thank you for rating your trip!';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _good = false;
          _note = _msg(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: kGold.withAlpha(90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _saved ? 'Your rating' : 'How was your trip?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: _busy ? null : () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: kGold,
                    size: 34,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _c,
            maxLines: 2,
            decoration: fieldDeco(
              'Comment (optional)',
              Icons.chat_bubble_outline,
            ),
          ),
          if (_note != null) MsgBox(_note!, good: _good),
          const SizedBox(height: 12),
          GoldButton(
            label: _saved ? 'Update rating' : 'Send rating',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// Admin > Dashboard tab: totals, last 7 days, busiest buses and ratings.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _s;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _call(() => _sb.rpc('admin_stats'));
      final m = r is Map
          ? Map<String, dynamic>.from(r)
          : jsonDecode('$r') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _s = m;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = '${_msg(e)}\n\nRun features_setup.sql in Supabase.',
      );
    }
  }

  List<Map<String, dynamic>> _list(String k) => ((_s?[k] as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Widget _row2(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [a, const SizedBox(width: 10), b]),
  );

  Widget _days() {
    final days = _list('by_day');
    if (days.isEmpty) return const SizedBox.shrink();
    final mx = max(1, days.map((d) => _i(d['n'])).reduce(max));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reservations, last 7 days',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${_i(d['n'])}',
                          style: const TextStyle(color: kMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 8 + 70.0 * _i(d['n']) / mx,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            gradient: kGoldGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${d['day']}',
                          style: const TextStyle(color: kMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buses() {
    final rows = _list('by_bus');
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Busiest buses',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final b in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_bus_filled,
                      size: 18,
                      color: kGold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${b['bus_id']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${_i(b['n'])} trips • ${peso(_d(b['rev']))}',
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                    if (b['avg'] != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 15, color: kGold),
                      Text(
                        _d(b['avg']).toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: kGold));
    }
    if (s == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [MsgBox(_error!)]);
    }
    final avg = s['rating_avg'] == null ? null : _d(s['rating_avg']);
    return RefreshIndicator(
      color: kGold,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row2(
            StatTile(
              icon: Icons.confirmation_number_outlined,
              value: '${_i(s['reservations'])}',
              label: 'Reservations',
            ),
            StatTile(
              icon: Icons.event_available_rounded,
              value: '${_i(s['active'])}',
              label: 'Active now',
              color: kWarn,
            ),
          ),
          _row2(
            StatTile(
              icon: Icons.payments_outlined,
              value: peso(_d(s['revenue'])),
              label: 'Paid fares',
              color: kGood,
            ),
            StatTile(
              icon: Icons.people_alt_outlined,
              value: '${_i(s['passengers'])}',
              label: 'Passengers',
            ),
          ),
          _row2(
            StatTile(
              icon: Icons.verified_outlined,
              value: '${_i(s['completed'])}',
              label: 'Completed',
              color: kGood,
            ),
            StatTile(
              icon: Icons.cancel_outlined,
              value: '${_i(s['cancelled'])}',
              label: 'Cancelled / missed',
              color: kBad,
            ),
          ),
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: kGold, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avg == null ? 'No ratings yet' : '${avg.toStringAsFixed(1)} / 5',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_i(s['rating_count'])} passenger rating${_i(s['rating_count']) == 1 ? '' : 's'}',
                        style: const TextStyle(color: kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _days(),
          _buses(),
        ],
      ),
    );
  }
}

// =====================================================
// DISCOUNT VERIFICATION (student / senior / PWD)
// A discount only applies after the passenger confirms their age (date of
// birth) and sends a valid ID. The AI reads the ID and compares the ID number,
// name and birth date; an admin then approves it (Admin > Discounts).
// Needs discounts_setup.sql in Supabase.
// =====================================================
int ageOf(DateTime dob, [DateTime? on]) {
  final n = on ?? DateTime.now();
  var a = n.year - dob.year;
  if (n.month < dob.month || (n.month == dob.month && n.day < dob.day)) a--;
  return a;
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _niceDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

bool _isDiscountType(String t) => t == 'student' || t == 'senior' || t == 'pwd';

String discountIdLabel(String t) => switch (t) {
  'student' => 'student ID',
  'senior' => 'Senior Citizen ID',
  'pwd' => 'PWD ID',
  _ => 'ID',
};

/// null = the birth date is fine for this discount, otherwise the message.
String? ageProblem(String type, DateTime? dob) {
  if (dob == null) return 'Choose your date of birth.';
  final a = ageOf(dob);
  if (dob.isAfter(DateTime.now()) || a > 120) {
    return 'That birth date does not look right.';
  }
  if (type == 'senior' && a < 60) {
    return 'The senior citizen discount is for ages 60 and above. Your age is $a.';
  }
  if (type == 'student' && a < 5) return 'Please check your birth date.';
  return null;
}

class DiscountApi {
  static Future<Map<String, dynamic>?> mine() async {
    final rows = await _sb
        .from('discount_requests')
        .select()
        .eq('user_id', _sb.auth.currentUser!.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  // photo goes to the private "staff-ids" bucket, in the user's own folder
  static Future<void> apply({
    required String type,
    required String idNumber,
    required DateTime dob,
    required XFile photo,
    required Uint8List bytes,
    required String check,
    required String note,
    required bool replace,
  }) async {
    final uid = _sb.auth.currentUser!.id;
    if (bytes.length > 6 * 1024 * 1024) {
      throw Exception('That photo is too big. Please use one under 6 MB.');
    }
    var ext = photo.name.contains('.')
        ? photo.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!RegExp(r'^[a-z0-9]{2,5}$').hasMatch(ext)) ext = 'jpg';
    final path = '$uid/discount_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _sb.storage
        .from('staff-ids')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: photo.mimeType ?? 'image/jpeg'),
        );
    final row = {
      'wanted_type': type,
      'id_number': idNumber,
      'birth_date': _isoDate(dob),
      'id_photo_path': path,
      'id_check': check,
      'id_check_note': note,
      'status': 'pending',
    };
    try {
      if (replace) {
        await _sb.from('discount_requests').update(row).eq('user_id', uid);
      } else {
        await _sb.from('discount_requests').insert({...row, 'user_id': uid});
      }
    } on PostgrestException catch (e) {
      throw Exception('${e.message} (run discounts_setup.sql in Supabase)');
    }
  }

  static Future<List<Map<String, dynamic>>> adminList() async {
    final res = await _call(() => _sb.rpc('admin_discount_requests'));
    final list = res is List ? res : (jsonDecode('$res') as List);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> adminDecide(String userId, bool approve) => _call(
    () => _sb.rpc(
      'admin_decide_discount',
      params: {'p_user': userId, 'p_approve': approve},
    ),
  );
}

/// Reads a discount ID photo with the AI and compares it with what the
/// passenger typed (ID number, name, birth date).
class DiscountIdScanner {
  static Future<IdScan> scan({
    required Uint8List bytes,
    required String mime,
    required String type,
    required String typedIdNumber,
    required DateTime dob,
    required String accountName,
  }) async {
    if (!kAiOn) return const IdScan(null, '', '', 'AI check is off');
    final want = switch (type) {
      'student' => 'a school or university student ID card',
      'senior' =>
        'a Senior Citizen ID (OSCA) or another government ID that shows the birth date',
      _ => 'a PWD ID (Persons with Disability ID)',
    };
    final system =
        'You check photos of ID cards for a bus fare discount. The applicant says this photo is $want. '
        'Answer with ONE json object and nothing else: '
        '{"is_real_id": true/false, "type_matches": true/false, '
        '"id_number": "text read from the card or empty", '
        '"holder_name": "name read from the card or empty", '
        '"birth_date": "YYYY-MM-DD read from the card, or empty if not shown", '
        '"looks_edited_or_screen": true/false, "readable": true/false, '
        '"reason": "one short sentence for the user"}. '
        'is_real_id is true only for a real physical card photographed directly, '
        'not a screenshot, a photocopy, a drawing or an edited image. '
        'type_matches is true only if the card is the kind of ID the applicant says. '
        'If the photo is blurry, cropped or dark, set readable to false.';
    final msgs = [
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mime,
              'data': base64Encode(bytes),
            },
          },
          {'type': 'text', 'text': 'Check this ID photo.'},
        ],
      },
    ];
    try {
      final r = await _sb.functions
          .invoke('ask-claude', body: {'system': system, 'messages': msgs})
          .timeout(const Duration(seconds: 45));
      final d = r.data;
      final j = d is Map
          ? Map<String, dynamic>.from(d)
          : jsonDecode('$d') as Map<String, dynamic>;
      if (j['content'] == null) throw Exception('${j['error'] ?? 'no answer'}');
      final text = (j['content'] as List)
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'].toString())
          .join('\n');
      final a = text.indexOf('{'), b = text.lastIndexOf('}');
      if (a < 0 || b <= a) throw Exception('bad answer');
      final o = jsonDecode(text.substring(a, b + 1)) as Map<String, dynamic>;
      final readable = o['readable'] != false;
      final real = o['is_real_id'] == true;
      final typeOk = o['type_matches'] == true;
      final fake = o['looks_edited_or_screen'] == true;
      final read = '${o['id_number'] ?? ''}'.trim();
      final name = '${o['holder_name'] ?? ''}'.trim();
      final bd = DateTime.tryParse('${o['birth_date'] ?? ''}'.trim());
      final why = '${o['reason'] ?? ''}'.trim();
      if (!readable) {
        return IdScan(false, read, name,
            'The photo is not clear. Lay the ID flat in good light so every word can be read.');
      }
      if (!real || fake) {
        return IdScan(false, read, name,
            why.isEmpty ? 'This does not look like a real ID card.' : why);
      }
      if (!typeOk) {
        return IdScan(false, read, name,
            'This does not look like a ${discountIdLabel(type)}. $why'.trim());
      }
      if (read.isEmpty || _fold(read) != _fold(typedIdNumber)) {
        return IdScan(false, read, name,
            'The ID number on the photo does not match the number you typed.');
      }
      if (IdCheck.name(name, accountName) != null) {
        return IdScan(false, read, name,
            'The name on the ID does not match the name of your account.');
      }
      if (bd != null) {
        if (bd.year != dob.year || bd.month != dob.month || bd.day != dob.day) {
          return IdScan(false, read, name,
              'The birth date on the ID does not match the date you entered.');
        }
      } else if (type == 'senior') {
        return IdScan(false, read, name,
            'The birth date must be readable on a senior ID. Please take a clearer photo.');
      }
      return IdScan(true, read, name, why);
    } catch (e) {
      debugPrint('Discount ID scan failed: $e');
      return const IdScan(null, '', '', 'Could not run the automatic check');
    }
  }
}

/// Sends the passenger to the ID screen right after log in / sign up when
/// they asked for a discount but have not been verified yet.
class DiscountGate extends StatefulWidget {
  final Profile profile;
  final Widget child;
  const DiscountGate({super.key, required this.profile, required this.child});

  @override
  State<DiscountGate> createState() => _DiscountGateState();
}

class _DiscountGateState extends State<DiscountGate> {
  static final Set<String> _skipped = {};
  bool _need = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final wants = _sb.auth.currentUser?.userMetadata?['wants_discount'];
    if (widget.profile.type == 'regular' &&
        _isDiscountType('$wants') &&
        !_skipped.contains(widget.profile.id)) {
      _checking = true;
      _check();
    }
  }

  Future<void> _check() async {
    var need = true;
    try {
      final r = await DiscountApi.mine();
      final status = '${r?['status'] ?? ''}';
      need = r == null || status == 'rejected';
    } catch (_) {
      need = false; // table missing: do not block the app
    }
    if (!mounted) return;
    setState(() {
      _need = need;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Backdrop(
          child: Center(child: CircularProgressIndicator(color: kGold)),
        ),
      );
    }
    if (_need) {
      return DiscountApplyPage(
        profile: widget.profile,
        onDone: () {
          _skipped.add(widget.profile.id);
          setState(() => _need = false);
        },
      );
    }
    return widget.child;
  }
}

class DiscountApplyPage extends StatefulWidget {
  final Profile profile;
  final VoidCallback onDone; // continue into the app / close this page
  const DiscountApplyPage({
    super.key,
    required this.profile,
    required this.onDone,
  });

  @override
  State<DiscountApplyPage> createState() => _DiscountApplyPageState();
}

class _DiscountApplyPageState extends State<DiscountApplyPage> {
  final TextEditingController _idNo = TextEditingController();
  final TextEditingController _idName = TextEditingController();
  String _type = 'student';
  DateTime? _dob;
  Map<String, dynamic>? _req;
  bool _loading = true;
  bool _busy = false;
  XFile? _photo;
  Uint8List? _preview;
  String? _message;

  @override
  void initState() {
    super.initState();
    final meta = _sb.auth.currentUser?.userMetadata;
    final wants = '${meta?['wants_discount'] ?? ''}';
    if (_isDiscountType(wants)) _type = wants;
    _idNo.text = '${meta?['id_number'] ?? ''}';
    _dob = DateTime.tryParse('${meta?['birth_date'] ?? ''}');
    _load();
  }

  @override
  void dispose() {
    _idNo.dispose();
    _idName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await DiscountApi.mine();
      if (!mounted) return;
      setState(() {
        _req = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = _msg(e);
      });
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - (_type == 'senior' ? 65 : 18), 1, 1),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (d != null && mounted) setState(() => _dob = d);
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = x;
        _preview = bytes;
        _message = null;
      });
    } catch (e) {
      if (mounted) setState(() => _message = _msg(e));
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    final bytes = _preview;
    if (photo == null || bytes == null) {
      setState(() => _message = 'Add a clear photo of your ID first.');
      return;
    }
    final bad =
        ageProblem(_type, _dob) ??
        IdCheck.idNumber(_idNo.text) ??
        IdCheck.name(_idName.text, widget.profile.name);
    if (bad != null) {
      setState(() => _message = bad);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final sc = await DiscountIdScanner.scan(
        bytes: bytes,
        mime: photo.mimeType ?? 'image/jpeg',
        type: _type,
        typedIdNumber: _idNo.text.trim(),
        dob: _dob!,
        accountName: widget.profile.name,
      );
      if (sc.valid == false) {
        if (mounted) {
          setState(() {
            _busy = false;
            _message = sc.reason;
          });
        }
        return;
      }
      await DiscountApi.apply(
        type: _type,
        idNumber: _idNo.text.trim(),
        dob: _dob!,
        photo: photo,
        bytes: bytes,
        check: sc.valid == true ? 'passed' : 'unchecked',
        note: sc.reason,
        replace: _req != null,
      );
      _photo = null;
      _preview = null;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _message = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _typeChips() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: ['student', 'senior', 'pwd'].map((t) {
      final on = _type == t;
      return ChoiceChip(
        label: Text(typeLabel(t)),
        selected: on,
        showCheckmark: false,
        selectedColor: kGold,
        backgroundColor: kSurface2,
        side: BorderSide(color: on ? kGold : Colors.white12),
        labelStyle: TextStyle(
          color: on ? kInk : Colors.white,
          fontWeight: FontWeight.w700,
        ),
        onSelected: _busy ? null : (_) => setState(() => _type = t),
      );
    }).toList(),
  );

  List<Widget> _statusView(String status) => [
    GlassCard(
      child: Column(
        children: [
          Icon(
            status == 'approved'
                ? Icons.verified_rounded
                : Icons.hourglass_top_rounded,
            size: 44,
            color: status == 'approved' ? kGood : kGold,
          ),
          const SizedBox(height: 12),
          Text(
            status == 'approved' ? 'Discount approved' : 'Waiting for approval',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            status == 'approved'
                ? 'Your ${typeLabel('${_req?['wanted_type']}')} discount is active. Log in again if your fares do not show it yet.'
                : 'Your ID was sent. An admin will check it. Until then you pay the full fare, and the discount starts once it is approved.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: widget.onDone,
          ),
        ],
      ),
    ),
  ];

  List<Widget> _formView(String status) => [
    GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Get your fare discount',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Students, seniors and PWD pay less. Confirm your age and send a valid ID. '
            'An admin checks it before the discount applies. Only you and the admin can see it.',
            style: TextStyle(color: kMuted),
          ),
          if (status == 'rejected')
            const MsgBox('Your last ID was not accepted. Please send a clearer one.'),
          const SizedBox(height: 16),
          const Label('DISCOUNT TYPE'),
          _typeChips(),
          const SizedBox(height: 14),
          InkWell(
            onTap: _busy ? null : _pickDob,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: fieldDeco('Date of birth', Icons.cake_outlined),
              child: Text(
                _dob == null
                    ? 'Tap to choose'
                    : '${_niceDate(_dob!)}  \u2022  age ${ageOf(_dob!)}',
                style: TextStyle(color: _dob == null ? kMuted : Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _idName,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco('Full name on the ID', Icons.badge_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _idNo,
            textCapitalization: TextCapitalization.characters,
            decoration: fieldDeco('ID number', Icons.pin_outlined),
          ),
          const SizedBox(height: 14),
          if (_preview != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_preview!, height: 200, fit: BoxFit.cover),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ),
            ],
          ),
          if (_message != null) MsgBox(_message!),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Send for verification',
            icon: Icons.send_rounded,
            busy: _busy,
            onPressed: _busy ? null : _submit,
          ),
          TextButton(
            onPressed: _busy ? null : widget.onDone,
            child: const Text('Continue without a discount'),
          ),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final status = '${_req?['status'] ?? ''}';
    final showStatus = _req != null && status != 'rejected';
    return BackdropScaffold(
      appBar: premiumBar('Discount verification'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: showStatus ? _statusView(status) : _formView(status),
            ),
    );
  }
}

/// Admin > Discounts tab.
class AdminDiscounts extends StatefulWidget {
  const AdminDiscounts({super.key});

  @override
  State<AdminDiscounts> createState() => _AdminDiscountsState();
}

class _AdminDiscountsState extends State<AdminDiscounts> {
  List<Map<String, dynamic>>? _list;
  final Map<String, String> _photo = {};
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await DiscountApi.adminList();
      if (!mounted) return;
      for (final r in l) {
        final id = '${r['user_id']}';
        final path = '${r['id_photo_path'] ?? ''}';
        if (path.isNotEmpty && !_photo.containsKey(id)) {
          Api.idPhotoUrl(path).then((u) {
            if (mounted) setState(() => _photo[id] = u);
          }).catchError((_) {});
        }
      }
      setState(() {
        _list = l;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = '${_msg(e)}\n\nRun discounts_setup.sql in Supabase.',
        );
      }
    }
  }

  Future<void> _decide(String id, bool approve) async {
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await DiscountApi.adminDecide(id, approve);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _card(Map<String, dynamic> r) {
    final id = '${r['user_id']}';
    final type = '${r['wanted_type']}';
    final dob = DateTime.tryParse('${r['birth_date']}');
    final age = dob == null ? null : ageOf(dob);
    final passed = '${r['id_check']}' == 'passed';
    final ageBad = dob == null ? true : ageProblem(type, dob) != null;
    final url = _photo[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['full_name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Pill(text: typeLabel(type), color: kGold),
              ],
            ),
            const SizedBox(height: 6),
            kv('Email', '${r['email']}'),
            kv('ID number', '${r['id_number'] ?? '-'}'),
            kv(
              'Birth date',
              dob == null ? '-' : '${_niceDate(dob)} (age $age)',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Auto check', style: TextStyle(color: kMuted)),
                  Pill(
                    text: passed ? 'Passed' : 'Not checked',
                    color: passed ? kGood : kWarn,
                  ),
                ],
              ),
            ),
            if (ageBad)
              const MsgBox('The age does not fit this discount. Check before approving.'),
            const SizedBox(height: 10),
            if (url != null)
              IdPhotoThumb(url: url, title: '${r['full_name']}')
            else
              const SizedBox(
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(color: kGold, strokeWidth: 2),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busyId == id ? null : () => _decide(id, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBad,
                      side: const BorderSide(color: kBad),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GoldButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    busy: _busyId == id,
                    onPressed: _busyId == id ? null : () => _decide(id, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    if (l == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: kGold));
    }
    return RefreshIndicator(
      color: kGold,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) MsgBox(_error!),
          if (l != null && l.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'No discount IDs waiting',
                  style: TextStyle(color: kMuted),
                ),
              ),
            ),
          if (l != null) ...l.map(_card),
        ],
      ),
    );
  }
}

// =====================================================
// LIVE FLEET: a bus whose driver phone is sending GPS right now is shown
// exactly where the driver is. Every other bus is moved by the demo simulation.
// =====================================================
final Map<String, List<double>> _fleetCum = {};
final Map<String, List<double>> _fleetStopCum = {};

List<double> _fleetCumOf(String routeId, List<LatLng> line) {
  final c = _fleetCum[routeId];
  if (c != null && c.length == line.length) return c;
  const d = Distance();
  final out = <double>[0];
  for (var i = 1; i < line.length; i++) {
    out.add(out.last + d.as(LengthUnit.Meter, line[i - 1], line[i]));
  }
  _fleetCum[routeId] = out;
  _fleetStopCum.remove(routeId);
  return out;
}

/// true while a real driver phone keeps sending GPS (even when stopped)
bool isDriverLive(Bus b) =>
    b.updatedAt != null && (b.ageSeconds ?? 9999) < 30 && b.running;

/// demo fleet: places [b] on its road as if it drove at kSimSpeedKmh
Bus simulateFleetBus(Bus b, List<LatLng> line, List<Stop> stops) {
  final cum = _fleetCumOf(b.routeId, line);
  final total = cum.last;
  if (total <= 0) return b;

  // every bus starts at a different place on its route
  final spread =
      b.id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) % 1000) / 1000.0;
  final secs = DateTime.now().millisecondsSinceEpoch / 1000.0;
  final meters = (spread * total + kSimSpeedKmh / 3.6 * secs) % total;

  var i = 1;
  while (i < cum.length - 1 && cum[i] < meters) {
    i++;
  }
  final a = line[i - 1], c = line[i];
  final seg = cum[i] - cum[i - 1];
  final f = seg <= 0 ? 0.0 : ((meters - cum[i - 1]) / seg).clamp(0.0, 1.0);
  final pos = LatLng(
    a.latitude + (c.latitude - a.latitude) * f,
    a.longitude + (c.longitude - a.longitude) * f,
  );

  // last stop already passed
  final sc = _fleetStopCum.putIfAbsent(
    b.routeId,
    () => stops
        .map(
          (s) => cum[RoadRoutes.nearestIndex(
            line,
            s.pos,
          ).clamp(0, cum.length - 1).toInt()],
        )
        .toList(),
  );
  var seq = stops.first.seq;
  for (var k = 0; k < stops.length; k++) {
    if (sc[k] <= meters) seq = stops[k].seq;
  }

  return Bus(
    id: b.id,
    routeId: b.routeId,
    route: b.route,
    destination: b.destination,
    pos: pos,
    speed: kSimSpeedKmh,
    running: true,
    currentSeq: seq,
    operator: b.operator,
    busType: b.busType,
    updatedAt: b.updatedAt,
  );
}

// =====================================================
// WEATHER (real data from Open-Meteo, no key needed)
// =====================================================
class WxHour {
  final DateTime t;
  final double temp;
  final int rain; // chance of rain, %
  final int code;
  final bool day;
  final int cloud; // cloud cover, %
  WxHour({
    required this.t,
    required this.temp,
    required this.rain,
    required this.code,
    required this.day,
    required this.cloud,
  });
}

class WxDay {
  final DateTime d;
  final int code;
  final double lo;
  final double hi;
  final int rain;
  final int cloud; // average cloud cover, % (-1 = unknown)
  WxDay({
    required this.d,
    required this.code,
    required this.lo,
    required this.hi,
    required this.rain,
    this.cloud = -1,
  });
}

class WeatherData {
  final double temp;
  final int code;
  final bool isDay;
  final double gust;
  final int cloud; // cloud cover right now, %
  final DateTime updated;
  final List<WxHour> hours;
  final List<WxDay> days;
  WeatherData({
    required this.temp,
    required this.code,
    required this.isDay,
    required this.gust,
    required this.cloud,
    required this.updated,
    required this.hours,
    required this.days,
  });
}

class WeatherApi {
  static Future<WeatherData> fetch(double lat, double lng) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lng.toStringAsFixed(4),
      'current':
          'temperature_2m,weather_code,is_day,wind_gusts_10m,cloud_cover',
      'hourly':
          'temperature_2m,precipitation_probability,weather_code,is_day,cloud_cover',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,cloud_cover_mean',
      'forecast_days': '10',
      'timezone': 'auto',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw Exception('The weather service is not available right now.');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final now = DateTime.parse('${cur['time']}');
    final h = j['hourly'] as Map<String, dynamic>;
    final ht = (h['time'] as List).map((e) => '$e').toList();
    final startHour = DateTime(now.year, now.month, now.day, now.hour);
    var s = ht.indexWhere((x) => !DateTime.parse(x).isBefore(startHour));
    if (s < 0) s = 0;
    final hours = <WxHour>[];
    for (var i = s; i < ht.length && hours.length < 25; i++) {
      hours.add(
        WxHour(
          t: DateTime.parse(ht[i]),
          temp: _d((h['temperature_2m'] as List)[i]),
          rain: _i((h['precipitation_probability'] as List)[i]),
          code: _i((h['weather_code'] as List)[i]),
          day: _i((h['is_day'] as List)[i]) == 1,
          cloud: _i((h['cloud_cover'] as List)[i]),
        ),
      );
    }
    final dd = j['daily'] as Map<String, dynamic>;
    final dt = (dd['time'] as List).map((e) => '$e').toList();
    final days = <WxDay>[];
    for (var i = 0; i < dt.length; i++) {
      days.add(
        WxDay(
          d: DateTime.parse(dt[i]),
          code: _i((dd['weather_code'] as List)[i]),
          lo: _d((dd['temperature_2m_min'] as List)[i]),
          hi: _d((dd['temperature_2m_max'] as List)[i]),
          rain: _i((dd['precipitation_probability_max'] as List)[i]),
          cloud: dd['cloud_cover_mean'] == null
              ? -1
              : _i((dd['cloud_cover_mean'] as List)[i]),
        ),
      );
    }
    return WeatherData(
      temp: _d(cur['temperature_2m']),
      code: _i(cur['weather_code']),
      isDay: _i(cur['is_day']) == 1,
      gust: _d(cur['wind_gusts_10m']),
      cloud: _i(cur['cloud_cover']),
      updated: now,
      hours: hours,
      days: days,
    );
  }

  static Future<String> placeName(double lat, double lng) async {
    try {
      final uri = Uri.https(
        'api.bigdatacloud.net',
        '/data/reverse-geocode-client',
        {
          'latitude': lat.toStringAsFixed(4),
          'longitude': lng.toStringAsFixed(4),
          'localityLanguage': 'en',
        },
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      for (final k in ['locality', 'city', 'principalSubdivision']) {
        final v = '${j[k] ?? ''}'.trim();
        if (v.isNotEmpty) return v;
      }
    } catch (_) {}
    return 'Current location';
  }
}

String wxText(int c) => switch (c) {
  0 => 'Clear',
  1 => 'Mostly Clear',
  2 => 'Partly Cloudy',
  3 => 'Mostly Cloudy',
  45 || 48 => 'Foggy',
  51 || 53 || 55 => 'Drizzle',
  56 || 57 => 'Freezing Drizzle',
  61 => 'Light Rain',
  63 => 'Rain',
  65 => 'Heavy Rain',
  66 || 67 => 'Freezing Rain',
  71 || 73 || 75 || 77 => 'Snow',
  80 => 'Light Showers',
  81 => 'Showers',
  82 => 'Heavy Showers',
  85 || 86 => 'Snow Showers',
  95 || 96 || 99 => 'Thunderstorms',
  _ => 'Cloudy',
};

/// The icon code to draw: for clear / cloudy skies the cloud cover decides,
/// so a bright day is shown as sunny. Rain, fog, snow and storms stay as given.
int wxEff(int code, int cloud) {
  if (code > 3 || cloud < 0) return code;
  if (cloud < 35) return 0;
  if (cloud < 65) return 2;
  return 3;
}

String wxLabel(int code, int cloud, bool day) {
  if (code > 3 || cloud < 0) return wxText(code);
  if (cloud < 15) return day ? 'Sunny' : 'Clear';
  if (cloud < 35) return day ? 'Mostly Sunny' : 'Mostly Clear';
  if (cloud < 65) return 'Partly Cloudy';
  if (cloud < 85) return 'Mostly Cloudy';
  return 'Cloudy';
}

bool wxRainy(int c) =>
    (c >= 51 && c <= 67) || (c >= 80 && c <= 82) || c >= 95;

String _hourLabel(int h) =>
    h == 0 ? '12AM' : (h < 12 ? '${h}AM' : (h == 12 ? '12PM' : '${h - 12}PM'));

class WxIcon extends StatelessWidget {
  final int code;
  final bool day;
  final double size;
  const WxIcon({
    super.key,
    required this.code,
    required this.day,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    const sun = Color(0xFFFFC94A);
    const moon = Color(0xFFE8E4FF);
    final sky = day ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    final skyColor = day ? sun : moon;
    if (code == 0 || code == 1) {
      return Icon(sky, size: size, color: skyColor);
    }
    if (code == 2) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(sky, size: size * 0.62, color: skyColor),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Icon(Icons.cloud_rounded, size: size * 0.86, color: Colors.white),
            ),
          ],
        ),
      );
    }
    if (wxRainy(code)) {
      final storm = code >= 95;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Icon(Icons.cloud_rounded, size: size * 0.9, color: Colors.white),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: storm
                  ? Icon(Icons.bolt_rounded, size: size * 0.5, color: sun)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Icon(
                            Icons.water_drop_rounded,
                            size: size * 0.26,
                            color: const Color(0xFF6FC3FF),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
    }
    if (code == 45 || code == 48) {
      return Icon(Icons.foggy, size: size, color: Colors.white70);
    }
    if (code >= 71 && code <= 86) {
      return Icon(Icons.ac_unit_rounded, size: size, color: const Color(0xFFBFE6FF));
    }
    return Icon(Icons.cloud_rounded, size: size, color: Colors.white);
  }
}

/// The small "cloud 25°" button on the commuter map. Tap it for the full forecast.
class WeatherChip extends StatefulWidget {
  const WeatherChip({super.key});

  @override
  State<WeatherChip> createState() => _WeatherChipState();
}

class _WeatherChipState extends State<WeatherChip> {
  WeatherData? _w;
  LatLng _at = kCenter;
  bool _gps = false;
  String _name = '';
  bool _failed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var at = kCenter;
      var gps = false;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 8));
          at = LatLng(p.latitude, p.longitude);
          gps = true;
        }
      } catch (_) {}
      final w = await WeatherApi.fetch(at.latitude, at.longitude);
      final name = await WeatherApi.placeName(at.latitude, at.longitude);
      if (!mounted) return;
      setState(() {
        _w = w;
        _at = at;
        _gps = gps;
        _name = name;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _w;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WeatherPage(
            at: _at,
            usingGps: _gps,
            name: _name,
            data: _w,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xDD070B14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (w != null)
              WxIcon(code: wxEff(w.code, w.cloud), day: w.isDay, size: 20)
            else
              Icon(
                _failed ? Icons.cloud_off_rounded : Icons.cloud_queue_rounded,
                size: 18,
                color: kMuted,
              ),
            const SizedBox(width: 6),
            Text(
              w == null ? '--\u00B0' : '${w.temp.round()}\u00B0',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full forecast screen: now, next hours and the 10-day outlook.
class WeatherPage extends StatefulWidget {
  final LatLng at;
  final bool usingGps;
  final String name;
  final WeatherData? data;
  const WeatherPage({
    super.key,
    required this.at,
    required this.usingGps,
    required this.name,
    this.data,
  });

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  WeatherData? _w;
  late LatLng _at;
  late bool _gps;
  late String _name;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _w = widget.data;
    _at = widget.at;
    _gps = widget.usingGps;
    _name = widget.name;
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final w = await WeatherApi.fetch(_at.latitude, _at.longitude);
      final n = await WeatherApi.placeName(_at.latitude, _at.longitude);
      if (!mounted) return;
      setState(() {
        _w = w;
        _name = n;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useMyLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission was denied.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      _at = LatLng(p.latitude, p.longitude);
      _gps = true;
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  List<Color> _sky(WeatherData w) {
    final eff = wxEff(w.code, w.cloud);
    final rainy = wxRainy(eff);
    final cloudy = eff >= 2;
    if (w.isDay) {
      if (rainy) return const [Color(0xFF3E4C66), Color(0xFF6C7C96)];
      if (cloudy) return const [Color(0xFF4B79B5), Color(0xFF8DB0D6)];
      return const [Color(0xFF2F80ED), Color(0xFF6DB3F2)];
    }
    if (rainy) return const [Color(0xFF1B2236), Color(0xFF39455E)];
    return const [Color(0xFF141B3A), Color(0xFF2B3764)];
  }

  String _summary(WeatherData w) {
    final gust = '${w.gust.round()} km/h';
    WxHour? rain;
    for (final h in w.hours.take(24)) {
      if (h.rain >= 40) {
        rain = h;
        break;
      }
    }
    if (rain != null) {
      final when = identical(rain, w.hours.first)
          ? 'now'
          : 'around ${_hourLabel(rain.t.hour)}';
      return 'Rainy conditions expected $when. Wind gusts are up to $gust.';
    }
    return '${wxLabel(w.code, w.cloud, w.isDay)} conditions for the next 24 hours. Wind gusts are up to $gust.';
  }

  Widget _card({required Widget child, EdgeInsets? pad}) => Container(
    width: double.infinity,
    padding: pad ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black.withAlpha(46),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white12),
    ),
    child: child,
  );

  Widget _hourly(WeatherData w) => SizedBox(
    height: 118,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: w.hours.length,
      separatorBuilder: (_, __) => const SizedBox(width: 18),
      itemBuilder: (_, i) {
        final h = w.hours[i];
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              i == 0 ? 'Now' : _hourLabel(h.t.hour),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            Column(
              children: [
                WxIcon(code: wxEff(h.code, h.cloud), day: h.day, size: 30),
                SizedBox(
                  height: 14,
                  child: h.rain >= 20
                      ? Text(
                          '${h.rain}%',
                          style: const TextStyle(
                            color: Color(0xFF6FC3FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            Text(
              '${h.temp.round()}\u00B0',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
          ],
        );
      },
    ),
  );

  Widget _bar(double lo, double hi, double gmin, double gmax, double? now) =>
      SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (c, cs) {
            final span = max(gmax - gmin, 1.0);
            final left = cs.maxWidth * (lo - gmin) / span;
            final w = max(cs.maxWidth * (hi - lo) / span, 6.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Positioned(
                  left: left,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (now != null)
                  Positioned(
                    left: (cs.maxWidth * (now - gmin) / span - 3)
                        .clamp(0.0, max(cs.maxWidth - 6, 0.0))
                        .toDouble(),
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black38, width: 0.5),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );

  Widget _daily(WeatherData w) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final gmin = w.days.map((d) => d.lo).reduce(min);
    final gmax = w.days.map((d) => d.hi).reduce(max);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white60),
              SizedBox(width: 8),
              Text(
                '10-DAY FORECAST',
                style: TextStyle(
                  color: Colors.white60,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < w.days.length; i++) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      i == 0 ? 'Today' : names[w.days[i].d.weekday - 1],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WxIcon(code: wxEff(w.days[i].code, w.days[i].cloud), day: true, size: 26),
                        SizedBox(
                          height: 14,
                          child: w.days[i].rain >= 20
                              ? Text(
                                  '${w.days[i].rain}%',
                                  style: const TextStyle(
                                    color: Color(0xFF6FC3FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${w.days[i].lo.round()}\u00B0',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _bar(
                      w.days[i].lo,
                      w.days[i].hi,
                      gmin,
                      gmax,
                      i == 0 ? w.temp : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${w.days[i].hi.round()}\u00B0',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = _w;
    final colors = w == null
        ? const [Color(0xFF141B3A), Color(0xFF2B3764)]
        : _sky(w);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Use my location',
                    icon: Icon(
                      _gps ? Icons.near_me_rounded : Icons.near_me_outlined,
                    ),
                    onPressed: _useMyLocation,
                  ),
                ],
              ),
              Expanded(
                child: w == null
                    ? Center(
                        child: _error == null
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(_error!, textAlign: TextAlign.center),
                              ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_gps)
                                      const Icon(Icons.near_me_rounded, size: 16),
                                    if (_gps) const SizedBox(width: 4),
                                    Text(
                                      _gps ? 'MY LOCATION' : 'MAP AREA',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _name.isEmpty ? 'Current location' : _name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${w.temp.round()}\u00B0',
                                  style: const TextStyle(
                                    fontSize: 96,
                                    fontWeight: FontWeight.w200,
                                    height: 1.05,
                                  ),
                                ),
                                Text(
                                  wxLabel(w.code, w.cloud, w.isDay),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  'H:${w.days.first.hi.round()}\u00B0  L:${w.days.first.lo.round()}\u00B0',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _summary(w),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white12, height: 1),
                                  const SizedBox(height: 14),
                                  _hourly(w),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _daily(w),
                            const SizedBox(height: 14),
                            if (_error != null)
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            Text(
                              'Weather data by Open-Meteo \u2022 updated ${_clock12(w.updated)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// TICKET: map + ETA + directions to your stop
// =====================================================
String _clock12(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
}

class TripStep {
  final String text;
  final double meters;
  final IconData icon;
  TripStep(this.text, this.meters, this.icon);
}

class FootRoute {
  final List<LatLng> pts;
  final double meters;
  final double seconds;
  final List<TripStep> steps;
  FootRoute(this.pts, this.meters, this.seconds, this.steps);
}

class RouteApi {
  static IconData _icon(String type, String mod) {
    if (type == 'arrive') return Icons.flag_rounded;
    if (type == 'depart') return Icons.navigation_rounded;
    return switch (mod) {
      'left' => Icons.turn_left_rounded,
      'right' => Icons.turn_right_rounded,
      'slight left' => Icons.turn_slight_left_rounded,
      'slight right' => Icons.turn_slight_right_rounded,
      'sharp left' => Icons.turn_sharp_left_rounded,
      'sharp right' => Icons.turn_sharp_right_rounded,
      'uturn' => Icons.u_turn_left_rounded,
      _ => Icons.straight_rounded,
    };
  }

  static String _text(String type, String mod, String name, String stopName) {
    final onto = name.isEmpty ? '' : ' onto $name';
    final on = name.isEmpty ? '' : ' on $name';
    switch (type) {
      case 'depart':
        return name.isEmpty ? 'Start walking' : 'Start on $name';
      case 'arrive':
        return 'Arrive at $stopName';
      case 'roundabout':
      case 'rotary':
        return 'Take the roundabout$onto';
      case 'continue':
      case 'new name':
        return 'Continue$on';
      default:
        if (mod == 'straight' || mod.isEmpty) return 'Continue$on';
        if (mod == 'uturn') return 'Make a U-turn$on';
        return 'Turn $mod$onto';
    }
  }

  /// walking route from [a] to [b] (OpenStreetMap routing, no key needed)
  static Future<FootRoute?> walk(LatLng a, LatLng b, String stopName) async {
    try {
      final url = Uri.parse(
        'https://routing.openstreetmap.de/routed-foot/route/v1/foot/'
        '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );
      final r = await http.get(url).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final routes = j['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final rt = routes.first as Map<String, dynamic>;
      final coords = (rt['geometry']['coordinates'] as List)
          .map((c) => LatLng(_d(c[1]), _d(c[0])))
          .toList();
      final steps = <TripStep>[];
      final legs = rt['legs'] as List? ?? const [];
      if (legs.isNotEmpty) {
        for (final s in (legs.first['steps'] as List? ?? const [])) {
          final m = s['maneuver'] as Map;
          final type = '${m['type']}';
          final mod = '${m['modifier'] ?? ''}';
          final name = '${s['name'] ?? ''}'.trim();
          steps.add(
            TripStep(
              _text(type, mod, name, stopName),
              _d(s['distance']),
              _icon(type, mod),
            ),
          );
        }
      }
      return FootRoute(coords, _d(rt['distance']), _d(rt['duration']), steps);
    } catch (_) {
      return null;
    }
  }
}

class _Eta {
  final double meters;
  final DateTime at;
  final int mins;
  _Eta(this.meters, this.at, this.mins);
}

String _distText(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// Shown on a reserved / boarded ticket: where the bus is, when it reaches
/// your stop, and how to walk there.
class TripGuide extends StatefulWidget {
  final Ticket ticket;
  // lets the ticket page show the bus ETA at the top, like a navigation panel
  final ValueNotifier<_Eta?>? etaOut;
  const TripGuide({super.key, required this.ticket, this.etaOut});

  @override
  State<TripGuide> createState() => _TripGuideState();
}

class _TripGuideState extends State<TripGuide> {
  final MapController _mc = MapController();
  Timer? _timer;
  Bus? _bus;
  List<Stop> _stops = [];
  List<LatLng> _road = [];
  LatLng? _me;
  FootRoute? _walk;
  String? _error;
  bool _loading = true;
  bool _locating = false;
  bool _noLoc = false;
  bool _showSteps = false;

  bool get _boarded => widget.ticket.status == 'boarded';
  int get _targetSeq =>
      _boarded ? widget.ticket.dropoffSeq : widget.ticket.pickupSeq;
  String get _targetName =>
      _boarded ? widget.ticket.dropoffName : widget.ticket.pickupName;

  LatLng? get _target {
    final pin = _boarded ? widget.ticket.dropoffPin : widget.ticket.pickupPin;
    if (pin != null) return pin;
    for (final s in _stops) {
      if (s.seq == _targetSeq) return s.pos;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Bus _shown(Bus b) {
    if (isDriverLive(b)) return b.asLive();
    if (kSimFleet &&
        b.routeId.isNotEmpty &&
        _road.length >= 2 &&
        _stops.isNotEmpty) {
      return simulateFleetBus(b, _road, _stops);
    }
    return b;
  }

  Future<void> _init() async {
    try {
      final b = await Api.bus(widget.ticket.busId);
      if (b == null) throw Exception('Bus not found.');
      final stops = await Api.stops(b.routeId);
      List<LatLng> road;
      try {
        road = await RoadRoutes.fetch(
          b.routeId,
          stops.map((s) => s.pos).toList(),
        );
      } catch (_) {
        road = stops.map((s) => s.pos).toList();
      }
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _road = road;
        _bus = _shown(b);
        _loading = false;
      });
      _publish();
      _fit();
      _locate();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tickBus());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _msg(e);
        });
      }
    }
  }

  Future<void> _tickBus() async {
    try {
      final b = await Api.bus(widget.ticket.busId);
      if (b != null && mounted) {
        setState(() => _bus = _shown(b));
        _publish();
      }
    } catch (_) {}
  }

  Future<void> _locate() async {
    if (_boarded) return; // directions are for getting to the pick-up stop
    setState(() {
      _locating = true;
      _noLoc = false;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('no location');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final me = LatLng(p.latitude, p.longitude);
      final t = _target;
      final w = t == null ? null : await RouteApi.walk(me, t, _targetName);
      if (!mounted) return;
      setState(() {
        _me = me;
        _walk = w;
      });
      _fit();
    } catch (_) {
      if (mounted) setState(() => _noLoc = true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pts = <LatLng>[];
      final t = _target;
      if (t != null) pts.add(t);
      if (_me != null) pts.add(_me!);
      final b = _bus;
      if (b != null && b.running) pts.add(b.pos);
      if (pts.isEmpty) return;
      var minLat = pts.first.latitude, maxLat = pts.first.latitude;
      var minLng = pts.first.longitude, maxLng = pts.first.longitude;
      for (final p in pts) {
        minLat = min(minLat, p.latitude);
        maxLat = max(maxLat, p.latitude);
        minLng = min(minLng, p.longitude);
        maxLng = max(maxLng, p.longitude);
      }
      final span = max(max(maxLat - minLat, (maxLng - minLng) * 0.7), 0.004);
      final zoom = (log(360 / span) / ln2 - 1.3).clamp(6.0, 17.0).toDouble();
      try {
        _mc.move(LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), zoom);
      } catch (_) {}
    });
  }

  // tell the ticket page the latest bus ETA
  void _publish() {
    final n = widget.etaOut;
    if (n == null) return;
    final e = _busEta();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      n.value = e;
    });
  }

  // when the bus reaches your stop, following the road
  _Eta? _busEta() {
    final b = _bus, t = _target;
    if (b == null || t == null) return null;
    if (!b.running && !kDemoBuses) return null;
    if (b.currentSeq >= _targetSeq) return null; // already there / passed
    const d = Distance();
    var m = 0.0;
    if (_road.length >= 2) {
      final i = RoadRoutes.nearestIndex(_road, b.pos);
      final j = RoadRoutes.nearestIndex(_road, t);
      if (j > i) {
        for (var k = i; k < j; k++) {
          m += d.as(LengthUnit.Meter, _road[k], _road[k + 1]);
        }
      } else {
        m = d.as(LengthUnit.Meter, b.pos, t);
      }
    } else {
      m = d.as(LengthUnit.Meter, b.pos, t); // no road path yet: straight line
    }
    final kmh = b.speed >= 10 ? b.speed : 40.0;
    final secs = m / (kmh / 3.6);
    final mins = max(1, (secs / 60).round());
    return _Eta(m, DateTime.now().add(Duration(seconds: secs.round())), mins);
  }

  Widget _col(String big, String small) => Expanded(
    child: Column(
      children: [
        Text(
          big,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        Text(small, style: const TextStyle(color: kMuted, fontSize: 13)),
      ],
    ),
  );

  Widget _etaBlock(String label, IconData icon, Color color, _Eta? e) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (e == null)
            const Text(
              'Not available right now',
              style: TextStyle(color: kMuted, fontSize: 13),
            )
          else
            Row(
              children: [
                _col(_clock12(e.at), 'arrival'),
                _col(
                  e.mins >= 120
                      ? (e.mins / 60).toStringAsFixed(1)
                      : '${e.mins}',
                  e.mins >= 120 ? 'hr' : 'min',
                ),
                _col((e.meters / 1000).toStringAsFixed(1), 'km'),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openMaps() async {
    final t = _target;
    if (t == null) return;
    try {
      await launchUrl(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${t.latitude},${t.longitude}'
          '&travelmode=${_boarded ? 'driving' : 'walking'}',
        ),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Widget _banner() {
    final w = _walk;
    if (w == null || w.steps.isEmpty) return const SizedBox.shrink();
    final s = w.steps.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2433),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(s.icon, size: 40, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              s.text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _map() {
    final b = _bus;
    final t = _target;
    return SizedBox(
      height: 300,
      child: FlutterMap(
        mapController: _mc,
        options: MapOptions(
          initialCenter: t ?? kCenter,
          initialZoom: 14,
          backgroundColor: kBg1,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.my_app1',
          ),
          if (_road.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _road,
                  strokeWidth: 4,
                  color: kGold.withAlpha(150),
                ),
              ],
            ),
          if (_walk != null && _walk!.pts.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _walk!.pts,
                  strokeWidth: 10,
                  color: Colors.white,
                ),
                Polyline(
                  points: _walk!.pts,
                  strokeWidth: 6,
                  color: const Color(0xFF2F7BFF),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (t != null)
                Marker(
                  point: t,
                  width: 36,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Icon(
                      _boarded ? Icons.flag_rounded : Icons.person_pin_circle,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (_me != null)
                Marker(
                  point: _me!,
                  width: 26,
                  height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F7BFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              if (b != null && b.running)
                Marker(
                  point: b.pos,
                  width: 60,
                  height: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: kGoldGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.directions_bus_filled,
                          size: 20,
                          color: kInk,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDD070B14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          b.isLive ? 'LIVE' : b.id,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: b.isLive ? kGood : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _steps() {
    final w = _walk;
    if (w == null || w.steps.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _showSteps = !_showSteps),
            icon: Icon(
              _showSteps
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              _showSteps
                  ? 'Hide directions'
                  : 'Show directions (${w.steps.length} steps)',
            ),
          ),
          if (_showSteps)
            for (final s in w.steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, size: 19, color: kGoldLight),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.text, style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      _distText(s.meters),
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const GlassCard(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(color: kGold)),
        ),
      );
    }
    if (_error != null) return MsgBox(_error!);
    final b = _bus;
    final busEta = _busEta();
    final w = _walk;
    _Eta? walkEta;
    if (w != null) {
      final mins = max(1, (w.seconds / 60).round());
      walkEta = _Eta(
        w.meters,
        DateTime.now().add(Duration(seconds: w.seconds.round())),
        mins,
      );
    }

    // a friendly line comparing your walk with the bus
    String? advice;
    Color adviceColor = kMuted;
    if (!_boarded && b != null) {
      if (!b.running) {
        advice = 'This bus is not running yet.';
      } else if (b.currentSeq >= _targetSeq) {
        advice = 'The bus already reached your stop.';
        adviceColor = kWarn;
      } else if (busEta != null && walkEta != null) {
        final slack = busEta.mins - walkEta.mins;
        if (slack >= 1) {
          advice = 'You will reach the stop about $slack min before the bus.';
          adviceColor = kGood;
        } else {
          advice = 'The bus may reach the stop before you. Hurry!';
          adviceColor = kWarn;
        }
      }
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: kGold.withAlpha(90),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(),
            _map(),
            if (!_boarded)
              _etaBlock(
                w == null ? 'Walk to $_targetName' : 'Walk to $_targetName',
                Icons.directions_walk_rounded,
                const Color(0xFF6FA8FF),
                walkEta,
              ),
            _etaBlock(
              _boarded
                  ? 'Bus reaches $_targetName'
                  : 'Bus reaches your stop (${widget.ticket.pickupName})',
              Icons.directions_bus_filled,
              kGold,
              busEta,
            ),
            if (_noLoc && !_boarded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(
                  'Turn on location to get walking directions to your stop.',
                  style: TextStyle(color: kWarn.withAlpha(230), fontSize: 12),
                ),
              ),
            if (advice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(
                  advice,
                  style: TextStyle(
                    color: adviceColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _steps(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open in Maps'),
                  ),
                  if (!_boarded)
                    TextButton.icon(
                      onPressed: _locating ? null : _locate,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(_locating ? 'Locating...' : 'Update my location'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin > Staff tab: every registered driver and conductor.
/// Uses the admin_staff() function (see admin_staff_setup.sql); if it is not
/// installed yet it falls back to reading the profiles table directly.
class AdminStaff extends StatefulWidget {
  const AdminStaff({super.key});

  @override
  State<AdminStaff> createState() => _AdminStaffState();
}

class _AdminStaffState extends State<AdminStaff> {
  List<Map<String, dynamic>>? _list;
  Map<String, Bus> _buses = {};
  String? _error;
  String _filter = 'all'; // all, driver, conductor
  String _q = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // keep the on-trip / off-duty status live
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      List<Map<String, dynamic>> rows;
      try {
        final res = await _sb.rpc('admin_staff');
        final l = res is List ? res : (jsonDecode('$res') as List);
        rows = l.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        final res = await _sb
            .from('profiles')
            .select()
            .inFilter('role', ['driver', 'conductor']);
        rows = (res as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      final m = <String, Bus>{};
      try {
        for (final b in await Api.buses()) {
          m[b.id] = b;
        }
      } catch (_) {}
      rows.sort((a, b) {
        final r = '${a['role']}'.compareTo('${b['role']}');
        return r != 0
            ? r
            : '${a['full_name']}'.toLowerCase().compareTo(
                '${b['full_name']}'.toLowerCase(),
              );
      });
      if (!mounted) return;
      setState(() {
        _list = rows;
        _buses = m;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '${_msg(e)}\n\nRun admin_staff_setup.sql in Supabase.',
        );
      }
    }
  }

  Widget _chip(String key, String label) {
    final on = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: kGold,
        backgroundColor: kSurface2,
        side: BorderSide(color: on ? kGold : Colors.white12),
        labelStyle: TextStyle(
          color: on ? kInk : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => _filter = key),
      ),
    );
  }

  String _since(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    return d == null ? '' : 'Registered ${_niceDate(d)}';
  }

  Widget _card(Map<String, dynamic> r) {
    final role = '${r['role']}';
    final isDriver = role == 'driver';
    final busId = '${r['bus_id'] ?? ''}'.trim();
    final bus = busId.isEmpty ? null : _buses[busId];
    final email = '${r['email'] ?? ''}'.trim();
    final idNo = '${r['id_number'] ?? ''}'.trim();
    final since = _since('${r['created_at'] ?? ''}');
    // a bus is "on trip" when it is running; shown for its driver and conductor
    final onTrip = bus != null && bus.running;
    final busText = busId.isEmpty
        ? 'No bus assigned'
        : 'Bus $busId${bus == null || bus.route.isEmpty ? '' : ' \u2022 ${bus.route}'}';
    return tileCard(
      icon: isDriver
          ? Icons.directions_bus_filled_rounded
          : Icons.qr_code_scanner_rounded,
      accent: isDriver ? kGold : kGood,
      title: '${r['full_name'] ?? '-'}',
      subtitle: [
        if (email.isNotEmpty) email,
        if (idNo.isNotEmpty) 'ID: $idNo',
        busText,
        if (since.isNotEmpty) since,
      ].join('\n'),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Pill(
            text: isDriver ? 'Driver' : 'Conductor',
            color: isDriver ? kGold : kGood,
          ),
          const SizedBox(height: 6),
          Pill(
            text: onTrip ? 'On trip' : 'Off duty',
            color: onTrip ? kGood : kMuted,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _list;
    if (all == null && _error == null) {
      return const Center(child: CircularProgressIndicator(color: kGold));
    }
    final q = _q.trim().toLowerCase();
    final shown = (all ?? [])
        .where((r) => _filter == 'all' || '${r['role']}' == _filter)
        .where(
          (r) =>
              q.isEmpty ||
              '${r['full_name']} ${r['email']} ${r['bus_id']} ${r['id_number']}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    final drivers = (all ?? []).where((r) => '${r['role']}' == 'driver').length;
    final cond = (all ?? []).where((r) => '${r['role']}' == 'conductor').length;
    final onTripNow = (all ?? []).where((r) {
      final id = '${r['bus_id'] ?? ''}'.trim();
      return id.isNotEmpty && (_buses[id]?.running ?? false);
    }).length;
    return RefreshIndicator(
      color: kGold,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) MsgBox(_error!),
          if (all != null) ...[
            Row(
              children: [
                StatTile(
                  icon: Icons.directions_bus_filled_rounded,
                  value: '$drivers',
                  label: 'Drivers',
                ),
                const SizedBox(width: 10),
                StatTile(
                  icon: Icons.qr_code_scanner_rounded,
                  value: '$cond',
                  label: 'Conductors',
                  color: kGood,
                ),
                const SizedBox(width: 10),
                StatTile(
                  icon: Icons.route_rounded,
                  value: '$onTripNow',
                  label: 'On trip',
                  color: kWarn,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: fieldDeco('Search name, email, bus or ID', Icons.search_rounded),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chip('all', 'All'),
                _chip('driver', 'Drivers'),
                _chip('conductor', 'Conductors'),
              ],
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Center(
                  child: Text(
                    'No registered staff found',
                    style: TextStyle(color: kMuted),
                  ),
                ),
              ),
            ...shown.map(_card),
          ],
        ],
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  final Profile profile;
  const AdminPage({super.key, required this.profile});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>>? _list;
  final Map<String, String> _bus = {}; // chosen starting bus per applicant ('' = none)
  List<Bus> _allBuses = [];
  final Map<String, String> _photo = {};
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Api.adminRequests();
      try {
        _allBuses = await Api.buses();
      } catch (_) {}
      if (!mounted) return;
      for (final r in l) {
        final id = '${r['user_id']}';
        // only pre-select the applicant's bus hint if that bus really exists
        final hint = '${r['bus_hint'] ?? ''}'.trim().toUpperCase();
        _bus.putIfAbsent(
          id,
          () => _allBuses.any((b) => b.id.toUpperCase() == hint)
              ? _allBuses.firstWhere((b) => b.id.toUpperCase() == hint).id
              : '',
        );
        final path = '${r['id_photo_path'] ?? ''}';
        if (path.isNotEmpty && !_photo.containsKey(id)) {
          Api.idPhotoUrl(path).then((u) {
            if (mounted) setState(() => _photo[id] = u);
          }).catchError((_) {});
        }
      }
      setState(() {
        _list = l;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  Future<void> _decide(String id, bool approve) async {
    final bus = approve ? (_bus[id] ?? '') : '';
    if (bus.isNotEmpty && !_allBuses.any((b) => b.id == bus)) {
      setState(() => _error = 'Bus $bus does not exist. Choose a bus from the list.');
      return;
    }
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await Api.adminDecide(id, approve, bus);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _card(Map<String, dynamic> r) {
    final id = '${r['user_id']}';
    final role = '${r['wanted_role']}';
    final passed = '${r['id_check']}' == 'passed';
    final url = _photo[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['full_name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Pill(text: role == 'driver' ? 'Driver' : 'Conductor', color: kGold),
              ],
            ),
            const SizedBox(height: 6),
            kv('Email', '${r['email']}'),
            kv('ID number', '${r['id_number'] ?? '-'}'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Auto check', style: TextStyle(color: kMuted)),
                  Pill(
                    text: passed ? 'Passed' : 'Not checked',
                    color: passed ? kGood : kWarn,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (url != null)
              IdPhotoThumb(url: url, title: '${r['full_name']}')
            else
              const SizedBox(
                height: 60,
                child: Center(
                  child: CircularProgressIndicator(color: kGold, strokeWidth: 2),
                ),
              ),
            const SizedBox(height: 12),
            const Label('STARTING BUS (OPTIONAL, DRIVER CAN CHANGE IT)'),
            PDrop<String>(
              value: _allBuses.any((b) => b.id == _bus[id]) ? _bus[id] : '',
              hint: 'No starting bus',
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('No starting bus'),
                ),
                ..._allBuses.map(
                  (b) => DropdownMenuItem<String>(
                    value: b.id,
                    child: Text(
                      '${b.id} • ${b.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _bus[id] = v ?? ''),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busyId == id ? null : () => _decide(id, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kBad,
                      side: const BorderSide(color: kBad),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GoldButton(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    busy: _busyId == id,
                    onPressed: _busyId == id ? null : () => _decide(id, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    return DefaultTabController(
      length: 4,
      child: BackdropScaffold(
      appBar: premiumBar(
        'Admin',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          _logoutButton(),
        ],
        bottom: premiumTabs(['Applications', 'Discounts', 'Staff', 'Dashboard']),
      ),
      body: TabBarView(
        children: [
      l == null && _error == null
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) MsgBox(_error!),
                if (l != null && l.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'No applications waiting',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                  ),
                if (l != null) ...l.map(_card),
              ],
            ),
          const AdminDiscounts(),
          const AdminStaff(),
          const AdminDashboard(),
        ],
      ),
      ),
    );
  }
}

// decides which screen to show: commuter, conductor or driver
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late Future<Profile> _future = Api.myProfile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Backdrop(
              child: Center(child: CircularProgressIndicator(color: kGold)),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            body: Backdrop(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load your profile.\n${snap.error ?? ''}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      GoldButton(
                        label: 'Try again',
                        onPressed: () =>
                            setState(() => _future = Api.myProfile()),
                      ),
                      TextButton(
                        onPressed: () => _sb.auth.signOut(),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final p = snap.data!;
        // a driver / conductor who signed up but is not approved yet
        final wants = _sb.auth.currentUser?.userMetadata?['wants_role'];
        if ((wants == 'driver' || wants == 'conductor') &&
            p.role != 'driver' &&
            p.role != 'conductor') {
          return StaffApplyPage(
            profile: p,
            role: '$wants',
            onRefresh: () => setState(() => _future = Api.myProfile()),
          );
        }
        return FutureBuilder<bool>(
          future: Api.isAdmin(),
          builder: (context, a) {
            if (a.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Backdrop(
                  child: Center(
                    child: CircularProgressIndicator(color: kGold),
                  ),
                ),
              );
            }
            if (a.data == true) return AdminPage(profile: p);
            return switch (p.role) {
              'driver' => DriverPage(profile: p),
              'conductor' => ConductorPage(profile: p),
              _ => DiscountGate(profile: p, child: CommuterPage(profile: p)),
            };
          },
        );
      },
    );
  }
}

// =====================================================
// AFTER LOG IN / SIGN UP
//   1. "Let's get started" screen
//   2. add a profile picture (can be skipped)
//   3. the profile page lists every bus the passenger reserved
// The photo goes to the public Supabase Storage bucket "avatars" (run
// avatars_setup.sql once) and its link is saved in the user's metadata, so no
// table changes are needed.
// =====================================================

/// LoginPage turns this on right before it logs in / signs up, and AuthGate
/// shows [WelcomeFlow] once, then turns it off again.
bool _showGetStarted = false;

String? _avatarUrl() {
  final v = _sb.auth.currentUser?.userMetadata?['avatar_url'];
  final s = v == null ? '' : '$v';
  return s.isEmpty ? null : s;
}

class AvatarApi {
  static const String bucket = 'avatars';

  /// Uploads the photo, saves its link in the user's metadata and returns it.
  static Future<String> upload(XFile photo, {Uint8List? bytes}) async {
    final uid = _sb.auth.currentUser!.id;
    final data = bytes ?? await photo.readAsBytes();
    if (data.length > 5 * 1024 * 1024) {
      throw Exception('That photo is too big. Please use one under 5 MB.');
    }
    final path = '$uid/avatar.jpg';
    try {
      await _sb.storage
          .from(bucket)
          .uploadBinary(
            path,
            data,
            fileOptions: FileOptions(
              contentType: photo.mimeType ?? 'image/jpeg',
              upsert: true,
            ),
          );
    } catch (e) {
      throw Exception(
        'Could not upload the photo. Run avatars_setup.sql in Supabase '
        '(it creates the "avatars" bucket). ${_msg(e)}',
      );
    }
    final base = _sb.storage.from(bucket).getPublicUrl(path);
    final url = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
    await _sb.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
    return url;
  }
}

/// Round profile picture with a gold ring. Shows the initials when there is
/// no photo yet.
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? url;
  final Uint8List? bytes; // a photo that was just picked (not uploaded yet)
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.url,
    this.bytes,
  });

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: kGold,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
    Widget inner;
    if (bytes != null) {
      inner = Image.memory(bytes!, fit: BoxFit.cover, width: size, height: size);
    } else if (url != null) {
      inner = Image.network(
        url!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      inner = fallback;
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(max(1.5, size * 0.04)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: kGoldGradient,
        boxShadow: [BoxShadow(color: kGold.withAlpha(70), blurRadius: size * 0.25)],
      ),
      child: ClipOval(child: Container(color: kSurface2, child: inner)),
    );
  }
}

Widget _cameraBadge() => Container(
  padding: const EdgeInsets.all(9),
  decoration: BoxDecoration(
    gradient: kGoldGradient,
    shape: BoxShape.circle,
    border: Border.all(color: kBg0, width: 3),
  ),
  child: const Icon(Icons.photo_camera_rounded, size: 18, color: kInk),
);

const TextStyle _eyebrowStyle = TextStyle(
  color: kGold,
  fontSize: 12,
  fontWeight: FontWeight.w800,
  letterSpacing: 3,
);

class WelcomeFlow extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeFlow({super.key, required this.onDone});

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  int _step = 0; // 0 = Let's get started, 1 = profile picture
  bool _busy = false;
  String? _error;
  XFile? _photo;
  Uint8List? _preview;

  String get _fullName =>
      '${_sb.auth.currentUser?.userMetadata?['full_name'] ?? ''}'.trim();
  String get _first => _fullName.isEmpty ? '' : _fullName.split(' ').first;

  void _afterIntro() {
    // someone who already has a picture goes straight in
    if (_avatarUrl() != null) {
      widget.onDone();
    } else {
      setState(() => _step = 1);
    }
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 900,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = x;
        _preview = bytes;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    }
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null) {
      setState(
        () => _error = 'Take or choose a photo first, or tap "Skip for now".',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AvatarApi.upload(photo, bytes: _preview);
      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _msg(e);
        });
      }
    }
  }

  Widget _dots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      2,
      (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: i == _step ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          gradient: i == _step ? kGoldGradient : null,
          color: i == _step ? null : Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  Widget _startStep() => Column(
    key: const ValueKey('start'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Center(child: _LogoHalo()),
      const SizedBox(height: 8),
      const Text('WELCOME', textAlign: TextAlign.center, style: _eyebrowStyle),
      const SizedBox(height: 10),
      const Text(
        "Let's get started",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      Text(
        _first.isEmpty
            ? 'Your account is ready. Set up your profile to track buses, reserve seats and see all your trips in one place.'
            : 'Hi $_first! Your account is ready. Set up your profile to track buses, reserve seats and see all your trips in one place.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: kMuted, fontSize: 15, height: 1.45),
      ),
      const SizedBox(height: 32),
      GoldButton(
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: _afterIntro,
      ),
    ],
  );

  Widget _photoStep() => Column(
    key: const ValueKey('photo'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'YOUR PROFILE',
        textAlign: TextAlign.center,
        style: _eyebrowStyle,
      ),
      const SizedBox(height: 10),
      const Text(
        'Add your profile picture',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'This is how you show up in BusTrack. You can change it any time from your profile.',
        textAlign: TextAlign.center,
        style: TextStyle(color: kMuted, fontSize: 14, height: 1.45),
      ),
      const SizedBox(height: 26),
      Center(
        child: GestureDetector(
          onTap: _busy ? null : () => _pick(ImageSource.gallery),
          child: Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(name: _fullName, size: 150, bytes: _preview),
              Positioned(right: 4, bottom: 4, child: _cameraBadge()),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose photo'),
            ),
          ),
        ],
      ),
      if (_error != null) MsgBox(_error!),
      const SizedBox(height: 18),
      GoldButton(
        label: 'Save and continue',
        icon: Icons.check_rounded,
        busy: _busy,
        onPressed: _busy ? null : _save,
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: _busy ? null : widget.onDone,
        child: const Text('Skip for now'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.97, end: 1).animate(a),
                          child: c,
                        ),
                      ),
                      child: _step == 0 ? _startStep() : _photoStep(),
                    ),
                    const SizedBox(height: 26),
                    _dots(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- PROFILE: picture + every bus the passenger reserved ----------
// "Show on map" closes this page and returns the bus id; the map page then
// selects that bus.
class ProfilePage extends StatefulWidget {
  final Profile profile;
  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Ticket>? _tickets;
  Map<String, Bus> _buses = {};
  String? _error;
  String? _avatar;
  Uint8List? _newBytes; // shown while the new photo uploads
  bool _uploading = false;
  Map<String, dynamic>? _discountReq;

  @override
  void initState() {
    super.initState();
    _avatar = _avatarUrl();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await Api.myTickets();
      final m = <String, Bus>{};
      try {
        for (final b in await Api.buses()) {
          m[b.id] = b;
        }
      } catch (_) {}
      Map<String, dynamic>? dr;
      try {
        dr = await DiscountApi.mine();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _discountReq = dr;
        _tickets = t;
        _buses = m;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    }
  }

  Future<void> _changePhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kBg1,
      shape: _sheetShape,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: kGold),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: kGold),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 900,
        imageQuality: 85,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newBytes = bytes;
        _uploading = true;
        _error = null;
      });
      final url = await AvatarApi.upload(x, bytes: bytes);
      if (!mounted) return;
      setState(() {
        _avatar = url;
        _newBytes = null;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newBytes = null;
        _uploading = false;
        _error = _msg(e);
      });
    }
  }

  Widget _discountCard() {
    final p = widget.profile;
    Widget card(Color c, IconData icon, String text, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        borderColor: c.withAlpha(120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: c),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: kMuted, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
    if (p.type != 'regular') {
      return card(
        kGood,
        Icons.verified_rounded,
        '${typeLabel(p.type)} discount is active. Your fares are discounted.',
      );
    }
    final status = '${_discountReq?['status'] ?? ''}';
    if (status == 'pending') {
      return card(
        kWarn,
        Icons.hourglass_top_rounded,
        'Your discount ID is waiting for approval. You pay the full fare until an admin approves it.',
      );
    }
    return card(
      kGold,
      Icons.local_offer_outlined,
      status == 'rejected'
          ? 'Your last ID was not accepted. Send a clearer one to get your student, senior or PWD discount.'
          : 'Students, seniors and PWD pay less. Confirm your age and send a valid ID.',
      action: OutlinedButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (c) => DiscountApplyPage(
                profile: widget.profile,
                onDone: () => Navigator.pop(c),
              ),
            ),
          );
          _load();
        },
        icon: const Icon(Icons.badge_outlined),
        label: const Text('Verify my ID'),
      ),
    );
  }

  Widget _header() {
    final p = widget.profile;
    final email = _sb.auth.currentUser?.email ?? '';
    return GlassCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: _uploading ? null : _changePhoto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  name: p.name,
                  size: 112,
                  url: _avatar,
                  bytes: _newBytes,
                ),
                if (_uploading)
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: kGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(right: 0, bottom: 0, child: _cameraBadge()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            p.name.trim().isEmpty ? 'Your name' : p.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(email, style: const TextStyle(color: kMuted)),
            ),
          const SizedBox(height: 10),
          Pill(text: '${typeLabel(p.type)} passenger', color: kGold),
          TextButton(
            onPressed: _uploading ? null : _changePhoto,
            child: const Text('Change photo'),
          ),
        ],
      ),
    );
  }

  Widget _ticketRow(Ticket t) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TicketPage(ticket: t)));
      _load();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.pickupName}  >  ${t.dropoffName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${seatLabel(t.seat)}  •  ${peso(t.total)}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(text: statusShort(t.status), color: statusColor(t.status)),
          const Icon(Icons.chevron_right_rounded, color: kMuted, size: 20),
        ],
      ),
    ),
  );

  Widget _busCard(String busId, List<Ticket> list) {
    final bus = _buses[busId];
    final active = list
        .where((t) => t.status == 'reserved' || t.status == 'boarded')
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: active > 0 ? kGold.withAlpha(120) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: kGold.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bus_filled,
                    color: kGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (bus != null)
                        Text(
                          bus.title,
                          style: const TextStyle(color: kGold, fontSize: 12),
                        ),
                      if (bus != null && bus.route.isNotEmpty)
                        Text(
                          bus.route,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
                if (bus != null)
                  Pill(
                    text: bus.running ? 'Running' : 'Not running',
                    color: bus.running ? kGood : kMuted,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _ticketRow(list[i]),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, busId),
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Show on map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _tickets;
    final groups = <String, List<Ticket>>{};
    for (final t in tickets ?? const <Ticket>[]) {
      groups.putIfAbsent(t.busId, () => []).add(t);
    }
    final active = (tickets ?? const <Ticket>[])
        .where((t) => t.status == 'reserved' || t.status == 'boarded')
        .length;

    return BackdropScaffold(
      appBar: premiumBar(
        'My profile',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlide(index: 0, child: _header()),
          const SizedBox(height: 14),
          _discountCard(),
          FadeSlide(
            index: 1,
            child: Row(
              children: [
                StatTile(
                  icon: Icons.confirmation_number_outlined,
                  value: '${tickets?.length ?? 0}',
                  label: 'Reservations',
                ),
                const SizedBox(width: 10),
                StatTile(
                  icon: Icons.directions_bus_filled,
                  value: '${groups.length}',
                  label: 'Buses',
                  color: kGood,
                ),
                const SizedBox(width: 10),
                StatTile(
                  icon: Icons.event_available_rounded,
                  value: '$active',
                  label: 'Active',
                  color: kWarn,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'My reserved buses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${groups.length} bus${groups.length == 1 ? '' : 'es'}',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_error != null) MsgBox(_error!),
          if (tickets == null && _error == null)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: Center(child: CircularProgressIndicator(color: kGold)),
            ),
          if (tickets != null && tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 52,
                    color: kMuted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No reserved buses yet.\nReserve a seat and the bus shows up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted),
                  ),
                ],
              ),
            ),
          for (final e in groups.entries) _busCard(e.key, e.value),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () {
              // this page sits on top of the app, so close it before logging out
              Navigator.of(context).popUntil((r) => r.isFirst);
              _sb.auth.signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

Widget _logoutButton() => IconButton(
  tooltip: 'Log out',
  icon: const Icon(Icons.logout_rounded),
  onPressed: () => _sb.auth.signOut(),
);

Widget _noBus() => const Center(
  child: Padding(
    padding: EdgeInsets.all(24),
    child: Text(
      'This account has no bus yet. Ask the admin to assign one.',
      textAlign: TextAlign.center,
      style: TextStyle(color: kMuted),
    ),
  ),
);

const RoundedRectangleBorder _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

// =====================================================
// COMMUTER
// =====================================================
class CommuterPage extends StatefulWidget {
  final Profile profile;
  const CommuterPage({super.key, required this.profile});

  @override
  State<CommuterPage> createState() => _CommuterPageState();
}

class _CommuterPageState extends State<CommuterPage> {
  // taken-seat counts per bus, refreshed at most every 15 s
  final Map<String, int> _seatCount = {}; // seated passengers
  final Map<String, int> _standCount = {}; // standing passengers
  final Map<String, DateTime> _seatAt = {};

  void _ensureSeats(Bus b) {
    final last = _seatAt[b.id];
    if (last != null && DateTime.now().difference(last).inSeconds < 15) return;
    _seatAt[b.id] = DateTime.now();
    Api.takenSeats(b.id)
        .then((s) {
          if (!mounted) return;
          setState(() {
            _seatCount[b.id] = seatedCount(s);
            _standCount[b.id] = standingCount(s);
          });
        })
        .catchError((_) {});
  }

  final MapController _map = MapController();
  List<Ticket> _myTickets = [];
  List<Bus> _raw = []; // buses exactly as stored in the database
  final Map<String, List<double>> _cumCache = {};
  final Map<String, List<double>> _stopCumCache = {};
  Timer? _simTimer;

  // what the screens use: the demo fleet moves, real drivers stay real
  List<Bus> get _buses => kSimFleet ? _raw.map(_simBus).toList() : _raw;

  List<double> _cumOf(String routeId, List<LatLng> line) {
    final c = _cumCache[routeId];
    if (c != null && c.length == line.length) return c;
    const d = Distance();
    final out = <double>[0];
    for (var i = 1; i < line.length; i++) {
      out.add(out.last + d.as(LengthUnit.Meter, line[i - 1], line[i]));
    }
    _cumCache[routeId] = out;
    _stopCumCache.remove(routeId);
    return out;
  }

  Bus _simBus(Bus b) {
    // a driver phone is sending GPS right now: show exactly where it is
    if (isDriverLive(b)) return b.asLive();
    if (b.routeId.isEmpty) return b;
    final line = _roads[b.routeId];
    final stops = _routeStops[b.routeId];
    if (line == null || line.length < 2 || stops == null || stops.isEmpty) {
      return b;
    }
    return simulateFleetBus(b, line, stops);
  }

  List<Stop> _selStops = [];
  String? _error;
  DateTime? _updated;
  String? _selectedId;
  Timer? _timer;

  // real road paths, keyed by route id
  final Map<String, List<LatLng>> _roads = {};
  final Map<String, List<Stop>> _routeStops = {};
  List<Map<String, dynamic>> _routeList = [];
  String? _filterRoute; // null = all routes
  StreamSubscription<List<Map<String, dynamic>>>? _live;
  bool _follow = true; // keep the map on the selected bus

  @override
  void initState() {
    super.initState();
    _load();
    _loadRoads();
    _timer = Timer.periodic(kRefresh, (_) => _load());
    // move the demo fleet and keep the camera on the selected bus
    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !kSimFleet) return;
      setState(() {});
      _checkAlerts();
      final sel = _selectedBus;
      if (_follow && sel != null && sel.running) {
        try {
          _map.move(sel.pos, _map.camera.zoom);
        } catch (_) {}
      }
    });
    _listenLive();
  }

  // Instant bus positions from Supabase Realtime (falls back to polling).
  void _listenLive() {
    try {
      _live = _sb.from('buses').stream(primaryKey: ['id']).listen((rows) {
        if (!mounted) return;
        final list = rows.map((j) => Bus.fromRow(j)).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
        setState(() {
          _raw = list;
          _error = null;
          _updated = DateTime.now();
        });
        final sel = _selectedBus;
        if (_follow && sel != null && sel.running) {
          _map.move(sel.pos, _map.camera.zoom);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  // Fetches every route's stops, then the road path through them.
  Future<void> _loadRoads() async {
    try {
      final routes = await Api.routes();
      if (!mounted) return;
      setState(() => _routeList = routes);
      for (final r in routes) {
        final id = '${r['id']}';
        try {
          final stops = await Api.stops(id);
          if (stops.length < 2) continue;
          _routeStops[id] = stops;
          final line = await RoadRoutes.fetch(
            id,
            stops.map((s) => s.pos).toList(),
          );
          if (!mounted) return;
          setState(() => _roads[id] = line);
        } catch (_) {}
      }
    } catch (_) {}
  }

  // moves the map so a whole route is visible
  void _fitPoints(List<LatLng> pts) {
    if (pts.isEmpty) return;
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    final span = max(max(maxLat - minLat, (maxLng - minLng) * 0.7), 0.01);
    final zoom = (log(360 / span) / ln2 - 1.0).clamp(5.0, 14.0);
    _map.move(LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), zoom);
  }

  void _pickRoute(String? id) {
    setState(() {
      _filterRoute = id;
      if (id != null) {
        _selectedId = null;
        _selStops = _routeStops[id] ?? [];
      } else {
        _selStops = [];
      }
    });
    if (id == null) {
      _map.move(kCenter, kZoom);
    } else {
      _fitPoints(
        _roads[id] ?? (_routeStops[id] ?? []).map((s) => s.pos).toList(),
      );
    }
  }

  String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Bus? get _selectedBus {
    for (final b in _buses) {
      if (b.id == _selectedId) return b;
    }
    return null;
  }

  List<Bus> get _shownBuses => _filterRoute == null
      ? _buses
      : _buses.where((b) => b.routeId == _filterRoute).toList();

  // km by road and rough minutes to the next stop
  ({Stop? next, double km, int mins})? _nextInfo(Bus b) {
    final stops = _routeStops[b.routeId];
    if (stops == null || stops.isEmpty) return null;
    final nx = stops.where((s) => s.seq == b.currentSeq + 1).toList();
    if (nx.isEmpty) return (next: null, km: 0, mins: 0);
    final line = _roads[b.routeId] ?? const <LatLng>[];
    final km = RoadRoutes.kmAlong(line, b.pos, nx.first.pos);
    final mins = b.speed >= 5 ? (km / b.speed * 60).round() : -1;
    return (next: nx.first, km: km, mins: mins);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _live?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    try {
      final t = await Api.myTickets();
      if (mounted) setState(() => _myTickets = t);
    } catch (_) {}
  }

  Future<void> _load() async {
    _loadTickets();
    try {
      final buses = await Api.buses();
      if (!mounted) return;
      setState(() {
        _raw = buses;
        _error = null;
        _updated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Cannot reach server: ${_msg(e)}');
    }
  }

  Future<void> _select(Bus b) async {
    setState(() => _selectedId = b.id);
    // a bus that never sent GPS sits at 0,0 (open ocean): don't jump there
    if (b.pos.latitude.abs() > 0.01 || b.pos.longitude.abs() > 0.01) {
      _map.move(b.pos, 11);
    }
    if (b.routeId.isEmpty) return;
    try {
      final s = _routeStops[b.routeId] ?? await Api.stops(b.routeId);
      _routeStops[b.routeId] = s;
      if (mounted && _selectedId == b.id) setState(() => _selStops = s);
      final line =
          _roads[b.routeId] ??
          await RoadRoutes.fetch(b.routeId, s.map((x) => x.pos).toList());
      if (!mounted || _selectedId != b.id) return;
      setState(() => _roads[b.routeId] = line);
      _fitPoints(line);
    } catch (_) {}
  }

  void _openAsk() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AssistantPage(profile: widget.profile, getBuses: () => _buses),
      ),
    );
  }

  // ---- in-app trip alerts: one pop-up per event, per ticket ----
  final Set<String> _alerted = {};

  void _alert(String key, IconData icon, String text) {
    if (!_alerted.add(key) || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Row(
            children: [
              Icon(icon, color: kGold),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  void _checkAlerts() {
    for (final t in _myTickets) {
      if (t.status != 'reserved' && t.status != 'boarded') continue;
      Bus? bus;
      for (final b in _buses) {
        if (b.id == t.busId) bus = b;
      }
      if (bus == null || !bus.running) continue;
      if (t.status == 'reserved') {
        if (bus.currentSeq >= t.pickupSeq) {
          _alert(
            '${t.id}:passed',
            Icons.warning_amber_rounded,
            'Bus ${t.busId} passed your pick-up point (${t.pickupName}).',
          );
        } else if (bus.currentSeq == t.pickupSeq - 1) {
          _alert(
            '${t.id}:near',
            Icons.directions_bus_filled,
            'Bus ${t.busId} is almost at ${t.pickupName}. Get ready to board!',
          );
        }
      } else if (bus.currentSeq == t.dropoffSeq - 1) {
        _alert(
          '${t.id}:drop',
          Icons.flag_rounded,
          'Your stop, ${t.dropoffName}, is next. Get ready to get off.',
        );
      }
    }
  }

  Future<void> _openProfile() async {
    final busId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProfilePage(profile: widget.profile)),
    );
    if (!mounted) return;
    setState(() {}); // new profile picture
    _loadTickets();
    if (busId == null) return;
    for (final b in _buses) {
      if (b.id == busId) {
        _select(b);
        break;
      }
    }
  }

  Future<void> _reserve(Bus b) async {
    var prof = widget.profile;
    try {
      prof = await Api.myProfile(); // picks up a newly approved discount
    } catch (_) {}
    if (!mounted) return;
    final t = await showModalBottomSheet<Ticket>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: kBg1,
      shape: _sheetShape,
      builder: (_) => ReserveSheet(bus: b, profile: prof),
    );
    if (t == null || !mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => TicketPage(ticket: t)));
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  // red pins for the passenger's own reservations: where to get on and off
  List<Marker> _myPins() {
    final out = <Marker>[];
    for (final t in _myTickets) {
      if (t.status != 'reserved' && t.status != 'boarded') continue;
      Bus? bus;
      for (final b in _raw) {
        if (b.id == t.busId) bus = b;
      }
      final stops = bus == null ? null : _routeStops[bus.routeId];
      LatLng? stopPos(int seq) {
        if (stops == null) return null;
        for (final x in stops) {
          if (x.seq == seq) return x.pos;
        }
        return null;
      }

      if (t.status == 'reserved') {
        final at = t.pickupPin ?? stopPos(t.pickupSeq);
        if (at != null) out.add(redPinMarker(at, 'Your pick-up'));
      }
      final to = t.dropoffPin ?? stopPos(t.dropoffSeq);
      if (to != null) {
        out.add(redPinMarker(to, 'Your drop-off', icon: Icons.flag_rounded));
      }
    }
    return out;
  }

  Widget _busMarker(Bus b) {
    final selected = b.id == _selectedId;
    return GestureDetector(
      onTap: () => _select(b),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseRing(
            active: b.running,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: b.running ? kGoldGradient : null,
                color: b.running ? null : kSurface2,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (b.running ? kGold : Colors.black).withAlpha(
                      selected ? 190 : 80,
                    ),
                    blurRadius: selected ? 22 : 8,
                    spreadRadius: selected ? 3 : 0,
                  ),
                ],
              ),
              child: Icon(
                Icons.directions_bus_filled,
                size: 20,
                color: b.running ? kInk : kMuted,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xDD070B14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              b.id,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapView() {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kGold.withAlpha(160), kGold.withAlpha(20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.5),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: const MapOptions(
                initialCenter: kCenter,
                initialZoom: kZoom,
                backgroundColor: kBg1,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.my_app1',
                ),
                // real road paths: every route faint, the active one bold
                PolylineLayer(polylines: _roadLines()),
                // stops of the selected bus
                MarkerLayer(
                  markers: _selStops
                      .map(
                        (s) => Marker(
                          point: s.pos,
                          width: 100,
                          height: 36,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, size: 10, color: kGold),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xDD070B14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 9),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                // my reserved pick-up / drop-off pins
                MarkerLayer(markers: _myPins()),
                // buses
                MarkerLayer(
                  markers: _shownBuses
                      .where(
                        (b) =>
                            b.pos.latitude.abs() > 0.01 ||
                            b.pos.longitude.abs() > 0.01,
                      )
                      .map(
                        (b) => Marker(
                          point: b.pos,
                          width: 70,
                          height: 64,
                          child: _busMarker(b),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            // live chip
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xDD070B14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _updated == null ? kMuted : kGood,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _updated == null
                          ? 'Connecting...'
                          : 'Live • ${_time(_updated!)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            // zoom + recenter controls
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _mapBtn(
                    Icons.add,
                    () => _map.move(_map.camera.center, _map.camera.zoom + 1),
                  ),
                  const SizedBox(height: 8),
                  _mapBtn(
                    Icons.remove,
                    () => _map.move(_map.camera.center, _map.camera.zoom - 1),
                  ),
                  const SizedBox(height: 8),
                  _mapBtn(Icons.my_location_rounded, _recenter),
                  const SizedBox(height: 8),
                  _mapBtn(
                    _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                    () => setState(() => _follow = !_follow),
                  ),
                ],
              ),
            ),
            // selected bus info
            if (_selectedBus != null)
              Positioned(
                left: 10,
                right: 58,
                bottom: 22,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _selectedInfo(_selectedBus!),
                  ),
                ),
              ),
            const Positioned(
              right: 8,
              bottom: 6,
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- map helpers -----
  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xDD070B14),
        shape: BoxShape.circle,
        border: Border.all(color: kGoldDark.withAlpha(140)),
      ),
      child: Icon(icon, size: 19, color: kGoldLight),
    ),
  );

  void _recenter() {
    final b = _selectedBus;
    if (b != null) {
      final line = _roads[b.routeId];
      if (line != null) {
        _fitPoints(line);
        return;
      }
      _map.move(b.pos, 12);
      return;
    }
    if (_filterRoute != null && _roads[_filterRoute] != null) {
      _fitPoints(_roads[_filterRoute]!);
      return;
    }
    _map.move(kCenter, kZoom);
  }

  List<Polyline> _roadLines() {
    final active = _selectedBus?.routeId ?? _filterRoute;
    final out = <Polyline>[];

    // inactive routes first, so the active one is drawn on top
    _roads.forEach((id, line) {
      if (id == active) return;
      if (_filterRoute != null && id != _filterRoute) return;
      out.add(
        Polyline(
          points: line,
          strokeWidth: 4,
          color: const Color(0xFF2F6BFF).withAlpha(150),
        ),
      );
    });

    if (active != null && _roads[active] != null) {
      final line = _roads[active]!;
      // dark casing, then gold line
      out.add(
        Polyline(points: line, strokeWidth: 9, color: kBg0.withAlpha(200)),
      );
      out.add(Polyline(points: line, strokeWidth: 5, color: kGold));
      // part the bus has already driven
      final b = _selectedBus;
      if (b != null && b.running && line.length > 2) {
        final i = RoadRoutes.nearestIndex(line, b.pos);
        if (i > 1) {
          out.add(
            Polyline(
              points: line.sublist(0, i + 1),
              strokeWidth: 5,
              color: kMuted.withAlpha(200),
            ),
          );
        }
      }
    }
    return out;
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _dur(int mins) =>
      mins >= 60 ? '${mins ~/ 60} h ${mins % 60} min' : '$mins min';

  Widget _infoChip(IconData icon, String text, {Color color = kGoldLight}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(90)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  // arrival estimates: end of the route, and the passenger's own stop
  List<Widget> _liveChips(Bus b, List<Stop> stops) {
    final out = <Widget>[];
    if (!b.running || stops.isEmpty) return out;
    final line = _roads[b.routeId] ?? const <LatLng>[];
    final moving = b.speed >= 5;

    String eta(double km) {
      if (!moving) return 'waiting for speed';
      final m = (km / b.speed * 60).round();
      return '${_clock(DateTime.now().add(Duration(minutes: m)))} (${_dur(m)})';
    }

    // my ticket on this bus
    for (final t in _myTickets) {
      if (t.busId != b.id) continue;
      if (t.status != 'reserved' && t.status != 'boarded') continue;
      final seq = t.status == 'reserved' ? t.pickupSeq : t.dropoffSeq;
      final stop = stops.where((x) => x.seq == seq).toList();
      if (stop.isEmpty) continue;
      final label = t.status == 'reserved' ? 'Your pick-up' : 'Your stop';
      if (b.currentSeq >= seq) {
        out.add(_infoChip(Icons.check_circle_outline, '$label ${stop.first.name}: passed', color: kWarn));
      } else {
        final km = RoadRoutes.kmAlong(line, b.pos, stop.first.pos);
        out.add(_infoChip(Icons.person_pin_circle_rounded, '$label ${stop.first.name} • ${km.toStringAsFixed(1)} km • ${eta(km)}', color: kGood));
      }
      break;
    }

    final last = stops.last;
    final kmLeft = RoadRoutes.kmAlong(line, b.pos, last.pos);
    out.add(_infoChip(Icons.flag_rounded, 'Arrives ${last.name}: ${eta(kmLeft)}'));
    out.add(_infoChip(Icons.route_rounded, '${kmLeft.toStringAsFixed(1)} km left'));
    final left = stops.where((x) => x.seq > b.currentSeq).length;
    out.add(_infoChip(Icons.pin_drop_outlined, '$left stop${left == 1 ? '' : 's'} left'));
    final taken = _seatCount[b.id];
    if (taken != null) {
      final free = kSeats - taken;
      out.add(_infoChip(Icons.event_seat_rounded, free > 0 ? '$free seats free' : 'Full', color: free > 0 ? kGood : kBad));
    }
    return out;
  }

  Widget _selectedInfo(Bus b) {
    final info = _nextInfo(b);
    final stops = _routeStops[b.routeId] ?? const <Stop>[];
    final total = stops.length <= 1 ? 1 : stops.length - 1;
    final done = (b.currentSeq - 1).clamp(0, total);
    String nextTxt;
    if (!b.running) {
      nextTxt = 'Not running right now';
    } else if (info == null) {
      nextTxt = 'Loading route...';
    } else if (info.next == null) {
      nextTxt = 'Near the end of the route';
    } else {
      final eta = info.mins < 0 ? 'stopped' : '~${info.mins} min';
      nextTxt =
          'Next: ${info.next!.name} • ${info.km.toStringAsFixed(1)} km • $eta';
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 230),
      child: SingleChildScrollView(
        child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xEE070B14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withAlpha(110)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_filled, size: 16, color: kGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${b.id}  •  ${b.title}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (b.isLive)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill(text: 'LIVE DRIVER', color: kGood),
                ),
              if (b.running)
                Text(
                  '${b.speed.toStringAsFixed(0)} km/h',
                  style: const TextStyle(color: kGoldLight, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            b.route.isEmpty ? 'No route' : b.route,
            style: const TextStyle(color: kGoldLight, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(nextTxt, style: const TextStyle(color: kMuted, fontSize: 12)),
          if (_liveChips(b, stops).isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _liveChips(b, stops)),
          ],
          const SizedBox(height: 6),
          Text(
            'GPS ${b.pos.latitude.toStringAsFixed(5)}, ${b.pos.longitude.toStringAsFixed(5)}'
            '${b.ageSeconds == null ? '' : ' • updated ${b.ageSeconds}s ago'}',
            style: const TextStyle(color: kMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: b.running ? done / total : 0,
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: kGold,
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }

  // horizontally scrolling route filter
  Widget _routeChips() {
    if (_routeList.isEmpty) return const SizedBox.shrink();
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: kGold,
        backgroundColor: kSurface2,
        side: BorderSide(color: on ? kGold : Colors.white12),
        labelStyle: TextStyle(
          color: on ? kInk : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        onSelected: (_) => tap(),
      ),
    );
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All routes', _filterRoute == null, () => _pickRoute(null)),
          for (final r in _routeList)
            chip(
              '${r['name']}',
              _filterRoute == '${r['id']}',
              () => _pickRoute('${r['id']}'),
            ),
        ],
      ),
    );
  }

  Widget _busCard(Bus b) {
    final sel = b.id == _selectedId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderColor: sel ? kGold : (b.running ? kGood.withAlpha(100) : null),
        padding: const EdgeInsets.all(14),
        onTap: () => _select(b),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (b.running ? kGold : kMuted).withAlpha(30),
              ),
              child: Icon(
                Icons.directions_bus_filled,
                color: b.running ? kGold : kMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    b.title,
                    style: const TextStyle(color: kGold, fontSize: 12),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.alt_route_rounded,
                        size: 13,
                        color: kMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.route.isEmpty ? 'No route yet' : b.route,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (b.running && _nextInfo(b)?.next != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Next: ${_nextInfo(b)!.next!.name}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kGoldLight, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Pill(
                        text: b.running ? 'Running' : 'Not running',
                        color: b.running ? kGood : kMuted,
                      ),
                      if (b.running) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${b.speed.toStringAsFixed(0)} km/h',
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  if (b.running || kDemoBuses)
                    Builder(
                      builder: (context) {
                        _ensureSeats(b);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OccupancyBar(
                            taken: _seatCount[b.id] ?? 0,
                            total: kSeats,
                            standingTaken: _standCount[b.id] ?? 0,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            GoldButton(
              label: 'Reserve',
              compact: true,
              // demo: every bus can be reserved, even when it is not running
              onPressed: (b.running || kDemoBuses) ? () => _reserve(b) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final name = p.name.trim();
    final first = name.isEmpty ? 'there' : name.split(' ').first;

    return BackdropScaffold(
      appBar: premiumBar(
        'BusTrack',
        brand: true,
        actions: [
          IconButton(
            tooltip: 'My profile',
            icon: UserAvatar(name: p.name, size: 32, url: _avatarUrl()),
            onPressed: _openProfile,
          ),
          IconButton(
            tooltip: 'My tickets',
            icon: const Icon(Icons.confirmation_number_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TicketsPage())),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          _logoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAsk,
        backgroundColor: kGold,
        foregroundColor: kInk,
        elevation: 8,
        icon: const Icon(Icons.auto_awesome),
        label: const Text(
          'Ask BusTrack',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greet()}, $first',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Where are you riding today?',
                        style: TextStyle(color: kMuted),
                      ),
                    ],
                  ),
                ),
                const WeatherChip(),
                if (p.type != 'regular') ...[
                  const SizedBox(width: 8),
                  Pill(text: '${typeLabel(p.type)} fare', color: kGold),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                StatTile(
                  icon: Icons.directions_bus_filled,
                  value: '${_buses.where((b) => b.running).length}',
                  label: 'Buses running',
                  color: kGood,
                ),
                const SizedBox(width: 10),
                StatTile(
                  icon: Icons.alt_route_rounded,
                  value: '${_routeList.length}',
                  label: 'Routes',
                ),
                const SizedBox(width: 10),
                StatTile(
                  icon: Icons.speed_rounded,
                  value: _selectedBus?.running == true
                      ? '${_selectedBus!.speed.toStringAsFixed(0)} km/h'
                      : '--',
                  label: 'Selected bus',
                  color: const Color(0xFF2F6BFF),
                ),
              ],
            ),
          ),
          _routeChips(),
          if (_routeList.isNotEmpty) const SizedBox(height: 10),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _mapView(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MsgBox(_error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Available buses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${_shownBuses.where((b) => b.running).length} running • ${_shownBuses.length} total',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _shownBuses.isEmpty
                ? Center(
                    child: Text(
                      _filterRoute == null
                          ? 'No buses found'
                          : 'No buses on this route yet',
                      style: const TextStyle(color: kMuted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    children: [
                      for (var i = 0; i < _shownBuses.length; i++)
                        FadeSlide(index: i, child: _busCard(_shownBuses[i])),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- TYPE-TO-SEARCH PLACE PICKER ----------
// The passenger can type a stop name, or any place in the Philippines. For a
// typed place we look it up on OpenStreetMap and pick the NEAREST stop of the
// bus route, so the fare is still worked out from real stops.
class _Place {
  final String title;
  final String subtitle;
  final Stop stop;
  final double km;
  _Place(this.title, this.subtitle, this.stop, this.km);
}

String _fold(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class StopPicker extends StatefulWidget {
  
  final String hint;
  final String disabledHint;
  final List<Stop> stops; // stops that can be chosen right now
  final List<Stop> routeStops; // every stop of the route (for the map search)
  final int? value; // chosen stop number
  final String? note; // e.g. "Nearest stop to SM Lanang • 2.1 km away"
  final bool enabled;
  final void Function(int seq, String? note) onChanged;
  final VoidCallback onCleared;

  const StopPicker({
    super.key,
    required this.hint,
    required this.stops,
    required this.routeStops,
    required this.value,
    required this.onChanged,
    required this.onCleared,
    this.note,
    this.enabled = true,
    this.disabledHint = '',
  });

  @override
  State<StopPicker> createState() => _StopPickerState();
}

class _StopPickerState extends State<StopPicker> {
  final TextEditingController _t = TextEditingController();
  final FocusNode _f = FocusNode();
  bool _open = false;
  bool _busy = false;
  bool _editing = false;
  String? _err;
  List<_Place> _places = [];

  String? _nameOf(int? seq) {
    if (seq == null) return null;
    for (final s in widget.routeStops) {
      if (s.seq == seq) return s.name;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _t.text = _nameOf(widget.value) ?? '';
    _f.addListener(() {
      if (_f.hasFocus && widget.enabled && mounted) {
        setState(() => _open = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant StopPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final n = _nameOf(widget.value);
      if (n != null) {
        _t.text = n;
      } else if (!_editing) {
        _t.clear();
        _places = [];
        _err = null;
      }
    }
    _editing = false;
    if (!widget.enabled && _open) _open = false;
  }

  @override
  void dispose() {
    _t.dispose();
    _f.dispose();
    super.dispose();
  }

  void _onText(String v) {
    final sel = _nameOf(widget.value);
    if (sel != null && v != sel) {
      _editing = true;
      widget.onCleared();
    }
    setState(() {
      _open = true;
      _err = null;
      _places = [];
    });
  }

  void _clear() {
    _t.clear();
    final had = widget.value != null;
    setState(() {
      _places = [];
      _err = null;
      _open = true;
    });
    if (had) {
      _editing = true;
      widget.onCleared();
    }
    _f.requestFocus();
  }

  void _choose(Stop s, String? note) {
    _t.text = s.name;
    setState(() {
      _open = false;
      _places = [];
      _err = null;
    });
    _f.unfocus();
    widget.onChanged(s.seq, note);
  }

  Future<void> _search() async {
    final q = _t.text.trim();
    if (q.length < 2 || widget.stops.isEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
      _places = [];
    });
    try {
      final params = <String, String>{
        'q': q,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'ph',
      };
      if (widget.routeStops.isNotEmpty) {
        // prefer results around the route (not a hard limit)
        final lats = widget.routeStops.map((s) => s.pos.latitude);
        final lngs = widget.routeStops.map((s) => s.pos.longitude);
        final minLat = lats.reduce(min) - 0.6, maxLat = lats.reduce(max) + 0.6;
        final minLng = lngs.reduce(min) - 0.6, maxLng = lngs.reduce(max) + 0.6;
        params['viewbox'] = '$minLng,$maxLat,$maxLng,$minLat';
      }
      final res = await http
          .get(Uri.https('nominatim.openstreetmap.org', '/search', params))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('search ${res.statusCode}');
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;

      const dist = Distance();
      final found = <_Place>[];
      for (final j in list) {
        final lat = double.tryParse('${j['lat']}');
        final lon = double.tryParse('${j['lon']}');
        if (lat == null || lon == null) continue;
        final at = LatLng(lat, lon);
        Stop? best;
        var bestKm = double.infinity;
        for (final s in widget.stops) {
          final km = dist.as(LengthUnit.Kilometer, at, s.pos);
          if (km < bestKm) {
            bestKm = km;
            best = s;
          }
        }
        if (best == null) continue;
        final display = '${j['display_name'] ?? ''}';
        final nm = '${j['name'] ?? ''}'.trim();
        final title = nm.isNotEmpty ? nm : display.split(',').first.trim();
        var sub = display;
        if (sub.length > 70) sub = '${sub.substring(0, 70)}...';
        found.add(_Place(title, sub, best, bestKm));
      }
      found.sort((a, b) => a.km.compareTo(b.km));
      if (!mounted) return;
      setState(() {
        _places = found.take(5).toList();
        _busy = false;
        if (found.isEmpty) {
          _err = 'No place found for "$q". Try another spelling.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = 'Could not search places right now. Please pick a stop from the list.';
      });
    }
  }

  Widget _hdr(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
    child: Text(
      t,
      style: const TextStyle(
        color: kMuted,
        fontSize: 10.5,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    bool selected = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) => Material(
    color: selected ? kGold.withAlpha(24) : Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? kGold : kGoldLight),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    ),
  );

  Widget _panel() {
    final raw = _t.text.trim();
    final q = raw.toLowerCase();
    final sel = _nameOf(widget.value)?.toLowerCase();
    final showAll = q.isEmpty || q == sel;
    final matches = widget.stops
              .where((s) => showAll || _fold(s.name).contains(_fold(q)))
        .toList();

    final kids = <Widget>[];
    kids.add(_hdr('STOPS ON THIS ROUTE'));
    if (matches.isEmpty) {
      kids.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Text(
            'No stop named "$raw" on this route.',
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
        ),
      );
    }
    for (final s in matches) {
      kids.add(
        _row(
          icon: Icons.location_on_outlined,
          title: s.name,
          selected: s.seq == widget.value,
          onTap: () => _choose(s, null),
        ),
      );
    }
    if (!showAll && raw.length >= 2) {
      kids.add(const Divider(height: 8, color: Colors.white12));
      kids.add(
        _row(
          icon: Icons.travel_explore_rounded,
          title: 'Search "$raw" on the map',
          subtitle: 'Finds any place and picks the nearest stop',
          trailing: _busy
              ? const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kGold,
                    ),
                  ),
                )
              : null,
          onTap: _busy ? null : _search,
        ),
      );
    }
    if (_err != null) {
      kids.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Text(
            _err!,
            style: const TextStyle(color: kWarn, fontSize: 12),
          ),
        ),
      );
    }
    if (_places.isNotEmpty) {
      kids.add(_hdr('PLACES FOUND'));
      for (final p in _places) {
        final far = p.km > 15;
        kids.add(
          _row(
            icon: Icons.place_rounded,
            title: p.title,
            subtitle:
                '${p.subtitle}\nNearest stop: ${p.stop.name} • ${p.km.toStringAsFixed(1)} km away${far ? ' (far from the route)' : ''}',
            onTap: () => _choose(
              p.stop,
              'Nearest stop to "${p.title}" • ${p.km.toStringAsFixed(1)} km away',
            ),
          ),
        );
      }
    }

    // taps inside the list must not count as "tap outside" for the text box
    return TextFieldTapRegion(
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: kids,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white12),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _t,
          focusNode: _f,
          enabled: widget.enabled,
          onChanged: _onText,
          onTap: () => setState(() => _open = true),
          onTapOutside: (_) {
            if (_open) setState(() => _open = false);
          },
          onSubmitted: (_) {
            final q = _t.text.trim().toLowerCase();
            final m = widget.stops
.where((s) => _fold(s.name).contains(_fold(q)))
                .toList();
            if (m.length == 1) {
              _choose(m.first, null);
            } else if (m.isEmpty) {
              _search();
            }
          },
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: widget.enabled ? widget.hint : widget.disabledHint,
            hintStyle: const TextStyle(color: kMuted),
            filled: true,
            fillColor: kSurface,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: kGold,
              size: 20,
            ),
            suffixIcon: _t.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: kMuted,
                      size: 20,
                    ),
                    onPressed: _clear,
                  )
                : const Icon(Icons.arrow_drop_down, color: kGold),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kGold, width: 1.4),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: (_open && widget.enabled)
              ? _panel()
              : const SizedBox(width: double.infinity),
        ),
        if (widget.note != null && widget.value != null && !_open)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 13, color: kGoldLight),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.note!,
                    style: const TextStyle(color: kGoldLight, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Red map pin with a small label under it. The tip of the pin sits exactly
// on the coordinate.
Marker redPinMarker(
  LatLng p,
  String label, {
  IconData icon = Icons.location_on_rounded,
}) => Marker(
  point: p,
  width: 150,
  height: 100,
  child: Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      Transform.translate(
        offset: const Offset(0, -18),
        child: Icon(
          icon,
          size: 38,
          color: kBad,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      Positioned(
        top: 54,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xEE070B14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBad.withAlpha(140)),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  ),
);

class PinResult {
  final LatLng pos;
  final Stop stop; // nearest stop of the route, used to work out the fare
  final double km;
  PinResult(this.pos, this.stop, this.km);
}

/// Full-screen map: tap anywhere to drop a red pin where you get on or off.
class PinPickerPage extends StatefulWidget {
  final String title;
  final List<Stop> stops; // stops that can be chosen
  final List<Stop> routeStops; // whole route (for the first view)
  final LatLng? initial;
  const PinPickerPage({
    super.key,
    required this.title,
    required this.stops,
    required this.routeStops,
    this.initial,
  });

  @override
  State<PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<PinPickerPage> {
  final MapController _mc = MapController();
  LatLng? _pin;
  Stop? _near;
  double _km = 0;
  bool _locating = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) _compute(i);
  }

  void _compute(LatLng p) {
    const d = Distance();
    Stop? best;
    var bk = double.infinity;
    for (final s in widget.stops) {
      final k = d.as(LengthUnit.Kilometer, p, s.pos);
      if (k < bk) {
        bk = k;
        best = s;
      }
    }
    _pin = p;
    _near = best;
    _km = bk;
  }

  void _place(LatLng p) => setState(() {
    _compute(p);
    _err = null;
  });

  (LatLng, double) _view() {
    final i = widget.initial;
    if (i != null) return (i, 15);
    final pts = widget.routeStops.isNotEmpty ? widget.routeStops : widget.stops;
    if (pts.isEmpty) return (kCenter, kZoom);
    var minLat = pts.first.pos.latitude, maxLat = minLat;
    var minLng = pts.first.pos.longitude, maxLng = minLng;
    for (final s in pts) {
      minLat = min(minLat, s.pos.latitude);
      maxLat = max(maxLat, s.pos.latitude);
      minLng = min(minLng, s.pos.longitude);
      maxLng = max(maxLng, s.pos.longitude);
    }
    final span = max(max(maxLat - minLat, (maxLng - minLng) * 0.7), 0.01);
    final zoom = (log(360 / span) / ln2 - 1.0).clamp(5.0, 14.0).toDouble();
    return (LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), zoom);
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _err = null;
    });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission was denied.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final at = LatLng(p.latitude, p.longitude);
      _place(at);
      _mc.move(at, 15);
    } catch (e) {
      if (mounted) setState(() => _err = _msg(e));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _view();
    final far = _km > 15;
    return Scaffold(
      appBar: premiumBar(widget.title),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mc,
            options: MapOptions(
              initialCenter: v.$1,
              initialZoom: v.$2,
              backgroundColor: kBg1,
              onTap: (_, p) => _place(p),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.my_app1',
              ),
              MarkerLayer(
                markers: [
                  for (final s in widget.stops)
                    Marker(
                      point: s.pos,
                      width: 90,
                      height: 34,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 9, color: kGold),
                          Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_pin != null)
                MarkerLayer(markers: [redPinMarker(_pin!, 'Your pin')]),
            ],
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Column(
              children: [
                _round(Icons.add, () => _mc.move(_mc.camera.center, _mc.camera.zoom + 1)),
                const SizedBox(height: 8),
                _round(Icons.remove, () => _mc.move(_mc.camera.center, _mc.camera.zoom - 1)),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: kBad),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pin == null
                              ? 'Tap the map to drop a red pin.'
                              : 'Nearest stop: ${_near?.name ?? '-'} • ${_km.toStringAsFixed(1)} km away',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (_pin != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 32),
                      child: Text(
                        far
                            ? 'This pin is far from the route. Your fare is worked out from the nearest stop.'
                            : 'Your fare is worked out from the nearest stop.',
                        style: TextStyle(color: far ? kWarn : kMuted, fontSize: 12),
                      ),
                    ),
                  if (_err != null) MsgBox(_err!),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _locating ? null : _locate,
                          icon: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: kGold),
                                )
                              : const Icon(Icons.my_location_rounded),
                          label: const Text('My location'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GoldButton(
                          label: 'Use this pin',
                          icon: Icons.check_rounded,
                          onPressed: (_pin == null || _near == null)
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  PinResult(_pin!, _near!, _km),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _round(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xEE070B14),
        shape: BoxShape.circle,
        border: Border.all(color: kGoldDark.withAlpha(140)),
      ),
      child: Icon(icon, size: 20, color: kGoldLight),
    ),
  );
}

// ---------- RESERVE SHEET ----------
class ReserveSheet extends StatefulWidget {
  final Bus bus;
  final Profile profile;
  const ReserveSheet({super.key, required this.bus, required this.profile});

  @override
  State<ReserveSheet> createState() => _ReserveSheetState();
}

class _ReserveSheetState extends State<ReserveSheet> {
  List<Stop> _stops = [];
  Set<int> _taken = {};
  bool _loading = true;
  int? _pick;
  int? _drop;
  String? _pickNote;
  String? _dropNote;
  LatLng? _pickPin; // red pins placed on the map
  LatLng? _dropPin;
  int? _seat;
  Quote? _quote;
  String? _quoteErr;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final stops = await Api.stops(widget.bus.routeId);
      final taken = await Api.takenSeats(widget.bus.id);
      if (!mounted) return;
      setState(() {
        _stops = stops;
        _taken = taken;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _msg(e);
      });
    }
  }

  Future<void> _loadQuote() async {
    if (_pick == null || _drop == null) return;
    try {
      final q = await Api.quote(
        widget.bus.routeId,
        _pick!,
        _drop!,
        widget.profile.type,
      );
      if (!mounted) return;
      setState(() {
        _quote = q;
        _quoteErr = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _quoteErr = _msg(e);
      });
    }
  }

  bool get _full => seatedCount(_taken) >= kSeats;

  Future<void> _openPin(bool pickup, List<Stop> allowed) async {
    final r = await Navigator.of(context).push<PinResult>(
      MaterialPageRoute(
        builder: (_) => PinPickerPage(
          title: pickup ? 'Pin where you get on' : 'Pin where you get off',
          stops: allowed,
          routeStops: _stops,
          initial: pickup ? _pickPin : _dropPin,
        ),
      ),
    );
    if (r == null || !mounted) return;
    final note =
        'Red pin • nearest stop: ${r.stop.name} • ${r.km.toStringAsFixed(1)} km away';
    setState(() {
      if (pickup) {
        _pick = r.stop.seq;
        _pickNote = note;
        _pickPin = r.pos;
        if (_drop != null && _drop! <= r.stop.seq) {
          _drop = null;
          _dropNote = null;
          _dropPin = null;
        }
      } else {
        _drop = r.stop.seq;
        _dropNote = note;
        _dropPin = r.pos;
      }
      _quote = null;
    });
    _loadQuote();
  }

  Widget _pinBtn(bool pickup, List<Stop> allowed, bool enabled) {
    final has = (pickup ? _pickPin : _dropPin) != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: (enabled && allowed.isNotEmpty)
            ? () => _openPin(pickup, allowed)
            : null,
        icon: const Icon(Icons.location_on_rounded, color: kBad),
        label: Text(
          has
              ? 'Red pin placed • tap to move it'
              : (pickup
                    ? 'Drop a red pin where you get on'
                    : 'Drop a red pin where you get off'),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_pick == null || _drop == null) {
      setState(() => _error = 'Choose your pick-up and drop-off points.');
      return;
    }
    if (_seat == null) {
      setState(
        () => _error = _full
            ? 'Please pick a standing place.'
            : 'Please pick a seat.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final t = await Api.reserve(widget.bus, _seat!, _pick!, _drop!);
      if (_pickPin != null || _dropPin != null) {
        try {
          await Api.setPins(t.id, _pickPin, _dropPin);
        } catch (e) {
          debugPrint('pins not saved: $e');
        }
      }
      if (!mounted) return;
      Navigator.pop(context, t);
    } catch (e) {
      final fresh = await Api.takenSeats(widget.bus.id);
      if (!mounted) return;
      var msg = _msg(e);
      final standing = _seat != null && _seat! > kSeats;
      if (standing && !msg.contains('just taken')) {
        msg =
            '$msg\n\nStanding places use numbers above $kSeats. If the '
            'database rejects them, run standing_check.sql in Supabase and '
            'send me the result.';
      }
      setState(() {
        _saving = false;
        _taken = fresh;
        if (_seat != null && fresh.contains(_seat)) _seat = null;
        _error = msg;
      });
    }
  }

  // one airplane-style seat: Available (green outline), Selected (gold),
  // Filled (grey with a cross)
  Widget _seatBox(int n) {
    final taken = _taken.contains(n);
    final selected = _seat == n;
    final line = selected
        ? kGold
        : (taken ? Colors.white12 : kGood.withAlpha(190));
    return GestureDetector(
      onTap: taken ? null : () => setState(() => _seat = n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 44,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? kGoldGradient : null,
          color: selected
              ? null
              : (taken ? const Color(0xFF2A3347) : kSurface),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(color: line, width: selected ? 1.6 : 1.2),
          boxShadow: selected
              ? [BoxShadow(color: kGold.withAlpha(110), blurRadius: 10)]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 20, color: kInk)
            : (taken
                  ? const Icon(Icons.close_rounded, size: 16, color: Colors.white24)
                  : Text(
                      '$n',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    )),
      ),
    );
  }

  Widget _standBox(int i) {
    final n = kSeats + i;
    final taken = _taken.contains(n);
    final selected = _seat == n;
    return GestureDetector(
      onTap: taken ? null : () => setState(() => _seat = n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        height: 38,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected ? kGoldGradient : null,
          color: selected ? null : (taken ? Colors.white10 : kSurface),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? kGold
                : (taken ? Colors.white10 : kWarn.withAlpha(140)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check : Icons.accessibility_new_rounded,
              size: 16,
              color: selected ? kInk : (taken ? Colors.white24 : kWarn),
            ),
            const SizedBox(width: 4),
            Text(
              'Stand $i',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? kInk
                    : (taken ? Colors.white24 : Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standingSection() {
    final left = kStandingMax - standingCount(_taken);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FadeSlide(
        key: const ValueKey('standing'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              borderColor: kWarn.withAlpha(140),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.groups_rounded, color: kWarn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          left > 0
                              ? 'Bus is full - standing room available'
                              : 'Bus is completely full',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          left > 0
                              ? '$left of $kStandingMax standing places left. You travel standing and can take a seat if one frees up.'
                              : 'All $kSeats seats and $kStandingMax standing places are reserved. Try another bus.',
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (left > 0) ...[
              const SizedBox(height: 12),
              const Label('STANDING PLACES'),
              Wrap(
                children: [
                  for (var i = 1; i <= kStandingMax; i++) _standBox(i),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legend(Color fill, Color border, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border),
        ),
      ),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(color: kMuted, fontSize: 11)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final rows = kSeats ~/ 4;
    final lastSeq = _stops.isEmpty ? 0 : _stops.last.seq;
    // demo buses ignore how far the bus has "driven"; real buses only offer
    // stops that are still ahead of the bus
    final passed = widget.bus.currentSeq; // only stops still ahead of the bus
    final pickStops = _stops
        .where((s) => s.seq > passed && s.seq < lastSeq)
        .toList();
    final dropStops = _stops
        .where((s) => _pick != null && s.seq > _pick!)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _loading
          ? const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(color: kGold)),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const BrandMark(size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reserve a seat',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${widget.bus.id}  •  ${widget.bus.route}',
                              style: const TextStyle(color: kMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (pickStops.isEmpty)
                    MsgBox(
                      _stops.isEmpty
                          ? 'This bus has no stops loaded for its route (${widget.bus.routeId.isEmpty ? 'no route set' : widget.bus.routeId}). Run routes_seed.sql and demo_bus.sql in Supabase.'
                          : 'This bus has already passed all of its pick-up points. Choose another bus, or wait for its next trip.',
                    ),
                  const Label('PICK-UP POINT'),
                  StopPicker(
                    hint: 'Type a stop or any place to get on',
                    stops: pickStops,
                    routeStops: _stops,
                    value: _pick,
                    note: _pickNote,
                    onChanged: (seq, note) {
                      setState(() {
                        _pick = seq;
                        _pickNote = note;
                        _pickPin = null;
                        if (_drop != null && _drop! <= seq) {
                          _drop = null;
                          _dropNote = null;
                          _dropPin = null;
                        }
                        _quote = null;
                      });
                      _loadQuote();
                    },
                    onCleared: () => setState(() {
                      _pick = null;
                      _pickNote = null;
                      _pickPin = null;
                      _drop = null;
                      _dropNote = null;
                      _dropPin = null;
                      _quote = null;
                    }),
                  ),
                  _pinBtn(true, pickStops, true),
                  const SizedBox(height: 14),
                  const Label('DROP-OFF POINT'),
                  StopPicker(
                    hint: 'Type a stop or any place to get off',
                    disabledHint: 'Choose your pick-up first',
                    enabled: _pick != null,
                    stops: dropStops,
                    routeStops: _stops,
                    value: _drop,
                    note: _dropNote,
                    onChanged: (seq, note) {
                      setState(() {
                        _drop = seq;
                        _dropNote = note;
                        _dropPin = null;
                        _quote = null;
                      });
                      _loadQuote();
                    },
                    onCleared: () => setState(() {
                      _drop = null;
                      _dropNote = null;
                      _dropPin = null;
                      _quote = null;
                    }),
                  ),
                  _pinBtn(false, dropStops, _pick != null),
                  if (_quoteErr != null) MsgBox(_quoteErr!),
                  if (_quote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: GlassCard(
                        borderColor: kGold.withAlpha(110),
                        child: Column(
                          children: [
                            kv(
                              'Distance',
                              '${_quote!.distance.toStringAsFixed(1)} km',
                            ),
                            kv('Fare', peso(_quote!.fare)),
                            if (_quote!.discount > 0)
                              kv(
                                '${typeLabel(widget.profile.type)} discount',
                                '-${peso(_quote!.discount)}',
                              ),
                            kv('Reservation fee', peso(_quote!.fee)),
                            const Divider(height: 20),
                            kv(
                              'You pay the conductor',
                              peso(_quote!.total),
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Label('CHOOSE YOUR SEAT'),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        color: kBg0.withAlpha(120),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(70),
                          topRight: Radius.circular(70),
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        ),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_bus_filled,
                                size: 16,
                                color: kMuted,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'FRONT',
                                style: TextStyle(
                                  color: kMuted,
                                  fontSize: 11,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final l in ['A', 'B'])
                                SizedBox(
                                  width: 46,
                                  child: Center(
                                    child: Text(l, style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              const SizedBox(width: 30),
                              for (final l in ['C', 'D'])
                                SizedBox(
                                  width: 46,
                                  child: Center(
                                    child: Text(l, style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          for (int r = 0; r < rows; r++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _seatBox(r * 4 + 1),
                                _seatBox(r * 4 + 2),
                                SizedBox(
                                  width: 30, // aisle with the row number
                                  child: Center(
                                    child: Text(
                                      '${r + 1}',
                                      style: const TextStyle(color: kMuted, fontSize: 10),
                                    ),
                                  ),
                                ),
                                _seatBox(r * 4 + 3),
                                _seatBox(r * 4 + 4),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legend(kSurface, kGood.withAlpha(190), 'Available'),
                      const SizedBox(width: 16),
                      _legend(kGold, kGold, 'Selected'),
                      const SizedBox(width: 16),
                      _legend(const Color(0xFF2A3347), Colors.white24, 'Filled'),
                    ],
                  ),
                  if (_full) _standingSection(),
                  const SizedBox(height: 14),
                  const Text(
                    'Nothing is paid in the app. Show your QR code to the conductor and pay when you board. If the bus passes your pick-up point before you board, the reservation is cancelled automatically.',
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                  if (_error != null) MsgBox(_error!),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: GoldButton(
                      label: (_seat != null && _seat! > kSeats)
                          ? 'Confirm standing place'
                          : 'Confirm reservation',
                      icon: Icons.check_circle_outline,
                      busy: _saving,
                      onPressed: _saving ? null : _confirm,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ---------- MY TICKETS ----------
class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  List<Ticket>? _tickets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await Api.myTickets();
      if (!mounted) return;
      setState(() {
        _tickets = t;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _msg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropScaffold(
      appBar: premiumBar(
        'My tickets',
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(16), child: MsgBox(_error!))
          : _tickets == null
          ? const Center(child: CircularProgressIndicator(color: kGold))
          : _tickets!.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 56,
                    color: kMuted,
                  ),
                  SizedBox(height: 12),
                  Text('No reservations yet', style: TextStyle(color: kMuted)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _tickets!
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TicketPage(ticket: t),
                            ),
                          );
                          _load();
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${t.pickupName}  >  ${t.dropoffName}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Pill(
                                  text: statusShort(t.status),
                                  color: statusColor(t.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Bus ${t.busId}  •  ${seatLabel(t.seat)}',
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  peso(t.total),
                                  style: const TextStyle(
                                    color: kGold,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

// ---------- ONE TICKET (boarding pass with QR) ----------
class TicketPage extends StatefulWidget {
  final Ticket ticket;
  const TicketPage({super.key, required this.ticket});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  late Ticket _t = widget.ticket;
  final ValueNotifier<_Eta?> _eta = ValueNotifier<_Eta?>(null);
  Timer? _timer;
  String? _error;
  bool _busy = false;
  Bus? _busInfo; // bus name and whether it is running

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    _loadBus();
  }

  Future<void> _loadBus() async {
    try {
      final b = await Api.bus(_t.busId);
      if (mounted) setState(() => _busInfo = b);
    } catch (_) {}
  }

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
      ],
    ),
  );

  Widget _val(String v) => Text(
    v,
    textAlign: TextAlign.right,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  );

  // everything the conductor needs to see next to the QR code
  Widget _ticketDetails() {
    final b = _busInfo;
    final ticketPaid = _t.paid && _t.status == 'reserved';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kBg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _row('Passenger', _val(_t.name.isEmpty ? '-' : _t.name)),
          const Divider(height: 8),
          _row('Bus number', _val(_t.busId)),
          const Divider(height: 8),
          _row('Bus name', _val(b == null ? '-' : b.title)),
          const Divider(height: 8),
          _row('Seat', _val(seatLabel(_t.seat))),
          const Divider(height: 8),
          _row(
            'Bus status',
            b == null
                ? _val('-')
                : Pill(
                    text: b.running ? 'Running' : 'Not running',
                    color: b.running ? kGood : kMuted,
                  ),
          ),
          const Divider(height: 8),
          _row(
            'Ticket status',
            Pill(
              text: ticketPaid ? 'Reserved - paid online' : statusText(_t.status),
              color: ticketPaid ? kGood : statusColor(_t.status),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eta.dispose();
    super.dispose();
  }

  // Navigation-style ETA panel (arrival / min / km) shown right under the
  // status, so the passenger sees it as soon as the ticket is opened.
  Widget _etaBanner() {
    if (_t.status != 'reserved' && _t.status != 'boarded') {
      return const SizedBox.shrink();
    }
    final boarded = _t.status == 'boarded';
    final place = boarded ? _t.dropoffName : _t.pickupName;
    Widget col(String big, String small) => Expanded(
      child: Column(
        children: [
          Text(
            big,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          Text(small, style: const TextStyle(color: kMuted, fontSize: 13)),
        ],
      ),
    );
    return ValueListenableBuilder<_Eta?>(
      valueListenable: _eta,
      builder: (context, e, _) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: kBg1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kGold.withAlpha(110)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_filled, size: 16, color: kGold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    boarded
                        ? 'Bus reaches $place'
                        : 'Bus reaches your stop ($place)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kGold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (e == null)
              const Text(
                'ETA will show when the bus is on its way',
                style: TextStyle(color: kMuted, fontSize: 13),
              )
            else
              Row(
                children: [
                  col(_clock12(e.at), 'arrival'),
                  col(
                    e.mins >= 120
                        ? (e.mins / 60).toStringAsFixed(1)
                        : '${e.mins}',
                    e.mins >= 120 ? 'hr' : 'min',
                  ),
                  col((e.meters / 1000).toStringAsFixed(1), 'km'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      final t = await Api.myTicket(_t.id);
      if (mounted) setState(() => _t = t);
      _loadBus();
    } catch (_) {}
  }

  Future<void> _payOnline() async {
    if (kDemoPayments) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: kBg1,
        shape: _sheetShape,
        builder: (_) => DemoPaySheet(ticket: _t),
      );
      if (ok == true) await _refresh();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await Api.payUrl(_t.id);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('Could not open the payment page.');
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.cancel(_t.id);
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _place(String label, String name, CrossAxisAlignment align) =>
      Expanded(
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              label,
              style: TextStyle(
                color: kInk.withAlpha(170),
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: const TextStyle(
                color: kInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final active = _t.status == 'reserved' || _t.status == 'boarded';
    return BackdropScaffold(
      appBar: premiumBar('Boarding pass'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kGold.withAlpha(90)),
                boxShadow: [
                  BoxShadow(
                    color: kGold.withAlpha(30),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: kGoldGradient,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(27),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'BUS ${_t.busId}',
                              style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              seatLabel(_t.seat).toUpperCase(),
                              style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _place(
                              'FROM',
                              _t.pickupName,
                              CrossAxisAlignment.start,
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: kInk,
                            ),
                            _place(
                              'TO',
                              _t.dropoffName,
                              CrossAxisAlignment.end,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Pill(
                          text: (_t.paid && _t.status == 'reserved')
                              ? 'Reserved - paid online'
                              : statusText(_t.status),
                          color: (_t.paid && _t.status == 'reserved')
                              ? kGood
                              : statusColor(_t.status),
                        ),
                        const SizedBox(height: 16),
                        _etaBanner(),
                        if (active)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: QrImageView(data: _t.code, size: 200),
                              ),
                              if (_t.paid)
                                Transform.rotate(
                                  angle: -0.35,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kBg0.withAlpha(215),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: kGood,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Text(
                                      'PAID',
                                      style: TextStyle(
                                        color: kGood,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 6,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          Icon(
                            _t.status == 'completed'
                                ? Icons.verified_outlined
                                : Icons.block_rounded,
                            size: 72,
                            color: statusColor(_t.status),
                          ),
                        const SizedBox(height: 14),
                        SelectableText(
                          _t.code,
                          style: const TextStyle(
                            color: kGold,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        const Text(
                          'Show this code to the conductor',
                          style: TextStyle(color: kMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _ticketDetails(),
                        if (_t.status == 'reserved' || _t.status == 'boarded') ...[
                          const SizedBox(height: 16),
                          TripGuide(key: ValueKey('guide-${_t.id}-${_t.status}'), ticket: _t, etaOut: _eta),
                        ],
                        if (_t.status == 'completed') ...[
                          const SizedBox(height: 16),
                          RateTripCard(ticket: _t),
                        ],
                      ],
                    ),
                  ),
                  const TearLine(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        kv('Fare', peso(_t.fare)),
                        if (_t.discount > 0)
                          kv(
                            '${typeLabel(_t.type)} discount',
                            '-${peso(_t.discount)}',
                          ),
                        kv('Reservation fee', peso(_t.fee)),
                        const Divider(height: 20),
                        kv(
                          _t.paid ? 'Paid' : 'Pay online or on boarding',
                          peso(_t.total),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_t.discount > 0)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'Bring a valid ID for your discount.',
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
            if (_error != null) MsgBox(_error!),
            if (_t.status == 'reserved' && !_t.paid)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final m in kPayMethods)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: PayLogo(method: m, size: 34),
                      ),
                  ],
                ),
              ),
            if (_t.status == 'reserved' && !_t.paid)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: GoldButton(
                    label: 'Pay online (GCash / Maya / card)',
                    icon: Icons.payments_outlined,
                    busy: _busy,
                    onPressed: _busy ? null : _payOnline,
                  ),
                ),
              ),
            if (_t.status == 'reserved' && !_t.paid)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel reservation (free)'),
                  ),
                ),
              ),
            if (_t.status == 'reserved' && _t.paid)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'Paid. Show your QR code to the conductor to board. To cancel a paid ticket, ask the conductor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- DEMO PAYMENT (fake checkout, no real money) ----------
class DemoPaySheet extends StatefulWidget {
  final Ticket ticket;
  const DemoPaySheet({super.key, required this.ticket});

  @override
  State<DemoPaySheet> createState() => _DemoPaySheetState();
}

class _DemoPaySheetState extends State<DemoPaySheet> {
  static const PayMethod _cashM = PayMethod(
    'cash',
    'Pay on the bus',
    Icons.payments_rounded,
    kWarn,
  );
  String _method = 'GCash';
  bool _busy = false;
  bool _done = false;
  bool _cashDone = false;
  String? _error;
  final TextEditingController _num = TextEditingController(); // GCash / Maya
  final TextEditingController _cardNo = TextEditingController();
  final TextEditingController _exp = TextEditingController();
  final TextEditingController _cvv = TextEditingController();
  final TextEditingController _holder = TextEditingController();

  bool get _cash => _method == _cashM.name;

  @override
  void dispose() {
    _num.dispose();
    _cardNo.dispose();
    _exp.dispose();
    _cvv.dispose();
    _holder.dispose();
    super.dispose();
  }

  // 09171234567, +639171234567 and 639171234567 all become 09171234567
  String? _normNumber(String raw) {
    var s = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.startsWith('63') && s.length == 12) s = '0${s.substring(2)}';
    return RegExp(r'^09\d{9}$').hasMatch(s) ? s : null;
  }

  String? _validate() {
    if (_cash) return null;
    if (_method == 'Card') {
      final n = _cardNo.text.replaceAll(' ', '');
      if (!RegExp(r'^\d{16}$').hasMatch(n)) {
        return 'Enter your 16-digit card number.';
      }
      final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(_exp.text);
      if (m == null) return 'Enter the expiry date as MM/YY.';
      final mm = int.parse(m.group(1)!);
      final yy = 2000 + int.parse(m.group(2)!);
      final now = DateTime.now();
      if (mm < 1 || mm > 12) return 'The expiry month must be 01 to 12.';
      if (yy < now.year || (yy == now.year && mm < now.month)) {
        return 'This card has expired.';
      }
      if (!RegExp(r'^\d{3,4}$').hasMatch(_cvv.text)) {
        return 'Enter the 3 or 4 digit CVV.';
      }
      if (_holder.text.trim().length < 3) return 'Type the name on the card.';
      return null;
    }
    if (_normNumber(_num.text) == null) {
      return 'Enter a valid $_method mobile number, like 09171234567.';
    }
    return null;
  }

  // shown on the success screen, never the full number
  String get _masked {
    if (_method == 'Card') {
      final n = _cardNo.text.replaceAll(' ', '');
      return n.length < 4 ? '' : 'Card ending in ${n.substring(n.length - 4)}';
    }
    final n = _normNumber(_num.text);
    return n == null ? '' : '$_method \u2022 ${n.substring(0, 4)} *** ${n.substring(7)}';
  }

  Future<void> _confirmCash() async {
    setState(() => _cashDone = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.pop(context, false); // still unpaid, pay the conductor
  }

  Widget _form() {
    if (_cash) {
      return GlassCard(
        borderColor: kWarn.withAlpha(110),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.payments_rounded, color: kWarn),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pay ${peso(widget.ticket.total)} in cash to the conductor when you board. '
                'Show your QR code. Your seat stays reserved until the bus passes your pick-up point.',
                style: const TextStyle(color: kMuted, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    if (_method == 'Card') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Label('CARD DETAILS'),
          TextField(
            controller: _cardNo,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [_CardNumberFormatter()],
            decoration: fieldDeco('Card number', Icons.credit_card_rounded),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _exp,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ExpiryFormatter()],
                  decoration: fieldDeco('MM/YY', Icons.event_rounded),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvv,
                  enabled: !_busy,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: fieldDeco('CVV', Icons.lock_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _holder,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: fieldDeco('Name on card', Icons.person_outline),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Label('${_method.toUpperCase()} MOBILE NUMBER'),
        TextField(
          controller: _num,
          enabled: !_busy,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: fieldDeco('09XX XXX XXXX', Icons.phone_android_rounded),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the mobile number linked to your $_method wallet.',
          style: const TextStyle(color: kMuted, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _pay() async {
    final bad = _validate();
    if (bad != null) {
      setState(() => _error = bad);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 1600)); // "processing"
      await Api.demoPay(widget.ticket.id);
      if (!mounted) return;
      setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 1300));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _msg(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    if (_cashDone) {
      return SizedBox(
        height: 320,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kWarn,
                    boxShadow: [
                      BoxShadow(color: kWarn.withAlpha(110), blurRadius: 36),
                    ],
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    size: 52,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pay on the bus',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Give ${peso(t.total)} in cash to the conductor when you board.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_done) {
      return SizedBox(
        height: 320,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, _) => Transform.scale(
                  scale: v,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kGood,
                      boxShadow: [
                        BoxShadow(color: kGood.withAlpha(110), blurRadius: 36),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 58,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PayLogo(
                method: kPayMethods.firstWhere(
                  (m) => m.name == _method,
                  orElse: () => kPayMethods.first,
                ),
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Payment successful',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              if (_masked.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _masked,
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                peso(t.total),
                style: const TextStyle(color: kGold, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Pill(text: 'DEMO - no real money', color: kWarn),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const BrandMark(size: 40),
                const SizedBox(width: 12),
                const Text(
                  'Pay for your seat',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Bus ${t.busId} • ${seatLabel(t.seat)} • ${t.pickupName} > ${t.dropoffName}',
              style: const TextStyle(color: kMuted),
            ),
            const SizedBox(height: 16),
            GlassCard(
              borderColor: kGold.withAlpha(110),
              child: Column(
                children: [
                  kv('Fare', peso(t.fare)),
                  if (t.discount > 0)
                    kv('${typeLabel(t.type)} discount', '-${peso(t.discount)}'),
                  kv('Reservation fee', peso(t.fee)),
                  const Divider(height: 20),
                  kv('Total', peso(t.total), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Label('PAY ONLINE WITH'),
            ...kPayMethods.map(
              (m) => PayMethodTile(
                method: m,
                selected: _method == m.name,
                onTap: _busy
                    ? null
                    : () => setState(() {
                        _method = m.name;
                        _error = null;
                      }),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
            ),
            const SizedBox(height: 6),
            PayMethodTile(
              method: _cashM,
              selected: _cash,
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _method = _cashM.name;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 6),
            _form(),
            if (_error != null) MsgBox(_error!),
            const SizedBox(height: 18),
            GoldButton(
              label: _busy
                  ? 'Processing...'
                  : (_cash
                        ? 'Reserve and pay on the bus'
                        : 'Pay ${peso(t.total)} with $_method'),
              icon: _cash ? Icons.check_circle_outline : Icons.lock_outline,
              busy: _busy,
              onPressed: _busy ? null : (_cash ? _confirmCash : _pay),
            ),
            const SizedBox(height: 10),
            Text(
              _cash
                  ? 'Nothing is charged now. The conductor collects your payment when you board.'
                  : 'Demo only: your number and card details are not saved or sent anywhere, and nothing is charged.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final d = newV.text.replaceAll(RegExp(r'[^0-9]'), '');
    final b = StringBuffer();
    for (var i = 0; i < d.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(d[i]);
    }
    final s = b.toString();
    return TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldV, TextEditingValue newV) {
    final d = newV.text.replaceAll(RegExp(r'[^0-9]'), '');
    final b = StringBuffer();
    for (var i = 0; i < d.length && i < 4; i++) {
      if (i == 2) b.write('/');
      b.write(d[i]);
    }
    final s = b.toString();
    return TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }
}

// =====================================================
// CONDUCTOR
// =====================================================
class ConductorPage extends StatelessWidget {
  final Profile profile;
  const ConductorPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final busId = profile.busId;
    return DefaultTabController(
      length: 3,
      child: BackdropScaffold(
        appBar: premiumBar(
          'Conductor • ${busId ?? 'no bus'}',
          actions: [_logoutButton()],
          bottom: premiumTabs(['Scan', 'Fare', 'Passengers']),
        ),
        body: busId == null
            ? _noBus()
            : TabBarView(
                children: [
                  const _ScanTab(),
                  _FareTab(busId: busId),
                  const _PassengersTab(),
                ],
              ),
      ),
    );
  }
}

class _ScanTab extends StatefulWidget {
  const _ScanTab();

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  final TextEditingController _code = TextEditingController();
  Ticket? _t;
  String _usedCode = '';
  String? _message;
  bool _good = false;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find([String? c]) async {
    final code = (c ?? _code.text).trim().toUpperCase();
    if (code.isEmpty) return;
    _code.text = code;
    setState(() {
      _busy = true;
      _message = null;
      _t = null;
      _usedCode = code;
    });
    try {
      final t = await Api.lookup(code);
      if (!mounted) return;
      setState(() {
        _t = t;
        _good = false;
        if (t == null) _message = 'No reservation with that code on your bus.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _good = false;
          _message = _msg(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final v = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanPage()));
    if (v != null) _find(v);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      // not paid in the app = the passenger pays CASH to the conductor now
      final cash = _t != null && !_t!.paid;
      if (cash) {
        try {
          await Api.collectCash(_t!.id);
        } catch (_) {
          // older database: the confirm below still marks the ticket paid
        }
      }
      final ok = await Api.confirm(_usedCode);
      await _find(_usedCode);
      if (mounted) {
        setState(() {
          _good = ok;
          _message = ok
              ? (cash ? 'Cash collected. Passenger boarded.' : 'Boarded.')
              : 'Could not confirm. The status changed.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _good = false;
          _message = _msg(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _find(),
          style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700),
          decoration: fieldDeco('Reservation code', Icons.pin_outlined)
              .copyWith(
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: kGold),
                  onPressed: _busy ? null : _find,
                ),
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _scan,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan QR code'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(color: kGold),
          ),
        if (_message != null) MsgBox(_message!, good: _good),
        if (t != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: GlassCard(
              borderColor: kGold.withAlpha(110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Pill(
                        text: statusShort(t.status),
                        color: statusColor(t.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  kv(
                    t.seat > kSeats ? 'Place' : 'Seat',
                    t.seat > kSeats
                        ? 'Standing ${t.seat - kSeats}'
                        : '${t.seat}',
                  ),
                  kv('From', t.pickupName),
                  kv('To', t.dropoffName),
                  if (t.type != 'regular')
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kWarn.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kWarn.withAlpha(120)),
                      ),
                      child: Text(
                        '${typeLabel(t.type)} discount: CHECK ID',
                        style: const TextStyle(
                          color: kWarn,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const Divider(height: 22),
                  kv('Fare', peso(t.fare)),
                  if (t.discount > 0) kv('Discount', '-${peso(t.discount)}'),
                  kv('Reservation fee', peso(t.fee)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment', style: TextStyle(color: kMuted)),
                        Pill(text: payLabel(t), color: payColor(t)),
                      ],
                    ),
                  ),
                  if (t.paid)
                    kv('Total (paid)', peso(t.total), bold: true)
                  else
                    kv('Collect in cash', peso(t.total), bold: true),
                  const SizedBox(height: 14),
                  if (t.status == 'reserved')
                    SizedBox(
                      width: double.infinity,
                      child: GoldButton(
                        label: t.paid
                            ? 'Paid - confirm boarding'
                            : 'Cash received ${peso(t.total)} - board',
                        icon: Icons.check_circle_outline,
                        busy: _busy,
                        onPressed: _busy ? null : _confirm,
                      ),
                    )
                  else
                    Text(
                      statusText(t.status),
                      style: const TextStyle(
                        color: kMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: premiumBar('Scan passenger QR'),
      body: MobileScanner(
        onDetect: (BarcodeCapture capture) {
          if (_done) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && v.isNotEmpty) {
              _done = true;
              Navigator.pop(context, v);
              return;
            }
          }
        },
      ),
    );
  }
}

// walk-in fare calculator (no reservation fee)
class _FareTab extends StatefulWidget {
  final String busId;
  const _FareTab({required this.busId});

  @override
  State<_FareTab> createState() => _FareTabState();
}

class _FareTabState extends State<_FareTab> {
  Bus? _bus;
  List<Stop> _stops = [];
  int? _from;
  int? _to;
  String _type = 'regular';
  Quote? _quote;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final b = await Api.bus(widget.busId);
      if (b == null || b.routeId.isEmpty) {
        if (mounted) {
          setState(
            () => _error = 'No route yet. The driver must start a trip.',
          );
        }
        return;
      }
      final s = await Api.stops(b.routeId);
      if (!mounted) return;
      setState(() {
        _bus = b;
        _stops = s;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  Future<void> _calc() async {
    if (_from == null || _to == null || _bus == null) return;
    try {
      final q = await Api.quote(_bus!.routeId, _from!, _to!, _type);
      if (!mounted) return;
      setState(() {
        _quote = q;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _error = _msg(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSeq = _stops.isEmpty ? 0 : _stops.last.seq;
    final toStops = _stops
        .where((s) => _from != null && s.seq > _from!)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _bus == null ? 'Route' : _bus!.route,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const Label('FROM'),
              PDrop<int>(
                value: _from,
                hint: 'Pick-up point',
                items: _stops
                    .where((s) => s.seq < lastSeq)
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s.seq, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _from = v;
                    if (_to != null && v != null && _to! <= v) _to = null;
                    _quote = null;
                  });
                  _calc();
                },
              ),
              const SizedBox(height: 14),
              const Label('TO'),
              PDrop<int>(
                value: _to,
                hint: 'Drop-off point',
                items: toStops
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s.seq, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _to = v;
                    _quote = null;
                  });
                  _calc();
                },
              ),
              const SizedBox(height: 14),
              const Label('PASSENGER'),
              PDrop<String>(
                value: _type,
                hint: 'Passenger type',
                items: ['regular', 'student', 'senior', 'pwd']
                    .map(
                      (t) =>
                          DropdownMenuItem(value: t, child: Text(typeLabel(t))),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _type = v ?? 'regular';
                    _quote = null;
                  });
                  _calc();
                },
              ),
            ],
          ),
        ),
        if (_error != null) MsgBox(_error!),
        if (_quote != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: GlassCard(
              borderColor: kGold.withAlpha(110),
              child: Column(
                children: [
                  kv('Distance', '${_quote!.distance.toStringAsFixed(1)} km'),
                  kv('Fare', peso(_quote!.fare)),
                  if (_quote!.discount > 0)
                    kv(
                      '${typeLabel(_type)} discount',
                      '-${peso(_quote!.discount)}',
                    ),
                  const Divider(height: 20),
                  kv(
                    'Collect',
                    peso(_quote!.fare - _quote!.discount),
                    bold: true,
                  ),
                  if (_type != 'regular')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Check the passenger ID.',
                        style: TextStyle(color: kWarn),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PassengersTab extends StatefulWidget {
  const _PassengersTab();

  @override
  State<_PassengersTab> createState() => _PassengersTabState();
}

class _PassengersTabState extends State<_PassengersTab> {
  List<Ticket> _list = [];
  String? _error;
  String? _note;
  String? _busyId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await Api.manifest();
      if (!mounted) return;
      setState(() {
        _list = l;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  // the passenger handed over cash
  Future<void> _collect(Ticket t) async {
    setState(() {
      _busyId = t.id;
      _note = null;
    });
    try {
      await Api.collectCash(t.id);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _note = _msg(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  double _sum(Iterable<Ticket> l) => l.fold(0.0, (a, t) => a + t.total);

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(16), child: MsgBox(_error!));
    }
    if (_list.isEmpty) {
      return const Center(
        child: Text('No passengers yet', style: TextStyle(color: kMuted)),
      );
    }
    final list = [..._list]
      ..sort((a, b) {
        final c = a.pickupSeq.compareTo(b.pickupSeq);
        return c != 0 ? c : a.seat.compareTo(b.seat);
      });
    final online = list.where((t) => payState(t) == 'online').toList();
    final cashDone = list.where((t) => payState(t) == 'cash').toList();
    final due = list.where((t) => !t.paid).toList();
    final onBoard = list.where((t) => t.status == 'boarded').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            children: [
              kv('Passengers', '${list.length} (on board $onBoard)'),
              kv('Paid online', '${online.length} • ${peso(_sum(online))}'),
              kv(
                'Cash collected',
                '${cashDone.length} • ${peso(_sum(cashDone))}',
              ),
              const Divider(height: 20),
              kv(
                'Cash to collect',
                '${due.length} • ${peso(_sum(due))}',
                bold: true,
              ),
            ],
          ),
        ),
        if (_note != null) MsgBox(_note!),
        const SizedBox(height: 10),
        ...list.map(
          (t) => tileCard(
            icon: Icons.event_seat_rounded,
            title: '${seatLabel(t.seat)} • ${t.name}',
            subtitle:
                '${t.pickupName} > ${t.dropoffName}\n'
                '${payLabel(t)} • ${peso(t.total)}'
                '${t.type != 'regular' ? '\n${typeLabel(t.type)} - check ID' : ''}',
            accent: t.status == 'boarded' ? kGood : kWarn,
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Pill(
                  text: t.status == 'boarded' ? 'On board' : 'Waiting',
                  color: statusColor(t.status),
                ),
                if (!t.paid && t.status == 'reserved')
                  TextButton(
                    onPressed: _busyId == t.id ? null : () => _collect(t),
                    child: const Text('Cash received'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================
// DRIVER
// =====================================================
// Driver map: where the bus is, the road, and every stop with passengers
// waiting to be picked up (gold) or getting off (green).
class _DriverMap extends StatefulWidget {
  final Bus? bus;
  final List<Stop> stops;
  final List<LatLng> road;
  final List<Ticket> manifest;
  final List<Map<String, dynamic>> pins; // red pins placed by passengers
  final String? pinErr; // why the pins could not be loaded
  const _DriverMap({
    required this.bus,
    required this.stops,
    required this.road,
    required this.manifest,
    this.pins = const [],
    this.pinErr,
  });

  @override
  State<_DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<_DriverMap> {
  final MapController _mc = MapController();
  bool _ready = false;
  bool _fitted = false;

  bool _valid(LatLng p) => p.latitude.abs() > 0.01 || p.longitude.abs() > 0.01;

  List<LatLng> get _allPoints {
    if (widget.road.isNotEmpty) return widget.road;
    return widget.stops.map((s) => s.pos).toList();
  }

  void _fit() {
    final pts = _allPoints;
    if (!_ready || pts.isEmpty) return;
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    final span = max(max(maxLat - minLat, (maxLng - minLng) * 0.7), 0.01);
    final zoom = (log(360 / span) / ln2 - 1.0).clamp(5.0, 14.0);
    _mc.move(LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), zoom);
    _fitted = true;
  }

  @override
  void didUpdateWidget(covariant _DriverMap old) {
    super.didUpdateWidget(old);
    if (!_fitted && _allPoints.isNotEmpty) _fit();
  }

  Widget _pin(Stop s, int up, int down, List<String> names) {
    final busy = up > 0 || down > 0;
    if (!busy) {
      return const Icon(Icons.circle, size: 9, color: kMuted);
    }
    final color = up > 0 ? kGold : kGood;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (up > 0) ...[
                const Icon(Icons.north_east_rounded, size: 12, color: kInk),
                Text(' $up', style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
              if (up > 0 && down > 0) const SizedBox(width: 6),
              if (down > 0) ...[
                const Icon(Icons.south_east_rounded, size: 12, color: kInk),
                Text(' $down', style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xDD070B14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            names.isEmpty ? s.name : '${s.name} • ${names.join(', ')}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final busPos = (bus != null && _valid(bus.pos)) ? bus.pos : null;
    final start = busPos ??
        (widget.stops.isNotEmpty ? widget.stops.first.pos : kCenter);

    final markers = <Marker>[];
    for (final s in widget.stops) {
      final up = widget.manifest
          .where((t) => t.status == 'reserved' && t.pickupSeq == s.seq)
          .length;
      final down = widget.manifest
          .where((t) =>
              (t.status == 'reserved' || t.status == 'boarded') &&
              t.dropoffSeq == s.seq)
          .length;
      final busy = up > 0 || down > 0;
      final names = widget.manifest
          .where((t) => t.status == 'reserved' && t.pickupSeq == s.seq)
          .map((t) => t.name.trim().split(' ').first)
          .where((n) => n.isNotEmpty)
          .take(3)
          .toList();
      markers.add(
        Marker(
          point: s.pos,
          width: busy ? 170 : 14,
          height: busy ? 52 : 14,
          child: _pin(s, up, down, names),
        ),
      );
    }
    // red pins: the exact spot each passenger wants to get on / off
    for (final p in widget.pins) {
      final who = '${p['rname'] ?? ''}'.trim().split(' ').first;
      final status = '${p['rstatus'] ?? ''}';
      if (status == 'reserved' && p['plat'] != null && p['plng'] != null) {
        markers.add(
          redPinMarker(
            LatLng(_d(p['plat']), _d(p['plng'])),
            who.isEmpty ? 'Pick up' : 'Pick up: $who',
          ),
        );
      }
      if (p['dlat'] != null && p['dlng'] != null) {
        markers.add(
          redPinMarker(
            LatLng(_d(p['dlat']), _d(p['dlng'])),
            who.isEmpty ? 'Drop off' : 'Drop off: $who',
            icon: Icons.flag_rounded,
          ),
        );
      }
    }
    if (busPos != null) {
      markers.add(
        Marker(
          point: busPos,
          width: 56,
          height: 56,
          child: PulseRing(
            size: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGoldGradient,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.directions_bus_filled, size: 20, color: kInk),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mc,
              options: MapOptions(
                initialCenter: start,
                initialZoom: 11,
                backgroundColor: kBg1,
                onMapReady: () {
                  _ready = true;
                  if (!_fitted && _allPoints.isNotEmpty) _fit();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.my_app1',
                ),
                if (widget.road.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: widget.road, strokeWidth: 9, color: kBg0.withAlpha(200)),
                      Polyline(points: widget.road, strokeWidth: 5, color: kGold),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _btn(Icons.add, () => _mc.move(_mc.camera.center, _mc.camera.zoom + 1)),
                  const SizedBox(height: 8),
                  _btn(Icons.remove, () => _mc.move(_mc.camera.center, _mc.camera.zoom - 1)),
                  const SizedBox(height: 8),
                  _btn(Icons.my_location_rounded, () {
                    if (busPos != null) _mc.move(busPos, 14);
                  }),
                  const SizedBox(height: 8),
                  _btn(Icons.alt_route_rounded, _fit),
                ],
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xDD070B14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'Gold = stop   Red pin = passenger   Bus = you',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
            if (busPos == null)
              const Positioned(
                left: 10,
                top: 10,
                child: Pill(text: 'Start your trip to show your position', color: kWarn),
              ),
            Positioned(
              left: 10,
              right: 58,
              top: busPos == null ? 44 : 10,
              child: widget.pinErr != null
                  ? MsgBox('Red pins could not load: ${widget.pinErr}')
                  : (widget.pins.isEmpty
                        ? const Pill(
                            text: 'No red pins on this bus yet',
                            color: kMuted,
                          )
                        : Pill(
                            text: '${widget.pins.length} passenger pin(s)',
                            color: kBad,
                          )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xDD070B14),
        shape: BoxShape.circle,
        border: Border.all(color: kGoldDark.withAlpha(140)),
      ),
      child: Icon(icon, size: 19, color: kGoldLight),
    ),
  );
}

class DriverPage extends StatefulWidget {
  final Profile profile;
  const DriverPage({super.key, required this.profile});

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  List<Map<String, dynamic>> _routes = [];
  String? _routeId;
  Bus? _bus;
  List<Stop> _stops = [];
  String _stopsFor = '';
  List<Ticket> _manifest = [];
  List<LatLng> _road = [];
  String? _loadErr;
  List<Map<String, dynamic>> _pins = [];
  String? _pinErr;
  List<LatLng> _simLine = []; // road the simulated bus drives along
  List<double> _simCum = []; // metres from the start to each point
  DateTime? _simStart;
  String? _busId; // the bus this driver is driving right now
  List<Bus> _allBuses = [];
  bool _picking = false;
  Timer? _gps;
  Timer? _poll;
  bool _on = false;
  String _status = 'Not on a trip';

  @override
  void initState() {
    super.initState();
    _busId = widget.profile.busId;
    _loadRoutes();
    _loadBuses();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      _refresh();
      _loadBuses();
    });
  }

  @override
  void dispose() {
    _gps?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    try {
      final r = await Api.routes();
      if (!mounted) return;
      setState(() {
        _routes = r;
        _routeId ??= r.isEmpty ? null : '${r.first['id']}';
      });
    } catch (_) {}
  }

  Future<void> _loadBuses() async {
    try {
      final l = await Api.buses();
      if (mounted) setState(() => _allBuses = l);
    } catch (_) {}
  }

  Future<void> _chooseBus(String? id) async {
    if (id == null || id == _busId || _on) return;
    setState(() {
      _picking = true;
      _loadErr = null;
    });
    try {
      await Api.chooseBus(id);
      if (!mounted) return;
      setState(() {
        _busId = id;
        _bus = null;
        _stops = [];
        _stopsFor = '';
        _road = [];
        _manifest = [];
        _status = 'Not on a trip';
      });
      await _refresh();
      await _loadBuses();
    } catch (e) {
      if (mounted) setState(() => _loadErr = _msg(e));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // "Which bus are you driving?" dropdown
  Widget _busPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Label('BUS YOU ARE DRIVING'),
        PDrop<String>(
          value: _allBuses.any((b) => b.id == _busId) ? _busId : null,
          hint: _picking ? 'Switching...' : 'Choose your bus (e.g. DV-03)',
          items: _allBuses.map((b) {
            return DropdownMenuItem<String>(
              value: b.id,
              child: Text(
                '${b.id} • ${b.title}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (_on || _picking) ? null : _chooseBus,
        ),
        if (_on)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'End your trip before you switch buses.',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }

  Future<void> _refresh() async {
    final busId = _busId;
    if (busId == null) return;
    try {
      final b = await Api.bus(busId);
      if (b != null && b.routeId.isNotEmpty && b.routeId != _stopsFor) {
        final s = await Api.stops(b.routeId);
        _stops = s;
        _stopsFor = b.routeId;
        try {
          _road = await RoadRoutes.fetch(
            b.routeId,
            s.map((x) => x.pos).toList(),
          );
        } catch (_) {
          _road = [];
        }
      }
      final m = await Api.manifest();
      var pins = <Map<String, dynamic>>[];
      String? pinErr;
      try {
        pins = await Api.busPins();
      } catch (e) {
        pinErr = _msg(e);
      }
      if (!mounted) return;
      setState(() {
        _bus = b;
        _manifest = m;
        _pins = pins;
        _pinErr = pinErr;
        _loadErr = null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadErr = _msg(e));
    }
  }

  // ---- simulated trip: first stop to last stop at kSimSpeedKmh ----
  Future<bool> _prepareSim() async {
    try {
      final stops = await Api.stops(_routeId!);
      if (stops.length < 2) throw Exception('This route has no stops yet.');
      final pts = stops.map((x) => x.pos).toList();
      List<LatLng> line;
      try {
        line = await RoadRoutes.fetch(_routeId!, pts);
      } catch (_) {
        line = pts;
      }
      if (line.length < 2) line = pts;
      const d = Distance();
      final cum = <double>[0];
      for (var i = 1; i < line.length; i++) {
        cum.add(cum.last + d.as(LengthUnit.Meter, line[i - 1], line[i]));
      }
      _simLine = line;
      _simCum = cum;
      _simStart = DateTime.now();
      return true;
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: ${_msg(e)}');
      return false;
    }
  }

  LatLng _simPointAt(double meters) {
    if (meters <= 0) return _simLine.first;
    if (meters >= _simCum.last) return _simLine.last;
    var i = 1;
    while (i < _simCum.length && _simCum[i] < meters) {
      i++;
    }
    final a = _simLine[i - 1], b = _simLine[i];
    final seg = _simCum[i] - _simCum[i - 1];
    final f = seg <= 0 ? 0.0 : (meters - _simCum[i - 1]) / seg;
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * f,
      a.longitude + (b.longitude - a.longitude) * f,
    );
  }

  Future<void> _simTick() async {
    try {
      final start = _simStart;
      if (_simLine.length < 2 || start == null) return;
      final secs = DateTime.now().difference(start).inMilliseconds / 1000;
      final meters = kSimSpeedKmh / 3.6 * secs;
      final total = _simCum.last;
      final arrived = meters >= total;
      final pos = _simPointAt(meters);
      await Api.updateBus(
        pos.latitude,
        pos.longitude,
        arrived ? 0 : kSimSpeedKmh,
      );
      await _refresh();
      if (!mounted) return;
      setState(() {
        _status = arrived
            ? 'Arrived at the destination'
            : 'Sharing location • ${kSimSpeedKmh.toStringAsFixed(0)} km/h • ${((total - meters) / 1000).toStringAsFixed(1)} km to go';
      });
      if (arrived) {
        _gps?.cancel();
        _gps = null;
        // stay at the destination for a moment, then close the trip
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted && _on) _end();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: ${_msg(e)}');
    }
  }

  Future<void> _tick() async {
    if (kSimulateTrip) {
      await _simTick();
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final kmh = max(0.0, p.speed) * 3.6; // m/s to km/h
      await Api.updateBus(p.latitude, p.longitude, kmh);
      await _refresh();
      if (mounted) {
        setState(
          () => _status = 'Sharing location • ${kmh.toStringAsFixed(0)} km/h',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: ${_msg(e)}');
    }
  }

  Future<void> _start() async {
    if (_routeId == null) {
      setState(() => _status = 'Choose a route first.');
      return;
    }
    if (!kSimulateTrip) {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission was denied.');
        return;
      }
    }
    try {
      await Api.startTrip(_routeId!);
    } catch (e) {
      setState(() => _status = 'Error: ${_msg(e)}');
      return;
    }
    if (kSimulateTrip && !await _prepareSim()) {
      try {
        await Api.endTrip();
      } catch (_) {}
      return;
    }
    setState(() {
      _on = true;
      _status = 'Trip started';
    });
    _tick();
    _gps = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _tick(),
    );
  }

  Future<void> _end() async {
    _gps?.cancel();
    _gps = null;
    try {
      await Api.endTrip();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _on = false;
      _status = 'Trip ended';
    });
    _refresh();
  }

  Future<void> _dropped(Ticket t) async {
    try {
      await Api.complete(t.id);
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: ${_msg(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busId = _busId;
    final current = _bus?.currentSeq ?? 0;

    final pickups = _manifest.where((t) => t.status == 'reserved').toList()
      ..sort((a, b) => a.pickupSeq.compareTo(b.pickupSeq));
    final drops = _manifest.where((t) => t.status == 'boarded').toList()
      ..sort((a, b) => a.dropoffSeq.compareTo(b.dropoffSeq));

    return BackdropScaffold(
      appBar: premiumBar(
        'Driver • ${busId ?? 'no bus'}',
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              if (_on) await _end();
              await _sb.auth.signOut();
            },
          ),
        ],
      ),
      body: busId == null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Which bus are you driving today?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _busPicker(),
                      if (_loadErr != null) MsgBox(_loadErr!),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _busPicker(),
                        const Label('ROUTE'),
                        PDrop<String>(
                          value: _routeId,
                          hint: 'Choose route',
                          items: _routes
                              .map(
                                (r) => DropdownMenuItem(
                                  value: '${r['id']}',
                                  child: Text('${r['name']}'),
                                ),
                              )
                              .toList(),
                          onChanged: _on
                              ? null
                              : (v) => setState(() => _routeId = v),
                        ),
                        const SizedBox(height: 14),
                        if (_on)
                          OutlinedButton.icon(
                            onPressed: _end,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('End trip'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kBad,
                              side: const BorderSide(color: kBad),
                            ),
                          )
                        else
                          GoldButton(
                            label: 'Start trip',
                            icon: Icons.play_arrow_rounded,
                            onPressed: _start,
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 9,
                              color: _on ? kGood : kMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _status,
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loadErr != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MsgBox('Could not load passengers: $_loadErr'),
                  ),
                Expanded(
                  child: DefaultTabController(
                    length: 4,
                    child: Column(
                      children: [
                        premiumTabs([
                          'Pick up (${pickups.length})',
                          'Drop off (${drops.length})',
                          'Map',
                          'Route',
                        ]),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // ---- PICK UP ----
                              pickups.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No one waiting',
                                        style: TextStyle(color: kMuted),
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: pickups
                                          .map(
                                            (t) => tileCard(
                                              icon: Icons.north_east_rounded,
                                              title:
                                                  'Pick up at ${t.pickupName}',
                                              subtitle:
                                                  '${seatLabel(t.seat)} • ${t.name}\nGetting off at ${t.dropoffName}',
                                              trailing:
                                                  t.pickupSeq == current + 1
                                                  ? const Pill(
                                                      text: 'NEXT',
                                                      color: kGold,
                                                    )
                                                  : null,
                                            ),
                                          )
                                          .toList(),
                                    ),
                              // ---- DROP OFF ----
                              drops.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No one on board',
                                        style: TextStyle(color: kMuted),
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: drops
                                          .map(
                                            (t) => tileCard(
                                              icon: Icons.south_east_rounded,
                                              title:
                                                  'Drop off at ${t.dropoffName}',
                                              subtitle:
                                                  '${seatLabel(t.seat)} • ${t.name}\nBoarded at ${t.pickupName}',
                                              accent: kGood,
                                              trailing: TextButton(
                                                onPressed: () => _dropped(t),
                                                child: const Text('Dropped'),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                              // ---- MAP ----
                              _DriverMap(
                                bus: _bus,
                                stops: _stops,
                                road: _road,
                                manifest: _manifest,
                                pins: _pins,
                                pinErr: _pinErr,
                              ),
                              // ---- ROUTE ----
                              _stops.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'Start a trip to see the route',
                                        style: TextStyle(color: kMuted),
                                      ),
                                    )
                                  : ListView(
                                      padding: const EdgeInsets.all(16),
                                      children: _stops.map((s) {
                                        final up = _manifest
                                            .where(
                                              (t) =>
                                                  t.status == 'reserved' &&
                                                  t.pickupSeq == s.seq,
                                            )
                                            .length;
                                        final down = _manifest
                                            .where((t) => t.dropoffSeq == s.seq)
                                            .length;
                                        final passed = s.seq <= current;
                                        final next = s.seq == current + 1;
                                        return tileCard(
                                          icon: passed
                                              ? Icons.check_circle_rounded
                                              : (next
                                                    ? Icons.arrow_circle_right
                                                    : Icons
                                                          .radio_button_unchecked),
                                          accent: passed
                                              ? kGood
                                              : (next ? kGold : kMuted),
                                          title: s.name,
                                          subtitle:
                                              'Pick up: $up • Drop off: $down',
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------- ASSISTANT CHAT SCREEN ----------
class AssistantPage extends StatefulWidget {
  final Profile profile;
  final List<Bus> Function() getBuses;
  const AssistantPage({
    super.key,
    required this.profile,
    required this.getBuses,
  });

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

// ---------- small animated helpers (used by the assistant chat) ----------

/// Fades + slides + scales its child in once. [delay] lets you stagger lists.
class _PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double dx; // start offset (fraction of own width)
  final double dy; // start offset (fraction of own height)
  final bool skip; // true = show instantly (already played before)
  const _PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dx = 0,
    this.dy = 0.18,
    this.skip = false,
  });

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.skip) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(widget.dx, widget.dy),
          end: Offset.zero,
        ).animate(_a),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(_a),
          alignment: widget.dx > 0
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Three bouncing dots shown while the assistant is thinking.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final p = ((_c.value - i * 0.16) % 1.0 + 1.0) % 1.0;
            final lift = p < 0.5 ? sin(p / 0.5 * pi) : 0.0;
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: Transform.translate(
                offset: Offset(0, -5 * lift),
                child: Opacity(
                  opacity: 0.4 + 0.6 * lift,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: kGoldLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Reveals text a few letters at a time. The bubble keeps its final size
/// (the not-yet-typed part is transparent), so nothing jumps around.
class _Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback? onDone;
  const _Typewriter({required this.text, required this.style, this.onDone});

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final ms = (widget.text.length * 14).clamp(500, 2600).toInt();
    _c =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: ms),
          )
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) widget.onDone?.call();
          })
          ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        if (_c.isCompleted) {
          return SelectableText(widget.text, style: widget.style);
        }
        final n = (widget.text.length * _c.value).floor();
        return Text.rich(
          TextSpan(
            style: widget.style,
            children: [
              TextSpan(text: widget.text.substring(0, n)),
              TextSpan(
                text: widget.text.substring(n),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small glowing dot that pulses (used for the "AI mode" status).
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.5 + 1.0 * v,
                child: Opacity(
                  opacity: (1 - v) * 0.55,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shrinks slightly while pressed, for tactile buttons and chips.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pressable({required this.child, this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.9 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _AssistantPageState extends State<AssistantPage> {
  late final BusAssistant _bot = BusAssistant(widget.profile);
  final TextEditingController _in = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _sc = ScrollController();
  final List<ChatMsg> _msgs = [];
  bool _thinking = false;
  bool _hasText = false;

  static const _chips = [
    'Buses to Davao City',
    'Fare from Tandag City to Davao City',
    'Seats available',
    'My tickets',
    'How do I reserve?',
    'Discounts',
  ];

  @override
  void initState() {
    super.initState();
    final name = widget.profile.name.trim().split(' ').first;
    _msgs.add(
      ChatMsg(
        false,
        'Hi${name.isEmpty ? '' : ' $name'}! I am your BusTrack assistant. '
        'Ask me about running buses, fares, free seats, your tickets, or how to reserve. '
        'You can also tap a suggestion below.',
        fresh: true,
      ),
    );
    _in.addListener(() {
      final has = _in.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _in.dispose();
    _focus.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) {
        _sc.animateTo(
          _sc.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Gemini sometimes adds markdown even when told not to. Tidy it up.
  String _tidy(String s) {
    return s
        .replaceAll('**', '')
        .replaceAllMapped(
          RegExp(r'^[ \t]*[\*\-][ \t]+', multiLine: true),
          (_) => '• ',
        )
        .trim();
  }

  String _hm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _in.text).trim();
    if (text.isEmpty || _thinking) return;
    _in.clear();
    final history = List<ChatMsg>.from(_msgs);
    setState(() {
      _msgs.add(ChatMsg(true, text));
      _thinking = true;
    });
    _scrollDown();

    String answer;
    try {
      answer = await _bot.reply(text, widget.getBuses(), history);
    } catch (e) {
      answer = 'Sorry, something went wrong: ${_msg(e)}';
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(ChatMsg(false, _tidy(answer), fresh: true));
      _thinking = false;
    });
    _scrollDown();
  }

  Widget _avatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: kGoldGradient,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: kGold.withAlpha(60), blurRadius: 8)],
      ),
      child: const Icon(Icons.directions_bus_rounded, size: 16, color: kInk),
    );
  }

  BoxDecoration _botBubbleDecoration() {
    return BoxDecoration(
      color: kSurface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(18),
      ),
      border: Border.all(color: Colors.white12),
    );
  }

  Widget _bubble(ChatMsg m) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    final style = TextStyle(
      color: m.mine ? kInk : Colors.white,
      height: 1.45,
      fontWeight: m.mine ? FontWeight.w600 : FontWeight.normal,
    );

    final Widget text = (!m.mine && m.fresh)
        ? _Typewriter(text: m.text, style: style, onDone: () => m.fresh = false)
        : SelectableText(m.text, style: style);

    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: maxW),
      decoration: m.mine
          ? BoxDecoration(
              gradient: kGoldGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: kGold.withAlpha(45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : _botBubbleDecoration(),
      child: text,
    );

    final skip = m.shown;
    m.shown = true;

    return _PopIn(
      key: ObjectKey(m),
      skip: skip,
      dx: m.mine ? 0.12 : -0.12,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: m.mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!m.mine) ...[_avatar(), const SizedBox(width: 8)],
                Flexible(child: body),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 4, left: m.mine ? 0 : 36),
              child: Text(
                _hm(m.time),
                style: const TextStyle(color: kMuted, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return _PopIn(
      key: const ValueKey('typing'),
      dx: -0.12,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _avatar(),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: _botBubbleDecoration(),
              child: const _TypingDots(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip() {
    final on = kAiOn;
    final color = on ? kGold : kMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on)
            _PulseDot(color: color)
          else
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.all(4.5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 4),
          Text(
            on ? 'AI mode' : 'Smart data mode',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(int i, String label) {
    return _PopIn(
      key: ValueKey('chip$i'),
      delay: Duration(milliseconds: 250 + i * 80),
      dy: 0.5,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _Pressable(
          onTap: _thinking ? null : () => _send(label),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGoldDark.withAlpha(120)),
            ),
            child: Text(
              label,
              style: const TextStyle(color: kGoldLight, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sendButton() {
    final canSend = _hasText && !_thinking;
    return _Pressable(
      onTap: canSend ? _send : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: canSend ? kGoldGradient : null,
          color: canSend ? null : kSurface2,
          shape: BoxShape.circle,
          border: canSend ? null : Border.all(color: Colors.white12),
          boxShadow: canSend
              ? [
                  BoxShadow(
                    color: kGold.withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (c, a) => RotationTransition(
            turns: Tween<double>(begin: 0.85, end: 1).animate(a),
            child: ScaleTransition(scale: a, child: c),
          ),
          child: _thinking
              ? const Center(
                  key: ValueKey('loading'),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: kGold,
                    ),
                  ),
                )
              : Icon(
                  Icons.send_rounded,
                  key: const ValueKey('send'),
                  color: canSend ? kInk : kMuted,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropScaffold(
      appBar: premiumBar(
        'Assistant',
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _statusChip(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _sc,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [..._msgs.map(_bubble), if (_thinking) _typingBubble()],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < _chips.length; i++) _chip(i, _chips[i]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: kBg1,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: _focus.hasFocus
                            ? [
                                BoxShadow(
                                  color: kGold.withAlpha(55),
                                  blurRadius: 18,
                                ),
                              ]
                            : [],
                      ),
                      child: TextField(
                        controller: _in,
                        focusNode: _focus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Ask about buses, fares, seats...',
                          hintStyle: const TextStyle(color: kMuted),
                          filled: true,
                          fillColor: kSurface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: const BorderSide(
                              color: kGold,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _sendButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}