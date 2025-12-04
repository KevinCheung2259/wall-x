# Wall-X Docker Image
# 基于 NVIDIA CUDA 镜像以支持 GPU 加速
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/opt/conda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# 设置工作目录
WORKDIR /workspace

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    wget \
    vim \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    ninja-build \
    && rm -rf /var/lib/apt/lists/*

# 安装 Miniconda
RUN curl -o ~/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda clean -ya

# 创建 Python 3.10 环境
RUN conda create -n wallx python=3.10 -y && \
    conda clean -ya

# 激活环境并设置为默认
ENV PATH=/opt/conda/envs/wallx/bin:$PATH
SHELL ["/bin/bash", "-c"]

# 复制项目文件
# 注意：构建前需要先在宿主机初始化 submodule：git submodule update --init --recursive
COPY requirements.txt /workspace/
COPY setup.py /workspace/
COPY pyproject.toml /workspace/
COPY csrc /workspace/csrc
COPY wall_x /workspace/wall_x
COPY scripts /workspace/scripts
COPY train_qact.py /workspace/
COPY README.md /workspace/

# 复制 3rdparty（submodule）- 必须在宿主机上先初始化
COPY 3rdparty /workspace/3rdparty

# 安装 Python 依赖
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt

# 安装 Flash Attention（限制并行编译作业数以避免内存不足）
RUN MAX_JOBS=4 pip install --no-cache-dir --no-build-isolation flash-attn==2.7.4.post1

# 安装 LeRobot
RUN git clone https://github.com/huggingface/lerobot.git /tmp/lerobot && \
    cd /tmp/lerobot && \
    git checkout c66cd401767e60baece16e1cf68da2824227e076 && \
    pip install --no-cache-dir -e . && \
    cd /workspace && \
    rm -rf /tmp/lerobot/.git

# 安装 Wall-X（编译 CUDA 扩展）
# 注意：3rdparty 已通过 COPY 包含，无需再初始化 submodule
RUN MAX_JOBS=4 pip install --no-build-isolation --verbose .

# 创建模型和数据目录
RUN mkdir -p /workspace/models /workspace/data /workspace/logs

# 暴露服务端口（用于 WebSocket 服务）
EXPOSE 8000

# 设置默认命令
CMD ["/bin/bash"]

