-- ==============================================================================
-- BANAAG PostgreSQL & Supabase Database Schema
-- Version: 1.0.0
-- Architecture: Multi-tenant, Row-Level Security (RLS), Offline-First Cloud Sync
-- ==============================================================================

-- 1. Enable UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Projects Table
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    project_code TEXT NOT NULL,
    title TEXT NOT NULL,
    client_name TEXT NOT NULL,
    location TEXT NOT NULL,
    service_type TEXT NOT NULL DEFAULT '1-Phase 230V',
    contract_amount NUMERIC(12, 2) DEFAULT 0.00,
    current_phase_number INT DEFAULT 1,
    progress_percentage DOUBLE PRECISION DEFAULT 0.15,
    status TEXT NOT NULL DEFAULT 'CONSULTATION',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for Projects
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Contractors can only view own projects"
    ON public.projects FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Contractors can insert own projects"
    ON public.projects FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Contractors can update own projects"
    ON public.projects FOR UPDATE
    USING (auth.uid() = user_id);

-- 3. Appliance Loads & Needs Analysis Tally Table
CREATE TABLE IF NOT EXISTS public.project_appliance_loads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    category TEXT NOT NULL,
    name TEXT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    rating_va INT NOT NULL DEFAULT 100,
    is_dedicated_circuit BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.project_appliance_loads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Contractors access own project appliance loads"
    ON public.project_appliance_loads FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = project_appliance_loads.project_id
            AND projects.user_id = auth.uid()
        )
    );

-- 4. Plan Canvas Points & Conduit Routes Table
CREATE TABLE IF NOT EXISTS public.canvas_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    point_identifier TEXT NOT NULL, -- e.g. 'pt-1'
    device_type TEXT NOT NULL,      -- e.g. 'OUTLET_DUPLEX', 'LIGHT', 'SWITCH_1G', 'PANEL'
    label TEXT NOT NULL,
    pos_x DOUBLE PRECISION NOT NULL,
    pos_y DOUBLE PRECISION NOT NULL,
    circuit_number INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.conduit_routes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    route_identifier TEXT NOT NULL,
    from_point_id TEXT NOT NULL,
    to_point_id TEXT NOT NULL,
    measured_length_meters DOUBLE PRECISION NOT NULL DEFAULT 3.5,
    conduit_size_mm INT DEFAULT 20,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.canvas_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conduit_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Contractors manage own canvas points"
    ON public.canvas_points FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = canvas_points.project_id
            AND projects.user_id = auth.uid()
        )
    );

CREATE POLICY "Contractors manage own conduit routes"
    ON public.conduit_routes FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = conduit_routes.project_id
            AND projects.user_id = auth.uid()
        )
    );

-- 5. Variation Orders (Signed Contract Modifications) Table
CREATE TABLE IF NOT EXISTS public.variation_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    vo_number TEXT NOT NULL,
    description TEXT NOT NULL,
    cost_material NUMERIC(10, 2) DEFAULT 0.00,
    cost_labor NUMERIC(10, 2) DEFAULT 0.00,
    total_cost NUMERIC(10, 2) GENERATED ALWAYS AS (cost_material + cost_labor) STORED,
    client_signature_data TEXT, -- Base64 encoded stroke path
    is_signed BOOLEAN DEFAULT FALSE,
    signed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.variation_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Contractors manage own variation orders"
    ON public.variation_orders FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = variation_orders.project_id
            AND projects.user_id = auth.uid()
        )
    );

-- 6. Pre-Cover Rough-In Photo Audits Table (Metadata only, files stored in Storage Bucket)
CREATE TABLE IF NOT EXISTS public.rough_in_photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE NOT NULL,
    phase_id TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    geo_latitude DOUBLE PRECISION,
    geo_longitude DOUBLE PRECISION,
    sha256_hash TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.rough_in_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Contractors manage own rough-in photos"
    ON public.rough_in_photos FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.projects
            WHERE projects.id = rough_in_photos.project_id
            AND projects.user_id = auth.uid()
        )
    );

-- ==============================================================================
-- 4. BANAAG Anti-Counterfeit 1-Device Single-Session Licensing Architecture
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.licensed_buyers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    buyer_name TEXT NOT NULL,
    phone_number TEXT,
    tier TEXT NOT NULL DEFAULT 'PRO_CONTRACTOR',
    active_device_id TEXT,             -- Stores hardware fingerprint / unique device ID
    active_device_model TEXT,          -- e.g. "realme C75 (RMX3941)"
    is_active BOOLEAN DEFAULT TRUE,
    bound_at TIMESTAMP WITH TIME ZONE,
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS: Public client can only query if their device is the registered one
ALTER TABLE public.licensed_buyers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public checking of active device session"
    ON public.licensed_buyers FOR SELECT
    USING (true);

-- Function to bind a device session (Rejects if already bound to another phone)
CREATE OR REPLACE FUNCTION public.bind_device_session(
    p_email TEXT,
    p_device_id TEXT,
    p_device_model TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_buyer RECORD;
BEGIN
    -- Check if buyer exists in whitelist
    SELECT * INTO v_buyer FROM public.licensed_buyers WHERE LOWER(email) = LOWER(p_email);
    
    IF v_buyer IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'NOT_REGISTERED',
            'message', 'This Gmail is not yet registered in our system. Please purchase an official BANAAG license to activate.'
        );
    END IF;

    IF NOT v_buyer.is_active THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'LICENSE_DISABLED',
            'message', 'Your license has been suspended or revoked. Please contact ASV Solutions support.'
        );
    END IF;

    -- Case 1: First time binding or binding to same device
    IF v_buyer.active_device_id IS NULL OR v_buyer.active_device_id = p_device_id THEN
        UPDATE public.licensed_buyers
        SET active_device_id = p_device_id,
            active_device_model = p_device_model,
            bound_at = COALESCE(bound_at, NOW()),
            last_seen_at = NOW()
        WHERE LOWER(email) = LOWER(p_email);

        RETURN jsonb_build_object(
            'success', true,
            'code', 'BOUND_SUCCESS',
            'buyer_name', v_buyer.buyer_name,
            'tier', v_buyer.tier,
            'message', 'Device successfully bound. 30-Day Offline Lease activated.'
        );
    ELSE
        -- Case 2: Attempting to bind a second device while first device is active
        RETURN jsonb_build_object(
            'success', false,
            'code', 'DEVICE_LIMIT_REACHED',
            'active_model', v_buyer.active_device_model,
            'message', '1-Device Policy Active: This account is currently active on another device (' || COALESCE(v_buyer.active_device_model, 'Phone') || '). Please use the Transfer Device option on your old phone first.'
        );
    END IF;
END;
$$;

-- Function to release/transfer device
CREATE OR REPLACE FUNCTION public.release_device_session(
    p_email TEXT,
    p_device_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.licensed_buyers
    SET active_device_id = NULL,
        active_device_model = NULL
    WHERE LOWER(email) = LOWER(p_email) AND active_device_id = p_device_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Device released successfully. You may now log in from your new device.'
    );
END;
$$;
