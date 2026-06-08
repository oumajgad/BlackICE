from pathlib import Path
from decimal import Decimal, ROUND_HALF_UP
import re

root = Path('history/provinces')
pattern = re.compile(r'^(?P<leading>\s*manpower\s*=\s*)(?P<value>[0-9]+(?:\.[0-9]+)?)(?P<rest>\s*(?:#.*)?)$', re.IGNORECASE)
files = list(root.rglob('*.txt'))
modified = 0
changes = []
pop_pattern = re.compile(r'^(?P<indent>\s*)population\s*=.*$', re.IGNORECASE)
for file in files:
    text = file.read_text(encoding='cp1252')
    lines = text.splitlines(keepends=True)
    new_lines = []
    changed = False
    i = 0
    while i < len(lines):
        line = lines[i]
        m = pattern.match(line)
        if m:
            orig = m.group('value')
            val = Decimal(orig)
            newval = (val / Decimal('2')).quantize(Decimal('0.0001'), rounding=ROUND_HALF_UP)
            s = format(newval.normalize(), 'f')
            if '.' in s:
                s = s.rstrip('0').rstrip('.') if '.' in s else s
            if s == '-0':
                s = '0'
            if s != orig:
                line = f"{m.group('leading')}{s}{m.group('rest')}\n"
                changes.append((str(file), orig, s))
            new_lines.append(line)

            next_line = lines[i + 1] if i + 1 < len(lines) else None
            if next_line is not None and pop_pattern.match(next_line):
                indent = pop_pattern.match(next_line).group('indent')
                population_line = f"{indent}population = 10\n"
                if next_line != population_line:
                    new_lines.append(population_line)
                    changed = True
                else:
                    new_lines.append(next_line)
                i += 2
                continue
            else:
                new_lines.append('population = 10\n')
                changed = True
                i += 1
                continue
        new_lines.append(line)
        i += 1

    if changed:
        file.write_text(''.join(new_lines), encoding='cp1252')
        modified += 1

print(f"Processed {len(files)} files. Modified {modified} files.")
for p,o,n in changes[:100]:
    print(f'{p}: {o} -> {n}')
