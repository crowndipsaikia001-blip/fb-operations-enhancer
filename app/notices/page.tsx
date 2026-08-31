'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'

type StaffOption = {
  person_id: string
  people: { id: string; full_name: string } | null
}

type Notice = {
  id: string
  title: string
  body: string
  category: string | null
  created_at: string
  people: { full_name: string } | null
}

const CATEGORIES = ['VIP', 'Menu Change', 'Price Update', 'Event', 'General']

export default function NoticesPage() {
  const [staff, setStaff] = useState<StaffOption[]>([])
  const [notices, setNotices] = useState<Notice[]>([])
  const [authorPersonId, setAuthorPersonId] = useState('')
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [category, setCategory] = useState('General')
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    fetch('/api/staff')
      .then((res) => res.json())
      .then((data) => setStaff(data.staff || []))

    fetch('/api/notices')
      .then((res) => res.json())
      .then((data) => setNotices(data.notices || []))

    const channel = supabase
      .channel('notices-feed')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'notices' },
        () => {
          fetch('/api/notices')
            .then((res) => res.json())
            .then((data) => setNotices(data.notices || []))
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!authorPersonId || !title || !body) return

    setSubmitting(true)
    await fetch('/api/notices', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ authorPersonId, title, body, category }),
    })
    setTitle('')
    setBody('')
    setSubmitting(false)
  }

  return (
    <main style={{ padding: '2rem', fontFamily: 'sans-serif', maxWidth: 700, margin: '0 auto' }}>
      <h1>BD Notices</h1>

      <form onSubmit={handleSubmit} style={{ marginBottom: '2rem', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
        <select value={authorPersonId} onChange={(e) => setAuthorPersonId(e.target.value)} required>
          <option value="">Who are you?</option>
          {staff.map((s) =>
            s.people ? (
              <option key={s.person_id} value={s.people.id}>
                {s.people.full_name}
              </option>
            ) : null
          )}
        </select>

        <select value={category} onChange={(e) => setCategory(e.target.value)}>
          {CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>

        <input
          placeholder="Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />

        <textarea
          placeholder="Details"
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={3}
          required
        />

        <button type="submit" disabled={submitting}>
          {submitting ? 'Posting...' : 'Post Notice'}
        </button>
      </form>

      <div>
        {notices.map((n) => (
          <div key={n.id} style={{ borderBottom: '1px solid #ddd', padding: '0.75rem 0' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>
              {n.category ? `[${n.category}] ` : ''}
              {n.people?.full_name || 'Unknown'} — {new Date(n.created_at).toLocaleString()}
            </div>
            <div style={{ fontWeight: 'bold' }}>{n.title}</div>
            <div>{n.body}</div>
          </div>
        ))}
      </div>
    </main>
  )
}
