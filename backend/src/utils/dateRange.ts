import type { ParsedQs } from 'qs';

export interface DateRangeFilter {
  dateFrom?: Date;
  dateTo?: Date;
}

/** Parses the optional ISO date bounds used by reporting/list endpoints. */
export function parseDateRange(query: ParsedQs): DateRangeFilter | null {
  const parse = (value: unknown): Date | undefined | null => {
    if (value == null) return undefined;
    if (typeof value !== 'string' || value.trim() === '') return null;
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  };

  const dateFrom = parse(query.dateFrom);
  const dateTo = parse(query.dateTo);
  if (dateFrom === null || dateTo === null) return null;
  if (dateFrom && dateTo && dateFrom > dateTo) return null;

  return { dateFrom, dateTo };
}

export function parseSortOrder(value: unknown): 'asc' | 'desc' | null {
  if (value == null) return 'desc';
  if (value === 'newest') return 'desc';
  if (value === 'oldest') return 'asc';
  return null;
}
