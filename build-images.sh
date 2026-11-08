#!/usr/bin/env bash
# 批量构建 <版本>/<变体> 镜像（变体: UOS / kylin）
#
# 用法:
#   ./build-images.sh                              # 构建 4.0 ~ 4.4 的 UOS 与 kylin 全部变体 (linux/amd64，仅本地)
#   VARIANTS=UOS ./build-images.sh                 # 只构建 UOS 变体
#   VARIANTS=kylin VERSIONS="4.3 4.4" ./build-images.sh
#   IMAGE=registry.local/rabbitmq ./build-images.sh
#   PUSH=1 PLATFORMS=linux/amd64,linux/arm64 ./build-images.sh      # 多架构构建并推送
#   MIRROR_GITHUB=https://mirror.example.com ./build-images.sh      # 内网 GitHub 代理
#
# 产出的 tag（镜像自带 rabbitmq_management 管理控制台）:
#   UOS   : ${IMAGE}:<版本目录>-management      ${IMAGE}:<完整版本>-management
#   kylin : ${IMAGE}:<版本目录>-kylin-management ${IMAGE}:<完整版本>-kylin-management
#
# 说明: UOS 的 tag 不带 OS 后缀是为了保持既有镜像名不变；其它变体统一追加 -<变体>。
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

IMAGE="${IMAGE:-rabbitmq}"
VERSIONS="${VERSIONS:-4.0 4.1 4.2 4.3 4.4}"
VARIANTS="${VARIANTS:-UOS kylin}"
PLATFORMS="${PLATFORMS:-linux/amd64}"
PUSH="${PUSH:-0}"
BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-}"
BASE_IMAGE_REPO="${BASE_IMAGE_REPO:-}"
MIRROR_GITHUB="${MIRROR_GITHUB:-}"
ERLANG_RPM_EL="${ERLANG_RPM_EL:-}"

build_args=''
[ -n "$BASE_IMAGE_TAG" ]  && build_args="${build_args} --build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG}"
[ -n "$BASE_IMAGE_REPO" ] && build_args="${build_args} --build-arg BASE_IMAGE_REPO=${BASE_IMAGE_REPO}"
[ -n "$MIRROR_GITHUB" ]   && build_args="${build_args} --build-arg MIRROR_GITHUB=${MIRROR_GITHUB}"
[ -n "$ERLANG_RPM_EL" ]   && build_args="${build_args} --build-arg ERLANG_RPM_EL=${ERLANG_RPM_EL}"

built=0
for variant in $VARIANTS; do
	for version in $VERSIONS; do
		dir="$version/$variant"
		if [ ! -f "$dir/Dockerfile" ]; then
			echo >&2 "skip: $dir/Dockerfile 不存在"
			continue
		fi

		# 从 Dockerfile 的 ARG 行取完整版本号（tr -d '\r' 兼容 Windows 工作区的 CRLF）
		full="$(sed -nE 's/^ARG[[:space:]]+RABBITMQ_VERSION=([^ #]+).*/\1/p' "$dir/Dockerfile" | tr -d '\r' | head -n1)"
		if [ -z "$full" ]; then
			echo >&2 "error: $dir/Dockerfile 中未找到 ARG RABBITMQ_VERSION"
			exit 1
		fi

		# UOS 保持既有 tag 命名（不带后缀），其它变体追加 -<变体>
		suffix=''
		[ "$variant" = 'UOS' ] || suffix="-$variant"

		tags=(--tag "${IMAGE}:${version}${suffix}-management" --tag "${IMAGE}:${full}${suffix}-management")

		echo "==> 构建 ${dir} (RabbitMQ ${full}) -> ${IMAGE}:${version}${suffix}-management, ${IMAGE}:${full}${suffix}-management"

		# 单架构 + 不推送: 用普通 docker build，构建结果直接进本地镜像库
		if [ "$PLATFORMS" = 'linux/amd64' ] && [ "$PUSH" != '1' ]; then
			# shellcheck disable=SC2086
			docker build $build_args "${tags[@]}" "$dir"
		else
			out='--load'
			[ "$PUSH" = '1' ] && out='--push'
			# shellcheck disable=SC2086
			docker buildx build --platform "$PLATFORMS" $out $build_args "${tags[@]}" "$dir"
		fi

		built=$((built + 1))
	done
done

echo "完成: 共构建 ${built} 个镜像"
