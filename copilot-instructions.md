# PMP 租赁通知服务

除非另有要求，否则使用简体中文回复。

- 工作范围仅限于用户请求的任务。保留无关改动；仅对影响任务的实质性歧义提问，并报告实际阻碍。不要每项任务都要求先审批计划。
- 以下是技术栈快照，并非升级要求：Java 17、Spring Boot 3.3.12、Maven、Spring Cloud 2023.0.3/OpenFeign、Lombok 和 MapStruct。如有变化，以当前源码和构建配置为准。避免引入不必要的依赖、升级或基础设施建议。
- 基础包：`com.spl.pmp.service.lease.notification`。遵循 controller -> service 接口 -> service.impl -> feign.client 的分层；沿用现有 model 中的 DTO/VO/枚举及构造器注入。外部数据操作通过 Feign 委托处理；不要凭空添加本地数据库/JPA 层，也不要仅凭依赖推断存在 AMQP 消费者。
- 保持 API 大小写、载荷、状态码以及现有 `common.exception`/`config` 错误处理不变。已知邮件模板路由包括 GET `/buildings/{buildingID}/email-template`、GET `/email-templates` 和 POST `/buildings/{buildingID}/upsert-email-template`。仅在用户要求时变更接口契约。避免过于宽泛的异常捕获或静默降级。
- 先只检查相关文件及其直接依赖。没有证据时，不要断言运行时行为、性能提升或可靠性改善。明确区分源码观察、假设与实际执行的检查。
- 优先使用现有依赖编写隔离的 JUnit 5/Mockito/MockMvc 测试。执行前检查所选测试，并模拟外部依赖。未经明确批准，不得启动应用、进行真实服务集成或连接生产环境。
- 未发现 Maven Wrapper；使用可用的 Maven 和已配置的 JDK。私有 Azure Artifacts 源可能导致依赖解析受阻：应报告该阻碍，不得泄露、安装或更改凭据。
- 绝不记录密钥或敏感载荷。不要擅自提交、推送、部署、执行远程写入或修改用户配置。保留无关文件，包括未跟踪文件。
- 修改代码时，在安全可行的前提下，于修改前后运行相关的现有检查；如实记录失败和跳过的检查。仅修改文档时只需验证结构，无需构建应用。
- `pmp-data-lease` 仓库禁止使用 `@Query` 注解的 HQL/JPQL/原生 SQL 字符串（含 `join fetch`）编写仓储查询。自定义查询一律遵循既有的 `XxxRepositoryCustom` 接口 + `XxxRepositoryImpl`（`repository/impl` 包）模式，通过注入的 `EntityManager` 使用 `CriteriaBuilder`/`CriteriaQuery`/`Root`/`Join`/`Predicate` 实现；`Impl` 类无需 `@Repository` 注解，由 Spring Data JPA 按命名约定自动装配。参考 `LeaseUnitRepositoryImpl`、`BuildingUnitRepositoryImpl`、`LeaseActualChargeAmountRepositoryImpl`。
- 编写/修改代码时不要自动添加注释（含行内注释、Javadoc、方法/类说明）以及 `@Schema(description = ...)` 等接口文档注解；只有在用户明确要求时才添加。
- 遵守常见 SonarQube 规则，避免引入可预测的告警：变量/参数/循环变量命名避免使用 `record` 等受限标识符（S6213）；日期字面量优先使用 `java.time.Month`/`DayOfWeek` 等枚举常量而非裸整数（S8694）；数值断言优先使用 `isZero()`/`isPositive()`/`isNegative()` 等语义化断言而非 `isEqualTo(0)`（S5838）；单个测试方法内的断言数量应控制在 25 个以内，超出时按验证场景拆分为多个测试方法或提取共享的私有构造/结果获取方法（S5961）。
- VO、DTO、Feign client 接口、service 接口（无业务逻辑的纯字段容器或接口声明）不需要编写单元测试；测试精力应放在有实际业务逻辑的类上（ServiceImpl、Controller、工具类、Repository 自定义实现等）。
- 编写代码时，或者从c#代码及其他代码转换为Java代码时，遵循现有的命名约定和风格。避免引入不必要的依赖、升级或基础设施建议。而且最好写完所有服务的代码后再进行编译和测试，避免频繁编译和测试。
- 编写代码完成后，根据需求或原代码来源，进行二次确认，避免遗漏或误解，导致逻辑丢失，代码不完整或错误。
- 编写代码时，需要按照数据服务（如pmp-data-lease）只做数据查询，业务服务（如pmp-service-lease或pmp-service-lease-billing）把数据层查询的数据进行业务处理。
- 编写代码时，数据层查询如Repository或RepositoryImpl中，不要出现静态常量定义，基本规则是定义在实体中，非实体中的字段，最好定义在constant类中。
- 禁止执行 `git commit`、`git push` 或任何形式的提交/推送操作，无论修改是否已完成、是否获得口头认可；如需提交，必须由用户自行执行。
# MCP 工具容错策略

- 额外规则：多语言处理应在 pmp-service-lease-report 中执行；pmp-data-lease 仅负责原始数据查询，pmp-service-lease 负责 code/code description 查询与数据注释，避免在多个仓库重复实现同一实体（例如 codeMultiLangVo）。


## 适用范围
所有需要执行代码、调用 MCP 工具的任务。

## 切换规则
1. 执行代码时，优先使用 MCP 检测超时，超时时间 15 秒。
2. 若出现以下情况，立即切换到下一个可用 MCP，不要等待用户确认：
   - 请求超时
   - 连接失败
   - 返回 5xx
   - 工具不可用
3. 切换顺序：按Copilot插件中的规则切换。
4. 每次切换时，简要说明切换原因。
5. 若所有 MCP 均失败，报告错误并停止任务。