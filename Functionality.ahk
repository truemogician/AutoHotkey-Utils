/**
 * Some common useful functionality for games. To use, instantiate a sub class, then bind the `Down` and `Up` methods to corresponding keys.
 */
class Functionality {
	static fPressed := Map()

	static pPressed := Map()

	static lastPressedTime := Map()

	static Initialize(key) {
		Functionality.fPressed[key] := false
		Functionality.pPressed[key] := false
		Functionality.lastPressedTime[key] := 0
	}

	/**
	 * In many games, the player needs to hold down a key to perform an action.
	 * This class could turn the operation mode into toggling to save your fingers.
	 */
	class HoldToToggle {
		/**
		 * @param threshold Pressing `key` for less than `threshold` will be interpreted as a "click"
		 * and thus won't trigger corresponding actions. Default is 200ms.
		 */
		__New(key, threshold := 200) {
			this.Key := key
			this.Threshold := threshold
			Functionality.Initialize(key)
		}

		Down() {
			Functionality.pPressed[this.Key] := true
			if (!Functionality.fPressed[this.Key]) {
				SendInput("{" this.Key " Down}")
				Functionality.fPressed[this.Key] := true
				Functionality.lastPressedTime := A_TickCount
			}
		}

		Up() {
			Functionality.pPressed[this.Key] := false
			if (A_TickCount - Functionality.lastPressedTime[this.Key] > this.Threshold) {
				SendInput("{" this.Key " Up}")
				Functionality.fPressed[this.Key] := false
				Functionality.lastPressedTime := 0
			}
		}
	}

	/**
	 * In some situations, the player needs to click a key continuously, which is exhausting.
	 * This class allows you to perform such action at a specified frequency while holding the key.
	 */
	class HoldForContinuouslyClick {
		/**
		 * @param interval The interval between two clicks. Default is 250ms.
		 * @param pressTime The time the key will be hold for a press. Default is 50ms.
		 */
		__New(key, interval := 250, pressTime := 50) {
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

	/**
	 * Press the original key for the first time it is clicked, and press a secondary key when double clicked.
	 */
	class DoubleClickSecondaryKey {
		/**
		 * @param altKey The secondary key to press when double clicked.
		 * @param timeout Maximum time between two clicks to be considered as a double click. Default is 200ms.
		 */
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
			local last := Functionality.lastPressedTime.Has(this.Key) ? Functionality.lastPressedTime[this.Key] : 0
			if (A_TickCount - last > this.Timeout) {
				SendInput("{" this.Key " Down}")
				Functionality.pPressed[this.Key] := true
				Functionality.lastPressedTime[this.Key] := A_TickCount
			} else {
				SendInput("{" this.AltKey " Down}")
				Functionality.pPressed[this.AltKey] := true
				Functionality.lastPressedTime[this.Key] := 0
			}
		}

		Up() {
			local cur := Functionality.pPressed[this.Key] ? this.Key : this.AltKey
			SendInput("{" cur " Up}")
			Functionality.pPressed[cur] := false
		}
	}
}