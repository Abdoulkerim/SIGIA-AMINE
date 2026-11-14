'use client'

import { useMemo, useState } from 'react'

type ArabicLevel = { id: string; code: string; name: string; education_stage?: string | null }
type ArabicProfile = { student_id: string; arabic_level_id: string | null; arabic_full_name?: string | null; students?: { first_name?: string | null; last_name?: string | null; student_number?: string | null } | null }
type ArabicSubject = { id: string; name: string; code: string; education_stage?: string | null }

const levelFrenchLabels: Record<string, string> = {
  'Cp1': 'Cours préparatoire 1',
  'الأول الاعدادي': 'Première année du collège',
  'الثاني الاعدادي': 'Deuxième année du collège',
  'الثالث الاعدادي': 'Troisième année du collège',
  'الرابع الاعدادي': 'Quatrième année du collège',
  'الثانوية': 'Première année du lycée',
  'الثاني الثانوي': 'Deuxième année du lycée',
  'الثالث الثانوي': 'Troisième année du lycée',
  'الأول': 'Niveau 1',
  'الثاني': 'Niveau 2',
  'الثالث': 'Niveau 3',
}

const subjectTranslations: Record<string, { fr: string; ar: string }> = {
  alad: { fr: 'Littérature et textes', ar: 'الأدب والنصوص' },
  almo: { fr: 'Lecture', ar: 'المطالعة' },
  alfr: { fr: 'Sciences des successions', ar: 'الفرائض' },
  'an nah': { fr: 'Grammaire et morphologie arabes', ar: 'النحو والصرف' },
  aqui: { fr: 'Doctrine islamique', ar: 'العقيدة' },
  'cor h': { fr: 'Mémorisation du Coran', ar: 'حفظ القرآن الكريم' },
  'cor l': { fr: 'Lecture du Coran', ar: 'قراءة القرآن الكريم' },
  fiq: { fr: 'Jurisprudence islamique', ar: 'الفقه' },
  hadi: { fr: 'Hadith', ar: 'الحديث' },
  'oul h': { fr: 'Sciences du hadith', ar: 'علوم الحديث' },
  oul: { fr: 'Sciences du Coran', ar: 'علوم القرآن' },
  ouss: { fr: 'Fondements de la jurisprudence', ar: 'أصول الفقه' },
  sirr: { fr: 'Biographie prophétique et histoire', ar: 'السيرة والتاريخ' },
  taf: { fr: 'Exégèse du Coran', ar: 'التفسير' },
}

function stageLabel(stage?: string | null) {
  if (!stage) return ''
  const labels: Record<string, string> = { preschool: 'Maternelle', primaire: 'Primaire', moyen: 'Moyen', secondaire: 'Secondaire', vocational: 'Centre de formation' }
  return labels[stage.toLowerCase()] ?? stage.replaceAll('_', ' ')
}

export function ArabicSessionFields({ profiles, levels, subjects }: { profiles: ArabicProfile[]; levels: ArabicLevel[]; subjects: ArabicSubject[] }) {
  const [studentId, setStudentId] = useState('')
  const selectedProfile = profiles.find((profile) => profile.student_id === studentId)
  const selectedLevel = levels.find((level) => level.id === selectedProfile?.arabic_level_id)
  const matchingSubjects = useMemo(() => {
    if (!selectedLevel?.education_stage) return subjects
    return subjects.filter((subject) => subject.education_stage?.toLowerCase() === selectedLevel.education_stage?.toLowerCase())
  }, [selectedLevel, subjects])

  return <>
    <div className="field">
      <label className="label" htmlFor="arabic-session-student">Élève</label>
      <select className="select" id="arabic-session-student" name="studentId" required value={studentId} onChange={(event) => setStudentId(event.target.value)}>
        <option value="">{profiles.length ? 'Choisir' : 'Aucun élève Arabe disponible'}</option>
        {profiles.map((profile) => {
          const student = profile.students
          const frenchName = `${student?.last_name ?? ''} ${student?.first_name ?? ''}`.trim()
          const level = levels.find((item) => item.id === profile.arabic_level_id)
          const levelLabel = level ? `${levelFrenchLabels[level.code] ?? levelFrenchLabels[level.name] ?? level.name} / ${level.name}` : 'Classe Arabe non définie'
          return <option key={profile.student_id} value={profile.student_id}>{student?.student_number ? `${student.student_number} · ` : ''}{profile.arabic_full_name || frenchName} · {levelLabel}</option>
        })}
      </select>
      {selectedLevel ? <small className="field-hint">Classe Arabe : {levelFrenchLabels[selectedLevel.code] ?? levelFrenchLabels[selectedLevel.name] ?? selectedLevel.name} / <span dir="rtl" lang="ar">{selectedLevel.name}</span>{selectedLevel.education_stage ? ` · Cycle ${stageLabel(selectedLevel.education_stage)}` : ''}</small> : null}
    </div>
    <div className="field">
      <label className="label" htmlFor="arabic-session-subject">Activité / matière</label>
      <select className="select" id="arabic-session-subject" name="activityType" required defaultValue="">
        <option value="" disabled>{selectedLevel ? 'Choisir une matière pour cette classe Arabe' : 'Choisir une matière Arabe'}</option>
        {matchingSubjects.map((subject) => {
          const translation = subjectTranslations[subject.code.trim().toLowerCase()]
          const french = translation?.fr ?? subject.name
          const arabic = translation?.ar
          return <option key={subject.id} value={subject.name}>{french}{arabic ? ` / ${arabic}` : ''} · {subject.code}</option>
        })}
      </select>
      {selectedLevel?.education_stage && !subjects.some((subject) => subject.education_stage?.toLowerCase() === selectedLevel.education_stage?.toLowerCase()) ? <small className="field-hint">Aucune matière Arabe n’est configurée pour le cycle « {stageLabel(selectedLevel.education_stage)} ». Les matières d’un autre cycle ne sont pas proposées.</small> : null}
    </div>
  </>
}
