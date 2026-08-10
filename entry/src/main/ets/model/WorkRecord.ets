export interface WorkRecord {
  id: number;
  workDate: string;
  startTime: string;
  endTime: string;
  breakMinutes: number;
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

export function emptyRecord(date: string): WorkRecord {
  return {
    id: 0,
    workDate: date,
    startTime: '09:00',
    endTime: '17:00',
    breakMinutes: 60,
    hourlyRate: 30,
    note: '',
    workMinutes: 420,
    wage: 210
  };
}

export function calculateMinutes(start: string, end: string, breakMinutes: number): number {
  const startParts = start.split(':');
  const endParts = end.split(':');
  if (startParts.length !== 2 || endParts.length !== 2) {
    return 0;
  }
  const startValue = Number(startParts[0]) * 60 + Number(startParts[1]);
  let endValue = Number(endParts[0]) * 60 + Number(endParts[1]);
  if (endValue < startValue) {
    endValue += 24 * 60;
  }
  return Math.max(0, endValue - startValue - Math.max(0, breakMinutes));
}

export function formatDuration(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) {
    return `${rest}分钟`;
  }
  return rest === 0 ? `${hours}小时` : `${hours}小时${rest}分`;
}
