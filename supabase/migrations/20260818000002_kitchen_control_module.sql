-- ============================================================================
-- MODULE 2: KITCHEN CONTROL
-- Features: Receiving, Yield Management, Recipe Costing, Production Logs
-- ============================================================================

-- -----------------------------------------------------------------------------
-- PHASE 1: KITCHEN TABLES
-- -----------------------------------------------------------------------------

-- Supplier Receivings (Detailed receiving with quality checks)
CREATE TABLE supplier_receivings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id),
    purchase_order_id UUID REFERENCES purchase_orders(id),
    supplier_name TEXT NOT NULL,
    invoice_number TEXT,
    received_date TIMESTAMPTZ DEFAULT NOW(),
    received_by UUID REFERENCES people(id),
    
    -- Item Details
    item_id UUID REFERENCES items(id),
    ordered_qty NUMERIC(12,4),
    received_qty NUMERIC(12,4) NOT NULL,
    accepted_qty NUMERIC(12,4) NOT NULL,
    rejected_qty NUMERIC(12,4) DEFAULT 0,
    
    -- Quality & Safety
    unit_cost NUMERIC(12,2),
    total_cost NUMERIC(12,2),
    expiry_date DATE,
    batch_number TEXT,
    temperature_at_receiving NUMERIC(5,2), -- For cold chain items
    quality_status TEXT DEFAULT 'accepted', -- 'accepted', 'rejected', 'partial'
    rejection_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Yield Tests (Trim loss, cooking loss, usable yield)
CREATE TABLE yield_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id),
    item_id UUID NOT NULL REFERENCES items(id),
    test_date TIMESTAMPTZ DEFAULT NOW(),
    performed_by UUID REFERENCES people(id),
    
    -- Weights
    raw_weight NUMERIC(12,4) NOT NULL,
    trim_loss_weight NUMERIC(12,4) DEFAULT 0,
    cooking_loss_weight NUMERIC(12,4) DEFAULT 0,
    usable_yield_weight NUMERIC(12,4) NOT NULL,
    
    -- Calculations (auto-computed via trigger or app)
    yield_percent NUMERIC(6,2),
    trim_loss_percent NUMERIC(6,2),
    cooking_loss_percent NUMERIC(6,2),
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Production Logs (Daily production records)
CREATE TABLE production_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id),
    production_date DATE DEFAULT CURRENT_DATE,
    shift TEXT DEFAULT 'day', -- 'day', 'evening', 'night'
    department department_type NOT NULL DEFAULT 'kitchen',
    produced_by UUID REFERENCES people(id),
    
    -- What was produced
    item_id UUID NOT NULL REFERENCES items(id), -- Finished product
    recipe_id UUID, -- Link to future recipes table if needed
    quantity_produced NUMERIC(12,4) NOT NULL,
    unit_of_measure TEXT NOT NULL,
    
    -- Ingredients used (summary or link to detailed log)
    ingredients_used JSONB, -- {"item_id": "qty", ...}
    
    -- Quality metrics
    portions_expected NUMERIC(12,4),
    portions_actual NUMERIC(12,4),
    portion_variance NUMERIC(12,4),
    
    status TEXT DEFAULT 'completed', -- 'planned', 'in_progress', 'completed', 'cancelled'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Kitchen Wastage Categories (Standardized reasons)
CREATE TABLE kitchen_wastage_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id),
    name TEXT NOT NULL, -- 'Preparation Waste', 'Cooking Waste', 'Spoilage', etc.
    category_group TEXT NOT NULL, -- 'process', 'quality', 'safety', 'other'
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(property_id, name)
);

-- Food Safety Checks (Temperature logs, hygiene audits)
CREATE TABLE food_safety_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id),
    check_date TIMESTAMPTZ DEFAULT NOW(),
    check_type TEXT NOT NULL, -- 'temperature', 'hygiene', 'expiry', 'storage'
    performed_by UUID REFERENCES people(id),
    
    -- Location/Equipment
    location TEXT NOT NULL, -- 'walkin_cooler', 'freezer_1', 'dry_store', etc.
    equipment_id UUID REFERENCES items(id), -- Optional: specific equipment
    
    -- Measurements
    temperature_reading NUMERIC(5,2),
    expected_temp_min NUMERIC(5,2),
    expected_temp_max NUMERIC(5,2),
    
    -- Compliance
    is_compliant BOOLEAN,
    violation_details TEXT,
    corrective_action TEXT,
    
    -- Hygiene checklist (JSON for flexibility)
    checklist_results JSONB, -- {"hand_wash": true, "surfaces_clean": true, ...}
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE supplier_receivings ENABLE ROW LEVEL SECURITY;
ALTER TABLE yield_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_wastage_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_safety_checks ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- PHASE 2: KITCHEN RLS POLICIES
-- -----------------------------------------------------------------------------

-- Helper: Get current person's property access
CREATE OR REPLACE FUNCTION kitchen_has_access(req_property_id UUID) RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM property_memberships pm
        WHERE pm.property_id = req_property_id
        AND pm.person_id = (SELECT id FROM people WHERE auth_id = auth.uid())
    );
$$ LANGUAGE SQL SECURITY DEFINER STABLE SET search_path = public, pg_temp;

-- Supplier Receivings Policies
CREATE POLICY "Staff view receivings" ON supplier_receivings FOR SELECT 
    USING (kitchen_has_access(property_id));

CREATE POLICY "Managers create receivings" ON supplier_receivings FOR INSERT 
    WITH CHECK (kitchen_has_access(property_id) AND has_authority('manager'));

CREATE POLICY "Managers update receivings" ON supplier_receivings FOR UPDATE 
    USING (kitchen_has_access(property_id) AND has_authority('manager'));

-- Yield Tests Policies
CREATE POLICY "Staff view yield tests" ON yield_tests FOR SELECT 
    USING (kitchen_has_access(property_id));

CREATE POLICY "Managers create yield tests" ON yield_tests FOR INSERT 
    WITH CHECK (kitchen_has_access(property_id) AND has_authority('manager'));

-- Production Logs Policies
CREATE POLICY "Staff view production" ON production_logs FOR SELECT 
    USING (kitchen_has_access(property_id));

CREATE POLICY "Staff create production" ON production_logs FOR INSERT 
    WITH CHECK (kitchen_has_access(property_id));

CREATE POLICY "Managers update production" ON production_logs FOR UPDATE 
    USING (kitchen_has_access(property_id) AND has_authority('manager'));

-- Wastage Categories Policies
CREATE POLICY "Staff view wastage categories" ON kitchen_wastage_categories FOR SELECT 
    USING (kitchen_has_access(property_id));

CREATE POLICY "Admins manage wastage categories" ON kitchen_wastage_categories FOR ALL 
    USING (kitchen_has_access(property_id) AND has_authority('admin'));

-- Food Safety Checks Policies
CREATE POLICY "Staff view safety checks" ON food_safety_checks FOR SELECT 
    USING (kitchen_has_access(property_id));

CREATE POLICY "Staff create safety checks" ON food_safety_checks FOR INSERT 
    WITH CHECK (kitchen_has_access(property_id));

CREATE POLICY "Managers update safety checks" ON food_safety_checks FOR UPDATE 
    USING (kitchen_has_access(property_id) AND has_authority('manager'));

-- -----------------------------------------------------------------------------
-- PHASE 3: KITCHEN VIEWS & REPORTS
-- -----------------------------------------------------------------------------

-- Yield Performance View
CREATE OR REPLACE VIEW kitchen_yield_report AS
SELECT 
    yt.id,
    p.name as property_name,
    i.name as item_name,
    i.category_id,
    yt.raw_weight,
    yt.trim_loss_weight,
    yt.cooking_loss_weight,
    yt.usable_yield_weight,
    yt.yield_percent,
    yt.test_date,
    per.full_name as tested_by,
    CASE 
        WHEN yt.yield_percent < 70 THEN '🔴 Critical'
        WHEN yt.yield_percent < 80 THEN '🟠 Attention'
        ELSE '🟢 Good'
    END as yield_status
FROM yield_tests yt
JOIN properties p ON p.id = yt.property_id
JOIN items i ON i.id = yt.item_id
LEFT JOIN people per ON per.id = yt.performed_by
ORDER BY yt.test_date DESC;

-- Receiving Variance View
CREATE OR REPLACE VIEW kitchen_receiving_variance AS
SELECT 
    sr.id,
    sr.supplier_name,
    sr.invoice_number,
    sr.item_id,
    i.name as item_name,
    sr.ordered_qty,
    sr.received_qty,
    sr.accepted_qty,
    sr.rejected_qty,
    (sr.ordered_qty - sr.received_qty) as short_received_qty,
    (sr.received_qty - sr.accepted_qty) as rejected_qty,
    sr.quality_status,
    sr.rejection_reason,
    sr.received_date,
    CASE 
        WHEN sr.rejected_qty > 0 THEN '🔴 Quality Issue'
        WHEN (sr.ordered_qty - sr.received_qty) > (sr.ordered_qty * 0.1) THEN '🟠 Short Delivery'
        ELSE '🟢 OK'
    END as variance_status
FROM supplier_receivings sr
JOIN items i ON i.id = sr.item_id
ORDER BY sr.received_date DESC;

-- Daily Production Summary
CREATE OR REPLACE VIEW kitchen_daily_production AS
SELECT 
    pl.production_date,
    pl.shift,
    pl.department,
    COUNT(*) as total_productions,
    SUM(pl.quantity_produced) as total_quantity,
    SUM(pl.portions_expected) as expected_portions,
    SUM(pl.portions_actual) as actual_portions,
    SUM(pl.portions_variance) as total_variance,
    STRING_AGG(i.name, ', ') as items_produced
FROM production_logs pl
JOIN items i ON i.id = pl.item_id
GROUP BY pl.production_date, pl.shift, pl.department
ORDER BY pl.production_date DESC, pl.shift;

-- -----------------------------------------------------------------------------
-- PHASE 4: SEED DATA
-- -----------------------------------------------------------------------------

DO $$
DECLARE
    v_prop_id UUID;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE code = 'LOOP-BLR';

    -- Seed Wastage Categories
    INSERT INTO kitchen_wastage_categories (property_id, name, category_group) VALUES
    (v_prop_id, 'Preparation Waste', 'process'),
    (v_prop_id, 'Cooking Waste', 'process'),
    (v_prop_id, 'Spoilage', 'quality'),
    (v_prop_id, 'Expiry', 'quality'),
    (v_prop_id, 'Overproduction', 'process'),
    (v_prop_id, 'Returned Food', 'quality'),
    (v_prop_id, 'Burned/Damaged', 'process'),
    (v_prop_id, 'Quality Rejection', 'quality'),
    (v_prop_id, 'Staff Meal', 'other'),
    (v_prop_id, 'Pest Contamination', 'safety')
    ON CONFLICT (property_id, name) DO NOTHING;

    RAISE NOTICE '✅ Kitchen Control Module installed!';
    RAISE NOTICE '📊 Views created: kitchen_yield_report, kitchen_receiving_variance, kitchen_daily_production';
END $$;

-- -----------------------------------------------------------------------------
-- VERIFICATION
-- -----------------------------------------------------------------------------
SELECT 
    'Kitchen Module Status' as check_type,
    COUNT(*) as table_count
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('supplier_receivings', 'yield_tests', 'production_logs', 'kitchen_wastage_categories', 'food_safety_checks');
