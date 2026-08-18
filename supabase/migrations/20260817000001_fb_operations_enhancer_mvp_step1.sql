-- ============================================================================
-- LOOP Craft Bar & Kitchen - Operations Enhancer MVP (Revision 5)
-- Migration: 20260817000001_fb_operations_enhancer_mvp.sql
-- Step 1 of 5: Schema Foundation, Enums, and Core Tables
-- ============================================================================

-- Ensure clean slate for re-runs (idempotent drops)
DROP FUNCTION IF EXISTS append_audit_log CASCADE;
DROP FUNCTION IF EXISTS check_property_authorization CASCADE;
DROP FUNCTION IF EXISTS get_user_authority_level CASCADE;
DROP FUNCTION IF EXISTS process_stock_movement CASCADE;
DROP FUNCTION IF EXISTS process_wastage_authorization CASCADE;
DROP TRIGGER IF EXISTS trg_stock_balance ON stock_movements;
DROP TRIGGER IF EXISTS trg_wastage_stock_movement ON wastage_requests;
DROP TRIGGER IF EXISTS trg_audit_immutable ON audit_logs;

DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS pos_ticket_items CASCADE;
DROP TABLE IF EXISTS pos_tickets CASCADE;
DROP TABLE IF EXISTS pos_webhook_events CASCADE;
DROP TABLE IF EXISTS wastage_requests CASCADE;
DROP TABLE IF EXISTS transfer_requests CASCADE;
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS stock_levels CASCADE;
DROP TABLE IF EXISTS items CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS property_memberships CASCADE;
DROP TABLE IF EXISTS people CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- ============================================================================
-- SECTION 1: ENUMS (Authority Model & Status Types)
-- ============================================================================

-- Authority Model: Lower number = Greater privilege
-- 1 = Admin (Full system access)
-- 2 = Manager (Property-level full access)
-- 3 = Supervisor (Limited operational access)
-- 4 = Staff (Basic operational access only)
CREATE TYPE authority_level AS ENUM ('admin', 'manager', 'supervisor', 'staff');

CREATE TYPE movement_type AS ENUM ('purchase_receive', 'transfer_in', 'transfer_out', 'pos_consumption', 'wastage', 'adjustment');
CREATE TYPE wastage_status AS ENUM ('pending', 'authorized', 'rejected');
CREATE TYPE transfer_status AS ENUM ('pending', 'in_transit', 'received', 'cancelled');
CREATE TYPE purchase_status AS ENUM ('pending', 'partial', 'completed', 'cancelled');

-- ============================================================================
-- SECTION 2: CORE TABLES (Properties, People, Roles, Memberships)
-- ============================================================================

-- Properties: Multi-tenant isolation boundary
CREATE TABLE properties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT,
    timezone TEXT DEFAULT 'UTC',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Roles: System-wide role definitions
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    default_authority authority_level NOT NULL DEFAULT 'staff',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- People: User accounts with property association
-- NOTE: property_id here is informational ONLY. 
-- AUTHORIZATION is determined SOLELY by property_memberships.
CREATE TABLE people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    property_id UUID REFERENCES properties(id), -- Informational only, NOT for authz
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(auth_user_id)
);

-- Property Memberships: THE AUTHORITATIVE AUTHORIZATION RELATIONSHIP
-- This table determines who can access what property with what authority
CREATE TABLE property_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    person_id UUID NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    authority authority_level NOT NULL DEFAULT 'staff',
    granted_by UUID REFERENCES people(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    UNIQUE(property_id, person_id) WHERE revoked_at IS NULL
);

-- Indexes for authorization lookups
CREATE INDEX idx_property_memberships_person ON property_memberships(person_id);
CREATE INDEX idx_property_memberships_property ON property_memberships(property_id);
CREATE INDEX idx_property_memberships_active ON property_memberships(property_id, person_id) WHERE revoked_at IS NULL;

-- ============================================================================
-- SECTION 3: INVENTORY FOUNDATION (Categories, Items)
-- ============================================================================

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    parent_id UUID REFERENCES categories(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(property_id, name)
);

CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),
    sku TEXT,
    name TEXT NOT NULL,
    description TEXT,
    unit_of_measure TEXT NOT NULL DEFAULT 'unit',
    reorder_level DECIMAL(10,3) DEFAULT 0,
    cost_per_unit DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(property_id, sku) WHERE sku IS NOT NULL
);

CREATE INDEX idx_items_property ON items(property_id);
CREATE INDEX idx_items_category ON items(category_id);

-- ============================================================================
-- SECTION 4: STOCK MANAGEMENT (Levels, Movements)
-- ============================================================================

CREATE TABLE stock_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    location TEXT DEFAULT 'main',
    quantity_on_hand DECIMAL(10,3) NOT NULL DEFAULT 0,
    quantity_reserved DECIMAL(10,3) NOT NULL DEFAULT 0,
    last_counted_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(property_id, item_id, location)
);

CREATE INDEX idx_stock_levels_property_item ON stock_levels(property_id, item_id);

CREATE TABLE stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    movement_type movement_type NOT NULL,
    quantity DECIMAL(10,3) NOT NULL, -- Positive = in, Negative = out
    reference_type TEXT, -- 'transfer', 'wastage', 'purchase', 'pos', 'adjustment'
    reference_id UUID, -- Polymorphic reference to source record
    from_location TEXT,
    to_location TEXT,
    notes TEXT,
    performed_by UUID REFERENCES people(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_movement_quantity CHECK (quantity != 0)
);

CREATE INDEX idx_stock_movements_property ON stock_movements(property_id);
CREATE INDEX idx_stock_movements_item ON stock_movements(item_id);
CREATE INDEX idx_stock_movements_reference ON stock_movements(reference_type, reference_id);

-- ============================================================================
-- SECTION 5: TRANSFERS BETWEEN LOCATIONS/PROPERTIES
-- ============================================================================

CREATE TABLE transfer_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_property_id UUID NOT NULL REFERENCES properties(id),
    destination_property_id UUID NOT NULL REFERENCES properties(id),
    status transfer_status NOT NULL DEFAULT 'pending',
    requested_by UUID NOT NULL REFERENCES people(id),
    authorized_by UUID REFERENCES people(id),
    received_by UUID REFERENCES people(id),
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    authorized_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    notes TEXT,
    CONSTRAINT chk_different_properties CHECK (source_property_id != destination_property_id)
);

CREATE TABLE transfer_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES transfer_requests(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES items(id),
    quantity_requested DECIMAL(10,3) NOT NULL,
    quantity_sent DECIMAL(10,3),
    quantity_received DECIMAL(10,3),
    notes TEXT,
    UNIQUE(transfer_id, item_id)
);

-- ============================================================================
-- SECTION 6: PURCHASE ORDERS
-- ============================================================================

CREATE TABLE purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    supplier_name TEXT NOT NULL,
    supplier_contact TEXT,
    status purchase_status NOT NULL DEFAULT 'pending',
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expected_date DATE,
    received_date DATE,
    total_amount DECIMAL(10,2),
    ordered_by UUID NOT NULL REFERENCES people(id),
    received_by UUID REFERENCES people(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    item_id UUID REFERENCES items(id), -- Can be null for unmapped items
    item_description TEXT NOT NULL, -- Fallback if item_id is null
    quantity_ordered DECIMAL(10,3) NOT NULL,
    quantity_received DECIMAL(10,3) DEFAULT 0,
    unit_cost DECIMAL(10,2),
    line_total DECIMAL(10,2),
    UNIQUE(purchase_order_id, item_id) WHERE item_id IS NOT NULL,
    UNIQUE(purchase_order_id, item_description) WHERE item_id IS NULL
);

-- ============================================================================
-- END OF STEP 1
-- Next: Step 2 will add Wastage, POS Integration, and Audit tables
-- ============================================================================
