class Operations {
	static fPressed := Map()

	static pPressed := Map()

	static waiting := Map()

	static Initialize(key) {
		Operations.fPressed[key] := false
		Operations.pPressed[key] := false
		Operations.waiting[key] := false
	}

	class HoldToToggle {
		__New(key, timeout) {
			this.Key := key
			this.Timeout := timeout
			Operations.Initialize(key)
		}

		Down() {
			Operations.pPressed[this.Key] := true
			if (!Operations.fPressed[this.Key]) {
				Operations.fPressed[this.Key] := true
				SendInput("{" this.Key " Down}")
				Operations.waiting[this.Key] := true
				action() {
					Operations.waiting[this.Key] := false
				}
				SetTimer(action, -this.Timeout)
			}
		}

		Up() {
			Operations.pPressed[this.Key] := false
			if (!Operations.waiting[this.Key]) {
				Operations.fPressed[this.Key] := false
				SendInput("{" this.Key " Up}")
			}
		}
	}

	class HoldForContinuouslyClick {
		__New(key, interval, pressTime := 50) {
			this.Key := key
			this.Interval := interval
			this.PressTime := pressTime
			Operations.Initialize(key)
		}

		Down() {
			if (Operations.pPressed[this.Key])
				return
			Operations.pPressed[this.Key] := true
			timerFunction() {
				if (Operations.pPressed[this.Key] = false) {
					SetTimer(, 0)
					return
				}
				if (this.PressTime <= 0)
					SendInput("{" this.Key "}")
				else {
					SendInput("{" this.Key " Down}")
					lgr.Log(this.Key " Down")
					Operations.fPressed[this.Key] := true
					Sleep(this.PressTime)
					SendInput("{" this.Key " Up}")
					lgr.Log(this.Key " Up")
					Operations.fPressed[this.Key] := false
				}
			}
			SetTimer(timerFunction, this.Interval)
		}

		Up() {
			Operations.pPressed[this.Key] := false
		}
	}

	class DoubleClickSecondaryKey {
		lastPressedTime := Map()

		__New(key, altKey, timeout := 200) {
			this.Key := key
			this.AltKey := altKey
			this.Timeout := timeout
			Operations.Initialize(key)
		}

		Down() {
			if (Operations.pPressed[this.Key]) {
				SendInput("{" this.Key " Down}")
				return
			}
			local last := this.lastPressedTime.Has(this.Key) ? this.lastPressedTime[this.Key] : 0
			if (A_TickCount - last > this.Timeout) {
				SendInput("{" this.Key " Down}")
				Operations.pPressed[this.Key] := true
				this.lastPressedTime[this.Key] := A_TickCount
			} else {
				SendInput("{" this.AltKey " Down}")
				Operations.pPressed[this.AltKey] := true
				this.lastPressedTime[this.Key] := 0
			}
		}

		Up() {
			local cur := Operations.pPressed[this.Key] ? this.Key : this.AltKey
			SendInput("{" cur " Up}")
			Operations.pPressed[cur] := false
		}
	}
}