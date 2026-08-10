import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MonthSummary, WorkRecord } from '../model/WorkRecord';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'hourly_work.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const CREATE_TABLE = `CREATE TABLE IF NOT EXISTS work_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  work_date TEXT NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  break_minutes INTEGER NOT NULL DEFAULT 0,
  hourly_rate REAL NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  work_minutes INTEGER NOT NULL DEFAULT 0,
  wage REAL NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)`;

export class WorkRecordStore {
  private store?: relationalStore.RdbStore;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store) {
      return;
    }
    this.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await this.store.executeSql(CREATE_TABLE);
    await this.store.executeSql('CREATE INDEX IF NOT EXISTS idx_work_record_date ON work_record(work_date)');
  }

  private requireStore(): relationalStore.RdbStore {
    if (!this.store) {
      throw new Error('数据库尚未初始化');
    }
    return this.store;
  }

  async listByMonth(month: string): Promise<WorkRecord[]> {
    const result = await this.requireStore().querySql(
      'SELECT * FROM work_record WHERE work_date LIKE ? ORDER BY work_date DESC, start_time DESC',
      [`${month}%`]
    );
    const records: WorkRecord[] = [];
    while (result.goToNextRow()) {
      records.push(this.readRecord(result));
    }
    result.close();
    return records;
  }

  async insert(record: WorkRecord): Promise<number> {
    const now = Date.now();
    const values: relationalStore.ValuesBucket = {
      'work_date': record.workDate,
      'start_time': record.startTime,
      'end_time': record.endTime,
      'break_minutes': record.breakMinutes,
      'hourly_rate': record.hourlyRate,
      'note': record.note,
      'work_minutes': record.workMinutes,
      'wage': record.wage,
      'created_at': now,
      'updated_at': now
    };
    return await this.requireStore().insert('work_record', values);
  }

  async update(record: WorkRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'work_date': record.workDate,
      'start_time': record.startTime,
      'end_time': record.endTime,
      'break_minutes': record.breakMinutes,
      'hourly_rate': record.hourlyRate,
      'note': record.note,
      'work_minutes': record.workMinutes,
      'wage': record.wage,
      'updated_at': Date.now()
    };
    const predicates = new relationalStore.RdbPredicates('work_record');
    predicates.equalTo('id', record.id);
    return await this.requireStore().update(values, predicates);
  }

  async remove(id: number): Promise<number> {
    const predicates = new relationalStore.RdbPredicates('work_record');
    predicates.equalTo('id', id);
    return await this.requireStore().delete(predicates);
  }

  async summary(month: string): Promise<MonthSummary> {
    const result = await this.requireStore().querySql(
      `SELECT COUNT(DISTINCT work_date) AS days,
       COALESCE(SUM(work_minutes), 0) AS total_minutes,
       COALESCE(SUM(wage), 0) AS total_wage,
       COALESCE(AVG(hourly_rate), 0) AS average_rate
       FROM work_record WHERE work_date LIKE ?`,
      [`${month}%`]
    );
    let summary: MonthSummary = { days: 0, totalMinutes: 0, totalWage: 0, averageRate: 0 };
    if (result.goToFirstRow()) {
      summary = {
        days: result.getLong(result.getColumnIndex('days')),
        totalMinutes: result.getLong(result.getColumnIndex('total_minutes')),
        totalWage: result.getDouble(result.getColumnIndex('total_wage')),
        averageRate: result.getDouble(result.getColumnIndex('average_rate'))
      };
    }
    result.close();
    return summary;
  }

  private readRecord(result: relationalStore.ResultSet): WorkRecord {
    return {
      id: result.getLong(result.getColumnIndex('id')),
      workDate: result.getString(result.getColumnIndex('work_date')),
      startTime: result.getString(result.getColumnIndex('start_time')),
      endTime: result.getString(result.getColumnIndex('end_time')),
      breakMinutes: result.getLong(result.getColumnIndex('break_minutes')),
      hourlyRate: result.getDouble(result.getColumnIndex('hourly_rate')),
      note: result.getString(result.getColumnIndex('note')),
      workMinutes: result.getLong(result.getColumnIndex('work_minutes')),
      wage: result.getDouble(result.getColumnIndex('wage'))
    };
  }
}

export const workRecordStore = new WorkRecordStore();
