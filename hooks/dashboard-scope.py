#!/usr/bin/env python3
"""Confina o dashboard-builder.

Escreve só em <cwd>/.dashboard/ e na própria memória; lê também as pastas de skills.
O único comando de shell permitido é `dashboard-update check`.
"""
import json
import os
import re
import shlex
import sys


def bloquear(msg):
    print(f"dashboard-builder: {msg}", file=sys.stderr)
    sys.exit(2)


d = json.load(sys.stdin)
ti = d.get("tool_input", {})
tool = d.get("tool_name", "")
cwd = d.get("cwd") or os.getcwd()
home = os.path.expanduser("~")
real = os.path.realpath

if tool == "Bash":
    cmd = ti.get("command", "")
    script = os.path.join(home, ".claude/bin/dashboard-update")
    if re.fullmatch(r"[A-Za-z0-9_ ./:=+@%,~-]+", cmd):
        argv = shlex.split(cmd)
        if len(argv) == 2 and argv[1] == "check" and os.path.expanduser(argv[0]) == script:
            sys.exit(0)
    bloquear("Bash só pode rodar: ~/.claude/bin/dashboard-update check")

alvo = ti.get("file_path") or ti.get("path")
if not alvo:
    bloquear("informe um caminho dentro de .dashboard/")
alvo = real(os.path.join(cwd, alvo))

escrita = [
    real(os.path.join(cwd, ".dashboard")),
    real(os.path.join(home, ".claude/agent-memory/dashboard-builder")),
]
leitura = escrita + [real(os.path.join(home, p)) for p in (".claude/skills", ".claude/plugins", ".agents/skills")]
permitidos = escrita if tool in ("Write", "Edit") else leitura

if not any(alvo == b or alvo.startswith(b + os.sep) for b in permitidos):
    bloquear(f"{tool} fora da área permitida: {alvo}")

padrao = ti.get("pattern", "")
if tool == "Glob" and (padrao.startswith("/") or ".." in padrao):
    bloquear("padrão de Glob fora da área permitida")
sys.exit(0)
