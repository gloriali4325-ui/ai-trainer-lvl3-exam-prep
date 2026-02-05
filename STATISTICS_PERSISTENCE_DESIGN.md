# 用户统计数据持久化设计文档

## 问题背景
之前的设计中，用户的学习统计数据（已答题目、正确率、模拟测试次数）存储在 `User` 模型中，当用户退出登录时会被清零，这与标准考试题库的设计不符。

## 改进方案
按照一般的考试题库应用设计，统计数据应该是**持久化的**，即：
- 用户退出应用后统计数据仍然保留
- 用户重新登录时能看到之前的学习统计
- 统计数据只有在用户主动重置或同步到服务器后才会更新

## 架构设计

### 1. 核心变化

#### UserStatisticsService（新增）
专门负责用户统计数据的持久化和管理：

```dart
class UserStatisticsService extends ChangeNotifier {
  // 统计数据字段
  int _totalQuestionsAttempted;      // 已答题目总数
  int _totalQuestionsCorrect;        // 正确题目数
  int _mockExamsTaken;              // 模拟考试次数
  DateTime? _lastUpdateTime;         // 最后更新时间
  
  // 核心方法
  Future<void> initialize()              // 初始化时从本地加载
  Future<void> recordQuestionAttempt()   // 记录一次答题
  Future<void> recordMockExam()          // 记录一次模拟考试
  Future<void> updateStatistics()       // 批量更新（与服务器同步）
  Future<void> clearStatistics()        // 用户主动重置
}
```

**存储位置**：使用 `SharedPreferences` 存储，key 格式为 `user_statistics_{userId}`
**存储内容**：JSON 格式包含统计数据和最后更新时间

#### User 模型（已修改）
- 保留 `totalQuestionsAttempted`, `totalQuestionsCorrect`, `mockExamsTaken` 等字段用于向后兼容
- 添加 `lastSyncAt` 字段用于追踪最后同步时间
- 这些字段现在仅用于显示从服务器同步的数据

#### UserProgressService（已修改）
- `recordQuestionAttempt()` 和 `recordMockExam()` 方法改为空实现（保留以兼容）
- `clearLocalUser()` 不再清除统计数据，只清除会话信息
- 继续管理学习进度（比如分类练习、随机练习的进度）

### 2. 数据流

**记录答题流程**：
```
QuestionDrillingScreen
  ↓
UserStatisticsService.recordQuestionAttempt()
  ↓
SharedPreferences (本地持久化)
  ↓
UI 刷新显示最新统计
```

**登录流程**：
```
用户登录
  ↓
UserProgressService.initialize()    (加载用户信息)
  ↓
UserStatisticsService.initialize()  (从本地加载该用户的统计数据)
  ↓
HomePage 显示统计数据 (来自 UserStatisticsService)
```

**退出流程**：
```
用户退出
  ↓
AuthService.signOut()
  ↓
UserProgressService.clearLocalUser()  (清除会话)
  ↓
统计数据保留在本地！
  ↓
下次该用户登录时，统计数据自动加载
```

### 3. 修改的文件列表

#### 新增文件
- `lib/services/user_statistics_service.dart` - 统计服务

#### 修改的文件
- `lib/main.dart` - 添加 UserStatisticsService Provider
- `lib/models/user.dart` - 添加 lastSyncAt 字段
- `lib/services/user_progress_service.dart` - 修改统计记录逻辑
- `lib/screens/home_screen.dart` - 改用 UserStatisticsService 显示统计
- `lib/screens/question_drilling_screen.dart` - 改用 UserStatisticsService 记录
- `lib/screens/category_practice_screen.dart` - 改用 UserStatisticsService 记录
- `lib/screens/operational_skills_screen.dart` - 改用 UserStatisticsService 记录
- `lib/screens/operational_skills_drilling_screen.dart` - 改用 UserStatisticsService 记录
- `lib/screens/mock_exam_screen.dart` - 改用 UserStatisticsService 记录

### 4. 存储格式示例

**SharedPreferences 中的存储**：
```json
{
  "user_statistics_user123": {
    "totalQuestionsAttempted": 150,
    "totalQuestionsCorrect": 120,
    "mockExamsTaken": 5,
    "lastUpdateTime": "2024-01-29T15:30:00.000Z"
  }
}
```

### 5. 后续计划（Supabase 同步）

为了实现完整的考试系统设计，建议后续实现：

1. **创建 Supabase 表**：
```sql
CREATE TABLE user_statistics (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  total_questions_attempted INT DEFAULT 0,
  total_questions_correct INT DEFAULT 0,
  mock_exams_taken INT DEFAULT 0,
  last_updated_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

2. **同步机制**：
   - 用户退出时将本地统计上传到服务器
   - 用户登录时下载最新的统计数据
   - 支持多设备数据同步

3. **数据一致性**：
   - 以服务器为准（或根据最后修改时间判断）
   - 解决离线编辑冲突

## 优势

✅ **用户体验好**：退出登录后统计数据不丢失  
✅ **符合标准设计**：与考试题库应用一致  
✅ **易于扩展**：可轻松添加服务器同步  
✅ **向后兼容**：保留原有字段，API 无需大改  
✅ **数据持久化**：本地和服务器双重保障  

## 测试建议

1. 答题并记录统计
2. 退出登录
3. 重新登录，验证统计数据仍存在
4. 切换用户，验证统计数据隔离
5. 清空缓存，验证数据丢失后重新应答

## 常见问题

**Q: 为什么不直接修改 User 模型？**  
A: User 模型代表用户身份和基本信息，应保持简洁。统计数据是行为数据，应单独管理。

**Q: 多设备如何同步统计数据？**  
A: 后续通过 Supabase 实现服务器端统计表，登录时同步。

**Q: 如何清除用户的统计数据？**  
A: 调用 `UserStatisticsService.clearStatistics()` 方法，或在服务器端删除对应记录。
