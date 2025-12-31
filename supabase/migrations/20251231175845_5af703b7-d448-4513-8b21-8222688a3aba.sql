-- Create profiles table
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro')),
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  subscription_status TEXT DEFAULT 'active' CHECK (subscription_status IN ('active', 'canceled', 'past_due', 'trialing', NULL)),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles RLS policies
CREATE POLICY "Users can view their own profile" 
ON public.profiles FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Trigger to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name', '')
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Add user_id to widget_configs
ALTER TABLE public.widget_configs 
ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Drop existing policy and create new ones for widget_configs
DROP POLICY IF EXISTS "Widget configs are publicly readable by api_key" ON public.widget_configs;

CREATE POLICY "Users can view their own widgets"
ON public.widget_configs FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Public can view widgets by api_key"
ON public.widget_configs FOR SELECT
TO anon
USING (true);

CREATE POLICY "Users can create their own widgets"
ON public.widget_configs FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own widgets"
ON public.widget_configs FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own widgets"
ON public.widget_configs FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Trigger for updated_at on profiles
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Function to check widget limit based on tier
CREATE OR REPLACE FUNCTION public.check_widget_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_tier TEXT;
  widget_count INTEGER;
BEGIN
  -- Get user's subscription tier
  SELECT subscription_tier INTO user_tier
  FROM public.profiles
  WHERE user_id = NEW.user_id;
  
  -- Count existing widgets
  SELECT COUNT(*) INTO widget_count
  FROM public.widget_configs
  WHERE user_id = NEW.user_id;
  
  -- Check limits: free = 1 widget, pro = unlimited
  IF user_tier = 'free' AND widget_count >= 1 THEN
    RAISE EXCEPTION 'Free tier is limited to 1 widget. Upgrade to Pro for unlimited widgets.';
  END IF;
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_widget_limit
BEFORE INSERT ON public.widget_configs
FOR EACH ROW
EXECUTE FUNCTION public.check_widget_limit();