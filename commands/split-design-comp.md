# デザインカンプ分割スキル

`.cursor/rules/design-comp-split.mdc` に従い、選択したデザインカンプ画像をセクション単位に切り出す。各セクション画像と JSON を `design-comps/` 以下に保存する。

## 使い方

```
/split-design-comp
```

引数は不要。スキル起動後に対象画像を選択できる。

---

## 手順

### 1. 対象画像の選択（必須・最初に行う）

Glob ツールで `design-comps/**/*.png` および `design-comps/**/*.jpg` を検索し、見つかった**全画像ファイル**の一覧をユーザーに提示する。

**ユーザーに選択を促すメッセージ例:**
> `design-comps/` 内に以下の画像が見つかりました。分割対象にするファイルを選んでください。
>
> 1. `design-comps/pages/top/00_full_comp.png`
> 2. `design-comps/pages/about/about.png`
> 3. `design-comps/pages/contact/contact_full.png`
> …
>
> 番号またはパスで指定してください。

ユーザーが選択したパスを `INPUT` として以降の手順で使用する。  
`PAGE` は `INPUT` が属するフォルダ名（`os.path.basename(os.path.dirname(INPUT))`）から取得する。

---

### 2. ルール読み込み（必須・画像選択と並行可）

**`.cursor/rules/design-comp-split.mdc` を Read ツールで開いて全文を読み込む。**  
次に `.cursor/rules/project-pages.mdc` を読み込み、`[page-name]` を確定する（表の **design-comps フォルダ** 列の値が正）。

読み込んだ内容から以下を把握する:
- 出力ディレクトリ構造
- Header / KV / Footer / Main セクションの分割ロジック
- ファイル命名規則（`01_kv_comp.png` から始まる・`00_full_comp.png` に JSON 不要）
- JSON データ仕様（`role` / `elements` 構造、font-size テーブル、カラー変数一覧）
- 対応するカスタムプロパティが存在しない色の扱い（ユーザーに確認）
- §5 の条件分岐（クライアント独自のコーディングルールがあるかどうかによる KV 配置・ロゴタグの使い分け）

---

### 3. Python 依存確認

```bash
pip install Pillow numpy -q
```

---

### 4. Phase 1 — 境界分析とデバッグクロップ生成

以下のロジックで `_split_tmp.py` を生成・実行する。  
**目的**: セクション境界を推定し、各領域の切り出し画像（デバッグ用）を生成して視覚確認する。

```python
from PIL import Image
import numpy as np, os, sys

INPUT = sys.argv[1] if len(sys.argv) > 1 else "design-comps/pages/top/00_full_comp.png"
PAGE  = os.path.basename(os.path.dirname(INPUT))  # e.g. "about"

img = Image.open(INPUT).convert("RGB")
arr = np.array(img)
h, w = arr.shape[:2]
print(f"画像サイズ: {w}x{h}")

# キャンバス行判定（行の標準偏差が低い = 均一な背景色）
row_stds  = np.array([arr[y].astype(np.float32).reshape(-1).std() for y in range(h)])
row_means = arr.mean(axis=1)[:, :3]

# キャンバス色（std 最小行の平均色）
canvas_y = int(row_stds.argmin())
canvas_c = np.array(arr[canvas_y].mean(axis=0)[:3], dtype=int)
print(f"キャンバス色: RGB{tuple(canvas_c)} (y={canvas_y})")

# キャンバスギャップ行: std<10 かつ canvas_dist<20
canvas_dist = np.abs(row_means.astype(int) - canvas_c).sum(axis=1)
is_canvas   = (row_stds < 10) & (canvas_dist < 20)

# コンテンツ区間を検出
sections = []
prev_end = 0
in_gap = False; gs = 0
for y in range(h):
    if is_canvas[y]:
        if not in_gap:
            if y - prev_end >= 30:
                sections.append((prev_end, y - 1))
            gs = y; in_gap = True
    else:
        if in_gap:
            prev_end = y; in_gap = False
if prev_end < h - 30:
    sections.append((prev_end, h - 1))

print(f"\n検出されたセクション ({len(sections)}件):")
for i, (s, e) in enumerate(sections):
    mean = row_means[s:e+1].mean(axis=0)
    print(f"  [{i}] y={s:4d}-{e:4d}  ({e-s+1}px)  "
          f"mean=({int(mean[0])},{int(mean[1])},{int(mean[2])})")

# デバッグクロップ生成
os.makedirs("design-comps/_debug", exist_ok=True)
for i, (s, e) in enumerate(sections):
    path = f"design-comps/_debug/{i:02d}_sec_{s}-{e}.png"
    img.crop((0, s, w, e + 1)).save(path)
    print(f"  saved: {path}")
```

---

### 5. Phase 1 の視覚確認

生成された `design-comps/_debug/*.png` を **すべて** Read ツールで開いて内容を確認する。  
以下の点を確認・記録する:

- 各セクションが何を表しているか（Header / KV / コンテンツ名 / Footer）
- セクション境界が正しいか、複数のデバッグ画像を結合すべきか
- 背景色が `--color-*` カスタムプロパティに対応しているか
- Figma キャンバス色と同じ背景のセクション（HTML では背景指定なしの可能性）
- KV の暗背景と次セクション（明背景）の切れ目の y 座標

境界の調整が必要な場合は、追加でピクセル単位のデバッグクロップを生成して確認する（境界付近のみ再クロップ）。

---

### 6. Phase 2 — 確定境界で本番分割

境界が確定したら、以下のスクリプトで本番用の分割画像を生成する。  
`SECTIONS` リストは Phase 1 の視覚確認結果をもとに**手動で確定**する。

```python
from PIL import Image
import numpy as np, os, sys

INPUT = sys.argv[1] if len(sys.argv) > 1 else "design-comps/pages/top/00_full_comp.png"
PAGE  = os.path.basename(os.path.dirname(INPUT))

img = Image.open(INPUT).convert("RGB")
arr = np.array(img)
h, w = arr.shape[:2]
row_stds = np.array([arr[y].astype(np.float32).reshape(-1).std() for y in range(h)])
canvas_y = int(row_stds.argmin())
canvas_c = np.array(arr[canvas_y].mean(axis=0)[:3], dtype=int)

def crop_trim(y0, y1, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    crop = img.crop((0, y0, w, y1 + 1))
    rgba = crop.convert("RGBA")
    d = np.array(rgba)
    mask = np.abs(d[:, :, :3].astype(int) - canvas_c).sum(axis=2) < 20
    d[mask, 3] = 0
    bb = Image.fromarray(d, "RGBA").getbbox()
    out = crop.crop(bb) if bb else crop
    out.save(path)
    print(f"  {path}  ({out.size[0]}x{out.size[1]})")

# ↓ 視覚確認後に確定した境界を記入する
SECTIONS = [
    # (y0, y1, 出力パス)
    (0,    79,   f"design-comps/layout/header/header_comp.png"),
    (0,    999,  f"design-comps/pages/{PAGE}/01_kv_comp.png"),
    # (1020, 1619, f"design-comps/pages/{PAGE}/02_[name]_comp.png"),
    # ...
    (5952, 6381, f"design-comps/layout/footer/footer_comp.png"),
]

print(f"\n{INPUT}: {w}x{h}\n")
for y0, y1, path in SECTIONS:
    crop_trim(y0, y1, path)
print("\n完了。")
```

**命名規則（`design-comp-split.mdc` §3 準拠）:**
- KV は `01_kv_comp.png`（連番 `01` 固定）
- 以降は `02_[name]_comp.png` から連番
- `00_full_comp.png` は入力元・トリム不要・JSON 不要

---

### 7. 本番画像の視覚確認

出力された各 `*_comp.png` を Read ツールで開いて内容・切り取り範囲を確認する。  
問題があれば SECTIONS の境界を修正して再実行する。

---

### 8. 色の確認（JSON 生成前に必須）

各セクションの背景色・テキスト色を `.cursor/rules/design-comp-split.mdc` のカラー変数リストと照合する。

**対応するカスタムプロパティが存在しない色が出現した場合はユーザーに確認する（固定値を使わない）。**

確認例:
> 「`05_news` の背景色 ≈ #666666 に対応するカスタムプロパティが `_base.scss` に見当たりません。  
> 新しいカスタムプロパティとして追加しますか？それとも既存のプロパティで代替しますか？」

---

### 9. JSON 生成

各セクション画像と同じ階層に `[name].json` を生成する。  
**仕様はすべて `.cursor/rules/design-comp-split.mdc` §4 に従う。**

- `color` / `background` / `border-color` → `var(--color-*)`
- `font-family` → `var(--font-family-base)`
- `font-size` → 直接 rem 値
- `font-weight` → 直接数値（見出し=600 / 本文=500）
- デザインが写真背景 / オーバーレイの場合は `"note": "背景は photo + 暗いオーバーレイ"` と記載し、`background` プロパティは省略する
- 背景色が Figma キャンバス色と一致する場合（HTML で背景指定なしの可能性）は `"note"` に明記する
- `00_full_comp.png` の JSON は生成しない

---

### 10. クリーンアップ

```python
import shutil, os
shutil.rmtree("design-comps/_debug", ignore_errors=True)
os.remove("_split_tmp.py")
```

---

### 11. 完了報告

生成したファイルの一覧と各セクションの概要をユーザーに報告する。  
`_base.scss` に追加が必要なカスタムプロパティがあれば明示する。
