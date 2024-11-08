class Utils {
	static _SleepResolution := 15.6

	static SystemTime {
		get {
			static freq := 0
			if (freq == 0)
				DllCall("QueryPerformanceFrequency", "Int64*", &freq)
			DllCall("QueryPerformanceCounter", "Int64*", &tick := 0)
			return tick / freq * 1000
		}
	}

	static ThreadSleep(time) {
		DllCall("kernel32\Sleep", "UInt", time)
	}

	static SleepAtLeast(time) {
		start := this.SystemTime
		Sleep(time)
		while (this.SystemTime - start < time)
			Sleep(this._SleepResolution)
	}

	static SleepAtMost(time) {
		if (time <= this._SleepResolution) {
			this.ThreadSleep(time)
			return
		}
		start := this.SystemTime
		Sleep(time - this._SleepResolution)
		while (this.SystemTime - start + this._SleepResolution < time)
			Sleep(this._SleepResolution)
	}

	/**
	 * @param time The amount of time to pause (in milliseconds).
	 * @param mode Sleep mode.
	 * - `unset` or `""`: `Sleep`
	 * - `"thread"`: `Utils.ThreadSleep`
	 * - `"min"`: `Utils.SleepAtLeast`
	 * - `"max"`: `Utils.SleepAtMost`
	 */
	static Sleep(time, mode?) {
		if (!IsSet(mode) || mode == "")
			Sleep(time)
		else if (mode == "thread")
			this.ThreadSleep(time)
		else if (mode == "min")
			this.SleepAtLeast(time)
		else if (mode == "max")
			this.SleepAtMost(time)
		else
			throw ValueError("Invalid sleep mode: " mode)
	}
}

class Logger {
	__New(filePath := "") {
		this.FilePath := filePath
		this.__File := FileOpen(filePath, FileExist(filePath) ? "a" : "w")
	}

	__Delete() {
		this.__File.Close()
	}

	Log(message) {
		this.__File.Write("[" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss.") A_MSec "] " message "`n")
		handle := this.__File.Handle
	}

	Clear() {
		this.__File.Close()
		this.__File := FileOpen(this.FilePath, "w")
		this.__File.Write("")
	}
}