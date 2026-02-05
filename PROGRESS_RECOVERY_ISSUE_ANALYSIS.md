# 🔍 做题进度恢复问题诊断报告

## 问题描述

**现象**：长时间未登录后重新登录，分类练习等做题的进度不能恢复，总是从第一题开始。

**预期**：应该恢复到之前中断的位置（例如第30题）。

## 根本原因分析

### 问题链路

```
1. 用户从分类练习退出
   ↓
2. 进度被保存到 SharedPreferences
   ├─ Key: category_progress_{userId}_{categoryId}
   └─ Value: 题目索引
   
3. 长时间后用户重新登录
   ↓
4. AuthGate 调用 UserProgressService.initialize()
   ↓
5. 用户进入 CategoryPracticeScreen
   ↓
6. CategoryPracticeScreen._loadQuestions() 执行
   ├─ 等待 userService.isLoading == false
   ├─ 等待 userService.currentUser != null
   └─ 条件满足后继续
   
7. 调用 getCategoryState()
   ├─ 检查 _currentUser 是否 != null
   ├─ 如果 _currentUser == null → 返回 null
   └─ 进度丢失！❌
```

### 核心问题代码

**UserProgressService.getCategoryState()**：
```dart
Future<Map<String, dynamic>?> getCategoryState(String categoryId, {String? categoryName}) async {
  if (_currentUser == null) return null;  // ← 问题在这里！
  
  // ... 读取 SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final key = '${_categoryProgressKey}state_${_currentUser!.id}_$categoryId';
  // ...
}
```

**CategoryPracticeScreen._loadQuestions()**：
```dart
void _loadQuestions() async {
  final userService = _userService;

  // 等待加载完成
  if ((userService.isLoading || userService.currentUser == null) && _loadRetries < 5) {
    _loadRetries++;
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) {
      _loadQuestions();
    }
    return;
  }
  
  // 此时调用 getCategoryState
  final savedState = await userService.getCategoryState(
    widget.categoryId,
    categoryName: _categoryName,
  );  // ← 可能返回 null
}
```

## 问题成因详解

### 时序问题

1. **等待条件不精确**：
   ```
   检查点：userService.isLoading || userService.currentUser == null
   ↓
   只要 isLoading 为 false 且 currentUser != null 就认为加载完成
   ↓
   但这不保证 currentUser 被正确初始化！
   ```

2. **异步竞态**：
   ```
   AuthGate.initState()
   ├─ userService.initialize()  ← 异步
   │  ├─ 检查现有用户
   │  └─ 加载 currentUser
   │
   同时：
   ├─ 用户被标记为已认证
   ├─ HomePage 显示
   └─ CategoryPracticeScreen 立即加载
        ├─ _loadQuestions() 执行
        └─ getCategoryState() 调用 ← 可能 _currentUser 还未完全初始化
   ```

3. **多用户场景**：
   ```
   用户 A 长时间未登录
   → SharedPreferences 中还有用户 B 的数据
   → 重新登录用户 A
   → CategoryPracticeScreen 加载
   → 使用了用户 B 的 key 去查询（格式中包含 userId）
   → 没找到用户 A 的数据
   → 返回 null
   ```

## 相关代码位置

| 文件 | 方法 | 问题 |
|------|------|------|
| `user_progress_service.dart` | `getCategoryState()` | 没有检查进度数据是否存在，依赖 `_currentUser` |
| `category_practice_screen.dart` | `_loadQuestions()` | 等待条件不够精确 |
| `auth_gate.dart` | `_initialize()` | 没有确保所有初始化完全完成 |

## 为什么长时间未登录会加重这个问题

1. **会话过期**：长时间不活跃，认证令牌可能过期
2. **用户切换**：期间可能有其他用户登录过
3. **数据转移**：如果更换设备或重装应用，本地数据丢失
4. **SharedPreferences 清理**：某些情况下可能被清空

## 验证问题的步骤

### 快速复现

```
1. 使用账户 A 打开应用
2. 进入分类练习
3. 做到第 30 题
4. 完全关闭应用
5. 等待 1 小时（或长时间）
6. 重新打开应用
7. 进入同一个分类练习
8. 观察：是否从第 1 题开始？ ❌
```

### 日志诊断

在日志中查找：
```
[UserProgress] Loaded category {categoryId} state for user {userId}
```

如果看到进度日志，说明读取成功；如果没有，说明数据丢失。

## 问题的完整链路图

```
用户长时间不活跃
    ↓
    ├─ 关闭应用
    ├─ 长时间不打开
    └─ 本地缓存可能被系统清理
    
重新打开应用
    ↓
    ├─ AuthGate 启动
    ├─ UserProgressService.initialize()
    └─ 尝试从 SharedPreferences 恢复用户
    
用户重新登录
    ↓
    ├─ loadUserForId() 异步执行
    ├─ _currentUser 更新
    └─ 可能有时序问题
    
进入 CategoryPracticeScreen
    ↓
    ├─ _loadQuestions() 开始
    ├─ 检查 userService.isLoading && currentUser != null
    └─ 但可能 _currentUser 内部状态不一致
    
调用 getCategoryState()
    ↓
    ├─ 检查 _currentUser == null
    ├─ 如果为 null → 返回 null ❌
    └─ 进度丢失
```

## 相关代码缺陷

### 缺陷 1：getCategoryState() 依赖 _currentUser

```dart
Future<Map<String, dynamic>?> getCategoryState(String categoryId, {String? categoryName}) async {
  if (_currentUser == null) return null;  // ← 问题：应该从 SharedPreferences 直接读取
  
  // 应该使用 userId 参数，而不依赖 _currentUser
}
```

### 缺陷 2：_loadQuestions() 等待条件不完整

```dart
if ((userService.isLoading || userService.currentUser == null) && _loadRetries < 5) {
  // ← 问题：只检查 isLoading 和 currentUser 存在，
  //        没有检查 currentUser 是否被完全初始化
}
```

### 缺陷 3：没有备用方案

```dart
final savedState = await userService.getCategoryState(...);

if (savedState != null) {
  // 恢复进度
} else {
  // 直接使用默认值，没有其他尝试 ❌
}
```

## 解决方案

### 方案 1：改进 getCategoryState()

```dart
Future<Map<String, dynamic>?> getCategoryState(
  String categoryId, 
  String userId,  // ← 添加 userId 参数
  {String? categoryName}
) async {
  // 不依赖 _currentUser，直接使用传入的 userId
  final prefs = await SharedPreferences.getInstance();
  final key = '${_categoryProgressKey}${userId}_$categoryId';
  
  String? jsonString = prefs.getString(key);
  if (jsonString == null && categoryName != null) {
    final nameKey = '${_categoryProgressKey}name_${userId}_$categoryName';
    jsonString = prefs.getString(nameKey);
  }
  
  if (jsonString == null) return null;
  
  try {
    return json.decode(jsonString) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('Failed to load category state: $e');
    return null;
  }
}
```

### 方案 2：在 CategoryPracticeScreen 中获取 userId

```dart
final savedState = await userService.getCategoryState(
  widget.categoryId,
  userService.currentUser?.id ?? '',  // ← 传递 userId
  categoryName: _categoryName,
);
```

### 方案 3：添加完整性检查

```dart
void _loadQuestions() async {
  // ... 等待加载完成
  
  // 确保 currentUser 完全初始化
  if (userService.currentUser == null) {
    debugPrint('[CategoryPractice] Current user is null, retrying...');
    if (_loadRetries < 5) {
      _loadRetries++;
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _loadQuestions();
    }
    return;
  }
  
  // 安全地获取进度
  final userId = userService.currentUser!.id;
  final savedState = await userService.getCategoryState(
    widget.categoryId,
    userId,
    categoryName: _categoryName,
  );
}
```

### 方案 4：添加持久化检查

```dart
// 在 CategoryPracticeScreen 中添加调试日志
void _loadQuestions() {
  debugPrint('[CategoryPractice] Loading questions for category: ${widget.categoryId}');
  debugPrint('[CategoryPractice] Current user: ${userService.currentUser?.id}');
  
  final savedState = await userService.getCategoryState(...);
  
  if (savedState == null) {
    debugPrint('[CategoryPractice] No saved state found!');
    // 尝试直接从 SharedPreferences 读取
    final prefs = await SharedPreferences.getInstance();
    final userId = userService.currentUser?.id;
    if (userId != null) {
      final key = 'category_progress_${userId}_${widget.categoryId}';
      final progress = prefs.getInt(key);
      debugPrint('[CategoryPractice] Direct read progress: $progress');
    }
  }
}
```

## 优先级修复建议

### 高优先级（立即修复）
1. ✅ 改进 `getCategoryState()` 方法，不依赖 `_currentUser`
2. ✅ 在调用前确保 `currentUser` 完全初始化
3. ✅ 添加详细的调试日志

### 中优先级（近期修复）
4. 实现备用方案（如果主方案失败，尝试备用恢复）
5. 添加数据完整性检查
6. 添加用户反馈（"正在恢复您的进度..."）

### 低优先级（优化）
7. 性能优化：预加载进度数据
8. UX 优化：显示恢复进度的动画
9. 增强：支持多设备同步

## 涉及的其他功能

相同的问题也可能出现在：
- `getDrillingProgress()` - 随机练习进度
- `getOperationalDrillingState()` - 操作技能练习进度
- `getDrillingState()` - 随机练习完整状态

这些方法都有相同的 `_currentUser == null` 检查问题。

## 总结

**问题根源**：`getCategoryState()` 依赖 `_currentUser` 对象，但在重新登录的时序问题中，这个对象可能还未完全初始化。

**影响范围**：所有涉及进度恢复的功能都可能受影响。

**修复难度**：低（只需调整方法签名和内部逻辑）

**修复优先级**：高（影响用户体验）

---

**下一步**：建议实施上述的"方案 1 + 方案 2 + 方案 3"来完整解决这个问题。
