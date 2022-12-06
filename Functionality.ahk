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
	}

	static Initialize(key) => this.Logical.Initialize(key)

	static Press(key, recordTime := false) {
		Send("{" key " Down}")
		this.Logical[key] := true
		if (recordTime)
			this.Logical.LastPressedTime[key] := A_TickCount
	}

	static Release(key, recordTime := false) {
		Send("{" key " Up}")
		this.Logical[key] := false
		if (recordTime)
			this.Logical.LastReleasedTime[key] := A_TickCount
	}

	static Click(key, holdTime := 50, recordTime := false) {
		if (holdTime <= 0)
			Send(key)
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
		 * @param physical Whether the key is physically pressed. Default is false.
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
			KeyState.Initialize(key)
		}

		Down() {
			if (KeyState.Physical[this.Key])
				return
			if (!KeyState.Logical[this.Key])
				KeyState.Press(this.Key, true)
		}

		Up() {
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
		 */
		__New(key, threshold := 200, pressTime := 50) {
			this.Key := key
			this.Threshold := threshold
			this.PressTime := pressTime
			KeyState.Initialize(key)
		}

		Down() {
			if (KeyState.Physical[this.Key])
				return
			KeyState.Press(this.Key)
			timerFunction() {
				if (KeyState.Physical[this.Key])
					KeyState.Release(this.Key)
			}
			SetTimer(timerFunction, -this.Threshold)
		}

		Up() {
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
	class HoldForContinuouslyClick {
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
			KeyState.Initialize(key)
			KeyState.Initialize(targetKey)
		}

		Down() {
			if (KeyState.Physical[this.Key])
				return
			timerFunc() {
				if (!KeyState.Physical[this.Key]) {
					SetTimer(, 0)
					return
				}
				KeyState.Click(this.TargetKey, this.PressTime)
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
			if (KeyState.Logical[this.TargetKey])
				KeyState.Release(this.TargetKey)
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
			this.__AltKeyPressed := false
			KeyState.Initialize(key)
			KeyState.Initialize(altKey)
		}

		Down() {
			if (KeyState.Physical[this.Key])
				return
			if (A_TickCount - KeyState.Logical.LastPressedTime[this.Key] > this.Timeout) {
				KeyState.Press(this.Key, true)
				this.__AltKeyPressed := false
			}
			else {
				KeyState.Press(this.AltKey)
				this.__AltKeyPressed := true
			}
		}

		Up() {
			KeyState.Release(this.__AltKeyPressed ? this.AltKey : this.Key)
		}
	}
}