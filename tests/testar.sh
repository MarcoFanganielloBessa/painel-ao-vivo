#!/usr/bin/env bash
# Testes de quem mantém o pacote. Não escrevem em ~/.claude; usam uma pasta temporária.
# Uso: ./tests/testar.sh
set -uo pipefail
AQUI="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$AQUI/hooks/dashboard-scope.py"
U="$AQUI/bin/dashboard-update"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
falhas=0
conferir() { # nome esperado obtido
  if [ "$2" = "$3" ]; then printf '  ok    %s\n' "$1"; else printf '  FALHA %s (esperado %s, veio %s)\n' "$1" "$2" "$3"; falhas=$((falhas + 1)); fi
}

echo "hook (o hook usa ~/.claude/bin/dashboard-update como único comando permitido)"
h() { local r=0; printf '{"tool_name":"%s","cwd":"%s","tool_input":%s}' "$1" "$T" "$2" | python3 "$HOOK" >/dev/null 2>&1 || r=$?; echo "$r"; }
S="$HOME/.claude/bin/dashboard-update"
conferir "Write dentro de .dashboard"        0 "$(h Write "{\"file_path\":\"$T/.dashboard/index.html\"}")"
conferir "Write relativo em .dashboard"      0 "$(h Write '{"file_path":".dashboard/a.html"}')"
conferir "Write na memória do agente"        0 "$(h Write "{\"file_path\":\"$HOME/.claude/agent-memory/dashboard-builder/estilo.md\"}")"
conferir "Write fora (/tmp/x)"               2 "$(h Write '{"file_path":"/tmp/x"}')"
conferir "Write escapando com .."            2 "$(h Write '{"file_path":".dashboard/../x.txt"}')"
conferir "Write em skills (só leitura)"      2 "$(h Write "{\"file_path\":\"$HOME/.claude/skills/x.md\"}")"
conferir "Edit no CLAUDE.md"                 2 "$(h Edit "{\"file_path\":\"$HOME/.claude/CLAUDE.md\"}")"
conferir "Read de ~/.ssh"                    2 "$(h Read "{\"file_path\":\"$HOME/.ssh/id_rsa\"}")"
conferir "Read do .env do projeto"           2 "$(h Read "{\"file_path\":\"$T/.env\"}")"
conferir "Read em skills"                    0 "$(h Read "{\"file_path\":\"$HOME/.claude/skills/painel-ao-vivo/SKILL.md\"}")"
conferir "Glob com path em .dashboard"       0 "$(h Glob '{"path":".dashboard","pattern":"*.html"}')"
conferir "Glob sem path"                     2 "$(h Glob '{"pattern":"*"}')"
conferir "Glob com padrão absoluto"          2 "$(h Glob '{"path":".dashboard","pattern":"/etc/*"}')"
conferir "Bash: check com ~"                 0 "$(h Bash '{"command":"~/.claude/bin/dashboard-update check"}')"
conferir "Bash: check com caminho absoluto"  0 "$(h Bash "{\"command\":\"$S check\"}")"
conferir "Bash: check encadeado com rm"      2 "$(h Bash "{\"command\":\"$S check; rm -rf ~\"}")"
conferir "Bash: rm"                          2 "$(h Bash '{"command":"rm -rf x"}')"
conferir "Bash: outro subcomando"            2 "$(h Bash "{\"command\":\"$S tarefa T1\"}")"
conferir "Bash: --dir"                       2 "$(h Bash "{\"command\":\"$S --dir /tmp check\"}")"
conferir "Bash: ~outro-usuario"              2 "$(h Bash '{"command":"~root/.claude/bin/dashboard-update check"}')"

echo "script"
mkdir -p "$T/p/.dashboard/sub" && cd "$T/p/.dashboard/sub" || exit 1
cat > "$T/p/.dashboard/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="10">
<script type="application/json" id="estado">{"titulo":"t","tarefas":[],"perguntas":[],"entregas":[],"travas":[]}</script>
<script>const e = JSON.parse(document.getElementById('estado').textContent);</script>
HTML
estado() { python3 -c "
import re,json
h=open('$T/p/.dashboard/index.html').read()
e=json.loads(re.search(r'id=\"estado\">(.*?)</script>',h,re.S).group(1).replace('<\\\\/','</'))
print($1)"; }
"$U" check >/dev/null 2>&1;                               conferir "check ok (achando .dashboard de uma subpasta)" 0 $?
"$U" tarefa T1 --nome A --estado andando;                 conferir "tarefa cria e muda estado" andando "$(estado 'e["tarefas"][0]["estado"]')"
"$U" entrega 'x </script> y';                             conferir "entrega escapa </script>" 1 "$(estado 'len(e["entregas"])')"
"$U" pergunta P1 "q" --padrao "d"; "$U" resolver P1;      conferir "pergunta e resolver" True "$(estado 'e["perguntas"][0]["resolvida"]')"
"$U" trava T1 "m"; conferir "trava marca a tarefa" travado "$(estado 'e["tarefas"][0]["estado"]')"
"$U" destrava T1;  conferir "destrava volta a andando" andando "$(estado 'e["tarefas"][0]["estado"]')"
"$U" resolver P9 >/dev/null 2>&1;                         conferir "resolver inexistente falha" 1 $?
for i in $(seq 1 30); do "$U" entrega "e$i" & done; wait
conferir "30 chamadas simultâneas não perdem nada" 31 "$(estado 'len(e["entregas"])')"
sed -i.bak 's/const e = JSON/const e = = JSON/' "$T/p/.dashboard/index.html"
"$U" check >/dev/null 2>&1;                               conferir "check pega erro de JavaScript" 1 $?

echo
if [ "$falhas" = 0 ]; then echo "Tudo certo."; else echo "$falhas falha(s)."; exit 1; fi
