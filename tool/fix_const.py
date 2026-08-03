"""Remove the enclosing `const` for flagged flipping-color usages.

After making BeeColors surface/text colors brightness-aware getters, every
`const` widget that references one of them is now an invalid_constant. This
finds the innermost `const` whose bracket range encloses each flagged color and
strips it. Run repeatedly (idempotent) until `flutter analyze` is clean.
"""
import re
import sys

FLIP = r'BeeColors\.(bg|surface|surfaceHi|cellText|outerCellText|muted|outerFace|outerFaceTop|outerFaceSide)\b'

# file -> list of 1-indexed line numbers flagged by the analyzer
TARGETS = {
    'lib/screens/game_screen.dart': [223, 336, 392, 395, 431, 439, 612, 643, 715],
    'lib/screens/home_screen.dart': [104, 202, 206, 266, 274],
    'lib/screens/how_to_screen.dart': [132, 167],
    'lib/screens/import_screen.dart': [204, 230, 289, 295, 300],
    'lib/screens/paywall_screen.dart': [60, 94, 103],
    'lib/screens/results_screen.dart': [71, 77, 144, 167],
    'lib/screens/settings_screen.dart': [313],
    'lib/screens/stats_screen.dart': [65, 84, 90, 120, 133, 147],
    'lib/widgets/timers_bar.dart': [61],
}

OPEN, CLOSE = '([{', ')]}'


def innermost_const(text, pos):
    """Return the start index of the innermost `const` keyword whose bracketed
    body encloses `pos`, or None."""
    best = None
    for m in re.finditer(r'\bconst\b', text):
        c = m.start()
        if c >= pos:
            break
        om = re.search(r'[\(\[]', text[c:pos + 1])
        if not om:
            continue
        openp = c + om.start()
        depth = 0
        close = None
        for i in range(openp, len(text)):
            ch = text[i]
            if ch in OPEN:
                depth += 1
            elif ch in CLOSE:
                depth -= 1
                if depth == 0:
                    close = i
                    break
        if close is not None and openp < pos <= close:
            best = c  # later (deeper) enclosing const wins
    return best


def fix_file(path, lines):
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    removed = 0
    # process flagged lines bottom-to-top so earlier line contents stay stable
    for ln in sorted(lines, reverse=True):
        starts = [len(x) for x in text.split('\n')]
        # absolute index of start of line ln
        abs_start = sum(len(x) + 1 for x in text.split('\n')[:ln - 1])
        line_text = text.split('\n')[ln - 1]
        m = re.search(FLIP, line_text)
        if not m:
            continue
        pos = abs_start + m.start()
        c = innermost_const(text, pos)
        if c is None:
            continue
        # strip 'const' + following whitespace
        text = text[:c] + re.sub(r'^const\s+', '', text[c:], count=1)
        removed += 1
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    return removed


total = 0
for path, lines in TARGETS.items():
    n = fix_file(path, lines)
    total += n
    print(f'{path}: removed {n} const')
print(f'total {total}')
