# Hermes Agent - Docker Compose Setup

Self-hosted [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research, containerisé avec gateway Telegram et WebUI.

## Fonctionnalités

- **Agent IA autonome** — exécution de tâches, code, navigation web, raisonnement
- **Gateway Telegram** — contrôle ton agent depuis Telegram
- **WebUI** — interface web sombre et légère (port 8787)
- **Multi-provider** — OpenAI, Anthropic, OpenRouter, Groq, Mistral, Ollama, GitHub Copilot, etc.
- **Dashboard** — monitoring local (port 9119)
- **CLI unifié** — `scripts/hermes-cli` pour tout gérer (start/stop/menu/provider/logs)
- **Multi-profile** — plusieurs agents avec des configs et personnalités différentes

## Architecture

```
┌──────────────┐    ┌───────────────┐
│  hermes      │    │  hermes-webui │
│  gateway     │◄──►│  port 8787    │
│  ports       │    │  (agent in-   │
│  8642/9119   │    │   process)    │
└──────┬───────┘    └───────┬───────┘
       └────────┬───────────┘
                │
       ┌────────▼────────┐
       │  data_runtime/  │
       │  (config,       │
       │   sessions,     │
       │   skills,       │
       │   mémoire)      │
       └─────────────────┘
```

Les deux conteneurs partagent `data_runtime/`. La configuration source est dans `config/` et synchronisée vers `data_runtime/` au bootstrap.

## Quick Start

```bash
# 1. Configuration
cp config/.env.example config/.env
nano config/.env          # API keys, tokens Telegram, IDs autorisés
nano config/config.yaml   # provider/modèle par défaut
nano config/SOUL.md       # personnalité (optionnel)

# 2. Initialisation
mkdir -p data_runtime
./scripts/sync-runtime-config.sh

# 3. Démarrage
./scripts/hermes-cli start   # ou: ./scripts/hermes-cli menu (recommandé)

# Dashboard: http://127.0.0.1:9119
# WebUI:     http://127.0.0.1:8787
```

## Scripts

| Script | Rôle |
|---|---|
| `scripts/hermes-cli` | Hub principal : start/stop/menu/provider/doctor/logs/setup |
| `scripts/sync-runtime-config.sh` | Synchronise `config/` → `data_runtime/` |
| `scripts/maintenance-data.sh` | Backup rotatif + archivage |

### hermes-cli

```bash
./scripts/hermes-cli            # Menu interactif
./scripts/hermes-cli doctor     # Vérifier la santé
./scripts/hermes-cli provider add   # Ajouter/changer de provider
./scripts/hermes-cli provider login # Login provider (si requis)
./scripts/hermes-cli menu       # Menu interactif interne
./scripts/hermes-cli setup      # Wizard interactif
```

### WebUI

```bash
./scripts/hermes-cli webui status   # Statut du WebUI
./scripts/hermes-cli webui logs     # Logs
./scripts/hermes-cli webui restart  # Redémarrage
```

## Configuration

```
.
├── docker-compose.yml
├── Dockerfile
├── config/
│   ├── .env.example
│   ├── .env              # local, non versionné
│   ├── config.yaml       # provider/modèle par défaut
│   └── SOUL.md           # personnalité (optionnel)
├── data_runtime/         # runtime monté dans /opt/data (écrivable)
├── data_archive/         # archives (maintenance)
├── backups/              # backups
└── scripts/              # scripts utilitaires
```

### Variables essentielles (config/.env)

| Variable | Description |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Token bot @BotFather |
| `TELEGRAM_ALLOWED_USERS` | IDs Telegram autorisés (csv) |
| `OPENAI_API_KEY` | Clé OpenAI |
| `ANTHROPIC_API_KEY` | Clé Anthropic |
| `OPENROUTER_API_KEY` | Clé OpenRouter |
| `HERMES_WEBUI_PASSWORD` | Mot de passe WebUI (recommandé si exposé) |
| `HERMES_WORKSPACE` | Chemin workspace pour le navigateur WebUI |

### Provider par défaut (config/config.yaml)

```yaml
model:
  provider: openrouter
  default: deepseek/deepseek-v4-flash:free
```

Providers supportés : `openrouter`, `anthropic`, `openai`, `nous`, `custom`, `ollama`, `google`, `kimi-coding`, `mistral`, `copilot`

## Setup Telegram

1. Créer un bot via [@BotFather](https://t.me/BotFather)
2. Mettre le token dans `config/.env`
3. Récupérer ton user ID via [@userinfobot](https://t.me/userinfobot)
4. Ajouter l'ID dans `TELEGRAM_ALLOWED_USERS`
5. `./scripts/hermes-cli start`

## Sécurité dashboard

Par défaut le dashboard écoute sur `127.0.0.1` uniquement. Pour un accès distant, place un reverse proxy (Caddy/Nginx) avec Basic Auth + TLS devant — **ne jamais exposer 9119 directement**.

## Multi-profile

Ajoute un service dans `docker-compose.yml` avec ses propres volumes `data-*` et `config-*`:
```yaml
services:
  hermes-work:
    build: .
    container_name: hermes-work
    command: gateway run
    ports:
      - "8642:8642"
      - "9119:9119"
    volumes:
      - ./data-work:/opt/data
      - ./config-work/SOUL.md:/opt/data/SOUL.md:ro
```

## Article associé

Blog post : [devbyben.fr](https://devbyben.fr/blog/hermes-agent-lagent-ia-autonome-open-source) — présentation complète + guide de déploiement.
