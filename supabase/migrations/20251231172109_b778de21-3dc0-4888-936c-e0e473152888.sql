-- Create widget_configs table for embeddable widget configuration
CREATE TABLE public.widget_configs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  api_key TEXT NOT NULL UNIQUE,
  
  -- Widget appearance
  primary_color TEXT DEFAULT '#14b8a6',
  position TEXT DEFAULT 'bottom-right' CHECK (position IN ('bottom-right', 'bottom-left')),
  title TEXT DEFAULT 'AI Assistant',
  greeting TEXT DEFAULT 'Hi! How can I help you today?',
  
  -- Features
  enable_voice BOOLEAN DEFAULT true,
  enable_chat BOOLEAN DEFAULT true,
  
  -- Agent IDs (optional overrides)
  voice_agent_id TEXT,
  chat_agent_id TEXT,
  
  -- Allowed domains for CORS
  allowed_domains TEXT[] DEFAULT '{}',
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.widget_configs ENABLE ROW LEVEL SECURITY;

-- Create policy for public read access (widgets need to fetch config)
CREATE POLICY "Widget configs are publicly readable by api_key" 
ON public.widget_configs 
FOR SELECT 
USING (true);

-- Create function to generate API key
CREATE OR REPLACE FUNCTION public.generate_widget_api_key()
RETURNS TEXT AS $$
BEGIN
  RETURN 'wgt_' || encode(gen_random_bytes(24), 'hex');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for automatic timestamp updates
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

CREATE TRIGGER update_widget_configs_updated_at
BEFORE UPDATE ON public.widget_configs
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Insert a default widget config for testing
INSERT INTO public.widget_configs (name, api_key, title, greeting)
VALUES (
  'Default Widget',
  'wgt_demo_' || encode(gen_random_bytes(16), 'hex'),
  'AI Assistant',
  'Hi there! 👋 How can I help you today?'
);