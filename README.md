# development-risk-scanner
// for demo checking
# Deployment Risk Scanner — "Bob 2.0" Prototype (v2)

A working prototype of the Pre-Deployment Risk Scanner described in the chat: one
"Deployment Manager" agent that dispatches five subagents in parallel, each checking one
risk area, then rolls the results into a single go/no-go verdict.

**v2 adds three capabilities requested after the first build**, aimed at the gaps
called out as differentiators (orchestration depth, remediation, evidence quality):

1. **Automatic remediation + verification loop** — every failed subagent now shows a
   "Suggested remediation" and an **"Apply suggested fix & re-scan"** button.
2. **Risk → Fix → Re-scan → Approval workflow** — applying a fix automatically re-runs
   all five subagents; once every one passes, an **Approval** panel unlocks so you can
   record who approved the release and download a signed-looking certificate.
3. **Deeper orchestration layer + evidence from real files** — a "Main Agent" status
   card and a live **Orchestration Log** show what was dispatched and when; every
   panel now accepts a real **file upload**, and findings cite the actual filename as
   evidence instead of just "pasted text."

Nothing about the original five checks, the demo scenario, or the report format was
changed — this is additive.

It's a single self-contained web page — **no install, no server, no internet connection
needed.** Everything runs in your browser with JavaScript; nothing you type is sent
anywhere.

---

## 1. How to open it

1. Unzip the folder.
2. Double-click **`index.html`** (or right-click → Open with → your browser).
3. That's it — the app loads immediately.

Folder contents:

```
deployment-risk-scanner/
├── index.html          ← the app itself, open this
├── README.md            ← this file
└── samples/              ← example input files matching the chat's demo scenario
    ├── migration_sample.sql
    ├── api_old.json
    ├── api_new.json
    ├── dependencies_sample.txt
    ├── env_sample.txt
    ├── service_payment.json
    └── service_order.json
```

---

## 2. The fastest way to see it work

Click **"Load demo scenario"** at the top of the page. This fills in all five panels
with the exact failing example from the chat (dropped `user_email` column, `/login`
response field renamed, `bcrypt`/`auth-lib` conflict, missing `JWT_SECRET`, currency
mismatch between `payment-service` and `order-service`). Then click **"▶ Run all
checks"** and watch all five subagents light up and report failures, ending in a
**DEPLOYMENT BLOCKED** verdict — reproducing the walkthrough from the original chat.

Click **"Clear all"** afterwards to start with empty panels for your own project.

---

## 3. The five subagents, in detail

Each subagent is an independent function. They all run **in parallel** (via
`Promise.all` in the code) when you press "Run all checks," not one after another —
that's what the brief means by "parallel tasks."

### 🗄️ 1. Database Migration Safety Checker
**What it needs:** paste the contents of your migration script (SQL) into the
"Migration script" box.
**What it looks for, line by line:**
- `DROP COLUMN` — flags it, since old code may still read that column.
- `DROP TABLE` — flags it as irreversible and likely to break foreign keys/queries.
- `RENAME COLUMN` — flags it, since old code referencing the previous name breaks.
- `ADD COLUMN ... NOT NULL` with no `DEFAULT` — flags it, since it will fail against
  existing rows that don't have a value.
- `ALTER COLUMN ... NOT NULL` with no `DEFAULT` — same reasoning, for existing NULLs.
**Output:** one line per risky statement, with the line number, e.g. *"Line 3: DROP
COLUMN user_email — breaks any code still reading this column."*

### 🌐 2. API Breaking-Change Detector
**What it needs:** two small JSON documents — your **old** and **new** API contract —
in the format:
```json
{
  "/endpoint-path": {
    "method": "POST",
    "request": ["field1", "field2"],
    "response": ["field3"]
  }
}
```
You can describe as many endpoints as you like in the same object.
**What it looks for:**
- An endpoint that existed in the old contract but is missing from the new one
  (removed endpoint).
- A field that was in the old `response` array but isn't in the new one (removed
  response field — the classic "client expects `token`, server now sends
  `session_id`" case from the brief).
- A field that appears in the new `request` array but wasn't in the old one (a newly
  *required* input that old clients never sent).
**Output:** one line per breaking change, naming the endpoint and the field.

### 📦 3. Dependency Conflict Scanner
**What it needs:** paste your dependency manifest — either `package.json`-style
(`"name": "version"`) or `requirements.txt`-style (`name==version`), one package per
line, into the box.
**What it looks for:**
- The specific conflict from the brief: `bcrypt` pinned to a 3.x version alongside
  `auth-lib`, which only supports bcrypt 2.x.
- A generic check: the same package name listed twice in the file with two different
  version pins (a common sign of a merged/duplicated dependency block).
**Output:** one line per conflict found, naming both packages and their versions.
**Note:** this is a small demo rule set (matching the brief's example), not a full
package-registry resolver — see "Extending it" below to add your own real rules.

### ⚙️ 4. Environment Configuration Validator
**What it needs:** two things —
1. the contents of your `.env` file (`KEY=value`, one per line) in the left box, and
2. a comma-separated list of variable names the service actually requires, in the
   right box (e.g. `DB_URL, JWT_SECRET, REDIS_URL`).
**What it looks for:** any required key that is either completely absent from the
`.env` contents, or present but set to an empty value.
**Output:** one line per missing/empty variable, e.g. *"Missing environment variable:
JWT_SECRET."*

### 🔗 5. Cross-Service Contract Checker
**What it needs:** two JSON config snippets, one per service, each with a `"service"`
name field plus whatever shared settings you want compared (currency, API version,
timeout, etc.), e.g.:
```json
{"service": "payment-service", "currency": "INR", "apiVersion": "v2"}
{"service": "order-service",  "currency": "USD", "apiVersion": "v2"}
```
**What it looks for:** any key that exists in *both* configs but has a different
value — that's the mismatch the brief describes (`payment-service` expects INR,
`order-service` expects USD).
**Output:** one line per mismatched key, showing both services' values side by side.
**Note:** the prototype compares exactly two services at a time; see "Extending it"
below to compare more.

---

## 4. Reading the results

- **Control room strip** (top): a status light per subagent — grey = idle, blue
  pulsing = running, green = passed, red = failed.
- **Verdict bar**: the overall call —
  - **DEPLOYMENT BLOCKED** (red) if *any* subagent found an issue.
  - **CLEAR TO DEPLOY** (green) if all five passed.
- **Final Deployment Risk Report**: every subagent's full findings, in plain language,
  matching the "Deployment Risk Report" text block from the original chat.
- **Download report (.txt)**: once a scan finishes, this button saves the same report
  as a plain-text file you can attach to a ticket or paste into Slack.
- **Manual vs. Bob 2.0 table**: the illustrative time-savings comparison from the
  brief (30 min → instant, etc.) — shown for context, not measured from your actual
  input.

## 5. Using the sample files

The `samples/` folder holds the same demo scenario as the "Load demo scenario"
button, split into individual files, in case you want to see what realistic input
files look like or swap in your own project's files one at a time:

| File | Goes in |
|---|---|
| `migration_sample.sql` | Migration script box |
| `api_old.json` / `api_new.json` | Old / New API contract boxes |
| `dependencies_sample.txt` | Dependency file box |
| `env_sample.txt` | `.env` file contents box |
| `service_payment.json` / `service_order.json` | Service A / Service B config boxes |

Just open a sample file in any text editor, copy its contents, and paste into the
matching box (or paste your own project's real files in the same shape).

## 6. Extending it (optional, for developers)

This is a rule-based prototype, not a connection to a real CI/CD pipeline or a
language model. To make it check *your* real risk rules:

- Open `index.html` in a code editor and find the matching function in the
  `<script>` section: `checkMigration()`, `checkApi()`, `checkDeps()`, `checkEnv()`,
  `checkServices()`.
- Each function takes plain text/JSON and returns an array of finding strings — add
  your own `if` conditions (e.g. more known-conflicting package pairs in
  `KNOWN_CONFLICTS`) following the existing pattern.
- To wire it to a real deployment pipeline instead of manual paste-in, these five
  functions are the pieces you'd call from a CI step, feeding them the actual
  migration diff, OpenAPI spec diff, lockfile, `.env`, and service configs pulled
  from your repo/CD system.

## 7. New in v2: the full workflow

### Main Agent / orchestration layer
At the top of the page, a **"Main Agent — Deployment Manager"** card shows the
orchestrator's own status in plain language ("Dispatching 5 subagents in
parallel…", "Aggregating subagent results…", "Blocked, waiting on remediation…",
"Approved, release-ready"). Below the five subagent lights, the **Orchestration
Log** panel timestamps every step: dispatch, each subagent's completion time and
verdict, the aggregated verdict, any remediation applied, and the final approval —
a readable evidence trail of exactly what the orchestrator did and when, not just
the final report.

### Uploading real project files (evidence)
Next to each input box is a **📎 Upload** button. Pick the real file from your
project (the actual migration `.sql`, `package.json`, `.env`, service config, etc.)
and its contents load into the box automatically. The tag under the box switches
from *"Source: pasted text"* to *"Source: your-file-name.sql (uploaded)"*, and that
filename now appears next to each finding in the report and in the downloaded
report/certificate — so a reader can see exactly which file each risk came from,
not just a generic description.

### Suggested fixes
Every failing subagent now shows what it would change and why, for example:
- **Migration:** removes the unsafe `DROP COLUMN`/`DROP TABLE`/rename statement and
  leaves a comment describing the safe phased alternative; adds a placeholder
  `DEFAULT` where a `NOT NULL` column has none.
- **API:** merges the old response field back into the new contract so existing
  clients keep working.
- **Dependencies:** re-pins the conflicting package to the version the other
  library actually supports (e.g. `bcrypt` back to `2.4.0` for `auth-lib` v2.x).
- **Environment:** appends a `CHANGE_ME` placeholder for any missing/empty required
  variable.
- **Cross-service:** syncs the mismatched value on Service B to match Service A.

These are heuristic, pattern-matched fixes for a prototype — good for showing the
workflow end-to-end, not a substitute for a real code review.

### Apply fix & re-scan
Click **"Apply suggested fix & re-scan"** on any failing subagent's card. The tool:
1. Rewrites that subagent's input box(es) with the fix.
2. Logs the change in the Orchestration Log.
3. Automatically re-runs **all five** subagents (iteration counter goes up).
4. Updates the verdict bar and every subagent's status.

Repeat for each failing subagent until the verdict reads **CLEAR TO DEPLOY**.

### Approval
Once every subagent passes, the **"Risk → Fix → Re-scan → Approval"** panel
unlocks. Optionally type an approver name, click **"Approve release,"** then
**"Download approval certificate (.txt)"** for a file containing the approver,
timestamp, number of scan iterations it took to get clean, the full orchestration
log, and the final report — a self-contained record of the whole workflow.

## 8. Limits of this prototype

- It's heuristic/pattern-based, not an actual language model reading your code — it
  catches the specific risk patterns described in the brief, not every possible
  deployment issue.
- Everything runs client-side in memory; nothing is saved, so refreshing the page
  clears all input (use the download button to keep a copy of a report).
- The Cross-Service Contract Checker compares exactly two services per run.
