#Include "./Logger.ahk"

/**
 * A static class storing and mapping the logical and physical states of keys.
 */
class KeyState {
	/**
	 * A readonly mapping of the physical states of keys using `GetKeyState` with `P` mode.
	 */
	class Physical {
		static __Item[key] => GetKeyState(key, "P")
	}

	/**
	 * A static class storing and mapping the logical state of keys.
	 * 
	 * When `UseSystemState` is `true`, the states are mapped from `GetKeyState`;
	 * otherwize, they are managed by the class itself.
	 */
	class Logical {
		static __Map := Map()
		static __Logger := ""
		static __LastPressedTimeMap := Map()
		static __LastReleasedTimeMap := Map()
		/**
		 * Whether to use the `GetKeyState` to retrieve the logical states of keys. Default is `true`.
		 */
		static UseSystemState := true
		static __Item[key] {
			get => this.UseSystemState ? GetKeyState(key) : this.__Map.Has(key) ? this.__Map[key] : false
			set {
				if (!this.UseSystemState)
					this.__Map[key] := value
			}
		}
		/**
		 * A map recording the last pressed time of keys.
		 */
		static LastPressedTime => this.__LastPressedTimeMap
		/**
		 * A map recording the last released time of keys.
		 */
		static LastReleasedTime => this.__LastReleasedTimeMap

		static Initialize(key) {
			if (!this.UseSystemState)
				this.__Map[key] := false
			this.__LastPressedTimeMap[key] := 0
			this.__LastReleasedTimeMap[key] := 0
		}
		static EnableLogging(logFile) {
			this.__Logger := Logger(logFile)
		}
		static DisableLogging() {
			this.__Logger := ""
		}
	}

	static Initialize(key) => this.Logical.Initialize(key)

	static Press(key, recordTime := false) {
		Send("{" key " Down}")
		this.Logical[key] := true
		if (recordTime)
			this.Logical.LastPressedTime[key] := A_TickCount
		if (this.Logical.__Logger != "")
			this.Logical.__Logger.Log(key " Pressed")
	}

	static Release(key, recordTime := false) {
		Send("{" key " Up}")
		this.Logical[key] := false
		if (recordTime)
			this.Logical.LastReleasedTime[key] := A_TickCount
		if (this.Logical.__Logger != "")
			this.Logical.__Logger.Log(key " Released")
	}

	static Click(key, holdTime := 50, recordTime := false) {
		if (holdTime <= 0) {
			Send(key)
			if (this.Logical.__Logger != "")
				this.Logical.__Logger.Log(key " Clicked")
		}
		else {
			this.Press(key, recordTime)
			Sleep(holdTime)
			this.Release(key, recordTime)
		}
	}
}

/**
 * Some common useful functionality for games. To use, instantiate a sub class, then bind the `Down` and `Up` methods to corresponding keys.
 */
class Functionality {
	/**
	 * Perform the original action and record the key status.
	 */
	class Record {
		/**
		 * @param key The key to record and perform the original action.
		 * @param recordTime Whether to record the pressed and released time of the key.
		 * @param noRepeat If true, the key down event won't be triggered repeatedly when holding the key. Default is false.
		 */
		__New(key, recordTime := false, noRepeat := false) {
			this.Key := key
			this.RecordTime := recordTime
			this.NoRepeat := noRepeat
			this.__Triggered := false
			KeyState.Initialize(key)
		}

		/**
		 * @return Whether the action is performed. Only false when `NoRepeat` is true and the event has already been triggered.
		 */
		Down() {
			if (this.NoRepeat && this.__Triggered)
				return false
			KeyState.Press(this.Key, this.RecordTime)
			this.__Triggered := true
			return true
		}

		Up() {
			KeyState.Release(this.Key)
			this.__Triggered := false
		}
	}

	/**
	 * In many games, the player needs to hold down a key to perform an action.
	 * If the action lasts long enough, it would be a pain for fingers.
	 * This class would transfer quick click to toggling, while still preserve the original mode for long hold.
	 */
	class ToggleInHold {
		/**
		 * @param threshold Time threshold to distinguish long hold from quick click. Default is 200ms.
		 */
		__New(key, threshold := 200) {
			this.Key := key
			this.Threshold := threshold
			this.__Triggered := false
			KeyState.Initialize(key)
		}

		Down() {
			if (this.__Triggered)
				return
			this.__Triggered := true
			if (!KeyState.Logical[this.Key])
				KeyState.Press(this.Key, true)
		}

		Up() {
			this.__Triggered := false
			if (A_TickCount - KeyState.Logical.LastPressedTime[this.Key] > this.Threshold)
				KeyState.Release(this.Key)
		}
	}

	/**
	 * In many games, some keys are used to toggle certain status.
	 * But in some cases, the status only needs to be enabled for a short time, and clicking twice reduces reactivity.
	 * This class would transfer long hold to holding, which means that the status will be toggle when pressed and toggled back when released,
	 * while still preserve the original mode for quick click.
	 */
	class HoldInToggle {
		/**
		 * @param threshold Time threshold to distinguish long hold from quick click. Default is 200ms.
		 * @param pressTime The time the key will be hold for a click. Default is 50ms.
		 * @param physicalKey This operation relys on key's physical state.
		 * If the action is triggered by a different key, specify it here. Default is the same as `key`.
		 */
		__New(key, threshold := 200, pressTime := 50, physicalKey := key) {
			this.Key := key
			this.Threshold := threshold
			this.PressTime := pressTime
			this.PhysicalKey := physicalKey
			this.__Triggered := false
			KeyState.Initialize(key)
			if (key != physicalKey)
				KeyState.Initialize(physicalKey)
		}

		Down() {
			if (this.__Triggered)
				return
			this.__Triggered := true
			KeyState.Press(this.Key)
			timerFunction() {
				if (KeyState.Physical[this.PhysicalKey])
					KeyState.Release(this.Key)
			}
			SetTimer(timerFunction, -this.Threshold)
		}

		Up() {
			this.__Triggered := false
			if (KeyState.Logical[this.Key])
				KeyState.Release(this.Key)
			else
				KeyState.Click(this.Key, this.PressTime)
		}
	}

	/**
	 * In some situations, the player needs to click a key continuously, which is exhausting.
	 * This class allows you to perform such action at a specified frequency while holding the key.
	 */
	class HoldForContinuousClick {
		/**
		 * @param key The key that triggers this action
		 * @param targetKey The key to be continuously clicked when holding `key`. Default is the same as `key`.
		 * @param interval The interval between two clicks. Default is 250ms.
		 * @param pressTime The time the key will be hold for a press. Default is 50ms.
		 */
		__New(key, targetKey := key, interval := 250, pressTime := 50) {
			this.Key := key
			this.TargetKey := targetKey
			this.Interval := interval
			this.PressTime := pressTime
			this.__Triggered := false
			KeyState.Initialize(key)
			KeyState.Initialize(targetKey)
		}

		/**
		 * Oscillation for press time, should be within [0, 1). Default is 0.
		 * @note A constant press time may rouse suspicion, so using oscillation is recommended.
		 */
		Oscillation := 0

		Down() {
			if (this.__Triggered)
				return
			this.__Triggered := true
			timerFunc() {
				if (!KeyState.Physical[this.Key])
					SetTimer(, 0)
				else {
					local pressTime := Round(this.PressTime * Random(1 - this.Oscillation, 1 + this.Oscillation))
					KeyState.Click(this.TargetKey, pressTime)
				}
			}
			if (this.Key != this.TargetKey)
				SetTimer(timerFunc, this.Interval)
			else {
				KeyState.Press(this.TargetKey)
				startTimer() {
					if (!KeyState.Physical[this.Key])
						return
					KeyState.Release(this.TargetKey)
					SetTimer(timerFunc, this.Interval)
				}
				SetTimer(startTimer, -this.Interval)
			}
		}

		Up() {
			this.__Triggered := false
			if (KeyState.Logical[this.TargetKey])
				KeyState.Release(this.TargetKey)
		}
	}

	/**
	 * Trigger a secondary key when double clicked.
	 */
	class DoubleClickSecondaryKey {
		/**
		 * @param altKey The secondary key to press when double clicked.
		 * @param mode The reaction mode for the secondary key. Default is `"replace"`.
		 * - `"replace"`: Only the secondary key will be pressed and released during the second click.
		 * - `"concur"`: Both the original and secondary key will be pressed and released during the second click.
		 * - `"press"`: The secondary key will be clicked at the press moment of the second click.
		 * - `"release"`: The secondary key will be clicked at the release moment of the second click.
		 * @param timeout Maximum time between two clicks to be considered as a double click. Default is 200ms.
		 */
		__New(key, altKey, timeout := 200, mode := "replace") {
			this.Key := key
			this.AltKey := altKey
			this.Timeout := timeout
			this.Mode := mode
			this.__Triggered := false
			this.__AltKeyTriggered := false
			KeyState.Initialize(key)
			KeyState.Initialize(altKey)
		}

		Down() {
			if (this.__Triggered)
				return
			this.__Triggered := true
			if (A_TickCount - KeyState.Logical.LastPressedTime[this.Key] > this.Timeout) {
				KeyState.Press(this.Key, true)
				this.__AltKeyTriggered := false
			}
			else {
				this.__AltKeyTriggered := true
				if (this.Mode == "replace" || this.Mode == "concur")
					KeyState.Press(this.AltKey)
				else if (this.Mode == "press")
					KeyState.Click(this.AltKey)
				if (this.Mode != "replace")
					KeyState.Press(this.Key, true)
			}
		}

		Up() {
			this.__Triggered := false
			if (this.__AltKeyTriggered) {
				if (this.mode == "replace" || this.mode == "concur")
					KeyState.Release(this.AltKey)
				else if (this.mode == "release")
					KeyState.Click(this.AltKey)
			}
			if (!this.__AltKeyTriggered || this.Mode != "replace")
				KeyState.Release(this.Key)
		}
	}

	/**
	 * Click one key and trigger some other keys at the same time.
	 */
	class OneToMany {
		/**
		 * @param otherKeys The keys to be triggered at the same time.
		 */
		__New(key, otherKeys*) {
			this.Key := key
			this.OtherKeys := otherKeys
			this.__Triggered := false
			KeyState.Initialize(key)
			for (otherKey in otherKeys)
				KeyState.Initialize(otherKey)
		}

		Down() {
			if (this.__Triggered)
				return
			this.__Triggered := true
			KeyState.Press(this.Key)
			for (otherKey in this.OtherKeys)
				KeyState.Press(otherKey)
		}

		Up() {
			this.__Triggered := false
			KeyState.Release(this.Key)
			for (otherKey in this.OtherKeys)
				KeyState.Release(otherKey)
		}
	}

	/**
	 * Double click is a common problem for mice, which is often caused by dust or the oxidation of the mouseswitch.
	 * While a more permanent solution is to replace the switch, this class provides a temporary solution by filtering out the second click.
	 */
	class FixDoubleClick {
		/**
		 * @param key The key with double click problem.
		 * @param threshould The time threshold to distinguish anomalous double click. Default is 80ms.
		 */
		__New(key, threshould := 80) {
			this.Key := key
			this.Threshold := threshould
			this.__Ignored := false
			KeyState.Initialize(key)
		}

		Down() {
			if (this.__Ignored)
				return
			if (A_TickCount - KeyState.Logical.LastPressedTime[this.Key] <= this.Threshold)
				this.__Ignored := true
			else
				KeyState.Press(this.Key, true)
		}

		Up() {
			if (this.__Ignored)
				this.__Ignored := false
			else
				KeyState.Release(this.Key)
		}
	}
}