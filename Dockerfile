# 公网部署默认：FastAPI 手机页（内存占用相对 Streamlit 更小，便于小规格云主机）
# 构建镜像需包含 data/*.csv、models/*.joblib、config.yaml（或构建后挂载卷）

FROM python:3.11-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV FOOTBALL_CONFIG=/app/config.yaml

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# 云平台会注入 PORT；本地默认 8765
ENV PORT=8765
EXPOSE 8765

CMD ["sh", "-c", "uvicorn app.mobile_server:app --host 0.0.0.0 --port ${PORT}"]
