import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from "react";
import { User, Session } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

interface Profile {
  id: string;
  user_id: string;
  email: string | null;
  full_name: string | null;
  avatar_url: string | null;
  subscription_tier: "free" | "starter" | "pro" | "enterprise";
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  subscription_status: string | null;
  created_at: string;
  updated_at: string;
}

interface SubscriptionInfo {
  subscribed: boolean;
  tier: "free" | "starter" | "pro" | "enterprise";
  widget_limit: number;
  subscription_end: string | null;
  is_trialing: boolean;
}

interface AuthContextType {
  user: User | null;
  session: Session | null;
  profile: Profile | null;
  subscription: SubscriptionInfo | null;
  loading: boolean;
  signUp: (email: string, password: string, fullName?: string) => Promise<{ error: Error | null }>;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
  refreshSubscription: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [subscription, setSubscription] = useState<SubscriptionInfo | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchProfile = async (userId: string) => {
    const { data, error } = await supabase
      .from("profiles")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();
    
    if (error) {
      console.error("Error fetching profile:", error);
      return null;
    }
    return data as Profile | null;
  };

  const fetchSubscription = useCallback(async () => {
    try {
      const { data, error } = await supabase.functions.invoke("check-subscription");
      if (error) {
        console.error("Error checking subscription:", error);
        setSubscription({
          subscribed: false,
          tier: "free",
          widget_limit: 5,
          subscription_end: null,
          is_trialing: false,
        });
        return;
      }
      setSubscription(data as SubscriptionInfo);
    } catch (err) {
      console.error("Error fetching subscription:", err);
      setSubscription({
        subscribed: false,
        tier: "free",
        widget_limit: 5,
        subscription_end: null,
        is_trialing: false,
      });
    }
  }, []);

  const refreshProfile = async () => {
    if (user) {
      const profileData = await fetchProfile(user.id);
      setProfile(profileData);
    }
  };

  const refreshSubscription = useCallback(async () => {
    if (session) {
      await fetchSubscription();
    }
  }, [session, fetchSubscription]);

  useEffect(() => {
    const { data: { subscription: authSubscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        
        if (session?.user) {
          setTimeout(() => {
            fetchProfile(session.user.id).then(setProfile);
            fetchSubscription();
          }, 0);
        } else {
          setProfile(null);
          setSubscription(null);
        }
      }
    );

    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      if (session?.user) {
        Promise.all([
          fetchProfile(session.user.id),
          fetchSubscription(),
        ]).then(([profileData]) => {
          setProfile(profileData);
          setLoading(false);
        });
      } else {
        setLoading(false);
      }
    });

    return () => authSubscription.unsubscribe();
  }, [fetchSubscription]);

  // Refresh subscription every minute
  useEffect(() => {
    if (!session) return;
    
    const interval = setInterval(() => {
      fetchSubscription();
    }, 60000);

    return () => clearInterval(interval);
  }, [session, fetchSubscription]);

  const signUp = async (email: string, password: string, fullName?: string) => {
    const redirectUrl = `${window.location.origin}/`;
    
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: redirectUrl,
        data: {
          full_name: fullName,
        },
      },
    });
    
    return { error: error as Error | null };
  };

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    
    return { error: error as Error | null };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setSession(null);
    setProfile(null);
    setSubscription(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        session,
        profile,
        subscription,
        loading,
        signUp,
        signIn,
        signOut,
        refreshProfile,
        refreshSubscription,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
