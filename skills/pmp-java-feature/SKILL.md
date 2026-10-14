---
name: pmp-java-feature
description: "在 PMP 租赁通知服务中实现用户明确要求的 Java/Spring 功能或代码修改。不适用于 C# 转 Java（使用 pmp-java-convert-from-csharp）、仅分析的问题、未获修复授权的诊断、只读审查或仅测试任务。"
---

# PMP Java 功能开发

如果可以访问 `..\..\copilot-instructions.md`，请遵循其中的共享约束；此处引用不会自动激活这些约束。

## 操作步骤
1. 确认请求明确表达了实现功能或修改代码的意图。提取预期行为、受影响的接口契约和验收标准；仅澄清会实质性影响实现的歧义。
2. 检查相关 controller、service 接口及实现、Feign 契约和 model 类型。沿用现有模式，不要扫描整个仓库。
3. 检查相关测试，建立安全的验证基线。在受影响的各层完成最小但完整的修改；使用现有测试工具补充有针对性的回归测试。
4. 修改后运行相关且安全的检查，并检查差异中是否混入无关改动。

## 任务边界
- 不要把解释说明类请求变成实现任务。
- 不要仅因存在某项依赖就引入持久化或消息架构。
- 保持公共接口契约不变，除非所请求的行为确实需要变更且已获得明确授权。
- 新增或修改入参 DTO/Request 时，不自动添加 `@NotNull`、`@NotBlank`、`@Pattern`、`@Min` 等 Bean Validation 校验注解，也不为此新增 `@Valid`/`@Validated`；必要的业务条件检查沿用业务服务现有方式。既有且与任务无关的校验不擅自删除。
- 报表日期入参应先参考目标仓库同类报表的类型、JSON 绑定和跨层传递方式。`reportMonth` 沿用既有 `LocalDate` 等日期类型，不因界面显示 `MM-yyyy` 而定义成 `String`，也不自行增加字符串月份解析；DTO、Feign、消息载荷及业务服务应保持类型一致。
- 在 `pmp-data-lease` 中新增/修改仓储查询时，禁止使用 `@Query` 的 HQL/JPQL/原生 SQL 字符串（含 `join fetch`）；一律通过 `XxxRepositoryCustom`/`XxxRepositoryImpl` + `CriteriaBuilder` 实现，详见共享约束文件。
- 业务查询的编排与结果组装一律放在 `pmp-service-lease`：由业务服务分别调用数据服务的单一职责查询，再完成关联、分组、聚合、计算和业务模型组装。`pmp-data-lease` 只提供简单、贴近原始数据的查询；禁止在一个数据服务方法或 Repository 方法中执行多个独立查询并拼装报表或业务结果，也不得将此类编排隐藏在辅助方法中。单次查询所需的关联、子查询以及既有分页查询的计数不属于业务查询编排。
- `pmp-data-lease` 对外返回的 VO 及其行数据类型应定义为独立顶级类，单独存放在相应 model/vo 包下，使用有业务含义的名称；不要把行 VO 定义成另一个 VO 的 `static class`，也不要返回 `TenancyExpiryScheduleReportRawDataVo.VacantUnitRow` 这类嵌套类型。提取时保留字段、构造器及 JSON 结构，同步更新 Controller、Service、Repository 投影、Feign 契约和测试中的类型与引用。此规则优先于将此类内部数据模型改写为嵌套 `record` 的建议。
- 不为方便报表查询而自动给已有实体添加集合关联或反向关联。尤其不得给 `LeaseEntity` 新增 `leaseTurnoverRents`；需要的原始数据应分别查询，并在业务服务组装，保持原有实体映射不变。
- 涉及"当前日期"默认值的设置（如查询参数缺省时补默认报表日期等）一律放在 `pmp-service-lease` 层完成，不要放在 `pmp-channel-lease` 层；且必须通过 `com.spl.pmp.service.lease.utils.DateUtils.getCurrentLocalDate()` 获取当前日期，禁止直接使用 `LocalDate.now()`。
- 编写/修改代码时不要自动添加注释或 `@Schema(description = ...)` 等接口文档注解；仅在用户明确要求时才添加。
- 新增实体字段常量时，名称使用实体类名去掉 `Entity` 后的名称作为前缀，再拼接字段名，并转换为大写下划线格式，避免与继承的常量重名。例如 `LeasePCExclusionPeriodEntity` 的 `remarks` 定义为 `LEASE_PC_EXCLUSION_PERIOD_REMARKS = "remarks"`；常量值仍为真实属性名，重命名时同步更新所有引用。
- java代码中对于空值的判断，尽量不用`== null`，而是使用`Objects.isNull()`或`Objects.nonNull()`等，以提高代码可读性和一致性。
- 遵守 SonarQube 常见规则（"认知复杂度"S3776 规则除外，不因追求降低复杂度而做大范围重构）：
  - 不要使用 `record` 等受限标识符作为变量/参数名（S6213）。
  - 日期/月份字面量优先使用 `java.time.Month`（如 `Month.JANUARY`/`Month.DECEMBER.getValue()`）等枚举常量而非裸整数（S8694）。
  - `java.time.*`（`LocalDate`/`Month`/`YearMonth` 等）、`BigDecimal`、`Optional` 等 value-based 类型的相等比较一律使用 `.equals()`，不要用 `==`/`!=`（`null` 判断除外）（S8696）。
  - 重复出现的字符串/颜色等字面量应改为引用已定义的常量，不要重复硬编码同一值（S1192，如已定义 `COLOR_WHITE` 就不要再写字面量 `"#FFFFFF"`）。
  - 不要在代码中留下未依附于任何声明的"悬空" Javadoc 注释（`/** ... */` 后没有紧跟类/方法/字段声明）；说明性文字应改写为普通行注释 `//` 或删除（S8491）。
  - 同一循环体内 `break`/`continue` 语句总数应控制在 1 条以内；多个提前退出条件应合并为一个组合布尔条件（用局部变量拆解可读性）后统一用一次 `continue`/`break`，不得为了消除而反向新增复杂的嵌套结构（S135）。
  - 仅承载不可变字段、无自定义业务方法的内部静态类（如构造器注入后不再变化的引用型 DTO）应优先改写为 Java `record`；改写前必须确认该类型的访问器（`getXxx()`）未被其他类/测试直接调用，否则需要同步改造所有调用点，避免破坏契约（S6218 类建议）。
- 代码中不要使用带完整包名的内联类引用（如 `com.spl.pmp.service.lease.report.utils.AsposeExcelUtils.CellStyleConfig`）；应通过 `import` 引入类型后使用简名（嵌套类沿用项目既有写法，如 `import ...AsposeExcelUtils;` 后使用 `AsposeExcelUtils.CellStyleConfig`）。
- 在 Feign 客户端接口（如 `LeaseDataClient`/`LeaseServiceClient`/`LeaseReportServiceClient`）中新增方法时，一律追加到接口末尾（最后一个已有方法之后、右花括号之前），不要插入到已有方法中间。
- 新增/修改多语言资源包（`resourcebundle/report/**/*.properties`）时，键值一律使用可读的 UTF-8 明文字符（中文直接写汉字），不要写成 `\uXXXX` 转义序列，以与项目现有资源文件保持一致的格式；写入/修改后应人工核对文案本身是否正确（无错别字、简繁体混用等），不能仅满足编译通过。

## 证据与完成标准
报告修改的文件、实现的行为、对接口契约的影响，以及具体检查和结果。说明设计决策时引用源码位置。完成任务需覆盖验收标准并通过相关检查；否则，必须明确说明哪些内容尚未验证及其原因。绝不能将受阻的验证描述为成功。
