ARG BASE_IMAGE="ubuntu:24.04"
ARG INTEL_CDN="https://downloads.intel.com/akdlm/software/acdsinst"
ARG QUARTUS_VERSION="24.1std"
ARG QUARTUS_SUBVERSION="1077"
ARG QDZ_PLATFORM="cyclonev"
ARG QUARTUS_FULL_VERSION="${QUARTUS_VERSION}.0.${QUARTUS_SUBVERSION}"
ARG SETUP_NAME="QuartusLiteSetup-${QUARTUS_FULL_VERSION}-linux.run"
ARG QDZ_FILE="${QDZ_PLATFORM}-${QUARTUS_FULL_VERSION}.qdz"
ARG QUARTUS_ROOT="/opt/intelFPGA"
ARG FEX_ROOT="/opt/fexemu"
ARG FEX_VERSION="f4e3e4ad30f3927869498f6fa73e3afecf20c1d4"

FROM ${BASE_IMAGE} AS installer

WORKDIR /tmp

ARG INTEL_CDN
ARG SETUP_NAME
ARG QUARTUS_VERSION
ARG QUARTUS_SUBVERSION
ARG QDZ_PLATFORM
ARG QUARTUS_FULL_VERSION
ARG QUARTUS_ROOT
ARG QDZ_FILE

ADD ${INTEL_CDN}/${QUARTUS_VERSION}/${QUARTUS_SUBVERSION}/ib_installers/${SETUP_NAME} .
ADD ${INTEL_CDN}/${QUARTUS_VERSION}/${QUARTUS_SUBVERSION}/ib_installers/${QDZ_FILE} .

RUN chmod a+x ${SETUP_NAME}

FROM --platform=linux/arm64 installer AS install-arm64

RUN apt update && \
    apt install -y wget gnupg software-properties-common lsb-release

ARG LLVM_VERSION=21

RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN echo "deb http://apt.llvm.org/$(lsb_release -sc)/ llvm-toolchain-$(lsb_release -sc)-${LLVM_VERSION} main" >> /etc/apt/sources.list.d/llvm.list
RUN echo "deb-src http://apt.llvm.org/$(lsb_release -sc)/ llvm-toolchain-$(lsb_release -sc)-${LLVM_VERSION} main" >> /etc/apt/sources.list.d/llvm.list

RUN apt update && apt install -y \
    cmake \
    binfmt-support \
    libssl-dev \
    python3-setuptools \
    g++-x86-64-linux-gnu \
    libgcc-14-dev-i386-cross \
    libgcc-14-dev-amd64-cross \
    nasm \
    libstdc++-14-dev-i386-cross \
    libstdc++-14-dev-amd64-cross \
    libstdc++-14-dev-arm64-cross \
    squashfs-tools \
    squashfuse \
    libc-bin \
    libc6-dev-i386-amd64-cross \
    lib32stdc++-14-dev-amd64-cross \
    qtdeclarative5-dev \
    qml-module-qtquick-controls \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-dialogs \
    libbz2-1.0 \
    binutils \
    libglib2.0-0 \
    libnsl-dev \
    libfontconfig \
    libx11-xcb1 \
    libxext6 \
    libsm6 \
    libdbus-1-3 \
    libxft2 \
    libxtst6 \
    libxi6 \
    libgtk2.0-0 \
    ninja-build \
    pkg-config \
    curl \
    locales \
    jq \
    clang-${LLVM_VERSION} \
    lld-${LLVM_VERSION}

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

ARG FEX_VERSION
ADD https://github.com/FEX-Emu/FEX.git#${FEX_VERSION} /tmp/FEX

ENV CC=clang-${LLVM_VERSION}
ENV CXX=clang++-${LLVM_VERSION}

ARG FEX_ROOT
RUN mkdir -p ${FEX_ROOT}

RUN cd /tmp/FEX && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=${FEX_ROOT} -DCMAKE_BUILD_TYPE=Release -DUSE_LINKER=lld-${LLVM_VERSION} -DENABLE_LTO=True -DBUILD_TESTING=False -DENABLE_ASSERTIONS=False -G Ninja .. && \
    cmake --build . --target install --parallel && \
    rm -rf /tmp/FEX

ENV PATH="${FEX_ROOT}/bin:${PATH}"

RUN useradd -ms /bin/bash user
RUN chown -R user:user /opt /tmp

USER user

RUN mkdir -p /home/user
RUN FEXRootFSFetcher --distro-name "ubuntu" --distro-version "24.04" -y -x

RUN FEX /tmp/${SETUP_NAME} --mode unattended --accept_eula 1 --installdir ${QUARTUS_ROOT} && \
    rm -rf ${QUARTUS_ROOT}/uninstall/

FROM --platform=linux/amd64 installer AS install-amd64

RUN mkdir -p /home/user
RUN /tmp/${SETUP_NAME} --mode unattended --accept_eula 1 --installdir ${QUARTUS_ROOT} && \
    rm -rf ${QUARTUS_ROOT}/uninstall/

FROM install-${TARGETARCH} AS install

FROM ${BASE_IMAGE} AS final

RUN apt update && \
    apt install -y locales libbz2-1.0 binutils libglib2.0-0 libnsl-dev libfontconfig libx11-xcb1 libxext6 libsm6 libdbus-1-3 libxft2 libxtst6 libxi6 libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN useradd -ms /bin/bash user

USER user

COPY --from=install /opt /opt
COPY --from=install --chown=user:user /home/user /home/user

WORKDIR /home/user

ARG FEX_ROOT
ENV PATH="${FEX_ROOT}/bin:${PATH}"

ARG QUARTUS_ROOT
ENV QUARTUS_PATH=${QUARTUS_ROOT}/

ENV QUARTUS_ROOTDIR=${QUARTUS_PATH}/quartus
ENV SOPC_KIT_NIOS2=${QUARTUS_PATH}/nios2eds
ENV PATH=${QUARTUS_ROOTDIR}/bin/:${QUARTUS_ROOTDIR}/linux64/gnu/:${QUARTUS_ROOTDIR}/sopc_builder/bin/:$PATH
ENV PATH=${SOPC_KIT_NIOS2}/:${SOPC_KIT_NIOS2}/bin/:${SOPC_KIT_NIOS2}/bin/gnu/H-x86_64-pc-linux-gnu/bin/:${SOPC_KIT_NIOS2}/sdk2/bin/:$PATH

FROM --platform=arm64 final AS final-arm64

ENTRYPOINT [ "FEXBash" ]

FROM --platform=amd64 final AS final-amd64

ENTRYPOINT [ "bash", "-c" ]

FROM final-${TARGETARCH}

RUN echo "qcu_detected_procs_using_sysconf = on" >> /home/user/quartus.ini

WORKDIR /build
