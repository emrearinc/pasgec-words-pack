import json, gzip
import pandas as pd
from pathlib import Path

XLSX_PATH = Path("Tabu_Kelimeler.xlsx")
OUT_DIR   = Path("packs")
OUT_FILE  = OUT_DIR / "words_pack_v1.json.gz"
VERSION   = 1

df = pd.read_excel(XLSX_PATH)

def clean(x):
    if pd.isna(x): return ""
    return str(x).strip()

words = []
for _, r in df.iterrows():
    word = clean(r.get("Kelime"))
    forbidden = [clean(r.get(f"Yasaklı{i}")) for i in range(1, 6)]
    forbidden = [x for x in forbidden if x and x.lower() != word.lower()]

    if not word or len(forbidden) < 3:
        continue

    words.append({
        "word": word,
        "forbidden": forbidden[:5],
        "category": "Genel",
        "is_active": 1
    })

payload = {"version": VERSION, "words": words}

OUT_DIR.mkdir(parents=True, exist_ok=True)
with gzip.open(OUT_FILE, "wt", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False)

print("OK:", OUT_FILE, "words:", len(words))
