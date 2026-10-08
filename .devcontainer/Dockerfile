ARG VARIANT=ubuntu-24.04
FROM mcr.microsoft.com/vscode/devcontainers/base:${VARIANT}

ENV DEBIAN_FRONTEND=noninteractive
ENV PDK_ROOT=/home/vscode/ttsetup/pdk
ENV PDK=gf180mcuD

RUN apt update
RUN apt install -y iverilog gtkwave python3 python3-pip python3-venv python3-tk python-is-python3 libcairo2 verilator libpng-dev libqhull-dev

# Install Python packages in a virtual environment (Ubuntu manages system Python).
RUN python3 -m venv /opt/venv
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# Clone tt-support-tools
RUN mkdir -p /ttsetup
RUN git clone https://github.com/TinyTapeout/tt-support-tools /ttsetup/tt-support-tools

COPY test/requirements.txt /ttsetup/test_requirements.txt
COPY .devcontainer/copy_tt_support_tools.sh /ttsetup

# KLayout builds from source on ARM64; limit compiler memory use.
RUN KLAYOUT_SETUP_MULTICORE=2 pip3 install -r /ttsetup/test_requirements.txt -r /ttsetup/tt-support-tools/requirements.txt

# Install verible (for formatting)
RUN umask 022 && \
    case "$(uname -m)" in \
        aarch64) VERIBLE_ARCH=arm64 ;; \
        x86_64) VERIBLE_ARCH=x86_64 ;; \
        *) echo "Unsupported Verible architecture: $(uname -m)" >&2; exit 1 ;; \
    esac && \
    curl -fL "https://github.com/chipsalliance/verible/releases/download/v0.0-3795-gf4d72375/verible-v0.0-3795-gf4d72375-linux-static-${VERIBLE_ARCH}.tar.gz" | \
    tar zxf - -C /usr/local --strip-components=1 && \
    chmod 755 /usr/local/bin

# Install LibreLane
RUN pip3 install librelane==2.4.2
