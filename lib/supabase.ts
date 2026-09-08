import { createClient, type SupabaseClient } from '@supabase/supabase-js'

type SupabaseEnv = {
  NEXT_PUBLIC_SUPABASE_URL?: string
  NEXT_PUBLIC_SUPABASE_ANON_KEY?: string
  SUPABASE_SERVICE_ROLE_KEY?: string
}

const env = process.env as SupabaseEnv

const BUILD_FALLBACK_URL = 'https://example.supabase.co'
const BUILD_FALLBACK_KEY = 'build-time-placeholder'

function isValidHttpUrl(value: string | undefined): value is string {
  if (!value) return false
  try {
    const url = new URL(value)
    return url.protocol === 'http:' || url.protocol === 'https:'
  } catch {
    return false
  }
}

function requireRuntimeUrl(): string {
  const value = env.NEXT_PUBLIC_SUPABASE_URL
  if (isValidHttpUrl(value)) return value

  if (process.env.NODE_ENV === 'production') {
    throw new Error('NEXT_PUBLIC_SUPABASE_URL must be a valid HTTP or HTTPS URL')
  }

  return BUILD_FALLBACK_URL
}

function requireRuntimeKey(value: string | undefined, envName: string): string {
  if (value) return value

  if (process.env.NODE_ENV === 'production') {
    throw new Error(`${envName} is required at runtime`)
  }

  return BUILD_FALLBACK_KEY
}

export function createSupabaseClients(): {
  supabase: SupabaseClient
  supabaseAdmin: SupabaseClient
} {
  const url = requireRuntimeUrl()
  const anonKey = requireRuntimeKey(env.NEXT_PUBLIC_SUPABASE_ANON_KEY, 'NEXT_PUBLIC_SUPABASE_ANON_KEY')
  const serviceRoleKey = requireRuntimeKey(env.SUPABASE_SERVICE_ROLE_KEY, 'SUPABASE_SERVICE_ROLE_KEY')

  return {
    supabase: createClient(url, anonKey),
    supabaseAdmin: createClient(url, serviceRoleKey, {
      auth: { autoRefreshToken: false },
    }),
  }
}

// Lazy proxies prevent Next.js build-time module evaluation from requiring
// runtime Supabase configuration while keeping the existing API unchanged.
export const supabase = new Proxy({} as SupabaseClient, {
  get(_target, property, receiver) {
    const client = createSupabaseClients().supabase
    return Reflect.get(client as object, property, receiver)
  },
})

export const supabaseAdmin = new Proxy({} as SupabaseClient, {
  get(_target, property, receiver) {
    const client = createSupabaseClients().supabaseAdmin
    return Reflect.get(client as object, property, receiver)
  },
})
