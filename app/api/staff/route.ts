import { NextResponse } from 'next/server'
import { supabaseAdmin } from '@/lib/supabase'

export async function GET() {
  const { data, error } = await supabaseAdmin
    .from('property_memberships')
    .select('person_id, department, people(id, full_name), roles(name)')
    .order('department')

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  return NextResponse.json({ staff: data })
}
