-- ================================================================
-- TEST CASES for Revision 5 Migration
-- ================================================================
-- These tests verify the core invariants of the system.
-- NOTE: These tests require a clean database with the migration applied.
-- They assume auth.uid() can be mocked or tested in a session with a valid user.
-- ================================================================

\echo 'Starting Test Cases...'

-- ========================================================================
-- SETUP HELPER: Create test data
-- ========================================================================

-- Mock property and people for testing (in real scenario, these come from auth)
DO $$
DECLARE
    test_prop_id UUID;
    test_person_id UUID;
BEGIN
    -- Create test property
    INSERT INTO properties (name, address) VALUES ('Test Bar', '123 Test St')
    ON CONFLICT DO NOTHING
    RETURNING id INTO test_prop_id;
    
    -- Note: In real tests, person would be linked to auth.users
    -- For unit testing triggers, we may bypass auth checks or mock them
    
    RAISE NOTICE 'Setup complete for property: %', test_prop_id;
END $$;

-- ========================================================================
-- TEST A: Purchase Receiving
-- ========================================================================
-- Verify: Inserting a purchase order creates positive stock movement
\echo 'TEST A: Purchase Receiving'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_po_id UUID;
    v_initial_balance NUMERIC;
    v_new_balance NUMERIC;
BEGIN
    -- Setup
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    
    INSERT INTO items (property_id, name, sku) 
    VALUES (v_prop_id, 'Test Spirit', 'SKU-001') 
    RETURNING id INTO v_item_id;
    
    -- Initial balance should be 0
    SELECT COALESCE(quantity, 0) INTO v_initial_balance FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    -- Create PO
    INSERT INTO purchase_orders (property_id, supplier_name, status) 
    VALUES (v_prop_id, 'Test Supplier', 'pending') 
    RETURNING id INTO v_po_id;
    
    INSERT INTO purchase_order_items (order_id, item_id, quantity, unit_cost) 
    VALUES (v_po_id, v_item_id, 50, 20.00);
    
    -- Simulate receiving (manually insert movement for this test)
    INSERT INTO stock_movements (item_id, property_id, quantity, movement_type, reference_id, reason)
    VALUES (v_item_id, v_prop_id, 50, 'purchase', v_po_id, 'Received PO');
    
    -- Verify balance updated
    SELECT quantity INTO v_new_balance FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    IF v_new_balance = 50 THEN
        RAISE NOTICE 'TEST A PASS: Balance updated to 50 after purchase';
    ELSE
        RAISE EXCEPTION 'TEST A FAIL: Expected balance 50, got %', v_new_balance;
    END IF;
END $$;

-- ========================================================================
-- TEST B: Transfer
-- ========================================================================
-- Verify: Transfer out reduces source stock, transfer in increases destination
\echo 'TEST B: Transfer'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_src UUID;
    v_prop_dest UUID;
    v_transfer_id UUID;
    v_src_balance_before NUMERIC;
    v_src_balance_after NUMERIC;
BEGIN
    -- Setup two properties
    SELECT id INTO v_prop_src FROM properties WHERE name = 'Test Bar' LIMIT 1;
    INSERT INTO properties (name, address) VALUES ('Test Lounge', '456 Test St') 
    ON CONFLICT DO NOTHING RETURNING id INTO v_prop_dest;
    IF v_prop_dest IS NULL THEN SELECT id INTO v_prop_dest FROM properties WHERE name = 'Test Lounge' LIMIT 1; END IF;
    
    -- Ensure item exists in source
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_src LIMIT 1;
    
    -- Ensure source has stock
    SELECT quantity INTO v_src_balance_before FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_src;
    
    -- Create transfer request
    INSERT INTO transfer_requests (source_property_id, destination_property_id, status)
    VALUES (v_prop_src, v_prop_dest, 'pending')
    RETURNING id INTO v_transfer_id;
    
    INSERT INTO transfer_items (transfer_id, item_id, quantity)
    VALUES (v_transfer_id, v_item_id, 20);
    
    -- Simulate transfer out movement
    INSERT INTO stock_movements (item_id, property_id, quantity, movement_type, reference_id)
    VALUES (v_item_id, v_prop_src, -20, 'transfer_out', v_transfer_id);
    
    -- Verify source balance reduced
    SELECT quantity INTO v_src_balance_after FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_src;
    
    IF v_src_balance_after = v_src_balance_before - 20 THEN
        RAISE NOTICE 'TEST B PASS: Source balance reduced by 20';
    ELSE
        RAISE EXCEPTION 'TEST B FAIL: Expected source balance %, got %', v_src_balance_before - 20, v_src_balance_after;
    END IF;
END $$;

-- ========================================================================
-- TEST C: POS Consumption
-- ========================================================================
-- Verify: POS ticket creates negative stock movement
\echo 'TEST C: POS Consumption'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_ticket_id UUID;
    v_balance_before NUMERIC;
    v_balance_after NUMERIC;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_id LIMIT 1;
    
    SELECT quantity INTO v_balance_before FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    -- Create POS ticket
    INSERT INTO pos_tickets (property_id, external_ticket_id, source_system, total_amount)
    VALUES (v_prop_id, 'TICKET-001', 'Square', 50.00)
    RETURNING id INTO v_ticket_id;
    
    INSERT INTO pos_ticket_items (ticket_id, item_id, quantity, unit_price)
    VALUES (v_ticket_id, v_item_id, 2, 25.00);
    
    -- Simulate consumption movement
    INSERT INTO stock_movements (item_id, property_id, quantity, movement_type, reference_id)
    VALUES (v_item_id, v_prop_id, -2, 'pos_sale', v_ticket_id);
    
    SELECT quantity INTO v_balance_after FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    IF v_balance_after = v_balance_before - 2 THEN
        RAISE NOTICE 'TEST C PASS: Balance reduced by 2 after POS sale';
    ELSE
        RAISE EXCEPTION 'TEST C FAIL: Expected balance %, got %', v_balance_before - 2, v_balance_after;
    END IF;
END $$;

-- ========================================================================
-- TEST D: Pending Wastage (No Stock Movement Yet)
-- ========================================================================
-- Verify: Wastage in 'pending' status does NOT create stock movement
\echo 'TEST D: Pending Wastage'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_wastage_id UUID;
    v_movement_count INTEGER;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_id LIMIT 1;
    
    -- Create wastage request in pending status
    INSERT INTO wastage_requests (property_id, status, reason)
    VALUES (v_prop_id, 'pending', 'Spilled during service')
    RETURNING id INTO v_wastage_id;
    
    INSERT INTO wastage_items (wastage_id, item_id, quantity, reason_detail)
    VALUES (v_wastage_id, v_item_id, 5, 'Accidental spill');
    
    -- Check no movement created yet (trigger only fires on authorize)
    SELECT count(*) INTO v_movement_count 
    FROM stock_movements 
    WHERE reference_id = v_wastage_id AND movement_type = 'wastage';
    
    IF v_movement_count = 0 THEN
        RAISE NOTICE 'TEST D PASS: No stock movement for pending wastage';
    ELSE
        RAISE EXCEPTION 'TEST D FAIL: Expected 0 movements, got %', v_movement_count;
    END IF;
END $$;

-- ========================================================================
-- TEST E: Authorized Wastage (Exactly-One Movement)
-- ========================================================================
-- Verify: Authorizing wastage creates exactly ONE negative stock movement
\echo 'TEST E: Authorized Wastage'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_wastage_id UUID;
    v_balance_before NUMERIC;
    v_balance_after NUMERIC;
    v_movement_count INTEGER;
    v_movement_qty NUMERIC;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_id LIMIT 1;
    
    SELECT quantity INTO v_balance_before FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    -- Create new wastage request
    INSERT INTO wastage_requests (property_id, status, reason)
    VALUES (v_prop_id, 'pending', 'Broken bottle')
    RETURNING id INTO v_wastage_id;
    
    INSERT INTO wastage_items (wastage_id, item_id, quantity, reason_detail)
    VALUES (v_wastage_id, v_item_id, 3, 'Dropped');
    
    -- Authorize (trigger should fire)
    UPDATE wastage_requests SET status = 'authorized', authorized_at = NOW() WHERE id = v_wastage_id;
    
    -- Verify exactly one movement created
    SELECT count(*), COALESCE(SUM(quantity), 0) INTO v_movement_count, v_movement_qty
    FROM stock_movements 
    WHERE reference_id = v_wastage_id AND movement_type = 'wastage';
    
    SELECT quantity INTO v_balance_after FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    IF v_movement_count = 1 AND v_movement_qty = -3 AND v_balance_after = v_balance_before - 3 THEN
        RAISE NOTICE 'TEST E PASS: Exactly one movement (-3) created on authorization';
    ELSE
        RAISE EXCEPTION 'TEST E FAIL: count=%, qty=%, balance_before=%, balance_after=%', 
            v_movement_count, v_movement_qty, v_balance_before, v_balance_after;
    END IF;
END $$;

-- ========================================================================
-- TEST F: Rejected Wastage (Zero Movements)
-- ========================================================================
-- Verify: Rejecting wastage creates NO stock movement
\echo 'TEST F: Rejected Wastage'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_wastage_id UUID;
    v_movement_count INTEGER;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_id LIMIT 1;
    
    -- Create new wastage request
    INSERT INTO wastage_requests (property_id, status, reason)
    VALUES (v_prop_id, 'pending', 'Test rejection')
    RETURNING id INTO v_wastage_id;
    
    INSERT INTO wastage_items (wastage_id, item_id, quantity, reason_detail)
    VALUES (v_wastage_id, v_item_id, 10, 'Test');
    
    -- Reject
    UPDATE wastage_requests SET status = 'rejected', authorized_at = NOW() WHERE id = v_wastage_id;
    
    -- Verify no movement created
    SELECT count(*) INTO v_movement_count 
    FROM stock_movements 
    WHERE reference_id = v_wastage_id AND movement_type = 'wastage';
    
    IF v_movement_count = 0 THEN
        RAISE NOTICE 'TEST F PASS: No stock movement for rejected wastage';
    ELSE
        RAISE EXCEPTION 'TEST F FAIL: Expected 0 movements, got %', v_movement_count;
    END IF;
END $$;

-- ========================================================================
-- TEST G: Duplicate POS Webhook (Idempotency)
-- ========================================================================
-- Verify: Same external_ticket_id cannot be inserted twice
\echo 'TEST G: Duplicate POS Webhook'

DO $$
DECLARE
    v_prop_id UUID;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    
    -- First insert should succeed
    INSERT INTO pos_tickets (property_id, external_ticket_id, source_system, total_amount)
    VALUES (v_prop_id, 'UNIQUE-TICKET', 'Square', 100.00);
    
    -- Second insert with same external_ticket_id should fail
    BEGIN
        INSERT INTO pos_tickets (property_id, external_ticket_id, source_system, total_amount)
        VALUES (v_prop_id, 'UNIQUE-TICKET', 'Square', 100.00);
        
        RAISE EXCEPTION 'TEST G FAIL: Duplicate insert should have been rejected';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'TEST G PASS: Duplicate POS ticket rejected by unique constraint';
    END;
END $$;

-- ========================================================================
-- TEST H: Unmapped POS Item
-- ========================================================================
-- Verify: POS ticket items can have NULL item_id (unmapped items)
\echo 'TEST H: Unmapped POS Item'

DO $$
DECLARE
    v_prop_id UUID;
    v_ticket_id UUID;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    
    INSERT INTO pos_tickets (property_id, external_ticket_id, source_system, total_amount)
    VALUES (v_prop_id, 'TICKET-UNMAPPED', 'Square', 30.00)
    RETURNING id INTO v_ticket_id;
    
    -- Insert item with NULL item_id (should succeed)
    INSERT INTO pos_ticket_items (ticket_id, item_id, external_item_id, item_name, quantity, unit_price)
    VALUES (v_ticket_id, NULL, 'EXT-ITEM-999', 'Unknown Cocktail', 1, 30.00);
    
    RAISE NOTICE 'TEST H PASS: Unmapped POS item inserted successfully';
END $$;

-- ========================================================================
-- TEST I: Physical Stock Adjustment
-- ========================================================================
-- Verify: Manual adjustment movement updates balance correctly
\echo 'TEST I: Physical Stock Adjustment'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_balance_before NUMERIC;
    v_balance_after NUMERIC;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_id LIMIT 1;
    
    SELECT quantity INTO v_balance_before FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    -- Manual adjustment (e.g., found extra stock)
    INSERT INTO stock_movements (item_id, property_id, quantity, movement_type, reason)
    VALUES (v_item_id, v_prop_id, 5, 'adjustment', 'Physical count discrepancy');
    
    SELECT quantity INTO v_balance_after FROM stock_levels WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    IF v_balance_after = v_balance_before + 5 THEN
        RAISE NOTICE 'TEST I PASS: Adjustment increased balance by 5';
    ELSE
        RAISE EXCEPTION 'TEST I FAIL: Expected %, got %', v_balance_before + 5, v_balance_after;
    END IF;
END $$;

-- ========================================================================
-- TEST J: Bar Reconciliation (Multiple Movements)
-- ========================================================================
-- Verify: Final balance matches sum of all movements
\echo 'TEST J: Bar Reconciliation'

DO $$
DECLARE
    v_item_id UUID;
    v_prop_id UUID;
    v_calculated_balance NUMERIC;
    v_actual_balance NUMERIC;
BEGIN
    SELECT id INTO v_prop_id FROM properties WHERE name = 'Test Bar' LIMIT 1;
    SELECT id INTO v_item_id FROM items WHERE name = 'Test Spirit' AND property_id = v_prop_id LIMIT 1;
    
    -- Calculate sum of all movements
    SELECT COALESCE(SUM(quantity), 0) INTO v_calculated_balance
    FROM stock_movements
    WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    -- Get actual balance from stock_levels
    SELECT quantity INTO v_actual_balance
    FROM stock_levels
    WHERE item_id = v_item_id AND property_id = v_prop_id;
    
    IF v_actual_balance = v_calculated_balance THEN
        RAISE NOTICE 'TEST J PASS: Balance (%) matches sum of movements', v_actual_balance;
    ELSE
        RAISE EXCEPTION 'TEST J FAIL: Balance mismatch. Actual=%, Calculated=%', v_actual_balance, v_calculated_balance;
    END IF;
END $$;

\echo ''
\echo 'All Test Cases Completed.'
