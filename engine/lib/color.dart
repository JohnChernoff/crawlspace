class GameColor {
  final int argb;
  const GameColor(this.argb);

  GameColor scale(double t) => GameColor.fromRgb(
    (r * t).round().clamp(0, 255),
    (g * t).round().clamp(0, 255),
    (b * t).round().clamp(0, 255),
    a,
  );

  static GameColor lerp(GameColor a, GameColor b, double t) {
    return GameColor.fromRgb(
      (a.r + (b.r - a.r) * t).round().clamp(0, 255),
      (a.g + (b.g - a.g) * t).round().clamp(0, 255),
      (a.b + (b.b - a.b) * t).round().clamp(0, 255),
      (a.a + (b.a - a.a) * t).round().clamp(0, 255),
    );
  }

  const GameColor.fromRgb(int r, int g, int b, [int a = 255])
      : argb = (a << 24) | (r << 16) | (g << 8) | b;

  int get a => (argb >> 24) & 0xFF;
  int get r => (argb >> 16) & 0xFF;
  int get g => (argb >> 8) & 0xFF;
  int get b => argb & 0xFF;
}

class GameColors {
  // Neutrals
  static const black = GameColor.fromRgb(0, 0, 0);
  static const white = GameColor.fromRgb(255, 255, 255);
  static const gray = GameColor.fromRgb(128, 128, 128);
  static const lightGray = GameColor.fromRgb(200, 200, 200);
  static const darkGray = GameColor.fromRgb(64, 64, 64);

  // Reds / Oranges
  static const red = GameColor.fromRgb(220, 20, 60);
  static const darkRed = GameColor.fromRgb(139, 0, 0);
  static const orange = GameColor.fromRgb(255, 165, 0);
  static const amber = GameColor.fromRgb(255, 191, 0);
  static const coral = GameColor.fromRgb(255, 127, 80);

  // Yellows
  static const yellow = GameColor.fromRgb(255, 255, 0);
  static const gold = GameColor.fromRgb(255, 215, 0);
  static const khaki = GameColor.fromRgb(240, 230, 140);

  // Greens
  static const green = GameColor.fromRgb(0, 200, 0);
  static const darkGreen = GameColor.fromRgb(0, 100, 0);
  static const lime = GameColor.fromRgb(0, 255, 0);
  static const olive = GameColor.fromRgb(128, 128, 0);

  // Blues
  static const blue = GameColor.fromRgb(0, 0, 255);
  static const darkBlue = GameColor.fromRgb(0, 0, 139);
  static const lightBlue = GameColor.fromRgb(128, 128, 222);
  static const skyBlue = GameColor.fromRgb(135, 206, 235);
  static const cyan = GameColor.fromRgb(0, 255, 255);
  static const teal = GameColor.fromRgb(0, 128, 128);

  // Purples / Magentas
  static const purple = GameColor.fromRgb(128, 0, 128);
  static const violet = GameColor.fromRgb(238, 130, 238);
  static const magenta = GameColor.fromRgb(255, 0, 255);
  static const indigo = GameColor.fromRgb(75, 0, 130);

  // Browns / Earth tones
  static const brown = GameColor.fromRgb(165, 42, 42);
  static const sienna = GameColor.fromRgb(160, 82, 45);
  static const tan = GameColor.fromRgb(210, 180, 140);

  // Sci-fi extras (nice for SpaceFugue vibes)
  static const neonGreen = GameColor.fromRgb(57, 255, 20);
  static const neonBlue = GameColor.fromRgb(31, 81, 255);
  static const neonPink = GameColor.fromRgb(255, 20, 147);
}
