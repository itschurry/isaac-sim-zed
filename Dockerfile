# NVIDIA 공식 Isaac Sim 이미지 (버전은 사용 중인 것에 맞게 수정, 예: 2023.1.1 or 4.0.0)
FROM nvcr.io/nvidia/isaac-sim:5.1.0

# ---------------------------------------------------------
# 1. Root 권한으로 전환하여 필수 도구 설치
# ---------------------------------------------------------
USER root

RUN apt-get update && apt-get install -y \
    sudo \
    git \
    vim \
    curl \
    wget \
    unzip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 2. 'isaac-sim' 사용자(기본 사용자)에게 sudo 권한 부여
# ---------------------------------------------------------
ARG USER_ID=1234
# (비밀번호 없이 sudo 사용 가능하도록 설정 - 기존 파일을 덮어쓰지 않고 추가)
RUN echo "isaac-sim ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ---------------------------------------------------------
# 3. CUDA Toolkit 설치 (ZED SDK를 위해 필수!)
# ---------------------------------------------------------
# Isaac Sim이 사용하는 CUDA 버전과 맞춰야 합니다. (예: 12.1)
# Toolkit만 설치(--toolkit)해서 용량을 조금이라도 아낍니다.
ARG CUDA_VER_MAJOR=12
ARG CUDA_VER_MINOR=8
RUN wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda_12.8.1_570.124.06_linux.run \
    && chmod +x cuda_*.run \
    && ./cuda_*.run --silent --toolkit --override \
    && rm cuda_*.run

# 3. 환경 변수 설정 (이제 /usr/local/cuda가 생겼으니 잡아줍니다)
ENV PATH=/usr/local/cuda/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# 3. NVIDIA Repo 등록 (cuDNN, TensorRT 설치용)
# 24.04용 Keyring을 받아야 합니다.
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb \
    && dpkg -i cuda-keyring_1.1-1_all.deb \
    && rm cuda-keyring_1.1-1_all.deb \
    && apt-get update

# 4. cuDNN 9 설치 (중요: Ubuntu 24.04는 cuDNN 9가 표준)
# 'libcudnn9-cuda-12' 패키지를 사용합니다.
RUN apt-get install -y --no-install-recommends \
    libcudnn9-cuda-12 \
    libcudnn9-dev-cuda-12

# 5. TensorRT 설치 
# ZED SDK 5.x + Ubuntu 24.04는 보통 최신 TensorRT(8.6 or 10)를 지원합니다.
# 일단 메타 패키지로 설치하여 의존성을 자동 해결합니다.
RUN apt-get install -y --no-install-recommends \
    tensorrt \
    libnvinfer-dev \
    libnvinfer-plugin-dev \
    libnvonnxparsers-dev

# ---------------------------------------------------------
# 4. Install ZED SDK 5.1.0
# ---------------------------------------------------------
# ZED SDK 설치 시 필요한 의존성 미리 설치
RUN apt-get update && apt-get install -y --no-install-recommends \
    libusb-1.0-0-dev \
    libhidapi-libusb0 \
    libopenblas-dev \
    libpng-dev \
    libturbojpeg \
    zstd \
    lsb-release \
    libqt5opengl5 \
    libqt5xml5 \
    libarchive-dev \
    libqt5svg5 \
    && rm -rf /var/lib/apt/lists/*

# ZED SDK 다운로드 및 설치 (Silent Mode)
ARG ZED_SDK_URL="https://download.stereolabs.com/zedsdk/5.1/cu12/ubuntu24"

WORKDIR /tmp
RUN wget -q --no-check-certificate -O ZED_SDK_Linux.run ${ZED_SDK_URL} && \
    chmod +x ZED_SDK_Linux.run && \
    # Silent install 옵션: 드라이버 제외, 툴 포함, CUDA 체크 무시
    ./ZED_SDK_Linux.run -- silent && \
    rm ZED_SDK_Linux.run && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/usr/local/zed/lib:$LD_LIBRARY_PATH
RUN chmod -R 755 /usr/local/zed
# ---------------------------------------------------------
# 5. 다시 기본 사용자로 전환
# ---------------------------------------------------------
USER isaac-sim
# 작업 디렉토리 설정 (Isaac Sim 루트)
WORKDIR /isaac-sim
