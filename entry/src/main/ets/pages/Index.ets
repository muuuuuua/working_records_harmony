import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { workRecordStore } from '../database/WorkRecordStore';
import {
  calculateMinutes,
  emptyRecord,
  formatDuration,
  MonthSummary,
  WorkRecord
} from '../model/WorkRecord';

interface ThemeColors {
  background: string;
  card: string;
  primary: string;
  primarySoft: string;
  accent: string;
  text: string;
  secondary: string;
  line: string;
  danger: string;
}

const COLORS: ThemeColors = {
  background: '#F4F6F1',
  card: '#FFFFFF',
  primary: '#27695C',
  primarySoft: '#E1EEE9',
  accent: '#F1A33B',
  text: '#18211F',
  secondary: '#697470',
  line: '#E7EAE7',
  danger: '#C64E4E'
};

function pad(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function todayText(): string {
  const date = new Date();
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function monthText(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}`;
}

function monthTitle(month: string): string {
  const parts = month.split('-');
  return `${parts[0]}年${Number(parts[1])}月`;
}

function dayTitle(date: string): string {
  const parts = date.split('-');
  return `${Number(parts[1])}月${Number(parts[2])}日`;
}

function cloneRecord(record: WorkRecord): WorkRecord {
  return {
    id: record.id,
    workDate: record.workDate,
    startTime: record.startTime,
    endTime: record.endTime,
    breakMinutes: record.breakMinutes,
    hourlyRate: record.hourlyRate,
    note: record.note,
    workMinutes: record.workMinutes,
    wage: record.wage
  };
}

function isTwoDigits(value: string): boolean {
  if (value.length !== 2) {
    return false;
  }
  const numberValue = Number(value);
  return !Number.isNaN(numberValue) && numberValue >= 0 && numberValue <= 99;
}

function isValidDate(value: string): boolean {
  const parts = value.split('-');
  if (parts.length !== 3 || parts[0].length !== 4 || !isTwoDigits(parts[1]) || !isTwoDigits(parts[2])) {
    return false;
  }
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);
  if (Number.isNaN(year) || month < 1 || month > 12 || day < 1) {
    return false;
  }
  const parsed = new Date(year, month - 1, day);
  return parsed.getFullYear() === year && parsed.getMonth() === month - 1 && parsed.getDate() === day;
}

function isValidTime(value: string): boolean {
  const parts = value.split(':');
  if (parts.length !== 2 || !isTwoDigits(parts[0]) || !isTwoDigits(parts[1])) {
    return false;
  }
  return Number(parts[0]) <= 23 && Number(parts[1]) <= 59;
}

@Entry
@Component
struct Index {
  @State selectedMonth: string = monthText(new Date());
  @State records: WorkRecord[] = [];
  @State summary: MonthSummary = { days: 0, totalMinutes: 0, totalWage: 0, averageRate: 0 };
  @State selectedTab: number = 0;
  @State showEditor: boolean = false;
  @State saving: boolean = false;
  @State draft: WorkRecord = emptyRecord(todayText());
  @State errorText: string = '';

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    workRecordStore.init(context)
      .then(() => this.refresh())
      .catch((error: Error) => this.showError(`数据库初始化失败：${error.message}`));
  }

  async refresh(): Promise<void> {
    try {
      this.records = await workRecordStore.listByMonth(this.selectedMonth);
      this.summary = await workRecordStore.summary(this.selectedMonth);
    } catch (error) {
      this.showError(`读取失败：${(error as Error).message}`);
    }
  }

  showError(message: string): void {
    promptAction.showToast({ message: message, duration: 2500 });
  }

  changeMonth(offset: number): void {
    const parts = this.selectedMonth.split('-');
    const date = new Date(Number(parts[0]), Number(parts[1]) - 1 + offset, 1);
    this.selectedMonth = monthText(date);
    this.refresh();
  }

  openNew(): void {
    const today = todayText();
    const date = today.startsWith(this.selectedMonth) ? today : `${this.selectedMonth}-01`;
    this.draft = emptyRecord(date);
    this.errorText = '';
    this.showEditor = true;
  }

  openEdit(record: WorkRecord): void {
    this.draft = cloneRecord(record);
    this.errorText = '';
    this.showEditor = true;
  }

  updateCalculation(): void {
    this.draft.workMinutes = calculateMinutes(
      this.draft.startTime,
      this.draft.endTime,
      this.draft.breakMinutes
    );
    this.draft.wage = this.draft.workMinutes / 60 * this.draft.hourlyRate;
  }

  validate(): boolean {
    if (!isValidDate(this.draft.workDate)) {
      this.errorText = '请输入有效日期，格式为 YYYY-MM-DD';
      return false;
    }
    if (!isValidTime(this.draft.startTime) || !isValidTime(this.draft.endTime)) {
      this.errorText = '时间格式应为 HH:mm（例如 09:30）';
      return false;
    }
    if (this.draft.breakMinutes < 0 || this.draft.hourlyRate < 0) {
      this.errorText = '休息时间和时薪不能为负数';
      return false;
    }
    this.updateCalculation();
    if (this.draft.workMinutes <= 0) {
      this.errorText = '有效工作时长必须大于 0';
      return false;
    }
    this.errorText = '';
    return true;
  }

  async save(): Promise<void> {
    if (!this.validate() || this.saving) {
      return;
    }
    this.saving = true;
    try {
      if (this.draft.id === 0) {
        await workRecordStore.insert(this.draft);
      } else {
        await workRecordStore.update(this.draft);
      }
      this.selectedMonth = this.draft.workDate.substring(0, 7);
      this.showEditor = false;
      await this.refresh();
      promptAction.showToast({ message: '已保存' });
    } catch (error) {
      this.errorText = `保存失败：${(error as Error).message}`;
    } finally {
      this.saving = false;
    }
  }

  confirmDelete(record: WorkRecord): void {
    AlertDialog.show({
      title: '删除这条记录？',
      message: `${record.workDate}  ${record.startTime}–${record.endTime}`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: COLORS.danger,
        action: async () => {
          try {
            await workRecordStore.remove(record.id);
            await this.refresh();
            promptAction.showToast({ message: '已删除' });
          } catch (error) {
            this.showError(`删除失败：${(error as Error).message}`);
          }
        }
      }
    });
  }

  @Builder
  MonthSwitcher() {
    Row() {
      Button('‹')
        .fontSize(28)
        .fontColor(COLORS.primary)
        .backgroundColor(Color.Transparent)
        .width(48)
        .onClick(() => this.changeMonth(-1))
      Column({ space: 2 }) {
        Text(monthTitle(this.selectedMonth))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.text)
        Text('工资与工时')
          .fontSize(12)
          .fontColor(COLORS.secondary)
      }
      .layoutWeight(1)
      Button('›')
        .fontSize(28)
        .fontColor(COLORS.primary)
        .backgroundColor(Color.Transparent)
        .width(48)
        .onClick(() => this.changeMonth(1))
    }
    .width('100%')
    .padding({ top: 10, bottom: 12 })
  }

  @Builder
  SummaryHero() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('本月预计工资')
            .fontSize(13)
            .fontColor('#D8EEE8')
          Text(`¥ ${this.summary.totalWage.toFixed(2)}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('账本')
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('#3D7A6F')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(18)
      }
      Divider().color('#4A8177')
      Row() {
        this.HeroMetric('出勤', `${this.summary.days} 天`)
        this.HeroMetric('总工时', formatDuration(this.summary.totalMinutes))
        this.HeroMetric('记录', `${this.records.length} 条`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLORS.primary)
    .borderRadius(22)
  }

  @Builder
  HeroMetric(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label).fontSize(12).fontColor('#C7E2DC')
      Text(value).fontSize(15).fontWeight(FontWeight.Medium).fontColor(Color.White)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  TabBar() {
    Row() {
      this.TabButton('每日记录', 0)
      this.TabButton('月度统计', 1)
    }
    .width('100%')
    .height(48)
    .padding(4)
    .backgroundColor('#E8ECE7')
    .borderRadius(14)
  }

  @Builder
  TabButton(label: string, index: number) {
    Button(label)
      .fontSize(15)
      .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedTab === index ? COLORS.primary : COLORS.secondary)
      .backgroundColor(this.selectedTab === index ? Color.White : Color.Transparent)
      .borderRadius(11)
      .layoutWeight(1)
      .height(40)
      .onClick(() => this.selectedTab = index)
  }

  @Builder
  EmptyView() {
    Column({ space: 12 }) {
      Text('◷').fontSize(54).fontColor('#A9B9B3')
      Text('这个月还没有工时记录')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLORS.text)
      Text('点击下方按钮，记下第一天的工作')
        .fontSize(13)
        .fontColor(COLORS.secondary)
      Button('新增工时')
        .fontColor(Color.White)
        .backgroundColor(COLORS.primary)
        .margin({ top: 8 })
        .onClick(() => this.openNew())
    }
    .width('100%')
    .padding({ top: 52, bottom: 40 })
  }

  @Builder
  RecordCard(record: WorkRecord) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(dayTitle(record.workDate))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLORS.text)
          Text(`${record.startTime} – ${record.endTime}  ·  休息${record.breakMinutes}分钟`)
            .fontSize(13)
            .fontColor(COLORS.secondary)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 3 }) {
          Text(`¥${record.wage.toFixed(2)}`)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLORS.primary)
          Text(`¥${record.hourlyRate.toFixed(2)}/时`)
            .fontSize(11)
            .fontColor(COLORS.secondary)
        }
        .alignItems(HorizontalAlign.End)
      }
      Row() {
        Text(formatDuration(record.workMinutes))
          .fontSize(13)
          .fontColor(COLORS.primary)
          .backgroundColor(COLORS.primarySoft)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
        if (record.note.length > 0) {
          Text(record.note)
            .fontSize(12)
            .fontColor(COLORS.secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 9 })
            .layoutWeight(1)
        } else {
          Blank().layoutWeight(1)
        }
        Button('编辑')
          .fontSize(13)
          .fontColor(COLORS.primary)
          .backgroundColor(Color.Transparent)
          .height(32)
          .onClick(() => this.openEdit(record))
        Button('删除')
          .fontSize(13)
          .fontColor(COLORS.danger)
          .backgroundColor(Color.Transparent)
          .height(32)
          .onClick(() => this.confirmDelete(record))
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLORS.card)
    .borderRadius(18)
    .shadow({ radius: 10, color: '#10000000', offsetY: 3 })
  }

  @Builder
  StatisticsView() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        this.StatCard('平均时薪', `¥${this.summary.averageRate.toFixed(2)}`, '每小时')
        this.StatCard('平均日薪', `¥${(this.summary.days > 0 ? this.summary.totalWage / this.summary.days : 0).toFixed(2)}`, '每个出勤日')
      }
      Row({ space: 12 }) {
        this.StatCard('平均每天', formatDuration(this.summary.days > 0 ? Math.round(this.summary.totalMinutes / this.summary.days) : 0), '工作时长')
        this.StatCard('合计工时', (this.summary.totalMinutes / 60).toFixed(1), '小时')
      }
      Column({ space: 12 }) {
        Row() {
          Text('工资构成').fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
          Blank()
          Text(`${this.records.length} 笔`).fontSize(13).fontColor(COLORS.secondary)
        }
        if (this.records.length === 0) {
          Text('暂无数据').fontSize(14).fontColor(COLORS.secondary).padding(24)
        } else {
          ForEach(this.records.slice(0, 8), (record: WorkRecord) => {
            Row() {
              Text(dayTitle(record.workDate)).fontSize(13).fontColor(COLORS.text).width(74)
              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .height(8)
                  .width(`${Math.max(8, record.wage / Math.max(1, this.summary.totalWage) * 100)}%`)
                  .backgroundColor(COLORS.accent)
                  .borderRadius(4)
              }
              .height(8)
              .layoutWeight(1)
              .backgroundColor('#F2EEE6')
              .borderRadius(4)
              Text(`¥${record.wage.toFixed(0)}`)
                .fontSize(13)
                .fontColor(COLORS.secondary)
                .width(62)
                .textAlign(TextAlign.End)
            }
            .width('100%')
          }, (record: WorkRecord) => record.id.toString())
        }
      }
      .width('100%')
      .padding(17)
      .backgroundColor(Color.White)
      .borderRadius(18)
    }
    .width('100%')
  }

  @Builder
  StatCard(label: string, value: string, unit: string) {
    Column({ space: 5 }) {
      Text(label).fontSize(12).fontColor(COLORS.secondary)
      Text(value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(COLORS.text).maxLines(1)
      Text(unit).fontSize(11).fontColor('#95A09C')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .height(105)
    .padding(15)
    .backgroundColor(Color.White)
    .borderRadius(17)
  }

  @Builder
  FieldLabel(label: string, hint: string) {
    Row() {
      Text(label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(COLORS.text)
      Blank()
      Text(hint).fontSize(11).fontColor('#98A19E')
    }
    .width('100%')
  }

  @Builder
  Editor() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(15)
          .fontColor(COLORS.secondary)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.showEditor = false)
        Text(this.draft.id === 0 ? '新增工时' : '编辑工时')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button(this.saving ? '保存中' : '保存')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.primary)
          .backgroundColor(Color.Transparent)
          .enabled(!this.saving)
          .onClick(() => this.save())
      }
      .width('100%')
      .height(58)
      .padding({ left: 4, right: 4 })
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 20 }) {
          Column({ space: 8 }) {
            this.FieldLabel('工作日期', 'YYYY-MM-DD')
            TextInput({ text: this.draft.workDate, placeholder: '2026-08-10' })
              .height(48)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .onChange((value: string) => this.draft.workDate = value)
          }
          Row({ space: 12 }) {
            Column({ space: 8 }) {
              this.FieldLabel('开始时间', 'HH:mm')
              TextInput({ text: this.draft.startTime, placeholder: '09:00' })
                .height(48)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.draft.startTime = value;
                  this.updateCalculation();
                })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 8 }) {
              this.FieldLabel('结束时间', 'HH:mm')
              TextInput({ text: this.draft.endTime, placeholder: '17:00' })
                .height(48)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.draft.endTime = value;
                  this.updateCalculation();
                })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          Row({ space: 12 }) {
            Column({ space: 8 }) {
              this.FieldLabel('休息', '分钟')
              TextInput({ text: this.draft.breakMinutes.toString(), placeholder: '0' })
                .type(InputType.Number)
                .height(48)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.draft.breakMinutes = Number(value) || 0;
                  this.updateCalculation();
                })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 8 }) {
              this.FieldLabel('时薪', '元/小时')
              TextInput({ text: this.draft.hourlyRate.toString(), placeholder: '30' })
                .type(InputType.Number)
                .height(48)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .onChange((value: string) => {
                  this.draft.hourlyRate = Number(value) || 0;
                  this.updateCalculation();
                })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          Column({ space: 8 }) {
            this.FieldLabel('备注', '选填')
            TextInput({ text: this.draft.note, placeholder: '例如：张阿姨家、加班等' })
              .height(48)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .onChange((value: string) => this.draft.note = value)
          }
          Row() {
            Column({ space: 4 }) {
              Text('本次有效工时').fontSize(12).fontColor('#D0E7E1')
              Text(formatDuration(this.draft.workMinutes))
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Column({ space: 4 }) {
              Text('预计工资').fontSize(12).fontColor('#D0E7E1')
              Text(`¥ ${this.draft.wage.toFixed(2)}`)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }.alignItems(HorizontalAlign.End)
          }
          .width('100%')
          .padding(18)
          .backgroundColor(COLORS.primary)
          .borderRadius(17)
          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(13)
              .fontColor(COLORS.danger)
              .width('100%')
          }
          Button('保存记录')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .backgroundColor(COLORS.primary)
            .enabled(!this.saving)
            .onClick(() => this.save())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 22, bottom: 40 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.background)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.showEditor) {
        this.Editor()
      } else {
        Column() {
          Scroll() {
            Column({ space: 16 }) {
              this.MonthSwitcher()
              this.SummaryHero()
              this.TabBar()
              if (this.selectedTab === 0) {
                if (this.records.length === 0) {
                  this.EmptyView()
                } else {
                  Column({ space: 12 }) {
                    ForEach(this.records, (record: WorkRecord) => {
                      this.RecordCard(record)
                    }, (record: WorkRecord) => record.id.toString())
                  }.width('100%')
                }
              } else {
                this.StatisticsView()
              }
              Blank().height(88)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor(COLORS.background)

        Button('+')
          .width(58)
          .height(58)
          .fontSize(30)
          .fontColor(Color.White)
          .backgroundColor(COLORS.accent)
          .borderRadius(29)
          .shadow({ radius: 12, color: '#40000000', offsetY: 5 })
          .margin({ right: 20, bottom: 24 })
          .onClick(() => this.openNew())
      }
    }
    .width('100%')
    .height('100%')
  }
}
