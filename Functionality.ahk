class Functionality {
	static fPressed := Map()

	static pPressed := Map()

	static waiting := Map()

	static Initialize(key) {
		Functionality.fPressed[key] := false
		Functionality.pPressed[key] := false
		Functionality.waiting[key] := false
	}

	class HoldToToggle {
		__New(key, timeout) {
			this.Key := key
			this.Timeout := timeout
			Functionality.Initialize(key)
		}

		Down() {
			Functionality.pPressed[this.Key] := true
			if (!Functionality.fPressed[this.Key]) {
				Functionality.fPressed[this.Key] := true
				SendInput("{" this.Key " Down}")
				Functionality.waiting[this.Key] := true
				action() {
					Functionality.waiting[this.Key] := false
				}
				SetTimer(action, -this.Timeout)
			}
		}

		Up() {
			Functionality.pPressed[this.Key] := false
			if (!Functionality.waiting[this.Key]) {
				Functionality.fPressed[this.Key] := false
				SendInput("{" this.Key " Up}")
			}
		}
	}

	class HoldForContinuouslyClick {
		__New(key, interval, pressTime := 50) {
			this.Key := key
			this.Interval := interval
			this.PressTime := pressTime
			Functionality.Initialize(key)
		}

		Down() {
			if (Functionality.pPressed[this.Key])
				return
			Functionality.pPressed[this.Key] := true
			timerFunction() {
				if (Functionality.pPressed[this.Key] = false) {
					SetTimer(, 0)
					return
				}
				if (this.PressTime <= 0)
					SendInput("{" this.Key "}")
				else {
					SendInput("{" this.Key " Down}")
					lgr.Log(this.Key " Down")
					Functionality.fPressed[this.Key] := true
					Sleep(this.PressTime)
					SendInput("{" this.Key " Up}")
					lgr.Log(this.Key " Up")
					Functionality.fPressed[this.Key] := false
				}
			}
			SetTimer(timerFunction, this.Interval)
		}

		Up() {
			Functionality.pPressed[this.Key] := false
		}
	}

	class DoubleClickSecondaryKey {
		lastPressedTime := Map()

		__New(key, altKey, timeout := 200) {
			this.Key := key
			this.AltKey := altKey
			this.Timeout := timeout
			Functionality.Initialize(key)
		}

		Down() {
			if (Functionality.pPressed[this.Key]) {
				SendInput("{" this.Key " Down}")
				return
			}
			local last := this.lastPressedTime.Has(this.Key) ? this.lastPressedTime[this.Key] : 0
			if (A_TickCount - last > this.Timeout) {
				SendInput("{" this.Key " Down}")
				Functionality.pPressed[this.Key] := true
				this.lastPressedTime[this.Key] := A_TickCount
			} else {
				SendInput("{" this.AltKey " Down}")
				Functionality.pPressed[this.AltKey] := true
				this.lastPressedTime[this.Key] := 0
			}
		}

		Up() {
			local cur := Functionality.pPressed[this.Key] ? this.Key : this.AltKey
			SendInput("{" cur " Up}")
			Functionality.pPressed[cur] := false
		}
	}
}