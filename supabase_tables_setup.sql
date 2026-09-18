-- Phase 1a: Voice Settings & Logs
CREATE TABLE IF NOT EXISTS public.voice_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
    always_listening boolean DEFAULT false,
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.voice_command_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    wake_detected boolean DEFAULT false,
    transcript text NOT NULL,
    matched_intent text NOT NULL,
    action_taken text NOT NULL,
    cancelled boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS for Phase 1a tables
ALTER TABLE public.voice_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voice_command_log ENABLE ROW LEVEL SECURITY;

-- Since the app uses device UUID as user_id and anon key, we allow all for now
-- Note: Replace these with proper auth.uid() policies when migrating to Supabase Auth
CREATE POLICY "Allow all on voice_settings" ON public.voice_settings FOR ALL USING (true);
CREATE POLICY "Allow all on voice_command_log" ON public.voice_command_log FOR ALL USING (true);

-- Phase 2: Solo Trip Mode & Check-ins
CREATE TABLE IF NOT EXISTS public.solo_trip_sessions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    interval_minutes integer NOT NULL,
    grace_period_minutes integer DEFAULT 2,
    notify_method text NOT NULL, -- 'notification', 'voice', 'both'
    status text NOT NULL DEFAULT 'active', -- 'active', 'completed', 'cancelled'
    started_at timestamptz DEFAULT now(),
    next_checkin_due_at timestamptz,
    last_confirmed_at timestamptz,
    alert_contact_ids uuid[] DEFAULT '{}',
    created_at timestamptz DEFAULT now()
);

-- Prevent overlapping active sessions per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_active_solo_trip ON public.solo_trip_sessions(user_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS public.solo_trip_checkin_log (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES public.solo_trip_sessions(id) ON DELETE CASCADE,
    due_at timestamptz NOT NULL,
    responded_at timestamptz,
    response_lat double precision,
    response_lng double precision,
    escalated boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_location_shares (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    shared_with_contact_id uuid REFERENCES public.emergency_contacts(id) ON DELETE CASCADE,
    lat double precision NOT NULL,
    lng double precision NOT NULL,
    updated_at timestamptz DEFAULT now(),
    expires_at timestamptz,
    active boolean DEFAULT true,
    source text -- 'manual', 'checkin', 'solo_trip'
);

-- Enable RLS for Phase 2 tables
ALTER TABLE public.solo_trip_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solo_trip_checkin_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_location_shares ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all on solo_trip_sessions" ON public.solo_trip_sessions FOR ALL USING (true);
CREATE POLICY "Allow all on solo_trip_checkin_log" ON public.solo_trip_checkin_log FOR ALL USING (true);
CREATE POLICY "Allow all on live_location_shares" ON public.live_location_shares FOR ALL USING (true);
