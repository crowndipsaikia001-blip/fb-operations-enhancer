import { NextRequest, NextResponse } from 'next/server'
import { supabaseAdmin } from '@/lib/supabase'

const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN!
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID!

export async function POST(req: NextRequest) {
  try {
    const { authorPersonId, title, body, category } = await req.json()

    if (!authorPersonId || !title || !body) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const { data: property } = await supabaseAdmin
      .from('properties')
      .select('id')
      .eq('code', 'LOOP')
      .single()

    if (!property) {
      return NextResponse.json({ error: 'Property not found' }, { status: 500 })
    }

    const { data: notice, error } = await supabaseAdmin
      .from('notices')
      .insert({
        property_id: property.id,
        author_person_id: authorPersonId,
        title,
        body,
        category: category || null,
      })
      .select('id, title, body, category, created_at')
      .single()

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 })
    }

    const { data: author } = await supabaseAdmin
      .from('people')
      .select('full_name')
      .eq('id', authorPersonId)
      .single()

    const telegramText =
      `New BD Notice\n\n` +
      `From: ${author?.full_name || 'Unknown'}\n` +
      `${category ? `Category: ${category}\n` : ''}` +
      `Title: ${title}\n\n` +
      `${body}`

    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: telegramText,
      }),
    })

    return NextResponse.json({ notice })
  } catch (err) {
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}

export async function GET() {
  const { data, error } = await supabaseAdmin
    .from('notices')
    .select('id, title, body, category, created_at, author_person_id, people(full_name)')
    .order('created_at', { ascending: false })
    .limit(50)

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }

  return NextResponse.json({ notices: data })
}
