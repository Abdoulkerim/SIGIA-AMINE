import Link from 'next/link'
import { createClient } from '@/lib/supabase/server'
import { createBuilding, createDormitory, createRoom, createBed } from '../boarding-actions'

export default async function StructuresPage({ searchParams }: { searchParams: Promise<Record<string,string|undefined>> }) {
  const sp = await searchParams
  const supabase = await createClient()
  const claims = await supabase.auth.getClaims(); const userId = claims.data?.claims?.sub
  const { data: profile } = userId ? await supabase.from('users').select('school_id').eq('id', userId).single() : { data: null }
  const schoolId = profile?.school_id
  const [{ data: buildings }, { data: dormitories }, { data: rooms }] = schoolId ? await Promise.all([
    supabase.from('boarding_buildings').select('id,code,name').eq('school_id',schoolId).order('code'),
    supabase.from('boarding_dormitories').select('id,name,gender,building_id').order('name'),
    supabase.from('boarding_rooms').select('id,name,capacity,floor,status,dormitory_id').order('name'),
  ]) : [{ data: [] },{ data: [] },{ data: [] }]
  const { data: beds } = schoolId ? await supabase.from('boarding_beds').select('id,bed_number,status,room_id').order('bed_number') : { data: [] }

  return <main className="page">
    <div className="page-header"><div><h1 className="page-title">Structures de l’internat</h1><p className="page-subtitle">Bâtiments → dortoirs → chambres → lits.</p></div><Link className="button button-secondary" href="/internat">Retour</Link></div>
    {sp.error && <div className="error">{sp.error}</div>}
    {sp.created && <div className="success">Élément créé avec succès.</div>}

    <section className="grid grid-4">
      <form className="card" action={createBuilding}><h2 style={{ marginTop: 0 }}>Bâtiment</h2><div className="field"><label className="label">Code</label><input className="input" name="code" required /></div><div className="field"><label className="label">Nom</label><input className="input" name="name" required /></div><div className="field"><label className="label">Description</label><textarea className="input" name="description" /></div><button className="button button-primary">Créer</button></form>
      <form className="card" action={createDormitory}><h2 style={{ marginTop: 0 }}>Dortoir</h2><div className="field"><label className="label">Bâtiment</label><select className="select" name="buildingId" required>{(buildings??[]).map((b:any)=><option key={b.id} value={b.id}>{b.code} — {b.name}</option>)}</select></div><div className="field"><label className="label">Nom</label><input className="input" name="name" required /></div><div className="field"><label className="label">Sexe</label><select className="select" name="gender"><option value="">Non précisé</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select></div><button className="button button-primary">Créer</button></form>
      <form className="card" action={createRoom}><h2 style={{ marginTop: 0 }}>Chambre</h2><div className="field"><label className="label">Dortoir</label><select className="select" name="dormitoryId" required>{(dormitories??[]).map((d:any)=><option key={d.id} value={d.id}>{d.name}</option>)}</select></div><div className="field"><label className="label">Nom</label><input className="input" name="name" required /></div><div className="field"><label className="label">Capacité</label><input className="input" type="number" min="1" name="capacity" required /></div><div className="field"><label className="label">Étage</label><input className="input" name="floor" /></div><button className="button button-primary">Créer</button></form>
      <form className="card" action={createBed}><h2 style={{ marginTop: 0 }}>Lit</h2><div className="field"><label className="label">Chambre</label><select className="select" name="roomId" required>{(rooms??[]).map((r:any)=><option key={r.id} value={r.id}>{r.name} — cap. {r.capacity}</option>)}</select></div><div className="field"><label className="label">Numéro</label><input className="input" name="bedNumber" required /></div><button className="button button-primary">Créer</button></form>
    </section>

    <section className="card" style={{ marginTop: 16 }}><h2 style={{ marginTop: 0 }}>Bâtiments</h2><div className="table-wrap"><table className="table"><thead><tr><th>Code</th><th>Nom</th><th>Nb dortoirs</th></tr></thead><tbody>{(buildings??[]).map((b:any)=><tr key={b.id}><td>{b.code}</td><td>{b.name}</td><td>{(dormitories??[]).filter((d:any)=>d.building_id===b.id).length}</td></tr>)}</tbody></table></div></section>

    <section className="card" style={{ marginTop: 16 }}><h2 style={{ marginTop: 0 }}>Chambres et lits</h2><div className="table-wrap"><table className="table"><thead><tr><th>Dortoir</th><th>Chambre</th><th>Capacité</th><th>Statut</th><th>Lits</th></tr></thead><tbody>{(rooms??[]).map((r:any)=><tr key={r.id}><td>{(dormitories??[]).find((d:any)=>d.id===r.dormitory_id)?.name ?? '—'}</td><td>{r.name}</td><td>{r.capacity}</td><td><span className="badge">{r.status}</span></td><td>{(beds??[]).filter((b:any)=>b.room_id===r.id).map((b:any)=>`${b.bed_number} (${b.status})`).join(', ') || 'Aucun lit'}</td></tr>)}</tbody></table></div></section>
  </main>
}
