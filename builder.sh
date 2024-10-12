#!/bin/bash

declare -g configFile="./templates/config.yaml"
declare -g fileName
declare -g headFileTemplate="./templates/head.mustache"
declare -g headJson
declare -g bodyFileTemplate="./templates/body.mustache"
declare -g bodyJson
declare -g tmpBodyJson

declare -g schemesPath="$HOME/.local/share/tinted-theming/tinty/repos/schemes/base16/"
declare -g schemeSystem
declare -g schemeSlug
declare -g schemeSlugUnderscored
declare -g schemeName
declare -g schemeAuthor
declare -g schemeVariant

declare -g tokenHex
declare -g tokenBgr
declare -g tokenHexR
declare -g tokenHexG
declare -g tokenHexB
declare -g tokenRgbR
declare -g tokenRgbG
declare -g tokenRgbB
declare -g tokenRgb16R
declare -g tokenRgb16G
declare -g tokenRgb16B
declare -g tokenDecR
declare -g tokenDecG
declare -g tokenDecB

readarray -t schemesFiles < <(find "$schemesPath" -type f -iname '*.yaml')
readarray -t necessaryTokensPaletteList < <(grep -oP '\{\{\K[^}]+(?=\}\})' "$bodyFileTemplate" | awk -F'-' '{print $1}' | sort -u)

function getProperty() {
	yq -oy "$schemeFile" | yq -o=json -r ".$1"
}

function createFile() {
	# Extract filename entry from config
	yq '.default.filename' "$configFile" >"/tmp/filename-base16-nwg-dock.txt"

	fileName=$(lustache-cli -i "/tmp/filename-base16-nwg-dock.txt" --json-data "$headJson")

	if [[ -e ./"$fileName" ]]; then
		return
	else
		touch ./"$fileName"
	fi
}

for schemeFile in "${schemesFiles[@]}"; do
	schemeName=$(getProperty "name")
	schemeAuthor=$(getProperty "author")
	schemeSlug=$(basename "$schemeFile" .yaml)
	schemeSlugUnderscored="${schemeSlug//-/_}"
	schemeSystem=$(yq '.default.supported-systems[0]' "$configFile")
	schemeVariant=$(getProperty "variant")

	headJson=$(
		jq \
			--null-input \
			--arg schemeName "$schemeName" \
			--arg schemeAuthor "$schemeAuthor" \
			--arg schemeSlug "$schemeSlug" \
			--arg schemeSlugUnderscored "$schemeSlugUnderscored" \
			--arg schemeSystem "$schemeSystem" \
			--arg schemeVariant "$schemeVariant" \
			'{ 
				"scheme-name": $schemeName,
				"scheme-author": $schemeAuthor,
				"scheme-slug": $schemeSlug,
				"scheme-slug-underscored": $schemeSlugUnderscored,
				"scheme-system": $schemeSystem,
				"scheme-variant": $schemeVariant,
				"hasVariant": (if $schemeVariant != "" then "true" else "false" end) 
			}'
	)

	for tokenName in "${necessaryTokensPaletteList[@]}"; do
		tokenHex=$(yq -oy "$schemeFile" | yq -o=json -r ".palette.$tokenName")
		tokenBgr=$(echo "$tokenHex" | rev)
		tokenHexR=${tokenHex:0:2}
		tokenHexG=${tokenHex:2:2}
		tokenHexB=${tokenHex: -2}
		tokenRgbR=$((16#$tokenHexR))
		tokenRgbG=$((16#$tokenHexG))
		tokenRgbB=$((16#$tokenHexB))
		tokenRgb16R=$(echo "($tokenRgbR / 255) * 65535" | bc -l | awk '{print int($1)}')
		tokenRgb16G=$(echo "($tokenRgbG / 255) * 65535" | bc -l | awk '{print int($1)}')
		tokenRgb16B=$(echo "($tokenRgbB / 255) * 65535" | bc -l | awk '{print int($1)}')
		tokenDecR=$(echo "scale=4; $tokenRgbR / 255" | bc)
		tokenDecG=$(echo "scale=4; $tokenRgbG / 255" | bc)
		tokenDecB=$(echo "scale=4; $tokenRgbB / 255" | bc)

		tmpBodyJson=$(
			jq \
				--null-input \
				--arg tokenName "$tokenName" \
				--arg tokenHex "$tokenHex" \
				--arg tokenBgr "$tokenBgr" \
				--arg tokenHexR "$tokenHexR" \
				--arg tokenHexG "$tokenHexG" \
				--arg tokenHexB "$tokenHexB" \
				--arg tokenRgbR "$tokenRgbR" \
				--arg tokenRgbG "$tokenRgbG" \
				--arg tokenRgbB "$tokenRgbB" \
				--arg tokenRgb16R "$tokenRgb16R" \
				--arg tokenRgb16G "$tokenRgb16G" \
				--arg tokenRgb16B "$tokenRgb16B" \
				--arg tokenDecR "$tokenDecR" \
				--arg tokenDecG "$tokenDecG" \
				--arg tokenDecB "$tokenDecB" \
				'{
					($tokenName + "-hex"): $tokenHex,
					($tokenName + "-bgr"): $tokenBgr,
					($tokenName + "-hex-r"): $tokenHexR,
					($tokenName + "-hex-g"): $tokenHexG,
					($tokenName + "-hex-b"): $tokenHexB,
					($tokenName + "-rgb-r"): $tokenRgbR,
					($tokenName + "-rgb-g"): $tokenRgbG,
					($tokenName + "-rgb-b"): $tokenRgbB,
					($tokenName + "-rgb16-r"): $tokenRgb16R,
					($tokenName + "-rgb16-g"): $tokenRgb16G,
					($tokenName + "-rgb16-b"): $tokenRgb16B,
					($tokenName + "-dec-r"): $tokenDecR,
					($tokenName + "-dec-g"): $tokenDecG,
					($tokenName + "-dec-b"): $tokenDecB
				}'
		)

		bodyJson=$(echo "$bodyJson" "$tmpBodyJson" | jq -s 'add')
	done

	createFile

	lustache-cli -i "$headFileTemplate" --json-data "$headJson" >./"$fileName"

	echo >>./"$fileName"

	lustache-cli -i "$bodyFileTemplate" --json-data "$bodyJson" >>./"$fileName"

done
