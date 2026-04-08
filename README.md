# prompt-vault

Personal AI prompt library with semantic search powered by embeddings.

## Overview

A self-hosted, fully static prompt library built on top of GitHub infrastructure.
No external backend required — embeddings are generated via GitHub Actions and
search runs entirely in the browser via GitHub Pages.

Prompts are written in English. Search queries can be written in Polish or English
thanks to the multilingual embedding model.

## Project Structure

```
prompt-vault/
├── prompts/
│   ├── education/
│   ├── finance/
│   ├── productivity/
│   ├── travel/
│   └── ...
├── scripts/
│   └── generate_embeddings.py
├── docs/
│   └── index.html
├── embeddings.json
├── .github/
│   └── workflows/
│       └── generate_embeddings.yml
└── README.md
```

## Prompt File Convention

Each prompt consists of two files:

| File | Purpose |
|---|---|
| `prompt-name.md` | Raw prompt content — clean, ready to copy |
| `prompt-name.json` | Metadata: title, category, tags, use_case, tested_on, additional_data |

### Metadata fields

| Field | Description |
|---|---|
| `title` | Display name |
| `category` | Topic-based folder (e.g. `education`, `travel`) |
| `use_case` | Technical context: `claude-project`, `workflow`, etc. |
| `tags` | Array of short labels |
| `description` | One-sentence summary |
| `language` | Prompt language |
| `response_language` | Expected response language |
| `tested_on` | Model the prompt was tested on |
| `version` | Semantic version |
| `additional_data` | Placeholders to replace before use (e.g. `<city>`, `<current_date>`) |

## Roadmap

### Phase 1 – Foundation
- [x] Directory structure and prompt file schema (JSON)
- [x] Seed data — initial prompts across multiple categories
- [x] README with project description

### Phase 2 – Embeddings Pipeline
- [ ] `generate_embeddings.py` using Universal Sentence Encoder Multilingual
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
| Embeddings model | Universal Sentence Encoder Multilingual |
| CI/CD | GitHub Actions |
| Hosting | GitHub Pages |
| Search | Cosine similarity in vanilla JS |
| Storage | Markdown + JSON files in repository |

## License

MIT