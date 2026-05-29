# Math Notes

这个仓库用于长期管理高等数学、线性代数、概率论笔记。

## 目录

- `高等数学/`: 高等数学笔记
- `线性代数/`: 线性代数笔记
- `概率论/`: 概率论笔记
- `assets/`: 图片与例图资源
- `tools/`: 本地同步与链接规范化脚本

## 同步方式

本机通过 Windows 计划任务 `YankNoteMathAutoPush` 每 3 分钟运行一次：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\math-notes\tools\sync-math-notes.ps1
```

脚本会在有修改时自动规范化图片链接、提交并推送到 GitHub。

    