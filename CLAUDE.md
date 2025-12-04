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
4. **To merge Claude's work into main** (user runs):
   ```bash
   git fetch origin
   git checkout main
   git merge origin/claude/<branch-name>
   git push origin main
   ```

## Working Rules

### Communication Style
- **BE TERSE** - Brief, direct responses
- **NO LONG EXPLANATIONS** - Get to the point
- **NEVER BS, GUESS, OR SPECULATE** - If unsure, say so

### Content Rules
- **NEVER REMOVE CONTENT** without explicit user approval
- **Preserve paper content** - transform, don't delete
- **Formal boxes** contain rigorous material from paper
- **Informal text** expands and explains for book readers

### LaTeX Rules
- **main.tex** must be self-contained (no external \input for directories that might not sync)
- **Test compilation** on Overleaf before considering done
- **Keep packages minimal** for Overleaf compatibility

## Key Concepts to Understand

- **SRSW**: Single-Reader/Single-Writer - core GLP discipline
- **Reader/Writer pairs**: Communication channels between concurrent processes
- **Committed choice**: No backtracking, first applicable clause
- **Streams**: Incrementally constructed lists - fundamental GLP data structure
- **Plays**: Technique for simulating multiagent systems in single-agent GLP [TO BE DOCUMENTED]

## Reference Repositories

- **GLP-2025 Paper**: https://github.com/EShapiro2/GLP-2025
- **FCP Reference**: https://github.com/EShapiro2/FCP (Flat Concurrent Prolog)
