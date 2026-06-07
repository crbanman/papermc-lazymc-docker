#!/bin/sh
set -eu

PAPER_API_URL="https://fill.papermc.io/v3/projects/paper"
PAPER_USER_AGENT="${PAPER_USER_AGENT:-papermc-lazymc-docker/1.0 (https://github.com/crbanman/papermc-lazymc-docker)}"
PAPER_CHANNEL=$(printf '%s' "${PAPER_CHANNEL:-STABLE}" | tr '[:lower:]' '[:upper:]')

fetch_json() {
  curl -fsSL -H "User-Agent: $PAPER_USER_AGENT" "$1"
}

download_file() {
  curl -fsSL -H "User-Agent: $PAPER_USER_AGENT" -o "$2" "$1"
}

get_lazymc_arch() {
  case "$(uname -m)" in
    x86_64|amd64)
      printf '%s\n' "x64"
      ;;
    aarch64|arm64)
      printf '%s\n' "aarch64"
      ;;
    armv7l|armv7*)
      printf '%s\n' "armv7"
      ;;
    *)
      printf 'Unsupported CPU architecture for lazymc: %s\n' "$(uname -m)" >&2
      exit 1
      ;;
  esac
}

replace_lazymc_command() {
  command=$1
  tmp_file=$(mktemp)

  awk -v command="$command" '
    BEGIN {
      gsub(/\\/, "\\\\", command)
      gsub(/"/, "\\\"", command)
    }
    /^[[:space:]]*command[[:space:]]*=/ {
      print "command = \"" command "\""
      next
    }
    { print }
  ' lazymc.toml > "$tmp_file"

  mv "$tmp_file" lazymc.toml
}

mkdir -p /papermc
cd /papermc

if [ "${LAZYMC_VERSION:-latest}" = "latest" ]; then
  LAZYMC_VERSION=$(fetch_json "https://api.github.com/repos/timvisee/lazymc/releases/latest" | jq -r .tag_name)
fi
LAZYMC_ARCH=$(get_lazymc_arch)
LAZYMC_URL="https://github.com/timvisee/lazymc/releases/download/$LAZYMC_VERSION/lazymc-$LAZYMC_VERSION-linux-$LAZYMC_ARCH"
download_file "$LAZYMC_URL" lazymc
chmod +x lazymc

# Generate lazymc.toml if necessary
if [ ! -e lazymc.toml ]; then
  ./lazymc config generate
fi

# Get version information and build download URL.
if [ "${MC_VERSION:-latest}" = "latest" ]; then
  MC_VERSION=$(fetch_json "$PAPER_API_URL" | jq -r '.versions | to_entries[0] | .value[0] // empty')
  if [ -z "$MC_VERSION" ]; then
    printf 'Could not determine the latest Paper version from %s.\n' "$PAPER_API_URL" >&2
    exit 1
  fi
fi

BUILDS_JSON=$(fetch_json "$PAPER_API_URL/versions/$MC_VERSION/builds")
if ! printf '%s' "$BUILDS_JSON" | jq -e 'type == "array"' >/dev/null; then
  printf 'Could not get Paper builds for version %s.\n' "$MC_VERSION" >&2
  printf '%s\n' "$BUILDS_JSON" >&2
  exit 1
fi

if [ "${PAPER_BUILD:-latest}" = "latest" ]; then
  BUILD_JSON=$(printf '%s' "$BUILDS_JSON" | jq -c --arg channel "$PAPER_CHANNEL" 'first(.[] | select(.channel == $channel)) // empty')
else
  BUILD_JSON=$(printf '%s' "$BUILDS_JSON" | jq -c --arg build "$PAPER_BUILD" 'first(.[] | select((.id | tostring) == $build)) // empty')
fi

if [ -z "$BUILD_JSON" ]; then
  printf 'Could not find Paper build "%s" for version %s on channel %s.\n' "${PAPER_BUILD:-latest}" "$MC_VERSION" "$PAPER_CHANNEL" >&2
  exit 1
fi

PAPER_BUILD=$(printf '%s' "$BUILD_JSON" | jq -r '.id')
JAR_NAME=$(printf '%s' "$BUILD_JSON" | jq -r '.downloads."server:default".name // empty')
PAPER_URL=$(printf '%s' "$BUILD_JSON" | jq -r '.downloads."server:default".url // empty')
PAPER_SHA256=$(printf '%s' "$BUILD_JSON" | jq -r '.downloads."server:default".checksums.sha256 // empty')

if [ -z "$JAR_NAME" ] || [ -z "$PAPER_URL" ] || [ -z "$PAPER_SHA256" ]; then
  printf 'Paper build %s for version %s does not include a complete server download.\n' "$PAPER_BUILD" "$MC_VERSION" >&2
  exit 1
fi

# Update if necessary
if [ ! -e "$JAR_NAME" ]; then
  # Remove old server jar(s)
  rm -f ./*.jar
  # Download new server jar
  download_file "$PAPER_URL" "$JAR_NAME"

  ACTUAL_SHA256=$(sha256sum "$JAR_NAME" | awk '{ print $1 }')
  if [ "$ACTUAL_SHA256" != "$PAPER_SHA256" ]; then
    rm -f "$JAR_NAME"
    printf 'Paper download checksum mismatch for %s. Expected %s, got %s.\n' "$JAR_NAME" "$PAPER_SHA256" "$ACTUAL_SHA256" >&2
    exit 1
  fi

  # If this is the first run, accept the EULA
  if [ ! -e eula.txt ]; then
    # Run the server once to generate eula.txt
    java -jar "$JAR_NAME" --nogui || true
    if [ ! -e eula.txt ]; then
      printf 'Paper did not generate eula.txt. Cannot accept the Minecraft EULA automatically.\n' >&2
      exit 1
    fi
    # Edit eula.txt to accept the EULA
    sed -i 's/^eula=false$/eula=true/' eula.txt
  fi
fi

# Add RAM options to Java options if necessary
SERVER_JAVA_OPTS="${JAVA_OPTS:-}"
if [ -n "${MC_RAM:-}" ]; then
  SERVER_JAVA_OPTS="-Xms${MC_RAM} -Xmx${MC_RAM}${SERVER_JAVA_OPTS:+ $SERVER_JAVA_OPTS}"
fi

# Update lazymc config command
LAZYMC_COMMAND="java -server"
if [ -n "$SERVER_JAVA_OPTS" ]; then
  LAZYMC_COMMAND="$LAZYMC_COMMAND $SERVER_JAVA_OPTS"
fi
LAZYMC_COMMAND="$LAZYMC_COMMAND -jar $JAR_NAME --nogui"
replace_lazymc_command "$LAZYMC_COMMAND"

# Start server
exec ./lazymc start
