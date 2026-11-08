#!/usr/bin/env bash
# 批量构建 <版本>/UOS 变体镜像
#
# 用法:
#   ./build-uos.sh                       # 构建 4.0 ~ 4.4 全部版本 (linux/amd64，仅本地)
#   VERSIONS="4.3 4.4" ./build-uos.sh    # 只构建指定版本
#   IMAGE=registry.local/rabbitmq ./build-uos.sh
#   PUSH=1 PLATFORMS=linux/amd64,linux/arm64 ./build-uos.sh   # 多架构构建并推送
#   BASE_IMAGE_TAG=uos-server-20-1070a:v1 ./build-uos.sh      # 指定 UOS 基础镜像 tag
#
# 产出的 tag 与 CI 保持一致 (镜像自带 rabbitmq_management 管理控制台):
#   ${IMAGE}:<版本目录>-management        例如 rabbitmq:4.3-management
#   ${IMAGE}:<完整版本号>-management      例如 rabbitmq:4.3.7-management
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

IMAGE="${IMAGE:-rabbitmq}"
VERSIONS="${VERSIONS:-4.0 4.1 4.2 4.3 4.4}"
PLATFORMS="${PLATFORMS:-linux/amd64}"
PUSH="${PUSH:-0}"
BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-}"

build_args=''
if [ -n "$BASE_IMAGE_TAG" ]; then
	build_args="--build-arg BASE_IMAGE_TAG=${BASE_IMAGE_TAG}"
fi

built=0
for version in $VERSIONS; do
	dir="$version/UOS"
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

	tags=(--tag "${IMAGE}:${version}-management" --tag "${IMAGE}:${full}-management")

	echo "==> 构建 ${version}/UOS (RabbitMQ ${full}) -> ${IMAGE}:${version}-management, ${IMAGE}:${full}-management"

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

echo "完成: 共构建 ${built} 个镜像"
