export const locales = ["en", "zh"] as const;

export type Locale = (typeof locales)[number];

export type Dictionary = typeof dictionaries.en;

export function normalizeLocale(value: string | undefined | null): Locale {
  return value === "zh" ? "zh" : "en";
}

export function labelStatus(value: string, locale: Locale) {
  const labels = dictionaries[locale].statusLabels;
  return labels[value as keyof typeof labels] ?? value.replaceAll("_", " ");
}

export function localizeFallback(value: string, locale: Locale) {
  if (locale === "en") {
    return value;
  }

  return dictionaries.zh.fallbacks[value as keyof typeof dictionaries.zh.fallbacks] ?? value;
}

export const dictionaries = {
  en: {
    languageName: "English",
    nav: {
      tournaments: "Tournaments",
      myGames: "My Games",
      today: "Today",
      organizer: "Organizer",
      rules: "Rules"
    },
    common: {
      open: "Open",
      manage: "Manage",
      public: "Public",
      account: "Account",
      mobileApp: "Mobile app",
      tbd: "TBD",
      datesTbd: "Dates TBD",
      homeTbd: "Home TBD",
      awayTbd: "Away TBD",
      venueTbd: "Venue TBD",
      fieldTbd: "Field TBD",
      addressTbd: "Address TBD",
      independent: "Independent",
      unassignedTeam: "Unassigned team",
      final: "Final",
      mainNavigation: "Main navigation"
    },
    notFound: {
      title: "Page not found",
      lead: "The requested page could not be found.",
      action: "Back to home"
    },
    home: {
      eyebrow: "Tournament platform",
      lead:
        "A web and mobile-supported operating system for tournament registration, rosters, waivers, schedules, check-in, score reporting, and standings.",
      openActive: "Open active tournament",
      viewTournaments: "View tournaments",
      organizerConsole: "Organizer console",
      activeEvent: "Active event",
      divisions: "divisions",
      registrations: "registrations",
      areas: "Platform areas",
      registrationTitle: "Registration",
      registrationBody: "Register a team for the active event, choose a division, and submit the player roster.",
      registrationAction: "Start registration",
      scheduleTitle: "Schedule",
      scheduleBody: "View published games, field assignments, opponents, and score status.",
      scheduleAction: "View schedule",
      operationsTitle: "Event Operations",
      operationsBody: "Open organizer tools for registration review, check-in, scores, and standings.",
      operationsAction: "Open organizer"
    },
    tournaments: {
      title: "Tournaments",
      lead: "Browse active AAYSA Sports tournament operations.",
      sessions: "sessions"
    },
    tournamentDetail: {
      registerTeam: "Register team",
      viewSchedule: "View schedule",
      eventWindow: "Event window",
      teamPrice: "Team price starts at {price} before promo codes and processing fees.",
      teams: "Teams",
      standings: "Standings",
      venue: "Venue",
      divisions: "Divisions",
      roster: "roster",
      sessions: "Sessions",
      operations: "Operations",
      registrationsTracked: "{count} team registrations are currently tracked for this event."
    },
    registrationPage: {
      eyebrow: "Registration",
      lead:
        "Submit team manager details, division, roster, guardian waiver status, promo code, and payment readiness."
    },
    schedule: {
      title: "Schedule",
      lead: "Published games, fields, opponents, and score status."
    },
    teams: {
      title: "Teams",
      lead: "Public team registration status summary."
    },
    standings: {
      title: "Standings",
      organizerTitle: "Organizer standings",
      lead: "Win 3, draw 1, loss 0. Tie-breakers: points, goal difference, goals for, team name.",
      organizerLead: "Current computed standings after final scores.",
      team: "Team",
      division: "Division",
      played: "Played",
      wins: "W",
      draws: "D",
      losses: "L",
      goalsFor: "GF",
      goalsAgainst: "GA",
      goalDiff: "GD",
      points: "Pts"
    },
    venue: {
      title: "Venue",
      lead: "Venue and field setup for event-day navigation."
    },
    organizer: {
      title: "Organizer",
      lead: "Registration readiness, schedule management, check-in, scores, and standings.",
      tournaments: "Tournaments",
      tournamentsBody: "Review event setup, sessions, venues, registrations, and operational status.",
      viewTournaments: "View tournaments",
      registrations: "Registrations",
      registrationsBody: "Track roster counts, payment status, waiver completion, and eligibility readiness.",
      eventDay: "Event day",
      eventDayBody: "Publish schedules, check teams in, enter scores, and update standings.",
      currentEvent: "Current event",
      registrationCount: "{count} registrations",
      tournamentLead: "Event setup and operating status.",
      registrationsTracked: "{count} registrations tracked.",
      reviewRegistrations: "Review registrations",
      schedule: "Schedule",
      gamesConfigured: "{count} games configured.",
      manageSchedule: "Manage schedule",
      openCheckIn: "Open check-in",
      notifications: "Notifications",
      recentActivity: "Recent activity",
      scores: "Scores",
      standings: "Standings",
      registrationsTitle: "Organizer registrations",
      registrationsLead: "Readiness table: team, division, roster, payment, waivers, eligibility, status.",
      scheduleTitle: "Organizer schedule",
      scheduleLead: "Published games and field assignments.",
      checkInTitle: "Check-in",
      checkInLead: "QR and manual check-in will write to CheckIn records. First version exposes readiness before scanning.",
      scoresLead: "Enter final scores. Saving a score updates standings and records a score notification."
    },
    accountPages: {
      accountTitle: "Account",
      accountLead: "Authentication and family/team linking will connect here in the next implementation pass.",
      athletesTitle: "My Athletes",
      athletesLead: "Registered athletes will appear here after account ownership and guardian access are connected.",
      gamesTitle: "My Games",
      gamesLead: "Personalized schedules will filter by authenticated family or team after auth is connected.",
      teamsTitle: "My Teams",
      teamsLead: "Team manager registrations and roster management will appear here after login is connected.",
      waiversTitle: "Waivers",
      waiversLead: "Guardian waiver records are stored with legal version, signer identity, timestamp, and request metadata.",
      todayTitle: "Today",
      todayLead: "Event-day app entry for games, venues, check-in, alerts, and sharing."
    },
    rules: {
      title: "Rules",
      lead: "Operational rules for AAYSA Sports tournament registration, eligibility, waivers, refunds, and standings.",
      rosterTitle: "Roster",
      rosterBody: "5v5 teams must submit 5 to 7 players. Teams outside that range require organizer review.",
      waiversTitle: "Waivers",
      waiversBody: "Each player needs a guardian waiver acceptance tied to the active legal document version.",
      standingsTitle: "Standings",
      standingsBody: "Default points are win 3, draw 1, loss 0. Sorting uses points, goal difference, goals for, then team name."
    },
    registrationForm: {
      step1: "Step 1",
      step2: "Step 2",
      steps34: "Steps 3-4",
      steps56: "Steps 5-6",
      teamManager: "Team manager",
      name: "Name",
      email: "Email",
      phone: "Phone",
      teamAndDivision: "Team and division",
      teamName: "Team name",
      club: "Club or organization",
      division: "Division",
      rosterHint: "Roster {min}-{max} players. DOB range {start} to {end}.",
      openDate: "open",
      rosterWaivers: "Roster and waivers",
      addPlayer: "Add player",
      player: "Player {index}",
      firstName: "First name",
      lastName: "Last name",
      dob: "Date of birth",
      guardianName: "Guardian name",
      guardianEmail: "Guardian email",
      waiverAccepted: "Guardian waiver accepted",
      removePlayer: "Remove player",
      reviewPayment: "Review and payment",
      teamFee: "Team fee {amount}",
      processingFee: "Processing fee {amount}",
      stripePending: "Stripe checkout pending integration",
      promoCode: "Promo code",
      submitting: "Submitting...",
      submit: "Submit registration",
      submitError: "Registration could not be submitted.",
      submitSuccess: "Registration {id} created. Status: {status}. Balance: {balance}."
    },
    table: {
      noRegistrations: "No registrations yet.",
      team: "Team",
      division: "Division",
      roster: "Roster",
      payment: "Payment",
      waivers: "Waivers",
      eligibility: "Eligibility",
      status: "Status",
      ready: "READY"
    },
    scoreForm: {
      homeScore: "Home score",
      awayScore: "Away score",
      saving: "Saving...",
      saved: "Score saved. Refresh to see standings.",
      failed: "Score could not be saved.",
      save: "Save"
    },
    apiErrors: {
      missingRegistrationFields: "Missing required registration fields",
      tournamentNotFound: "Tournament not found",
      divisionNotFound: "Division not found",
      rosterSize: "Roster must include {min} to {max} players",
      invalidScores: "Scores must be non-negative integers",
      gameNotFound: "Game not found or missing teams"
    },
    paymentLabels: {
      paid: "Paid",
      refunded: "Refunded",
      failed: "Failed",
      pending: "Pending",
      notStarted: "Not started"
    },
    statusLabels: {
      DRAFT: "Draft",
      PENDING_PAYMENT: "Pending payment",
      PAID: "Paid",
      WAIVER_INCOMPLETE: "Waiver incomplete",
      ELIGIBILITY_REVIEW: "Eligibility review",
      READY: "Ready",
      CANCELLED: "Cancelled",
      REFUNDED: "Refunded",
      REGISTRATION_OPEN: "Registration open",
      REGISTRATION_CLOSED: "Registration closed",
      SCHEDULED: "Scheduled",
      LIVE: "Live",
      COMPLETED: "Completed",
      FINAL: "Final",
      IN_PROGRESS: "In progress",
      FORFEIT: "Forfeit",
      MISSING: "Missing",
      SIGNED: "Signed",
      PENDING: "Pending",
      ELIGIBLE: "Eligible",
      INELIGIBLE: "Ineligible",
      OVERRIDDEN: "Overridden",
      SUCCEEDED: "Succeeded",
      FAILED: "Failed",
      COMPED: "Comped"
    },
    fallbacks: {}
  },
  zh: {
    languageName: "中文",
    nav: {
      tournaments: "赛事",
      myGames: "我的比赛",
      today: "今日",
      organizer: "组织者",
      rules: "规则"
    },
    common: {
      open: "打开",
      manage: "管理",
      public: "公开",
      account: "账户",
      mobileApp: "移动 App",
      tbd: "待定",
      datesTbd: "日期待定",
      homeTbd: "主队待定",
      awayTbd: "客队待定",
      venueTbd: "场馆待定",
      fieldTbd: "场地待定",
      addressTbd: "地址待定",
      independent: "独立球队",
      unassignedTeam: "未分配球队",
      final: "完赛",
      mainNavigation: "主导航"
    },
    notFound: {
      title: "页面不存在",
      lead: "没有找到你请求的页面。",
      action: "返回首页"
    },
    home: {
      eyebrow: "赛事平台",
      lead: "面向网页和移动端的 AAYSA Sports 赛事运营系统，覆盖报名、名单、免责声明、赛程、签到、比分和排名。",
      openActive: "打开当前赛事",
      viewTournaments: "查看赛事",
      organizerConsole: "组织者控制台",
      activeEvent: "当前赛事",
      divisions: "个组别",
      registrations: "个报名",
      areas: "平台模块",
      registrationTitle: "报名",
      registrationBody: "为当前赛事报名队伍，选择组别并提交球员名单。",
      registrationAction: "开始报名",
      scheduleTitle: "赛程",
      scheduleBody: "查看已发布的比赛、场地分配、对阵和比分状态。",
      scheduleAction: "查看赛程",
      operationsTitle: "赛事运营",
      operationsBody: "进入组织者工具，审核报名、签到、录入比分并查看排名。",
      operationsAction: "打开组织者后台"
    },
    tournaments: {
      title: "赛事",
      lead: "浏览正在运营的 AAYSA Sports 赛事。",
      sessions: "个场次"
    },
    tournamentDetail: {
      registerTeam: "报名队伍",
      viewSchedule: "查看赛程",
      eventWindow: "赛事日期",
      teamPrice: "队伍费用从 {price} 起，优惠码和手续费另计。",
      teams: "队伍",
      standings: "排名",
      venue: "场馆",
      divisions: "组别",
      roster: "名单",
      sessions: "场次",
      operations: "运营",
      registrationsTracked: "当前赛事已记录 {count} 个队伍报名。"
    },
    registrationPage: {
      eyebrow: "报名",
      lead: "提交队伍负责人、组别、球员名单、监护人免责声明状态、优惠码和付款状态。"
    },
    schedule: {
      title: "赛程",
      lead: "已发布的比赛、场地、对阵和比分状态。"
    },
    teams: {
      title: "队伍",
      lead: "公开队伍报名状态摘要。"
    },
    standings: {
      title: "排名",
      organizerTitle: "组织者排名",
      lead: "胜 3 分，平 1 分，负 0 分。排序按积分、净胜球、进球数、队名。",
      organizerLead: "最终比分录入后的当前排名。",
      team: "队伍",
      division: "组别",
      played: "场次",
      wins: "胜",
      draws: "平",
      losses: "负",
      goalsFor: "进球",
      goalsAgainst: "失球",
      goalDiff: "净胜",
      points: "积分"
    },
    venue: {
      title: "场馆",
      lead: "赛事日导航所需的场馆和场地设置。"
    },
    organizer: {
      title: "组织者",
      lead: "管理报名准备状态、赛程、签到、比分和排名。",
      tournaments: "赛事",
      tournamentsBody: "查看赛事设置、场次、场馆、报名和运营状态。",
      viewTournaments: "查看赛事",
      registrations: "报名",
      registrationsBody: "追踪名单人数、付款状态、免责声明完成度和资格状态。",
      eventDay: "赛事日",
      eventDayBody: "发布赛程、队伍签到、录入比分并更新排名。",
      currentEvent: "当前赛事",
      registrationCount: "{count} 个报名",
      tournamentLead: "赛事设置和运营状态。",
      registrationsTracked: "已追踪 {count} 个报名。",
      reviewRegistrations: "查看报名",
      schedule: "赛程",
      gamesConfigured: "已配置 {count} 场比赛。",
      manageSchedule: "管理赛程",
      openCheckIn: "打开签到",
      notifications: "通知",
      recentActivity: "近期动态",
      scores: "比分",
      standings: "排名",
      registrationsTitle: "组织者报名",
      registrationsLead: "准备状态表：队伍、组别、名单、付款、免责声明、资格、状态。",
      scheduleTitle: "组织者赛程",
      scheduleLead: "已发布的比赛和场地分配。",
      checkInTitle: "签到",
      checkInLead: "二维码和手动签到会写入 CheckIn 记录。第一版先展示扫描前的准备状态。",
      scoresLead: "录入最终比分。保存比分会更新排名并记录比分通知。"
    },
    accountPages: {
      accountTitle: "账户",
      accountLead: "下一步会在这里接入登录以及家庭/队伍关联。",
      athletesTitle: "我的运动员",
      athletesLead: "接入账户归属和监护人权限后，已注册运动员会显示在这里。",
      gamesTitle: "我的比赛",
      gamesLead: "接入登录后，将按家庭或队伍筛选个性化赛程。",
      teamsTitle: "我的队伍",
      teamsLead: "登录接入后，队伍负责人报名和名单管理会显示在这里。",
      waiversTitle: "免责声明",
      waiversLead: "监护人免责声明记录会保存法律版本、签署人身份、时间戳和请求信息。",
      todayTitle: "今日",
      todayLead: "赛事日 App 入口，用于查看比赛、场馆、签到、提醒和分享。"
    },
    rules: {
      title: "规则",
      lead: "AAYSA Sports 赛事报名、资格、免责声明、退款和排名运营规则。",
      rosterTitle: "名单",
      rosterBody: "5v5 队伍必须提交 5 到 7 名球员。超出范围的队伍需要组织者审核。",
      waiversTitle: "免责声明",
      waiversBody: "每名球员都需要监护人接受当前法律文件版本对应的免责声明。",
      standingsTitle: "排名",
      standingsBody: "默认积分：胜 3、平 1、负 0。排序按积分、净胜球、进球数、队名。"
    },
    registrationForm: {
      step1: "第 1 步",
      step2: "第 2 步",
      steps34: "第 3-4 步",
      steps56: "第 5-6 步",
      teamManager: "队伍负责人",
      name: "姓名",
      email: "邮箱",
      phone: "电话",
      teamAndDivision: "队伍和组别",
      teamName: "队伍名称",
      club: "俱乐部或组织",
      division: "组别",
      rosterHint: "名单 {min}-{max} 人。出生日期范围 {start} 至 {end}。",
      openDate: "开放",
      rosterWaivers: "名单和免责声明",
      addPlayer: "添加球员",
      player: "球员 {index}",
      firstName: "名",
      lastName: "姓",
      dob: "出生日期",
      guardianName: "监护人姓名",
      guardianEmail: "监护人邮箱",
      waiverAccepted: "监护人已接受免责声明",
      removePlayer: "移除球员",
      reviewPayment: "确认和付款",
      teamFee: "队伍费用 {amount}",
      processingFee: "手续费 {amount}",
      stripePending: "Stripe Checkout 待接入",
      promoCode: "优惠码",
      submitting: "提交中...",
      submit: "提交报名",
      submitError: "报名无法提交。",
      submitSuccess: "报名 {id} 已创建。状态：{status}。余额：{balance}。"
    },
    table: {
      noRegistrations: "暂无报名。",
      team: "队伍",
      division: "组别",
      roster: "名单",
      payment: "付款",
      waivers: "免责声明",
      eligibility: "资格",
      status: "状态",
      ready: "已就绪"
    },
    scoreForm: {
      homeScore: "主队比分",
      awayScore: "客队比分",
      saving: "保存中...",
      saved: "比分已保存。刷新后查看排名。",
      failed: "比分无法保存。",
      save: "保存"
    },
    apiErrors: {
      missingRegistrationFields: "缺少必填报名字段",
      tournamentNotFound: "未找到赛事",
      divisionNotFound: "未找到组别",
      rosterSize: "名单必须包含 {min} 到 {max} 名球员",
      invalidScores: "比分必须是非负整数",
      gameNotFound: "未找到比赛或比赛缺少队伍"
    },
    paymentLabels: {
      paid: "已付款",
      refunded: "已退款",
      failed: "失败",
      pending: "待付款",
      notStarted: "未开始"
    },
    statusLabels: {
      DRAFT: "草稿",
      PENDING_PAYMENT: "待付款",
      PAID: "已付款",
      WAIVER_INCOMPLETE: "免责声明未完成",
      ELIGIBILITY_REVIEW: "资格审核",
      READY: "已就绪",
      CANCELLED: "已取消",
      REFUNDED: "已退款",
      REGISTRATION_OPEN: "报名开放",
      REGISTRATION_CLOSED: "报名关闭",
      SCHEDULED: "已排程",
      LIVE: "进行中",
      COMPLETED: "已完成",
      FINAL: "完赛",
      IN_PROGRESS: "进行中",
      FORFEIT: "弃权",
      MISSING: "缺失",
      SIGNED: "已签署",
      PENDING: "待处理",
      ELIGIBLE: "符合资格",
      INELIGIBLE: "不符合资格",
      OVERRIDDEN: "人工通过",
      SUCCEEDED: "已成功",
      FAILED: "失败",
      COMPED: "已减免"
    },
    fallbacks: {
      "Initial seed tournament for AAYSA Sports registration and operations development.":
        "AAYSA Sports 报名和赛事运营开发的初始示例赛事。"
    }
  }
} as const;

export function interpolate(template: string, values: Record<string, string | number>) {
  return template.replace(/\{(\w+)\}/g, (_, key) => String(values[key] ?? ""));
}
