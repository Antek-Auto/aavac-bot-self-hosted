#!/bin/bash

# ==============================================================================
# Easy Supabase Setup Script
# ==============================================================================
# This script handles the entire backend setup for the AI Widget Platform.
# It wraps multiple Supabase CLI commands into one easy flow.
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                AI Widget Platform - Backend Setup                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 1. Check Prerequisites
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v supabase &> /dev/null; then
  echo -e "${RED}Error: Supabase CLI is not installed.${NC}"
  echo "Please install it before running this script:"
  echo "  - macOS: brew install supabase/tap/supabase"
  echo "  - Windows: scoop bucket add supabase https://github.com/supabase/scoop-bucket.git && scoop install supabase"
  echo "  - npm: npm install -g supabase"
  exit 1
fi

echo -e "${GREEN}✓ Supabase CLI found${NC}"
echo ""

# 2. Login to Supabase
# ------------------------------------------------------------------------------
echo -e "${YELLOW}Checking login status...${NC}"
if ! supabase projects list &> /dev/null; then
  echo "Please log in to Supabase:"
  supabase login
fi
echo -e "${GREEN}✓ Logged in${NC}"
echo ""

# 3. Link Project
# ------------------------------------------------------------------------------
echo -e "${BLUE}[Step 1/4] Link Supabase Project${NC}"
echo "Enter your Supabase Project Reference (found in your project settings URL: https://supabase.com/dashboard/project/xxxxx)"
read -p "Project Reference: " PROJECT_REF

if [ -z "$PROJECT_REF" ]; then
  echo -e "${RED}Error: Project reference is required.${NC}"
  exit 1
fi

# Link project
supabase link --project-ref "$PROJECT_REF"
echo -e "${GREEN}✓ Linked to project $PROJECT_REF${NC}"
echo ""

# 4. Setup Database
# ------------------------------------------------------------------------------
echo -e "${BLUE}[Step 2/4] Setup Database Schema${NC}"
echo "Applying database migrations (tables, policies, default settings)..."
supabase db push

echo -e "${GREEN}✓ Database schema applied${NC}"
echo ""

# 5. Deploy Edge Functions
# ------------------------------------------------------------------------------
echo -e "${BLUE}[Step 3/4] Deploy Edge Functions${NC}"
echo "Deploying serverless functions for Voice, Chat, and Widget config..."

# List of functions to deploy
FUNCTIONS=(
    "retell-create-call"
    "retell-text-chat"
    "widget-config"
    "widget-embed"
    "wordpress-plugin"
)

# Checking if we are in the root directory
if [ ! -d "supabase/functions" ]; then
  echo -e "${RED}Error: Cannot find supabase/functions directory. Make sure you are in the project root.${NC}"
  exit 1
fi

for func in "${FUNCTIONS[@]}"; do
    echo -n "Deploying $func... "
    # Using --no-verify-jwt to allow public access where needed (handled by internal logic/CORS)
    if supabase functions deploy "$func" --no-verify-jwt > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        echo "Check logs with: supabase functions logs $func"
    fi
done

echo -e "${GREEN}✓ Edge functions deployed${NC}"
echo ""

# 6. Configure Secrets (Retell AI)
# ------------------------------------------------------------------------------
echo -e "${BLUE}[Step 4/4] Configure API Keys (Optional)${NC}"
echo "Do you want to configure Retell AI keys now? (Recommended for voice features)"
read -p "Configure Retell AI? (y/n): " CONFIGURE_RETELL

if [[ "$CONFIGURE_RETELL" =~ ^[Yy]$ ]]; then
  read -sp "Retell API Key: " RETELL_API_KEY
  echo ""
  read -p "Retell Voice Agent ID: " RETELL_AGENT_ID
  read -p "Retell Chat Agent ID: " RETELL_TEXT_AGENT_ID
  
  echo ""
  echo "Setting secrets..."
  
  if [ -n "$RETELL_API_KEY" ]; then
      supabase secrets set RETELL_API_KEY="$RETELL_API_KEY"
  fi
  if [ -n "$RETELL_AGENT_ID" ]; then
      supabase secrets set RETELL_AGENT_ID="$RETELL_AGENT_ID"
  fi
  if [ -n "$RETELL_TEXT_AGENT_ID" ]; then
      supabase secrets set RETELL_TEXT_AGENT_ID="$RETELL_TEXT_AGENT_ID"
  fi
  
  echo -e "${GREEN}✓ Secrets configured${NC}"
else
  echo "Skipping secrets configuration. You can do this later via the Admin Dashboard."
fi
echo ""

# 7. Final Output
# ------------------------------------------------------------------------------
echo -e "${BLUE}══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}                         SETUP COMPLETE!                              ${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Your backend is ready. Now you just need to deploy the frontend to Vercel."
echo ""
echo "Use these values for your Vercel Environment Variables:"
echo "-------------------------------------------------------"
echo "VITE_SUPABASE_URL             : https://$PROJECT_REF.supabase.co"
echo "VITE_SUPABASE_PROJECT_ID      : $PROJECT_REF"
echo "VITE_SUPABASE_PUBLISHABLE_KEY : [Your Supabase Anon/Public Key]"
echo "-------------------------------------------------------"
echo ""
echo "Get your Anon Key from: https://supabase.com/dashboard/project/$PROJECT_REF/settings/api"
