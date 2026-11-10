#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

OWNER="kulisaiji_owo"
REPO="saijis_translation"

TOKEN="${GITEE_TOKEN:-}"
if [[ -z "$TOKEN" && -f token.json ]]; then
  TOKEN="$(tr -d '[:space:]' < token.json)"
fi
if [[ -z "$TOKEN" ]]; then
  echo "未找到令牌：请把 Gitee 私人令牌写入同目录 token.json，或设置环境变量 GITEE_TOKEN。" >&2
  exit 1
fi

# 读取令牌所属账号与仓库默认分支；接口不可用时回退到 owner / master
GITEE_USER="$(curl -fsS --max-time 15 "https://gitee.com/api/v5/user?access_token=${TOKEN}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("login",""))' 2>/dev/null || true)"
GITEE_USER="${GITEE_USER:-$OWNER}"
BRANCH="$(curl -fsS --max-time 15 "https://gitee.com/api/v5/repos/${OWNER}/${REPO}?access_token=${TOKEN}" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("default_branch","") or "master")' 2>/dev/null || true)"
BRANCH="${BRANCH:-master}"

# 如有改动则补一次提交
if ! git diff --quiet --cached || ! git diff --quiet; then
  git add -- README.md "mielonu's the sift/zh_cn.json"
  git commit -m "Add Chinese translation for Mielonu's The Sift" || true
fi

# 用临时 askpass 提供凭据，令牌不写入 .git/config
ASKPASS="$(mktemp)"
trap 'rm -f "$ASKPASS"' EXIT
cat > "$ASKPASS" <<'INNER'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "$GITEE_USER" ;;
  *Password*) printf '%s\n' "$GITEE_TOKEN" ;;
  *) printf '\n' ;;
esac
INNER
chmod +x "$ASKPASS"

export GITEE_USER GITEE_TOKEN GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0
git remote remove origin 2>/dev/null || true
git remote add origin "https://gitee.com/${OWNER}/${REPO}.git"
git push -u origin "$BRANCH"

echo "完成：已推送到 https://gitee.com/${OWNER}/${REPO} 的 ${BRANCH} 分支。"
