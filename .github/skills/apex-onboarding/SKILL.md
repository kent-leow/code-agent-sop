---
name: apex-onboarding
description: Configure or update APEX (API Portal v2) for an agency licence onboarding card (MOLBLT "[APEX][STG/PROD]" cards, label apex-onboarding). Reads the card, picks the scenario, and produces a step-by-step APEX checklist (create API, subscribe, bridge, test, grant access, update). Use when asked to onboard/update APEX for an agency, set up an APEX API, bridge APEX zones, subscribe to an agency API, grant an agency access, or work a card like MOLBLT-7824.
metadata:
  category: operations
  tier: advanced
  status: active
  invocation: explicit
---

# APEX Onboarding

Card → concrete APEX task list. Guidance only: the user does portal clicks unless they say otherwise. Full guide: Confluence BIZSG "APEX: Onboarding(Text)" (id 2849867662; read via `jira-ticket` `get-page.sh`). Canonical: MOLB/L1T "APEX Portal Common guides".

## 1. Read the card

`bash .github/skills/jira-ticket/scripts/get-issue.sh --issue-key <KEY>` (IF fails → STOP with its error). Extract:

| Card field | Use |
|---|---|
| Environment | Staging / Production portal |
| APIs onboarding to / exposed to GoBiz | Gobiz → agency |
| APIs exposed by GoBiz | agency → Gobiz |
| Server Zone · APEX setup | agency on Internet/Intranet; own APEX + zone? |
| APEX API name(s) | agency API to subscribe to |
| Endpoints (name + URL) | paths + base URL for spec |
| Static HTTP headers | Overrides tab / OP interceptors |
| API authentication / properties | outbound auth |
| Agency APEX Org / App ID | grant access |
| Tech Notes steps 1-5 | status tracker; scenario guide link |

Missing/contradictory values (auth fields disagree, no licence ID) → **open items for the agency**; never guess.

## 2. Pick the scenario

Gobiz → agency:

| # | Scenario | When | Gobiz does |
|---|---|---|---|
| 1 | GobizInternet-GobizIntranet | agency intranet, no own APEX | Create API (Intranet), bridge to Internet, subscribe L1T |
| 2 | GobizInternet | agency internet, no own APEX | Create API (Internet), subscribe L1T |
| 3 | GobizInternet-AgencyIntranet | agency APEX on intranet | subscribe to agency API; Gobiz Internet API for the hop |
| 4 | AgencyInternet | agency APEX on internet | subscribe to agency API only |

Agency → Gobiz (LCP/SFA/LAR): publish Gobiz API in the agency's zone, grant access to the agency's APEX org in the **same zone**. Card's scenario guide link (Tech Notes) wins.

## 2b. Check current state (read-only, mandatory before proposing)

Every OP API row value (`apex_cloud_api_url_path`, base/path split, `interceptors` shape) must be validated against OP DB records fetched **this run**. Never derive from the card alone; never invent the `interceptors` format.

**Access** (`postgres-query` skill, db `op`, card's env; needs VPN — if DNS fails in sandbox, retry unsandboxed):
- **One PROD session, one statement** (PROD access alerts team Slack): no `check --connect`/`tables`/`describe` probes; run the combined SQL below; save to `<DOCS_DIR>/db-cache/op-prod-<licence id>.json`; work from that file.
- **Cache first**: reuse that file if <1 h old or from this session (say so); agency/sibling patterns reusable ≤7 days.
- **Refetch** only if state may have changed (user created/edited rows, verifying a fix/test call log, "recheck") — state why, refetch once.
- **DB unreadable** (denied, no VPN, missing creds) → write "Not proposed: OP state not fetched" + reason + the SQL for the user to run; emit **no JSON**; never fall back to a card-derived guess.

Columns (no `describe` needed): `onboarding_portal_licence(id, l1t_licence_id, name, agency_id, apex_cloud_licence_base_path)` · `onboarding_portal_agency(id, short_name, apex_cloud_base_url, apex_cloud_enabled)` · `onboarding_portal_api(id, licence_id, common_api_type, http_method, host_endpoint, is_apex_enabled, apex_cloud_api_url_path)` · `onboarding_portal_api_interceptors(api_id, interceptor_id)` · `onboarding_portal_interceptor(id, name, header_type, arguments, is_sensitive)` · `onboarding_portal_apicalllog(api_id, url, status_code, response_body, created_at, common_api_type)`.

Combined statement — `src`: `own` = licence's rows, `agency` = same agency's licences (path patterns, siblings), `ic` = their interceptors. Narrow `agency` with `l.l1t_licence_id >= <nearby id>` if large. New agency (no `agency`, empty `own`): the one extra allowed fetch is other agencies' rows of the same `common_api_type`, planned into the next single statement, never a loop.

```sql
with target as (
  select l.id, l.agency_id from onboarding_portal_licence l
  where l.l1t_licence_id = <licence id>   -- or: l.name ilike '%<licence name>%'
), rows_ as (
  select case when l.id = (select id from target) then 'own' else 'agency' end as src,
         a.short_name, a.apex_cloud_base_url, a.apex_cloud_enabled,
         l.l1t_licence_id, l.name, l.apex_cloud_licence_base_path,
         api.id as api_id, api.common_api_type, api.http_method,
         api.host_endpoint, api.is_apex_enabled, api.apex_cloud_api_url_path
  from onboarding_portal_licence l
  join onboarding_portal_agency a on a.id = l.agency_id
  left join onboarding_portal_api api on api.licence_id = l.id
  where l.agency_id = (select agency_id from target)
    and l.apex_cloud_licence_base_path is not null
)
select src, short_name, apex_cloud_base_url, apex_cloud_enabled, l1t_licence_id,
       name, apex_cloud_licence_base_path, common_api_type, http_method,
       host_endpoint, is_apex_enabled, apex_cloud_api_url_path,
       null::text as ic_name, null::text as ic_header_type, null::text as ic_arguments
from rows_
union all
select 'ic', r.short_name, null, null, r.l1t_licence_id, null, null, r.common_api_type,
       null, null, null, null, i.name, i.header_type,
       case when i.is_sensitive then '<redacted>' else i.arguments::text end
from rows_ r
join onboarding_portal_api_interceptors ai on ai.api_id = r.api_id
join onboarding_portal_interceptor i on i.id = ai.interceptor_id
order by 1, l1t_licence_id, common_api_type
limit 200
```

**Rules**
- OP stores the **APEX gateway** URL/path (`agency.apex_cloud_base_url`, `licence.apex_cloud_licence_base_path`), not the agency backend URL → never strip them from the card URL. Take `apex_cloud_api_url_path` from the licence's own rows' pattern (e.g. `/<licence id>/<action>`), else siblings'; check the card's backend path fits. No pattern → Unvalidated, excluded from JSON.
- Interceptors: reuse an existing one by name when its header matches the card; propose new only if none, copying `header_type`/`arguments` shape from a fetched row. Print `arguments` only when `is_sensitive = false`; never print card secrets.
- No licence row → licence must be created first (look up by name; "Licence ID: Not provided" ≠ absent). Zero API rows → all endpoints Required.
- Each proposed row cites evidence (db · env · query · excerpt); unsupported value → "Unvalidated", excluded from JSON.
- Card has no value for a check → skip and say so. APEX portal state (subscription, grants) can't be read here → user-verified items.

Compare to card → Required / Done / Mismatch:

| Item | Expected | OP column |
|---|---|---|
| Agency APEX gateway URL | exists, enabled (not card backend URL) | `agency.apex_cloud_base_url`, `apex_cloud_enabled = t` |
| Licence base path | exists (gateway path) | `licence.apex_cloud_licence_base_path` |
| API row per card endpoint | exists, path fits pattern | `api.apex_cloud_api_url_path`, `is_apex_enabled = t` |
| Static header interceptors | linked where needed | `api_interceptors` → `interceptor` |

Card endpoint → `common_api_type` (verified on PROD; unlisted → query distinct values, never guess):

| Card | Type |
|---|---|
| CreateApplication | `CREATE_APPLICATION` |
| Validate / Validation | `VALIDATION` |
| StatusUpdate | `STATUS_UPDATE` (`STATUS_POLL` separate) |
| Pre-populate | `PRE_POPULATE` |
| CalculateFee | `CALCULATE_FEE` |
| Payment | `PAYMENT` |
| Withdraw / WithdrawApplication | `WITHDRAW` |
| Clarification | `CREATE_APPLICATION_RFA` |

Required rows → JSON array (only after a successful fetch), one object per endpoint: `l1t_licence_id`, `interceptors` (names; `[]` unless static headers), `common_api_type`, `http_method` = `POST`, `host_endpoint` = `APEX`, `is_apex_enabled` = `true`, `apex_cloud_api_url_path` (leading `/`).

## 3. Steps per task

**A. Create API (1, 2)** — portal banner "You are currently on" = right env + zone → Publish > Manage APIs > Create API > REST → name `molb-l1t-<agency>-<optional-ref>`, version `1.0.0` → OpenAPI 3.0.2 from generic template: one `servers[0].url` = agency common base URL (different domain = separate API); `paths` = non-common remainder per card endpoint, kebab-case, unused samples removed → Load, Lint (warnings OK), Backend base URL, submit → Draft with REST + JWT badges.

**B. Subscribe (L1T)** — API > Subscriptions > `l1t` > Subscribe (or from the application page); per API.

**C. Bridge (1)** — API > Relevant actions > Bridge to other zone → `[Bridge] <name>`, same spec → subscribe to L1T in that zone; direction per guide.

**D. Test** — Postman with L1T API key + JWT → APEX Monitoring (Kibana) by correlation ID, inbound + outbound logs. A backend error still proves routing. Failures → `investigate-apex` skill.

**E. Subscribe to agency API (3, 4)** — agency must publish + grant Gobiz org first → Consume > Approved APIs > find by name > Subscriptions > `l1t` > Subscribe, every API. Empty list = access not granted.

**F. Grant agency access (agency → Gobiz)** — needs agency APEX Org ID/name; grant at org level, **matching zone only** (cross-zone breaks, MOLBLT-5541); confirm via View application / View by Applications.

**G. Update existing API** — spec immutable: Clone → change → subscribe → update URL in Onboarding Portal → delete old. Backend URL only: edit in place, no downtime. Live API: Edit creates draft copy; spec change = new API, downtime, re-grant. Confirm with PM before Onboarding Portal refresh.

**H. Certificates** — auto-fetched at creation; backend URL change → install manually (Manage trusted certs). Ask agency for ROOT cert (leaf ~1 yr). HTTP 526 = install root. Published API: use Edit to upload.

**Limits**: no path forwarding (list every endpoint) · static headers only (no dynamic/timestamp) · Draft works for own org; Published needed to share.

## 4. Output

`<DOCS_DIR>/apex-checklist.md` (docs-folder skill, `.docs/<JIRA-KEY>-<kebab-title>/`; overwrite on re-run). Chat: path + 3-line summary of Required items.

1. Scenario + why (one line)
2. Current state table (2b), Required / Done / Mismatch + evidence
3. OP API rows `json` block with per-row evidence — or "Not proposed: OP state not fetched" + SQL, no JSON
4. Checklist mapped to Tech Notes steps, exact card values, `- [ ]` only for Required
5. Open items for the agency
6. Test evidence to attach (correlation ID, inbound/outbound log)

No writes to Jira/Confluence unless asked. No agency-specific values in this skill.
