# 足球比赛预测系统

基于历史比赛数据，预测主胜 / 平局 / 客胜及大致比分；Poisson / Dixon–Coles 与随机森林融合，Streamlit 交互界面。

## 项目结构

```
.
├── config.yaml           # 数据路径、训练参数、是否滚动 CV 等
├── data/                 # 数据集
├── notebooks/
├── src/
│   ├── config.py
│   ├── data_loader.py
│   ├── model.py          # Poisson / Dixon–Coles
│   ├── ml_model.py       # 特征、训练、评估
│   └── predictor.py      # 推理接口
├── app/
│   ├── app.py            # Streamlit 主界面
│   └── streamlit_app.py  # 兼容入口
├── scripts/
│   ├── train_ml.py       # 训练并保存 models/ml_bundle.joblib
│   ├── download_bundesliga.py   # 仅德甲 D1
│   └── download_football_data_leagues.py  # 多联赛（五大联赛等）
├── models/               # 训练产物（joblib）
├── tests/
├── requirements.txt
└── README.md
```

## 环境

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## 不同联赛用不同模型（推荐）

同一套特征 pipeline，但 **每个联赛单独训练一个 `joblib`**，预测时按 CSV 里的 `Div` 自动加载，避免「德甲模型硬套英冠」。

1. 准备含多联赛的 `data/*.csv`（`Div` 列）。
2. 训练单个联赛：  
   `python scripts/train_ml.py --league E1 --data data/championship_5y.csv`  
   默认输出 `models/ml_bundle_E1.joblib`。
3. 在 `config.yaml` 中配置：

```yaml
league_models:
  D1: models/ml_bundle_D1.joblib
  E1: models/ml_bundle_E1.joblib
```

未列出的 `Div` 会回退到 `paths.ml_bundle`。

批量训练：`python scripts/train_all_leagues.py --data data/multi.csv --leagues D1 E1 E0`

代码入口：`predictor.load_predictor_for_league("E1")`、`config.get_model_path_for_league`。

## 数据只有德甲？

默认示例文件 `data/bundesliga_football_data_5y.csv` 来自脚本 **`scripts/download_bundesliga.py`**，只拉了德国 **D1**，所以只有德甲。

要加入英超、西甲、意甲、法甲等，可用 **`scripts/download_football_data_leagues.py`**（同源 [football-data.co.uk](https://www.football-data.co.uk/data.php)）：

```bash
python scripts/download_football_data_leagues.py
```

默认下载 **D1, E0, SP1, I1, F1**（德甲/英超/西甲/意甲/法甲）近五季，输出 `data/multi_league_football_data_5y.csv`。自定义：

```bash
python scripts/download_football_data_leagues.py --leagues D1 E0 --out data/my_leagues.csv
```

然后在 `config.yaml` 里把 `paths.data_csv` 改成该文件，再重新 `python scripts/train_ml.py`。Streamlit 里 `Div` 会列出多个联赛代码供选择。

## 重新训练（特征或代码更新后务必执行）

在项目根目录执行：

```bash
python scripts/train_ml.py
```

- 读取 `config.yaml` 中的 `paths.data_csv`、`training.*`、`model.*`。
- 产物写入 `config.yaml` 的 `paths.ml_bundle`（默认 `models/ml_bundle.joblib`）。

可选：仅关闭滚动 CV 以加快训练（与下面 `run_cv` 二选一逻辑一致）：

```bash
python scripts/train_ml.py --no-cv
```

### 滚动 CV 指标（会变慢）

需要 TimeSeriesSplit 多折的 **accuracy / Brier 均值±方差** 时，在 `config.yaml` 中设置：

```yaml
training:
  run_cv: true
```

保持 `run_cv: false` 可缩短训练时间（最终仍有时序划分的测试集指标）。

## 运行 Web

```bash
python -m streamlit run app/app.py
```

也可：`streamlit run app/streamlit_app.py`

## 配置与环境变量

- `FOOTBALL_CONFIG`：配置文件路径（默认项目根 `config.yaml`）。
- `FOOTBALL_DATA_CSV`、`FOOTBALL_ML_BUNDLE`：覆盖数据与模型路径（见 `src/config.py`）。
- `FOOTBALL_DATABASE_URL`：覆盖 `paths.database_url`（默认 `sqlite:///data/football.db`）。

## 多联赛数据库（可行性与用法）

**可行**：把「全球各联赛赛果」放进本地库（或定期同步），**预测时**再按所选联赛导出时间序列、构造特征并推理——与当前 CSV 流程一致，只是数据源从文件换成 DB/API。

**现实限制**：没有任何一个免费接口稳定覆盖「几乎所有联赛」；通常需要 **商业 API**（如 API-Football、Sportmonks）+ 你自己的同步任务写入 `data/football.db`。本仓库提供：

- `src/db/store.py`：SQLite 表 `leagues` / `teams` / `matches`，`leagues.code` 对应原 CSV 的 `Div`（如 `D1`）。
- `scripts/import_csv_to_db.py`：把现有 CSV 导入库，便于迁移与测试。
- `src/db/analysis.py`：`predict_sync(...)` 从库读联赛 → `build_single_match_feature_row_from_df` → 与文件预测一致。
- 「后台分析」：若预测耗时高，可把 `predict_sync` 放进 **Celery/RQ** 任务；`enqueue_prediction_analysis` 为占位。

**注意**：模型仍按「特征列」训练；多联赛混训时需统一 `Div`/赔率等 schema，或 **分联赛训练多个 bundle**。

## 许可证

待定。
