# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# 参考官方镜像: https://github.com/docker-library/rabbitmq (4.1/ubuntu/Dockerfile)
# 官方基于较新的 Ubuntu 源码编译 OpenSSL + Erlang/OTP，本文件适配 UOS Server 20 1070a (yum/dnf)
#
# 本目录是仓库 UOS 变体族 (4.0 / 4.1 / 4.2 / 4.3 / 4.4) 中的一个:
#   五个版本共用同一套构建逻辑与同一个 UOS 基础镜像 (uos-server-20-1070a)，
#   差异仅在 RABBITMQ_VERSION / OTP_VERSION / erlang RPM 的两个 SHA256 摘要。
#   具体版本号见下方 ARG 区 —— 升级时只改 ARG，注释无需同步；
#   完整版本矩阵见仓库根目录 README.md。
#
# 与官方的主要差异:
#   1. 放弃源码编译 OpenSSL + Erlang/OTP（UOS 20 gcc/perl/autotools 较老，编译阶段报错多）
#      改用 RabbitMQ 官方团队维护的零依赖 Erlang RPM 仓库:
#      https://github.com/rabbitmq/erlang-rpm  (https://www.rabbitmq.com/docs/install-rpm#downloads)
#      erlang-<OTP_VERSION>-1.el8.<arch>.rpm 自带 OpenSSL 运行时，RHEL8/UOS Server 20 (glibc 2.28) 兼容
#   2. RabbitMQ 本体使用官方通用二进制包 (标准工具链版，非 latest-toolchain):
#      https://github.com/rabbitmq/rabbitmq-server/releases/download/v<RABBITMQ_VERSION>/rabbitmq-server-generic-unix-<RABBITMQ_VERSION>.tar.xz
#      解压到 /opt/rabbitmq，布局与官方 Docker 镜像一致，entrypoint/conf.d 零改动
#   3. gosu 不在 UOS 源中，改为从 GitHub releases 下载静态二进制
#   4. 下载产物完整性校验 (双重):
#      a) RabbitMQ tar.xz 通过官方 .asc PGP 签名校验 (gpg keyserver: hkps://keys.openpgp.org，
#         与官方 alpine/ubuntu Dockerfile 一致)
#      b) Erlang RPM 通过官方 SHA256 摘要校验 —— rabbitmq/erlang-rpm release 不提供 .asc
#         签名文件 (资产均为 .rpm)，官方校验手段是 release 元数据中的 digest，
#         摘要取自 https://api.github.com/repos/rabbitmq/erlang-rpm/releases/tags/v<OTP_VERSION>
#   5. 官方 management 变体 (4.1/ubuntu/management) 的功能合并进来，单镜像即带管理控制台:
#      启用 rabbitmq_management 插件、保留 metrics collector、安装 rabbitmqadmin
#
# 构建流程 (单阶段):
#   RUN#1 单次 yum 会话: yum 调优 + 运行时依赖(含 gnupg2) + erlang RPM (SHA256 校验) + 冒烟测试 + 清理
#   -> 创建 rabbitmq 用户/目录 -> gosu
#   -> 解压 rabbitmq-server-generic-unix tar.xz (.asc PGP 签名校验 + 冒烟测试)
#   -> 启用插件 -> rabbitmqadmin
# (每个独立 RUN 调 yum 都会重新下载全部仓库元数据，故 yum 操作合并进 RUN#1)
#
# 构建: docker build -t rabbitmq:4.1-management .
# 全量: 在仓库根目录执行 ./build-uos.sh

ARG RABBITMQ_VERSION=4.1.8
ARG OTP_VERSION=27.3.4.19
ARG GOSU_VERSION=1.17
ARG RABBITMQADMIN_VERSION=2.35.0
ARG BASE_IMAGE_TAG=uos-server-20-1070a:latest

# 下载源与验签相关（内网环境必须可覆盖）
#   MIRROR_GITHUB          : 留空直连 github.com；内网可指向 GitHub 代理
#   PGP_KEYSERVER          : 首选 keyserver（hkps 端口在内网常被拦截）
#   PGP_KEYSERVER_FALLBACK : 首选失败后的备用 keyserver
ARG MIRROR_GITHUB=""
ARG PGP_KEYSERVER=hkps://keys.openpgp.org
ARG PGP_KEYSERVER_FALLBACK=keyserver.ubuntu.com

# erlang-rpm release 无 .asc 签名文件，使用官方 digest (GitHub API) 做 SHA256 校验
# 升级 OTP_VERSION 时需同步更新以下两个摘要
ARG ERLANG_RPM_SHA256_X86_64=d61548b5df3c60bf85e94be9677478e7154210787376801d5f4cedf05d2e0c05
ARG ERLANG_RPM_SHA256_AARCH64=462ea060f25566d9c1f4b368806056af88f05fb5bb51e924251ea4e7a79d72e4

############################################
# runtime: 最终运行镜像（单阶段）
############################################

FROM ghcr.io/blueapple168/${BASE_IMAGE_TAG}

ARG RABBITMQ_VERSION
ARG OTP_VERSION
ARG GOSU_VERSION
ARG RABBITMQADMIN_VERSION
ARG ERLANG_RPM_SHA256_X86_64
ARG ERLANG_RPM_SHA256_AARCH64
ARG MIRROR_GITHUB
ARG PGP_KEYSERVER
ARG PGP_KEYSERVER_FALLBACK

LABEL maintainer="blueapple" \
        version="1.0" \
        description="RabbitMQ ${RABBITMQ_VERSION} (management) with Erlang/OTP ${OTP_VERSION} on UOS 1070a" \
        org.opencontainers.image.source="https://github.com/blueapple168/rabbitmq-docker" \
        org.opencontainers.image.base.name="registry.uniontech.com/uos-server-base/uos-server-20-1070a:latest" \
        org.opencontainers.image.title="RabbitMQ" \
        org.opencontainers.image.version="${RABBITMQ_VERSION}"

ENV TZ=Asia/Shanghai

# UTF-8 locale，避免 latin1 编码告警
# (必须放在执行 erlang/rabbitmqctl 的 RUN 之前，否则冒烟测试阶段 VM 以 latin1 编码启动并告警)
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

# Erlang RPM 来源: RabbitMQ 官方团队维护的零依赖包 (自带 OpenSSL 运行时)
# el8 对应 UOS Server 20 (RHEL 8 兼容, glibc 2.28)，无需源码编译 OpenSSL/Erlang
# 仅记录仓库内路径，主机部分由 RUN 内的 MIRROR_GITHUB 决定
ENV ERLANG_RPM_PATH=rabbitmq/erlang-rpm/releases/download/v${OTP_VERSION}
ENV ERLANG_RPM_VERSION=${OTP_VERSION}

# yum 相关操作 (调优/makecache/装依赖/装 erlang RPM) 合并在单个 RUN 中:
# 每个独立 RUN 调用 yum 都要重新下载全部仓库元数据 (UOS 全部仓库约 60s/次)，
# 拆成多个 RUN 会导致元数据重复下载，拉长构建时间并增大被取消/超时的暴露窗口
RUN set -eux; \
    echo "${TZ}" > /etc/timezone; \
    sed -i 's/\$StateMode/ufu/g' /etc/yum.repos.d/UnionTechOS.repo; \
    sed -i 's/Version: 39\.2\.0/Version: 2026.10.09/g' /usr/lib/python3.6/site-packages/setuptools-39.2.0.dist-info/METADATA 2>/dev/null || true; \
    \
    : "=== yum/dnf 网络调优：默认 timeout=30s 太短，minrate=1000 容易在低速链路上触发下载中止；延长超时到 300s、降低低速阈值到 100 B/s、retries=10 ===" ; \
    if [ -f /etc/yum.conf ]; then \
        sed -i '/^[ \t]*\(timeout\|minrate\|retries\)=/d' /etc/yum.conf 2>/dev/null || true; \
        if grep -q '^\[main\]' /etc/yum.conf; then \
            sed -i '/^\[main\]/a timeout=300\nminrate=100\nretries=10' /etc/yum.conf; \
        else \
            printf '\n[main]\ntimeout=300\nminrate=100\nretries=10\n' >> /etc/yum.conf; \
        fi; \
    fi; \
    yum makecache; \
    \
    : "=== 运行时依赖：ca-certificates (TLS)、tzdata (时区)、xz (解压 RabbitMQ 发行包)、wget/curl (下载)、procps (rabbitmqctl wait 需要 ps)、findutils+hostname (docker-entrypoint.sh 依赖) ===" ; \
    yum install -y --setopt=install_weak_deps=false --nogpgcheck --nodocs \
        --setopt=timeout=300 --setopt=minrate=100 \
        ca-certificates tar tzdata xz wget curl procps gnupg2 findutils hostname; \
    \
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
    \
    : "=== 下载 erlang-rpm 并按架构映射官方 SHA256 (x86_64/aarch64 对应 el8 资产) ===" ; \
    case "$(uname -m)" in \
        x86_64)  rpmArch='x86_64';   rpmSha="${ERLANG_RPM_SHA256_X86_64}" ;; \
        aarch64) rpmArch='aarch64';  rpmSha="${ERLANG_RPM_SHA256_AARCH64}" ;; \
        *) echo >&2 "error: unsupported arch: '$(uname -m)'"; exit 1 ;; \
    esac; \
    ERLANG_RPM="erlang-${ERLANG_RPM_VERSION}-1.el8.${rpmArch}.rpm"; \
    ERLANG_RPM_URL="${GH}/${ERLANG_RPM_PATH}/${ERLANG_RPM}"; \
    \
    fetch "$ERLANG_RPM_URL" "/tmp/${ERLANG_RPM}"; \
    \
    : "=== SHA256 校验: 摘要来自 rabbitmq/erlang-rpm release 官方元数据 (无 .asc 资产，这是官方提供的唯一校验手段) ===" ; \
    echo "${rpmSha}  /tmp/${ERLANG_RPM}" | sha256sum --check --strict -; \
    \
    : "=== localinstall: 自动解析依赖并安装 (rpm -ivh 不会处理缺失依赖) ===" ; \
    yum localinstall -y --setopt=install_weak_deps=false --nogpgcheck --nodocs "/tmp/${ERLANG_RPM}"; \
    rm -f "/tmp/${ERLANG_RPM}"; \
    \
    : "=== 冒烟测试: erlang-rpm 安装到 /usr/lib64/erlang, /usr/bin/erl 由 RPM 软链提供 ===" ; \
    command -v erl; \
    erl -noshell -eval 'case crypto:start() of ok -> io:format("crypto started ok\n"); {error,E} -> io:format("crypto start ERROR ~p\n",[E]), halt(1) end, init:stop().'; \
    \
    yum clean all; \
    rm -rf /var/cache/yum /var/cache/dnf

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

# gosu: UOS 源中无此包，从 GitHub 下载静态二进制，用于从 root 降权执行
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  gosuArch='amd64' ;; \
        aarch64) gosuArch='arm64' ;; \
        *) echo >&2 "error: unsupported arch: '$(uname -m)'"; exit 1 ;; \
    esac; \
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
    \
    : "=== 下载 gosu 与官方 SHA256SUMS 并校验 ===" ; \
    fetch "${GH}/tianon/gosu/releases/download/${GOSU_VERSION}/SHA256SUMS" /tmp/gosu.sums; \
    fetch "${GH}/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${gosuArch}" "/tmp/gosu-${gosuArch}"; \
    cd /tmp; \
    grep " \*\?gosu-${gosuArch}\$" gosu.sums | sha256sum -c -; \
    install -m 0755 "/tmp/gosu-${gosuArch}" /usr/local/bin/gosu; \
    rm -f /tmp/gosu.sums "/tmp/gosu-${gosuArch}"; \
    cd /; \
    \
    : "=== 验证 gosu 可用 ===" ; \
    gosu nobody true;

############################################
# 安装 RabbitMQ: 官方通用二进制包 (标准工具链版)
# https://www.rabbitmq.com/docs/install-generic-unix
# 标准版而非 latest-toolchain: 标准版面向老 glibc 环境构建，
# 与 erlang-rpm 为 RHEL8 标准环境构建的 OTP 27 是官方推荐组合
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
    : "=== 卸载 gnupg2 (校验已完成; 用 rpm -e 避免 yum 再拉一次仓库元数据; 失败仅提示不阻断) ===" ; \
    rpm -e gnupg2 2>/dev/null || echo "Notice: gnupg2 was not removed (可能被基础镜像预装且被依赖)"; \
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
# management 插件 (参考官方 4.1/ubuntu/management/Dockerfile)
############################################

# 启用 rabbitmq_management 插件 (管理 UI: 15672, TLS: 15671)
RUN set -eux; \
    gosu rabbitmq rabbitmq-plugins enable --offline rabbitmq_management

# 说明: 官方基础镜像默认通过 conf.d/20-management_agent.disable_metrics_collector.conf
# 禁用 metrics collector 以启用 Prometheus 风格指标; 但管理 UI 的统计/图表依赖 metrics collector,
# 官方 management 变体是在 build 后 rm 掉该文件。本镜像合并了 management 功能，
# 因此直接不 COPY 该文件 (等价于官方 management 变体的 rm)。
# 目录中保留 20-management_agent.disable_metrics_collector.conf 仅为与 alpine/ubuntu 变体布局对齐，
# 本 Dockerfile 不引用它 —— 若重新 COPY 会导致管理界面统计功能失效。

# rabbitmqadmin (rabbitmqadmin-ng): 官方 CLI 管理工具，按架构从 GitHub 下载静态二进制
# 注意: 使用 musl 静态版而非 gnu 版 —— gnu 版需要 GLIBC 2.34+，UOS 20 (el8, glibc 2.28) 无法运行;
#       musl 版为全静态链接，无任何 libc 运行时依赖
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  adminArch='x86_64-unknown-linux-musl' ;; \
        aarch64) adminArch='aarch64-unknown-linux-musl' ;; \
        *) echo >&2 "[INFO] rabbitmqadmin is not available on $(uname -m) (yet?)"; exit 0 ;; \
    esac; \
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
