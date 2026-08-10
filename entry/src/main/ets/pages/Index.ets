import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { workRecordStore } from '../database/WorkRecordStore';
import {
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
  return dateText(new Date());
}

function dateText(date: Date): string {
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

function weekDayText(value: string): string {
  const parts = value.split('-');
  if (parts.length !== 3) {
    return '';
  }
  const labels: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  return labels[date.getDay()];
}

function cloneRecord(record: WorkRecord): WorkRecord {
  return {
    id: record.id,
    workDate: record.workDate,
    period: record.period,
    hours: record.hours,
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

function isValidHoursInput(value: string): boolean {
  if (value.length === 0) {
    return true;
  }
  let decimalIndex = -1;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    if (code === 46 && decimalIndex < 0) {
      decimalIndex = index;
    } else if (code < 48 || code > 57) {
      return false;
    }
  }
  return decimalIndex < 0 || value.length - decimalIndex - 1 <= 1;
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
  @State hoursInput: string = '4.0';
  @State errorText: string = '';

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    workRecordStore.init(context)
      .then(() => this.refresh())
      .catch((error: Error) => this.showError(`数据库初始化失败：${error.message}`));
  }

  onBackPress(): boolean {
    if (this.showEditor) {
      this.showEditor = false;
      this.errorText = '';
      return true;
    }
    return false;
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

  async openNew(): Promise<void> {
    const today = todayText();
    const date = today.startsWith(this.selectedMonth) ? today : `${this.selectedMonth}-01`;
    const draft = emptyRecord(date);
    try {
      const defaults = await workRecordStore.getDefaults();
      if (defaults) {
        draft.period = defaults.period;
        draft.hours = defaults.hours;
        draft.hourlyRate = defaults.hourlyRate;
        draft.workMinutes = Math.round(draft.hours * 60);
        draft.wage = draft.hours * draft.hourlyRate;
      }
    } catch (error) {
      this.showError(`读取上次记录失败：${(error as Error).message}`);
    }
    this.draft = draft;
    this.hoursInput = draft.hours.toFixed(1);
    this.errorText = '';
    this.showEditor = true;
  }

  openEdit(record: WorkRecord): void {
    this.draft = cloneRecord(record);
    this.hoursInput = record.hours.toFixed(1);
    this.errorText = '';
    this.showEditor = true;
  }

  updateCalculation(): void {
    this.draft.workMinutes = Math.round(this.draft.hours * 60);
    this.draft.wage = this.draft.hours * this.draft.hourlyRate;
  }

  showDatePicker(): void {
    let selected = new Date();
    if (isValidDate(this.draft.workDate)) {
      const parts = this.draft.workDate.split('-');
      selected = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    CalendarPickerDialog.show({
      selected: selected,
      markToday: true,
      onAccept: (value: Date) => {
        this.draft.workDate = dateText(value);
        this.errorText = '';
      }
    });
  }

  updateHoursInput(value: string): void {
    if (!isValidHoursInput(value)) {
      return;
    }
    this.hoursInput = value;
    const hours = Number(value);
    if (!Number.isNaN(hours) && hours >= 0) {
      this.draft.hours = hours;
      this.updateCalculation();
    }
  }

  adjustHours(direction: number): void {
    const inputValue = Number(this.hoursInput);
    const current = Number.isNaN(inputValue) ? this.draft.hours : inputValue;
    let adjusted = 0.5;
    if (direction > 0) {
      adjusted = Math.floor(current * 2 + 0.000001) / 2 + 0.5;
    } else {
      adjusted = Math.max(0.5, Math.ceil(current * 2 - 0.000001) / 2 - 0.5);
    }
    this.draft.hours = Math.round(adjusted * 10) / 10;
    this.hoursInput = this.draft.hours.toFixed(1);
    this.updateCalculation();
  }

  validate(): boolean {
    if (!isValidDate(this.draft.workDate)) {
      this.errorText = '请输入有效日期，格式为 YYYY-MM-DD';
      return false;
    }
    const inputHours = Number(this.hoursInput);
    if (Number.isNaN(inputHours) || inputHours <= 0 || inputHours > 24) {
      this.errorText = '工时请输入大于0且不超过24的数字';
      return false;
    }
    if (this.draft.hourlyRate < 0) {
      this.errorText = '时薪不能为负数';
      return false;
    }
    this.draft.hours = Math.round(inputHours * 10) / 10;
    this.hoursInput = this.draft.hours.toFixed(1);
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
      message: `${record.workDate}  ${record.period} ${record.hours.toFixed(1)}小时`,
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
    .padding({ top: 28, bottom: 40 })
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
          Text(`${record.period}  ·  ${record.hours.toFixed(1)}小时`)
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
            this.FieldLabel('工作日期', '点击选择')
            Row() {
              Text(`${this.draft.workDate}  ${weekDayText(this.draft.workDate)}`)
                .fontSize(16)
                .fontColor(COLORS.text)
              Blank()
              Text('日历  ›')
                .fontSize(14)
                .fontColor(COLORS.primary)
            }
              .width('100%')
              .height(48)
              .padding({ left: 14, right: 14 })
              .backgroundColor(Color.White)
              .borderRadius(12)
              .onClick(() => this.showDatePicker())
          }
          Column({ space: 8 }) {
            this.FieldLabel('工作时段', '选择上午或下午')
            Row({ space: 8 }) {
              Button('上午')
                .layoutWeight(1)
                .height(44)
                .fontColor(this.draft.period === '上午' ? Color.White : COLORS.primary)
                .backgroundColor(this.draft.period === '上午' ? COLORS.primary : COLORS.primarySoft)
                .borderRadius(12)
                .onClick(() => this.draft.period = '上午')
              Button('下午')
                .layoutWeight(1)
                .height(44)
                .fontColor(this.draft.period === '下午' ? Color.White : COLORS.primary)
                .backgroundColor(this.draft.period === '下午' ? COLORS.primary : COLORS.primarySoft)
                .borderRadius(12)
                .onClick(() => this.draft.period = '下午')
            }
            .width('100%')
          }
          Row({ space: 12 }) {
            Column({ space: 8 }) {
              this.FieldLabel('工作时长', '小时')
              Row({ space: 6 }) {
                TextInput({ text: this.hoursInput, placeholder: '4.0' })
                  .layoutWeight(1)
                  .maxLength(4)
                  .height(48)
                  .backgroundColor(Color.White)
                  .borderRadius(12)
                  .onChange((value: string) => this.updateHoursInput(value))
                Column() {
                  Button('▲')
                    .width(44)
                    .height(24)
                    .fontSize(12)
                    .fontColor(COLORS.primary)
                    .backgroundColor(COLORS.primarySoft)
                    .borderRadius({ topLeft: 10, topRight: 10 })
                    .onClick(() => this.adjustHours(1))
                  Button('▼')
                    .width(44)
                    .height(24)
                    .fontSize(12)
                    .fontColor(COLORS.primary)
                    .backgroundColor(COLORS.primarySoft)
                    .borderRadius({ bottomLeft: 10, bottomRight: 10 })
                    .onClick(() => this.adjustHours(-1))
                }
                .height(48)
              }
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
              Text(`${this.draft.period}工时`).fontSize(12).fontColor('#D0E7E1')
              Text(`${this.draft.hours.toFixed(1)} 小时`)
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
          Column({ space: 16 }) {
            this.MonthSwitcher()
            this.SummaryHero()
            this.TabBar()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })

          Scroll() {
            Column() {
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
            .constraintSize({ minHeight: '100%' })
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, right: 16 })
          }
          .width('100%')
          .layoutWeight(1)
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
