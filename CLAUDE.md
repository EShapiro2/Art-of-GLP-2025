# Instructions for Claude Code - Art of GLP Book

## Project Overview
- **Project**: "The Art of Grassroots Logic Programming" - a book based on GLP
- **Format**: LaTeX using memoir document class
- **Main file**: `main.tex` (self-contained, compiles on Overleaf)
- **Synced with**: Overleaf

## Book Structure

**Two Parts:**
- **Part I: Concurrent GLP** - single-agent concurrent logic programming (CURRENT FOCUS)
- **Part II: Multiagent GLP** - distributed systems, security, grassroots protocols (LATER)

**Two Tracks:**
- **Informal track**: Intuitive explanations, examples, programming techniques
- **Formal track**: Rigorous definitions and proofs in shaded `\begin{formal}...\end{formal}` boxes

## Source Material

The book transforms the GLP-2025 paper into textbook form:
- **Paper sections**: `glp_section_*.tex` - source material for chapters
- **Paper appendices**: `glp_appendix_*.tex` - source for formal content

## Git Collaboration Protocol

1. **Main branch** (`main`) is synced with Overleaf
2. **Claude works on**: `claude/...-<session-id>` branches
3. **Permissions**:
   - Claude can only push to `claude/...` branches
   - User merges into `main` for Overleaf sync

## Syncing with Overleaf - Step by Step

### Initial Setup (one time)

1. **Link Overleaf to GitHub:**
   - In Overleaf: New Project → Import from GitHub
   - Select `EShapiro2/Art-of-GLP-2025`
   - Overleaf syncs with `main` branch

2. **Clone repo locally (if not already done):**
   ```bash
   git clone git@github.com:EShapiro2/Art-of-GLP-2025.git ~/Art-of-GLP-2025
   ```

3. **Use SSH (avoids password issues):**
   ```bash
   cd ~/Art-of-GLP-2025
   git remote set-url origin git@github.com:EShapiro2/Art-of-GLP-2025.git
   ```

### After Claude Code Makes Changes

Claude pushes to `claude/<branch-name>`. To get changes into Overleaf:

```bash
cd ~/Art-of-GLP-2025
git fetch origin claude/<branch-name>
git merge -m "Merge claude branch" origin/claude/<branch-name>
git push origin main
```

Then in Overleaf: Menu → GitHub → Pull

### After Editing in Overleaf

Push from Overleaf to GitHub (Menu → GitHub → Push), then:

```bash
cd ~/Art-of-GLP-2025
git pull origin main
```

## Working Rules

### Communication Style
- **BE TERSE** - Brief, direct responses
- **NO LONG EXPLANATIONS** - Get to the point
- **NEVER BS, GUESS, OR SPECULATE** - If unsure, say so
- **REVIEW CLAUDE WEB INSTRUCTIONS** - When receiving instructions from Claude Web, review them first and let Udi know if you have any comments, questions, or issues before executing

### Content Rules
- **NEVER REMOVE CONTENT** without explicit user approval
- **Preserve paper content** - transform, don't delete
- **Formal boxes** contain rigorous material from paper
- **Informal text** expands and explains for book readers

### LaTeX Rules
- **main.tex** must be self-contained (no external \input for directories that might not sync)
- **Test compilation** on Overleaf before considering done
- **Keep packages minimal** for Overleaf compatibility

### After Context Compaction
When a conversation is compacted and continued:
- **READ CLAUDE.md AGAIN** - Always re-read this file at the start of a continued session
- **DO NOT WORK FROM SUMMARIES** - If you had detailed instructions before compaction, STOP and ask the user to provide them again. Summaries lose critical details. You cannot execute instructions you only have a summary of.

### After Completing Changes
When you commit and push changes to a `claude/...` branch, provide the user with merge instructions:
```bash
git fetch origin claude/<branch-name>
git merge -m "Merge claude branch" origin/claude/<branch-name>
git push origin main
```

## Key Concepts to Understand

- **SRSW**: Single-Reader/Single-Writer - core GLP discipline
- **Reader/Writer pairs**: Communication channels between concurrent processes
- **Committed choice**: No backtracking, first applicable clause
- **Streams**: Incrementally constructed lists - fundamental GLP data structure
- **Plays**: Technique for simulating multiagent systems in single-agent GLP [TO BE DOCUMENTED]

## Reference Repositories

- **GLP-2025 Paper**: https://github.com/EShapiro2/GLP-2025
- **FCP Reference**: https://github.com/EShapiro2/FCP (Flat Concurrent Prolog)
- **GLP Runtime & Examples**: https://github.com/EShapiro2/GLP (includes AofGLP/)

## GLP Repo Workflow

Claude works on `claude/...` branches. To merge into main:

```bash
cd ~/GLP
git checkout main
git pull origin main
git fetch origin claude/<branch-name>
git merge -m "Merge claude/<branch-name> into main" origin/claude/<branch-name>
git push origin main
```
