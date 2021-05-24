#!/bin/bash

[[ -z "$CF_API_KEY" ]] && {
	echo "Missing CF_API_KEY"
	exit 1
}
[[ -z "$WOWI_API_TOKEN" ]] && {
	echo "Missing WOWI_API_TOKEN"
	exit 1
}

# dictates which Interface version will be used by default
BASE_VERSION="${1:-retail}"

# query CurseForge for the latest game version (e.g. 9.0.5)
gameVersions="$(curl -sSLH"X-API-Token: $CF_API_KEY" "https://wow.curseforge.com/api/game/versions")"
if jq '.errorCode' <<< "$gameVersions" 2>/dev/null; then
	# if this doesn't fail then we have an error
	echo "Error: $(jq -r '.errorMessage' <<< "$gameVersions")"
	exit 1
elif [[ -z "$gameVersions" ]]; then
	echo "Error: no data from CurseForge API"
	exit 1
fi

# map game versions to variables
retailVersion="$(jq -r 'map(select(.gameVersionTypeID == 517)) | max_by(.id) | .name' <<< "$gameVersions")"
classicVersion="$(jq -r 'map(select(.gameVersionTypeID == 67408)) | max_by(.id) | .name' <<< "$gameVersions")"
bccVersion="$(jq -r 'map(select(.gameVersionTypeID == 73246)) | max_by(.id) | .name' <<< "$gameVersions")"

if [[ -z "$retailVersion" ]] || [[ -z "$classicVersion" ]] || [[ -z "$bccVersion" ]]; then
	echo "Failed to get game version from CurseForge"
	exit 1
fi

# query WoWInterface for Interface version (e.g. 90005)
interfaceVersions="$(curl -sSLH"X-API-Token: $WOWI_API_TOKEN" "https://api.wowinterface.com/addons/compatible.json")"
if jq '.ERROR' <<< "$interfaceVersions" 2>/dev/null; then
	# if this doesn't fail then we have an error
	echo "Error: $(jq -r '.ERROR' <<< "$interfaceVersions")"
	exit 1
elif [[ -z "$interfaceVersions" ]]; then
	echo "Error: no data from WoWInterface API"
	exit 1
fi

# map interface version to variables based on game version
retailInterfaceVersion="$(jq -r --arg v "$retailVersion" '.[] | select(.game == "Retail" and .default  == true) | .interface' <<< "$interfaceVersions")"
classicInterfaceVersion="$(jq -r --arg v "$classicVersion" '.[] | select(.id == $v) | .interface' <<< "$interfaceVersions")"
bccInterfaceVersion="$(jq -r --arg v "$bccVersion" '.[] | select(.id == $v) | .interface' <<< "$interfaceVersions")"

if [[ -z "$retailInterfaceVersion" ]] || [[ -z "$classicInterfaceVersion" ]]; then
	echo "Failed to get interface version from WoWInterface"
	exit 1
fi

# write to TOC files
while read -r file; do
	before="$(md5sum "$file")"

	case "${BASE_VERSION,,}" in
		retail) sed -ri 's/^(## Interface: ).*$/\1'"$retailInterfaceVersion"'/' "$file" ;;
		classic) sed -ri 's/^(## Interface: ).*$/\1'"$classicInterfaceVersion"'/' "$file" ;;
		bcc) sed -ri 's/^(## Interface: ).*$/\1'"$bccInterfaceVersion"'/' "$file" ;;
	esac

	sed -ri 's/^(## Interface-Retail: ).*$/\1'"$retailInterfaceVersion"'/' "$file"
	sed -ri 's/^(## Interface-Classic: ).*$/\1'"$classicInterfaceVersion"'/' "$file"
	sed -ri 's/^(## Interface-BCC: ).*$/\1'"$bccInterfaceVersion"'/' "$file"

	if [[ "$(md5sum "$file")" != "$before" ]]; then
		echo "Updated $file"
	fi
done < <(find . -name '*.toc')
