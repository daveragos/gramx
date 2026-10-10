// Draws the screens that sit beside each step of docs/iphone.html, into
// docs/assets/guide/. They are drawn rather than captured, so every helper
// app and every iPhone screen comes out at the same size and in the same
// style, with a placeholder account instead of someone's real one. Run it
// after changing a figure, or after a release changes the IPA's name:
//
//   dart run tool/guide_figures.dart
import 'dart:convert';
import 'dart:io';

const _dir = 'docs/assets/guide';
const _font =
    "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif";

/// The site's accent, used for every highlight ring and badge.
const _accent = '#3cb8ff';
const _onAccent = '#00131f';
const _blue = '#007aff';
const _email = 'name@icloud.com';

late final String _ipa;
late final String _glyph;

void main() {
  final version = RegExp(
    r'^version:\s*([\d.]+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
  _ipa = 'gramx-$version.ipa';
  _glyph =
      'data:image/png;base64,'
      '${base64Encode(File('docs/assets/brand/glyph-on-dark.png').readAsBytesSync())}';
  Directory(_dir).createSync(recursive: true);

  final figures = <String, _Figure>{
    // Shared between helper apps.
    'trust-computer': _trustComputer(),
    'trust-developer': _trustDeveloper(),
    'developer-mode': _developerMode(),
    'safari-download': _safariDownload(),
    'open-gramx': _openGramx(),
    'download-ipa': _downloadIpa(),
    'itunes-icloud': _appleDownloads(icloud: true),
    'itunes': _appleDownloads(icloud: false),
    // Sideloadly.
    'sideloadly-site': _sideloadlySite(),
    'sideloadly-main': _sideloadlyMain(),
    'sideloadly-advanced': _sideloadlyAdvanced(),
    'sideloadly-signin': _sideloadlySignIn(),
    // SideStore.
    'localdevvpn': _localDevVpn(),
    'iloader-site': _iloaderSite(),
    'iloader-signin': _iloaderSignIn(),
    'iloader-install': _iloaderInstall(),
    'sidestore-refresh': _sidestoreRefresh(),
    'sidestore-add': _storeAdd(_sideStore),
    // AltStore.
    'altstore-site': _altstoreSite(),
    'wifi-sync': _wifiSync(),
    'altserver-install': _altserverInstall(),
    'altstore-add': _storeAdd(_altStore),
  };

  for (final entry in figures.entries) {
    final f = entry.value;
    final file = File('$_dir/${entry.key}.svg');
    file.writeAsStringSync(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${f.w} ${f.h}" '
      'width="${f.w}" height="${f.h}" font-family="$_font">\n'
      '<title>${_esc(f.title)}</title>\n'
      '${f.body}\n</svg>\n',
    );
    stdout.writeln('${entry.key} ${f.w}x${f.h}');
  }
}

class _Figure {
  const _Figure(this.w, this.h, this.title, this.body);
  final int w;
  final int h;
  final String title;
  final String body;
}

// ── Primitives ───────────────────────────────────────────────────────────

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _n(num v) =>
    v is int || v == v.roundToDouble() ? v.round().toString() : v.toString();

String rect(
  num x,
  num y,
  num w,
  num h, {
  num r = 0,
  String fill = 'none',
  String? stroke,
  num sw = 1,
  num? op,
  String? attrs,
}) {
  final b = StringBuffer(
    '<rect x="${_n(x)}" y="${_n(y)}" width="${_n(w)}" '
    'height="${_n(h)}"',
  );
  if (r > 0) b.write(' rx="${_n(r)}"');
  b.write(' fill="$fill"');
  if (stroke != null) b.write(' stroke="$stroke" stroke-width="${_n(sw)}"');
  if (op != null) b.write(' opacity="${_n(op)}"');
  if (attrs != null) b.write(' $attrs');
  b.write('/>');
  return b.toString();
}

String circle(
  num cx,
  num cy,
  num r, {
  String fill = 'none',
  String? stroke,
  num sw = 1,
  num? op,
}) {
  final b = StringBuffer(
    '<circle cx="${_n(cx)}" cy="${_n(cy)}" r="${_n(r)}" fill="$fill"',
  );
  if (stroke != null) b.write(' stroke="$stroke" stroke-width="${_n(sw)}"');
  if (op != null) b.write(' opacity="${_n(op)}"');
  b.write('/>');
  return b.toString();
}

String path(
  String d, {
  String fill = 'none',
  String? stroke,
  num sw = 1.5,
  String? transform,
}) {
  final b = StringBuffer('<path d="$d" fill="$fill"');
  if (stroke != null) {
    b.write(
      ' stroke="$stroke" stroke-width="${_n(sw)}" '
      'stroke-linecap="round" stroke-linejoin="round"',
    );
  }
  if (transform != null) b.write(' transform="$transform"');
  b.write('/>');
  return b.toString();
}

String text(
  num x,
  num y,
  String s, {
  num size = 13,
  String fill = '#000',
  int weight = 400,
  String anchor = 'start',
  num? op,
  String? family,
}) {
  final b = StringBuffer(
    '<text x="${_n(x)}" y="${_n(y)}" font-size="${_n(size)}" fill="$fill"',
  );
  if (weight != 400) b.write(' font-weight="$weight"');
  if (anchor != 'start') b.write(' text-anchor="$anchor"');
  if (op != null) b.write(' opacity="${_n(op)}"');
  if (family != null) b.write(' font-family="$family"');
  b.write('>${_esc(s)}</text>');
  return b.toString();
}

String lines(
  num x,
  num y,
  List<String> ls, {
  num size = 13,
  num leading = 16,
  String fill = '#000',
  int weight = 400,
  String anchor = 'start',
}) {
  final b = StringBuffer();
  for (var i = 0; i < ls.length; i++) {
    b.write(
      text(
        x,
        y + i * leading,
        ls[i],
        size: size,
        fill: fill,
        weight: weight,
        anchor: anchor,
      ),
    );
  }
  return b.toString();
}

String g(String body, {String? transform, num? op, String? attrs}) {
  final b = StringBuffer('<g');
  if (transform != null) b.write(' transform="$transform"');
  if (op != null) b.write(' opacity="${_n(op)}"');
  if (attrs != null) b.write(' $attrs');
  b.write('>$body</g>');
  return b.toString();
}

/// A drop shadow for anything that floats: alerts, menus, sheets.
const _shadow =
    '<filter id="sh" x="-20%" y="-20%" width="140%" height="160%">'
    '<feDropShadow dx="0" dy="6" stdDeviation="8" flood-opacity="0.28"/></filter>';

String badge(int n, num cx, num cy) =>
    circle(cx, cy, 11, fill: _accent) +
    text(
      cx,
      cy + 4.5,
      '$n',
      size: 13,
      weight: 800,
      fill: _onAccent,
      anchor: 'middle',
    );

/// Rings the control a step talks about. [n] numbers it when a figure
/// shows more than one thing to do.
String ring(num x, num y, num w, num h, {num r = 10, int? n}) =>
    rect(x - 5, y - 5, w + 10, h + 10, r: r, stroke: _accent, sw: 8, op: 0.25) +
    rect(x - 5, y - 5, w + 10, h + 10, r: r, stroke: _accent, sw: 2.5) +
    (n == null ? '' : badge(n, x - 5, y - 5));

String chevron(num x, num y, {String stroke = '#c4c4c6', num size = 5}) => path(
  'M${_n(x)} ${_n(y - size)} L${_n(x + size)} ${_n(y)} '
  'L${_n(x)} ${_n(y + size)}',
  stroke: stroke,
  sw: 2,
);

String tick(num cx, num cy, {String stroke = '#fff', num s = 1}) => path(
  'M${_n(cx - 4 * s)} ${_n(cy)} L${_n(cx - 1 * s)} ${_n(cy + 3 * s)} '
  'L${_n(cx + 4.5 * s)} ${_n(cy - 3.5 * s)}',
  stroke: stroke,
  sw: 2 * s,
);

// ── iPhone ───────────────────────────────────────────────────────────────

/// The top of an iPhone, cut off below [h] with a fade, so a figure can be
/// as tall as its screen needs. [screen] draws from y=8 inside the bezel.
String phone(int w, int h, String screen, {bool dark = false}) {
  final sw = w - 16;
  final fg = dark ? '#fff' : '#000';
  final status =
      text(44, 39, '9:41', size: 15, weight: 600, fill: fg) +
      rect(w / 2 - 45, 18, 90, 26, r: 13, fill: '#000') +
      // Signal, then battery.
      rect(w - 96, 32, 3, 5, r: 1, fill: fg) +
      rect(w - 91, 30, 3, 7, r: 1, fill: fg) +
      rect(w - 86, 28, 3, 9, r: 1, fill: fg) +
      rect(w - 81, 26, 3, 11, r: 1, fill: fg) +
      rect(w - 66, 26, 24, 12, r: 3.5, stroke: fg, op: 0.4) +
      rect(w - 64, 28, 20, 8, r: 2, fill: fg) +
      rect(w - 41, 29.5, 1.5, 5, r: 0.75, fill: fg, op: 0.4);
  return '<defs>'
      '<clipPath id="sc"><rect x="8" y="8" width="$sw" height="${h + 80}" rx="36"/></clipPath>'
      '<linearGradient id="fg" x1="0" y1="0" x2="0" y2="1">'
      '<stop offset="0.9" stop-color="#fff"/>'
      '<stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
      '<mask id="fm"><rect width="$w" height="$h" fill="url(#fg)"/></mask>'
      '$_shadow</defs>'
      '<g mask="url(#fm)">'
      '${rect(0, 0, w, h + 80, r: 44, fill: '#1c1c1e')}'
      '<g clip-path="url(#sc)">'
      '${rect(8, 8, sw, h + 80, fill: dark ? '#000' : '#f2f2f7')}'
      '$status$screen'
      '</g></g>';
}

String nav(int w, String title, {String back = 'Back', bool dark = false}) =>
    path('M30 64 L22 72 L30 80', stroke: dark ? '#0a84ff' : _blue, sw: 2.2) +
    text(36, 78, back, size: 17, fill: dark ? '#0a84ff' : _blue) +
    text(
      w / 2,
      78,
      title,
      size: 17,
      weight: 600,
      fill: dark ? '#fff' : '#000',
      anchor: 'middle',
    );

typedef RowDrawer = String Function(num x, num y, num w);

/// An inset grouped list, as in Settings. Rows are 44 tall.
String group(num x, num y, num w, List<RowDrawer> rows, {bool dark = false}) {
  final b = StringBuffer(
    rect(x, y, w, rows.length * 44, r: 10, fill: dark ? '#1c1c1e' : '#fff'),
  );
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) {
      b.write(
        rect(x + 16, y + i * 44, w - 16, 1, fill: dark ? '#38383a' : '#e5e5ea'),
      );
    }
    b.write(rows[i](x, y + i * 44, w));
  }
  return b.toString();
}

RowDrawer row(
  String label, {
  String? value,
  bool chevron = true,
  bool? toggle,
  String? labelFill,
  bool center = false,
  String? icon,
  bool dark = false,
}) =>
    (x, y, w) {
      final fg = labelFill ?? (dark ? '#fff' : '#000');
      final b = StringBuffer();
      var lx = x + 16;
      if (icon != null) {
        b.write(rect(x + 16, y + 7, 30, 30, r: 7, fill: icon));
        lx = x + 58;
      }
      if (center) {
        b.write(
          text(x + w / 2, y + 28, label, size: 17, fill: fg, anchor: 'middle'),
        );
        return b.toString();
      }
      b.write(text(lx, y + 28, label, size: 17, fill: fg));
      if (toggle != null) {
        b.write(toggleSwitch(x + w - 67, y + 6.5, toggle));
      } else {
        if (value != null) {
          b.write(
            text(
              x + w - (chevron ? 34 : 16),
              y + 28,
              value,
              size: 17,
              fill: '#8e8e93',
              anchor: 'end',
            ),
          );
        }
        if (chevron) b.write(chevronAt(x + w - 20, y + 22));
      }
      return b.toString();
    };

String chevronAt(num x, num y) => chevron(x, y);

String toggleSwitch(num x, num y, bool on) =>
    rect(x, y, 51, 31, r: 15.5, fill: on ? '#34c759' : '#e9e9eb') +
    circle(
      on ? x + 35.5 : x + 15.5,
      y + 15.5,
      13.5,
      fill: '#fff',
      stroke: '#0000001a',
    );

/// The small grey text under a group.
String footnote(num x, num y, List<String> ls) =>
    lines(x, y, ls, size: 13, leading: 17, fill: '#6c6c70');

String sectionLabel(num x, num y, String s) =>
    text(x, y, s.toUpperCase(), size: 13, fill: '#6c6c70');

/// An iOS alert over a dimmed screen. Buttons sit side by side, or one
/// under another when [vertical]. [bold] marks the default button, [ringOn]
/// the one to tap, numbered with [badgeN].
String alert(
  int w,
  num y, {
  required List<String> title,
  List<String> body = const [],
  required List<String> buttons,
  bool vertical = false,
  int bold = -1,
  int? ringOn,
  int? badgeN,
  bool dark = false,
  num width = 270,
}) {
  final x = (w - width) / 2;
  final fill = dark ? '#2c2c2e' : '#f7f7f7';
  final fg = dark ? '#fff' : '#000';
  final sep = dark ? '#48484a' : '#cfcfd3';
  final blue = dark ? '#0a84ff' : _blue;
  var cy = y + 20;
  final b = StringBuffer();
  final content = StringBuffer();
  for (final t in title) {
    cy += 20;
    content.write(
      text(
        x + width / 2,
        cy - 4,
        t,
        size: 17,
        weight: 600,
        fill: fg,
        anchor: 'middle',
      ),
    );
  }
  if (body.isNotEmpty) {
    cy += 6;
    for (final t in body) {
      cy += 16;
      content.write(
        text(x + width / 2, cy - 4, t, size: 13, fill: fg, anchor: 'middle'),
      );
    }
  }
  final by = cy + 12;
  final bh = vertical ? buttons.length * 44 : 44;
  final h = by + bh - y;
  b.write(rect(0, 0, w, 2000, fill: '#000', op: 0.4));
  b.write(rect(x, y, width, h, r: 14, fill: fill, attrs: 'filter="url(#sh)"'));
  b.write(content);
  b.write(rect(x, by, width, 1, fill: sep));
  for (var i = 0; i < buttons.length; i++) {
    final num bx = vertical ? x : x + i * width / buttons.length;
    final num bw = vertical ? width : width / buttons.length;
    final num byy = vertical ? by + i * 44 : by;
    if (i > 0) {
      b.write(
        vertical
            ? rect(x, byy, width, 1, fill: sep)
            : rect(bx, by, 1, 44, fill: sep),
      );
    }
    b.write(
      text(
        bx + bw / 2,
        byy + 28,
        buttons[i],
        size: 17,
        weight: i == bold ? 600 : 400,
        fill: blue,
        anchor: 'middle',
      ),
    );
  }
  if (ringOn != null) {
    final num bx = vertical ? x : x + ringOn * width / buttons.length;
    final num bw = vertical ? width : width / buttons.length;
    final num byy = vertical ? by + ringOn * 44 : by;
    b.write(ring(bx + 2, byy + 2, bw - 4, 40, r: 12, n: badgeN));
  }
  return b.toString();
}

// ── Computer windows ─────────────────────────────────────────────────────

/// A window with a plain title bar, so it reads as Windows or Mac alike.
String window(int w, int h, String title, String body, {bool dark = false}) {
  final bg = dark ? '#2b2b2b' : '#ececee';
  final bar = dark ? '#363636' : '#e0e0e3';
  return '<defs>$_shadow<clipPath id="wc"><rect x="0.5" y="0.5" '
      'width="${w - 1}" height="${h - 1}" rx="10"/></clipPath></defs>'
      '${rect(0.5, 0.5, w - 1, h - 1, r: 10, fill: bg)}'
      '<g clip-path="url(#wc)">${rect(0, 0, w, 30, fill: bar)}</g>'
      '${rect(0.5, 30, w - 1, 1, fill: dark ? '#1e1e1e' : '#cfcfd4')}'
      '${text(w / 2, 20, title, size: 12, weight: 600, fill: dark ? '#dedede' : '#3a3a3a', anchor: 'middle')}'
      '$body'
      '${rect(0.5, 0.5, w - 1, h - 1, r: 10, stroke: dark ? '#505050' : '#c3c3c8')}';
}

String card(int w, int h, {String fill = '#fff', String stroke = '#d6dadf'}) =>
    '<defs>$_shadow</defs>${rect(0.5, 0.5, w - 1, h - 1, r: 12, fill: fill, stroke: stroke)}';

String btn(
  num x,
  num y,
  num w,
  num h,
  String label, {
  String fill = '#3c3c3c',
  String color = '#e8e8e8',
  num size = 12,
  int weight = 500,
  num r = 5,
  String? stroke,
}) =>
    rect(x, y, w, h, r: r, fill: fill, stroke: stroke) +
    text(
      x + w / 2,
      y + h / 2 + size * 0.36,
      label,
      size: size,
      weight: weight,
      fill: color,
      anchor: 'middle',
    );

String field(
  num x,
  num y,
  num w,
  num h,
  String value, {
  bool dark = false,
  bool muted = false,
  num size = 11.5,
}) =>
    rect(
      x,
      y,
      w,
      h,
      r: 4,
      fill: dark ? '#1f1f1f' : '#fff',
      stroke: dark ? '#5a5a5a' : '#c6c6c8',
    ) +
    text(
      x + 8,
      y + h / 2 + size * 0.36,
      value,
      size: size,
      fill: muted
          ? (dark ? '#8a8a8a' : '#9a9a9e')
          : (dark ? '#f0f0f0' : '#111'),
    );

String dropdown(
  num x,
  num y,
  num w,
  num h,
  String value, {
  bool dark = false,
}) =>
    field(x, y, w, h, value, dark: dark) +
    path(
      'M${_n(x + w - 14)} ${_n(y + h / 2 - 2)} l4 4 l4 -4',
      stroke: dark ? '#cfcfcf' : '#555',
      sw: 1.5,
    );

String label(num x, num y, String s, {bool dark = false, num size = 12}) =>
    text(x, y, s, size: size, fill: dark ? '#d4d4d4' : '#333');

String check(
  num x,
  num y,
  String s, {
  bool checked = false,
  bool dark = false,
  num size = 12,
  int weight = 400,
}) =>
    rect(
      x,
      y,
      14,
      14,
      r: 3,
      fill: checked ? '#2f6fe4' : (dark ? '#1f1f1f' : '#fff'),
      stroke: checked ? '#2f6fe4' : (dark ? '#6a6a6a' : '#9a9a9e'),
    ) +
    (checked ? tick(x + 7, y + 7.5, s: 0.8) : '') +
    text(
      x + 20,
      y + 11.5,
      s,
      size: size,
      weight: weight,
      fill: dark ? '#e8e8e8' : '#222',
    );

/// A document icon with a label on it, as helper apps draw an IPA.
String docIcon(
  num x,
  num y,
  num w,
  String label, {
  String fill = '#fff',
  String stroke = '#9a9aa0',
  String ink = '#444',
}) {
  final h = w * 1.25;
  final f = w * 0.3;
  return path(
        'M${_n(x)} ${_n(y)} h${_n(w - f)} l${_n(f)} ${_n(f)} v${_n(h - f)} '
        'h${_n(-w)} z',
        fill: fill,
        stroke: stroke,
        sw: 1.5,
      ) +
      path(
        'M${_n(x + w - f)} ${_n(y)} v${_n(f)} h${_n(f)}',
        stroke: stroke,
        sw: 1.5,
      ) +
      text(
        x + w / 2,
        y + h * 0.72,
        label,
        size: w * 0.3,
        weight: 800,
        fill: ink,
        anchor: 'middle',
      );
}

String image(String href, num x, num y, num w, num h) =>
    '<image href="$href" x="${_n(x)}" y="${_n(y)}" width="${_n(w)}" height="${_n(h)}"/>';

String diamond(num cx, num cy, num r, {String fill = '#fff'}) => path(
  'M${_n(cx)} ${_n(cy - r)} L${_n(cx + r)} ${_n(cy)} L${_n(cx)} ${_n(cy + r)} '
  'L${_n(cx - r)} ${_n(cy)} Z',
  fill: fill,
  stroke: fill,
  sw: r * 0.5,
);

// ── Shared figures ───────────────────────────────────────────────────────

_Figure _trustComputer() {
  const w = 320, h = 290;
  const wallpaper =
      '<defs><linearGradient id="wp" x1="0" y1="0" x2="1" y2="1">'
      '<stop offset="0" stop-color="#9bb8e8"/><stop offset="1" stop-color="#e3c9ea"/>'
      '</linearGradient></defs>';
  final screen =
      wallpaper +
      rect(8, 8, w - 16, h + 80, fill: 'url(#wp)') +
      text(
        w / 2,
        150,
        '9:41',
        size: 72,
        weight: 300,
        fill: '#fff',
        anchor: 'middle',
        op: 0.9,
      ) +
      alert(
        w,
        60,
        title: ['Trust This Computer?'],
        body: [
          'Your settings and data will be',
          'accessible from this computer',
          'when connected.',
        ],
        buttons: ['Trust', 'Don’t Trust'],
        vertical: true,
        bold: 0,
        ringOn: 0,
      );
  return _Figure(
    w,
    h,
    'The iPhone asks whether to trust this computer.',
    phone(w, h, screen),
  );
}

_Figure _trustDeveloper() {
  const w = 320, h = 448;
  final screen =
      nav(w, _email) +
      footnote(24, 112, [
        'Apps from developer “iPhone Developer:',
        '$_email (ABCDE12345)” are not',
        'trusted on this iPhone and will not run',
        'until the developer is trusted.',
      ]) +
      group(16, 176, w - 32, [
        row('Trust “$_email”', center: true, labelFill: _blue),
      ]) +
      ring(16, 176, w - 32, 44, r: 12, n: 1) +
      alert(
        w,
        232,
        title: ['Trust “iPhone Developer:', '$_email”', 'Apps on This iPhone'],
        body: [
          'Trusting will allow any app from this',
          'developer to be used on your iPhone',
          'and may allow access to your data.',
        ],
        buttons: ['Cancel', 'Trust'],
        bold: 1,
        ringOn: 1,
        badgeN: 2,
      );
  return _Figure(
    w,
    h,
    'Settings: the page for your Apple Account, with its Trust button and the confirmation.',
    phone(w, h, screen),
  );
}

_Figure _developerMode() {
  const w = 320, h = 330;
  final screen =
      nav(w, 'Developer Mode') +
      group(16, 104, w - 32, [row('Developer Mode', toggle: true)]) +
      ring(16, 104, w - 32, 44, r: 12, n: 1) +
      footnote(24, 166, [
        'Developer Mode lets apps installed outside',
        'the App Store run. It reduces your iPhone’s security.',
      ]) +
      alert(
        w,
        184,
        title: [
          'Turning on Developer Mode',
          'requires restarting your iPhone.',
        ],
        buttons: ['Cancel', 'Restart'],
        bold: 1,
        ringOn: 1,
        badgeN: 2,
      );
  return _Figure(
    w,
    h,
    'Settings: Developer Mode switched on, and the prompt to restart.',
    phone(w, h, screen),
  );
}

_Figure _safariDownload() {
  const w = 320, h = 300;
  final page =
      rect(8, 8, w - 16, h + 80, fill: '#fff') +
      rect(24, 70, 120, 14, r: 4, fill: '#e8e8ec') +
      rect(24, 96, 272, 10, r: 3, fill: '#efeff2') +
      rect(24, 114, 240, 10, r: 3, fill: '#efeff2') +
      rect(24, 132, 256, 10, r: 3, fill: '#efeff2') +
      rect(24, 160, 272, 60, r: 10, fill: '#f4f4f7') +
      // Safari's address bar, at the bottom.
      rect(8, 240, w - 16, 140, fill: '#f8f8fa') +
      rect(24, 250, 272, 36, r: 10, fill: '#e9e9ee') +
      text(w / 2, 273, 'github.com', size: 15, fill: '#333', anchor: 'middle') +
      alert(
        w,
        90,
        title: ['Do you want to download', '“$_ipa”?'],
        buttons: ['Cancel', 'Download'],
        bold: 1,
        ringOn: 1,
      );
  return _Figure(
    w,
    h,
    'Safari asks whether to download the gramX file.',
    phone(w, h, page),
  );
}

_Figure _openGramx() {
  const w = 320, h = 400;
  final screen =
      rect(8, 8, w - 16, h + 80, fill: '#f9f9f9') +
      rect(w / 2 - 36, 60, 72, 72, r: 18, fill: '#000') +
      image(_glyph, w / 2 - 20, 74, 40, 44) +
      text(
        w / 2,
        170,
        'Welcome to gramX',
        size: 22,
        weight: 800,
        fill: '#171717',
        anchor: 'middle',
      ) +
      text(
        w / 2,
        194,
        'Your Telegram channels, as one timeline.',
        size: 14,
        fill: '#536471',
        anchor: 'middle',
      ) +
      rect(32, 220, w - 64, 46, r: 23, fill: _accent) +
      rect(w / 2 - 114, 235, 10, 16, r: 2, stroke: '#fff', sw: 1.6) +
      text(
        w / 2 + 6,
        248,
        'Continue with Phone Number',
        size: 14,
        weight: 700,
        fill: '#fff',
        anchor: 'middle',
      ) +
      rect(32, 278, w - 64, 46, r: 23, stroke: '#cfd9de', sw: 1.5) +
      rect(w / 2 - 86, 294, 5, 5, fill: '#171717') +
      rect(w / 2 - 79, 294, 5, 5, fill: '#171717') +
      rect(w / 2 - 86, 301, 5, 5, fill: '#171717') +
      rect(w / 2 - 79, 301, 5, 5, fill: '#171717') +
      text(
        w / 2 + 6,
        306,
        'Log in via QR Code',
        size: 14,
        weight: 700,
        fill: '#171717',
        anchor: 'middle',
      ) +
      text(
        w / 2,
        354,
        'Browse without an account',
        size: 14,
        weight: 700,
        fill: '#536471',
        anchor: 'middle',
      );
  return _Figure(
    w,
    h,
    'The gramX welcome screen: continue with a phone number, log in via QR code, or browse without an account.',
    phone(w, h, screen),
  );
}

_Figure _downloadIpa() {
  const w = 360, h = 150;
  final body =
      card(w, h) +
      text(16, 32, 'Downloads', size: 14, weight: 700, fill: '#171717') +
      rect(w - 48, 18, 32, 20, r: 10, fill: '#eef1f4') +
      path('M${w - 36} 24 l4 4 l4 -4', stroke: '#536471', sw: 1.6) +
      rect(16, 50, w - 32, 76, r: 10, fill: '#f5f7f9') +
      docIcon(30, 62, 36, 'IPA') +
      text(84, 80, _ipa, size: 14, weight: 700, fill: '#171717') +
      text(84, 100, '24 MB · github.com · Done', size: 12, fill: '#536471') +
      text(84, 118, 'Show in folder', size: 12, fill: '#0f6ea6') +
      ring(16, 50, w - 32, 76, r: 12);
  return _Figure(
    w,
    h,
    'The browser’s downloads list showing the gramX file, finished.',
    body,
  );
}

_Figure _appleDownloads({required bool icloud}) {
  const w = 360;
  final h = icloud ? 200 : 134;
  final b = StringBuffer(card(w, h));
  b.write(
    text(
      16,
      26,
      'FROM APPLE’S WEBSITE',
      size: 11,
      weight: 700,
      fill: '#536471',
    ),
  );
  var y = 42;
  String rowOf(String name, String sub, String icon, int y) =>
      rect(16, y, w - 32, 56, r: 10, fill: '#f5f7f9') +
      icon +
      text(76, y + 24, name, size: 14, weight: 700, fill: '#171717') +
      text(76, y + 42, sub, size: 12, fill: '#536471') +
      btn(
        w - 108,
        y + 15,
        80,
        26,
        'Download',
        fill: '#0071e3',
        color: '#fff',
        r: 13,
        weight: 600,
      ) +
      ring(w - 108, y + 15, 80, 26, r: 16);
  b.write(
    '<defs><linearGradient id="it" x1="0" y1="0" x2="1" y2="1">'
    '<stop offset="0" stop-color="#f26fb6"/><stop offset="1" stop-color="#8a4cf0"/></linearGradient>'
    '<linearGradient id="ic" x1="0" y1="0" x2="0" y2="1">'
    '<stop offset="0" stop-color="#6fc0ff"/><stop offset="1" stop-color="#1a7be8"/></linearGradient></defs>',
  );
  b.write(
    rowOf(
      'iTunes for Windows',
      '64-bit',
      circle(46, y + 28, 18, fill: 'url(#it)') +
          text(
            46,
            y + 35,
            '♪',
            size: 20,
            weight: 700,
            fill: '#fff',
            anchor: 'middle',
          ),
      y,
    ),
  );
  if (icloud) {
    y += 66;
    b.write(
      rowOf(
        'iCloud for Windows',
        'Needed next to iTunes',
        rect(28, y + 10, 36, 36, r: 9, fill: 'url(#ic)') +
            path(
              'M-10 5 a5 5 0 0 1 1 -9 a7 7 0 0 1 13 -2 a5 5 0 0 1 5 11 z',
              fill: '#fff',
              transform: 'translate(46 ${y + 28})',
            ),
        y,
      ),
    );
  }
  y += 66;
  b.write(circle(28, y + 10, 8, stroke: '#f4212e', sw: 1.8));
  b.write(
    path('M24 ${y + 6} l8 8 M32 ${y + 6} l-8 8', stroke: '#f4212e', sw: 1.8),
  );
  b.write(
    text(
      44,
      y + 14,
      'Not the Microsoft Store versions',
      size: 12,
      fill: '#536471',
    ),
  );
  return _Figure(
    w,
    h,
    icloud
        ? 'Download buttons for iTunes and iCloud from Apple’s website, not the Microsoft Store.'
        : 'The download button for iTunes from Apple’s website, not the Microsoft Store.',
    b.toString(),
  );
}

// ── Sideloadly ───────────────────────────────────────────────────────────

_Figure _sideloadlySite() {
  const w = 360, h = 164;
  final body =
      card(w, h, fill: '#0c0c16', stroke: '#2a2a3c') +
      rect(16, 16, 40, 40, r: 10, fill: '#1b2a3a') +
      circle(36, 36, 11, stroke: '#3fd0c9', sw: 2.5) +
      path('M36 29 v12 M31 37 l5 5 l5 -5', stroke: '#3fd0c9', sw: 2.2) +
      text(68, 34, 'Sideloadly', size: 16, weight: 700, fill: '#fff') +
      text(68, 52, 'sideloadly.io', size: 12, fill: '#9a9ab0') +
      btn(
        16,
        76,
        160,
        40,
        'Download for macOS',
        fill: '#7c5cf6',
        color: '#fff',
        size: 13,
        weight: 600,
        r: 10,
      ) +
      btn(
        188,
        76,
        100,
        40,
        'Windows',
        fill: '#1a1a2a',
        color: '#fff',
        size: 13,
        weight: 600,
        r: 10,
        stroke: '#33334a',
      ) +
      ring(16, 76, 272, 40, r: 14) +
      text(
        16,
        142,
        'Free · macOS 10.12+ · Windows 7+',
        size: 11,
        fill: '#7a7a90',
      );
  return _Figure(w, h, 'The download buttons on sideloadly.io.', body);
}

String _sideloadlyTop({bool rings = true, bool advanced = false}) =>
    rect(16, 46, 72, 72, r: 6, fill: '#3a3a3a', stroke: '#555') +
    docIcon(
      35,
      58,
      34,
      'IPA',
      fill: 'none',
      stroke: '#e6e6e6',
      ink: '#e6e6e6',
    ) +
    text(52, 132, _ipa, size: 9.5, fill: '#dcdcdc', anchor: 'middle') +
    (rings ? ring(16, 46, 72, 90, r: 9, n: 1) : '') +
    label(104, 57, 'iDevice:', dark: true) +
    dropdown(104, 63, 196, 22, 'iPhone (18.6)', dark: true) +
    btn(306, 63, 22, 22, '', fill: '#3c3c3c', stroke: '#555') +
    btn(334, 63, 22, 22, '', fill: '#3c3c3c', stroke: '#555') +
    (rings ? ring(104, 63, 196, 22, r: 8, n: 2) : '') +
    label(104, 105, 'Apple account:', dark: true) +
    field(104, 111, 252, 22, _email, dark: true) +
    (rings ? ring(104, 111, 252, 22, r: 8, n: 3) : '') +
    btn(
      104,
      143,
      252,
      20,
      'Advanced options',
      fill: advanced ? '#4a4a4a' : '#3c3c3c',
      stroke: '#555',
    );

_Figure _sideloadlyMain() {
  const w = 380, h = 224;
  final body =
      _sideloadlyTop() +
      btn(16, 176, 348, 22, 'Start', fill: '#3c3c3c', stroke: '#555') +
      text(w / 2, 214, 'Idle.', size: 11, fill: '#dcdcdc', anchor: 'middle');
  return _Figure(
    w,
    h,
    'Sideloadly with the gramX file dropped on the IPA box, your iPhone selected, and your Apple Account typed in.',
    window(w, h, 'Sideloadly!', body, dark: true),
  );
}

_Figure _sideloadlyAdvanced() {
  const w = 380, h = 300;
  final body =
      _sideloadlyTop(rings: false, advanced: true) +
      rect(16, 172, 348, 72, r: 5, fill: '#333', stroke: '#484848') +
      label(26, 190, 'App name:', dark: true, size: 11) +
      field(90, 178, 100, 18, 'gramX', dark: true, size: 10.5) +
      label(26, 214, 'Bundle ID:', dark: true, size: 11) +
      field(
        90,
        202,
        100,
        18,
        'automatic',
        dark: true,
        muted: true,
        size: 10.5,
      ) +
      label(26, 236, 'Min iOS:', dark: true, size: 11) +
      field(90, 224, 48, 16, '15.0', dark: true, size: 10.5) +
      check(
        204,
        180,
        'Use automatic bundle ID',
        checked: true,
        dark: true,
        size: 11,
        weight: 600,
      ) +
      ring(200, 176, 152, 22, r: 8, n: 1) +
      check(206, 204, 'Remove restrictions', dark: true, size: 11) +
      check(206, 224, 'Tweak injection', dark: true, size: 11) +
      btn(16, 252, 348, 22, 'Start', fill: '#3c3c3c', stroke: '#555') +
      ring(16, 252, 348, 22, r: 8, n: 2) +
      text(w / 2, 290, 'Idle.', size: 11, fill: '#dcdcdc', anchor: 'middle');
  return _Figure(
    w,
    h,
    'Sideloadly’s advanced options, with Use automatic bundle ID ticked, and the Start button.',
    window(w, h, 'Sideloadly!', body, dark: true),
  );
}

_Figure _sideloadlySignIn() {
  const w = 380, h = 250;
  String dialog(
    num y,
    String title,
    List<String> body,
    String fieldValue, {
    bool muted = false,
  }) =>
      rect(
        24,
        y,
        332,
        94,
        r: 8,
        fill: '#3a3a3a',
        stroke: '#5a5a5a',
        attrs: 'filter="url(#sh)"',
      ) +
      text(38, y + 22, title, size: 12.5, weight: 700, fill: '#f0f0f0') +
      lines(38, y + 40, body, size: 11, leading: 14, fill: '#cfcfcf') +
      field(
        38,
        y + 46 + (body.length - 1) * 14,
        200,
        20,
        fieldValue,
        dark: true,
        muted: muted,
      ) +
      btn(
        258,
        y + 62,
        40,
        20,
        'Cancel',
        fill: '#4a4a4a',
        stroke: '#666',
        size: 11,
      ) +
      btn(
        306,
        y + 62,
        36,
        20,
        'OK',
        fill: '#2f6fe4',
        color: '#fff',
        size: 11,
        weight: 600,
      );
  final body =
      dialog(40, 'Apple Account password', [
        'Enter the password for $_email.',
      ], '••••••••••') +
      dialog(
        142,
        'Verification code',
        [
          'Enter the six-digit code shown on your',
          'other Apple devices, or sent by text.',
        ],
        '— — — — — —',
        muted: true,
      );
  return _Figure(
    w,
    h,
    'Sideloadly asks for your Apple Account password, then for the verification code.',
    window(w, h, 'Sideloadly!', body, dark: true),
  );
}

// ── SideStore ────────────────────────────────────────────────────────────

_Figure _localDevVpn() {
  const w = 320, h = 372;
  final screen =
      circle(w - 36, 92, 14, fill: '#1c1c1e') +
      circle(w - 36, 92, 5, stroke: '#c7c7cc', sw: 1.8) +
      text(24, 122, 'LocalDevVPN', size: 26, weight: 700, fill: '#fff') +
      rect(16, 138, w - 32, 90, r: 16, fill: '#1c1c1e') +
      text(32, 162, 'Current status', size: 14, weight: 600, fill: '#fff') +
      circle(58, 198, 22, fill: '#2c2c2e') +
      circle(58, 198, 9, stroke: '#8e8e93', sw: 1.8) +
      path('M51 191 l14 14', stroke: '#8e8e93', sw: 1.8) +
      text(140, 203, 'Disconnected', size: 15, weight: 500, fill: '#fff') +
      rect(16, 240, w - 32, 110, r: 16, fill: '#1c1c1e') +
      text(32, 264, 'Connection', size: 14, weight: 600, fill: '#fff') +
      text(
        32,
        280,
        'Start or stop the secure local tunnel.',
        size: 11,
        fill: '#8e8e93',
      ) +
      rect(32, 294, w - 64, 40, r: 12, fill: '#0a84ff') +
      text(
        w / 2,
        319,
        'Connect',
        size: 15,
        weight: 600,
        fill: '#fff',
        anchor: 'middle',
      ) +
      ring(32, 294, w - 64, 40, r: 15, n: 1) +
      alert(
        w,
        72,
        title: ['“LocalDevVPN” Would Like', 'to Add VPN Configurations'],
        body: [
          'All network activity on this iPhone may',
          'be filtered or monitored when using',
          'a VPN.',
        ],
        buttons: ['Don’t Allow', 'Allow'],
        bold: 1,
        ringOn: 1,
        badgeN: 2,
        dark: true,
      );
  return _Figure(
    w,
    h,
    'LocalDevVPN with its Connect button, and the iPhone asking to allow a VPN configuration.',
    phone(w, h, screen, dark: true),
  );
}

_Figure _iloaderSite() {
  const w = 360, h = 176;
  final body =
      card(w, h, fill: '#161616', stroke: '#2e2e2e') +
      rect(16, 16, 40, 40, r: 10, fill: '#1f6b2f') +
      path('M36 26 v13 M30 33 l6 6 l6 -6 M27 44 h18', stroke: '#fff', sw: 2.4) +
      text(68, 34, 'iloader', size: 16, weight: 700, fill: '#fff') +
      text(68, 52, 'iloader.app', size: 12, fill: '#9a9a9a') +
      text(16, 86, 'Windows', size: 12, weight: 600, fill: '#e8e8e8') +
      text(16, 102, 'needs iTunes', size: 10.5, fill: '#8a8a8a') +
      btn(
        120,
        76,
        108,
        32,
        'MSI Installer',
        fill: '#2a2a2a',
        stroke: '#444',
        size: 12,
        weight: 600,
        r: 8,
      ) +
      btn(
        236,
        76,
        108,
        32,
        'EXE Installer',
        fill: '#2a2a2a',
        stroke: '#444',
        size: 12,
        weight: 600,
        r: 8,
      ) +
      ring(120, 76, 224, 32, r: 12) +
      text(16, 136, 'macOS', size: 12, weight: 600, fill: '#e8e8e8') +
      btn(
        120,
        126,
        108,
        32,
        'DMG Installer',
        fill: '#2a2a2a',
        stroke: '#444',
        size: 12,
        weight: 600,
        r: 8,
      ) +
      ring(120, 126, 108, 32, r: 12);
  return _Figure(
    w,
    h,
    'The download buttons on iloader.app, for Windows and for Mac.',
    body,
  );
}

String _iloaderPanel(num x, num y, num w, num h) =>
    rect(x, y, w, h, r: 8, fill: '#262626', stroke: '#3a3a3a');

_Figure _iloaderSignIn() {
  const w = 400, h = 230;
  final body =
      text(16, 48, 'ACCOUNT', size: 9, weight: 700, fill: '#8a8a8a') +
      _iloaderPanel(16, 54, 200, 158) +
      text(30, 78, 'Apple ID', size: 14, weight: 700, fill: '#fff') +
      label(30, 98, 'Email', dark: true, size: 10) +
      field(30, 103, 172, 20, _email, dark: true, size: 10.5) +
      label(30, 136, 'Password', dark: true, size: 10) +
      field(30, 141, 172, 20, '••••••••••', dark: true, size: 10.5) +
      btn(
        30,
        174,
        172,
        24,
        'Sign In',
        fill: '#2f6fe4',
        color: '#fff',
        size: 12,
        weight: 600,
        r: 6,
      ) +
      ring(30, 174, 172, 24, r: 9, n: 1) +
      rect(
        232,
        66,
        152,
        128,
        r: 8,
        fill: '#333',
        stroke: '#555',
        attrs: 'filter="url(#sh)"',
      ) +
      text(
        308,
        90,
        'Verification code',
        size: 12,
        weight: 700,
        fill: '#f0f0f0',
        anchor: 'middle',
      ) +
      lines(
        308,
        108,
        ['Enter the code Apple sent', 'to your other devices.'],
        size: 10,
        leading: 13,
        fill: '#cfcfcf',
        anchor: 'middle',
      ) +
      [
        for (var i = 0; i < 6; i++)
          rect(
            244 + i * 22,
            134,
            18,
            24,
            r: 4,
            fill: '#1f1f1f',
            stroke: '#5a5a5a',
          ),
      ].join() +
      btn(
        244,
        166,
        128,
        20,
        'Continue',
        fill: '#2f6fe4',
        color: '#fff',
        size: 11,
        weight: 600,
      ) +
      ring(244, 166, 128, 20, r: 8, n: 2);
  return _Figure(
    w,
    h,
    'iloader’s Apple ID panel with the Sign In button, and the verification code prompt.',
    window(w, h, 'iloader', body, dark: true),
  );
}

_Figure _iloaderInstall() {
  const w = 400, h = 232;
  final body =
      text(16, 48, 'DEVICES', size: 9, weight: 700, fill: '#8a8a8a') +
      _iloaderPanel(16, 54, 368, 66) +
      text(30, 76, 'iDevice', size: 14, weight: 700, fill: '#fff') +
      rect(30, 86, 340, 26, r: 5, fill: '#26405f', stroke: '#3b5f8d') +
      text(40, 103, 'iPhone  ·  USB', size: 11.5, weight: 600, fill: '#fff') +
      rect(304, 92, 58, 14, r: 4, fill: '#dfe6f5') +
      text(
        333,
        102.5,
        'Selected',
        size: 9,
        weight: 700,
        fill: '#1e2a3a',
        anchor: 'middle',
      ) +
      ring(30, 86, 340, 26, r: 9, n: 1) +
      text(16, 142, 'INSTALLERS', size: 9, weight: 700, fill: '#8a8a8a') +
      btn(
        16,
        148,
        118,
        32,
        'SideStore (Stable)',
        fill: '#2a2a2a',
        stroke: '#444',
        size: 11,
        weight: 600,
        r: 6,
      ) +
      btn(
        142,
        148,
        118,
        32,
        'SideStore (Nightly)',
        fill: '#2a2a2a',
        stroke: '#444',
        size: 11,
        weight: 500,
        r: 6,
      ) +
      btn(
        268,
        148,
        116,
        32,
        'Import IPA',
        fill: '#2a2a2a',
        stroke: '#444',
        size: 11,
        weight: 500,
        r: 6,
      ) +
      ring(16, 148, 118, 32, r: 10, n: 2) +
      rect(16, 194, 368, 26, r: 6, fill: '#1c3a26', stroke: '#2f8f4f') +
      tick(32, 207, stroke: '#4ad66d', s: 1.1) +
      text(
        46,
        211,
        'SideStore Installed!',
        size: 12,
        weight: 700,
        fill: '#4ad66d',
      );
  return _Figure(
    w,
    h,
    'iloader with your iPhone selected, the SideStore (Stable) button, and the message that SideStore was installed.',
    window(w, h, 'iloader', body, dark: true),
  );
}

class _Store {
  const _Store(
    this.name,
    this.author,
    this.tint,
    this.g1,
    this.g2,
    this.rowFill,
  );
  final String name;
  final String author;
  final String tint;
  final String g1;
  final String g2;
  final String rowFill;
}

const _sideStore = _Store(
  'SideStore',
  'SideStore Team',
  '#6f4fd8',
  '#8b5cf6',
  '#ec6fb0',
  '#f3eefc',
);
const _altStore = _Store(
  'AltStore',
  'Riley Testut',
  '#1f8f8a',
  '#1aa39a',
  '#2bcbb8',
  '#e9f6f4',
);

/// The top of the My Apps tab, shared by SideStore and AltStore.
String _myApps(int w, _Store s, {int? plusBadge, bool ringDays = false}) =>
    '<defs><linearGradient id="st" x1="0" y1="0" x2="1" y2="1">'
    '<stop offset="0" stop-color="${s.g1}"/><stop offset="1" stop-color="${s.g2}"/></linearGradient></defs>'
    '${rect(8, 8, w - 16, 2000, fill: '#fff')}'
    '${path('M30 100 v16 M22 108 h16', stroke: s.tint, sw: 2.2)}'
    '${plusBadge == null ? '' : ring(16, 94, 28, 28, r: 14, n: plusBadge)}'
    '${text(24, 150, 'My Apps', size: 30, weight: 800, fill: '#000')}'
    '${rect(24, 162, w - 48, 24, r: 12, fill: '#e8f7f5')}'
    '${text(w / 2, 178, 'No Updates Available', size: 12, weight: 500, fill: '#1f8f8a', anchor: 'middle')}'
    '${text(24, 212, 'Active', size: 20, weight: 700, fill: '#000')}'
    '${text(w - 24, 212, 'Refresh All', size: 14, weight: 500, fill: s.tint, anchor: 'end')}'
    '${rect(16, 224, w - 32, 64, r: 14, fill: s.rowFill)}'
    '${rect(28, 234, 44, 44, r: 11, fill: 'url(#st)')}'
    '${diamond(50, 256, 12)}'
    '${text(84, 252, s.name, size: 15, weight: 700, fill: '#000')}'
    '${text(84, 270, s.author, size: 12, fill: '#6c6c70')}'
    '${text(w - 28, 246, 'Expires in', size: 9, fill: '#6c6c70', anchor: 'end')}'
    '${rect(w - 88, 251, 60, 24, r: 12, fill: '#3fb552')}'
    '${text(w - 58, 267, '7 DAYS', size: 11, weight: 700, fill: '#fff', anchor: 'middle')}'
    '${ringDays ? ring(w - 88, 251, 60, 24, r: 16, n: 1) : ''}';

String _tabBar(int w, int y, _Store s) {
  final names = ['News', 'Browse', 'My Apps', 'Settings'];
  final b = StringBuffer(rect(8, y, w - 16, 90, fill: '#f8f8f8'));
  b.write(rect(8, y, w - 16, 1, fill: '#e0e0e3'));
  for (var i = 0; i < names.length; i++) {
    final cx = 8 + (w - 16) * (i + 0.5) / 4;
    final on = i == 2;
    final c = on ? s.tint : '#9a9aa0';
    b.write(rect(cx - 10, y + 10, 20, 18, r: 4, stroke: c, sw: 1.8));
    b.write(
      text(
        cx,
        y + 42,
        names[i],
        size: 10,
        weight: on ? 600 : 400,
        fill: c,
        anchor: 'middle',
      ),
    );
  }
  return b.toString();
}

_Figure _sidestoreRefresh() {
  const w = 320, h = 340;
  final screen =
      _myApps(w, _sideStore, ringDays: true) + _tabBar(w, 300, _sideStore);
  return _Figure(
    w,
    h,
    'SideStore’s My Apps tab, with the 7 DAYS button next to SideStore.',
    phone(w, h, screen),
  );
}

_Figure _storeAdd(_Store s) {
  const w = 320, h = 372;
  final screen =
      _myApps(w, s, plusBadge: 1) +
      rect(0, 0, w, 2000, fill: '#000', op: 0.3) +
      rect(
        8,
        222,
        w - 16,
        220,
        r: 14,
        fill: '#f2f2f7',
        attrs: 'filter="url(#sh)"',
      ) +
      rect(w / 2 - 18, 230, 36, 5, r: 2.5, fill: '#c7c7cc') +
      text(
        w / 2,
        260,
        'Downloads',
        size: 17,
        weight: 600,
        fill: '#000',
        anchor: 'middle',
      ) +
      text(w - 24, 260, 'Cancel', size: 17, fill: _blue, anchor: 'end') +
      rect(16, 278, w - 32, 56, r: 10, fill: '#fff') +
      docIcon(30, 286, 30, 'IPA') +
      text(76, 300, _ipa, size: 14, weight: 600, fill: '#000') +
      text(76, 319, 'Today · 24 MB', size: 12, fill: '#6c6c70') +
      ring(16, 278, w - 32, 56, r: 13, n: 2);
  return _Figure(
    w,
    h,
    '${s.name}’s My Apps tab with the plus button at the top, and the gramX file chosen from Downloads.',
    phone(w, h, screen),
  );
}

// ── AltStore ─────────────────────────────────────────────────────────────

String _altIcon(num x, num y, num s) =>
    rect(x, y, s, s, r: s * 0.24, fill: '#1aa39a') +
    diamond(x + s / 2, y + s / 2, s * 0.26);

_Figure _altstoreSite() {
  const w = 360, h = 206;
  final body =
      card(w, h, fill: '#0f1716', stroke: '#24302e') +
      _altIcon(16, 16, 40) +
      text(68, 34, 'AltStore', size: 16, weight: 700, fill: '#fff') +
      text(68, 52, 'altstore.io', size: 12, fill: '#9aa8a6') +
      rect(w - 118, 20, 102, 22, r: 11, stroke: '#2bcbb8') +
      text(
        w - 67,
        35,
        'AltStore Classic',
        size: 11,
        weight: 600,
        fill: '#2bcbb8',
        anchor: 'middle',
      ) +
      btn(
        16,
        76,
        160,
        40,
        'AltServer for Mac',
        fill: '#1fa38f',
        color: '#fff',
        size: 13,
        weight: 600,
        r: 10,
      ) +
      btn(
        188,
        76,
        156,
        40,
        'AltServer for Windows',
        fill: '#1a2422',
        color: '#fff',
        size: 13,
        weight: 600,
        r: 10,
        stroke: '#2e3c39',
      ) +
      ring(16, 76, 328, 40, r: 14) +
      rect(16, 140, 328, 24, r: 5, fill: '#e8e8ea') +
      _altIcon(250, 144, 16) +
      rect(276, 147, 18, 10, r: 2.5, stroke: '#333') +
      rect(278, 149, 12, 6, r: 1, fill: '#333') +
      text(
        330,
        157,
        '9:41',
        size: 11,
        weight: 500,
        fill: '#111',
        anchor: 'end',
      ) +
      ring(248, 142, 20, 20, r: 8) +
      text(
        16,
        186,
        'AltServer runs in the menu bar, or near the clock on Windows.',
        size: 10.5,
        fill: '#9aa8a6',
      );
  return _Figure(
    w,
    h,
    'The AltServer download buttons on altstore.io, and where its icon appears once it runs.',
    body,
  );
}

_Figure _wifiSync() {
  const w = 400, h = 244;
  String panel(
    num y,
    String heading,
    String optionsLabel,
    List<String> opts,
    int checked,
    int n,
  ) =>
      rect(
        0.5,
        y + 0.5,
        w - 1,
        117,
        r: 10,
        fill: '#f5f5f7',
        stroke: '#cfcfd4',
      ) +
      text(16, y + 18, heading, size: 10, weight: 700, fill: '#6c6c70') +
      text(16, y + 52, optionsLabel, size: 12, weight: 600, fill: '#222') +
      [
        for (var i = 0; i < opts.length; i++)
          check(
            90,
            y + 41 + i * 21,
            opts[i],
            checked: i == checked,
            size: 11.5,
          ),
      ].join() +
      ring(86, y + 37 + checked * 21, 214, 22, r: 8, n: n) +
      btn(
        w - 72,
        y + 86,
        56,
        22,
        'Apply',
        fill: '#fff',
        color: '#222',
        stroke: '#b8b8bd',
        size: 11,
        r: 6,
      );
  const defs = '<defs>$_shadow</defs>';
  final body =
      defs +
      panel(
        0,
        'FINDER · MAC',
        'Options:',
        [
          'Show this iPhone when on Wi-Fi',
          'Automatically sync when connected',
          'Manually manage music and videos',
        ],
        0,
        1,
      ) +
      panel(
        126,
        'ITUNES · WINDOWS',
        'Options',
        [
          'Automatically sync when connected',
          'Sync with this iPhone over Wi-Fi',
          'Sync only checked songs and videos',
        ],
        1,
        2,
      );
  return _Figure(
    w,
    h,
    'The Wi-Fi sync box: Show this iPhone when on Wi-Fi in Finder on a Mac, or Sync with this iPhone over Wi-Fi in iTunes on Windows.',
    body,
  );
}

_Figure _altserverInstall() {
  const w = 380, h = 262;
  final menuItems = [
    'Install AltStore',
    'Enable JIT',
    'Install Mail Plug-in',
    'Launch at Login',
    'Quit AltServer',
  ];
  final b = StringBuffer('<defs>$_shadow</defs>');
  b.write(rect(0.5, 0.5, w - 1, 26, r: 6, fill: '#ececee', stroke: '#cfcfd4'));
  b.write(rect(214, 2, 24, 22, r: 5, fill: '#2f6fe4'));
  b.write(_altIcon(218, 5, 16));
  b.write(rect(262, 8, 18, 10, r: 2.5, stroke: '#333'));
  b.write(rect(264, 10, 12, 6, r: 1, fill: '#333'));
  b.write(
    text(
      w - 14,
      18,
      'Fri 9:41',
      size: 11,
      weight: 500,
      fill: '#111',
      anchor: 'end',
    ),
  );
  // The menu, with its submenu open on Install AltStore.
  b.write(
    rect(
      120,
      30,
      150,
      132,
      r: 8,
      fill: '#fff',
      stroke: '#d7d7dc',
      attrs: 'filter="url(#sh)"',
    ),
  );
  for (var i = 0; i < menuItems.length; i++) {
    final y = 38 + i * 24;
    final on = i == 0;
    if (on) b.write(rect(126, y - 2, 138, 22, r: 5, fill: '#2f6fe4'));
    b.write(
      text(138, y + 13, menuItems[i], size: 12.5, fill: on ? '#fff' : '#111'),
    );
    if (i < 2) {
      b.write(chevron(254, y + 9, stroke: on ? '#fff' : '#9a9aa0', size: 4));
    }
    if (i == 3) b.write(tick(132, y + 9, stroke: '#111', s: 0.8));
  }
  b.write(rect(126, 128, 138, 1, fill: '#e0e0e3'));
  b.write(
    rect(
      268,
      30,
      96,
      48,
      r: 8,
      fill: '#fff',
      stroke: '#d7d7dc',
      attrs: 'filter="url(#sh)"',
    ),
  );
  b.write(rect(274, 36, 84, 22, r: 5, fill: '#2f6fe4'));
  b.write(text(286, 51, 'iPhone', size: 12.5, fill: '#fff'));
  b.write(ring(274, 36, 84, 22, r: 8, n: 1));
  // AltServer's sign-in dialog.
  b.write(
    rect(
      16,
      150,
      348,
      100,
      r: 8,
      fill: '#fff',
      stroke: '#cfcfd4',
      attrs: 'filter="url(#sh)"',
    ),
  );
  b.write(_altIcon(28, 164, 28));
  b.write(
    text(
      68,
      170,
      'Please enter your Apple ID and password.',
      size: 12,
      weight: 700,
      fill: '#111',
    ),
  );
  b.write(
    text(
      68,
      184,
      'They are sent to Apple only, to allow sideloading.',
      size: 10,
      fill: '#6c6c70',
    ),
  );
  b.write(field(68, 192, 150, 20, _email, size: 10.5));
  b.write(field(226, 192, 120, 20, '••••••••', size: 10.5));
  b.write(
    btn(
      236,
      220,
      50,
      20,
      'Cancel',
      fill: '#fff',
      color: '#222',
      stroke: '#b8b8bd',
      size: 11,
      r: 6,
    ),
  );
  b.write(
    btn(
      294,
      220,
      52,
      20,
      'Install',
      fill: '#2f6fe4',
      color: '#fff',
      size: 11,
      weight: 600,
      r: 6,
    ),
  );
  b.write(ring(294, 220, 52, 20, r: 8, n: 2));
  return _Figure(
    w,
    h,
    'The AltServer menu with Install AltStore open and your iPhone listed, and the Apple ID sign-in it shows next.',
    b.toString(),
  );
}
