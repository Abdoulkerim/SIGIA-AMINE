
/** Type d'une requête Supabase paginable. */
type FetchAllRowsQuery<T> = {
  range(from: number, to: number): PromiseLike<{
    data: T[] | null
    error: any
  }>
}

/** Fetch every row from a Supabase query, bypassing the API's per-request row cap. */
export async function fetchAllRows<T>(
  createQuery: () => FetchAllRowsQuery<T>
): Promise<{ data: T[]; error: any }> {
  const pageSize = 1000
  const rows: T[] = []

  for (let from = 0; ; from += pageSize) {
    const { data, error } = await createQuery().range(
      from,
      from + pageSize - 1
    )

    if (error) return { data: [], error }

    const page = data ?? []
    rows.push(...page)

    if (page.length < pageSize) {
      return { data: rows, error: null }
    }
  }
}
