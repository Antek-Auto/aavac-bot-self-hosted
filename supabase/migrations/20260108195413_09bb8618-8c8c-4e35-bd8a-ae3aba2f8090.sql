-- Create demo_settings table for admin-only demo widget configuration
CREATE TABLE public.demo_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT DEFAULT 'AI Assistant',
  greeting TEXT DEFAULT 'Hi there! 👋 How can I help you today?',
  enable_voice BOOLEAN DEFAULT true,
  enable_chat BOOLEAN DEFAULT true,
  primary_color TEXT DEFAULT '#14b8a6',
  retell_api_key TEXT,
  voice_agent_id TEXT,
  chat_agent_id TEXT,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_by UUID REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE public.demo_settings ENABLE ROW LEVEL SECURITY;

-- Only admins can view and manage demo settings
CREATE POLICY "Admins can view demo settings"
ON public.demo_settings
FOR SELECT
USING (has_role(auth.uid(), 'admin'::app_role));

CREATE POLICY "Admins can manage demo settings"
ON public.demo_settings
FOR ALL
USING (has_role(auth.uid(), 'admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'admin'::app_role));

-- Allow public read for the demo widget to fetch settings (without sensitive fields)
CREATE POLICY "Public can view demo settings"
ON public.demo_settings
FOR SELECT
USING (true);

-- Insert default demo settings
INSERT INTO public.demo_settings (id, title, greeting)
VALUES ('00000000-0000-0000-0000-000000000001', 'AI Assistant', 'Hi there! 👋 How can I help you today?');