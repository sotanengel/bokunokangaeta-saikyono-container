# syntax=docker/dockerfile:1.7
FROM node:22-bookworm-slim

ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000
ARG UV_VERSION=0.11.2

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=UTC
ENV WORKSPACE=/workspace
ENV HOME=/home/${USERNAME}
ENV MISE_DATA_DIR=/home/${USERNAME}/.local/share/mise
ENV MISE_CACHE_DIR=/home/${USERNAME}/.cache/mise
ENV PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/.local/share/mise/shims:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        fd-find \
        fish \
        g++ \
        gcc \
        git \
        git-lfs \
        jq \
        less \
        libssl-dev \
        make \
        openssh-client \
        pkg-config \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        rsync \
        tini \
        unzip \
        vim \
        wget \
        xz-utils \
        zip \
        zsh && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    ln -sf /usr/bin/python3 /usr/local/bin/python

RUN existing_group="$(getent group "${USER_GID}" | cut -d: -f1 || true)" && \
    if [[ -n "${existing_group}" && "${existing_group}" != "${USERNAME}" ]]; then \
      groupmod --new-name "${USERNAME}" "${existing_group}"; \
    elif [[ -z "${existing_group}" ]]; then \
      groupadd --gid "${USER_GID}" "${USERNAME}"; \
    fi && \
    existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1 || true)" && \
    if [[ -n "${existing_user}" && "${existing_user}" != "${USERNAME}" ]]; then \
      usermod --login "${USERNAME}" --home "${HOME}" --move-home --shell /bin/bash --gid "${USER_GID}" "${existing_user}"; \
    elif ! id -u "${USERNAME}" >/dev/null 2>&1; then \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}"; \
    else \
      usermod --home "${HOME}" --move-home --shell /bin/bash --gid "${USER_GID}" "${USERNAME}"; \
    fi && \
    mkdir -p "${WORKSPACE}" "${HOME}/.local/bin" "${HOME}/.cache" "${HOME}/.config" && \
    chown -R "${USERNAME}:${USER_GID}" "${WORKSPACE}" "${HOME}"

RUN python3 -m pip install --no-cache-dir --break-system-packages "uv==${UV_VERSION}" && \
    curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh && \
    corepack enable

COPY scripts/agent-entrypoint.sh /usr/local/bin/agent-entrypoint
COPY scripts/bootstrap-languages.sh /usr/local/bin/bootstrap-languages
COPY scripts/install-agents.sh /usr/local/bin/install-agents

RUN chmod 0755 \
        /usr/local/bin/agent-entrypoint \
        /usr/local/bin/bootstrap-languages \
        /usr/local/bin/install-agents && \
    printf "eval \"\$(mise activate bash)\"\n" >> /etc/bash.bashrc && \
    printf "eval \"\$(mise activate zsh)\"\n" >> /etc/zsh/zshrc

USER ${USERNAME}
WORKDIR ${WORKSPACE}

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agent-entrypoint"]
CMD ["bash"]
