# Supabase Agent Deep Security Scan — 2026-02-25
> Source: Supabase AI Agent conversation (hlsitechio)
> Saved by: Claude Opus orchestrator

## CRITICAL FINDINGS

### 1. Unprotected Message Queues (pgmq) — NO RLS
- `pgmq.q_chief-commands` — **OPEN**
- `pgmq.q_content-pipeline` — **OPEN**
- `pgmq.q_hunt-tasks` — **OPEN**
- `pgmq.q_recon-tasks` — **OPEN**
- `pgmq.q_alerts` — **OPEN**
- Archives: `pgmq.a_*` — all **OPEN**
- `pgmq.meta` — **OPEN**
- **Impact**: Anyone with anon key can enqueue/dequeue tasks driving LLM agents

### 2. Edge Functions WITHOUT JWT Verification
- `gateway` — verify_jwt: **false** (heavy traffic, main entry point)
- `ghost` — verify_jwt: **false**
- `railway-status` — verify_jwt: **false**
- **Impact**: Unauthenticated callers can invoke agent commands

### 3. Overly-Permissive RLS Policies (INSERT/UPDATE ANYONE)
- `chiefs`: anon_insert_chiefs (INSERT ANYONE)
- `chief_runs`: anon_insert/update (INSERT/UPDATE ANYONE), anon_read (SELECT ANYONE)
- `heartbeat_metrics`: anon_insert/read (INSERT/SELECT ANYONE)
- `device_codes`: "Service can insert device codes" (WITH CHECK true)
- **Impact**: Attackers can forge telemetry, manufacture runs, poison dashboards

### 4. Public SELECT on Intel Tables
- `anon_read_chiefs`
- `anon_read_chief_runs`
- `anon_read_incidents`
- `anon_read_swarm_agents`
- `anon_read_heartbeat`
- **Impact**: Full internal posture exposed (agents, runs, incidents, health)

### 5. API Traffic Patterns
- Repeated REST requests from **multiple AWS IP ranges**
- Endpoints hit: `/rest/v1/api_keys`, `/rest/v1/agent_commands`, `/rest/v1/agents`, `/rest/v1/agent_sessions`, `/rest/v1/memories`, `/rest/v1/swarm_agents`, `/rest/v1/heartbeat_metrics`, `/rest/v1/rpc/read`
- User agents: `Python/3.13 aiohttp/3.13.3`, `Deno/SupabaseEdgeRuntime`
- Repeated PATCH on `/rest/v1/api_keys` from numerous AWS IPs

### 6. Hardcoded UUID in Memories Policies
- Policies use: `user_id = 'f6a421eb-...'`
- Brittle if compromised

### 7. Realtime Partitions Without RLS
- `realtime.messages` has RLS true
- Daily partitions `messages_2026_02_22..28` have **rls_enabled: false**

### 8. Functions with Mutable search_path
- `public.notify_incident`
- `public.expire_tool_approvals`
- `public.notify_finding`

## MEDIUM RISK
- `pg_net` extension installed (DB-initiated HTTP — potential SSRF)
- Storage policies restrict to bucket 'agent-files' with auth.uid() prefix (OK)
- Leaked password protection disabled in Auth

## RECOMMENDED ACTIONS
1. Enable RLS on ALL pgmq.* tables
2. Enable JWT verification on Edge Functions (gateway, ghost)
3. Replace all "always-true" INSERT/UPDATE policies
4. Rotate anon and service_role keys
5. Restrict SELECT on intel tables to authenticated only
6. Fix mutable search_path on flagged functions
7. Audit gateway function code for open proxying
8. Move provider API keys to Supabase Secrets

## IPs TO INVESTIGATE
- Multiple AWS IP ranges hitting REST endpoints
- Need to pull actual IPs from Supabase API logs
