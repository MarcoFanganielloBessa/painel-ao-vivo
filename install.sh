#!/usr/bin/env bash
# Painel ao vivo: instala em ~/.claude o agente, o hook, o script, a skill e o trecho do CLAUDE.md.
#   ./install.sh              instala ou atualiza
#   ./install.sh --permitir   também libera o script de atualização nas permissões (sem aprovação a cada uso)
#   ./install.sh --remover    desinstala (o estilo salvo continua)
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
INI="<!-- painel-ao-vivo:início -->"
FIM="<!-- painel-ao-vivo:fim -->"
PERMISSAO='Bash(~/.claude/bin/dashboard-update *)'

ok()    { printf '  \033[32m✓\033[0m %s\n' "$1"; }
aviso() { printf '  \033[33m!\033[0m %s\n' "$1"; }
erro()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }

if [ "${1:-}" = "--remover" ]; then
  rm -f "$CLAUDE/agents/dashboard-builder.md" "$CLAUDE/bin/dashboard-update" "$CLAUDE/hooks/dashboard-scope.py"
  rm -rf "$CLAUDE/skills/painel-ao-vivo"
  if [ -f "$CLAUDE/CLAUDE.md" ]; then
    python3 - "$CLAUDE/CLAUDE.md" "$INI" "$FIM" <<'PY'
import re, sys, pathlib
alvo, ini, fim = sys.argv[1:]
p = pathlib.Path(alvo)
t = p.read_text(encoding="utf-8")
p.write_text(re.sub(r"\n*" + re.escape(ini) + r".*?" + re.escape(fim) + r"\n?", "\n", t, flags=re.S), encoding="utf-8")
PY
  fi
  ok "Removido. O estilo que você escolheu continua em $CLAUDE/agent-memory/dashboard-builder/"
  exit 0
fi

echo "Painel ao vivo: instalando em $CLAUDE"

if ! command -v python3 >/dev/null; then erro "python3 não encontrado (necessário)"; exit 1; fi
if ! command -v node >/dev/null; then aviso "node não encontrado: o painel não terá o JavaScript validado antes da entrega"; fi

mkdir -p "$CLAUDE/agents" "$CLAUDE/bin" "$CLAUDE/hooks" "$CLAUDE/skills/painel-ao-vivo"
cp "$AQUI/agents/dashboard-builder.md" "$CLAUDE/agents/"
cp "$AQUI/bin/dashboard-update" "$CLAUDE/bin/"
cp "$AQUI/hooks/dashboard-scope.py" "$CLAUDE/hooks/"
cp "$AQUI/skills/painel-ao-vivo/SKILL.md" "$CLAUDE/skills/painel-ao-vivo/"
chmod +x "$CLAUDE/bin/dashboard-update" "$CLAUDE/hooks/dashboard-scope.py"
ok "agente, hook, script e skill copiados"

resultado=$(python3 - "$CLAUDE/CLAUDE.md" "$AQUI/claude-md.trecho.md" "$INI" "$FIM" <<'PY'
import re, sys, pathlib
alvo, trecho, ini, fim = sys.argv[1:]
p = pathlib.Path(alvo)
texto = p.read_text(encoding="utf-8") if p.exists() else ""
bloco = f"{ini}\n{pathlib.Path(trecho).read_text(encoding='utf-8').strip()}\n{fim}\n"
if ini in texto and fim in texto:
    novo, acao = re.sub(re.escape(ini) + r".*?" + re.escape(fim) + r"\n?", lambda m: bloco, texto, flags=re.S), "atualizado"
elif "## TAREFAS LONGAS" in texto:
    print("existe"); sys.exit(0)
else:
    novo, acao = texto.rstrip("\n") + ("\n\n" if texto.strip() else "") + bloco, "acrescentado"
p.write_text(novo, encoding="utf-8")
print(acao)
PY
)
case "$resultado" in
  existe) aviso "seu CLAUDE.md já tem uma seção '## TAREFAS LONGAS': não mexi. Confira se ela aponta para a skill painel-ao-vivo." ;;
  *)      ok "trecho do CLAUDE.md $resultado" ;;
esac

if [ "${1:-}" = "--permitir" ]; then
  r=$(python3 - "$CLAUDE/settings.json" "$PERMISSAO" <<'PY'
import json, shutil, sys, pathlib
alvo, regra = sys.argv[1:]
p = pathlib.Path(alvo)
d = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
allow = d.setdefault("permissions", {}).setdefault("allow", [])
if regra in allow:
    print("já estava"); sys.exit(0)
if p.exists():
    shutil.copy(p, str(p) + ".bak-painel")
allow.append(regra)
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print("adicionada (backup em settings.json.bak-painel)")
PY
)
  ok "permissão do script de atualização: $r"
elif ! grep -qF "dashboard-update" "$CLAUDE/settings.json" 2>/dev/null; then
  aviso "sem --permitir, o Claude pede aprovação a cada atualização do painel. Para liberar: ./install.sh --permitir"
fi

echo "Skills de design (o painel sai mais refinado com elas):"
tem_skill() { [ -d "$CLAUDE/skills/$1" ] || [ -d "$HOME/.agents/skills/$1" ]; }
for s in emil-design-eng animate; do
  if tem_skill "$s"; then ok "$s"; else aviso "$s faltando"; falta_emil=1; fi
done
if [ "${falta_emil:-0}" = 1 ]; then echo "      npx skills@latest add emilkowalski/skills -g -a claude-code -s emil-design-eng animate -y"; fi
if tem_skill better-ui; then ok "better-ui"; else aviso "better-ui faltando"; echo "      npx skills@latest add jakubkrehel/skills -g -a claude-code -s better-ui -y"; fi
if [ -d "$CLAUDE/plugins/cache/impeccable" ]; then ok "impeccable"; else aviso "impeccable faltando"; echo "      claude plugin marketplace add pbakaus/impeccable && claude plugin install impeccable@impeccable"; fi
if [ -d "$CLAUDE/plugins/cache/claude-plugins-official/frontend-design" ]; then ok "frontend-design"; else aviso "frontend-design faltando"; echo "      claude plugin install frontend-design@claude-plugins-official"; fi

echo "Teste rápido:"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.dashboard"
cat > "$T/.dashboard/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="10">
<script type="application/json" id="estado">{"titulo":"t","tarefas":[],"perguntas":[],"entregas":[],"travas":[]}</script>
<script>JSON.parse(document.getElementById('estado').textContent)</script>
HTML
U="$CLAUDE/bin/dashboard-update"
if (cd "$T" && "$U" tarefa T1 --nome Teste --estado andando >/dev/null && "$U" check >/dev/null); then ok "script de atualização"; else erro "o script de atualização falhou"; exit 1; fi
hook() { local r=0; printf '{"tool_name":"%s","cwd":"%s","tool_input":%s}' "$1" "$T" "$2" | python3 "$CLAUDE/hooks/dashboard-scope.py" >/dev/null 2>&1 || r=$?; echo "$r"; }
if [ "$(hook Write "{\"file_path\":\"$T/.dashboard/index.html\"}")" = 0 ] \
  && [ "$(hook Write '{"file_path":"/tmp/fora.txt"}')" = 2 ] \
  && [ "$(hook Bash '{"command":"rm -rf x"}')" = 2 ]; then ok "hook de segurança"; else erro "o hook de segurança falhou"; exit 1; fi

echo
echo "Pronto. Falta uma coisa: abra uma sessão NOVA do Claude Code (os agentes só são lidos quando a sessão começa)."
