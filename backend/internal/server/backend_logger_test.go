package server

import (
	"context"
	"errors"
	"testing"
)

func TestFormatLogError(t *testing.T) {
	cases := []struct {
		err  error
		want string
	}{
		{nil, ""},
		{context.DeadlineExceeded, "超时：ADB 命令执行超过时限（ADB 可能卡住或设备响应慢）"},
		{context.Canceled, "已取消：请求被中断（切换页面、重启服务或取消传输时会触发）"},
		{errors.New("adb failed"), "adb failed"},
	}
	for _, tc := range cases {
		got := formatLogError(tc.err)
		if got != tc.want {
			t.Fatalf("formatLogError(%v) = %q, want %q", tc.err, got, tc.want)
		}
	}
}
