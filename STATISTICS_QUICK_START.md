# 用户统计数据持久化 - 快速指南

## 📋 概述

从今天起，主页上的以下统计数据**不会再因为用户退出而清零**：

- ✅ **已答题目** - 用户总共答过多少道题
- ✅ **正确率** - 答对的题目占比
- ✅ **模拟测试** - 参加的模拟考试次数
- ✅ **错题本** - 记录的错题数量

## 🏗️ 工作原理

### 旧设计（已弃用）
```
用户答题 → UserProgressService.recordQuestionAttempt()
          ↓
        修改 User 对象中的统计数据
          ↓
        用户退出 → 清空 User 数据 → 统计清零 ❌
```

### 新设计（已实施）
```
用户答题 → UserStatisticsService.recordQuestionAttempt()
          ↓
        保存到 SharedPreferences（本地存储）
          ↓
        用户退出 → 统计数据保留在本地 ✅
          ↓
        用户重新登录 → 自动加载之前的统计数据 ✅
```

## 🔧 如何在代码中使用

### 记录答题统计

```dart
// 旧方式（已弃用但仍可用）
await userService.recordQuestionAttempt(isCorrect);

// 新方式（推荐）
final statisticsService = context.read<UserStatisticsService>();
await statisticsService.recordQuestionAttempt(isCorrect);
```

### 记录模拟考试

```dart
final statisticsService = context.read<UserStatisticsService>();
await statisticsService.recordMockExam();
```

### 在 UI 中显示统计数据

```dart
Consumer<UserStatisticsService>(
  builder: (context, statsService, child) {
    return Column(
      children: [
        Text('已答题目: ${statsService.totalQuestionsAttempted}'),
        Text('正确率: ${statsService.accuracyRate.toStringAsFixed(1)}%'),
        Text('模拟考试: ${statsService.mockExamsTaken}'),
      ],
    );
  },
)
```

## 📊 数据存储位置

统计数据存储在设备本地，使用以下格式：

**存储键**：`user_statistics_{userId}`  
**存储值**：JSON 格式
```json
{
  "totalQuestionsAttempted": 150,
  "totalQuestionsCorrect": 120,
  "mockExamsTaken": 5,
  "lastUpdateTime": "2024-01-29T15:30:00.000Z"
}
```

## 🎯 使用场景

### 场景 1：学生继续学习
```
小明答了 100 道题，退出应用
→ 再次打开应用
→ 仍然看到"已答题目: 100"
→ 继续答题，变成 101 道
```

### 场景 2：多用户设备
```
小明的统计: 已答 100 道，正确率 80%
小红的统计: 已答 80 道，正确率 90%
→ 两个用户的数据完全隔离
→ 互不影响
```

### 场景 3：重新安装应用
```
重新安装后，旧的统计数据会丢失
→ 建议后续添加"云同步"功能
→ 将数据备份到 Supabase
```

## ⚙️ 配置和初始化

无需额外配置！应用启动时会自动：

1. 创建 `UserStatisticsService` 实例
2. 在用户登录后自动加载对应的统计数据
3. 在主页自动显示最新统计

## 🔄 服务器同步（未来功能）

后续计划实现与 Supabase 的同步：

```dart
// 示例代码（未来实现）
final statsService = context.read<UserStatisticsService>();

// 检查是否需要同步
if (statsService.shouldSyncWithServer()) {
  // 上传统计数据到服务器
  await syncToSupabase();
}

// 从服务器下载最新统计
await statsService.updateStatistics(
  totalQuestionsAttempted: serverData['total'],
  totalQuestionsCorrect: serverData['correct'],
  mockExamsTaken: serverData['exams'],
);
```

## 🧹 清除统计数据

### 用户主动重置（示例）

```dart
// 在设置页面提供"重置统计"功能
ElevatedButton(
  onPressed: () async {
    await context.read<UserStatisticsService>().clearStatistics();
    setState(() {});
  },
  child: const Text('重置所有统计'),
)
```

### 用户删除账户

在服务器端删除对应用户的统计数据即可。

## 📝 相关文件

- 📄 [完整设计文档](./STATISTICS_PERSISTENCE_DESIGN.md)
- 📂 核心实现
  - `lib/services/user_statistics_service.dart` - 统计服务
  - `lib/models/user.dart` - 用户模型
  - `lib/screens/home_screen.dart` - 主页界面
  - `lib/screens/*_screen.dart` - 各个练习页面

## ✅ 检查清单

在你的代码中完成以下检查：

- [ ] 所有答题记录都通过 `UserStatisticsService` 而非 `UserProgressService`
- [ ] 主页通过 `Consumer<UserStatisticsService>` 显示统计
- [ ] 用户退出不清除 `UserStatisticsService` 数据
- [ ] 多个用户的统计数据隔离存储
- [ ] 应用启动时自动初始化统计服务

## 🐛 故障排除

### 问题：退出后统计数据仍然丢失

检查：
1. 是否调用了 `clearStatistics()` 或清除 SharedPreferences
2. UserStatisticsService 是否正确初始化
3. 是否清除了应用缓存

### 问题：多个用户统计数据混乱

检查：
1. SharedPreferences 的存储 key 是否包含 `{userId}`
2. 登录/退出时用户 ID 是否正确切换

### 问题：首次登录看不到统计

这是正常的！新用户的统计数据初始化为 0。

## 📞 支持

如有问题，请查看：
- [完整设计文档](./STATISTICS_PERSISTENCE_DESIGN.md)
- 代码注释
- UserStatisticsService 的公共 API
