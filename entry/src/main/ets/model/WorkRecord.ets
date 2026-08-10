export interface WorkRecord {
  id: number;
  workDate: string;
  period: string;
  hours: number;
  hourlyRate: number;
  note: string;
  workMinutes: number;
  wage: number;
}

export interface MonthSummary {
  days: number;
  totalMinutes: number;
  totalWage: number;
  averageRate: number;
}

export interface WorkDefaults {
  period: string;
  hours: number;
  hourlyRate: number;
}

export function emptyRecord(date: string): WorkRecord {
  return {
    id: 0,
    workDate: date,
    period: '上午',
    hours: 4,
    hourlyRate: 30,
    note: '',
    workMinutes: 240,
    wage: 120
  };
}

export function formatDuration(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) {
    return `${rest}分钟`;
  }
  return rest === 0 ? `${hours}小时` : `${hours}小时${rest}分`;
}
