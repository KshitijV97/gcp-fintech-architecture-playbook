# OpenHands with the self-hosted GLM endpoint

OpenHands is used for **longer-running, autonomous tasks** (for example dependency upgrades across services, or test-coverage campaigns) that run in a sandbox and come back as a PR for review.

## Run (Agent Canvas, Docker)

Bind to localhost only; mount only the repository being worked on.

```bash
docker run -it --rm \
  -p 127.0.0.1:8000:8000 \
  -v openhands-data:/home/openhands/.openhands \
  -v "$PWD":/projects/quillpay-platform \
  ghcr.io/openhands/agent-canvas:latest
```

Open `http://localhost:8000/canvas`. For team use, run it on a **Cloud Workstation or a dedicated GKE namespace** in the EU, never on a laptop with production credentials.

## Point it at GLM

In **Settings → LLM → Advanced**:

| Field | Value |
|---|---|
| Custom Model | `openai/glm-5.2` (the vLLM `--served-model-name`, with the `openai/` prefix) |
| Base URL | `https://llm.internal.quillpay.example/v1` |
| API Key | the vLLM `--api-key` value, from Secret Manager |

For SDK or headless use, the same values are read from `LLM_MODEL`, `LLM_BASE_URL` and `LLM_API_KEY`.

## Guardrails

- Treat the agent as **untrusted code execution**: container sandbox, no host Docker socket, no cloud credentials beyond a staging-only service account.
- The repo's `AGENTS.md` rules apply; CI enforces tiers on the resulting PR exactly as for Claude Code sessions.
- Outbound network is restricted by the namespace's egress policy to the GLM endpoint, the package mirrors and GitHub.
