# ============================================================
# Hermes Agent - Docker Compose Setup
# ============================================================

Self-hosted Hermes Agent by Nous Research, containerized with Telegram gateway.

## Article associe

- Blog post (DevByBen): https://devbyben.fr/blog/hermes-agent-lagent-ia-autonome-open-source
  - Preview: presentation complete de Hermes Agent + guide de deploiement Docker avec ce boilerplate.

## Quick Start

### 1. Configuration initiale

```bash
# Copier le template des variables d'environnement
cp config/.env.example config/.env

# Editer les fichiers de config
nano config/.env          # API keys, tokens, IDs autorises
nano config/config.yaml   # provider/model par defaut
nano config/SOUL.md       # personnalite (optionnel)
```

### 2. Initialiser le runtime

```bash
mkdir -p data_runtime
./scripts/sync-runtime-config.sh
```

### 3. Demarrer

```bash
# Demarrage
./scripts/hermes-cli start

# Menu interactif (recommande)
./scripts/hermes-cli menu

# Dashboard local
# http://127.0.0.1:9119
```

## Scripts utilitaires

### Index scripts

| Script | Role | Exemple |
|---|---|---|
| `scripts/hermes-cli` | Hub principal (CLI Hermes + provider add/login/connect + ops Docker + maintenance) | `./scripts/hermes-cli provider add` |
| `scripts/sync-runtime-config.sh` | Synchronise `config/` vers `data_runtime/` (`--force` pour ecraser runtime) | `./scripts/sync-runtime-config.sh --force` |
| `scripts/maintenance-data.sh` | Backup rotatif de `data_runtime` + prune de `data_archive` | `./scripts/maintenance-data.sh --keep 7 --archive-days 45` |

```bash
# CLI Hermes dans le conteneur
./scripts/hermes-cli

# Ouvrir explicitement le menu interactif interne
./scripts/hermes-cli menu

# Exemple: verifier la sante Hermes
./scripts/hermes-cli doctor

# Ouvrir le picker pour ajouter/changer de provider
./scripts/hermes-cli provider add

# Login provider (si requis par le provider)
./scripts/hermes-cli provider login
./scripts/hermes-cli provider login nous

# Connexion provider GitHub Copilot (via picker provider Hermes)
./scripts/hermes-cli provider add

# Synchroniser config/ -> data_runtime/
./scripts/sync-runtime-config.sh

# Forcer la synchro (ecrase le runtime)
./scripts/sync-runtime-config.sh --force
```

La connexion provider (dont Copilot) passe maintenant par les commandes Hermes standard
(`provider add` / `provider login`) via `scripts/hermes-cli`.

Important: pour que le dashboard puisse sauvegarder les changements de modeles
et que le provider GitHub Copilot puisse persister son token, `/opt/data/config.yaml`
et `/opt/data/.env` doivent etre ecrivables dans le conteneur.

Le compose de ce boilerplate n'attache donc pas `config/config.yaml` et `config/.env`
directement sur `/opt/data/*`; les fichiers runtime sont:
- `data_runtime/config.yaml`
- `data_runtime/.env`

Ils sont initialises automatiquement depuis `config/` au premier lancement des scripts.

Pour synchroniser explicitement apres modification de `config/`:

```bash
./scripts/sync-runtime-config.sh
```

Par defaut, le script n'ecrase pas un runtime deja different (protection).
Pour forcer l'ecrasement:

```bash
./scripts/sync-runtime-config.sh --force
docker compose restart hermes
```

## Initialisation interactive

Au premier setup, lance le wizard directement via le hub:

```bash
./scripts/hermes-cli setup
```

## Configuration

### Structure des fichiers (etat actuel)

```
.
|-- docker-compose.yml
|-- Dockerfile
|-- config/
|   |-- .env.example
|   |-- .env                  # local, non versionne
|   |-- config.yaml           # source versionnee (template)
|   `-- SOUL.md
|-- data_runtime/             # runtime monte dans /opt/data (writable)
|-- data_archive/             # archives optionnelles (maintenance)
|-- backups/                  # backups optionnels
`-- scripts/
    |-- hermes-cli
    |-- sync-runtime-config.sh
    `-- maintenance-data.sh
```
### Variables d'environnement (config/.env)

| Variable | Description |
|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather |
| `TELEGRAM_ALLOWED_USERS` | Comma-separated Telegram user IDs |
| `OPENAI_API_KEY` | OpenAI API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENROUTER_API_KEY` | OpenRouter API key |
| `GROQ_API_KEY` | Groq API key (fast inference) |
| `MISTRAL_API_KEY` | Mistral AI API key |
| `GH_TOKEN` / `GITHUB_TOKEN` | Token GitHub (utile pour provider Copilot et integrations GitHub) |
| `HF_TOKEN` | HuggingFace token (for model downloads, optional) |
| `HERMES_WEBUI_PASSWORD` | Password for WebUI (recommandé si expose sur 0.0.0.0) |
| `HERMES_WORKSPACE` | Chemin du workspace pour le navigateur de fichiers WebUI |

### Configuration provider (config/config.yaml)

Definis le provider et le modele par defaut dans `config.yaml`:

```yaml
model:
  provider: openrouter
  default: deepseek/deepseek-v4-flash:free
```

OpenRouter free model examples (checked live):
- `deepseek/deepseek-v4-flash:free`
- `poolside/laguna-m.1:free`
- `openai/gpt-oss-120b:free`
- `z-ai/glm-4.5-air:free`
- `nvidia/nemotron-3-super-120b-a12b:free`
- `meta-llama/llama-3.3-70b-instruct:free`
- `qwen/qwen3-coder:free`
- `qwen/qwen3-next-80b-a3b-instruct:free`
- `google/gemma-4-26b-a4b-it:free`
- `google/gemma-4-31b-it:free`

Supported providers: `openrouter`, `anthropic`, `openai`, `nous`, `custom`, `ollama`, `google`, `kimi-coding`, `mistral`, `copilot`

### Setup Telegram

1. Creer un bot via [@BotFather](https://t.me/BotFather)
2. Recuperer le token et le mettre dans `config/.env`
3. Recuperer ton user ID via [@userinfobot](https://t.me/userinfobot)
4. Ajouter ton ID dans `TELEGRAM_ALLOWED_USERS`
5. Demarrer Hermes: `./scripts/hermes-cli start`

### Mot de passe / securite dashboard

Le dashboard Hermes n'integre pas (pour l'instant) d'auth forte native de type login/password.
Le mode recommande est:

1) Garder les ports bindes sur localhost uniquement (deja le cas dans ce boilerplate):
   - 127.0.0.1:9119:9119
   - 127.0.0.1:8642:8642

2) Si acces distant necessaire: placer un reverse proxy (Caddy/Nginx/Traefik) avec Basic Auth
   + TLS devant le dashboard, et ne jamais exposer 9119 directement sur Internet.

3) Eviter `--insecure` sur reseau non fiable. Quand Hermes est lance sur 0.0.0.0,
   il affiche explicitement un warning indiquant qu'il n'y a pas d'auth robuste.

Exemple Caddy (basic auth):

```caddy
hermes.example.com {
  basicauth {
    ben JDJhJDE0JHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eA==
  }

  reverse_proxy 127.0.0.1:9119
}
```

Genere le hash avec:
```bash
caddy hash-password --plaintext 'ton-mot-de-passe-fort'
```

## Migration vers data_runtime + rollback

### Etat cible

- Runtime Hermes monte depuis `./data_runtime` vers `/opt/data`
- Configuration source versionnee dans `./config/` (copiee dans `data_runtime` au bootstrap)
- Fichiers runtime ecrivables utilises par Hermes:
  - `data_runtime/config.yaml` -> `/opt/data/config.yaml`
  - `data_runtime/.env` -> `/opt/data/.env`
- `config/SOUL.md` monte en lecture seule vers `/opt/data/SOUL.md`
- Anciennes donnees lourdes deplacees dans `data_archive/<timestamp>/`
- Backup complet disponible dans `backups/`

### Procedure de migration (safe)

```bash
# 1) Stop
docker compose down

# 2) Backup complet
mkdir -p backups
ts=$(date +%Y%m%d_%H%M%S)
tar -czf backups/hermes_data_${ts}.tgz data

# 3) Creation runtime + copie selective
mkdir -p data_runtime data_archive/$ts
rsync -a --delete \
  --exclude 'hermes-agent' \
  --exclude 'venv' \
  --exclude 'home' \
  --exclude 'portfolio-next' \
  --exclude 'codegraph' \
  data/ data_runtime/

# 4) Archivage des dossiers lourds
mv data/hermes-agent data/venv data/home data/portfolio-next data/codegraph data_archive/$ts/

# 5) Redemarrage
docker compose up -d
curl -fsS http://127.0.0.1:8642/health
```

### Rollback immediat

```bash
# 1) Stop
docker compose down

# 2) Remettre le volume legacy dans docker-compose.yml
#    ./data:/opt/data

# 3) Redemarrer
docker compose up -d
curl -fsS http://127.0.0.1:8642/health
```

### Maintenance reguliere

```bash
# Dry-run
./scripts/maintenance-data.sh --dry-run

# Execution reelle (defauts: keep=5, archive-days=30)
./scripts/maintenance-data.sh

# Exemple personnalise
./scripts/maintenance-data.sh --keep 7 --archive-days 45
```

## Commandes utiles

```bash
# Demarrer
./scripts/hermes-cli start

# Stop
./scripts/hermes-cli stop

# Logs
docker compose logs -f hermes

# Menu interactif
./scripts/hermes-cli menu

# CLI Hermes directe
./scripts/hermes-cli run

# Health
./scripts/hermes-cli doctor
```

## Hermes WebUI

[Hermes WebUI](https://github.com/nesquena/hermes-webui) est une interface web
sombre et legere pour Hermes Agent. Parite quasi-totale avec le CLI : tout ce
que tu fais en terminal est disponible depuis le navigateur.

### Architecture

```
┌────────────────┐    ┌──────────────────┐
│  hermes        │    │  hermes-webui    │
│  gateway run   │◄───│  port 8787       │
│  port 8642     │    │  (agent in-proc) │
│  port 9119     │    │                  │
└────────┬───────┘    └────────┬─────────┘
         │                     │
         └────────┬────────────┘
                  │
         ┌────────▼────────┐
         │  hermes-agent-  │
         │  src (volume)   │
         └─────────────────┘
```

- **hermes** : gateway + dashboard (existant, inchange)
- **hermes-webui** : interface web, demarre son propre agent in-process
- **hermes-agent-src** : volume partage contenant le source de l'agent (pour
  l'installation des dependances Python dans le conteneur WebUI)

Les deux conteneurs partagent `data_runtime/` (config, sessions, skills, memoire).

### Quick Start

```bash
# Demarrage (tout en un)
docker compose up -d

# Ouvrir dans le navigateur
xdg-open http://localhost:8787
# ou:
./scripts/hermes-cli menu  # option 15
```

Le WebUI detecte automatiquement la configuration Hermes existante dans
`data_runtime/` (provider, modele, skills, sessions). Aucune configuration
supplementaire requise.

### Gestion via hermes-cli

```bash
# Status
./scripts/hermes-cli webui status

# Logs
./scripts/hermes-cli webui logs

# Redemarrage
./scripts/hermes-cli webui restart

# Arret/relance
./scripts/hermes-cli webui stop
./scripts/hermes-cli webui start
```

### Mot de passe (recommandé pour l'acces distant)

Si tu exposes le WebUI au-dela de `127.0.0.1`, configure un mot de passe :

```bash
echo "HERMES_WEBUI_PASSWORD=ton-mot-de-passe-fort" >> config/.env
docker compose up -d --force-recreate hermes-webui
```

### Gateway-backed browser chat (optionnel)

Par defaut, le WebUI demarre son propre agent in-process pour le chat.
Tu peux le faire transiter par le gateway de l'agent principal :

```bash
HERMES_WEBUI_CHAT_BACKEND=gateway \
HERMES_WEBUI_GATEWAY_BASE_URL=http://hermes:8642 \
HERMES_WEBUI_GATEWAY_API_KEY=ta-cle-api \
docker compose up -d --force-recreate hermes-webui
```

### Workspace

Le navigateur de fichiers du WebUI monte `~/workspace` par defaut.
Pour utiliser un repertoire different :

```bash
HERMES_WORKSPACE=/chemin/vers/tes/projets docker compose up -d
```

### Mise a jour du volume agent source

Quand l'image `nousresearch/hermes-agent` est mise a jour, le volume
`hermes-agent-src` conserve l'ancien source. Pour le reinitialiser :

```bash
docker compose down
docker volume rm hermes_agent_docker_hermes-agent-src
docker compose pull
docker compose up -d
```

### Notes

- Le WebUI et le gateway agent partagent le meme `data_runtime/`. Les sessions
  creees depuis le WebUI apparaissent dans le gateway et vice-versa.
- En deux-conteneurs, les outils lances depuis le WebUI execution dans le
  conteneur WebUI (pas dans le conteneur agent). Pour des outils systeme
  (git, node), soit etends le Dockerfile WebUI, soit utilise le setup
  mono-conteneur (`docker-compose.yml` upstream).
- Le volume `hermes-agent-src` est monte en lecture-seule dans le WebUI.
  L'init script le copie dans un tmpfs pour l'installation des deps.

## Setup multi-profile

Pour plusieurs agents, ajoute un service supplementaire dans `docker-compose.yml`:

```yaml
services:
  hermes-work:
    build: .
    container_name: hermes-work
    restart: unless-stopped
    command: gateway run
    ports:
      - "8642:8642"
      - "9119:9119"
    volumes:
      - ./data-work:/opt/data
      - ./config-work/SOUL.md:/opt/data/SOUL.md:ro

  hermes-personal:
    build: .
    container_name: hermes-personal
    restart: unless-stopped
    command: gateway run
    ports:
      - "8643:8642"
      - "9120:9119"
    volumes:
      - ./data-personal:/opt/data
      - ./config-personal/SOUL.md:/opt/data/SOUL.md:ro
```
