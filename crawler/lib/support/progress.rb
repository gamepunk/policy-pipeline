# frozen_string_literal: true

# 终端单行进度输出:用 \r 回到行首覆盖刷新,避免滚屏刷日志。
# 仅用于进度条/状态行;错误与总结仍用 puts 换行输出。
# 进度条只在 TTY(真实终端)下刷新;输出被重定向(管道/工具捕获)时静默,
# 阶段结果由 done 负责输出,避免刷屏。
module Progress
  module_function

  # 刷新当前行(不换行),\e[K 清除行尾残留字符
  def refresh(text)
    return unless $stdout.tty?

    print "\r\e[K#{text}"
    $stdout.flush
  end

  # 结束进度行:TTY 下覆盖当前行,否则直接换行打印
  def done(text)
    if $stdout.tty?
      puts "\r\e[K#{text}"
    else
      puts text
    end
  end
end
