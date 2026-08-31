import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

const _navy = Color(0xFF092B61);
const _green = Color(0xFF14951F);
const _bodyColor = Color(0xFF596276);

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFF),
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundDecorations()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final landscape =
                    constraints.maxWidth > constraints.maxHeight &&
                    constraints.maxHeight <= 600;
                final content = landscape
                    ? _LandscapeLayout(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      )
                    : _PortraitLayout(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        textScale: textScale,
                      );

                // Con escalas habituales la pantalla es fija. El desplazamiento
                // solo se activa como protección para accesibilidad excepcional.
                if (textScale <= 1.3) return content;

                return SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.width,
    required this.height,
    required this.textScale,
  });

  final double width;
  final double height;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final compact =
        width < 380 || height < 740 || (width < 600 && textScale > 1);
    final compressed =
        compact &&
        height < 760 &&
        (textScale > 1.2 ||
            (textScale >= 1.14 && (width <= 320 || height < 680)));
    final dense = compact || height < 790;
    final horizontalPadding = width < 360 ? 14.0 : (width < 600 ? 20.0 : 28.0);
    final availableWidth = math.max(
      0.0,
      math.min(width - horizontalPadding * 2, 560.0),
    );
    final accessibilityCompression = textScale > 1.15 ? 0.82 : 1.0;
    final logoHeight = math.min(
      availableWidth / 1.487,
      (compressed ? 92.0 : (compact ? 170.0 : (height < 880 ? 205.0 : 232.0))) *
          accessibilityCompression,
    );
    final topBottomPadding = dense ? 6.0 : 12.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 920),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topBottomPadding,
            horizontalPadding,
            topBottomPadding,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Logo(height: logoHeight),
              _WelcomeCopy(compact: compact, compressed: compressed),
              _Benefits(compact: compact, compressed: compressed),
              _RoleButtons(compact: compact, compressed: compressed),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final compressed = height < 380;
    final padding = compressed ? 6.0 : 18.0;
    final logoHeight = math.min(height * (compressed ? 0.36 : 0.43), 170.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              Expanded(
                flex: 9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Logo(height: logoHeight),
                    const SizedBox(height: 4),
                    _WelcomeCopy(compact: true, compressed: compressed),
                  ],
                ),
              ),
              SizedBox(width: width < 700 ? 12 : 28),
              Expanded(
                flex: 11,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Benefits(compact: true, compressed: compressed),
                    SizedBox(height: compressed ? 5 : 9),
                    _RoleButtons(
                      compact: true,
                      landscape: true,
                      compressed: compressed,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Refanet, la red nacional de autopartes usadas',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1203 / 809,
              child: Image.asset(
                'assets/images/refanet_logo_transparent.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({required this.compact, this.compressed = false});

  final bool compact;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: const [
              TextSpan(text: '¡Bienvenido a '),
              TextSpan(
                text: 'refa',
                style: TextStyle(color: _navy),
              ),
              TextSpan(
                text: 'Net!',
                style: TextStyle(color: _green),
              ),
            ],
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _navy,
              fontSize: compressed ? 20 : (compact ? 24 : 30),
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: compressed ? 3 : (compact ? 5 : 9)),
        Text(
          'La plataforma que conecta clientes con yonkes para encontrar las mejores autopartes usadas.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: _bodyColor,
            fontSize: compressed ? 11.5 : (compact ? 14 : 16),
            fontWeight: FontWeight.w400,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits({required this.compact, this.compressed = false});

  final bool compact;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Benefit(
              compact: compact,
              compressed: compressed,
              icon: Icons.search,
              title: 'Encuentra',
              color: const Color(0xFF139321),
              description: 'Busca autopartes de forma rápida y sencilla.',
            ),
          ),
          const _BenefitDivider(),
          Expanded(
            child: _Benefit(
              compact: compact,
              compressed: compressed,
              icon: Icons.sell_outlined,
              title: 'Cotiza',
              color: const Color(0xFF0A4199),
              description:
                  'Compara precios y condiciones de diferentes yonkes.',
            ),
          ),
          const _BenefitDivider(),
          Expanded(
            child: _Benefit(
              compact: compact,
              compressed: compressed,
              icon: Icons.handshake_outlined,
              title: 'Ahorra',
              color: const Color(0xFF139321),
              description: 'Elige la mejor opción y ahorra en tus compras.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.compact,
    required this.compressed,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final bool compact;
  final bool compressed;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final circleSize = compressed ? 36.0 : (compact ? 50.0 : 60.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 8),
      child: Column(
        children: [
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: color.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: compressed ? 22 : (compact ? 29 : 34),
              color: color,
            ),
          ),
          SizedBox(height: compressed ? 3 : (compact ? 5 : 8)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontSize: compressed ? 11 : (compact ? 14 : 16),
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          SizedBox(height: compressed ? 2 : (compact ? 3 : 6)),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF17191F),
              fontSize: compressed ? 8.3 : (compact ? 10.5 : 12.5),
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFFDDE0E6),
    );
  }
}

class _RoleButtons extends StatelessWidget {
  const _RoleButtons({
    required this.compact,
    this.landscape = false,
    this.compressed = false,
  });

  final bool compact;
  final bool landscape;
  final bool compressed;

  @override
  Widget build(BuildContext context) {
    final height = compressed ? 48.0 : (compact || landscape ? 58.0 : 66.0);

    return Column(
      children: [
        _RoleButton(
          icon: Icons.person,
          label: 'Soy cliente',
          semanticLabel: 'Continuar como cliente',
          colors: const [Color(0xFF119823), Color(0xFF0E871C)],
          height: height,
          onTap: () => context.push(AppRoutes.clientLogin),
        ),
        SizedBox(height: compressed ? 6 : (compact || landscape ? 8 : 11)),
        _RoleButton(
          icon: Icons.storefront,
          label: 'Soy Yonke',
          semanticLabel: 'Continuar como yonke',
          colors: const [Color(0xFF114EB0), Color(0xFF093A91)],
          height: height,
          onTap: () => context.push(AppRoutes.yonkeLogin),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.colors,
    required this.height,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final List<Color> colors;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            gradient: LinearGradient(colors: colors),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: math.max(48, height),
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: height < 60 ? 12 : 18,
                      child: Container(
                        width: height * 0.68,
                        height: height * 0.68,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: colors.first,
                          size: height * 0.39,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontSize: height < 60 ? 20 : 25,
                            fontWeight: FontWeight.w800,
                            height: 1,
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

class _BackgroundDecorations extends StatelessWidget {
  const _BackgroundDecorations();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            top: -86,
            left: -88,
            child: _Ring(color: Color(0x1849AC53), size: 170),
          ),
          const Positioned(top: 34, right: 24, child: _DotMatrix()),
          const Positioned(
            right: -110,
            bottom: -126,
            child: _Ring(color: Color(0x180B4AA5), size: 224),
          ),
          const Positioned(
            bottom: 34,
            left: 28,
            child: _DotMatrix(color: Color(0x18139321)),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 20),
      ),
    );
  }
}

class _DotMatrix extends StatelessWidget {
  const _DotMatrix({this.color = const Color(0x180B4AA5)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 69,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(
          16,
          (_) => Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
