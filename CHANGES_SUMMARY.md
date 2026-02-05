# 用户统计数据持久化改进 - 完整改动总结

## 📌 问题回顾

**用户需求**：主页上的已答题目和正确率等统计数据在用户退出后会清零，需要按照一般的考试题库类型的设计重新设计这个逻辑。

**核心问题**：统计数据存储在 `User` 对象中，用户退出时调用 `clearLocalUser()` 会清空所有用户数据。

## ✨ 解决方案

创建独立的 **UserStatisticsService** 服务，将统计数据与用户会话分离，实现以下目标：

✅ 统计数据持久化存储到本地  
✅ 用户退出后统计数据不丢失  
✅ 用户重新登录时自动恢复统计数据  
✅ 支持多用户数据隔离  
✅ 为未来的服务器同步做准备  

## 📂 文件变更明细

### 新增文件

#### 1. `lib/services/user_statistics_service.dart` (新建)
**功能**：专门管理用户统计数据的持久化

**主要类和方法**：
- `UserStatisticsService` - 统计数据服务（ChangeNotifier）
- `initialize()` - 初始化时从本地加载数据
- `recordQuestionAttempt(bool correct)` - 记录答题
- `recordMockExam()` - 记录模拟考试
- `updateStatistics()` - 批量更新（服务器同步）
- `clearStatistics()` - 清除统计（用户重置）

**存储方式**：
- 使用 `SharedPreferences` 本地存储
- Key 格式：`user_statistics_{userId}`
- Value：JSON 格式的统计数据

**关键特性**：
- 用户隔离：每个用户 ID 单独存储
- 时间戳：记录最后更新时间
- 同步检查：`shouldSyncWithServer()` 判断是否需要同步

### 修改的文件

#### 2. `lib/models/user.dart` (已修改)
**改动**：
- 添加 `lastSyncAt` 字段，记录最后一次与服务器同步的时间
- 更新 `toJson()` 和 `fromJson()` 方法支持新字段
- 更新 `copyWith()` 方法支持新字段

**文件摘要**：
```dart
class User {
  // ... 现有字段 ...
  final DateTime lastSyncAt;  // 新增：最后同步时间
  
  // 更新的方法
  Map<String, dynamic> toJson()
  factory User.fromJson(Map<String, dynamic> json)
  User copyWith({...})
}
```

#### 3. `lib/main.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 在 `MultiProvider` 中添加 `UserStatisticsService` 提供者

**代码变更**：
```dart
// 添加导入
import 'package:ai_coach/services/user_statistics_service.dart';

// 在 MultiProvider 中添加
ChangeNotifierProvider(create: (_) => UserStatisticsService()),
```

#### 4. `lib/services/user_progress_service.dart` (已修改)
**改动**：
- 修改 `recordQuestionAttempt()` 方法，改为空实现（保留向后兼容）
- 修改 `recordMockExam()` 方法，改为空实现（保留向后兼容）
- 更新 `clearLocalUser()` 注释，说明不再清除统计数据

**代码变更**：
```dart
// 现在只更新 updatedAt 时间戳，不修改统计数据
Future<void> recordQuestionAttempt(bool correct) async {
  if (_currentUser == null) return;
  _currentUser = _currentUser!.copyWith(updatedAt: DateTime.now());
  await _saveUser();
  notifyListeners();
}

// 统计数据由 UserStatisticsService 管理
Future<void> clearLocalUser() async {
  _currentUser = null;  // 只清除会话，不清除统计
  notifyListeners();
}
```

#### 5. `lib/screens/home_screen.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 初始化时添加 `statisticsService.initialize()`
- 在 `Consumer3` 改为 `Consumer4`，新增 `UserStatisticsService`
- 显示统计数据时改用 `statisticsService` 而非 `user` 对象

**代码变更**：
```dart
// 导入
import 'package:ai_coach/services/user_statistics_service.dart';

// 初始化
final statisticsService = context.read<UserStatisticsService>();
await statisticsService.initialize();

// 显示
StatisticsCard(
  title: '已答题目',
  value: '${statisticsService.totalQuestionsAttempted}',
  // ...
),
StatisticsCard(
  title: '正确率',
  value: '${statisticsService.accuracyRate.toStringAsFixed(1)}%',
  // ...
),
StatisticsCard(
  title: '模拟测试',
  value: '${statisticsService.mockExamsTaken}',
  // ...
),
```

#### 6. `lib/screens/question_drilling_screen.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 在 `_submitAnswer()` 方法中改用 `statisticsService.recordQuestionAttempt()`

#### 7. `lib/screens/category_practice_screen.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 在 `_submitAnswer()` 方法中改用 `statisticsService.recordQuestionAttempt()`

#### 8. `lib/screens/operational_skills_screen.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 在答题提交时改用 `statisticsService.recordQuestionAttempt()`

#### 9. `lib/screens/operational_skills_drilling_screen.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 在代码执行结果处理时改用 `statisticsService.recordQuestionAttempt()`

#### 10. `lib/screens/mock_exam_screen.dart` (已修改)
**改动**：
- 导入 `UserStatisticsService`
- 在考试结束计算答题统计时改用 `statisticsService.recordQuestionAttempt()`
- 在考试完成时改用 `statisticsService.recordMockExam()`

### 新增文档文件

#### 11. `STATISTICS_PERSISTENCE_DESIGN.md` (新建)
完整的设计文档，包括：
- 问题背景分析
- 架构设计详解
- 数据流图
- 修改的文件清单
- 存储格式示例
- 后续计划
- 优势说明
- 测试建议
- 常见问题解答

#### 12. `STATISTICS_QUICK_START.md` (新建)
快速开始指南，包括：
- 概述
- 工作原理对比
- 代码使用示例
- 数据存储位置
- 常见使用场景
- 配置说明
- 故障排除
- 检查清单

## 🔄 核心逻辑变化

### 以前的流程
```
登录 → 加载 User → 显示 User 中的统计数据
  ↓
答题 → UserProgressService.recordQuestionAttempt()
  ↓
User.totalQuestionsAttempted++, User.totalQuestionsCorrect++
  ↓
退出 → clearLocalUser() → User 对象清空 → 统计数据丢失 ❌
```

### 现在的流程
```
登录 → 加载 User + 加载 UserStatisticsService
  ↓
UserStatisticsService 从本地读取该用户的统计数据
  ↓
主页显示 UserStatisticsService 中的统计数据
  ↓
答题 → UserStatisticsService.recordQuestionAttempt()
  ↓
统计数据保存到 SharedPreferences（本地存储）
  ↓
退出 → clearLocalUser() → User 对象清空，但统计数据保留 ✅
  ↓
重新登录 → UserStatisticsService 自动加载之前的统计数据 ✅
```

## 📊 数据存储结构变化

### 之前
```
User 对象（内存）
├── totalQuestionsAttempted: int
├── totalQuestionsCorrect: int
└── mockExamsTaken: int
  ↓ 用户退出时全部清空
```

### 现在
```
User 对象（内存）- 仅保存用户基本信息
├── id: String
├── name: String
├── createdAt: DateTime
└── updatedAt: DateTime

SharedPreferences（本地存储）- 持久化统计数据
└── user_statistics_{userId}: JSON
    ├── totalQuestionsAttempted: int
    ├── totalQuestionsCorrect: int
    ├── mockExamsTaken: int
    └── lastUpdateTime: DateTime
```

## 🧪 测试场景

### 场景 1：基本功能
1. ✅ 新用户答 10 道题
2. ✅ 检查"已答题目"是否显示 10
3. ✅ 检查"正确率"是否计算正确
4. ✅ 检查"错题本"是否包含错题

### 场景 2：数据持久化
1. ✅ 答题 10 道，记录统计
2. ✅ 退出应用
3. ✅ 重新打开应用
4. ✅ 验证统计数据是否仍然显示 10 道

### 场景 3：多用户隔离
1. ✅ 用户 A 答 100 道题
2. ✅ 用户 A 退出
3. ✅ 用户 B 登录，统计数据显示 0（新用户）
4. ✅ 用户 A 重新登录，统计仍然是 100

### 场景 4：数据累积
1. ✅ 用户答 10 道题，统计为 10
2. ✅ 再答 5 道题，统计更新为 15
3. ✅ 退出并重新登录，统计仍为 15
4. ✅ 再答 3 道题，统计更新为 18

## 🚀 后续扩展

### 第一阶段（已完成）
- ✅ 创建 UserStatisticsService
- ✅ 实现本地持久化
- ✅ 分离统计数据和会话数据
- ✅ 更新所有相关的 UI

### 第二阶段（计划中）
- ⏳ 创建 Supabase user_statistics 表
- ⏳ 实现数据同步机制
- ⏳ 支持多设备数据同步
- ⏳ 处理离线冲突

### 第三阶段（未来）
- ⏳ 数据统计分析（学习趋势等）
- ⏳ 数据导出功能
- ⏳ 数据备份恢复
- ⏳ 学习成就徽章系统

## 📋 检查清单

- [x] 创建 UserStatisticsService 服务
- [x] 修改 User 模型添加 lastSyncAt
- [x] 更新 UserProgressService 统计逻辑
- [x] 修改 home_screen 显示统计
- [x] 更新所有答题相关的 screen
- [x] 在 main.dart 注册服务
- [x] 创建完整设计文档
- [x] 创建快速开始指南
- [x] 验证代码无错误
- [x] 验证向后兼容

## 🎯 预期效果

✅ **用户体验**：退出后统计不丢失，重新登录能看到历史数据  
✅ **应用设计**：符合标准考试题库应用的架构  
✅ **代码质量**：关注点分离，各服务职责明确  
✅ **可维护性**：易于理解和扩展的架构  
✅ **易于测试**：可独立测试各个服务  

## 🔗 相关文档

- 📄 [完整设计文档](./STATISTICS_PERSISTENCE_DESIGN.md)
- 📄 [快速开始指南](./STATISTICS_QUICK_START.md)
- 📂 [源代码](./lib/)

---

**最后修改时间**：2024年1月29日  
**版本**：1.0  
**状态**：已完成
