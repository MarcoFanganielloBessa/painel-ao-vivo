---
name: painel-ao-vivo
description: Use antes de começar qualquer tarefa com mais de 5 passos ou que deva levar mais de 30 minutos, e enquanto ela roda. Monta e atualiza o painel de progresso ao vivo (.dashboard/index.html) para o usuário acompanhar, ou quando o usuário pedir um painel ou dashboard de acompanhamento. Só a sessão principal usa; subagentes nunca.
---

# Painel ao vivo

O painel é um HTML que o usuário abre com duplo clique e que se atualiza sozinho a cada 10 s.

- O **visual** é do subagente `dashboard-builder`, chamado uma vez por tarefa longa.
- Os **dados** são do script `$HOME/.claude/bin/dashboard-update`: sem modelo, milissegundos, horário do sistema, JSON sempre válido, seguro contra chamadas simultâneas.

Você nunca edita o HTML à mão, nunca lê o HTML e nunca chama o builder só para atualizar dados.

## 1. Montar (antes de começar)

1. O builder só escreve em `.dashboard/` da pasta onde foi chamado. Chame-o de dentro da pasta onde o trabalho acontece (com worktree, monte lá dentro) e anote o caminho absoluto `D=<pasta>/.dashboard`. Pegue a hora com `~/.claude/bin/dashboard-update agora`.
2. Chame `dashboard-builder` com `run_in_background: true`. Prompt curto, sem colar o plano:
   - `modo: montar` · `agora: $AGORA` · `titulo` · `idioma: pt-BR`
   - `estado`: tarefas (`id: nome`, todas pendente) e perguntas já conhecidas (`id: texto | ação padrão`)
   - `contexto`: 2 ou 3 linhas sobre o trabalho e o que o usuário mais quer ver
3. Se ele responder `PRECISO_DO_ESTILO`, pergunte ao usuário com AskUserQuestion (claro ou escuro; denso ou arejado; cor de destaque, com o verde [STUDIO] `#7A8B3C` como uma das opções) e chame de novo com as respostas. Só acontece na primeira vez de todas: depois o estilo vem da memória do agente.
4. Enquanto ele monta (cerca de 2 min), siga com o trabalho. Quando terminar, diga o caminho e abra com `open $D/index.html`.
5. Se o usuário pedir outro estilo ou outro visual, chame o builder com `modo: reformular` e `novo estilo: <as 3 escolhas>`; ele mantém os dados e atualiza a memória.
6. Na primeira montagem de todas, ou depois de mudar de estilo, rode a skill `web-design-guidelines` no HTML e mande as correções ao builder (`modo: reformular`). Nas outras montagens, pule (custa tokens).

## 2. Atualizar (depois de cada passo)

Um comando por evento. Junte com `&&` quando um passo mexe em duas coisas.

```bash
~/.claude/bin/dashboard-update tarefa T3 --estado andando --nota "implementador haiku"
~/.claude/bin/dashboard-update tarefa T3 --estado revisao
~/.claude/bin/dashboard-update tarefa T3 --estado correcao --nota "rodada 1/5"
~/.claude/bin/dashboard-update tarefa T3 --estado feito && ~/.claude/bin/dashboard-update entrega "T3 cliente Windsor: 9/9 testes, commit a1b2c3d"
~/.claude/bin/dashboard-update decisao "Ruling: <o que decidi> (custo se errado: <...>)"
~/.claude/bin/dashboard-update pergunta P1 "Cole a chave real do Windsor no .env" --padrao "Sigo com chave placeholder; o passo real fica pendente"
~/.claude/bin/dashboard-update resolver P1
~/.claude/bin/dashboard-update trava T5 "motivo"     # depois: destrava T5
```

- Escreva o comando direto, sem guardar em variável: o zsh não separa `$VAR` em palavras.
- O script acha o `.dashboard` subindo as pastas a partir do cwd. Se o cwd estiver fora da pasta do trabalho, acrescente `--dir $D` (caminho absoluto).
- Nunca escreva horário: o script usa o relógio.
- Se o script disser que o bloco de estado não existe, chame o builder em `modo: montar`.

## 3. Decisões que dependem do usuário

Acrescente a pergunta com a ação padrão (`pergunta`) e siga com o padrão, sem esperar. Ao resolver, `resolver`.
As paradas obrigatórias (ação destrutiva, segurança, efeito fora do worktree) continuam parando: nelas, pergunte de verdade.

## 4. Terminar

Todas as tarefas em `feito`, uma última `entrega`, perguntas resolvidas marcadas.
