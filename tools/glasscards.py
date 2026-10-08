#!/usr/bin/env python3
"""Swap solid card backgrounds for .glassCard() (Liquid Glass on iOS 26, the same solid card on iOS 18).
Handles the two card idioms used in the older screens:
  .background(AppTheme.cardBackground)\n .cornerRadius(R)
  .background(\n RoundedRectangle(cornerRadius: R)\n .fill(AppTheme.cardBackground)\n )
Only exact AppTheme.cardBackground fills are touched (not cardBackgroundLight, progress tracks or tinted fills)."""
import re, sys
A = re.compile(r"\.background\(AppTheme\.cardBackground\)\s*\n(\s*)\.cornerRadius\(([^)]+)\)")
B = re.compile(r"\.background\(\s*\n\s*RoundedRectangle\(cornerRadius:\s*([^,)]+)(?:,\s*style:\s*\.continuous)?\)\s*\n\s*\.fill\(AppTheme\.cardBackground\)\s*\n\s*\)")
C = re.compile(r"\.background\(RoundedRectangle\(cornerRadius:\s*([^,)]+)(?:,\s*style:\s*\.continuous)?\)\.fill\(AppTheme\.cardBackground\)\)")
for path in sys.argv[1:]:
    s = open(path).read()
    s, a = A.subn(lambda m: f".glassCard(cornerRadius: {m.group(2)})", s)
    s, b = B.subn(lambda m: f".glassCard(cornerRadius: {m.group(1)})", s)
    s, c = C.subn(lambda m: f".glassCard(cornerRadius: {m.group(1)})", s)
    open(path, "w").write(s)
    left = len(re.findall(r"AppTheme\.cardBackground\b(?!Light)", s))
    print(f"{path}: {a + b + c} cards -> glass, {left} cardBackground uses left")
