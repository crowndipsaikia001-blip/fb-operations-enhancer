# LOOP Craft Bar & Kitchen - Operations Enhancer

## Quick Start Guide

### 1. Get Your Supabase Credentials

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Create a new project or select existing one
3. Go to **Settings** → **API**
4. Copy these values:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon/public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role key** → `SUPABASE_SERVICE_ROLE_KEY` (keep secret!)

### 2. Configure Environment

Edit `.env.local` with your actual credentials:

```bash
NEXT_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 3. Apply the Migration

**Option A: Using Supabase Dashboard (Recommended for first time)**
1. Go to your Supabase project
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy entire content from `supabase/migrations/20260817000001_fb_operations_enhancer_mvp.sql`
5. Paste and click **Run**
6. Verify success (should show "Success. No rows returned")

**Option B: Using Supabase CLI**
```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project (get project ref from dashboard URL)
supabase link --project-ref your-project-ref

# Apply migration
supabase db push
```

### 4. Verify the Migration

Run the verification script in Supabase SQL Editor:
1. Copy content from `supabase/verification.sql`
2. Paste into SQL Editor
3. Run and check all tests show ✅ PASS

### 5. Run Test Cases (Optional)

To test the system logic:
1. Copy content from `supabase/test_cases.sql`
2. Paste into SQL Editor
3. Run and verify all test cases pass

### 6. Start Development Server

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

---

## Database Schema Overview

The migration creates **17 core tables**:

### Core Tables
- `properties` - Restaurant/venue locations
- `roles` - System roles (admin, manager, supervisor, staff)
- `people` - Staff members with authority levels (1-4)
- `property_memberships` - Links people to properties with roles

### Inventory & Stock
- `categories` - Item categories (Bar, Kitchen, Café)
- `items` - Ingredients/products master data
- `stock_levels` - Current stock per property/item
- `stock_movements` - All stock changes (signed quantities)
- `transfer_requests` - Inter-property transfers
- `transfer_items` - Transfer line items

### Operations
- `purchase_orders` - Supplier orders
- `purchase_order_items` - PO line items
- `wastage_requests` - Waste approval workflow
- `wastage_items` - Wastage line items
- `pos_tickets` - POS sales data (idempotent)
- `pos_ticket_items` - Ticket line items

### Audit & Security
- `audit_logs` - Immutable audit trail
- RLS policies on all tables
- Authority-based access control

---

## Next Steps

After setup, you can:

1. **Build the frontend** - Create UI components for each module
2. **Add API routes** - Create Next.js API endpoints for operations
3. **Implement dashboards** - Build management views for Bar, Kitchen, Café
4. **Add real-time features** - Use Supabase Realtime for live updates
5. **Generate TypeScript types** - Use Supabase CLI: `npx supabase gen types typescript --local > lib/database.types.ts`

---

## Security Notes

- ✅ All tables have Row Level Security (RLS) enabled
- ✅ Authority model: admin(1) < manager(2) < supervisor(3) < staff(4)
- ✅ Audit logs are immutable (cannot be modified/deleted)
- ✅ POS tickets are idempotent (duplicate webhooks rejected)
- ✅ Wastage requires authorization before affecting stock
- ✅ Service role key must NEVER be exposed to client-side code

---

## Support

For issues or questions:
1. Check verification script results
2. Review test cases for expected behavior
3. Consult Supabase documentation: https://supabase.com/docs
