Implementação em memória dos contratos de `../repositorios/`, carregada de `assets/dados/demonstracao.json` (§22, D9).

- `memoria_demonstracao.dart` — `MemoriaDemonstracao`: estado único, relógio, latência simulada, "sem conexão" (D11) e
  os seis repositórios (`repositorios`). Só `main.dart` a conhece.
- `estado_memoria.dart` — carga do JSON (datas relativas `{"emDias": n, "hora": "HH:mm"}` resolvidas no fuso da
  clínica), integridade referencial e consultas comuns. O "servidor simulado" é este estado.
- `regras.dart` — regras puras: alerta do §7.1, código de convite, ordenação estável.
- `*_memoria.dart` — um por contrato.
