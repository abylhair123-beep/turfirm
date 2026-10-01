import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Простая обёртка над inline-SVG иконками из макета (тот же стиль:
/// тонкая линия, скруглённые концы, без заливки — кроме звезды/сердца).
class AppIcon extends StatelessWidget {
  const AppIcon(this.svg, {super.key, this.size = 20, this.color});

  final String svg;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter:
          color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}

/// Библиотека иконок — цвет задаётся через [AppIcon.color], поэтому во всех
/// путях используется currentColor-подобный чёрный (#000), который
/// перекрашивается ColorFilter'ом.
class AppIcons {
  AppIcons._();

  static const search = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>''';

  static const bell = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M6 8a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6Z"/><path d="M10 21a2 2 0 0 0 4 0"/></svg>''';

  static const heart = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M20.8 8.6c0 5-8.8 9.9-8.8 9.9s-8.8-4.9-8.8-9.9a4.8 4.8 0 0 1 8.8-2.7 4.8 4.8 0 0 1 8.8 2.7Z"/></svg>''';

  static const star = '''
<svg viewBox="0 0 24 24" fill="#000" stroke="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2l3 6.5 7 .8-5.3 4.8 1.5 7L12 17.6 5.8 21.1l1.5-7L2 9.3l7-.8Z"/></svg>''';

  static const home = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M4 11.5 12 4l8 7.5"/><path d="M6 10v9h12v-9"/></svg>''';

  static const searchTab = search;

  static const ticket = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M5 8h14l-1 12H6L5 8Z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/></svg>''';

  static const user = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="8" r="3.4"/><path d="M5 20c1.2-4 4-6 7-6s5.8 2 7 6"/></svg>''';

  static const back = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M15 5 8 12l7 7"/></svg>''';

  static const arrowRight = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="M9 5l7 7-7 7"/></svg>''';

  static const pin = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" xmlns="http://www.w3.org/2000/svg"><path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11Z"/><circle cx="12" cy="10" r="2.4"/></svg>''';

  static const shieldCheck = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" xmlns="http://www.w3.org/2000/svg"><path d="M12 2 4 5v6c0 5 3.5 8.5 8 11 4.5-2.5 8-6 8-11V5l-8-3Z"/><path d="m9 12 2 2 4-4"/></svg>''';

  static const calendar = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>''';

  static const moon = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" xmlns="http://www.w3.org/2000/svg"><path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5Z"/></svg>''';

  static const food = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" xmlns="http://www.w3.org/2000/svg"><path d="M6 2v8M6 2c-2 1-2 5 0 6M18 2v18M6 10v10"/></svg>''';

  static const plane = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" xmlns="http://www.w3.org/2000/svg"><path d="M2 16c4-6 8 6 12 0s6 2 8-4"/><path d="m14 4 6 6-6 2 2-6-6-2Z"/></svg>''';

  static const checkCircle = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/></svg>''';

  static const check = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg"><path d="m5 13 5 5L20 7"/></svg>''';

  static const card = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 10h18"/></svg>''';

  static const plus = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.4" stroke-linecap="round" xmlns="http://www.w3.org/2000/svg"><path d="M12 5v14M5 12h14"/></svg>''';

  static const minus = '''
<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2.4" stroke-linecap="round" xmlns="http://www.w3.org/2000/svg"><path d="M5 12h14"/></svg>''';
}
