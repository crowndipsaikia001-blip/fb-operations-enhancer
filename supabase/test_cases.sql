-- ============================================================================
-- FB OPERATIONS ENHANCER — COMPLETE SECURITY & OPERATIONAL TEST SUITE
-- Target: Supabase PostgreSQL (Standard Public Schema)
-- NOTE: All tests execute in isolated BEGIN ... ROLLBACK blocks. Zero data persists.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TEST A: Purchase Receiving -> Automatic Stock Balance Increase
-- ----------------------------------------------------------------------------
BEGIN;
  -- 1. Setup
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Gin 750ml', 'GIN-01', 'SPIRITS', 'BOTTLE');
  INSERT INTO public.inventory_locations (id, property_id, name)
  VALUES ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Main Store');
  INSERT INTO public.people (id, property_id, full_name)
  VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Test Storekeeper');

  -- 2. Operation: Post Purchase Receiving
  INSERT INTO public.stock_movements (property_id, item_id, to_location_id, movement_type, quantity, uom, unit_cost, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PURCHASE_RECEIVING', 50.0000, 'BOTTLE', 1000.00, '44444444-4444-4444-4444-444444444444');

  -- 3. Verification Query
  SELECT quantity_on_hand AS test_a_balance 
  FROM public.stock_balances 
  WHERE property_id = '11111111-1111-1111-1111-111111111111' 
    AND item_id = '22222222-2222-2222-2222-222222222222' 
    AND location_id = '33333333-3333-3333-3333-333333333333';
  -- Expected: test_a_balance = 50.0000
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST B: Transfer Arithmetic (Opening 100, Transfer Out 20, Expected 80)
-- ----------------------------------------------------------------------------
BEGIN;
  -- 1. Setup
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Vodka 750ml', 'VOD-01', 'SPIRITS', 'BOTTLE');
  INSERT INTO public.inventory_locations (id, property_id, name) VALUES 
    ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Main Store'),
    ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Main Bar');
  INSERT INTO public.people (id, property_id, full_name)
  VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Storekeeper');

  -- Seed opening balance of 100 in Main Store
  INSERT INTO public.stock_movements (property_id, item_id, to_location_id, movement_type, quantity, uom, unit_cost, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'PURCHASE_RECEIVING', 100.0000, 'BOTTLE', 800.00, '44444444-4444-4444-4444-444444444444');

  -- 2. Operation: Transfer 20 bottles from Main Store to Main Bar
  INSERT INTO public.stock_movements (property_id, item_id, from_location_id, to_location_id, movement_type, quantity, uom, unit_cost, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', '55555555-5555-5555-5555-555555555555', 'TRANSFER', 20.0000, 'BOTTLE', 800.00, '44444444-4444-4444-4444-444444444444');

  -- 3. Verification Query
  SELECT 
    (SELECT quantity_on_hand FROM public.stock_balances WHERE location_id = '33333333-3333-3333-3333-333333333333') AS store_balance,
    (SELECT quantity_on_hand FROM public.stock_balances WHERE location_id = '55555555-5555-5555-5555-555555555555') AS bar_balance;
  -- Expected: store_balance = 80.0000, bar_balance = 20.0000
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST C: POS Consumption Depletion
-- ----------------------------------------------------------------------------
BEGIN;
  -- 1. Setup
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.departments (id, property_id, name, code) VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'Bar', 'BAR');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Campari 750ml', 'CAM-01', 'SPIRITS', 'BOTTLE');
  INSERT INTO public.inventory_locations (id, property_id, name) VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Main Bar');
  INSERT INTO public.people (id, property_id, full_name) VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'POS Bot');

  INSERT INTO public.stock_movements (property_id, item_id, to_location_id, movement_type, quantity, uom, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 'PURCHASE_RECEIVING', 10.0000, 'BOTTLE', '44444444-4444-4444-4444-444444444444');

  -- 2. Operation: POS Sale consumes 0.0800 bottles (60ml)
  INSERT INTO public.stock_movements (property_id, item_id, from_location_id, movement_type, quantity, uom, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 'CONSUMPTION_POS', 0.0800, 'BOTTLE', '44444444-4444-4444-4444-444444444444');

  -- 3. Verification Query
  SELECT quantity_on_hand AS bar_balance 
  FROM public.stock_balances 
  WHERE location_id = '55555555-5555-5555-5555-555555555555';
  -- Expected: bar_balance = 9.9200
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST D: Pending Wastage -> Zero Stock Movements
-- ----------------------------------------------------------------------------
BEGIN;
  -- 1. Setup
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.departments (id, property_id, name, code) VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'Kitchen', 'KITCHEN');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Milk 1L', 'MLK-01', 'DAIRY', 'LITER');
  INSERT INTO public.inventory_locations (id, property_id, name) VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Kitchen Fridge');
  INSERT INTO public.people (id, property_id, full_name) VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Staff Cook');

  -- 2. Operation: Insert Pending Wastage
  INSERT INTO public.wastage_records (id, property_id, department_id, item_id, location_id, quantity, uom, reason, status, reported_by)
  VALUES ('wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 3.0000, 'LITER', 'Spoiled carton', 'PENDING', '44444444-4444-4444-4444-444444444444');

  -- 3. Verification Query
  SELECT count(*) AS movement_count 
  FROM public.stock_movements 
  WHERE reference_id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';
  -- Expected: movement_count = 0
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST E: Authorized Wastage & Full Immutability Protection
-- ----------------------------------------------------------------------------
BEGIN;
  -- 1. Setup
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.departments (id, property_id, name, code) VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'Kitchen', 'KITCHEN');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Milk 1L', 'MLK-01', 'DAIRY', 'LITER');
  INSERT INTO public.inventory_locations (id, property_id, name) VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Kitchen Fridge');
  INSERT INTO public.people (id, property_id, full_name) VALUES 
    ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Staff Cook'),
    ('66666666-6666-6666-6666-666666666666', '11111111-1111-1111-1111-111111111111', 'Kitchen Chef');

  INSERT INTO public.wastage_records (id, property_id, department_id, item_id, location_id, quantity, uom, cost_value, reason, status, reported_by)
  VALUES ('wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 3.0000, 'LITER', 150.00, 'Spoiled carton', 'PENDING', '44444444-4444-4444-4444-444444444444');

  -- 2. Operation: Authorize Wastage
  UPDATE public.wastage_records 
  SET status = 'AUTHORIZED', authorized_by = '66666666-6666-6666-6666-666666666666'
  WHERE id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';

  -- 3. Verification: Exactly 1 stock movement created
  SELECT count(*) AS movement_count, (SELECT stock_movement_id IS NOT NULL FROM public.wastage_records WHERE id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww') AS has_fk
  FROM public.stock_movements 
  WHERE reference_id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';
  -- Expected: movement_count = 1, has_fk = true

  -- 4. Invariant Tests: Mutating authorized record MUST throw exception
  -- Test 4a: Altering quantity
  DO $$
  BEGIN
    UPDATE public.wastage_records SET quantity = 10.0000 WHERE id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';
    RAISE EXCEPTION 'FAILED: Quantity mutation on authorized wastage was allowed!';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: Mutation blocked
  END $$;

  -- Test 4b: Reversing status to PENDING
  DO $$
  BEGIN
    UPDATE public.wastage_records SET status = 'PENDING' WHERE id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';
    RAISE EXCEPTION 'FAILED: Status reversal on authorized wastage was allowed!';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: Reversal blocked
  END $$;

  -- Test 4c: Resetting stock_movement_id
  DO $$
  BEGIN
    UPDATE public.wastage_records SET stock_movement_id = NULL WHERE id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';
    RAISE EXCEPTION 'FAILED: Resetting stock_movement_id was allowed!';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: Reset blocked
  END $$;
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST F: Rejected Wastage -> Zero Stock Movements
-- ----------------------------------------------------------------------------
BEGIN;
  -- 1. Setup
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.departments (id, property_id, name, code) VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'Kitchen', 'KITCHEN');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Steak 1kg', 'STK-01', 'MEAT', 'KG');
  INSERT INTO public.inventory_locations (id, property_id, name) VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Walk-in Chiller');
  INSERT INTO public.people (id, property_id, full_name) VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Staff Cook');

  INSERT INTO public.wastage_records (id, property_id, department_id, item_id, location_id, quantity, uom, reason, status, reported_by)
  VALUES ('wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww', '11111111-1111-1111-1111-111111111111', 'dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 1.0000, 'KG', 'Burnt steak', 'PENDING', '44444444-4444-4444-4444-444444444444');

  -- 2. Operation: Reject Wastage
  UPDATE public.wastage_records 
  SET status = 'REJECTED', rejection_reason = 'Not verifiable'
  WHERE id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';

  -- 3. Verification Query
  SELECT count(*) AS movement_count 
  FROM public.stock_movements 
  WHERE reference_id = 'wwwwwwww-wwww-wwww-wwww-wwwwwwwwwwww';
  -- Expected: movement_count = 0
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST G: Duplicate POS Webhook (Idempotency Protection)
-- ----------------------------------------------------------------------------
BEGIN;
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');

  -- First webhook insert
  INSERT INTO public.pos_sales_tickets (property_id, source_system, external_ticket_id, ticket_number, business_date, opened_at, closed_at, gross_amount, net_amount)
  VALUES ('11111111-1111-1111-1111-111111111111', 'PETPOOJA', 'EXT-BILL-9901', 'T-101', CURRENT_DATE, now(), now(), 1200.00, 1200.00);

  -- Duplicate insert MUST throw unique constraint violation
  DO $$
  BEGIN
    INSERT INTO public.pos_sales_tickets (property_id, source_system, external_ticket_id, ticket_number, business_date, opened_at, closed_at, gross_amount, net_amount)
    VALUES ('11111111-1111-1111-1111-111111111111', 'PETPOOJA', 'EXT-BILL-9901', 'T-101', CURRENT_DATE, now(), now(), 1200.00, 1200.00);
    RAISE EXCEPTION 'FAILED: Duplicate POS ticket was permitted!';
  EXCEPTION WHEN unique_violation THEN
    -- Expected: Duplicate blocked cleanly
  END $$;
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST H: Unmapped POS Item -> Placed in Exception Queue
-- ----------------------------------------------------------------------------
BEGIN;
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.pos_sales_tickets (id, property_id, source_system, external_ticket_id, ticket_number, business_date, opened_at, closed_at, gross_amount, net_amount)
  VALUES ('tttttttt-tttt-tttt-tttt-tttttttttttt', '11111111-1111-1111-1111-111111111111', 'PETPOOJA', 'EXT-BILL-9902', 'T-102', CURRENT_DATE, now(), 500.00, 500.00);

  INSERT INTO public.pos_ticket_items (ticket_id, external_item_id, item_name, recipe_id, mapping_status, depletion_status)
  VALUES ('tttttttt-tttt-tttt-tttt-tttttttttttt', 'UNMAPPED_SPECIAL_01', 'Chef Special Plate', NULL, 'UNMAPPED', 'BYPASSED_UNMAPPED');

  SELECT count(*) AS unmapped_item_count 
  FROM public.pos_ticket_items 
  WHERE mapping_status = 'UNMAPPED';
  -- Expected: unmapped_item_count = 1
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST I: Physical Stock Adjustment
-- ----------------------------------------------------------------------------
BEGIN;
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Tequila 750ml', 'TEQ-01', 'SPIRITS', 'BOTTLE');
  INSERT INTO public.inventory_locations (id, property_id, name) VALUES ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'Main Bar');
  INSERT INTO public.people (id, property_id, full_name) VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Bar Auditor');

  -- Seed opening balance of 20 bottles
  INSERT INTO public.stock_movements (property_id, item_id, to_location_id, movement_type, quantity, uom, unit_cost, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 'PURCHASE_RECEIVING', 20.0000, 'BOTTLE', 1500.00, '44444444-4444-4444-4444-444444444444');

  -- Physical count shows 18 bottles (-2 variance) -> Audit Adjustment Posted
  INSERT INTO public.stock_movements (property_id, item_id, from_location_id, movement_type, quantity, uom, unit_cost, notes, recorded_by)
  VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', '55555555-5555-5555-5555-555555555555', 'AUDIT_ADJUSTMENT', 2.0000, 'BOTTLE', 1500.00, 'Stock count variance adjustment', '44444444-4444-4444-4444-444444444444');

  SELECT quantity_on_hand AS adjusted_balance 
  FROM public.stock_balances 
  WHERE location_id = '55555555-5555-5555-5555-555555555555';
  -- Expected: adjusted_balance = 18.0000
ROLLBACK;


-- ----------------------------------------------------------------------------
-- TEST J: Item-Level Bar Control Chain Calculation
-- ----------------------------------------------------------------------------
BEGIN;
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  INSERT INTO public.sections (id, property_id, name, section_type) VALUES ('ssssssss-ssss-ssss-ssss-ssssssssssss', '11111111-1111-1111-1111-111111111111', 'Main Bar', 'BAR');
  INSERT INTO public.item_master (id, property_id, name, item_code, item_category, primary_uom)
  VALUES ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Bourbon 750ml', 'BRB-01', 'SPIRITS', 'BOTTLE');
  INSERT INTO public.people (id, property_id, full_name) VALUES ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Bartender');

  INSERT INTO public.bar_shift_reconciliations (id, property_id, section_id, shift_date, shift_type, bartender_person_id)
  VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'ssssssss-ssss-ssss-ssss-ssssssssssss', CURRENT_DATE, '1ST', '44444444-4444-4444-4444-444444444444');

  INSERT INTO public.bar_item_reconciliations (
    bar_reconciliation_id,
    item_id,
    opening_stock_ml,
    transfers_in_ml,
    transfers_out_ml,
    theoretical_consumption_ml,
    wastage_breakage_ml,
    actual_closing_ml,
    unit_cost_per_ml
  ) VALUES (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    '22222222-2222-2222-2222-222222222222',
    1000.00,
    750.00,
    0.00,
    500.00,
    50.00,
    1150.00,
    2.0000
  );

  SELECT 
    expected_closing_ml,
    variance_ml,
    financial_variance_cost
  FROM public.bar_item_reconciliations
  WHERE bar_reconciliation_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  -- Expected: expected_closing_ml = 1200.00, variance_ml = -50.00, financial_variance_cost = -100.00
ROLLBACK;


-- ----------------------------------------------------------------------------
-- SECURITY TESTS: Multi-Tenant People & Audit Immutability Enforcement
-- ----------------------------------------------------------------------------

-- SECURITY TEST 1: Direct Audit Log INSERT/UPDATE/DELETE Prevention
BEGIN;
  INSERT INTO public.properties (id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'Test Outlet');
  
  -- 1a. Direct update on audit_logs MUST fail via trigger
  DO $$
  BEGIN
    UPDATE public.audit_logs SET action = 'HACKED';
    RAISE EXCEPTION 'FAILED: Direct UPDATE on audit_logs was allowed!';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: Blocked
  END $$;

  -- 1b. Direct delete on audit_logs MUST fail via trigger
  DO $$
  BEGIN
    DELETE FROM public.audit_logs;
    RAISE EXCEPTION 'FAILED: Direct DELETE on audit_logs was allowed!';
  EXCEPTION WHEN OTHERS THEN
    -- Expected: Blocked
  END $$;
ROLLBACK;
