#!/bin/bash
# /bye — 지금 대화 중인 Claude Code 세션 프로세스(와 그 MCP 자식들)만 종료한다.
# VSCode 확장에는 /exit 가 없어 세션이 백그라운드에 쌓이는 문제의 우회.
# 다른 세션은 절대 건드리지 않는다 — 자기 조상 중 첫 번째 `claude` 프로세스만 대상.

# 1) $$ 에서 위로 올라가 첫 번째 claude 프로세스를 찾는다. 그 사이의 조상은 kill 대상에서 뺀다.
p=$$
chain=" $p "
target=""
while [ "$p" -gt 1 ]; do
  comm=$(ps -o comm= -p "$p" 2>/dev/null)
  if [ "$(basename "$comm")" = "claude" ]; then target=$p; break; fi
  p=$(ps -o ppid= -p "$p" | tr -d ' ')
  [ -z "$p" ] && break
  chain="$chain$p "
done
if [ -z "$target" ]; then
  echo "조상 중 claude 프로세스를 찾지 못했습니다 — 아무것도 종료하지 않았습니다."
  exit 1
fi

# 2) claude 가 죽으면 자식들이 launchd 로 재부모화돼 못 찾게 되므로, 죽이기 전에 하위 트리를 스냅샷한다.
desc=$(ps -axo pid,ppid | awk -v root="$target" 'NR>1{pp[$1]=$2} END{for(p in pp){q=p; while(q in pp){ if(pp[q]==root){print p; break}; q=pp[q]}}}')
victims=""
for d in $desc; do
  case "$chain" in *" $d "*) ;; *) victims="$victims $d" ;; esac
done

before=$(pgrep -f 'native-binary/claude' | wc -l | tr -d ' ')
echo "세션 PID $target 종료 (MCP 자식 $(echo $victims | wc -w | tr -d ' ')개 포함). 현재 claude 세션 수: $before"
echo "종료 후 확인: pgrep -f native-binary/claude | wc -l  →  $((before-1)) 이어야 정상"

# 3) TERM → 2초 → 살아남은 것 KILL. claude 가 죽은 뒤엔 stdout 이 끊기므로 출력은 버린다.
exec >/dev/null 2>&1
kill $victims "$target" 2>/dev/null
sleep 2
for v in $victims "$target"; do kill -0 "$v" 2>/dev/null && kill -9 "$v"; done
