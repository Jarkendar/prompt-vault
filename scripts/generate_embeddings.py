#!/usr/bin/env python3
"""
generate_embeddings.py
Generates embeddings for all prompts in the prompts/ directory
using paraphrase-multilingual-MiniLM-L12-v2 (sentence-transformers).
Outputs embeddings.json to the repo root.
"""

import json
import pathlib

from sentence_transformers import SentenceTransformer

# ── Config ────────────────────────────────────────────────────────────────────
PROMPTS_DIR = pathlib.Path("prompts")
OUTPUT_FILE = pathlib.Path("embeddings.json")
MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"

# ── Load model ────────────────────────────────────────────────────────────────
print("Loading model...")
model = SentenceTransformer(MODEL_NAME)
print("Model loaded.")

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_prompt_pair(md_path: pathlib.Path) -> dict | None:
    """Load .md and matching .json metadata for a prompt."""
    json_path = md_path.with_suffix(".json")

    if not json_path.exists():
        print(f"  [SKIP] No matching JSON for {md_path}")
        return None

    content = md_path.read_text(encoding="utf-8").strip()
    metadata = json.loads(json_path.read_text(encoding="utf-8"))

    return {
        "path": str(md_path),
        "content": content,
        "metadata": metadata,
    }


def build_embedding_text(prompt: dict) -> str:
    """Build a rich text for embedding: title + description + tags + content."""
    meta = prompt["metadata"]
    parts = [
        meta.get("title", ""),
        meta.get("description", ""),
        " ".join(meta.get("tags", [])),
        prompt["content"],
    ]
    return " ".join(filter(None, parts))


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    md_files = sorted(PROMPTS_DIR.rglob("*.md"))
    print(f"Found {len(md_files)} markdown files.")

    prompts = []
    for md_path in md_files:
        print(f"  Loading: {md_path}")
        prompt = load_prompt_pair(md_path)
        if prompt:
            prompts.append(prompt)

    if not prompts:
        print("No prompts found. Exiting.")
        return

    print(f"\nGenerating embeddings for {len(prompts)} prompts...")
    texts = [build_embedding_text(p) for p in prompts]
    embeddings = model.encode(texts, show_progress_bar=True)

    results = []
    for prompt, vector in zip(prompts, embeddings):
        meta = prompt["metadata"]
        results.append({
            "path": prompt["path"],
            "title": meta.get("title", ""),
            "category": meta.get("category", ""),
            "use_case": meta.get("use_case", ""),
            "tags": meta.get("tags", []),
            "description": meta.get("description", ""),
            "language": meta.get("language", "en"),
            "response_language": meta.get("response_language", "en"),
            "tested_on": meta.get("tested_on", ""),
            "version": meta.get("version", "1.0.0"),
            "additional_data": meta.get("additional_data", []),
            "vector": vector.tolist(),
            "trigger_description": meta.get("trigger_description", ""),
            "compatible_with": meta.get("compatible_with", []),
        })

    OUTPUT_FILE.write_text(
        json.dumps(results, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nSaved {len(results)} embeddings to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()