-- ====================================================================
-- BOCARDO RESTAURANT AUTHENTICATION & RESTAURANT PROFILE SCHEMA
-- Migration: 20261018000000_create_bocardo_auth_and_restaurants.sql
-- ====================================================================

-- 1. Create Restaurants Table
CREATE TABLE IF NOT EXISTS public.restaurants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    restaurant_name TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    phone TEXT,
    email TEXT NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending_approval')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_restaurants_user_id UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_restaurants_user_id ON public.restaurants(user_id);
CREATE INDEX IF NOT EXISTS idx_restaurants_email ON public.restaurants(email);

-- 2. Create Restaurant Operational Profiles Table
CREATE TABLE IF NOT EXISTS public.restaurant_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
    cuisine_types TEXT[] DEFAULT '{}',
    address TEXT,
    city TEXT,
    postal_code TEXT,
    opening_hours JSONB DEFAULT '{"monday": {"open": "09:00", "close": "22:00"}}'::jsonb,
    is_accepting_orders BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_restaurant_profiles_restaurant_id UNIQUE (restaurant_id)
);

-- 3. Create Audit Log Table for Security Events
CREATE TABLE IF NOT EXISTS public.auth_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_audit_logs_user_id ON public.auth_audit_logs(user_id, created_at DESC);

-- 4. Automatic User Synchronization Trigger
-- When a user registers via Supabase Auth (Email or OAuth),
-- extract metadata and automatically populate the restaurants table.
CREATE OR REPLACE FUNCTION public.handle_new_restaurant_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_restaurant_name TEXT;
    v_owner_name TEXT;
    v_phone TEXT;
    v_new_restaurant_id UUID;
BEGIN
    -- Extract metadata supplied during signUp()
    v_restaurant_name := COALESCE(
        NEW.raw_user_meta_data->>'restaurant_name',
        NEW.raw_user_meta_data->>'restaurantName',
        'Bocardo Restaurant'
    );
    v_owner_name := COALESCE(
        NEW.raw_user_meta_data->>'owner_name',
        NEW.raw_user_meta_data->>'ownerName',
        NEW.raw_user_meta_data->>'full_name',
        'Owner'
    );
    v_phone := COALESCE(
        NEW.raw_user_meta_data->>'phone',
        NEW.raw_user_meta_data->>'phone_number',
        NEW.phone,
        ''
    );

    -- Insert into public.restaurants
    INSERT INTO public.restaurants (
        user_id,
        restaurant_name,
        owner_name,
        phone,
        email,
        is_verified
    ) VALUES (
        NEW.id,
        v_restaurant_name,
        v_owner_name,
        v_phone,
        NEW.email,
        (NEW.email_confirmed_at IS NOT NULL)
    )
    ON CONFLICT (user_id) DO UPDATE SET
        restaurant_name = EXCLUDED.restaurant_name,
        owner_name = EXCLUDED.owner_name,
        phone = EXCLUDED.phone,
        updated_at = NOW()
    RETURNING id INTO v_new_restaurant_id;

    -- Insert default profile
    INSERT INTO public.restaurant_profiles (
        restaurant_id
    ) VALUES (
        v_new_restaurant_id
    )
    ON CONFLICT (restaurant_id) DO NOTHING;

    -- Record audit log
    INSERT INTO public.auth_audit_logs (
        user_id,
        event_type,
        metadata
    ) VALUES (
        NEW.id,
        'USER_REGISTERED',
        jsonb_build_object('restaurant_id', v_new_restaurant_id, 'email', NEW.email)
    );

    RETURN NEW;
END;
$$;

-- Drop existing trigger if exists and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_restaurant_user();

-- 5. Row Level Security (RLS) Policies
-- Ensure strict multi-tenant isolation so one restaurant cannot view or edit another's data.

ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_audit_logs ENABLE ROW LEVEL SECURITY;

-- Restaurants Policies
CREATE POLICY "Public can view active restaurants"
    ON public.restaurants
    FOR SELECT
    USING (status = 'active');

CREATE POLICY "Owners can view own restaurant"
    ON public.restaurants
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Owners can update own restaurant"
    ON public.restaurants
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Restaurant Profiles Policies
CREATE POLICY "Public can view active restaurant profiles"
    ON public.restaurant_profiles
    FOR SELECT
    USING (
        restaurant_id IN (
            SELECT id FROM public.restaurants WHERE status = 'active'
        )
    );

CREATE POLICY "Owners can view own profile"
    ON public.restaurant_profiles
    FOR SELECT
    TO authenticated
    USING (
        restaurant_id IN (
            SELECT id FROM public.restaurants WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Owners can update own profile"
    ON public.restaurant_profiles
    FOR UPDATE
    TO authenticated
    USING (
        restaurant_id IN (
            SELECT id FROM public.restaurants WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        restaurant_id IN (
            SELECT id FROM public.restaurants WHERE user_id = auth.uid()
        )
    );

-- Audit Logs Policies: Only users can see their own audit events
CREATE POLICY "Users can view own audit logs"
    ON public.auth_audit_logs
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);
