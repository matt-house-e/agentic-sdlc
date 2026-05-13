---
description: Create a GitHub issue following project conventions, with the right type / priority / component labels
accepts_args: true
argument-hint: <plain-english request>
---

Create a GitHub issue from the user's description in `$ARGUMENTS`, following this repo's conventions. If the repo has `docs/development/github-standards.md` or equivalent, defer to it for any discrepancy with the defaults below.

## Input

`$ARGUMENTS` is plain English about what the user wants — feature, bug, task, spike, etc. Use it to infer type, scope, priority, and component(s).

If the request is too vague to scope (no clear outcome, ambiguous between feature and bug, etc.), ask one specific clarifying question before creating. Don't guess on the parts that determine the label set.

---

## 1. Analyze the request

- What kind of work is this? (epic / story / task / bug / spike)
- Which component(s) does it affect?
- What's the scope and priority?
- What are the specific outcomes needed?

---

## 2. Determine issue type

Choose ONE:

- **Epic** — Multi-sprint (2+ weeks), multiple developers, major architectural change
- **Story** — User-facing feature, 1–5 days, delivers direct user value
- **Task** — Technical work, < 1 day, non-user-facing improvement
- **Bug** — Fix broken functionality, variable scope
- **Spike** — Time-boxed research (max 4 hours), reduces uncertainty

---

## 3. Determine component(s)

Pull the repo's actual component vocabulary:

```bash
gh label list --search "component:" --json name --jq '.[].name'
```

Use only labels that exist. Common ones across Python service repos:

- `component:workflow` — orchestration / agent flows
- `component:llm` — model integration, prompts
- `component:ui` — frontend
- `component:api` — public API endpoints
- `component:service` — business-logic services
- `component:data` / `component:database` — data models, migrations
- `component:testing` — test infrastructure
- `component:docs` — documentation
- `component:config` — configuration / environment
- `component:ci` / `component:ci-cd` — CI/CD workflows
- `component:infra` — infrastructure / deployment

If the relevant area doesn't have a matching label, mention this in the issue body and tag the closest match — don't invent a new label inside this command.

---

## 4. Craft the title

```
[Type]: [Component] Description
```

Max 60 characters. Examples:

- `[Story]: [UI] Add file upload capability`
- `[Bug]: [Workflow] Conversation node crashes on empty input`
- `[Task]: [Service] Refactor LLM service for better testing`
- `[Spike]: [API] Investigate JSM Cloud rate limits`

If this repo uses a different title convention (e.g. conventional-commits style, or no `[Component]` prefix), follow what `gh issue list --limit 20` shows. Match existing style.

---

## 5. Body template

```markdown
## Context
[Why this issue exists — business or technical context]

## Current Behavior
[What happens now — only if applicable, e.g. for bugs or improvements]

## Expected Behavior
[What should happen instead]

## Acceptance Criteria
- [ ] [Specific, measurable outcome 1]
- [ ] [Specific, measurable outcome 2]
- [ ] [Specific, measurable outcome 3]
- [ ] Tests pass (specify which: unit / integration / e2e)
- [ ] Documentation updated if user-facing or API change

## Technical Details
**Files Affected**: [List likely files]
**Dependencies**: [List any blocking issues if known]

## Definition of Done
- [ ] Code follows project conventions (see `CLAUDE.md`)
- [ ] Tests written and passing
- [ ] Lint + format passes
- [ ] PR opened with `Closes #<this-issue>`

## Notes
[Anything else from the user's input]
```

Skip sections that don't apply — don't pad with empty headers.

---

## 6. Labels

Apply at minimum:

- **One `type:*`** — epic / story / task / bug / spike
- **One `priority:*`** — critical / high / medium / low
- **One or more `component:*`** — from the repo's actual vocabulary (step 3)

Optional:

- `status:blocked` / `status:ready` — if the repo uses status labels

---

## 7. Create the issue

```bash
gh issue create \
  --title "<title>" \
  --label "type:X,priority:Y,component:Z" \
  --body "$(cat <<'EOF'
<full body>
EOF
)"
```

---

## 8. Confirm + suggest next step

After creation:

1. Print the issue number and URL
2. Show the title and the applied labels
3. Suggest: *"Ready to start? Run `/ship_issue <number>` to go end-to-end, or `/create_branch <number>` to just set up the worktree."*

---

## Guidelines

- **Be specific** — acceptance criteria should be measurable and testable
- **Be realistic** — match scope to issue type; don't turn a task into an epic
- **Be consistent** — follow existing title and label conventions (check `gh issue list`)
- **Be helpful** — infer reasonable details from context, but ask one focused question if critical info is missing
- **No fluff** — no marketing language, superlatives, or unnecessary praise

---

## When to ask before creating

- The request is genuinely ambiguous (could be a feature or a bug; could be one issue or three)
- Priority is load-bearing for the implementation order and not obvious from context
- The user's description sounds like an epic but they may want a story
- The component is unclear and the label vocabulary is large

One question at a time, lead with your best guess: *"Reading this as a `type:bug` on `component:service` — sound right?"*. Don't dump a list of clarifying questions on the user.
