'use client'

import type { ChangeEvent } from 'react'

type SchoolYearOption = { id: string; name: string; is_current: boolean }
const CREATE_OPTION = '__create_school_year__'

export function SchoolYearSelect({
  years,
  name,
  id,
  value,
  required = false,
  returnTo = '/administration/classes',
}: {
  years: SchoolYearOption[]
  name: string
  id: string
  value: string
  required?: boolean
  returnTo?: '/administration/classes' | '/administration/classes/nouveau'
}) {
  function handleChange(event: ChangeEvent<HTMLSelectElement>) {
    if (event.currentTarget.value === CREATE_OPTION) {
      const query = new URLSearchParams({ returnTo })
      window.location.assign(`/administration/classes/annee-scolaire/nouvelle?${query.toString()}`)
    }
  }

  return (
    <select className="select" id={id} name={name} defaultValue={value} required={required} onChange={handleChange}>
      {!required ? <option value="">Choisir une année scolaire</option> : null}
      {years.map((year) => <option key={year.id} value={year.id}>{year.name}{year.is_current ? ' — actuelle' : ''}</option>)}
      <option value={CREATE_OPTION}>+ Créer une année scolaire…</option>
    </select>
  )
}
