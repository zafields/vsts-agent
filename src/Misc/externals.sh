#!/bin/bash
PLATFORM_CMD=$1
CONTAINER_URL=https://vstsagenttools.blob.core.windows.net/tools
NODE_URL=https://nodejs.org/dist
NODE_VERSION="6.10.3"
NODE_OLD_VERSION="5.10.1"

get_abs_path() {
  # exploits the fact that pwd will print abs path when no args
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

LAYOUT_DIR=$(get_abs_path `dirname $0`/../../_layout)
DOWNLOAD_DIR=$(get_abs_path `dirname $0`/../../_downloads)

function get_current_os_name() {
    if [[ "$PLATFORM_CMD" != "" ]]; then
        echo "$PLATFORM_CMD"
        return 0
    fi

    local uname=$(uname)
    if [ "$uname" = "Darwin" ]; then
        echo "darwin"
        return 0
    else
        echo "linux"
        return 0
    fi
    
    echo "windows"
    return 0
}

PLATFORM=$(get_current_os_name)

function failed() {
   local error=${1:-Undefined error}
   echo "Failed: $error" >&2
   exit 1
}

function checkRC() {
    local rc=$?
    if [ $rc -ne 0 ]; then
        failed "${1} failed with return code $rc"
    fi
}

function acquireExternalTool() {
    local download_source=$1 # E.g. https://vstsagenttools.blob.core.windows.net/tools/pdbstr/1/pdbstr.zip
    local target_dir="$LAYOUT_DIR/externals/$2" # E.g. $LAYOUT_DIR/externals/pdbstr
    local fix_nested_dir=$3 # Flag that indicates whether to move nested contents up one directory. E.g. TEE-CLC-14.0.4.zip
                            # directly contains only a nested directory TEE-CLC-14.0.4. When this flag is set, the contents
                            # of the nested TEE-CLC-14.0.4 directory are moved up one directory, and then the empty directory
                            # TEE-CLC-14.0.4 is removed.

    # Extract the portion of the URL after the protocol. E.g. vstsagenttools.blob.core.windows.net/tools/pdbstr/1/pdbstr.zip
    local relative_url="${download_source#*://}"

    # Check if the download already exists.
    local download_target="$DOWNLOAD_DIR/$relative_url"
    local download_basename="$(basename $download_target)"
    if [ -f "$download_target" ]; then
        echo "Download exists: $download_basename"
    else
        # Delete any previous partial file.
        local partial_target="$DOWNLOAD_DIR/partial/$download_basename"
        mkdir -p "$(dirname "$partial_target")" || checkRC 'mkdir'
        if [ -f "$partial_target" ]; then
            rm "$partial_target" || checkRC 'rm'
        fi

        # Download from source to the partial file.
        echo "Downloading $download_source"
        mkdir -p "$(dirname $download_target)" || checkRC 'mkdir'
        # curl -f Fail silently (no output at all) on HTTP errors (H)
        #      -k Allow connections to SSL sites without certs (H)
        #      -S Show error. With -s, make curl show errors when they occur
        #      -L Follow redirects (H)
        #      -o FILE    Write to FILE instead of stdout
        curl -fkSL -o "$partial_target" "$download_source" 2>"${download_target}_download.log" || checkRC 'curl'

        # Move the partial file to the download target.
        mv "$partial_target" "$download_target" || checkRC 'mv'
    fi

    # Extract to layout.
    mkdir -p "$target_dir" || checkRC 'mkdir'
    local nested_dir=""
    if [[ "$download_basename" == *.zip ]]; then
        # Extract the zip.
        echo "Extracting zip to layout"
        unzip "$download_target" -d "$target_dir" > /dev/null
        local rc=$?
        if [[ $rc -ne 0 && $rc -ne 1 ]]; then
            failed "unzip failed with return code $rc"
        fi

        # Capture the nested directory path if the fix_nested_dir flag is set.
        if [[ "$fix_nested_dir" == "fix_nested_dir" ]]; then
            nested_dir="${download_basename%.zip}" # Remove the trailing ".zip".
        fi
    elif [[ "$download_basename" == *.tar.gz ]]; then
        # Extract the tar gz.
        echo "Extracting tar gz to layout"
        tar xzf "$download_target" -C "$target_dir" > /dev/null || checkRC 'tar'

        # Capture the nested directory path if the fix_nested_dir flag is set.
        if [[ "$fix_nested_dir" == "fix_nested_dir" ]]; then
            nested_dir="${download_basename%.tar.gz}" # Remove the trailing ".tar.gz".
        fi
    else
        # Copy the file.
        echo "Copying to layout"
        cp "$download_target" "$target_dir/" || checkRC 'cp'
    fi

    # Fixup the nested directory.
    if [[ "$nested_dir" != "" ]]; then
        if [ -d "$target_dir/$nested_dir" ]; then
            mv "$target_dir/$nested_dir"/* "$target_dir/" || checkRC 'mv'
            rmdir "$target_dir/$nested_dir" || checkRC 'rmdir'
        fi
    fi
}

# Download the external tools only for Windows.
if [[ "$PLATFORM" == "windows" ]]; then
    acquireExternalTool "$CONTAINER_URL/azcopy/1/azcopy.zip" azcopy
    acquireExternalTool "$CONTAINER_URL/pdbstr/1/pdbstr.zip" pdbstr
    acquireExternalTool "$CONTAINER_URL/mingit/3/mingit.zip" git
    acquireExternalTool "$CONTAINER_URL/symstore/1/symstore.zip" symstore
    acquireExternalTool "$CONTAINER_URL/vstshost/m119_1_cdda11c6/vstshost.zip" vstshost
    acquireExternalTool "$CONTAINER_URL/vstsom/m119_1_cdda11c6/vstsom.zip" vstsom
    acquireExternalTool "$CONTAINER_URL/vswhere/1_0_62/vswhere.zip" vswhere
    acquireExternalTool "$NODE_URL/v${NODE_VERSION}/win-x64/node.exe" node/bin
    acquireExternalTool "$NODE_URL/v${NODE_VERSION}/win-x64/node.lib" node/bin
    acquireExternalTool "$NODE_URL/v${NODE_OLD_VERSION}/win-x64/node.exe" node-${NODE_OLD_VERSION}/bin
    acquireExternalTool "$NODE_URL/v${NODE_OLD_VERSION}/win-x64/node.lib" node-${NODE_OLD_VERSION}/bin
    acquireExternalTool "https://dist.nuget.org/win-x86-commandline/v3.3.0/nuget.exe" nuget
fi

# Download the external tools only for OSX.
if [[ "$PLATFORM" == "darwin" ]]; then
    acquireExternalTool "$NODE_URL/v${NODE_VERSION}/node-v${NODE_VERSION}-darwin-x64.tar.gz" node fix_nested_dir
    acquireExternalTool "$NODE_URL/v${NODE_OLD_VERSION}/node-v${NODE_OLD_VERSION}-darwin-x64.tar.gz" node-${NODE_OLD_VERSION} fix_nested_dir
fi

# Download the external tools common across OSX and Linux platforms.
if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "darwin" ]]; then
    acquireExternalTool "$CONTAINER_URL/tee/14_0_4_20160606/TEE-CLC-14.0.4.zip" tee fix_nested_dir
    acquireExternalTool "$CONTAINER_URL/vso-task-lib/0.5.5/vso-task-lib.tar.gz" vso-task-lib
fi

# Download the external tools common across Linux platforms (excluding OSX).
if [[ "$PLATFORM" == "linux" ]]; then
    acquireExternalTool "$NODE_URL/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz" node fix_nested_dir
    acquireExternalTool "$NODE_URL/v${NODE_OLD_VERSION}/node-v${NODE_OLD_VERSION}-linux-x64.tar.gz" node-${NODE_OLD_VERSION} fix_nested_dir
fi
