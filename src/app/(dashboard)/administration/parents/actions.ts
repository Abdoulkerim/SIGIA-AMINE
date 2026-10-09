'use server'

import { z } from 'zod'
import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

const parentSchema = z.object({
  firstName: z.string().trim().min(1).max(100),
  lastName: z.string().trim().min(1).max(100),
  gender: z.enum(['male', 'female', 'other']).optional(),
  profession: z.string().trim().max(150).optional(),
  phone: z.string().trim().max(50).optional(),
  email: z.string().trim().email().max(200).optional().or(z.literal('')),
  address: z.string().trim().max(500).optional(),
  preferredContactMethod: z.string().trim().max(50).optional(),
})

export async function createParent(formData: FormData) {
  const context = await (await import('@/lib/auth/current-user')).getCurrentUserContext()
  if (!context?.profile.school_id) redirect('/login')

  const parsed = parentSchema.safeParse({
    firstName: formData.get('firstName'),
    lastName: formData.get('lastName'),
    gender: formData.get('gender') || undefined,
    profession: formData.get('profession') || undefined,
    phone: formData.get('phone') || undefined,
    email: formData.get('email') || '',
    address: formData.get('address') || undefined,
    preferredContactMethod: formData.get('preferredContactMethod') || undefined,
  })

  if (!parsed.success) {
    redirect('/administration/parents/nouveau?error=Champs invalides')
  }

  const supabase = await createClient()
  const { error } = await supabase.from('parents').insert({
    school_id: context.profile.school_id,
    first_name: parsed.data.firstName,
    last_name: parsed.data.lastName,
    gender: parsed.data.gender ?? null,
    profession: parsed.data.profession || null,
    phone: parsed.data.phone || null,
    email: parsed.data.email || null,
    address: parsed.data.address || null,
    preferred_contact_method: parsed.data.preferredContactMethod || null,
  })

  if (error) {
    redirect(`/administration/parents/nouveau?error=${encodeURIComponent(error.message)}`)
  }

  revalidatePath('/administration/parents')
  redirect('/administration/parents?created=1')
}
