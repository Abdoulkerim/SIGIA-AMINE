export function firstRelation<T>(relation: T | T[] | null | undefined): T | undefined {
  if (Array.isArray(relation)) return relation[0]
  return relation ?? undefined
}
