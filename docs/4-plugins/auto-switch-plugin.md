# Auto-Switch Plugin

Plugin de troca automatica de modo do OpenCode.

## Localizacao

```
Plugin: "auto-switch-mode.ts" (interno)
```

## Funcionalidade

Detecta automaticamente o contexto e troca o modo do OpenCode:

```
┌─────────────────────────────────────────────────┐
│  Contexto Detectado                             │
│      │                                          │
│      ├── Codigo → Modo "code"                   │
│      ├── Terminal → Modo "terminal"              │
│      ├── Documento → Modo "read"                │
│      └── Edit → Modo "edit"                     │
└─────────────────────────────────────────────────┘
```

## Configuracao

Listado no config:

```jsonc
"plugin": [
    "auto-switch-mode.ts",
    ...
]
```

## Vantagens

- Transicao suave entre modos
- Sem necessidade de troca manual
- Melhora produtividade
- Contexto preservado entre trocas
