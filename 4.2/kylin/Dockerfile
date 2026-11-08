# syntax=docker/dockerfile:1.4
# RabbitMQ 4.2.9 (management) on Kylin Server V11 Minimal —— x86_64 / arm64 统一构建
#
# 参考官方镜像: https://github.com/docker-library/rabbitmq (4.2/ubuntu/Dockerfile)
# 同族变体: 4.2/UOS（UOS Server 20 1070a）。两者构建逻辑同源，差异见下。
#
# 与 UOS 变体的关键差异:
#   1. 基础镜像 cr.kylinos.cn/kylin/kylin-server-minimal:v11-2503。
#      包管理器是 dnf5（/usr/bin/dnf5），既没有 yum 也没有 microdnf，
#      因此 RUN 内按 dnf5 -> dnf -> microdnf -> yum 顺序探测，不写死单一命令。
#   2. minimal 层缺 tar / gzip / xz / curl / useradd / ps / hostname / bash，
#      必须先装包；缺 tar/gzip 会在解压 RabbitMQ 包时以 127 失败，报错点离真因很远。
#   3. Kylin V11 的包名与 RHEL 不完全一致（shadow 而非 shadow-utils），
#      这类包按候选名依次尝试，避免个别包名差异直接中断构建。
#   4. Kylin V11 2503 官方参数: 内核 6.6 / glibc 2.38 / gcc 12.3，
#      对应 erlang RPM 的 el9 分支（glibc >= 2.34）。构建期仍会探测 glibc 再决定，
#      使同一份文件也能直接用于 glibc 2.28 的 Kylin V10；可用 ARG ERLANG_RPM_EL 强制指定。
#   5. Erlang/OTP 用 RabbitMQ 官方零依赖 erlang-rpm（自带 OpenSSL 运行时），不源码编译；
#      RabbitMQ 本体用官方 generic-unix 标准工具链包（非 latest-toolchain）+ .asc PGP 校验。
#   6. 官方 management 变体的功能合并进单镜像（启用 rabbitmq_management、保留 metrics
#      collector、内置 rabbitmqadmin），与 UOS 变体一致。
#
# 构建:
#   docker build -t rabbitmq:4.2-kylin-management .
#   docker buildx build --platform linux/amd64,linux/arm64 -t rabbitmq:4.2-kylin-management .
#   内网代理: --build-arg MIRROR_GITHUB=https://mirror.example.com
#   强制 el 分支: --build-arg ERLANG_RPM_EL=el8
#
# 版本号统一在下方 ARG 区，升级时只改 ARG，注释无需同步；完整版本矩阵见仓库根目录 README.md。

# 基础镜像：Kylin Server V11 Minimal
ARG BASE_IMAGE_REPO=cr.kylinos.cn/kylin/kylin-server-minimal
ARG BASE_IMAGE_TAG=v11-2503
FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}

# 重新声明基础镜像参数，供后续 LABEL 等指令展开（ARG 在 FROM 之后失效）
ARG BASE_IMAGE_REPO
ARG BASE_IMAGE_TAG

# buildx 自动注入的目标架构（amd64 / arm64）。必须声明才能引用，
# 否则 set -u 下引用未定义的 TARGETARCH 会报 unbound variable
ARG TARGETARCH

ARG RABBITMQ_VERSION=4.2.9
ARG OTP_VERSION=27.3.4.19
ARG GOSU_VERSION=1.17
ARG RABBITMQADMIN_VERSION=2.35.0

# 组件版本之外的开关
#   MIRROR_GITHUB : 内网可指向 GitHub 代理（留空则直连 github.com）
#   PGP_KEYSERVER : RabbitMQ .asc 验签用的 keyserver
#   ERLANG_RPM_EL : auto = 按 glibc 版本自动判定 el8/el9；也可强制 el8 / el9
ARG MIRROR_GITHUB=""
ARG PGP_KEYSERVER=hkps://keys.openpgp.org
ARG PGP_KEYSERVER_FALLBACK=keyserver.ubuntu.com
ARG ERLANG_RPM_EL=auto

ARG OS_VERSION=v11-2503

# erlang-rpm release 无 .asc 签名文件，官方提供的唯一校验手段是 release 元数据里的 digest。
# 四个摘要分别对应 el8/el9 × x86_64/aarch64，升级 OTP_VERSION 时需同步更新全部四项。
# 摘要取自 https://api.github.com/repos/rabbitmq/erlang-rpm/releases/tags/v${OTP_VERSION}
ARG ERLANG_RPM_SHA256_EL8_X86_64=d61548b5df3c60bf85e94be9677478e7154210787376801d5f4cedf05d2e0c05
ARG ERLANG_RPM_SHA256_EL8_AARCH64=462ea060f25566d9c1f4b368806056af88f05fb5bb51e924251ea4e7a79d72e4
ARG ERLANG_RPM_SHA256_EL9_X86_64=ad0e8244f522a0be2132afb77ad088d0a6410e89bab9a60a0ebaed78cc097928
ARG ERLANG_RPM_SHA256_EL9_AARCH64=f47b4f5704c904b82cff5621acbf09e3d0c254d8f68244376fcc1792ce9cba93

LABEL org.opencontainers.image.authors="blueapple1120@qq.com" \
      version="1.0" \
      org.opencontainers.image.source="https://github.com/blueapple168/rabbitmq-docker" \
      org.opencontainers.image.base.name="${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}" \
      org.opencontainers.image.title="RabbitMQ" \
      org.opencontainers.image.description="RabbitMQ ${RABBITMQ_VERSION} (management) with Erlang/OTP ${OTP_VERSION} on Kylin Linux ${OS_VERSION} (multi-arch: amd64/arm64)" \
      org.opencontainers.image.version="${RABBITMQ_VERSION}" \
      os="Kylin Linux" \
      os.version="${OS_VERSION}" \
      os.arch="amd64,arm64"

ENV TZ=Asia/Shanghai

# UTF-8 locale，避免 Erlang/OTP 以 latin1 编码启动并告警
# (必须放在执行 erl/rabbitmqctl 的 RUN 之前，否则冒烟测试阶段就会告警)
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

############################################
# RUN#1 单次包管理器会话: 装依赖 -> 装 erlang RPM -> gosu -> 清理
# 每个独立 RUN 调 dnf5 都会重下仓库元数据，拆开会显著拉长构建时间
############################################

RUN set -euxo pipefail; \
    # ---- 0. 架构判别（erlang RPM 用 x86_64/aarch64，gosu 用 amd64/arm64）----
    case "${TARGETARCH:-amd64}" in \
        amd64) rpmArch='x86_64';  gosuArch='amd64' ;; \
        arm64) rpmArch='aarch64'; gosuArch='arm64' ;; \
        *) echo "ERROR: unsupported TARGETARCH=${TARGETARCH} (erlang-rpm 仅提供 x86_64/aarch64)" >&2; exit 1 ;; \
    esac; \
    GH="${MIRROR_GITHUB:-https://github.com}"; \
    : "=== 下载重试函数: 5 次 + 退避 + HTML 错误页识别 (GitHub 高并发下载易被限流/连接重置) ===" ; \
    fetch() { \
        _u="$1"; _o="$2"; _n=0; \
        while [ "$_n" -lt 5 ]; do \
            if curl -fsSL --connect-timeout 20 --retry 2 --retry-delay 5 -o "$_o" "$_u"; then \
                head -c 1024 "$_o" > /tmp/.fetch.probe 2>/dev/null || true; \
                if grep -qi -m1 -e '<!doctype' -e '<html' /tmp/.fetch.probe 2>/dev/null; then \
                    echo "WARN: ${_u} 返回 HTML 错误页，重试" >&2; rm -f "$_o" /tmp/.fetch.probe; \
                else \
                    rm -f /tmp/.fetch.probe; return 0; \
                fi; \
            fi; \
            _n=$((_n + 1)); echo "WARN: 下载失败 (第 ${_n}/5 次): ${_u}" >&2; sleep $((_n * 5)); \
        done; \
        echo "ERROR: 下载重试 5 次仍失败: ${_u}" >&2; return 1; \
    }; \
    echo "==> TARGETARCH=${TARGETARCH:-amd64}  rpmArch=${rpmArch}"; \
    \
    # ---- 1. 包管理器探测 ----
    PKG_MGR=""; \
    for m in dnf5 dnf microdnf yum; do \
        if command -v "$m" >/dev/null 2>&1; then PKG_MGR="$(command -v "$m")"; break; fi; \
        for d in /usr/bin /bin /usr/sbin /sbin; do \
            if [ -x "${d}/${m}" ]; then PKG_MGR="${d}/${m}"; break 2; fi; \
        done; \
    done; \
    if [ -z "$PKG_MGR" ]; then \
        echo "ERROR: 未找到可用的包管理器 (dnf5/dnf/microdnf/yum)" >&2; exit 1; \
    fi; \
    echo "==> 使用包管理器: ${PKG_MGR}"; \
    \
    # ---- 2. 安装运行时依赖 ----
    # 包名在麒麟仓库里可能与 RHEL 不同，先定义「按候选名依次尝试」的通用安装函数；
    # 全部失败只告警，由后面的「命令自检」兜底判定是否真的缺能力
    install_any() { \
        for p in "$@"; do \
            if "$PKG_MGR" install -y --setopt=install_weak_deps=False "$p" >/dev/null 2>&1; then \
                echo "  installed: $p"; return 0; \
            fi; \
        done; \
        echo "  WARN: 候选包均未安装成功: $*" >&2; return 0; \
    }; \
    \
    # 硬依赖：先一次装齐（快）；失败则逐包装，便于定位到底是哪个包名在麒麟仓库里不存在。
    # 缺 tar/gzip/xz 会在解压 RabbitMQ 包时以 127 失败，缺 bash 会让 entrypoint 起不来，
    # 报错点离真因都很远，所以这里宁可多装一轮也要把原因说清楚。
    HARD_PKGS="tar gzip xz curl ca-certificates sed gawk grep findutils coreutils bash"; \
    if ! "$PKG_MGR" install -y --setopt=install_weak_deps=False $HARD_PKGS; then \
        echo "WARN: 批量安装失败，改为逐包安装以定位缺包" >&2; \
        for _p in $HARD_PKGS; do install_any "$_p"; done; \
    fi; \
    install_any shadow shadow-utils; \
    install_any procps-ng procps; \
    install_any hostname; \
    install_any gnupg2 gnupg; \
    install_any glibc-all-langpacks glibc-langpack-en; \
    \
    # ---- 3. 命令自检（把缺包的报错点前移）----
    for c in tar xz curl gpg ps hostname bash sed awk grep find useradd groupadd sha256sum install; do \
        command -v "$c" >/dev/null 2>&1 \
            || { echo "ERROR: 缺少命令 ${c}，请确认麒麟仓库源可用（base/updates）" >&2; exit 1; }; \
    done; \
    \
    # ---- 4. 判定 erlang RPM 的 el 分支 ----
    GLIBC_VER="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}' || true)"; \
    if [ -z "$GLIBC_VER" ]; then \
        GLIBC_VER="$(ldd --version 2>&1 | sed -n '1s/.* //p' || true)"; \
    fi; \
    EL_TAG="${ERLANG_RPM_EL}"; \
    if [ "$EL_TAG" = 'auto' ]; then \
        if [ -z "$GLIBC_VER" ]; then \
            echo "ERROR: 无法探测 glibc 版本，请显式指定 --build-arg ERLANG_RPM_EL=el8|el9" >&2; exit 1; \
        fi; \
        GM="${GLIBC_VER%%.*}"; GN="${GLIBC_VER#*.}"; GN="${GN%%.*}"; \
        if [ "${GM:-0}" -gt 2 ] || { [ "${GM:-0}" -eq 2 ] && [ "${GN:-0}" -ge 34 ]; }; then \
            EL_TAG='el9'; \
        else \
            EL_TAG='el8'; \
        fi; \
    fi; \
    echo "==> glibc=${GLIBC_VER:-unknown} -> erlang RPM 分支 ${EL_TAG}"; \
    case "${EL_TAG}:${rpmArch}" in \
        el8:x86_64)  rpmSha="${ERLANG_RPM_SHA256_EL8_X86_64}" ;; \
        el8:aarch64) rpmSha="${ERLANG_RPM_SHA256_EL8_AARCH64}" ;; \
        el9:x86_64)  rpmSha="${ERLANG_RPM_SHA256_EL9_X86_64}" ;; \
        el9:aarch64) rpmSha="${ERLANG_RPM_SHA256_EL9_AARCH64}" ;; \
        *) echo "ERROR: 不支持的组合 ${EL_TAG}:${rpmArch}" >&2; exit 1 ;; \
    esac; \
    \
    # ---- 5. 下载 erlang RPM 并按官方 digest 做 SHA256 校验 ----
    ERLANG_RPM="erlang-${OTP_VERSION}-1.${EL_TAG}.${rpmArch}.rpm"; \
    ERLANG_RPM_URL="${GH}/rabbitmq/erlang-rpm/releases/download/v${OTP_VERSION}/${ERLANG_RPM}"; \
    echo "Downloading: ${ERLANG_RPM_URL}"; \
    fetch "$ERLANG_RPM_URL" "/tmp/${ERLANG_RPM}"; \
    echo "${rpmSha}  /tmp/${ERLANG_RPM}" | sha256sum --check --strict -; \
    \
    # erlang-rpm 为零依赖包；dnf5 对本地 rpm 的安装参数在不同小版本上略有差异，
    # 失败时用 rpm -ivh 兜底（无依赖可解析，所以安全）
    "$PKG_MGR" install -y --nogpgcheck --setopt=install_weak_deps=False "/tmp/${ERLANG_RPM}" \
        || rpm -ivh --replacepkgs "/tmp/${ERLANG_RPM}"; \
    rm -f "/tmp/${ERLANG_RPM}"; \
    \
    # ---- 6. 冒烟测试: crypto 依赖 OpenSSL 运行时，能起来说明 RPM 与 glibc/架构匹配 ----
    command -v erl; \
    erl -noshell -eval 'case crypto:start() of ok -> io:format("crypto started ok~n"); {error,E} -> io:format("crypto start ERROR ~p~n",[E]), halt(1) end, init:stop().'; \
    \
    # ---- 7. gosu: 麒麟源无此包，从 GitHub 下载静态二进制并按 SHA256SUMS 校验 ----
    mkdir -p /usr/local/bin /tmp/chk; \
    GOSU_BASE="${GH}/tianon/gosu/releases/download/${GOSU_VERSION}"; \
    fetch "${GOSU_BASE}/SHA256SUMS" /tmp/chk/gosu.sums; \
    fetch "${GOSU_BASE}/gosu-${gosuArch}" "/tmp/chk/gosu-${gosuArch}"; \
    cd /tmp/chk; \
    grep " \*\?gosu-${gosuArch}\$" gosu.sums | sha256sum -c -; \
    install -m 0755 "/tmp/chk/gosu-${gosuArch}" /usr/local/bin/gosu; \
    cd /; rm -rf /tmp/chk; \
    gosu nobody true; \
    \
    # ---- 8. 清理构建垃圾（dnf5 的缓存目录是 libdnf5，不是 dnf/yum）----
    "$PKG_MGR" clean all || true; \
    rm -rf /var/cache/dnf/* \
           /var/cache/libdnf5/* \
           /var/cache/yum/* \
           /var/cache/microdnf/* \
           /var/tmp/* \
           /tmp/*

############################################
# 创建 rabbitmq 系统用户/组、目录结构
############################################

ENV RABBITMQ_DATA_DIR=/var/lib/rabbitmq

RUN set -eux; \
    : "=== 创建 rabbitmq 系统用户/组 (幂等: 官方固定 ID 999 被基础镜像占用时回退为系统自动分配) ===" ; \
    if ! getent group rabbitmq >/dev/null; then \
        if getent group 999 >/dev/null; then \
            echo "::notice GID 999 已被基础镜像占用 ($(getent group 999))，改用系统自动分配 GID"; \
            groupadd --system rabbitmq; \
        else \
            groupadd --gid 999 --system rabbitmq; \
        fi; \
    fi; \
    if ! id rabbitmq >/dev/null 2>&1; then \
        if id -u 999 >/dev/null 2>&1; then \
            echo "::notice UID 999 已被基础镜像占用 ($(id -nu 999))，改用系统自动分配 UID"; \
            useradd --system --home-dir "$RABBITMQ_DATA_DIR" --gid rabbitmq rabbitmq; \
        else \
            useradd --uid 999 --system --home-dir "$RABBITMQ_DATA_DIR" --gid rabbitmq rabbitmq; \
        fi; \
    fi; \
    mkdir -p "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
    chown -fR rabbitmq:rabbitmq "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
    chmod 1777 "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
    \
    : "=== 允许 root 通过符号链接访问 erlang cookie ===" ; \
    ln -sf "$RABBITMQ_DATA_DIR/.erlang.cookie" /root/.erlang.cookie

############################################
# 安装 RabbitMQ: 官方通用二进制包 (标准工具链版)
# https://www.rabbitmq.com/docs/install-generic-unix
# 标准版而非 latest-toolchain: 标准版面向较老 glibc 环境构建，
# 与 erlang-rpm 为发行版标准环境构建的 OTP 是官方推荐组合
############################################

ENV RABBITMQ_VERSION=${RABBITMQ_VERSION}
ENV RABBITMQ_PGP_KEY_ID=0x0A9AF2115F4687BD29803A206B73A36E6026DFCA
ENV RABBITMQ_HOME=/opt/rabbitmq
ENV PATH=$RABBITMQ_HOME/sbin:$PATH

RUN set -eux; \
    : "=== 下载重试函数: 5 次 + 退避 + HTML 错误页识别 (GitHub 高并发下载易被限流/连接重置) ===" ; \
    fetch() { \
        _u="$1"; _o="$2"; _n=0; \
        while [ "$_n" -lt 5 ]; do \
            if curl -fsSL --connect-timeout 20 --retry 2 --retry-delay 5 -o "$_o" "$_u"; then \
                head -c 1024 "$_o" > /tmp/.fetch.probe 2>/dev/null || true; \
                if grep -qi -m1 -e '<!doctype' -e '<html' /tmp/.fetch.probe 2>/dev/null; then \
                    echo "WARN: ${_u} 返回 HTML 错误页，重试" >&2; rm -f "$_o" /tmp/.fetch.probe; \
                else \
                    rm -f /tmp/.fetch.probe; return 0; \
                fi; \
            fi; \
            _n=$((_n + 1)); echo "WARN: 下载失败 (第 ${_n}/5 次): ${_u}" >&2; sleep $((_n * 5)); \
        done; \
        echo "ERROR: 下载重试 5 次仍失败: ${_u}" >&2; return 1; \
    }; \
    GH="${MIRROR_GITHUB:-https://github.com}"; \
    RABBITMQ_SOURCE_URL="${GH}/rabbitmq/rabbitmq-server/releases/download/v$RABBITMQ_VERSION/rabbitmq-server-generic-unix-$RABBITMQ_VERSION.tar.xz"; \
    RABBITMQ_PATH="/usr/local/src/rabbitmq-$RABBITMQ_VERSION"; \
    \
    : "=== 下载 tar.xz 与官方 .asc PGP 签名文件 ===" ; \
    fetch "$RABBITMQ_SOURCE_URL" "$RABBITMQ_PATH.tar.xz"; \
    fetch "$RABBITMQ_SOURCE_URL.asc" "$RABBITMQ_PATH.tar.xz.asc"; \
    \
    : "=== PGP 签名校验: 导入 RabbitMQ 官方签名密钥并验证 tar.xz (与官方 alpine/ubuntu Dockerfile 一致) ===" ; \
    export GNUPGHOME="$(mktemp -d)"; \
    imported=''; \
    for ks in "$PGP_KEYSERVER" "$PGP_KEYSERVER_FALLBACK"; do \
        [ -n "$ks" ] || continue; \
        _n=0; \
        while [ "$_n" -lt 3 ]; do \
            if gpg --batch --keyserver "$ks" --recv-keys "$RABBITMQ_PGP_KEY_ID"; then imported=1; break 2; fi; \
            _n=$((_n + 1)); echo "WARN: keyserver ${ks} 导入失败 (第 ${_n}/3 次)" >&2; sleep $((_n * 5)); \
        done; \
    done; \
    [ "$imported" = 1 ] || { echo "ERROR: 所有 keyserver 均无法导入 RabbitMQ 签名密钥；内网可用 --build-arg PGP_KEYSERVER=<地址> 指定" >&2; exit 1; }; \
    gpg --batch --verify "$RABBITMQ_PATH.tar.xz.asc" "$RABBITMQ_PATH.tar.xz"; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME"; \
    \
    : "=== 解压 RabbitMQ 通用二进制包 (标准工具链版) ===" ; \
    mkdir -p "$RABBITMQ_HOME"; \
    tar --extract --file "$RABBITMQ_PATH.tar.xz" --directory "$RABBITMQ_HOME" --strip-components 1; \
    rm -rf "$RABBITMQ_PATH"*; \
    \
    : "=== 不默认将 SYS_PREFIX 指向 RABBITMQ_HOME，保持为空（官方行为） ===" ; \
    grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
    sed -i 's/^SYS_PREFIX=.*$/SYS_PREFIX=/' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
    grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
    \
    chown -R rabbitmq:rabbitmq "$RABBITMQ_HOME"; \
    \
    : "=== 以 rabbitmq 用户运行几个不依赖服务的命令，确认安装正确 ===" ; \
    [ ! -e "$RABBITMQ_DATA_DIR/.erlang.cookie" ]; \
    gosu rabbitmq rabbitmqctl help; \
    gosu rabbitmq rabbitmqctl list_ciphers; \
    gosu rabbitmq rabbitmq-plugins list; \
    : "=== 无残留 cookie ===" ; \
    rm -f "$RABBITMQ_DATA_DIR/.erlang.cookie"

# 默认启用 Prometheus 风格指标 (https://github.com/docker-library/rabbitmq/issues/419)
RUN gosu rabbitmq rabbitmq-plugins enable --offline rabbitmq_prometheus

# 向后兼容：允许直接 COPY 自定义插件到 /plugins
RUN ln -sf /opt/rabbitmq/plugins /plugins

############################################
# management 插件 (参考官方 4.2/ubuntu/management/Dockerfile)
############################################

# 启用 rabbitmq_management 插件 (管理 UI: 15672, TLS: 15671)
RUN set -eux; \
    gosu rabbitmq rabbitmq-plugins enable --offline rabbitmq_management

# 说明: 官方基础镜像默认通过 conf.d/20-management_agent.disable_metrics_collector.conf
# 禁用 metrics collector 以启用 Prometheus 风格指标; 但管理 UI 的统计/图表依赖 metrics collector,
# 官方 management 变体是在 build 后 rm 掉该文件。本镜像合并了 management 功能，
# 因此直接不 COPY 该文件 (等价于官方 management 变体的 rm)。
# 目录中保留 20-management_agent.disable_metrics_collector.conf 仅为与 UOS/alpine/ubuntu
# 变体布局对齐，本 Dockerfile 不引用它 —— 若重新 COPY 会导致管理界面统计功能失效。

# rabbitmqadmin (rabbitmqadmin-ng): 官方 CLI 管理工具，按架构从 GitHub 下载静态二进制
# 注意: 使用 musl 静态版而非 gnu 版 —— gnu 版需要 GLIBC 2.34+，
#       Kylin V10 (glibc 2.28) 无法运行；musl 版全静态链接，无任何 libc 运行时依赖
RUN set -eux; \
    : "=== 下载重试函数: 5 次 + 退避 + HTML 错误页识别 (GitHub 高并发下载易被限流/连接重置) ===" ; \
    fetch() { \
        _u="$1"; _o="$2"; _n=0; \
        while [ "$_n" -lt 5 ]; do \
            if curl -fsSL --connect-timeout 20 --retry 2 --retry-delay 5 -o "$_o" "$_u"; then \
                head -c 1024 "$_o" > /tmp/.fetch.probe 2>/dev/null || true; \
                if grep -qi -m1 -e '<!doctype' -e '<html' /tmp/.fetch.probe 2>/dev/null; then \
                    echo "WARN: ${_u} 返回 HTML 错误页，重试" >&2; rm -f "$_o" /tmp/.fetch.probe; \
                else \
                    rm -f /tmp/.fetch.probe; return 0; \
                fi; \
            fi; \
            _n=$((_n + 1)); echo "WARN: 下载失败 (第 ${_n}/5 次): ${_u}" >&2; sleep $((_n * 5)); \
        done; \
        echo "ERROR: 下载重试 5 次仍失败: ${_u}" >&2; return 1; \
    }; \
    GH="${MIRROR_GITHUB:-https://github.com}"; \
    case "$(uname -m)" in \
        x86_64)  adminArch='x86_64-unknown-linux-musl' ;; \
        aarch64) adminArch='aarch64-unknown-linux-musl' ;; \
        *) echo >&2 "[INFO] rabbitmqadmin is not available on $(uname -m) (yet?)"; exit 0 ;; \
    esac; \
    \
    fetch "${GH}/rabbitmq/rabbitmqadmin-ng/releases/download/v${RABBITMQADMIN_VERSION}/rabbitmqadmin-${RABBITMQADMIN_VERSION}-${adminArch}" \
        /usr/local/bin/rabbitmqadmin; \
    chmod +x /usr/local/bin/rabbitmqadmin; \
    \
    : "=== 验证 rabbitmqadmin 可用 ===" ; \
    rabbitmqadmin --help

# 设置 HOME，使任意 --user 都知道 erlang cookie 放在哪里
ENV HOME=$RABBITMQ_DATA_DIR

# 数据目录建议挂载卷
VOLUME $RABBITMQ_DATA_DIR

# rabbitmq-server 启动脚本依据 RUNNING_UNDER_SYSTEMD 决定是否以 exec 启动 erl，
# 设为 true 使 beam.smp 成为容器中的 PID 1（信号传递正确）
ENV RUNNING_UNDER_SYSTEMD=true

COPY --chown=rabbitmq:rabbitmq 10-defaults.conf /etc/rabbitmq/conf.d/
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

# 4369/25672: epmd 与节点间通信; 5671/5672: AMQP(+TLS);
# 15671/15672: 管理 UI(+TLS); 15691/15692: Prometheus 指标
EXPOSE 4369 5671 5672 15671 15672 15691 15692 25672

CMD ["rabbitmq-server"]
