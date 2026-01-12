# File: tools/build_words_pack.py
# Screen: Repo tool (PowerShell'den çalıştırılır)
# Purpose: Excel -> words pack (.json.gz) üretir, versiyonu otomatik artırır, pack_meta.json yazar.
# Note: --bump verilirse içerik aynı olsa bile yeni versiyon üretir.

import json, gzip, re, sys
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
XLSX_PATH = ROOT / "Tabu_Kelimeler.xlsx"
OUT_DIR   = ROOT / "packs"
META_PATH = ROOT / "pack_meta.json"

def clean(x) -> str:
    if pd.isna(x):
        return ""
    return str(x).strip()

def next_version(out_dir: Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    rx = re.compile(r"words_pack_v(\d+)\.json\.gz$", re.IGNORECASE)
    versions = []
    for p in out_dir.glob("words_pack_v*.json.gz"):
        m = rx.search(p.name)
        if m:
            versions.append(int(m.group(1)))
    return (max(versions) + 1) if versions else 1

def main():
    bump = "--bump" in sys.argv

    if not XLSX_PATH.exists():
        raise SystemExit(f"Excel bulunamadı: {XLSX_PATH}")

    df = pd.read_excel(XLSX_PATH)

    words = []
    for _, r in df.iterrows():
        word = clean(r.get("Kelime"))
        forbidden = [clean(r.get(f"Yasaklı{i}")) for i in range(1, 6)]
        forbidden = [x for x in forbidden if x and x.lower() != word.lower()]

        if not word or len(forbidden) < 3:
            continue

        # kategori Excel'de varsa al; yoksa Genel
        category = clean(r.get("Kategori")) or "Genel"

        words.append({
            "word": word,
            "forbidden": forbidden[:5],
            "category": category,
            "is_active": 1
        })

    # Eğer hiç kelime yoksa net hata verelim (sessizce "değişiklik yok" olmasın)
    if not words:
        raise SystemExit("Pack üretilemedi: Excel'den 0 kelime çıktı (en az 1 kelime ve min 3 yasaklı gerekir).")

    # Versiyon seç
    version = next_version(OUT_DIR)

    # bump yoksa: aynı payload hash'i üretebilecek durumları raporla
    out_file = OUT_DIR / f"words_pack_v{version}.json.gz"
    payload = {"version": version, "words": words}

    with gzip.open(out_file, "wt", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)

    meta = {
        "version": version,
        "packFile": f"packs/{out_file.name}",
        "wordCount": len(words)
    }
    META_PATH.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    print("OK:", out_file, "words:", len(words))
    print("META:", META_PATH)

if __name__ == "__main__":
    main()
