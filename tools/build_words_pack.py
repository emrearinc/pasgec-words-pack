# File: tools/build_words_pack.py
# Screen: Windows / Python
# Purpose: Tabu_Kelimeler.xlsx -> packs/words_pack_v{N}.json.gz üretir + pack_meta.json yazar (version auto-increment)

import json
import gzip
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
XLSX_PATH = ROOT / "Tabu_Kelimeler.xlsx"
OUT_DIR = ROOT / "packs"
META_PATH = ROOT / "pack_meta.json"


def clean(x):
    if pd.isna(x):
        return ""
    return str(x).strip()


def load_next_version() -> int:
    if META_PATH.exists():
        meta = json.loads(META_PATH.read_text(encoding="utf-8"))
        v = int(meta.get("version", 0))
        return v + 1
    return 1


def main():
    if not XLSX_PATH.exists():
        raise FileNotFoundError(f"Excel not found: {XLSX_PATH}")

    version = load_next_version()
    out_file = OUT_DIR / f"words_pack_v{version}.json.gz"

    df = pd.read_excel(XLSX_PATH)

    # Beklenen kolonlar: Kelime, Yasaklı1..Yasaklı5
    words = []
    seen = set()

    for _, r in df.iterrows():
        word = clean(r.get("Kelime"))
        if not word:
            continue

        forbidden = [clean(r.get(f"Yasaklı{i}")) for i in range(1, 6)]
        forbidden = [x for x in forbidden if x and x.lower() != word.lower()]

        # aynı kelimeyi iki kez eklemeyi engelle
        key = word.lower()
        if key in seen:
            continue
        seen.add(key)

        if len(forbidden) < 3:
            continue

        words.append({
            "word": word,
            "forbidden": forbidden[:5],
            # Excel'de Kategori kolonu varsa kullan
            "category": clean(r.get("Kategori")) or "Genel",
            "is_active": 1
        })

    payload = {"version": version, "words": words}

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with gzip.open(out_file, "wt", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)

    META_PATH.write_text(
        json.dumps(
            {
                "version": version,
                "pack_file": str(out_file.relative_to(ROOT)).replace("\\", "/"),
                "words_count": len(words),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    print("OK:", out_file, "words:", len(words))
    print("META:", META_PATH, "version:", version)


if __name__ == "__main__":
    main()
