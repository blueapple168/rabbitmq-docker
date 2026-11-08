# RabbitMQ Docker 镜像（UOS / Kylin 多版本）

本仓库 fork 自 [docker-library/rabbitmq](https://github.com/docker-library/rabbitmq)，在保留官方
`alpine` / `ubuntu` 变体（用于与上游持续同步）的基础上，新增两个**信创环境变体**：

| 变体 | 基础镜像 | 包管理器 | 用途 |
|------|----------|----------|------|
| `UOS` | `ghcr.io/blueapple168/uos-server-20-1070a:latest`（UOS Server 20 1070a） | yum（dnf） | 统信 UOS 环境部署 |
| `kylin` | `cr.kylinos.cn/kylin/kylin-server-minimal:v11-2503`（Kylin Server V11 Minimal） | dnf5 | 银河麒麟 V11 环境部署 |

两个变体共同特点：

- **单镜像即带管理控制台**（官方 `management` 变体的能力已合并进同一层），不存在“基础镜像 + management 叠加”两层；
  tag 保留 `-management` 后缀仅为命名约定与 CI 一致
- 面向**内网 / 信创环境**的离线部署，全部依赖可在构建期一次性拉取并做完整性校验
- 支持 **x86_64 / arm64** 双架构

当前维护 RabbitMQ **4.0 / 4.1 / 4.2 / 4.3 / 4.4** 五个版本 × 两个变体，共 10 个构建目录，
每个变体内五个版本共用同一套构建逻辑。

---

## 1. 目录结构

```
.
├── <版本>/alpine/          # 官方模板生成（apply-templates.sh），勿手工修改
├── <版本>/ubuntu/          # 官方模板生成（apply-templates.sh），勿手工修改
│   └── management/         # 官方 management 变体（FROM rabbitmq:<版本>）
├── <版本>/UOS/             # ★ 手工维护：UOS Server 20 变体
│   ├── Dockerfile
│   ├── 10-defaults.conf
│   ├── 20-management_agent.disable_metrics_collector.conf   # 仅布局对齐，Dockerfile 不引用
│   └── docker-entrypoint.sh
├── <版本>/kylin/           # ★ 手工维护：Kylin Server V11 变体
│   └── （同上，Dockerfile 不同）
├── build-images.sh         # 本地批量构建（可按变体/版本筛选）
├── build-uos.sh            # 早期仅构建 UOS 的脚本（保留可用，等价于 VARIANTS=UOS）
├── apply-templates.sh      # 上游模板渲染（已适配：不会删除 UOS / kylin 目录）
├── versions.sh / versions.json
└── .github/workflows/docker-build-rabbitmq-uos.yml
```

> `alpine` / `ubuntu` 由 `./update.sh` 从上游模板重新生成，**不要手改**；
> `UOS` / `kylin` 为手工维护，`apply-templates.sh` 只清理 `alpine` / `ubuntu`，不会动这两个变体。

---

## 2. 版本矩阵

### 2.1 UOS 变体（`<版本>/UOS`）

| 目录 | RabbitMQ | Erlang/OTP | Erlang RPM 基线 | 官方 Ubuntu 基线 | 产出 tag |
|------|----------|-----------|-----------------|------------------|----------|
| `4.0/UOS` | 4.0.9 | 27.3.4.19 | `erlang-27.3.4.19-1.el8` | 24.04 | `4.0-management` / `4.0.9-management` |
| `4.1/UOS` | 4.1.8 | 27.3.4.19 | `erlang-27.3.4.19-1.el8` | 24.04 | `4.1-management` / `4.1.8-management` |
| `4.2/UOS` | 4.2.9 | 27.3.4.19 | `erlang-27.3.4.19-1.el8` | 24.04 | `4.2-management` / `4.2.9-management` |
| `4.3/UOS` | 4.3.7 | 27.3.4.19 | `erlang-27.3.4.19-1.el8` | 24.04 | `4.3-management` / `4.3.7-management` |
| `4.4/UOS` | 4.4.0 | 29.1.2 | `erlang-29.1.2-1.el8` | 26.04 | `4.4-management` / `4.4.0-management` |

UOS Server 20 1070a 为 glibc 2.28（RHEL 8 ABI），固定使用 **el8** 资产。

### 2.2 Kylin 变体（`<版本>/kylin`）

| 目录 | RabbitMQ | Erlang/OTP | Erlang RPM 分支 | 基础镜像 tag | 产出 tag |
|------|----------|-----------|-----------------|--------------|----------|
| `4.0/kylin` | 4.0.9 | 27.3.4.19 | el9（glibc 2.38） | `v11-2503` | `4.0-kylin-management` / `4.0.9-kylin-management` |
| `4.1/kylin` | 4.1.8 | 27.3.4.19 | el9 | `v11-2503` | `4.1-kylin-management` / `4.1.8-kylin-management` |
| `4.2/kylin` | 4.2.9 | 27.3.4.19 | el9 | `v11-2503` | `4.2-kylin-management` / `4.2.9-kylin-management` |
| `4.3/kylin` | 4.3.7 | 27.3.4.19 | el9 | `v11-2503` | `4.3-kylin-management` / `4.3.7-kylin-management` |
| `4.4/kylin` | 4.4.0 | 29.1.2 | el9 | `v11-2503` | `4.4-kylin-management` / `4.4.0-kylin-management` |

Kylin V11 2503 官方参数：内核 6.6 / **glibc 2.38** / gcc 12.3，因此走 **el9** 分支。
Dockerfile 在构建期会探测 glibc 再决定 el8/el9，同一份文件也可直接用于 glibc 2.28 的 Kylin V10
（或用 `--build-arg ERLANG_RPM_EL=el8` 强制）。

### 2.3 通用说明

- Erlang 一律取 RabbitMQ 官方 `rabbitmq/erlang-rpm` 的**零依赖 RPM**（自带 OpenSSL 运行时），不源码编译。
- RabbitMQ 本体取官方 **`rabbitmq-server-generic-unix-<版本>.tar.xz`**（标准工具链版，**不是**
  `latest-toolchain` 版）——标准版面向较老 glibc 构建，与 erlang-rpm 的 OTP 是官方推荐组合。
- 4.4 使用 OTP 29，官方 Ubuntu 基线已切到 26.04；该版本在两个国产平台上的运行验证请以实际测试为准。

---

## 3. 变体特性对比

| 项目 | UOS 变体 | Kylin 变体 |
|------|----------|------------|
| 基础镜像 | `ghcr.io/blueapple168/uos-server-20-1070a:latest` | `cr.kylinos.cn/kylin/kylin-server-minimal:v11-2503` |
| 包管理器 | yum（dnf） | **dnf5**（无 yum / microdnf），按 dnf5→dnf→microdnf→yum 探测 |
| glibc | 2.28 → el8 资产 | 2.38 → el9 资产（构建期探测，可强制） |
| 包名差异 | `glibc-langpack-zh` 等 | `shadow`（非 shadow-utils）、`glibc-all-langpacks` 等，按候选名依次尝试 |
| Erlang | 官方 erlang-rpm（el8） | 官方 erlang-rpm（el8/el9 自动） |
| 插件 | `rabbitmq_management` + `rabbitmq_prometheus` | 同左 |
| 命令行 | `rabbitmqadmin` 2.35.0（musl 静态版） | 同左 |
| 降权运行 | `gosu` 1.17 + `rabbitmq` 用户（UID 999 被占用时自动回退） | 同左 |
| 完整性校验 | tar.xz：官方 `.asc` PGP；Erlang RPM：官方 SHA256 | 同左（Kylin 为 4 个摘要，覆盖 el8/el9 × 两架构） |
| 时区 / 编码 | `TZ=Asia/Shanghai`、`LANG=C.UTF-8` | 同左 |
| 数据目录 | `/var/lib/rabbitmq`（已声明 `VOLUME`） | 同左 |
| 兼容链接 | `/plugins` → `/opt/rabbitmq/plugins` | 同左 |
| 架构 | `x86_64` / `aarch64` | `x86_64` / `aarch64`（Kylin V11 另支持 LoongArch，但 erlang-rpm 无对应资产） |

### 端口

| 端口 | 用途 |
|------|------|
| 4369 | epmd（节点发现） |
| 5672 / 5671 | AMQP / AMQP over TLS |
| 15672 / 15671 | 管理控制台 / 管理控制台 over TLS |
| 25672 | 节点间通信（Erlang distribution） |
| 15692 | Prometheus 指标（`/metrics`） |
| 15691 | Prometheus 指标（聚合/旧路径） |

---

## 4. 快速开始

```bash
# UOS 变体
docker run -d --name rabbitmq \
  -p 5672:5672 -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS='<强口令>' \
  -v rabbitmq-data:/var/lib/rabbitmq \
  --restart=unless-stopped \
  rabbitmq:4.3-management

# Kylin 变体（只换 tag）
docker run -d --name rabbitmq \
  -p 5672:5672 -p 15672:15672 \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS='<强口令>' \
  -v rabbitmq-data:/var/lib/rabbitmq \
  --restart=unless-stopped \
  rabbitmq:4.3-kylin-management
```

管理控制台：<http://<host>:15672>（账号即上面设置的用户）。

### 常用环境变量

| 变量 | 说明 |
|------|------|
| `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS` | 首次启动创建的默认用户/口令 |
| `RABBITMQ_DEFAULT_VHOST` | 默认 vhost（默认 `/`） |
| `RABBITMQ_ERLANG_COOKIE` | 集群共享 cookie，多节点部署必须显式设置 |
| `RABBITMQ_NODENAME` | 节点名，默认 `rabbit@<hostname>` |
| `RABBITMQ_USE_LONGNAME` | 长短主机名不一致时 entrypoint 会自动置 `true` |
| `RABBITMQ_CONFIG_FILES` | 追加配置文件，例如 `/etc/rabbitmq/conf.d` |

> `RABBITMQ_SSL_*`、`RABBITMQ_MANAGEMENT_SSL_*`、`RABBITMQ_VM_MEMORY_HIGH_WATERMARK` 等已在
> RabbitMQ 4.x 废弃，设置后 entrypoint 会直接报错退出，请改用配置文件。

### 挂载自定义配置

```bash
docker run -d --name rabbitmq \
  -v "$PWD/rabbitmq.conf:/etc/rabbitmq/conf.d/99-custom.conf:ro" \
  rabbitmq:4.3-management
```

---

## 5. 构建

### 5.1 单个版本

```bash
# UOS
docker build -t rabbitmq:4.3-management 4.3/UOS

# Kylin（多架构）
docker buildx build --platform linux/amd64,linux/arm64 \
  -t rabbitmq:4.3-kylin-management --load 4.3/kylin

# 覆盖基础镜像 / 内网代理 / 强制 el 分支
docker build --build-arg BASE_IMAGE_TAG=uos-server-20-1070a:v1.2 -t rabbitmq:4.3-management 4.3/UOS
docker build --build-arg MIRROR_GITHUB=https://mirror.example.com -t rabbitmq:4.3-kylin-management 4.3/kylin
docker build --build-arg ERLANG_RPM_EL=el8 -t rabbitmq:4.3-kylin-management 4.3/kylin
```

### 5.2 批量构建

```bash
./build-images.sh                                        # 4.0~4.4 × UOS+kylin，linux/amd64，仅本地
VARIANTS=kylin ./build-images.sh                         # 只构建 kylin 变体
VARIANTS=kylin VERSIONS="4.3 4.4" ./build-images.sh      # 指定变体 + 版本
IMAGE=registry.local/rabbitmq ./build-images.sh          # 指定镜像名前缀
PUSH=1 PLATFORMS=linux/amd64,linux/arm64 ./build-images.sh   # 多架构构建并推送
```

可用环境变量：`IMAGE` / `VERSIONS` / `VARIANTS` / `PLATFORMS` / `PUSH` /
`BASE_IMAGE_TAG` / `BASE_IMAGE_REPO` / `MIRROR_GITHUB` / `ERLANG_RPM_EL`。

### 5.3 CI（GitHub Actions）

`.github/workflows/docker-build-rabbitmq-uos.yml` 自动扫描仓库内所有 `<版本>/<变体>/Dockerfile`
（排除 `alpine` / `ubuntu`），变体列表由目录结构推导，新增变体无需改 workflow：

| 触发 | 行为 |
|------|------|
| push / PR 涉及 `*/UOS/**` 或 `*/kylin/**` | 只构建被改动的 `<版本>/<变体>` |
| 手动触发 | 可指定 `version_dir`（如 `4.3`）与 `variant`（`UOS`/`kylin`），留空则全量 |
| 每日定时 / 手动勾选 `check_upstream` | 检查上游 `v<目录>.x` 最新正式版；有新版则改写该版本**所有变体**的 `ARG RABBITMQ_VERSION`、提交回 master 并立即构建 |

推送目标：

- UOS：`ghcr.io/<owner>/<repo>:4.3-management`、`:4.3.7-management`
- Kylin：`ghcr.io/<owner>/<repo>:4.3-kylin-management`、`:4.3.7-kylin-management`

> 定时任务只自动跟进 **RabbitMQ 补丁版本**；OTP 升级需人工修改（见下节），因为摘要校验会失效。

---

## 6. 维护指南

### 6.1 升级 RabbitMQ 补丁版本（如 4.3.7 → 4.3.8）

每个变体目录各改一处 ARG（CI 定时任务也会自动做，并同时改两个变体）：

```dockerfile
ARG RABBITMQ_VERSION=4.3.8
```

tar.xz 与 `.asc` 随版本号自动适配，PGP 校验无需改动。**OTP 与 RPM 摘要不变**。
Dockerfile 文件头注释不含具体版本号，因此 CI 自动 bump 后不会出现注释与 ARG 不一致。

### 6.2 升级 Erlang/OTP

**UOS 变体**（2 个摘要）：

```dockerfile
ARG OTP_VERSION=27.3.4.20
ARG ERLANG_RPM_SHA256_X86_64=<新摘要>
ARG ERLANG_RPM_SHA256_AARCH64=<新摘要>
```

**Kylin 变体**（4 个摘要，el8/el9 × x86_64/aarch64 都要更新）：

```dockerfile
ARG OTP_VERSION=27.3.4.20
ARG ERLANG_RPM_SHA256_EL8_X86_64=<新摘要>
ARG ERLANG_RPM_SHA256_EL8_AARCH64=<新摘要>
ARG ERLANG_RPM_SHA256_EL9_X86_64=<新摘要>
ARG ERLANG_RPM_SHA256_EL9_AARCH64=<新摘要>
```

摘要取自 `rabbitmq/erlang-rpm` release 元数据（该仓库不提供 `.asc`，digest 是官方唯一校验手段）：

```bash
curl -s "https://api.github.com/repos/rabbitmq/erlang-rpm/releases/tags/v27.3.4.20" \
  | jq -r '.assets[] | select(.name | test("^erlang-27\\.3\\.4\\.20-1\\.el[89]\\.(x86_64|aarch64)\\.rpm$"))
           | "\(.name)\t\(.digest)"'
```

拿到的是 `sha256:xxxx` 形式，去掉 `sha256:` 前缀后填入 ARG。

### 6.3 新增版本目录（如 4.5）

1. 复制最近一个版本的**每个变体**目录：`cp -r 4.4/UOS 4.5/UOS`、`cp -r 4.4/kylin 4.5/kylin`
2. 修改各变体 `Dockerfile` 的 ARG：`RABBITMQ_VERSION`、`OTP_VERSION`、各 `ERLANG_RPM_SHA256_*`
3. 把文件头注释里的目录名引用 `4.4` 改为 `4.5`（UOS 3 处、kylin 4 处）
4. 确认新版本存在 `rabbitmq-server-generic-unix-<版本>.tar.xz` **及其 `.asc`**
5. 在 `build-images.sh` 的 `VERSIONS` 默认值和本 README 的版本矩阵中补行
6. 提交后 CI 自动识别并构建（无需改 workflow）

### 6.4 新增一个 OS 变体（如 openEuler）

1. 新建 `<版本>/<变体名>/`，放入 `Dockerfile`、`10-defaults.conf`、`docker-entrypoint.sh`
   （`20-management_agent.disable_metrics_collector.conf` 仅作布局对齐，**不要 COPY**）
2. `Dockerfile` 里 `ARG RABBITMQ_VERSION` 必须保留（CI 与构建脚本靠它取版本号）
3. `build-images.sh` 的 `VARIANTS` 默认值加上新变体名；tag 会自动变为 `<版本>-<变体名>-management`
4. CI 无需修改：变体列表由 `find` 推导

### 6.5 已知坑

| 坑 | 说明 |
|----|------|
| **不要 COPY `20-management_agent.disable_metrics_collector.conf`** | 该文件会关闭 metrics collector，而管理 UI 的统计/图表依赖它。官方 `management` 变体是 build 后 `rm` 掉它；本镜像已合并 management，故直接不 COPY。若误加，管理界面统计会失效（`rabbitmq_prometheus` 仍可用）。 |
| 单个 RUN 内合并包管理器操作 | 每次 `yum`/`dnf5` 调用都会重下全部仓库元数据，拆成多个 RUN 会显著拉长构建时间 |
| 用 `install <本地rpm>` 而非 `localinstall` | dnf5 没有 `localinstall`；本地 rpm 用 `install /path/x.rpm`，失败时回退 `rpm -ivh` |
| erlang RPM 的 el 分支必须匹配 glibc | el9 要求 glibc ≥ 2.34。Kylin V11 = 2.38（el9）、Kylin V10 / UOS 20 = 2.28（el8），选错会在冒烟测试阶段报 crypto 启动失败 |
| minimal 层缺 `tar`/`xz`/`bash` | 缺 `tar`/`xz` 会在解压 RabbitMQ 包时以 127 失败；`docker-entrypoint.sh` 是 bash 脚本，必须装 `bash` |
| 包名因发行版而异 | UOS：`glibc-langpack-zh`；Kylin：`shadow`（非 shadow-utils）、`glibc-all-langpacks`。这类包按候选名依次尝试 |
| dnf5 缓存目录 | 是 `/var/cache/libdnf5`，不是 `/var/cache/dnf` |
| rabbitmqadmin 必须用 musl 版 | gnu 版要求 glibc ≥ 2.34，glibc 2.28 的平台（UOS 20 / Kylin V10）运行会报 `GLIBC_2.34 not found` |
| `SYS_PREFIX` 必须置空 | 否则 `rabbitmqctl` 等脚本的路径解析与官方镜像不一致 |
| `RUNNING_UNDER_SYSTEMD=true` | 使 `beam.smp` 成为 PID 1，保证信号传递正确 |

---

## 7. 与官方镜像的差异

| 维度 | 官方 `rabbitmq:<版本>` | 本仓库 UOS / Kylin 变体 |
|------|------------------------|--------------------------|
| 基础镜像 | `ubuntu:24.04` / `alpine:3.x` | UOS Server 20 1070a / Kylin Server V11 Minimal |
| OpenSSL | 源码编译 3.5.9 | 使用 erlang-rpm 自带运行时（不单独编译） |
| Erlang/OTP | 源码编译 | 官方零依赖 RPM（el8 / el9） |
| 校验方式 | tar.xz `.asc` PGP | tar.xz `.asc` PGP **+** RPM SHA256 |
| management | 独立 `-management` 变体 | **合并进单镜像** |
| 包管理 | apt / apk | yum（UOS） / dnf5（Kylin） |
| 体积 | 较小 | 较大（保留包管理器依赖与缓存清理后的元数据） |
| 适用场景 | 通用 / 公网 | 内网、信创、等保环境 |

---

## 8. 许可证

沿用上游 [LICENSE](LICENSE)（MPL 2.0）。RabbitMQ 与 Erlang/OTP 分别遵循其各自许可证。
