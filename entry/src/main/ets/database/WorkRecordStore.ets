import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { MonthSummary, WorkDefaults, WorkRecord } from '../model/WorkRecord';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'hourly_work_v2.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const CREATE_TABLE = `CREATE TABLE IF NOT EXISTS work_record (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  work_date TEXT NOT NULL,
  period TEXT NOT NULL DEFAULT '上午',
  hours REAL NOT NULL DEFAULT 0,
  hourly_rate REAL NOT NULL DEFAULT 0,
  note TEXT NOT NULL DEFAULT '',
  wage REAL NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)`;

const CREATE_DEFAULTS_TABLE = `CREATE TABLE IF NOT EXISTS work_defaults (
  id INTEGER PRIMARY KEY,
  period TEXT NOT NULL,
  hours REAL NOT NULL,
  hourly_rate REAL NOT NULL
)`;

export class WorkRecordStore {
  private store?: relationalStore.RdbStore;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store) {
      return;
    }
    this.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await this.store.executeSql(CREATE_TABLE);
    await this.store.executeSql(CREATE_DEFAULTS_TABLE);
    await this.store.executeSql('CREATE INDEX IF NOT EXISTS idx_work_record_date ON work_record(work_date)');
    await this.store.executeSql(
      `INSERT OR IGNORE INTO work_defaults (id, period, hours, hourly_rate)
       SELECT 1, period, hours, hourly_rate
       FROM work_record ORDER BY created_at DESC, id DESC LIMIT 1`
    );
  }

  private requireStore(): relationalStore.RdbStore {
    if (!this.store) {
      throw new Error('数据库尚未初始化');
    }
    return this.store;
  }

  async listByMonth(month: string): Promise<WorkRecord[]> {
    const result = await this.requireStore().querySql(
      `SELECT * FROM work_record WHERE work_date LIKE ?
       ORDER BY work_date DESC, CASE period WHEN '上午' THEN 0 ELSE 1 END`,
      [`${month}%`]
    );
    const records: WorkRecord[] = [];
    while (result.goToNextRow()) {
      records.push(this.readRecord(result));
    }
    result.close();
    return records;
  }

  async getDefaults(): Promise<WorkDefaults | undefined> {
    const result = await this.requireStore().querySql(
      'SELECT period, hours, hourly_rate FROM work_defaults WHERE id = 1'
    );
    let defaults: WorkDefaults | undefined = undefined;
    if (result.goToFirstRow()) {
      defaults = {
        period: result.getString(result.getColumnIndex('period')),
        hours: result.getDouble(result.getColumnIndex('hours')),
        hourlyRate: result.getDouble(result.getColumnIndex('hourly_rate'))
      };
    }
    result.close();
    return defaults;
  }

  async insert(record: WorkRecord): Promise<number> {
    const now = Date.now();
    const values: relationalStore.ValuesBucket = {
      'work_date': record.workDate,
      'period': record.period,
      'hours': record.hours,
      'hourly_rate': record.hourlyRate,
      'note': record.note,
      'wage': record.wage,
      'created_at': now,
      'updated_at': now
    };
    const rowId = await this.requireStore().insert('work_record', values);
    try {
      await this.requireStore().executeSql(
        `INSERT OR REPLACE INTO work_defaults
         (id, period, hours, hourly_rate) VALUES (1, ?, ?, ?)`,
        [record.period, record.hours, record.hourlyRate]
      );
    } catch (error) {
      console.error(`Failed to save work defaults: ${(error as Error).message}`);
    }
    return rowId;
  }

  async update(record: WorkRecord): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'work_date': record.workDate,
      'period': record.period,
      'hours': record.hours,
      'hourly_rate': record.hourlyRate,
      'note': record.note,
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
       ROUND(COALESCE(SUM(hours), 0) * 60) AS total_minutes,
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
    const hours = result.getDouble(result.getColumnIndex('hours'));
    return {
      id: result.getLong(result.getColumnIndex('id')),
      workDate: result.getString(result.getColumnIndex('work_date')),
      period: result.getString(result.getColumnIndex('period')),
      hours: hours,
      hourlyRate: result.getDouble(result.getColumnIndex('hourly_rate')),
      note: result.getString(result.getColumnIndex('note')),
      workMinutes: Math.round(hours * 60),
      wage: result.getDouble(result.getColumnIndex('wage'))
    };
  }
}

export const workRecordStore = new WorkRecordStore();
