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
