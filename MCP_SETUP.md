# MCP Configuration for LOOP Craft Bar & Kitchen

## Setup Instructions

### 1. Configure MCP Server

The MCP configuration has been created at `.gemini/antigravity/mcp_config.json`.

**To activate:**
1. Restart your Antigravity/Gemini agent
2. It will prompt you to complete OAuth flow with Supabase
3. Authenticate using your Supabase credentials

**Alternative manual setup:**
- In Agent Settings (Ctrl+, or Cmd+,)
- Navigate to "Customizations" tab
- Click "Authenticate" next to Supabase server

### 2. Install Agent Skills (Optional but Recommended)

Agent Skills provide ready-made instructions for working with Supabase:

```bash
npx skills add supabase/agent-skills
```

### 3. Update Environment Variables

Before connecting, update `.env.local` with your actual Supabase credentials:

```bash
# Get these from: https://app.supabase.com/project/dpzywkvqvstmrxcumdtd/settings/api
NEXT_PUBLIC_SUPABASE_URL=https://dpzywkvqvstmrxcumdtd.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
```

### 4. Apply Migration

Once authenticated, apply the migration:

**Option A: Via Supabase Dashboard**
1. Go to https://app.supabase.com/project/dpzywkvqvstmrxcumdtd
2. Navigate to SQL Editor
3. Copy contents from `supabase/migrations/20260817000001_fb_operations_enhancer_mvp.sql`
4. Paste and run

**Option B: Via Supabase CLI**
```bash
supabase db push
```

### 5. Verify Setup

Run the verification script in Supabase SQL Editor:
```sql
-- Copy contents from supabase/verification.sql
```

Expected output: All checks should PASS

### 6. Run Test Cases (Optional)

After verification, run test cases:
```sql
-- Copy contents from supabase/test_cases.sql
```

## Project Reference

- **Project ID**: `dpzywkvqvstmrxcumdtd`
- **Migration File**: `supabase/migrations/20260817000001_fb_operations_enhancer_mvp.sql`
- **Tables Created**: 17 core tables
- **Features**: Bar Control, Kitchen Control, Café Control, Inventory, POS Integration

## Next Steps After Setup

1. ✅ Apply migration to Supabase
2. ✅ Verify all 17 tables created
3. ✅ Run verification script
4. 🔄 Build Next.js frontend components
5. 🔄 Implement bar/kitchen/café dashboards
6. 🔄 Add real-time inventory tracking
7. 🔄 Create wastage approval workflows
8. 🔄 Build POS integration webhooks

## Troubleshooting

**Authentication Issues:**
- Check that project_ref in mcp_config.json matches your Supabase project
- Ensure you have owner/admin access to the project
- Try re-authenticating via Agent Settings

**Migration Failures:**
- Check Supabase logs for error details
- Ensure no conflicting tables exist
- Verify you're using the correct database branch

**MCP Connection Issues:**
- Restart the agent after saving config
- Check network connectivity to mcp.supabase.com
- Verify OAuth tokens are valid
