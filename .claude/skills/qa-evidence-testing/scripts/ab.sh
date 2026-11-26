# qa-evidence-testing helpers — SOURCE me:  . ab.sh
# Env: QA_ART (artifact dir, required before ac_begin), DASHBOARD_URL (default GoBiz dev dashboard).
# Requires: nvm Node 24, ~/.agent-browser/tools (agent-browser + ffmpeg) — see install.sh.

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null && nvm use 24 >/dev/null
# ffmpeg MUST be on PATH before the agent-browser daemon starts, or `record start` fails.
export PATH="$HOME/.agent-browser/tools/bin:$HOME/.agent-browser/tools/node_modules/.bin:$PATH"
export DASHBOARD_URL="${DASHBOARD_URL:-https://dashboard.dev.gobusiness.io}"

ab()   { agent-browser "$@" --auto-connect; }
idle() { ab wait --load networkidle >/dev/null 2>&1; }
die()  { echo "ERROR: $*" >&2; return 1; }

# First interactive ref whose snapshot line contains the literal text $1 (e.g. 'button "Log Out"').
ref() { ab snapshot -i 2>/dev/null | grep -F -- "$1" | head -1 | sed -nE 's/.*ref=(e[0-9]+).*/@\1/p'; }
# Last matching ref (confirm buttons in modals usually come after the menu item with the same name).
ref_last() { ab snapshot -i 2>/dev/null | grep -F -- "$1" | tail -1 | sed -nE 's/.*ref=(e[0-9]+).*/@\1/p'; }
# Click by snapshot text; fails loudly when the element is missing (no silent false passes).
click_text() { local r; r=$(ref "$1"); [ -n "$r" ] || { die "element not found: $1"; return 1; }; ab click "$r" >/dev/null; }

# Read helpers (eval = READ only).
text()   { ab eval "document.body.innerText.replace(/\\n+/g,' | ').slice(0,${1:-600})"; }
field()  { ab eval "document.body.innerText.match(/$1\\n([^\\n]+)/)?.[1] ?? null"; }   # value under a label
header() { ab eval "document.body.innerText.match(/Dashboard\\n([^\\n]+)\\n([A-Z0-9]+)\\n/)?.slice(1).join(' / ') ?? null"; }

shot() { [ -n "${QA_ART:-}" ] || { die "QA_ART not set"; return 1; }; mkdir -p "$QA_ART"
         ab screenshot "$QA_ART/$1.png" ${2:-} >/dev/null && echo "shot $1.png"; }

# Evidence id = AC<n>-<BEFORE|AFTER>[-<scenario>]  (e.g. AC2-AFTER, AC2-AFTER-invalid-uen, REG-login-BEFORE)
# step AC2-AFTER 1 dashboard "<observed value>" [--full]  → AC2-AFTER-step1-dashboard.png + log line
step() { local id=$1 n=$2 what=$3 obs=$4; shift 4
         echo "$id step$n $what: $obs"; shot "$id-step$n-$what" "$@"
         echo "$(date -u +%FT%TZ)	$id	step$n	$what	$obs" >> "$QA_ART/steps.tsv"; }

# ac_begin AC2-AFTER rename-new-name  → AC2-AFTER.start (UTC) + starts AC2-AFTER-rename-new-name.mp4
ac_begin() { [ -n "${QA_ART:-}" ] || { die "QA_ART not set"; return 1; }; mkdir -p "$QA_ART"
             date -u +%Y-%m-%dT%H:%M:%SZ > "$QA_ART/$1.start"
             ab record start "$QA_ART/$1-$2.mp4" --cursor 2>&1 | tail -1; }
ac_end()   { ab record stop 2>&1 | tail -1; date -u +%Y-%m-%dT%H:%M:%SZ > "$QA_ART/$1.end"; }

# ---- GoBiz dashboard (dev) specifics -------------------------------------------------------
# Mockpass is gated by an Agency Portal session: Government Email → System Admin.
ensure_logged_out() {
  ab open "$DASHBOARD_URL/" >/dev/null; idle
  case "$(ab get url)" in */login*) echo "logged-out";; *) logout_ui;; esac
}

login_cp() { # $1 = mockpass Corppass dropdown label text (e.g. "CMS-1530 rename test - NEW name")
  ab open "$DASHBOARD_URL/login" >/dev/null; idle
  case "$(ab get url)" in */login*) ;; *) die "already logged in — call ensure_logged_out first"; return 1;; esac
  click_text 'button "Log In for Business Users"' || return 1; idle
  case "$(ab get url)" in *agencyportal*)
    click_text 'Login with Government Email' || return 1; idle
    click_text 'button "System Admin"' || return 1; idle
    ab open "$DASHBOARD_URL/login" >/dev/null; idle
    click_text 'button "Log In for Business Users"' || return 1; idle;; esac
  click_text 'button "Login"' || return 1; idle          # top "Login" = dropdown mode
  click_text 'Select username' || return 1
  ab find text "$1" click >/dev/null || { die "mockpass user not found: $1"; return 1; }
  ab wait --url "**${DASHBOARD_URL#https://}/**" >/dev/null 2>&1; idle
  ab wait --text "Find Licence" >/dev/null 2>&1
  ab find text "Enter Dashboard" click >/dev/null 2>&1 || true   # BIZ_LOCAL ESD modal, if shown
  case "$(ab get url)" in */login*) die "login failed (still on /login)"; return 1;; esac
  ab get url
}

logout_ui() { # profile menu → "Log Out" item → confirm with the LAST "Log Out" button
  click_text 'button "profile menu"' || return 1; sleep 1
  ab find text "Log Out" click >/dev/null 2>&1; sleep 1
  local r; r=$(ref_last 'button "Log Out"'); [ -n "$r" ] && ab click "$r" >/dev/null
  ab wait --url "**/login**" >/dev/null 2>&1
  case "$(ab get url)" in */login*) echo "logged-out";; *) die "logout failed"; return 1;; esac
}
