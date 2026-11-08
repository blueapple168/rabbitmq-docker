#!/usr/bin/env bash
# vim:noet:
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	# https://github.com/docker-library/bashbrew/blob/master/scripts/jq-template.awk
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/9f6a35772ac863a0241f147c820354e4008edf38/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		# syntax=docker/dockerfile:1
		# check=skip=SecretsUsedInArgOrEnv
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	if [ -d "$version" ]; then
		# 只清理由模板生成的 alpine/ubuntu 变体；
		# UOS 变体为手工维护（不走模板），必须保留，否则 ./update.sh 会把 <版本>/UOS 一并删掉
		rm -rf "$version/alpine" "$version/ubuntu"
	fi

	if jq -e '.[env.version] | not' versions.json > /dev/null; then
		echo "skipping $version ..."
		continue
	fi

	for variant in alpine ubuntu; do
		export variant

		echo "processing $version/$variant ..."

		mkdir -p "$version/$variant"

		{
			generated_warning
			gawk -f "$jqt" "Dockerfile-$variant.template"
		} > "$version/$variant/Dockerfile"

		cp -f docker-entrypoint.sh conf.d/*.conf "$version/$variant/"

		if [ "$variant" = 'alpine' ]; then
			sed -i -e 's/gosu/su-exec/g' "$version/$variant/docker-entrypoint.sh"
		fi

		echo "processing $version/$variant/management ..."

		mkdir -p "$version/$variant/management"

		{
			generated_warning
			gawk -f "$jqt" Dockerfile-management.template
		} > "$version/$variant/management/Dockerfile"
	done
done
