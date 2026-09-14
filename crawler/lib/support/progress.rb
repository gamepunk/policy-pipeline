# frozen_string_literal: true

# 终端单行进度输出:用 \r 回到行首覆盖刷新,避免滚屏刷日志。
# 仅用于进度条/状态行;错误与总结仍用 puts 换行输出。
module Progress
  module_function

  # 刷新当前行(不换行),\e[K 清除行尾残留字符
  def refresh(text)
    print "\r\e[K#{text}"
    $stdout.flush
  end

  # 结束进度行:输出最终内容并换行
  def done(text)
    puts "\r\e[K#{text}"
  end
end
