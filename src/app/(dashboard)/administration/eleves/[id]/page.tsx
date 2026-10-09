import Link from 'next/link'
import { notFound } from 'next/navigation'
import { updateStudent } from '../actions'
import { getStudentDossier } from '@/server/services/students/get-student-dossier'
import { createClient } from '@/lib/supabase/server'

function text(value: unknown) {
  return value === null || value === undefined || value === '' ? '—' : String(value)
}

function contactValue(contact: Record<string, unknown>, ...keys: string[]) {
  const value = keys.map((key) => contact[key]).find((item) => typeof item === 'string')
  return typeof value === 'string' ? value : ''
}

export default async function StudentDossierPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>
  searchParams: Promise<{ error?: string; saved?: string }>
}) {
  const { id } = await params
  const query = await searchParams
  const dossier = await getStudentDossier(id)

  if (!dossier) notFound()

  const supabase = await createClient()
  const { data: schoolLife } = await supabase.rpc('get_student_school_life_summary', { p_student_id: id })
  const schoolLifeData = schoolLife as any ?? { attendance: [], justifications: [], discipline: [], followups: [], rewards: [] }
  const { data: financeCharges } = await supabase.from('student_charges').select('id,amount_due,status,due_date').eq('student_id', id)
  const { data: financeInvoices } = await supabase.from('invoices').select('id,total,status,due_date').eq('student_id', id)
  const financeData = {
    charges: financeCharges ?? [],
    invoices: financeInvoices ?? [],
    unpaid: [...(financeCharges ?? []), ...(financeInvoices ?? [])].filter((x:any) => x.status === 'pending' || x.status === 'partially_paid').length,
  }

  const { data: catering } = await supabase.rpc('get_student_catering', { p_student_id: id })
  const cateringData = catering as any ?? { attendance: [] }
  const { data: tahfizArabic } = await supabase.rpc('get_student_tahfiz_arabic', { p_student_id: id })
  const trainingData = tahfizArabic as any ?? { tahfiz: null, arabic: null }
  const { data: wushu } = await supabase.rpc('get_student_wushu', { p_student_id: id })
  const wushuData = wushu as any ?? { profile: null, sessions: [], evaluations: [], competitions: [] }

  const student = dossier.student
  const current = dossier.current_enrollment

  return (
    <main className="page">
      <div className="page-header">
        <div>
          <p className="page-subtitle">Dossier administratif numérique</p>
          <h1 className="page-title">{student.first_name} {student.last_name}</h1>
          <p className="page-subtitle">
            Matricule : <strong>{student.student_number}</strong>
          </p>
        </div>
        <div className="actions">
          <Link className="button button-secondary" href="/administration/eleves">Retour aux élèves</Link>
          <Link className="button button-secondary" href={`/administration/inscriptions?student=${student.id}`}>Inscriptions</Link>
        </div>
      </div>

      {query.error ? <p className="error">{query.error}</p> : null}
      {query.saved === '1' ? <p className="success">Le dossier élève a été enregistré.</p> : null}

      <section className="grid grid-3" style={{ marginBottom: 16 }}>
        <article className="card">
          <h2>Statut</h2>
          <p className="metric">{text(student.status)}</p>
          <span className="badge">{text(student.residence_type)}</span>
        </article>

        <article className="card">
          <h2>Classe actuelle</h2>
          <p className="metric">{text(current.class_name)}</p>
          <p>{text(current.level_name)}</p>
          <p>{text(current.school_year_name)}</p>
        </article>

        <article className="card">
          <h2>Inscription</h2>
          <p>{text(current.registration_number)}</p>
          <p>{text(current.status)}</p>
          <p>{text(current.enrollment_date)}</p>
        </article>
      </section>

      <form action={updateStudent}>
        <input type="hidden" name="studentId" value={student.id} />
        <section className="grid grid-2">
          <article className="card">
            <h2>Identité</h2>
            <div className="grid grid-2">
              <div className="field"><label className="label" htmlFor="studentNumber">Matricule *</label><input className="input" id="studentNumber" name="studentNumber" defaultValue={student.student_number} required maxLength={50} /></div>
              <div className="field"><label className="label" htmlFor="gender">Genre</label><select className="select" id="gender" name="gender" defaultValue={student.gender ?? ''}><option value="">Non précisé</option><option value="male">Masculin</option><option value="female">Féminin</option><option value="other">Autre</option></select></div>
              <div className="field"><label className="label" htmlFor="firstName">Prénom *</label><input className="input" id="firstName" name="firstName" defaultValue={student.first_name} required maxLength={100} /></div>
              <div className="field"><label className="label" htmlFor="lastName">Nom *</label><input className="input" id="lastName" name="lastName" defaultValue={student.last_name} required maxLength={100} /></div>
              <div className="field"><label className="label" htmlFor="dateOfBirth">Date de naissance</label><input className="input" id="dateOfBirth" name="dateOfBirth" type="date" defaultValue={student.date_of_birth ?? ''} /></div>
              <div className="field"><label className="label" htmlFor="placeOfBirth">Lieu de naissance</label><input className="input" id="placeOfBirth" name="placeOfBirth" defaultValue={student.place_of_birth ?? ''} maxLength={150} /></div>
              <div className="field"><label className="label" htmlFor="nationality">Nationalité</label><input className="input" id="nationality" name="nationality" defaultValue={student.nationality ?? ''} maxLength={100} /></div>
              <div className="field"><label className="label" htmlFor="residenceType">Régime</label><select className="select" id="residenceType" name="residenceType" defaultValue={student.residence_type}><option value="external">Externe</option><option value="internal">Interne</option><option value="other">Autre</option></select></div>
              <div className="field"><label className="label" htmlFor="status">Statut</label><select className="select" id="status" name="status" defaultValue={student.status}><option value="prospect">Prospect</option><option value="active">Actif</option><option value="transferred">Transféré</option><option value="graduated">Diplômé</option><option value="withdrawn">Retiré</option><option value="archived">Archivé</option></select></div>
            </div>
          </article>

          <article className="card">
            <h2>Coordonnées</h2>
            <div className="field"><label className="label" htmlFor="phone">Téléphone</label><input className="input" id="phone" name="phone" type="tel" defaultValue={student.phone ?? ''} maxLength={50} /></div>
            <div className="field"><label className="label" htmlFor="email">E-mail</label><input className="input" id="email" name="email" type="email" defaultValue={student.email ?? ''} maxLength={254} /></div>
            <div className="field"><label className="label" htmlFor="address">Adresse</label><textarea className="input" id="address" name="address" rows={3} defaultValue={student.address ?? ''} maxLength={500} /></div>
            <div className="field"><label className="label" htmlFor="photoUrl">Photo (URL ou chemin de stockage)</label><input className="input" id="photoUrl" name="photoUrl" defaultValue={student.photo_url ?? ''} maxLength={1000} /></div>
            <h3>Contact d’urgence</h3>
            <div className="field"><label className="label" htmlFor="emergencyName">Nom complet</label><input className="input" id="emergencyName" name="emergencyName" defaultValue={contactValue(student.emergency_contact, 'full_name', 'name')} maxLength={200} /></div>
            <div className="grid grid-2">
              <div className="field"><label className="label" htmlFor="emergencyRelationship">Lien avec l’élève</label><input className="input" id="emergencyRelationship" name="emergencyRelationship" defaultValue={contactValue(student.emergency_contact, 'relationship')} maxLength={100} /></div>
              <div className="field"><label className="label" htmlFor="emergencyPhone">Téléphone</label><input className="input" id="emergencyPhone" name="emergencyPhone" type="tel" defaultValue={contactValue(student.emergency_contact, 'phone', 'telephone')} maxLength={50} /></div>
            </div>
            <div className="field"><label className="label" htmlFor="medicalNotes">Observations médicales</label><textarea className="input" id="medicalNotes" name="medicalNotes" rows={4} defaultValue={student.medical_notes ?? ''} maxLength={5000} /></div>
          </article>
        </section>
        <div className="actions" style={{ marginTop: 16 }}>
          <button className="button button-primary" type="submit">Enregistrer le dossier</button>
        </div>
      </form>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Parents / Tuteurs</h2>
        {dossier.parents.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr><th>Nom</th><th>Relation</th><th>Téléphone</th><th>E-mail</th><th>Principal</th><th>Notifications</th></tr>
              </thead>
              <tbody>
                {dossier.parents.map((parent) => (
                  <tr key={parent.id}>
                    <td>{parent.last_name} {parent.first_name}</td>
                    <td>{parent.relationship}</td>
                    <td>{text(parent.phone)}</td>
                    <td>{text(parent.email)}</td>
                    <td>{parent.is_primary ? 'Oui' : 'Non'}</td>
                    <td>{parent.receives_notifications ? 'Oui' : 'Non'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="empty">Aucun parent/tuteur visible ou lié à ce dossier.</p>}
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Enseignants et affectations actuelles</h2>
        {dossier.teachers.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr><th>Enseignant</th><th>Matière</th><th>Classe</th><th>Année</th><th>H/semaine</th><th>Principal</th></tr>
              </thead>
              <tbody>
                {dossier.teachers.map((teacher, index) => (
                  <tr key={`${teacher.teacher_id}-${teacher.subject_id}-${teacher.class_id}-${index}`}>
                    <td>{teacher.teacher_last_name} {teacher.teacher_first_name}</td>
                    <td>{teacher.subject_name}</td>
                    <td>{teacher.class_name}</td>
                    <td>{teacher.school_year_name}</td>
                    <td>{text(teacher.weekly_hours)}</td>
                    <td>{teacher.is_primary ? 'Oui' : 'Non'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="empty">Aucune affectation pédagogique visible actuellement.</p>}
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Historique des inscriptions</h2>
        {dossier.enrollments.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr><th>Année</th><th>Inscription</th><th>Classe</th><th>Niveau</th><th>Régime</th><th>Statut</th><th>Type</th></tr>
              </thead>
              <tbody>
                {dossier.enrollments.map((enrollment) => (
                  <tr key={enrollment.id}>
                    <td>{enrollment.school_year_name}</td>
                    <td>{enrollment.registration_number}</td>
                    <td>{text(enrollment.class_name)}</td>
                    <td>{text(enrollment.level_name)}</td>
                    <td>{enrollment.residence_type}</td>
                    <td><span className="badge">{enrollment.status}</span></td>
                    <td>{enrollment.is_reenrollment ? 'Réinscription' : 'Première inscription'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="empty">Aucune inscription enregistrée.</p>}
      </section>

      <section className="grid grid-2" style={{ marginTop: 16 }}>
        <article className="card">
          <h2>Admissions</h2>
          {dossier.admissions.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Référence</th><th>Niveau</th><th>Année</th><th>Statut</th></tr></thead>
                <tbody>
                  {dossier.admissions.map((admission) => (
                    <tr key={admission.id}>
                      <td>{admission.application_number}</td>
                      <td>{text(admission.desired_level_name || admission.desired_level_label)}</td>
                      <td>{text(admission.desired_year_name)}</td>
                      <td><span className="badge">{admission.status}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <p className="empty">Aucune demande d'admission liée.</p>}
        </article>

        <article className="card">
          <h2>Personnes autorisées à récupérer l'élève</h2>
          {dossier.authorized_pickup_persons.length ? (
            <div className="table-wrap">
              <table>
                <thead><tr><th>Nom</th><th>Relation</th><th>Téléphone</th><th>Actif</th></tr></thead>
                <tbody>
                  {dossier.authorized_pickup_persons.map((person) => (
                    <tr key={person.id}>
                      <td>{person.full_name}</td>
                      <td>{text(person.relationship)}</td>
                      <td>{text(person.phone)}</td>
                      <td>{person.is_active ? 'Oui' : 'Non'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <p className="empty">Aucune personne autorisée enregistrée.</p>}
        </article>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div>
            <h2 style={{ margin: 0 }}>Vie scolaire</h2>
            <p className="page-subtitle">Historique intégré au dossier numérique : présence, justificatifs, discipline, suivi éducatif et récompenses.</p>
          </div>
          <Link className="button button-secondary" href="/vie-scolaire">Ouvrir le module</Link>
        </div>
        <div className="grid grid-4">
          <div><div className="stat-label">Présences / absences / retards</div><div className="stat-value">{schoolLifeData.attendance?.length ?? 0}</div></div>
          <div><div className="stat-label">Justificatifs</div><div className="stat-value">{schoolLifeData.justifications?.length ?? 0}</div></div>
          <div><div className="stat-label">Événements disciplinaires</div><div className="stat-value">{schoolLifeData.discipline?.length ?? 0}</div></div>
          <div><div className="stat-label">Suivis / récompenses</div><div className="stat-value">{(schoolLifeData.followups?.length ?? 0) + (schoolLifeData.rewards?.length ?? 0)}</div></div>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div><h2 style={{ margin: 0 }}>Restauration</h2><p className="page-subtitle">Présences aux repas intégrées au dossier numérique.</p></div>
          <Link className="button button-secondary" href="/restauration/presences">Ouvrir le module</Link>
        </div>
        <div className="grid grid-3">
          <div><div className="stat-label">Enregistrements repas</div><div className="stat-value">{cateringData.attendance?.length ?? 0}</div></div>
          <div><div className="stat-label">Repas servis</div><div className="stat-value">{(cateringData.attendance ?? []).filter((x: any) => x.served).length}</div></div>
          <div><div className="stat-label">Dernier repas suivi</div><div className="stat-value">{cateringData.attendance?.[0]?.meal_date ?? '—'}</div></div>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div><h2 style={{ margin: 0 }}>Tahfiz / Arabe</h2><p className="page-subtitle">Progression des formations spécialisées intégrée au dossier numérique.</p></div>
          <Link className="button button-secondary" href="/tahfiz-arabe">Ouvrir le module</Link>
        </div>
        <div className="grid grid-2">
          <article className="card" style={{boxShadow:'none'}}>
            <h3>Tahfiz</h3>
            {trainingData.tahfiz?.profile ? <><p><strong>Niveau :</strong> {text(trainingData.tahfiz.level?.name)}</p><p><strong>Progression :</strong> {trainingData.tahfiz.profile.current_progress}%</p><p><strong>Statut :</strong> {text(trainingData.tahfiz.profile.status)}</p><p><strong>Séances récentes :</strong> {trainingData.tahfiz.sessions?.length ?? 0}</p></> : <p className="empty">Aucun profil Tahfiz.</p>}
          </article>
          <article className="card" style={{boxShadow:'none'}}>
            <h3>Arabe</h3>
            {trainingData.arabic?.profile ? <><p><strong>Niveau :</strong> {text(trainingData.arabic.level?.name)}</p><p><strong>Progression :</strong> {trainingData.arabic.profile.current_progress}%</p><p><strong>Statut :</strong> {text(trainingData.arabic.profile.status)}</p><p><strong>Évaluations récentes :</strong> {trainingData.arabic.evaluations?.length ?? 0}</p></> : <p className="empty">Aucun profil Arabe.</p>}
          </article>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <div className="page-header" style={{ marginBottom: 12 }}>
          <div><h2 style={{ margin: 0 }}>Wushu</h2><p className="page-subtitle">Suivi intégré de la pratique Wushu, des entraînements, évaluations et compétitions.</p></div>
          <Link className="button button-secondary" href="/wushu">Ouvrir le module</Link>
        </div>
        {wushuData.profile ? <div className="grid grid-4">
          <div><div className="stat-label">Groupe</div><div className="stat-value">{text(wushuData.profile.group_name)}</div></div>
          <div><div className="stat-label">Grade</div><div className="stat-value">{text(wushuData.profile.current_grade)}</div></div>
          <div><div className="stat-label">Progression</div><div className="stat-value">{wushuData.profile.current_progress}%</div></div>
          <div><div className="stat-label">Statut</div><div className="stat-value">{text(wushuData.profile.status)}</div></div>
        </div> : <p className="empty">Aucun profil Wushu enregistré.</p>}
        <div className="grid grid-3" style={{marginTop:12}}>
          <div><div className="stat-label">Séances visibles</div><div className="stat-value">{wushuData.sessions?.length ?? 0}</div></div>
          <div><div className="stat-label">Évaluations visibles</div><div className="stat-value">{wushuData.evaluations?.length ?? 0}</div></div>
          <div><div className="stat-label">Résultats de compétitions</div><div className="stat-value">{wushuData.competitions?.length ?? 0}</div></div>
        </div>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Documents administratifs</h2>
        {dossier.documents.length ? (
          <div className="table-wrap">
            <table>
              <thead><tr><th>Titre</th><th>Référence</th><th>Statut</th><th>Date</th></tr></thead>
              <tbody>
                {dossier.documents.map((document) => (
                  <tr key={document.id}>
                    <td>{document.title}</td>
                    <td>{text(document.reference)}</td>
                    <td><span className="badge">{document.status}</span></td>
                    <td>{text(document.issue_date || document.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="empty">Aucun document administratif enregistré.</p>}
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <h2>Modules à venir</h2>
        <div className="grid grid-3">
          {Object.entries(dossier.modules).map(([module, step]) => (
            <div key={module} className="card" style={{ boxShadow: 'none', border: '1px solid var(--border)' }}>
              <strong>{module}</strong>
              <p className="page-subtitle">{step}</p>
            </div>
          ))}
        </div>
      </section>
    </main>
  )
}
