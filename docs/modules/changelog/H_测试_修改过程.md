# 模块修改过程记录：H 测试

最近同步：`2026-05-11`
状态：`active`

## 1. 当前状态
- 核心范围：测试入口、基线验证、链路复测、前端测试 UI
- 当前重点：把“能测”推进到“能复测、能分段看耗时、能直接在页面里看结果”

## 2. 修改记录

### 2026-04-26 / 初始化
- 改动内容：
  - 建立 H 模块修改过程文档，后续独立记录测试模块演进
- 测试：
  - 文档创建校验
- 测试结果：`通过`

### 2026-05-11 / 接入 F3 语音延迟测试
- 改动内容：
  - 在 H 测试模块新增 `F3 语音延迟测试` 卡片
  - 前端展示固定中文测试样本、总耗时、分段耗时、识别结果、最近测试历史
  - 后端新增：
    - `GET /api/testing/voice-latency-state`
    - `POST /api/testing/run-voice-latency-benchmark`
  - 新增并稳定化 `scripts/test_xunfei_voice_latency.ps1`
    - 自动读取 `config.ini` 中的讯飞配置
    - 自动生成固定中文样本音频
    - 自动转 PCM
    - 调用 `xunfei_asr.py`
    - 读取 `status_path` 中的分段耗时并回传 JSON
  - 扩展 `scripts/xunfei_asr.py` 的文件模式埋点，补齐这些关键指标：
    - `audio_file_loaded_ms`
    - `websocket_connected_ms`
    - `first_audio_sent_ms`
    - `first_result_received_ms`
    - `first_nonempty_text_received_ms`
    - `final_payload_sent_ms`
    - `final_result_received_ms`
    - `completed_ms`
- 影响文件：
  - `scripts/test_xunfei_voice_latency.ps1`
  - `scripts/xunfei_asr.py`
  - `webui/config/app-common.js`
  - `webui/config/app-testing.js`
  - `webui/config/index.html`
  - `webui/config/server-testing.ps1`
  - `webui/config/server.ps1`
  - `webui/config/styles.css`
- 测试：
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_xunfei_voice_latency.ps1`
  - `node --experimental-default-type=module --check webui/config/app-testing.js`
  - 点源 `webui/config/server-testing.ps1` 后执行 `Get-TestingVoiceLatencyState`
  - 点源 `webui/config/server-testing.ps1` 后执行 `Run-TestingVoiceLatencyBenchmark`
- 测试结果：`通过`
- 实测结论：
  - 脚本总耗时样本：`≈3103ms`
  - 后端接口总耗时样本：`≈2603ms`
  - 分段耗时样本：
    - `websocket_connected_ms≈237-262`
    - `first_audio_sent_ms≈238-264`
    - `first_result_received_ms≈572-688`
    - `completed_ms≈1898-2058`
  - 主要延迟仍集中在“首包发出后到服务返回第一条识别结果”这一段
