import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? ''
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? ''
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY ?? ''

function getConfiguredSupabaseUrl() {
  if (supabaseUrl) return supabaseUrl
  if (process.env.NODE_ENV === 'production') {
    throw new Error('NEXT_PUBLIC_SUPABASE_URL is required at runtime')
  }
  return 'https://example.supabase.co'
}

function getConfiguredKey(key: string, envName: string) {
  if (key) return key
  if (process.env.NODE_ENV === 'production') {
    throw new Error(`${envName} is required at runtime`)
  }
  return 'build-time-placeholder'
}

const configuredUrl = getConfiguredSupabaseUrl()
const configuredAnonKey = getConfiguredKey(supabaseAnonKey, 'NEXT_PUBLIC_SUPABASE_ANON_KEY')
const configuredServiceRoleKey = getConfiguredKey(supabaseServiceRoleKey, 'SUPABASE_SERVICE_ROLE_KEY')

export const supabase = createClient(configuredUrl, configuredAnonKey)

export const supabaseAdmin = createClient(
  configuredUrl,
  configuredServiceRoleKey,
  { auth: { autoRefreshToken: false } },
)
