package server

import (
	"testing"
)

// =====================================================================
// matchFiltersLine tests
//
// These cover the filter logic that used to be per-session `adb logcat
// --pid=` / `*:PRIO` command-line filters. Now applied client-side in
// LogSession.readerLoop because the subprocess is shared.
// =====================================================================

// standardLogcat builds a threadtime-format logcat line for testing.
// Components mirror what `adb logcat -v threadtime` emits.
func standardLogcat(date, time, pid, tid, prio, tag, msg string) string {
	return date + " " + time + "  " + pid + "  " + tid + " " + prio + " " + tag + ": " + msg
}

const (
	testDate = "01-01"
	testTime = "12:00:00.000"
	testPID  = "1234"
	testTID  = "5678"
	testPrio = "W"
	testTag  = "AndroidRuntime"
	testMsg  = "FATAL EXCEPTION: main"
)

func sampleLine() string {
	return standardLogcat(testDate, testTime, testPID, testTID, testPrio, testTag, testMsg)
}

func TestMatchFiltersLine_EmptyFilter_AllowsAll(t *testing.T) {
	if !matchFiltersLine(sampleLine(), LogFilter{}) {
		t.Error("empty filter should match any line")
	}
}

func TestMatchFiltersLine_KeywordCaseInsensitive(t *testing.T) {
	// Keyword matches in the body of the line, case-insensitive.
	if !matchFiltersLine(sampleLine(), LogFilter{Keyword: "fatal"}) {
		t.Error("lowercase keyword should match uppercase line content")
	}
	if !matchFiltersLine(sampleLine(), LogFilter{Keyword: "FATAL"}) {
		t.Error("exact-case keyword should match")
	}
	if matchFiltersLine(sampleLine(), LogFilter{Keyword: "nonexistent"}) {
		t.Error("non-matching keyword should reject")
	}
}

func TestMatchFiltersLine_TagCaseInsensitive(t *testing.T) {
	if !matchFiltersLine(sampleLine(), LogFilter{Tag: "android"}) {
		t.Error("lowercase tag substring should match AndroidRuntime")
	}
	if !matchFiltersLine(sampleLine(), LogFilter{Tag: "Android"}) {
		t.Error("case match should pass")
	}
	if matchFiltersLine(sampleLine(), LogFilter{Tag: "ActivityManager"}) {
		t.Error("different tag should reject")
	}
}

func TestMatchFiltersLine_TagEmptyLinePasses(t *testing.T) {
	// A line without standard logcat header (e.g. continuation, debug
	// dump) returns "" for tag. Tag filter must NOT auto-reject those
	// — keyword/priority still apply.
	if !matchFiltersLine("Some random output line", LogFilter{Tag: "ActivityManager"}) {
		t.Error("non-logcat line should pass tag filter when tag can't be parsed")
	}
}

func TestMatchFiltersLine_Priority_HigherThanFilterPasses(t *testing.T) {
	// Filter W (rank 3) → allow W (3), E (4), F (5). Reject V (0), D (1), I (2).
	cases := []struct {
		prio string
		want bool
	}{
		{"V", false},
		{"D", false},
		{"I", false},
		{"W", true},
		{"E", true},
		{"F", true},
	}
	for _, c := range cases {
		line := standardLogcat(testDate, testTime, testPID, testTID, c.prio, testTag, testMsg)
		got := matchFiltersLine(line, LogFilter{Priority: "W"})
		if got != c.want {
			t.Errorf("priority=%s with filter W: got %v, want %v", c.prio, got, c.want)
		}
	}
}

func TestMatchFiltersLine_Priority_LowercaseAllowsAll(t *testing.T) {
	// Defensive: unknown filter priority (e.g. lowercase 'w') falls
	// back to "match all". This shouldn't happen in practice (Flutter
	// sends single uppercase letter) but better than panic.
	for _, prio := range []string{"V", "D", "I", "W", "E", "F"} {
		line := standardLogcat(testDate, testTime, testPID, testTID, prio, testTag, testMsg)
		if !matchFiltersLine(line, LogFilter{Priority: "v"}) {
			t.Errorf("unknown filter priority 'v' should match all, failed on prio=%s", prio)
		}
	}
}

func TestMatchFiltersLine_Priority_NonLogcatLinePasses(t *testing.T) {
	// Continuation / dump lines without a priority char should NOT be
	// rejected by the priority filter — other filters still apply.
	if !matchFiltersLine("Random continuation line", LogFilter{Priority: "W"}) {
		t.Error("non-logcat line should pass priority filter when priority can't be parsed")
	}
}

func TestMatchFiltersLine_PackageName_SubstringMatch(t *testing.T) {
	line := standardLogcat(testDate, testTime, testPID, testTID, testPrio, "ActivityManager",
		"Force stopping com.example.foo uid=10001")
	if !matchFiltersLine(line, LogFilter{PackageName: "com.example.foo"}) {
		t.Error("PackageName substring should match")
	}
	if matchFiltersLine(line, LogFilter{PackageName: "com.example.bar"}) {
		t.Error("non-matching package should reject")
	}
}

func TestMatchFiltersLine_PackagePid_ExactMatch(t *testing.T) {
	// PID=1234 should match a filter of "1234".
	if !matchFiltersLine(sampleLine(), LogFilter{PackagePid: testPID}) {
		t.Errorf("PackagePid %q should match PID column", testPID)
	}
}

func TestMatchFiltersLine_PackagePid_DoesNotMatchTID(t *testing.T) {
	// Filter PID=1234, line has PID=1234 TID=9999. Should match.
	// Filter PID=9999 (TID value), line has PID=1234 TID=9999. Should
	// NOT match — that's the precision gain over substring matching.
	line := standardLogcat(testDate, testTime, "1234", "9999", testPrio, testTag, testMsg)

	if !matchFiltersLine(line, LogFilter{PackagePid: "1234"}) {
		t.Error("PackagePid should match PID column even when TID differs")
	}
	if matchFiltersLine(line, LogFilter{PackagePid: "9999"}) {
		t.Error("PackagePid must NOT match TID column (precision fix)")
	}
}

func TestMatchFiltersLine_PackagePid_NoSubstringFalsePositives(t *testing.T) {
	// " 1234 " appears in the message body but NOT as PID column.
	// Old substring-based filter would have falsely matched.
	line := standardLogcat(testDate, testTime, "5678", "9999", testPrio, testTag,
		"called from offset 1234")
	if matchFiltersLine(line, LogFilter{PackagePid: "1234"}) {
		t.Error("PackagePid must NOT match incidental 1234 in message body")
	}
}

func TestMatchFiltersLine_NonLogcatLineWithPID_NeverMatches(t *testing.T) {
	// A line without the standard header can't have its PID parsed;
	// PackagePid filter rejects it.
	if matchFiltersLine("totally unrelated output mentioning pid 1234", LogFilter{PackagePid: "1234"}) {
		t.Error("PackagePid filter should reject non-logcat lines")
	}
}

func TestMatchFiltersLine_AllFieldsCombined(t *testing.T) {
	// Tag AND priority AND keyword must all match.
	filter := LogFilter{
		Tag:      "android",
		Priority: "W",
		Keyword:  "fatal",
	}
	if !matchFiltersLine(sampleLine(), filter) {
		t.Error("all-filter pass case failed")
	}

	// Change one field → reject.
	filter.Tag = "activity"
	if matchFiltersLine(sampleLine(), filter) {
		t.Error("tag mismatch should reject")
	}
}

func TestExtractLogcatPID(t *testing.T) {
	cases := []struct {
		line string
		want string
	}{
		{sampleLine(), testPID},
		{"01-01 12:00:00.000  9999  9999 W Tag: msg", "9999"},
		{"not a logcat line", ""},
		{"", ""},
	}
	for _, c := range cases {
		got := extractLogcatPID(c.line)
		if got != c.want {
			t.Errorf("extractLogcatPID(%q) = %q, want %q", c.line, got, c.want)
		}
	}
}

func TestExtractLogcatPriority(t *testing.T) {
	cases := []struct {
		line string
		want byte
	}{
		{sampleLine(), 'W'},
		{standardLogcat(testDate, testTime, testPID, testTID, "E", "Tag", "msg"), 'E'},
		{standardLogcat(testDate, testTime, testPID, testTID, "V", "Tag", "msg"), 'V'},
		// Bug-regression: the old walk-forward impl would find 'M' in
		// "MM-DD" first and return whatever came before spaces. The
		// regex-based impl finds the actual priority column.
		{"01-01 12:00:00.000  1234  1234 E AndroidRuntime: boom", 'E'},
		{"not a logcat line", 0},
		{"", 0},
	}
	for _, c := range cases {
		got := extractLogcatPriority(c.line)
		if got != c.want {
			t.Errorf("extractLogcatPriority(%q) = %q, want %q", c.line, got, c.want)
		}
	}
}