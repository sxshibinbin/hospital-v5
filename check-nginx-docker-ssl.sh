#!/usr/bin/env bash

# Check SSL certificate paths used by nginx/openresty running in Docker.
# Run this script on the Docker host, not inside the container.

set -u

TARGET_HOST="${TARGET_HOST:-121.199.30.129}"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

join_by_space() {
  local item
  for item in "$@"; do
    printf '%s ' "$item"
  done
}

container_label() {
  local container="$1"
  docker inspect -f 'name={{.Name}} image={{.Config.Image}} id={{.Id}}' "$container" 2>/dev/null \
    | sed 's#name=/#name=#'
}

dump_nginx_config() {
  local container="$1"
  local cmd out status
  local cmds=(
    "nginx -T"
    "openresty -T"
    "/usr/sbin/nginx -T"
    "/usr/local/openresty/nginx/sbin/nginx -T"
  )

  for cmd in "${cmds[@]}"; do
    out="$(docker exec "$container" sh -c "$cmd" 2>&1)"
    status=$?

    if [ "$status" -eq 0 ] || printf '%s\n' "$out" | grep -qE 'ssl_certificate|# configuration file '; then
      printf '%s\n' "$out"
      return 0
    fi
  done

  return 1
}

nginx_prefix() {
  local container="$1"
  local out prefix

  out="$(docker exec "$container" sh -c 'nginx -V 2>&1 || openresty -V 2>&1 || /usr/local/openresty/nginx/sbin/nginx -V 2>&1' 2>/dev/null)"
  prefix="$(printf '%s\n' "$out" | sed -n 's/.*--prefix=\([^ ]*\).*/\1/p' | head -n 1)"

  if [ -n "$prefix" ]; then
    printf '%s\n' "$prefix"
  else
    printf '%s\n' "/etc/nginx"
  fi
}

parse_ssl_directives() {
  awk '
    /^# configuration file / {
      file=$0
      sub(/^# configuration file /, "", file)
      sub(/:$/, "", file)
      next
    }

    {
      line=$0
      sub(/[[:space:]]+#.*/, "", line)
      if (line ~ /^[[:space:]]*(ssl_certificate|ssl_certificate_key|ssl_trusted_certificate)[[:space:]]+/) {
        name=line
        sub(/^[[:space:]]*/, "", name)
        sub(/[[:space:]].*/, "", name)

        value=line
        sub(/^[[:space:]]*(ssl_certificate|ssl_certificate_key|ssl_trusted_certificate)[[:space:]]+/, "", value)
        sub(/[[:space:]]*;.*/, "", value)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'\''|'\''$/, "", value)

        if (file == "") {
          file="unknown"
        }
        print name "\t" value "\t" file
      }
    }
  '
}

load_mounts() {
  local container="$1"
  docker inspect -f '{{range .Mounts}}{{printf "%s\t%s\t%s\n" .Source .Destination .Type}}{{end}}' "$container" 2>/dev/null
}

map_container_path_to_host() {
  local cert_path="$1"
  local mounts="$2"
  local best_src=""
  local best_dst=""
  local best_type=""
  local best_len=0
  local src dst type dst_norm suffix

  while IFS=$'\t' read -r src dst type; do
    [ -z "${dst:-}" ] && continue

    dst_norm="${dst%/}"
    if [ "$cert_path" = "$dst_norm" ] || [[ "$cert_path" == "$dst_norm/"* ]]; then
      if [ "${#dst_norm}" -gt "$best_len" ]; then
        best_src="$src"
        best_dst="$dst_norm"
        best_type="$type"
        best_len="${#dst_norm}"
      fi
    fi
  done <<< "$mounts"

  if [ -n "$best_dst" ]; then
    suffix="${cert_path#"$best_dst"}"
    printf '%s\t%s\n' "${best_src%/}${suffix}" "$best_type"
    return 0
  fi

  return 1
}

container_realpath() {
  local container="$1"
  local path="$2"

  docker exec "$container" sh -c 'readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || printf "%s\n" "$1"' sh "$path" 2>/dev/null \
    | head -n 1
}

container_file_exists() {
  local container="$1"
  local path="$2"

  docker exec "$container" sh -c 'test -e "$1"' sh "$path" >/dev/null 2>&1
}

host_realpath() {
  local path="$1"

  if [ -e "$path" ]; then
    readlink -f "$path" 2>/dev/null || realpath "$path" 2>/dev/null || printf '%s\n' "$path"
  else
    printf '%s\n' "$path"
  fi
}

discover_containers() {
  local id name image lower

  docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}' \
    | while IFS=$'\t' read -r id name image; do
        lower="$(printf '%s %s' "$name" "$image" | tr '[:upper:]' '[:lower:]')"
        case "$lower" in
          *nginx*|*openresty*|*1panel*)
            printf '%s\n' "$name"
            ;;
        esac
      done
}

print_copy_hint() {
  local directive="$1"
  local host_path="$2"
  local container="$3"
  local container_path="$4"

  if [ -n "$host_path" ]; then
    log "    Windows 下载命令示例:"
    log "      scp root@${TARGET_HOST}:${host_path} D:\\nginx-ssl\\"
  else
    log "    宿主机没有对应挂载，证书可能只在容器内。可先在服务器执行:"
    log "      docker cp ${container}:${container_path} /root/$(basename "$container_path")"
    log "    然后在 Windows 下载:"
    log "      scp root@${TARGET_HOST}:/root/$(basename "$container_path") D:\\nginx-ssl\\"
  fi

  if [ "$directive" = "ssl_certificate_key" ]; then
    log "    注意: 这是私钥路径，不要发到聊天、群或工单里。"
  fi
}

main() {
  local containers=("$@")
  local container conf prefix mounts label
  local directive raw_path conf_file cert_path real_path exists_status
  local map_line host_path mount_type host_path_real key found_any=0
  declare -A seen

  has_cmd docker || fail "未找到 docker 命令。请在 Docker 宿主机上执行。"
  docker info >/dev/null 2>&1 || fail "当前用户不能访问 Docker。请改用 sudo bash $0，或把当前用户加入 docker 组。"

  if [ "${#containers[@]}" -eq 0 ]; then
    while IFS= read -r container; do
      [ -n "$container" ] && containers+=("$container")
    done < <(discover_containers)
  fi

  if [ "${#containers[@]}" -eq 0 ]; then
    log "没有自动发现 nginx/openresty 容器。当前运行容器如下:"
    docker ps --format '  {{.Names}}\t{{.Image}}\t{{.Ports}}'
    log ""
    log "请指定容器名重试，例如:"
    log "  bash $0 nginx"
    exit 1
  fi

  log "将检查以下容器: $(join_by_space "${containers[@]}")"
  log ""

  for container in "${containers[@]}"; do
    label="$(container_label "$container")"
    log "============================================================"
    log "容器: ${container}"
    [ -n "$label" ] && log "信息: ${label}"

    if ! conf="$(dump_nginx_config "$container")"; then
      log "未能在该容器内执行 nginx -T/openresty -T，跳过。"
      log ""
      continue
    fi

    prefix="$(nginx_prefix "$container")"
    mounts="$(load_mounts "$container")"

    if ! printf '%s\n' "$conf" | parse_ssl_directives | grep -q .; then
      log "该容器 nginx 配置里没有找到 ssl_certificate / ssl_certificate_key。"
      log ""
      continue
    fi

    while IFS=$'\t' read -r directive raw_path conf_file; do
      [ -z "${raw_path:-}" ] && continue

      key="${container}|${directive}|${raw_path}|${conf_file}"
      if [ -n "${seen[$key]:-}" ]; then
        continue
      fi
      seen[$key]=1
      found_any=1

      cert_path="$raw_path"
      if [[ "$cert_path" != /* ]]; then
        cert_path="${prefix%/}/${cert_path}"
      fi

      log ""
      log "  配置文件: ${conf_file}"
      log "  指令: ${directive}"
      log "  容器内配置路径: ${raw_path}"

      if [[ "$raw_path" == *'$'* || "$raw_path" == *'*'* ]]; then
        log "  该路径包含变量或通配符，脚本无法确定唯一证书文件。请按 server_name/SNI 到容器内展开确认。"
        continue
      fi

      real_path="$(container_realpath "$container" "$cert_path")"
      [ -z "$real_path" ] && real_path="$cert_path"

      if container_file_exists "$container" "$cert_path"; then
        exists_status="存在"
      else
        exists_status="不存在或无权限"
      fi

      log "  容器内绝对路径: ${cert_path}"
      log "  容器内真实路径: ${real_path}"
      log "  容器内文件状态: ${exists_status}"

      host_path=""
      mount_type=""
      if map_line="$(map_container_path_to_host "$real_path" "$mounts")"; then
        IFS=$'\t' read -r host_path mount_type <<< "$map_line"
      elif map_line="$(map_container_path_to_host "$cert_path" "$mounts")"; then
        IFS=$'\t' read -r host_path mount_type <<< "$map_line"
      fi

      if [ -n "$host_path" ]; then
        host_path_real="$(host_realpath "$host_path")"
        log "  宿主机映射路径: ${host_path}"
        log "  宿主机真实路径: ${host_path_real}"
        log "  Docker 挂载类型: ${mount_type}"
        print_copy_hint "$directive" "$host_path_real" "$container" "$real_path"
      else
        log "  宿主机映射路径: 未发现对应 volume/bind mount"
        print_copy_hint "$directive" "" "$container" "$real_path"
      fi
    done < <(printf '%s\n' "$conf" | parse_ssl_directives)

    log ""
  done

  if [ "$found_any" -eq 0 ]; then
    log "没有在候选容器中找到 SSL 证书配置。"
    exit 1
  fi
}

main "$@"
