# 第一阶段：构建应用
FROM golang:1.22 AS builder

WORKDIR /build

# 复制整个源代码目录
COPY . .

# 编译Go程序 (根据项目结构选择server或desktop入口)
RUN go mod download && \
    go build -o KrillinAI ./cmd/server && \
    chmod +x ./KrillinAI

# 第二阶段：创建运行环境
FROM nvidia/cuda:12.3.2-cudnn9-runtime-ubuntu22.04

WORKDIR /app

# 安装必要依赖和中日韩字体支持
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:savoury1/ffmpeg4 && \
    apt-get update && \
    apt-get install -y ffmpeg libdav1d-dev wget ca-certificates fonts-noto-cjk && \
    rm -rf /var/lib/apt/lists/*

# 下载yt-dlp
RUN mkdir -p bin && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64) \
            URL="https://github.com/yt-dlp/yt-dlp/releases/download/2025.01.15/yt-dlp_linux"; \
            ;; \
        armv7l) \
            URL="https://github.com/yt-dlp/yt-dlp/releases/download/2025.01.15/yt-dlp_linux_armv7l"; \
            ;; \
        aarch64) \
            URL="https://github.com/yt-dlp/yt-dlp/releases/download/2025.01.15/yt-dlp_linux_aarch64"; \
            ;; \
        *) \
            echo "Unsupported architecture: $ARCH" && exit 1; \
            ;; \
    esac && \
    wget -O bin/yt-dlp "$URL" && \
    chmod +x bin/yt-dlp

# 从构建阶段复制必要文件
COPY --from=builder /build/KrillinAI /app/
COPY --from=builder /build/static /app/static
COPY --from=builder /build/config /app/config

# 创建必要的目录
RUN mkdir -p /app/models /app/tasks

# 设置卷和环境变量
VOLUME ["/app/bin", "/app/models", "/app/tasks"]
ENV PATH="/app/bin:${PATH}"

# 暴露端口
EXPOSE 8888/tcp

# 设置入口点
ENTRYPOINT ["/app/KrillinAI"]
