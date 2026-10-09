import { createClient } from '@supabase/supabase-js'

const env = process.env
const url = env.SUPABASE_URL || env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321'
const secretKey = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY
const email = env.ADMIN_EMAIL
const password = env.ADMIN_PASSWORD
const firstName = env.ADMIN_FIRST_NAME || 'Administrateur'
const lastName = env.ADMIN_LAST_NAME || 'SIGIA'
const roleCode = env.ADMIN_ROLE_CODE || 'founder'
const schoolCode = env.SCHOOL_CODE || 'AL-AMINE'

if (!secretKey) {
  throw new Error('SUPABASE_SECRET_KEY ou SUPABASE_SERVICE_ROLE_KEY est obligatoire.')
}
if (!email || !password) {
  throw new Error('ADMIN_EMAIL et ADMIN_PASSWORD sont obligatoires.')
}
if (password.length < 8) {
  throw new Error('ADMIN_PASSWORD doit contenir au moins 8 caractères.')
}

const supabase = createClient(url, secretKey, {
  auth: { autoRefreshToken: false, persistSession: false }
})

async function main() {
  const { data: school, error: schoolError } = await supabase
    .from('schools')
    .select('id, code, name')
    .eq('code', schoolCode)
    .single()

  if (schoolError) throw schoolError

  const { data: role, error: roleError } = await supabase
    .from('roles')
    .select('id, code, name')
    .eq('code', roleCode)
    .single()

  if (roleError) throw roleError

  let authUser
  const { data: listData, error: listError } = await supabase.auth.admin.listUsers({
    page: 1,
    perPage: 1000
  })
  if (listError) throw listError

  authUser = listData.users.find((u) => u.email?.toLowerCase() === email.toLowerCase())

  if (!authUser) {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        first_name: firstName,
        last_name: lastName
      }
    })
    if (error) throw error
    authUser = data.user
  } else {
    const { data, error } = await supabase.auth.admin.updateUserById(authUser.id, {
      password,
      email_confirm: true,
      user_metadata: {
        first_name: firstName,
        last_name: lastName
      }
    })
    if (error) throw error
    authUser = data.user
  }

  const { error: userError } = await supabase.from('users').upsert({
    id: authUser.id,
    school_id: school.id,
    first_name: firstName,
    last_name: lastName,
    email,
    status: 'active'
  }, { onConflict: 'id' })

  if (userError) throw userError

  const { error: roleAssignmentError } = await supabase
    .from('user_roles')
    .upsert({
      user_id: authUser.id,
      role_id: role.id,
      school_id: school.id,
      is_active: true
    }, { onConflict: 'user_id,role_id,school_id' })

  if (roleAssignmentError) throw roleAssignmentError

  console.log('✅ Compte bootstrap créé/configuré.')
  console.log(`   Établissement : ${school.name} (${school.code})`)
  console.log(`   Utilisateur   : ${email}`)
  console.log(`   Rôle          : ${role.name} (${role.code})`)
  console.log('⚠️  Le mot de passe n’est jamais affiché et ne doit jamais être commité.')
}

main().catch((error) => {
  console.error('❌ Bootstrap admin échoué:', error.message)
  process.exit(1)
})
