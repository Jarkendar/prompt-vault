# prompt-vault

Personal AI prompt library with semantic search powered by embeddings.

## Overview

A self-hosted, fully static prompt library built on top of GitHub infrastructure.
No external backend required — embeddings are generated via GitHub Actions and
search runs entirely in the browser via GitHub Pages.

## Project Structure
```
prompt-vault/
├── prompts/
│   ├── coding/
│   ├── writing/
│   └── ...
├── scripts/
│   └── generate_embeddings.py
├── web/
│   └── index.html
├── embeddings.json
├── .github/
│   └── workflows/
│       └── generate_embeddings.yml
└── README.md
```

## Roadmap

### Phase 1 – Foundation
- [ ] Directory structure and prompt file schema (JSON)
- [ ] Seed data — initial prompts across multiple categories
- [ ] README with project description

### Phase 2 – Embeddings Pipeline
- [ ] `generate_embeddings.py` using Sentence Transformers (`all-MiniLM-L6-v2`)
- [ ] Local test — generate and save `embeddings.json`
- [ ] GitHub Actions workflow — auto-regenerate embeddings on push to `prompts/`

### Phase 3 – Search UI
- [ ] `index.html` — load `embeddings.json` at runtime
- [ ] Cosine similarity search implemented in vanilla JS (no backend)
- [ ] GitHub Pages — deploy and end-to-end test

### Phase 4 – Polish
- [ ] Filter by category
- [ ] One-click copy prompt to clipboard
- [ ] UI/UX improvements — readable result cards

## Tech Stack

| Component | Technology |
|---|---|
| Embeddings model | `all-MiniLM-L6-v2` (Sentence Transformers) |
| CI/CD | GitHub Actions |
| Hosting | GitHub Pages |
| Search | Cosine similarity in vanilla JS |
| Storage | JSON files in repository |

## License

MIT
