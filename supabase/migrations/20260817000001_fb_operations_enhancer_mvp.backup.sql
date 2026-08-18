-- ============================================================================
-- FB OPERATIONS ENHANCER — MVP REVISED SCHEMA MIGRATION (REVISION 5)
-- Classification: Data-preserving and table-non-destructive, subject to review of behavioral changes.
-- Target: Supabase PostgreSQL (Standard Public Schema)
-- ============================================================================

-- ============================================================================
-- 00. EXTENSIONS & HARDENED SECURITY DEFINER HELPERS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper: Resolve authenticated Supabase user to people.id
CREATE OR REPLACE FUNCTION public.current_user_person_id()
RETURNS UUID AS $$
  SELECT id FROM public.people WHERE auth_user_id = auth.uid() AND is_active = true LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE ALL ON FUNCTION public.current_user_person_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_person_id() TO authenticated;

-- Helper: Evaluate property membership and authority level (1=Admin, 2=Manager, 3=Supervisor, 4=Staff)
CREATE OR REPLACE FUNCTION public.current_user_has_property_access(target_property_id UUID, required_min_authority INT DEFAULT 4)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM public.property_memberships pm
    JOIN public.roles r ON pm.role_id = r.id
    JOIN public.people p ON pm.person_id = p.id
    WHERE pm.property_id = target_property_id
      AND p.auth_user_id = auth.uid()
      AND p.is_active = true
      AND r.authority_level <= required_min_authority
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE ALL ON FUNCTION public.current_user_has_property_access(UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_has_property_access(UUID, INT) TO authenticated;


-- ============================================================================
-- 01. RECONCILE EXISTING 7 FOUNDATION TABLES
-- ============================================================================

-- Table 1: properties
ALTER TABLE public.properties 
  ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
  ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'INR';

-- Table 2: roles
ALTER TABLE public.roles 
  ADD COLUMN IF NOT EXISTS authority_level INT NOT NULL DEFAULT 4;

-- Table 4: departments (Table created first without head_person_id FK)
CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL, -- 'BAR', 'KITCHEN', 'CAFE', 'SERVICE', 'STEWARDING', 'ADMIN'
  head_person_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_department_code UNIQUE (property_id, code)
);

-- Table 3: sections
ALTER TABLE public.sections 
  ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS section_type TEXT NOT NULL DEFAULT 'DINING',
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Table 5: people (Reconciled with auth linkage)
ALTER TABLE public.people 
  ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS operational_designation TEXT NOT NULL DEFAULT 'STEWARD',
  ADD COLUMN IF NOT EXISTS roster_group TEXT NOT NULL DEFAULT 'STEWARDS',
  ADD COLUMN IF NOT EXISTS default_weekly_off INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Add deferred Foreign Key on departments.head_person_id -> people.id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_departments_head_person'
  ) THEN
    ALTER TABLE public.departments 
      ADD CONSTRAINT fk_departments_head_person 
      FOREIGN KEY (head_person_id) REFERENCES public.people(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Table 11: sops
ALTER TABLE public.sops 
  ADD COLUMN IF NOT EXISTS department_id UUID REFERENCES public.departments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS version INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Table 12: tasks
ALTER TABLE public.tasks 
  ADD COLUMN IF NOT EXISTS sop_id UUID REFERENCES public.sops(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS scheduled_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES public.people(id) ON DELETE SET NULL;


-- ============================================================================
-- 02. WORKFORCE & ROSTER DOMAIN
-- ============================================================================

-- Table 6: property_memberships (AUTHORITATIVE ACCESS MATRIX)
CREATE TABLE IF NOT EXISTS public.property_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE RESTRICT,
  is_primary BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_person UNIQUE (property_id, person_id)
);

-- Table 7: roster_weeks
CREATE TABLE IF NOT EXISTS public.roster_weeks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL,
  week_end_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'READY_FOR_REVIEW', 'PENDING_APPROVALS', 'PUBLISHED', 'ARCHIVED'
  created_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  published_by UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_week_start UNIQUE (property_id, week_start_date)
);

-- Table 8: roster_assignments
CREATE TABLE IF NOT EXISTS public.roster_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roster_week_id UUID NOT NULL REFERENCES public.roster_weeks(id) ON DELETE CASCADE,
  person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  assignment_date DATE NOT NULL,
  assignment_code TEXT NOT NULL, -- '1ST', '2ND', 'RL', 'BRK', 'WO'
  normal_rotation_state TEXT NOT NULL, -- '1ST', '2ND' (Preserved independently)
  reporting_group TEXT NOT NULL, -- 'FIRST_SHIFT', 'SECOND_SHIFT', 'NONE'
  is_manual_override BOOLEAN NOT NULL DEFAULT false,
  override_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_person_assignment_date UNIQUE (person_id, assignment_date)
);

-- Table 9: rl_proposals
CREATE TABLE IF NOT EXISTS public.rl_proposals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roster_week_id UUID NOT NULL REFERENCES public.roster_weeks(id) ON DELETE CASCADE,
  person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  duty_date DATE NOT NULL,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PROPOSED', -- 'PROPOSED', 'APPROVED', 'REJECTED'
  proposed_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  reviewed_by UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_person_rl_week UNIQUE (roster_week_id, person_id)
);

-- Table 10: brk_periods
CREATE TABLE IF NOT EXISTS public.brk_periods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roster_week_id UUID NOT NULL REFERENCES public.roster_weeks(id) ON DELETE CASCADE,
  person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  duty_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'REJECTED'
  approved_by UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 03. QUALITY, CHECKLISTS & SOP EXECUTION
-- ============================================================================

-- Table 13: checklist_templates
CREATE TABLE IF NOT EXISTS public.checklist_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  section_id UUID REFERENCES public.sections(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  frequency TEXT NOT NULL DEFAULT 'DAILY_OPENING',
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 14: checklist_submissions
CREATE TABLE IF NOT EXISTS public.checklist_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  template_id UUID NOT NULL REFERENCES public.checklist_templates(id) ON DELETE RESTRICT,
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  submitted_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  shift_date DATE NOT NULL DEFAULT CURRENT_DATE,
  shift_type TEXT NOT NULL, -- '1ST', '2ND', 'RL'
  responses JSONB NOT NULL DEFAULT '{}'::jsonb,
  passed_count INT NOT NULL DEFAULT 0,
  failed_count INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'SUBMITTED', -- 'SUBMITTED', 'REVIEWED', 'ACTION_REQUIRED'
  reviewed_by UUID REFERENCES public.people(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 04. INVENTORY, MOVEMENT LEDGER & TWO-STAGE WASTAGE
-- ============================================================================

-- Table 15: item_master
CREATE TABLE IF NOT EXISTS public.item_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  item_code TEXT NOT NULL,
  item_category TEXT NOT NULL, -- 'SPIRITS', 'WINE', 'BEER', 'DAIRY', 'MEAT', 'SEAFOOD', 'PRODUCE', 'DRY_GOODS', 'COFFEE_TEA', 'PACKAGING', 'CHEMICALS'
  primary_uom TEXT NOT NULL,
  cost_per_primary_uom DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  par_level DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  reorder_point DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_item_code UNIQUE (property_id, item_code)
);

-- Table 16: inventory_locations
CREATE TABLE IF NOT EXISTS public.inventory_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  section_id UUID REFERENCES public.sections(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 17: stock_movements (Immutable Inventory Movement Ledger)
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE RESTRICT,
  from_location_id UUID REFERENCES public.inventory_locations(id) ON DELETE RESTRICT,
  to_location_id UUID REFERENCES public.inventory_locations(id) ON DELETE RESTRICT,
  movement_type TEXT NOT NULL, -- 'PURCHASE_RECEIVING', 'TRANSFER', 'CONSUMPTION_POS', 'WASTAGE', 'BREAKAGE', 'AUDIT_ADJUSTMENT'
  quantity DECIMAL(12,4) NOT NULL CHECK (quantity > 0),
  uom TEXT NOT NULL,
  unit_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
  reference_id UUID,
  notes TEXT,
  recorded_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial Unique Index: Guarantees no two WASTAGE movements can reference the same wastage_records.id
CREATE UNIQUE INDEX IF NOT EXISTS uq_stock_movement_wastage_ref 
  ON public.stock_movements (reference_id) 
  WHERE movement_type = 'WASTAGE';

-- Table 18: stock_balances (Materialized Snapshot Cache)
CREATE TABLE IF NOT EXISTS public.stock_balances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE RESTRICT,
  location_id UUID NOT NULL REFERENCES public.inventory_locations(id) ON DELETE CASCADE,
  quantity_on_hand DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  last_counted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_item_location UNIQUE (property_id, item_id, location_id)
);

-- Table 19: stock_counts (Physical Count Header)
CREATE TABLE IF NOT EXISTS public.stock_counts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  location_id UUID NOT NULL REFERENCES public.inventory_locations(id) ON DELETE RESTRICT,
  count_date DATE NOT NULL DEFAULT CURRENT_DATE,
  shift_type TEXT NOT NULL DEFAULT 'CLOSING',
  status TEXT NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'SUBMITTED', 'APPROVED'
  conducted_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  approved_by UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  approved_at TIMESTAMPTZ,
  total_variance_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 20: stock_count_items (Physical Count Detail)
CREATE TABLE IF NOT EXISTS public.stock_count_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stock_count_id UUID NOT NULL REFERENCES public.stock_counts(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE RESTRICT,
  expected_quantity DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  counted_quantity DECIMAL(12,4) NOT NULL DEFAULT 0.0000,
  variance_quantity DECIMAL(12,4) GENERATED ALWAYS AS (counted_quantity - expected_quantity) STORED,
  unit_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  variance_cost DECIMAL(12,2) GENERATED ALWAYS AS ((counted_quantity - expected_quantity) * unit_cost) STORED,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_count_item UNIQUE (stock_count_id, item_id)
);

-- Table 21: wastage_records (Guaranteed Exactly-Once Authorized Wastage)
CREATE TABLE IF NOT EXISTS public.wastage_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  section_id UUID REFERENCES public.sections(id) ON DELETE SET NULL,
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE RESTRICT,
  location_id UUID NOT NULL REFERENCES public.inventory_locations(id) ON DELETE RESTRICT,
  quantity DECIMAL(10,4) NOT NULL CHECK (quantity > 0),
  uom TEXT NOT NULL,
  cost_value DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'AUTHORIZED', 'REJECTED'
  reported_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  authorized_by UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  authorized_at TIMESTAMPTZ,
  rejection_reason TEXT,
  stock_movement_id UUID UNIQUE REFERENCES public.stock_movements(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 05. SHARED RECIPE & COSTING ENGINE (KITCHEN + BAR + CAFÉ)
-- ============================================================================

-- Table 22: recipes
CREATE TABLE IF NOT EXISTS public.recipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  department_id UUID NOT NULL REFERENCES public.departments(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  recipe_type TEXT NOT NULL, -- 'KITCHEN_DISH', 'BAR_COCKTAIL', 'BAR_POUR', 'CAFE_BEVERAGE', 'PREP_BATCH'
  yield_portions INT NOT NULL DEFAULT 1 CHECK (yield_portions > 0),
  selling_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  calculated_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  target_cost_percentage DECIMAL(5,2) NOT NULL DEFAULT 30.00,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 23: recipe_ingredients
CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE RESTRICT,
  quantity DECIMAL(10,4) NOT NULL CHECK (quantity > 0),
  uom TEXT NOT NULL,
  cost_share DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_recipe_item UNIQUE (recipe_id, item_id)
);


-- ============================================================================
-- 06. DEPARTMENT CONTROLS (BAR, KITCHEN, CAFÉ)
-- ============================================================================

-- Table 24: beverage_master (Canonical Conversion Source of Truth)
CREATE TABLE IF NOT EXISTS public.beverage_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE CASCADE,
  bottle_volume_ml DECIMAL(8,2) NOT NULL CHECK (bottle_volume_ml > 0),
  standard_pour_ml DECIMAL(8,2) NOT NULL DEFAULT 30.00 CHECK (standard_pour_ml > 0),
  servings_per_bottle DECIMAL(8,2) GENERATED ALWAYS AS (bottle_volume_ml / standard_pour_ml) STORED,
  tare_bottle_weight_grams DECIMAL(8,2),
  full_bottle_weight_grams DECIMAL(8,2),
  density_factor DECIMAL(6,4) NOT NULL DEFAULT 1.0000,
  spirit_category TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_beverage_item UNIQUE (item_id)
);

-- Table 25: bar_shift_reconciliations (Bar Shift Header)
CREATE TABLE IF NOT EXISTS public.bar_shift_reconciliations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  shift_date DATE NOT NULL DEFAULT CURRENT_DATE,
  shift_type TEXT NOT NULL, -- '1ST', '2ND', 'RL'
  bartender_person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  supervisor_person_id UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'DRAFT',
  total_variance_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  supervisor_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_bar_shift_instance UNIQUE (property_id, section_id, shift_date, shift_type)
);

-- Table 26: bar_item_reconciliations (Item-Level Exact Control Chain)
CREATE TABLE IF NOT EXISTS public.bar_item_reconciliations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bar_reconciliation_id UUID NOT NULL REFERENCES public.bar_shift_reconciliations(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES public.item_master(id) ON DELETE RESTRICT,
  opening_stock_ml DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  transfers_in_ml DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  transfers_out_ml DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  theoretical_consumption_ml DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  wastage_breakage_ml DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  -- Exact Formula: Expected = Opening + Transfers In - Transfers Out - Theoretical - Wastage
  expected_closing_ml DECIMAL(10,2) GENERATED ALWAYS AS (
    opening_stock_ml + transfers_in_ml - transfers_out_ml - theoretical_consumption_ml - wastage_breakage_ml
  ) STORED,
  actual_closing_ml DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  -- Exact Formula: Variance = Actual - Expected
  variance_ml DECIMAL(10,2) GENERATED ALWAYS AS (
    actual_closing_ml - (opening_stock_ml + transfers_in_ml - transfers_out_ml - theoretical_consumption_ml - wastage_breakage_ml)
  ) STORED,
  unit_cost_per_ml DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
  financial_variance_cost DECIMAL(10,2) GENERATED ALWAYS AS (
    (actual_closing_ml - (opening_stock_ml + transfers_in_ml - transfers_out_ml - theoretical_consumption_ml - wastage_breakage_ml)) * unit_cost_per_ml
  ) STORED,
  discrepancy_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_bar_item_recon UNIQUE (bar_reconciliation_id, item_id)
);

-- Table 27: temperature_logs (Kitchen Food Safety)
CREATE TABLE IF NOT EXISTS public.temperature_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  section_id UUID NOT NULL REFERENCES public.sections(id) ON DELETE RESTRICT,
  equipment_name TEXT NOT NULL,
  recorded_temp_celsius DECIMAL(4,1) NOT NULL,
  min_threshold DECIMAL(4,1) NOT NULL,
  max_threshold DECIMAL(4,1) NOT NULL,
  is_compliant BOOLEAN NOT NULL,
  corrective_action TEXT,
  recorded_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 28: cafe_daily_reconciliations (Café Control)
CREATE TABLE IF NOT EXISTS public.cafe_daily_reconciliations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  reconciliation_date DATE NOT NULL DEFAULT CURRENT_DATE,
  shift_type TEXT NOT NULL,
  espresso_shots_sold INT NOT NULL DEFAULT 0,
  coffee_beans_used_grams DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  gram_per_shot_average DECIMAL(4,2) GENERATED ALWAYS AS (
    CASE WHEN espresso_shots_sold > 0 THEN coffee_beans_used_grams / espresso_shots_sold ELSE 0.00 END
  ) STORED,
  milk_liters_used DECIMAL(6,2) NOT NULL DEFAULT 0.00,
  bakery_opening_units INT NOT NULL DEFAULT 0,
  bakery_sold_units INT NOT NULL DEFAULT 0,
  bakery_wastage_units INT NOT NULL DEFAULT 0,
  bakery_closing_units INT NOT NULL DEFAULT 0,
  barista_person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_cafe_shift_instance UNIQUE (property_id, reconciliation_date, shift_type)
);


-- ============================================================================
-- 07. POS INTEGRATION & SALES RECONCILIATION
-- ============================================================================

-- Table 29: pos_sales_tickets (Idempotent Header)
CREATE TABLE IF NOT EXISTS public.pos_sales_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  source_system TEXT NOT NULL, -- 'PETPOOJA', 'POSIST', 'SQUARE', 'TOAST', 'MANUAL'
  external_ticket_id TEXT NOT NULL,
  ticket_number TEXT NOT NULL,
  business_date DATE NOT NULL,
  section_id UUID REFERENCES public.sections(id) ON DELETE SET NULL,
  opened_at TIMESTAMPTZ NOT NULL,
  closed_at TIMESTAMPTZ NOT NULL,
  gross_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  net_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  payment_method TEXT NOT NULL DEFAULT 'CASH',
  steward_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_pos_ticket UNIQUE (property_id, source_system, external_ticket_id)
);

-- Table 30: pos_ticket_items (Item-to-Recipe Mapping & Exception Queue)
CREATE TABLE IF NOT EXISTS public.pos_ticket_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.pos_sales_tickets(id) ON DELETE CASCADE,
  external_item_id TEXT NOT NULL,
  item_name TEXT NOT NULL,
  recipe_id UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
  mapping_status TEXT NOT NULL DEFAULT 'MAPPED', -- 'MAPPED', 'UNMAPPED', 'RESOLVED'
  quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  is_void BOOLEAN NOT NULL DEFAULT false,
  is_complimentary BOOLEAN NOT NULL DEFAULT false,
  depletion_status TEXT NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 31: daily_sales_summaries
CREATE TABLE IF NOT EXISTS public.daily_sales_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  business_date DATE NOT NULL,
  gross_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  net_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  food_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  bar_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  cafe_sales DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_covers INT NOT NULL DEFAULT 0,
  average_spend_per_cover DECIMAL(10,2) GENERATED ALWAYS AS (
    CASE WHEN total_covers > 0 THEN net_sales / total_covers ELSE 0.00 END
  ) STORED,
  discounts_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  voids_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  nc_comp_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  reconciled_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_property_business_date UNIQUE (property_id, business_date)
);

-- Table 32: voids_discounts_comp_log
CREATE TABLE IF NOT EXISTS public.voids_discounts_comp_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  business_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ticket_id UUID REFERENCES public.pos_sales_tickets(id) ON DELETE SET NULL,
  item_name TEXT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  type TEXT NOT NULL, -- 'VOID', 'DISCOUNT', 'COMPLIMENTARY_NC', 'STAFF_MEAL'
  reason TEXT NOT NULL,
  authorized_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  steward_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 08. GOVERNANCE, AUDIT LOGS & NOTIFICATIONS
-- ============================================================================

-- Table 33: management_approvals
CREATE TABLE IF NOT EXISTS public.management_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  approval_type TEXT NOT NULL, -- 'RL_SHIFT', 'BRK_DUTY', 'LEAVE', 'WASTAGE', 'STOCK_ADJUSTMENT', 'VOID'
  entity_id UUID NOT NULL,
  requested_by UUID NOT NULL REFERENCES public.people(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'PENDING',
  actioned_by UUID REFERENCES public.people(id) ON DELETE RESTRICT,
  actioned_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table 34: audit_logs (Immutable Forensic Security Ledger)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  actor_person_id UUID REFERENCES public.people(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE', 'OVERRIDE', 'APPROVE', 'PUBLISH'
  entity_type TEXT NOT NULL, -- 'ROSTER', 'TASK', 'INVENTORY', 'SALES', 'APPROVAL'
  entity_id UUID NOT NULL,
  previous_state JSONB,
  new_state JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Controlled Append Function for Audit Logs (Direct INSERT is forbidden to clients)
CREATE OR REPLACE FUNCTION public.append_audit_log(
  target_property_id UUID,
  p_action TEXT,
  p_entity_type TEXT,
  p_entity_id UUID,
  p_previous_state JSONB DEFAULT NULL,
  p_new_state JSONB DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
  v_actor_id UUID;
BEGIN
  v_actor_id := public.current_user_person_id();
  
  IF NOT public.current_user_has_property_access(target_property_id, 4) THEN
    RAISE EXCEPTION 'Access denied: user is not an active member of property %', target_property_id;
  END IF;

  INSERT INTO public.audit_logs (
    property_id,
    actor_person_id,
    action,
    entity_type,
    entity_id,
    previous_state,
    new_state,
    ip_address,
    created_at
  ) VALUES (
    target_property_id,
    v_actor_id,
    p_action,
    p_entity_type,
    p_entity_id,
    p_previous_state,
    p_new_state,
    p_ip_address,
    now()
  ) RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

REVOKE ALL ON FUNCTION public.append_audit_log(UUID, TEXT, TEXT, UUID, JSONB, JSONB, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.append_audit_log(UUID, TEXT, TEXT, UUID, JSONB, JSONB, TEXT) TO authenticated;

-- Table 35: system_notifications
CREATE TABLE IF NOT EXISTS public.system_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  recipient_person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'INFO',
  link_url TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ============================================================================
-- 09. TRIGGERS: STOCK BALANCES, IMMUTABLE AUDIT & WASTAGE LEDGER POSTING
-- ============================================================================

-- A. Synchronize stock_balances from stock_movements (Exact Additive Delta Arithmetic)
CREATE OR REPLACE FUNCTION public.fn_sync_stock_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. Source location: Add negative delta (Proof: 100 + (-20) = 80)
  IF NEW.from_location_id IS NOT NULL THEN
    INSERT INTO public.stock_balances (property_id, item_id, location_id, quantity_on_hand, updated_at)
    VALUES (NEW.property_id, NEW.item_id, NEW.from_location_id, -NEW.quantity, now())
    ON CONFLICT (property_id, item_id, location_id)
    DO UPDATE SET 
      quantity_on_hand = public.stock_balances.quantity_on_hand + EXCLUDED.quantity_on_hand,
      updated_at = now();
  END IF;

  -- 2. Destination location: Add positive delta
  IF NEW.to_location_id IS NOT NULL THEN
    INSERT INTO public.stock_balances (property_id, item_id, location_id, quantity_on_hand, updated_at)
    VALUES (NEW.property_id, NEW.item_id, NEW.to_location_id, NEW.quantity, now())
    ON CONFLICT (property_id, item_id, location_id)
    DO UPDATE SET 
      quantity_on_hand = public.stock_balances.quantity_on_hand + EXCLUDED.quantity_on_hand,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

DROP TRIGGER IF EXISTS trg_stock_movement_balance_sync ON public.stock_movements;
CREATE TRIGGER trg_stock_movement_balance_sync
  AFTER INSERT ON public.stock_movements
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_stock_balance();

-- B. Exactly-Once Wastage Posting & Immutability Trigger
CREATE OR REPLACE FUNCTION public.fn_handle_authorized_wastage()
RETURNS TRIGGER AS $$
DECLARE
  v_movement_id UUID;
BEGIN
  -- INVARIANT: Once AUTHORIZED, the record is an immutable business event. No fields can be altered or reversed.
  IF OLD.status = 'AUTHORIZED' THEN
    IF (NEW.property_id IS DISTINCT FROM OLD.property_id) OR
       (NEW.department_id IS DISTINCT FROM OLD.department_id) OR
       (NEW.section_id IS DISTINCT FROM OLD.section_id) OR
       (NEW.item_id IS DISTINCT FROM OLD.item_id) OR
       (NEW.location_id IS DISTINCT FROM OLD.location_id) OR
       (NEW.quantity IS DISTINCT FROM OLD.quantity) OR
       (NEW.uom IS DISTINCT FROM OLD.uom) OR
       (NEW.cost_value IS DISTINCT FROM OLD.cost_value) OR
       (NEW.reason IS DISTINCT FROM OLD.reason) OR
       (NEW.status IS DISTINCT FROM OLD.status) OR
       (NEW.authorized_by IS DISTINCT FROM OLD.authorized_by) OR
       (NEW.authorized_at IS DISTINCT FROM OLD.authorized_at) OR
       (NEW.stock_movement_id IS DISTINCT FROM OLD.stock_movement_id) THEN
      RAISE EXCEPTION 'Authorized wastage records are immutable business events and cannot be modified or reversed.';
    END IF;
    RETURN NEW;
  END IF;

  -- Prevent client tampering with stock_movement_id prior to authorization
  IF OLD.stock_movement_id IS NOT NULL AND (NEW.stock_movement_id IS NULL OR NEW.stock_movement_id <> OLD.stock_movement_id) THEN
    RAISE EXCEPTION 'stock_movement_id cannot be modified or cleared once assigned.';
  END IF;

  -- Strict Transition: Fires ONLY when transitioning from non-authorized to AUTHORIZED and no movement exists yet
  IF OLD.status <> 'AUTHORIZED' AND NEW.status = 'AUTHORIZED' AND OLD.stock_movement_id IS NULL THEN
    INSERT INTO public.stock_movements (
      property_id,
      item_id,
      from_location_id,
      to_location_id,
      movement_type,
      quantity,
      uom,
      unit_cost,
      reference_id,
      notes,
      recorded_by,
      created_at
    ) VALUES (
      NEW.property_id,
      NEW.item_id,
      NEW.location_id,
      NULL,
      'WASTAGE',
      NEW.quantity,
      NEW.uom,
      CASE WHEN NEW.quantity > 0 THEN NEW.cost_value / NEW.quantity ELSE 0.00 END,
      NEW.id,
      'Authorized wastage: ' || NEW.reason,
      COALESCE(NEW.authorized_by, NEW.reported_by),
      now()
    ) RETURNING id INTO v_movement_id;

    NEW.stock_movement_id := v_movement_id;
    NEW.authorized_at := COALESCE(NEW.authorized_at, now());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

DROP TRIGGER IF EXISTS trg_authorized_wastage_posting ON public.wastage_records;
CREATE TRIGGER trg_authorized_wastage_posting
  BEFORE UPDATE ON public.wastage_records
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_handle_authorized_wastage();

-- C. Database-Level Immutability on audit_logs
CREATE OR REPLACE FUNCTION public.fn_prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Audit log records are immutable and cannot be updated or deleted.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON public.audit_logs;
CREATE TRIGGER trg_audit_logs_immutable
  BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_prevent_audit_log_modification();


-- ============================================================================
-- 10. COMPLETE ROW LEVEL SECURITY (RLS) POLICY MATRIX (ALL 35 MVP TABLES)
-- ============================================================================

-- Enable RLS across all 35 tables
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.people ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roster_weeks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roster_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rl_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brk_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_count_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wastage_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.beverage_master ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_shift_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bar_item_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temperature_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cafe_daily_reconciliations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_sales_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_ticket_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_sales_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voids_discounts_comp_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.management_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_notifications ENABLE ROW LEVEL SECURITY;

-- 1. properties
CREATE POLICY p_properties_select ON public.properties FOR SELECT TO authenticated
  USING (id IN (SELECT property_id FROM public.property_memberships WHERE person_id = public.current_user_person_id()));
CREATE POLICY p_properties_insert ON public.properties FOR INSERT TO authenticated
  WITH CHECK (false);
CREATE POLICY p_properties_update ON public.properties FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(id, 1));
CREATE POLICY p_properties_delete ON public.properties FOR DELETE TO authenticated
  USING (false);

-- 2. roles
CREATE POLICY p_roles_select ON public.roles FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_roles_insert ON public.roles FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 1));
CREATE POLICY p_roles_update ON public.roles FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));
CREATE POLICY p_roles_delete ON public.roles FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 3. sections
CREATE POLICY p_sections_select ON public.sections FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_sections_insert ON public.sections FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_sections_update ON public.sections FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_sections_delete ON public.sections FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 4. departments
CREATE POLICY p_departments_select ON public.departments FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_departments_insert ON public.departments FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_departments_update ON public.departments FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_departments_delete ON public.departments FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 5. people (Strict Multi-Tenant Isolation & Self-Update Hardening)
CREATE POLICY p_people_select ON public.people FOR SELECT TO authenticated
  USING (
    auth_user_id = auth.uid() OR id IN (
      SELECT pm_target.person_id 
      FROM public.property_memberships pm_target
      WHERE pm_target.property_id IN (
        SELECT pm_viewer.property_id 
        FROM public.property_memberships pm_viewer 
        WHERE pm_viewer.person_id = public.current_user_person_id()
      )
    )
  );
CREATE POLICY p_people_insert ON public.people FOR INSERT TO authenticated
  WITH CHECK (
    property_id IS NOT NULL AND
    EXISTS (
      SELECT 1 
      FROM public.property_memberships pm_creator
      JOIN public.roles r ON pm_creator.role_id = r.id
      WHERE pm_creator.person_id = public.current_user_person_id()
        AND pm_creator.property_id = property_id
        AND r.authority_level <= 2
    )
  );
CREATE POLICY p_people_update ON public.people FOR UPDATE TO authenticated
  USING (
    (id = public.current_user_person_id()) OR (
      property_id IS NOT NULL AND
      EXISTS (
        SELECT 1 
        FROM public.property_memberships pm_mgr
        JOIN public.roles r ON pm_mgr.role_id = r.id
        WHERE pm_mgr.person_id = public.current_user_person_id()
          AND pm_mgr.property_id = property_id
          AND r.authority_level <= 2
      )
    )
  )
  WITH CHECK (
    (
      id = public.current_user_person_id() 
      AND property_id = (SELECT p_old.property_id FROM public.people p_old WHERE p_old.id = public.current_user_person_id())
    ) OR (
      property_id IS NOT NULL AND
      EXISTS (
        SELECT 1 
        FROM public.property_memberships pm_mgr
        JOIN public.roles r ON pm_mgr.role_id = r.id
        WHERE pm_mgr.person_id = public.current_user_person_id()
          AND pm_mgr.property_id = property_id
          AND r.authority_level <= 2
      )
    )
  );
CREATE POLICY p_people_delete ON public.people FOR DELETE TO authenticated
  USING (false);

-- 6. property_memberships
CREATE POLICY p_memberships_select ON public.property_memberships FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_memberships_insert ON public.property_memberships FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 1));
CREATE POLICY p_memberships_update ON public.property_memberships FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));
CREATE POLICY p_memberships_delete ON public.property_memberships FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 7. roster_weeks
CREATE POLICY p_roster_weeks_select ON public.roster_weeks FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4) AND (status = 'PUBLISHED' OR public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_roster_weeks_insert ON public.roster_weeks FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_roster_weeks_update ON public.roster_weeks FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_roster_weeks_delete ON public.roster_weeks FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 8. roster_assignments
CREATE POLICY p_roster_assignments_select ON public.roster_assignments FOR SELECT TO authenticated
  USING (person_id = public.current_user_person_id() OR roster_week_id IN (
    SELECT id FROM public.roster_weeks WHERE property_id IN (
      SELECT property_id FROM public.property_memberships WHERE person_id = public.current_user_person_id()
    ) AND (status = 'PUBLISHED' OR public.current_user_has_property_access(property_id, 2))
  ));
CREATE POLICY p_roster_assignments_insert ON public.roster_assignments FOR INSERT TO authenticated
  WITH CHECK (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_roster_assignments_update ON public.roster_assignments FOR UPDATE TO authenticated
  USING (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_roster_assignments_delete ON public.roster_assignments FOR DELETE TO authenticated
  USING (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));

-- 9. rl_proposals
CREATE POLICY p_rl_proposals_select ON public.rl_proposals FOR SELECT TO authenticated
  USING (person_id = public.current_user_person_id() OR proposed_by = public.current_user_person_id() OR roster_week_id IN (
    SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)
  ));
CREATE POLICY p_rl_proposals_insert ON public.rl_proposals FOR INSERT TO authenticated
  WITH CHECK (proposed_by = public.current_user_person_id());
CREATE POLICY p_rl_proposals_update ON public.rl_proposals FOR UPDATE TO authenticated
  USING (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_rl_proposals_delete ON public.rl_proposals FOR DELETE TO authenticated
  USING (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));

-- 10. brk_periods
CREATE POLICY p_brk_periods_select ON public.brk_periods FOR SELECT TO authenticated
  USING (person_id = public.current_user_person_id() OR roster_week_id IN (
    SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 3)
  ));
CREATE POLICY p_brk_periods_insert ON public.brk_periods FOR INSERT TO authenticated
  WITH CHECK (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 3)));
CREATE POLICY p_brk_periods_update ON public.brk_periods FOR UPDATE TO authenticated
  USING (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_brk_periods_delete ON public.brk_periods FOR DELETE TO authenticated
  USING (roster_week_id IN (SELECT id FROM public.roster_weeks WHERE public.current_user_has_property_access(property_id, 2)));

-- 11. sops
CREATE POLICY p_sops_select ON public.sops FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_sops_insert ON public.sops FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_sops_update ON public.sops FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_sops_delete ON public.sops FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 12. tasks
CREATE POLICY p_tasks_select ON public.tasks FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_tasks_insert ON public.tasks FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_tasks_update ON public.tasks FOR UPDATE TO authenticated
  USING (assigned_to = public.current_user_person_id() OR public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_tasks_delete ON public.tasks FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));

-- 13. checklist_templates
CREATE POLICY p_checklist_templates_select ON public.checklist_templates FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_checklist_templates_insert ON public.checklist_templates FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_checklist_templates_update ON public.checklist_templates FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_checklist_templates_delete ON public.checklist_templates FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 14. checklist_submissions
CREATE POLICY p_checklist_submissions_select ON public.checklist_submissions FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_checklist_submissions_insert ON public.checklist_submissions FOR INSERT TO authenticated
  WITH CHECK (submitted_by = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_checklist_submissions_update ON public.checklist_submissions FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_checklist_submissions_delete ON public.checklist_submissions FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 15. item_master
CREATE POLICY p_item_master_select ON public.item_master FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_item_master_insert ON public.item_master FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_item_master_update ON public.item_master FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_item_master_delete ON public.item_master FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 16. inventory_locations
CREATE POLICY p_inventory_locations_select ON public.inventory_locations FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_inventory_locations_insert ON public.inventory_locations FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_inventory_locations_update ON public.inventory_locations FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_inventory_locations_delete ON public.inventory_locations FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 17. stock_movements (Append-Only Transactional Ledger)
CREATE POLICY p_stock_movements_select ON public.stock_movements FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_stock_movements_insert ON public.stock_movements FOR INSERT TO authenticated
  WITH CHECK (recorded_by = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_stock_movements_update ON public.stock_movements FOR UPDATE TO authenticated
  USING (false);
CREATE POLICY p_stock_movements_delete ON public.stock_movements FOR DELETE TO authenticated
  USING (false);

-- 18. stock_balances (Read-Only Cache to Clients)
CREATE POLICY p_stock_balances_select ON public.stock_balances FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_stock_balances_insert ON public.stock_balances FOR INSERT TO authenticated
  WITH CHECK (false);
CREATE POLICY p_stock_balances_update ON public.stock_balances FOR UPDATE TO authenticated
  USING (false);
CREATE POLICY p_stock_balances_delete ON public.stock_balances FOR DELETE TO authenticated
  USING (false);

-- 19. stock_counts
CREATE POLICY p_stock_counts_select ON public.stock_counts FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_stock_counts_insert ON public.stock_counts FOR INSERT TO authenticated
  WITH CHECK (conducted_by = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_stock_counts_update ON public.stock_counts FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_stock_counts_delete ON public.stock_counts FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 20. stock_count_items
CREATE POLICY p_stock_count_items_select ON public.stock_count_items FOR SELECT TO authenticated
  USING (stock_count_id IN (SELECT id FROM public.stock_counts WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_stock_count_items_insert ON public.stock_count_items FOR INSERT TO authenticated
  WITH CHECK (stock_count_id IN (SELECT id FROM public.stock_counts WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_stock_count_items_update ON public.stock_count_items FOR UPDATE TO authenticated
  USING (stock_count_id IN (SELECT id FROM public.stock_counts WHERE public.current_user_has_property_access(property_id, 3)));
CREATE POLICY p_stock_count_items_delete ON public.stock_count_items FOR DELETE TO authenticated
  USING (stock_count_id IN (SELECT id FROM public.stock_counts WHERE public.current_user_has_property_access(property_id, 2)));

-- 21. wastage_records
CREATE POLICY p_wastage_records_select ON public.wastage_records FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_wastage_records_insert ON public.wastage_records FOR INSERT TO authenticated
  WITH CHECK (reported_by = public.current_user_person_id() AND status = 'PENDING' AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_wastage_records_update ON public.wastage_records FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_wastage_records_delete ON public.wastage_records FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 22. recipes
CREATE POLICY p_recipes_select ON public.recipes FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_recipes_insert ON public.recipes FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_recipes_update ON public.recipes FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_recipes_delete ON public.recipes FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 23. recipe_ingredients
CREATE POLICY p_recipe_ingredients_select ON public.recipe_ingredients FOR SELECT TO authenticated
  USING (recipe_id IN (SELECT id FROM public.recipes WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_recipe_ingredients_insert ON public.recipe_ingredients FOR INSERT TO authenticated
  WITH CHECK (recipe_id IN (SELECT id FROM public.recipes WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_recipe_ingredients_update ON public.recipe_ingredients FOR UPDATE TO authenticated
  USING (recipe_id IN (SELECT id FROM public.recipes WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_recipe_ingredients_delete ON public.recipe_ingredients FOR DELETE TO authenticated
  USING (recipe_id IN (SELECT id FROM public.recipes WHERE public.current_user_has_property_access(property_id, 1)));

-- 24. beverage_master
CREATE POLICY p_beverage_master_select ON public.beverage_master FOR SELECT TO authenticated
  USING (item_id IN (SELECT id FROM public.item_master WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_beverage_master_insert ON public.beverage_master FOR INSERT TO authenticated
  WITH CHECK (item_id IN (SELECT id FROM public.item_master WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_beverage_master_update ON public.beverage_master FOR UPDATE TO authenticated
  USING (item_id IN (SELECT id FROM public.item_master WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_beverage_master_delete ON public.beverage_master FOR DELETE TO authenticated
  USING (item_id IN (SELECT id FROM public.item_master WHERE public.current_user_has_property_access(property_id, 1)));

-- 25. bar_shift_reconciliations
CREATE POLICY p_bar_recon_select ON public.bar_shift_reconciliations FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_bar_recon_insert ON public.bar_shift_reconciliations FOR INSERT TO authenticated
  WITH CHECK (bartender_person_id = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_bar_recon_update ON public.bar_shift_reconciliations FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_bar_recon_delete ON public.bar_shift_reconciliations FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 26. bar_item_reconciliations
CREATE POLICY p_bar_item_recon_select ON public.bar_item_reconciliations FOR SELECT TO authenticated
  USING (bar_reconciliation_id IN (SELECT id FROM public.bar_shift_reconciliations WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_bar_item_recon_insert ON public.bar_item_reconciliations FOR INSERT TO authenticated
  WITH CHECK (bar_reconciliation_id IN (SELECT id FROM public.bar_shift_reconciliations WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_bar_item_recon_update ON public.bar_item_reconciliations FOR UPDATE TO authenticated
  USING (bar_reconciliation_id IN (SELECT id FROM public.bar_shift_reconciliations WHERE public.current_user_has_property_access(property_id, 3)));
CREATE POLICY p_bar_item_recon_delete ON public.bar_item_reconciliations FOR DELETE TO authenticated
  USING (bar_reconciliation_id IN (SELECT id FROM public.bar_shift_reconciliations WHERE public.current_user_has_property_access(property_id, 1)));

-- 27. temperature_logs
CREATE POLICY p_temp_logs_select ON public.temperature_logs FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_temp_logs_insert ON public.temperature_logs FOR INSERT TO authenticated
  WITH CHECK (recorded_by = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_temp_logs_update ON public.temperature_logs FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_temp_logs_delete ON public.temperature_logs FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 28. cafe_daily_reconciliations
CREATE POLICY p_cafe_recon_select ON public.cafe_daily_reconciliations FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_cafe_recon_insert ON public.cafe_daily_reconciliations FOR INSERT TO authenticated
  WITH CHECK (barista_person_id = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_cafe_recon_update ON public.cafe_daily_reconciliations FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_cafe_recon_delete ON public.cafe_daily_reconciliations FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 29. pos_sales_tickets
CREATE POLICY p_pos_tickets_select ON public.pos_sales_tickets FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_pos_tickets_insert ON public.pos_sales_tickets FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_pos_tickets_update ON public.pos_sales_tickets FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_pos_tickets_delete ON public.pos_sales_tickets FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 30. pos_ticket_items
CREATE POLICY p_pos_ticket_items_select ON public.pos_ticket_items FOR SELECT TO authenticated
  USING (ticket_id IN (SELECT id FROM public.pos_sales_tickets WHERE public.current_user_has_property_access(property_id, 4)));
CREATE POLICY p_pos_ticket_items_insert ON public.pos_ticket_items FOR INSERT TO authenticated
  WITH CHECK (ticket_id IN (SELECT id FROM public.pos_sales_tickets WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_pos_ticket_items_update ON public.pos_ticket_items FOR UPDATE TO authenticated
  USING (ticket_id IN (SELECT id FROM public.pos_sales_tickets WHERE public.current_user_has_property_access(property_id, 2)));
CREATE POLICY p_pos_ticket_items_delete ON public.pos_ticket_items FOR DELETE TO authenticated
  USING (ticket_id IN (SELECT id FROM public.pos_sales_tickets WHERE public.current_user_has_property_access(property_id, 1)));

-- 31. daily_sales_summaries
CREATE POLICY p_daily_sales_select ON public.daily_sales_summaries FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_daily_sales_insert ON public.daily_sales_summaries FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_daily_sales_update ON public.daily_sales_summaries FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_daily_sales_delete ON public.daily_sales_summaries FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 32. voids_discounts_comp_log
CREATE POLICY p_voids_log_select ON public.voids_discounts_comp_log FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_voids_log_insert ON public.voids_discounts_comp_log FOR INSERT TO authenticated
  WITH CHECK (authorized_by = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_voids_log_update ON public.voids_discounts_comp_log FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_voids_log_delete ON public.voids_discounts_comp_log FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 33. management_approvals
CREATE POLICY p_mgmt_approvals_select ON public.management_approvals FOR SELECT TO authenticated
  USING (requested_by = public.current_user_person_id() OR public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_mgmt_approvals_insert ON public.management_approvals FOR INSERT TO authenticated
  WITH CHECK (requested_by = public.current_user_person_id() AND public.current_user_has_property_access(property_id, 4));
CREATE POLICY p_mgmt_approvals_update ON public.management_approvals FOR UPDATE TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_mgmt_approvals_delete ON public.management_approvals FOR DELETE TO authenticated
  USING (public.current_user_has_property_access(property_id, 1));

-- 34. audit_logs (Strictly Appended via Security Definer Function; Direct Insert/Update/Delete Forbidden)
CREATE POLICY p_audit_logs_select ON public.audit_logs FOR SELECT TO authenticated
  USING (public.current_user_has_property_access(property_id, 2));
CREATE POLICY p_audit_logs_insert ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (false); -- Direct inserts blocked; must call public.append_audit_log()
CREATE POLICY p_audit_logs_update ON public.audit_logs FOR UPDATE TO authenticated
  USING (false);
CREATE POLICY p_audit_logs_delete ON public.audit_logs FOR DELETE TO authenticated
  USING (false);

-- 35. system_notifications
CREATE POLICY p_notifications_select ON public.system_notifications FOR SELECT TO authenticated
  USING (recipient_person_id = public.current_user_person_id());
CREATE POLICY p_notifications_insert ON public.system_notifications FOR INSERT TO authenticated
  WITH CHECK (public.current_user_has_property_access(property_id, 3));
CREATE POLICY p_notifications_update ON public.system_notifications FOR UPDATE TO authenticated
  USING (recipient_person_id = public.current_user_person_id());
CREATE POLICY p_notifications_delete ON public.system_notifications FOR DELETE TO authenticated
  USING (recipient_person_id = public.current_user_person_id());
