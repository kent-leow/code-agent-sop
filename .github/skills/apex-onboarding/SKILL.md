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

Turns an onboarding card into a concrete APEX task list. Guidance only: portal clicks are done by the user unless they say otherwise.

Full guide (tables, screenshots context): Confluence BIZSG page "APEX: Onboarding(Text)" (id 2849867662). Canonical guides: MOLB/L1T space, "APEX Portal Common guides".

## 1. Read the card

Fetch the Jira card (`jira-ticket` skill; needs JIRA_EMAIL, JIRA_TOKEN, JIRA_BASE_URL). Extract:

| Card field | Use |
|---|---|
| Environment | Staging or Production portal |
| APIs onboarding to / exposed to GoBiz | Gobiz calls agency |
| APIs exposed by GoBiz | Agency calls Gobiz |
| Server Zone | Agency system on Internet or Intranet |
| APEX setup | Agency has own APEX? which zone? |
| APEX API name(s) | Agency API to subscribe to |
| Endpoints (name + URL) | Paths and base URL for the spec |
| Static HTTP headers | Overrides tab / OP interceptors |
| API authentication / properties | Outbound auth setting |
| Agency APEX Org / App ID | Needed to grant access |
| Tech Notes steps 1-5 | Status tracker; link of the scenario guide |

List anything missing or contradictory (e.g. auth fields that disagree, no licence ID) as **open items for the agency**. Do not guess them.

## 2. Pick the scenario

Gobiz calls agency:

| # | Scenario | When | Gobiz does |
|---|---|---|---|
| 1 | GobizInternet-GobizIntranet | Agency on intranet, no own APEX | Create API (Intranet), bridge to Internet, subscribe L1T |
| 2 | GobizInternet | Agency on internet, no own APEX | Create API (Internet), subscribe L1T |
| 3 | GobizInternet-AgencyIntranet | Agency has APEX on intranet | Subscribe to agency API; create Gobiz Internet API for the hop |
| 4 | AgencyInternet | Agency has APEX on internet | Subscribe to agency API only |

Agency calls Gobiz (LCP/SFA/LAR): publish Gobiz API in the agency's zone, then grant access to the agency's APEX organisation in the **same zone**.

If the card lists a scenario guide link in Tech Notes, use it.

## 2b. Check current state (read-only)

**Mandatory: fetch and validate before proposing.** Every value in the OP API rows JSON (`apex_cloud_api_url_path`, base URL / licence base path split, `interceptors` shape) must come from, or be validated against, records fetched from the OP DB in this run. Never derive the base/path split from the card alone, and never invent the `interceptors` format.

- Fetch order: (1) the licence by `l1t_licence_id`, else by name; (2) its agency row; (3) the agency's other licences' API rows, and, when the licence has no rows of its own, the same `common_api_type` rows of sibling licences, to learn the split and the `interceptors` JSON shape actually stored.
- If the DB cannot be read (access denied, no VPN, missing credentials): STOP the JSON section. Write "Not proposed: OP state not fetched" with the reason, list the exact query for the user to run, and do not emit any JSON. Never fall back to a card-derived guess.
- Each proposed row carries evidence: the fetched record(s) it was validated against (db · env · query · result excerpt). A value with no supporting record is marked "Unvalidated" and left out of the JSON.
- OP stores the **APEX gateway** URL/path (`agency.apex_cloud_base_url`, `licence.apex_cloud_licence_base_path`), not the agency backend URL on the card, so never derive `apex_cloud_api_url_path` by stripping the stored values from the card URL. Take it from the licence's existing API rows (same naming pattern, e.g. `/<licence id>/<action>`), else from sibling licences of the same agency, and check the card's backend path is consistent with that pattern. No pattern found: mark Unvalidated and leave it out of the JSON.
- Interceptors are not a column on the API row: they live in `onboarding_portal_api_interceptors` (`api_id`, `interceptor_id`) → `onboarding_portal_interceptor` (`name`, `header_type`, `arguments`, `is_sensitive`). Fetch them for the licence's rows and reuse an existing interceptor by name when its header matches the card; propose a new one only if none exists, copying `header_type` / `arguments` shape from a fetched row. Print `arguments` only when `is_sensitive` is false (they hold `${ENV_VAR}` placeholders); never print card secret values.

Find what is already configured so the checklist lists only what is required. Skip a check if the card gives no value for it, and say so.

**Onboarding Portal DB** (`postgres-query` skill, db `op`, same env as the card; PROD is read-only; needs VPN, and the sandbox may block DNS, so retry unsandboxed if the host does not resolve):

```sql
select a.short_name, a.apex_cloud_base_url, a.apex_cloud_enabled,
       l.name, l.l1t_licence_id, l.apex_cloud_licence_base_path,
       api.common_api_type, api.http_method, api.is_apex_enabled,
       api.host_endpoint, api.apex_cloud_api_url_path
from onboarding_portal_licence l
join onboarding_portal_agency a on a.id = l.agency_id
left join onboarding_portal_api api on api.licence_id = l.id
where l.l1t_licence_id = <licence id>   -- or: l.name ilike '%<licence name>%'
order by api.common_api_type limit 50
```

Interceptors of those rows (then sibling-licence rows of the same agency, and `common_api_type` rows of other agencies, if the licence has none):

```sql
select api.common_api_type, i.name, i.header_type, i.is_sensitive,
       case when i.is_sensitive then '<redacted>' else i.arguments end as arguments
from onboarding_portal_licence l
join onboarding_portal_api api on api.licence_id = l.id
join onboarding_portal_api_interceptors ai on ai.api_id = api.id
join onboarding_portal_interceptor i on i.id = ai.interceptor_id
where l.l1t_licence_id = <licence id> limit 50
```

Agency-wide view (licence path + api path patterns): same first query with `where a.short_name = '<agency>'`, `limit 100`.

Compare to the card and mark each row Required / Done / Mismatch:

| Item | Expected from card | OP column |
|---|---|---|
| Agency APEX gateway URL | exists and enabled (not the card's backend URL) | `agency.apex_cloud_base_url`, `apex_cloud_enabled = t` |
| Licence base path | exists (gateway path) | `licence.apex_cloud_licence_base_path` |
| One API row per card endpoint | row exists, path matches the licence's pattern | `api.apex_cloud_api_url_path`, `is_apex_enabled = t` |
| Static header interceptors | linked to each row that needs them | `api_interceptors` → `interceptor` |

- No licence row: the licence must be created first. Do not assume the card's "Licence ID: Not provided" means it is absent; look it up by name.
- Zero API rows: all endpoints are Required.
- Map card endpoint names to OP `common_api_type` (verified against PROD rows). Unlisted names: query distinct `common_api_type` first, never guess.

| Card endpoint | `common_api_type` |
|---|---|
| CreateApplication | `CREATE_APPLICATION` |
| Validate / Validation | `VALIDATION` |
| StatusUpdate | `STATUS_UPDATE` (`STATUS_POLL` is a separate type) |
| Pre-populate | `PRE_POPULATE` |
| CalculateFee | `CALCULATE_FEE` |
| Payment | `PAYMENT` |
| Withdraw / WithdrawApplication | `WITHDRAW` |
| Clarification | `CREATE_APPLICATION_RFA` |

- Every row uses `http_method = POST`, `host_endpoint = APEX`, `is_apex_enabled = true`, `interceptors = []` unless the card has static headers (then names of existing interceptors per the rule above; secret values are never copied). `apex_cloud_api_url_path` per the pattern rule above, with a leading `/`.
- Emit the Required rows as a JSON array, one object per endpoint, only after the fetch above succeeded: `l1t_licence_id`, `interceptors` (list of interceptor names), `common_api_type`, `http_method`, `host_endpoint`, `is_apex_enabled`, `apex_cloud_api_url_path`.
- APEX portal state (subscription, access grant) cannot be read from here; keep those as user-verified items.

## 3. Steps per task

### A. Create API (scenarios 1, 2)
1. Open the right portal (check the "You are currently on" banner: env + zone).
2. Publish > Manage APIs > Create API > REST.
3. Name `molb-l1t-<agency>-<optional-ref>`; version `1.0.0`; summary short.
4. Build the OpenAPI 3.0.2 spec from the generic template: one `servers[0].url` = agency common base URL; `paths` = only the non-common remainder, one per card endpoint; kebab-case paths; remove unused sample paths. Only one server per API; different domain = separate API.
5. Load from file, Lint (warnings OK), set Backend base URL, submit.
6. Confirm API shows as Draft with REST + JWT badges.

### B. Subscribe to application (L1T)
API > Subscriptions > select application `l1t` > Subscribe. Or from the application page. Repeat per API.

### C. Bridge (scenario 1)
Created API > Relevant actions > Bridge to the other zone. Creates `[Bridge] <name>` with same spec. Subscribe it to L1T in that zone. Follow the guide for direction.

### D. Test
Postman call with L1T API key + JWT. Then APEX Monitoring Tool (Kibana): filter by correlation ID; check inbound and outbound logs. A backend error still proves routing.

### E. Subscribe to agency API (scenarios 3, 4)
Agency must publish and grant access to Gobiz org first. Consume > Approved APIs > find by API name > Subscriptions > `l1t` > Subscribe, for every API. Empty list = access not granted.

### F. Grant agency access (agency calls Gobiz)
Needs agency APEX Org ID/name. Grant at organisation level, matching zone only (cross-zone grants cause connectivity issues, MOLBLT-5541). Confirm via View application / View by Applications.

### G. Update existing API
- Spec is immutable: Clone, change, subscribe, update URL in Onboarding Portal, delete old.
- Backend URL only: editable in place, no downtime.
- Live API: Edit creates a draft copy. Spec change = new API, downtime, re-grant access.
- Confirm with PM before triggering refresh in Onboarding Portal.

### H. Certificates
- Auto-fetched at creation. If backend URL changes later, install manually (Manage trusted certs).
- Ask agency for the ROOT cert (leaf ~1 yr). HTTP 526 = install root.
- Cannot upload to a published API; use Edit.

## 4. Limits to remember
- No path forwarding; list every endpoint.
- Static headers only; dynamic (timestamp) headers unsupported.
- Draft API works for own org; Published needed to share with other orgs.

## 5. Output

Write the result to a file and tell the user its path. Resolve the folder with the `docs-folder` skill (`.docs/<JIRA-KEY>-<kebab-title>/`), file name `apex-checklist.md`. Overwrite on re-run. Chat reply: path + 3-line summary of what is Required.

File contents, minimal:
1. Scenario + why (one line).
2. Current state: table of the 2b checks, each Required / Done / Mismatch, with the evidence (db · env · query · result excerpt).
3. OP API rows JSON (from 2b) in a fenced `json` block, each row with its DB evidence. If 2b was not fetched, write "Not proposed: OP state not fetched" plus the query to run, and no JSON.
4. Checklist mapped to the card's Tech Notes steps, each with the exact values from the card (API name, base URL, paths) and `- [ ]` boxes only for Required items.
5. Open items for the agency.
6. Test evidence to attach (correlation ID, inbound/outbound log).

Do not write to Jira or Confluence unless asked. Do not put agency-specific values into this skill.
