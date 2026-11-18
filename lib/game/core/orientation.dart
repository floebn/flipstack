/// Abbildung zwischen Plattform- und Weltraster für eine Orientierung
/// `r` (Anzahl Vierteldrehungen gegen den Uhrzeigersinn, beliebige ganze Zahl).
///
/// Plattformkoordinaten ändern sich nie. Weltkoordinaten sind kamerafest.
/// Passt zu `IsoProjection.rotate`: eine Vierteldrehung bildet die zentrierte
/// Koordinate (x, y) auf (-y, x) ab.
abstract final class Orientation {
  static int normalize(int r) => ((r % 4) + 4) % 4;

  static (int, int) platformToWorld(int x, int y, int r, int n) {
    for (var k = normalize(r); k > 0; k--) {
      (x, y) = (n - 1 - y, x);
    }
    return (x, y);
  }

  static (int, int) worldToPlatform(int x, int y, int r, int n) {
    for (var k = normalize(r); k > 0; k--) {
      (x, y) = (y, n - 1 - x);
    }
    return (x, y);
  }
}
