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
